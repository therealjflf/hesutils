
Hesiod on Linux clients
=======================

Hesiod tools
------------

The ``hesiod`` package is available in most Linux distributions. If not, it can be compiled from `sources <https://github.com/achernya/hesiod>`__.

It includes the Hesiod library ``libhesiod``, and ``hesinfo``, a tool to query a Hesiod server. Both obtain the Hesiod domain information from ``LHS`` and ``RHS`` in ``/etc/hesiod.conf``.

**Note**: Some distributions don't include a default ``/etc/hesiod.conf`` in their packages, for some reason. Thankfully the file is very short, and documented in the `manpage <https://manpages.ubuntu.com/manpages/focal/en/man5/hesiod.conf.5.html>`__.


Example::

    $ hesinfo joe passwd
    joe:*:5000:5000:,,,:/home/joe:/bin/bash


Note that the same information can be obtained with standard DNS tools::

    $ cat /etc/hesiod.conf
    #lhs=.ns
    rhs=.hesiod
    classes=IN

    $ dig joe.passwd.hesiod TXT

    ; <<>> DiG 9.11.5-P4-5~bpo9+1-Debian <<>> joe.passwd.hesiod TXT
    ;; global options: +cmd
    ;; Got answer:
    ;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 44214
    ;; flags: qr rd ra ad; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

    ;; OPT PSEUDOSECTION:
    ; EDNS: version: 0, flags:; udp: 4096
    ;; QUESTION SECTION:
    ;joe.passwd.hesiod.     IN  TXT

    ;; ANSWER SECTION:
    joe.passwd.hesiod.  600 IN  TXT "joe:*:5000:5000:,,,:/home/joe:/bin/bash"

    ;; Query time: 0 msec
    ;; SERVER: 127.0.0.1#53(127.0.0.1)
    ;; WHEN: Sat Mar 13 10:51:18 CET 2021
    ;; MSG SIZE  rcvd: 98


    $ nslookup -q=txt joe.passwd.hesiod
    Server:     127.0.0.1
    Address:    127.0.0.1#53

    Non-authoritative answer:
    joe.passwd.hesiod   text = "joe:*:5000:5000:,,,:/home/joe:/bin/bash"

    Authoritative answers can be found from:




User and group records
----------------------

Glibc-based distributions
~~~~~~~~~~~~~~~~~~~~~~~~~

Support for user and group records is available in the Glibc's Hesiod NSS module.

Some distributions ship the module inside the glibc package (e.g. `Debian <https://packages.debian.org/buster/amd64/libc6/filelist>`__, `Ubuntu <https://packages.ubuntu.com/focal/amd64/libc6/filelist>`__). Others have split it into external packages (e.g. Fedora). Finally some have deprecated Hesiod support and no longer build the glibc with the Hesiod NSS module (RHEL >= 7, SUSE). In some cases third-party repositories have rebuilt and packaged the module to bring back support.

**IMPORTANT NOTE**: Regrettably, the GNU libc maintainers decided unilaterally in 2020 to `deprecate <https://public-inbox.org/libc-alpha/87r1sx4h3v.fsf@oldenburg2.str.redhat.com/T/>`__ the Hesiod NSS module that was first added in 2000. This became official in the `2.32 release <https://sourceware.org/git/?p=glibc.git;a=blob_plain;f=NEWS;hb=refs/heads/release/2.32/master>`__. At the time of writing (2021, glibc `version 2.33 <https://sourceware.org/git/?p=glibc.git;a=tree;h=refs/heads/release/2.33/master>`__) the module is still there. I don't know yet of any external project to maintain that code outside of the glibc.


Configuring Hesiod is pretty straightforward:

#. Configure the LHS, RHS and class in ``/etc/hesiod.conf`` to match your DNS server zone, for example::

    #lhs=.ns
    rhs=.hesiod
    classes=IN

#. Configure ``/etc/nsswitch.conf`` to use Hesiod, for example::

   passwd:         compat hesiod
   group:          compat hesiod
   shadow:         compat
   gshadow:        files

   hosts:          files mdns4_minimal [NOTFOUND=return] dns
   networks:       files

   protocols:      db files hesiod
   services:       db files hesiod
   ethers:         db files
   rpc:            db files

   netgroup:       #nis


And that's it!

In the above nsswitch example, ``hesiod`` was added to all databases supported by the current glibc NSS backend. Hesgen doesn't support generating protocols or services records; if you haven't added any yourself you can omit ``hesiod`` for those databases.



Testing
~~~~~~~

Testing is pretty straightforward.

#. Populate your DNS zone with some real or test records, for example those in Dnsmasq syntax::

    # Users
    txt-record=joe.passwd.hesiod,"joe:*:5000:5000:,,,:/home/joe:/bin/bash"
    txt-record=5000.uid.hesiod,"joe:*:5000:5000:,,,:/home/joe:/bin/bash"

    # Groups
    txt-record=joesgroup.group.hesiod,"joesgroup:x:5000:joe"
    txt-record=5000.gid.hesiod,"joesgroup:x:5000:joe"
    txt-record=subgroup1.group.hesiod,"subgroup1:x:5001:"
    txt-record=5001.gid.hesiod,"subgroup1:x:5001:"
    txt-record=subgroup2.group.hesiod,"subgroup2:x:5002:"
    txt-record=5002.gid.hesiod,"subgroup2:x:5002:"

    # Group lists
    txt-record=joe.grplist.hesiod,"subgroup1:subgroup2"

#. Check that you can fetch the records::

   $ hesinfo joe passwd
   joe:*:5000:5000:,,,:/home/joe:/bin/bash

   $ hesinfo joesgroup group
   joesgroup:x:5000:joe

   $ hesinfo joe grplist
   subgroup1:subgroup2

#. Check that it works through NSS too::

   $ id joe
   uid=5000(joe) gid=5000(joesgroup) groups=5000(joesgroup),5001(subgroup1),5002(subgroup2)



Other distributions
~~~~~~~~~~~~~~~~~~~

Alternative C libraries, such as `musl <https://musl.libc.org/>`__, have no support for Hesiod at all, nor support for loading NSS modules.

Therefore distributions that ship with musl currently have no way of using Hesiod for user authentication. This includes:

- musl-only: Alpine Linux, OpenWRT;
- glibc or musl, when musl is used: Gentoo Linux, Void Linux.




FILSYS records
--------------

AutoFS supports Hesiod FILSYS records.

The Hesiod and AutoFS models are completely different. As a result, only a very narrow configuration can be expected to work. Caution must be exercised to avoid various issues. See `A tale of two models: AutoFS vs. FILSYS <client_autofs.rst>`__ for more details.

Support is absolutely minimum. From comment snippets, it looks like slightly more advanced support might have been planned at some point, and either never implemented or eventually removed. As of AutoFS 5.1.2, the only setup that I managed to get working is an indirect map with entries in Hesiod format::

    <root mount point>    hesiod


AutoFS upstream documentation is lacking, to say the least. The Hesiod-related comments in the configuration files cannot be trusted. Useful information is scattered around in distro-specific pages, but none of it applies to Hesiod. For example: `Arch <https://wiki.archlinux.org/index.php/Autofs>`__, `Gentoo <https://wiki.gentoo.org/wiki/AutoFS>`__, `Ubuntu <https://help.ubuntu.com/community/Autofs>`__, etc.




Other record types
------------------

The Glibc Hesiod NSS module also supports the protocols and services databases. The Hesutils don't support generating the corresponding records (yet).

Support for other record types needs to be implemented directly in the applications that need them, as there is no standardized system database for things like email account details.

It is really tricky to list the software that supports Hesiod, for two reasons:

- it might not rely on ``libhesiod`` but instead fetch some standard or custom records directly, therefore no requirement on ``libhesiod`` appears in package managers (this is the case with the glibc's Hesiod NSS module: it reimplements parts of ``libhesiod``, likely to avoid a circular dependency between the two libraries);

- or it may have its Hesiod support disabled at compilation time.


In Debian, the only two pieces of software that depend on ``libhesiod`` are:

- `AutoFS <client_autofs.rst>`__;

- The `Zephyr <https://github.com/zephyr-im/zephyr>`__ instant messaging system from MIT's Project Athena, depends on ``libhesiod``. You might need to read the sources or talk to MIT people to know more about that one, though.


Random Googling and checking of sources also tell me that both `Sendmail <https://www.proofpoint.com/us/products/email-protection/open-source-email-solution>`__ and `Fetchmail <https://www.fetchmail.info/>`__ support POBOX records to obtain information about user email accounts, via ``libhesiod``, but Hesiod support is disabled in Debian builds. There are certainly other cases like these.

