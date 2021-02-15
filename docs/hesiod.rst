
Hesutils and the Hesiod name service
====================================


What is the Hesiod name service?
--------------------------------

Hesiod is a mechanism through which information of various types (including user and group names) is distributed via DNS servers to network clients. As such it is a name service (or `directory service <https://en.wikipedia.org/wiki/Directory_service>`_).

Hesiod was designed and implemented by the MIT in the 1980s as part of `Project Athena <https://en.wikipedia.org/wiki/Project_Athena>`_, to provide directory services to the MIT campus workstations.

Its goals are broadly similar to those of `NIS <https://en.wikipedia.org/wiki/Network_Information_Service>`_ (created at about the same time at Sun Microsystems) and `LDAP <https://en.wikipedia.org/wiki/Lightweight_Directory_Access_Protocol>`_ (created a decade later as a simplification of the `X.500 <https://en.wikipedia.org/wiki/X.500>`_ directory access protocol). In the end the actual design choices and protocols of those three turned out to be very different from one another, though.



Why Hesiod?
-----------

There are a lot of very good reasons for using Hesiod over alternatives like NIS and LDAP:

- It's simple!

  - On the server(s), all the data is contained in DNS records, themselves text lines in DNS zone files. Everything is editable by hand, grep-able, trivially versionable in Git (or other VCS), and generally human-friendly;

  - No need for a separate service with additional open ports and firewall / packet filtering;

  - On the clients, basic configuration is limited to having the right DNS server in ``resolv.conf`` and adding ``hesiod`` to multiple lines of ``nsswitch.conf``;

  - Easy representation of corporate organizational structures via DNS subdomains (e.g. ``tech.chicago.ns.mycorp.com``);
  
  - Query syntax trivially encoded in the domain of the DNS request (e.g. ``joe.passwd.tech.chicago.ns.mycorp.com`` -- even without knowing anything about Hesiod you can already figure out what this request is for);


- As the data is sent via DNS, Hesiod benefits from the strengths of the DNS protocol. This includes things like:

  - Built-in high-availability (one of DNS' most underrated design features);

  - Very high-performance and low-latency implementation of many DNS servers;

  - Zone transfers and dynamic updates;

  - Simple and easy DNS delegation mechanism to spread the load over multiple servers, or use a dedicated server for Hesiod;

  - Ability to answer Hesiod requests in a local recursive DNS forwarder without any change to upstream servers;

  - DNS scales.


The key reason for using Hesiod is really its simplicity. The dominant directory service at that point in time is LDAP, and its most common implementation on Linux systems is OpenLDAP. A general opinion that I (the Hesutils author) hold and have heard from colleagues again and again over the years is that OpenLDAP is overly complicated, suffers from very poor design choices that seriously affect usability, and is overkill in a lot of cases. Hesiod is a much simpler solution, that's faster and easier to deploy and manage.


A good description of that situation is given in this `blog post <https://soylentnews.org/meta/article.pl?sid=15/07/13/0255214>`_ (`archive.org cache <https://web.archive.org/web/20190922024716/https://soylentnews.org/meta/article.pl?sid=15/07/13/0255214>`_).


Hesiod's simplicity was known from the very beginning, as this tidbit from `Dyer's 1988 paper <http://citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.37.8519>`_ (`local copy <PDF/10.1.1.37.8519.pdf>`_ of the PDF file) shows:

> A measure of how successful Hesiod has been in its deployment over the past six months is how infrequently problems have appeared. For the most part, applications make Hesiod queries and receive answers with millisecond delays. Today, the Hesiod database for Project Athena contains almost three megabytes of data: roughly 9500 /etc/passwd entries, 10000 /etc/group entries, 6500 file system entries and 8600 post office records. There are three primary Hesiod nameservers distributed across the campus network.



Why not Hesiod?
---------------

There are also a few reasons for which Hesiod might not be the best solution for you:

- Just like NIS, it's a Linux- and BSD-only mechanism. There is no support for it in Microsoft Windows or Apple OSX (or likely anything else). If you require support from those OS then you're probably already using LDAP (or its variant Active Directory) anyway.

- As the data is sent via DNS, Hesiod is affected by the limitations and security problems of the DNS protocol. In real life those can be mitigated out but you need to be aware of them when implementing a Hesiod infrastructure. For further information see `Passwords and security concerns <hes_sec.rst>`_.

- Some Linux distributions have decided that Hesiod wasn't used anymore (possibly because there isn't any complaint from those using it), and have started disabling NSS support for Hesiod in their glibc build. You will need to check whether your preferred distribution supports it, and if not you may want to ask for support to be brought back in.



Is there a Hesiod standard?
---------------------------

There isn't a real Hesiod standard per se, apart from how it's implemented and used at MIT. The two core documents that describe it are:

- "Hesiod Name Service" by Steven P. Dyer and Felix S. Hsu, in Project Athena Technical Plan, 1987.
  Available from `The Athena Technical Plan <https://web.mit.edu/Saltzer/www/publications/atp.html>`_ (`local copy <PDF/e.2.3.pdf>`_ of the PDF file)

- "The Hesiod Name Server" by Stephen P. Dyer, in Proceedings of the USENIX Winter Technical Conference, 1988.
  Available through `CiteSeerX <http://citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.37.8519>`_ (`local copy <PDF/10.1.1.37.8519.pdf>`_ of the PDF file)


There are some differences between the two. The first one is essentially the original design, while the second one is how it was implemented. So while the first one is still an interesting read and provides additional details, the second one is what serves as reference. 


When writing the Hesutils, the client behaviour on Linux was the absolute reference, rather than copying exactly the outputs listed in the documents above. The resulting records work well with the Linux implementations, and in some cases contain some specific optimizations to prevent extraneous requests.

The following maintained packages represent the current state of Hesiod support on Linux:

- The GNU libc (for user and group records): `https://sourceware.org/git?p=glibc.git;a=tree;f=hesiod;hb=HEAD`_ and other files

- The autofs kernel automounter (for FILSYS records): `https://git.kernel.org/pub/scm/linux/storage/autofs/autofs.git/tree/modules`_

- The `hesiod` package, containing a C client library and a tool to check the servers: `https://github.com/achernya/hesiod`_



How does Hesiod work?
---------------------

Like NIS or LDAP, Hesiod is a mechanism whose fundamental role is to provide user and group information over the network. This allows users to log into client machines using information available in a centralized database.

As opposed to, say, LDAP, Hesiod doesn't define a network communication protocol, nor does it require a specific piece of server software. Instead it uses DNS as a carrier protocol. All information available via Hesiod is obtained through DNS requests to a DNS server.

Hesiod defines:

- types of information available as DNS records;

- how to select a specific piece of information through the domain of the DNS request (request encoding);

- and the format of the data returned in answer to that request (record or response encoding);

So Hesiod is essentially a database format and query syntax over DNS, but not a protocol. As a corollary there isn't really such a thing as a Hesiod server: it's just a DNS server with the right data in the right way. Being a Hesiod server is a role, rather than a specific piece of software.


The DNS RFCs specify a generic record type, called a TXT record. TXT records were originally added to the spec for the very purpose of supporting Hesiod (together with the HS class). Since then TXT records have been used for everything and anything, in particular various forms of email sender validation. While there have been attempts to structure of the information they contain (`RFC 1464 <https://tools.ietf.org/html/rfc1464>`_), it goes a bit against the basic concept of a TXT record: store and serve unstructured or arbitrarily-structured data that doesn't fit in any other record type.

Hesiod DNS records are all TXT records, and the structure of the data within those TXT records is defined by Hesiod.

And that's it! There's no low-level protocol, no on-wire bitstream, no endianness, etc. All of that is dealt with by the underlying DNS protocol.


On the client side, applications need to support Hesiod as a source of information. At the time of writing there is support in the glibc NSS code for user, group and service requests. Some email clients may have implemented support for obtaining account information at some point in the past, but the current state is unknown. The original implementation of Hesiod at MIT provided much more information than this, as described in the historical documents. However this was not fully replicated on Linux or BSD.



What types of information are available via Hesiod?
---------------------------------------------------

The easiest way to understand Hesiod is to think of it essentially as centralized, network-wide ``/etc/passwd`` and ``/etc/group`` files. The DNS answers contain exactly the same information as would be obtained from either of those files, formatted in the exact same way.

For a given user, let's call him ``joe`` with ``uid 5001``, belonging to the primary group ``users`` with ``gid 5000``, the valid DNS requests and answers are:

- ``joe.passwd.<domain>`` providing Joe's ``/etc/passwd`` entry;

- ``5001.uid.<domain>`` also providing Joe's ``/etc/passwd`` entry;

- ``users.group.<domain>`` providing the ``users`` group's ``/etc/group`` entry;

- ``5000.gid.<domain>`` also providing the ``users`` group's ``/etc/group`` entry;

- ``joe.grplist.<domain>`` providing the list of groups of which ``joe`` is a member.

The last record is the only one that doesn't copy directly the data available in a standard UNIX file.


All those record types are mandatory, therefore a single user is identified by a minimum 5 separate records. In RFC 1034/1035 syntax, ``joe``'s records may look like this::

    ; Users
    joe.passwd          IN  TXT    "joe:*:5001:5000::/mnt/nfs/home/joe:/bin/bash"
    5001.uid            IN  CNAME  joe.passwd

    ; Groups
    users.group         IN  TXT    "users:x:5000:joe,user2,user3"
    5000.gid            IN  CNAME  users.group

    ; Group lists
    joe.grplist         IN  TXT    "5000:"


An additional, optional type of record called ``filsys`` can provide per-user home directory information to the automounter daemon of the client machines. That way remote home directories over NFS or other filesystems can be mounted on demand when the user logs in.

The FILSYS record for ``joe`` may look like this::

    ; Filesystems
    joe.filsys          IN  TXT    "NFS /export/home/joe nfssrv rw /mnt/nfs/home/joe"


The original Hesiod deployment at MIT contained many more record types than this. One could get details like print spooler information, preferred mail servers, etc. Support for such requests need to be implemented directly by the software that needs it. The glibc NSS code also supports using Hesiod for ``/etc/services`` and ``/etc/protocols`` entries (in a different format), but converting that information isn't supported by the Hesutils.



What are the Hesutils?
----------------------

The Hesutils are a set of scripts that facilitate the deployment and usage of a name server providing Hesiod records.

Currently the core script, ``hesgen`` (for HESiod GENerator), creates the TXT records for ``passwd``, ``uid``, ``group``, ``gid`` and ``filsys`` records based on the information contained in standard Linux files (``/etc/passwd`` and ``/etc/group``). Those TXT records can be printed out in various formats, as accepted by different DNS servers.

In other words, the Hesutils allow you to take a subset of the current user and group state of a given host, and generate an equivalent Hesiod setup. Users and groups are still managed on that original host in the normal manner, and after any change a new Hesiod setup can be generated.

Essentially ``hesgen`` is a database translation tool.

Additionally, a second tool called ``hesadd`` wraps around ``useradd`` and ``groupadd``. As described in the Hesutils `model of operations <hes_model.rst>`_, uids and gids eligible for translation to Hesiod need to be within certain ranges. This wrapper makes sure that the freshly-created users and groups are within those ranges.

The Hesutils are not the only way to start using Hesiod, but for most people and a lot of use cases this will be the easiest and fastest way.



Hesiod is old! Is anyone still using it?
----------------------------------------

Yes, definitely! I (the Hesutils author) have been using it for years, and the Hesutils are a documented, expanded, cleaned up version of the scripts that I wrote over time to generate the Hesiod TXT records.

I have deployed Hesiod in two different scenarios:

- QA / CI clusters within organizations that used LDAP, but the clusters didn't need LDAP (in fact those systems were completely isolated as the users had root access on the client machines for QA purposes);

- user name service to the various computers and VMs running on my home and work networks.


Now and then I read of other people having deployed it and being very happy. I believe that part of the reason why we don't read so much about it is that it just works. It's extremely easy to set up and there's no steep learning curve as with OpenLDAP -- and therefore no question on ServerFault!



Links and additional documentation
----------------------------------

I have already mentioned the two reference papers in `Is there a Hesiod standard?`_.


A few blog articles have been written in recent years (more recently than the reference papers, at any rate) about Hesiod. For example:

- `https://simonwo.net/technical/hesiod/`_
- `https://jpmens.net/2012/06/28/hesiod-a-lightweight-directory-service-on-dns/`_
- `https://soylentnews.org/meta/article.pl?sid=15/07/13/0255214`_

