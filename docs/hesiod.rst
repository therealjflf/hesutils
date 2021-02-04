
Hesutils and the Hesiod name service
------------------------------------


What is the Hesiod name service?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Hesiod is a mechanism through which information of various types (including user and group names) is distributed via DNS servers to network clients. As such it is a name service (or `directory service <https://en.wikipedia.org/wiki/Directory_service>`_).

Hesiod was designed and implemented by the MIT in the 1980s as part of `Project Athena <https://en.wikipedia.org/wiki/Project_Athena>`_, to provide directory services to the MIT campus workstations.

Its goals are broadly similar to those of `NIS <https://en.wikipedia.org/wiki/Network_Information_Service>` (created at about the same time at Sun Microsystems) and `LDAP <https://en.wikipedia.org/wiki/Lightweight_Directory_Access_Protocol>`_ (created a decade later as a simplification of the `X.500 <https://en.wikipedia.org/wiki/X.500>`_ directory access protocol). In the end the actual design choices and protocols of those three turned out to be very different from one another, though.



Why Hesiod?
~~~~~~~~~~~

There are a lot of very good reasons for using Hesiod over alternatives like NIS and LDAP:

- It's simple!

  - On the server(s), all the data is contained in DNS records, themselved text lines in DNS zone files. Everything is editable by hand, grep-able, trivially versionable in Git (or other VCS), and generally human-friendly;

  - No need for a separate service with additional open ports and firewall / packet filtering;

  - On the clients, basic configuration is limited to having the right DNS server in ``resolv.conf`` and adding ``hesiod`` to multiple lines of ``nsswitch.conf``;

  - Easy representation of corporate organizational structures via DNS subdomains (e.g. ``tech.chicago.ns.mycorp.com``);
  
  - Query syntax trivially encoded in the domain of the DNS request (e.g. ``joe.passwd.tech.chicago.ns.mycorp.com`` -- even without knowing anything about Hesiod you can already figure out what this request is for);


- As the data is sent via DNS, Hesiod benefits from the strengths of the DNS protocol. This includes things like:

  - Built-in high-availability (one of DNS' most underrated design features);

  - Very high-performance and low-latency implementation of many DNS servers;

  - Zone transfers and dynamic updates;

  - Simple and easy DNS delegation mechanism to spread the load over multiple servers or use a dedicated server for Hesiod;

  - Ability to inject Hesiod data using repeating DNS servers without any change to upstream servers;

  - DNS scales.


The key reason for using Hesiod is really its simplicity. The dominant directory service at that point in time is LDAP, and its most common implementation on Linux systems is OpenLDAP. A general opinion that I (the Hesutils author) hold and have heard from colleagues again and again over the years is that OpenLDAP is overly complicated, suffers from very poor design choices that seriously affect usability, and is overkill in a lot of cases. Hesiod is a much simpler solution, that's faster and easier to deploy and manage.


A good description of that situation is given in this blog post (`archive.org cache <https://web.archive.org/web/20190922024716/https://soylentnews.org/meta/article.pl?sid=15/07/13/0255214>`_):
`https://soylentnews.org/meta/article.pl?sid=15/07/13/0255214`_


Hesiod's simplicity was know from the very beginning, as this tidbit from `Dyer's 1987 paper <http://citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.37.8519>`_ shows::

    A measure of how successful Hesiod has been in its deployment over the past six months is how infrequently problems have appeared. For the most part, applications make Hesiod queries and receive answers with millisecond delays. Today, the Hesiod database for Project Athena contains almost three megabytes of data: roughly 9500 /etc/passwd entries, 10000 /etc/group entries, 6500 file system entries and 8600 post office records. There are three primary Hesiod nameservers distributed across the campus network.



Why not Hesiod?
~~~~~~~~~~~~~~~

There are also a few reasons for which Hesiod might not be the best solution for you:

- Just like NIS, it's a Linux- and BSD-only mechanism. There is no support for it in Microsoft Windows or Apple OSX (or likely anything else). If you require support from those OS then you're probably already using LDAP (or its variant Active Directory) anyway.

- As the data is sent via DNS, Hesiod is affected by the limitations and security problems of the DNS protocol. In real life those can be mitigated out but you need to be aware of them when implementing a Hesiod infrastructure. For further information see `Passwords and security concerns <sec.rst>`_.

- Some Linux distributions have decided that Hesiod wasn't used anymore (possibly because there isn't any complaint from those using it), and have started disabling Hesiod support from their packages. You will need to check whether your preferred distributions support it, and if not you may want to ask for support to be brought back in.



Is there a Hesiod standard?
~~~~~~~~~~~~~~~~~~~~~~~~~~~

There isn't a real Hesiod standard per se, apart from how it's implemented and used at MIT. The two core documents that describe it are:

- "Hesiod Name Service" by Steven P. Dyer and Felix S. Hsu, in Project Athena Technical Plan, 1987.
  Available from `The Athena Technical Plan <https://web.mit.edu/Saltzer/www/publications/atp.html>`_ (`local copy <PDF/e.2.3.pdf>`_ of the PDF file)

- "The Hesiod Name Server" by Stephen P. Dyer, in Proceedings of the USENIX Winter Technical Conference, 1988.
  Available through `CiteSeerX <http://citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.37.8519>`_ (`local copy <PDF/10.1.1.37.8519.pdf>`_ of the PDF file)


There are some differences between the two. The first one is essentially the original design, while the second one is how it was implemented. So while the first one is still an interesting read and provides additional details, the second one is what serves as reference. 


For the Hesutils the client behaviour on Linux is the absolute reference. There are a few maintained packages that, together, represent the state of Hesiod support on Linux:

- The GNU libc (users and groups): `https://sourceware.org/git?p=glibc.git;a=tree;f=hesiod;hb=HEAD`_

- The autofs kernel automounter (FILSYS records for mounts): `https://git.kernel.org/pub/scm/linux/storage/autofs/autofs.git/tree/modules`_

- The `hesiod` package, containing a C client library and a tool to check the servers: `https://github.com/achernya/hesiod`_



How does that Hesiod-over-DNS thing works?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The DNS RFCs specify a generic record type, called a TXT record. TXT records were originally added to the spec for the very purpose of supporting Hesiod (together with the HS class, which is now deprecated). Since then they have been used for everything and anything, in particular various forms of email sender validation. While there have been attempts to define a generic structure of the information contained within (`RFC 1464 <https://tools.ietf.org/html/rfc1464>`_), it goes a bit against the basic concept of a TXT record: store and serve unstructured or arbitrarily-structured data that doesn't fit in any other record type.


Hesiod specifies 3 things:

- the types of information available to the clients;

- what data is needed for each type and how it's encoded within a TXT record;

- how to access those records via DNS requests for specially-constructed domain names.


And that's it! There's no low-level protocol, no on-wire bitstream, no endianness, etc. All of that is dealt with by the DNS server, client and protocol.

As a corollary there isn't really a thing called a Hesiod server: it's just a DNS server with the right data in the right way. Being a Hesiod server is a role, rather than a dedicated piece of software.



What type of information is available via Hesiod?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The easiest way to understand Hesiod is to think of it essentially as centralized, network-wide ``/etc/passwd`` and ``/etc/group`` files. The DNS answers contain exactly the same information as would be obtained from either of those files, formatted in the exact same way.

For a given user, let's call him ``joe`` with ``uid 1234``, belonging to the primary group ``admin`` with ``gid 1000``, the valid DNS requests and answers are:

 - ``joe.passwd.<domain>`` providing Joe's ``/etc/passwd`` entry;

 - ``1234.gid.<domain>`` also providing Joe's ``/etc/passwd`` entry;

 - ``admin.group.<domain>`` providing the ``admin`` group's ``/etc/group`` entry;

 - ``1000.gid.<domain>`` also providing the ``admin`` group's ``/etc/group`` entry.


An additional, optional type of record called ``filsys`` can provide home directory information to the automounter daemon of the client machines, per user. That way remote home directories over NFS or other filesystems can be mounted on-demand when the user logs in.


The original Hesiod deployment at MIT contained much more than this. One could get details like printer spool information, preferred mail server, etc. Support for such requests need to be implemented by the software that needs it, which was never done in the Linux world as far as I know. So the Hesutils doesn't cover that.



What are the Hesutils?
~~~~~~~~~~~~~~~~~~~~~~

The Hesutils are a set of scripts that facilitate the deployment and usage of a Hesiod name server.

Currently the core script, ``hesgen`` (for HESiod GENerator), creates the TXT records for ``passwd``, ``uid``, ``group``, ``gid`` and ``filsys`` records based on the information contained in standard Linux files (``/etc/passwd`` and ``/etc/group``). Those TXT records can be printed out in various formats, as accepted by different DNS servers.

In other words, the Hesutils allow you to take the current user and group state of a given host (technically a subset of that state), and generate an equivalent Hesiod setup. Users and groups are still managed on that original host in the normal manner, and after any change a new Hesiod setup can be generated.

It's not the only way to start using Hesiod, but for most people and a lot of use cases this will be the easiest and fastest way.



Hesiod is old! Is anyone still using it?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Yes, definitely! I (the Hesutils author) have been using it for years, and the Hesutils are a documented, expanded, cleaned up version of the scripts that I wrote over time to generate the Hesiod TXT records.

I have deployed Hesiod in two different scenarios:

- QA / CI clusters within organizations that used LDAP, but the clusters didn't need LDAP (in fact those systems were completely isolated as the users had root access on the client machines for QA purposes);

- user name service to the various VMs running on my work laptops (``/export/home`` exported over the host-only network, SSH key password-less login).


Now and then I read of other people having deployed it and being very happy. I believe that part of the reason why we don't read so much about it is that it just works. It's extremely easy to set up and there's no steep learning curve as with OpenLDAP -- and therefore no question on StackOverflow!



Links and additional documentation
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

I have already mentioned the two reference papers in `Is there a Hesiod standard?`_.


A few blog articles have been written in recent years (more recently than the reference papers, at any rate) about Hesiod. For example:

- `https://simonwo.net/technical/hesiod/`_
- `https://jpmens.net/2012/06/28/hesiod-a-lightweight-directory-service-on-dns/`_
- `https://soylentnews.org/meta/article.pl?sid=15/07/13/0255214`_

