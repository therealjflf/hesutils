
Deviations and implementation choices
=====================================

Deviations
----------

GRPLIST
~~~~~~~

``Grplist`` are described in `Dyer's 1988 paper <http://citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.37.8519>`__ (`local copy <PDF/10.1.1.37.8519.pdf>`__ of the PDF file) as::

    HesiodName      HesiodNameType      Used By                 Info Returned
    group name      "grplist"           getgrent(), et. al.     Athena-wide group membership mapping


The same paper gives those examples of ``group`` and ``grplist`` records::

    # group.db
    # format of data is
    #   /etc/group entry
    10.01.group      HS     TXT 10.01:*:481:
    10.01a.group     HS     TXT 10.01a:*:483:
    10.01b.group     HS     TXT 10.01b:*:484:
    10.01sa.group    HS     TXT 10.01sa:*:639:
    10.01sb.group    HS     TXT 10.01sb:*:640:
    10.01t.group     HS     TXT 10.01t:*:638:

    # grplist.db
    # format of data is
    #   groupname1:gid1:groupname2:gid2:...
    10.01.grplist    HS     TXT "10.01:481:10.01t:638"
    10.01ta.grplist  HS     TXT "10.01t:638"


This shows an interesting feature of Hesiod: groups of groups. A user can be member of a meta-group, which has a GRPLIST RR containing other groups or further GRPLIST names. That's an easy way to add users to fixed groups-of-groups, as would be required when students sign up for certain classes for example.

In that paper, as well as ``hesinfo``'s `manpage <https://manpages.ubuntu.com/manpages/cosmic/man1/hesinfo.1.html>`__, a GRPLIST record is therefore defined with the key ``<groupname>.grplist``. One group points to a recursive list of groups.

The glibc's ``nss_hesiod`` module decided to redefine GRPLIST records. The key is now ``<username>.grplist``, and the value is the list of groups to which a user belongs. That's a completely different behaviour, which isn't document in any way that I know of (outside of looking at the sources or logging requests on the server). Most of the official docs describe the official behaviour, while most blog articles describe the glibc NSS module's behaviour.

That overloading of the name type (``grplist``) is very unfortunate. Obtaining a list of groups for a given user is a very desirable feature, but it should have been under a different name type. In the current situation, when a user and a group share the same name it's impossible to know if ``<name>.grplist`` refers to the user (to obtain a list of memberships) or group (to obtain a list of subgroups).

Also when using the group variant of GRPLIST, the records are quite simple and can be edited by hand without too much hassle. Using the user variant complicates things a lot as each modification to a user requires editing in multiple places, thus increasing the chances of a mistake. So some sort of software tool for record generation is recommended with the user variant, such as, you guessed it, the Hesutils.


For compatibility reasons ``hesgen`` will generate the *user* variant of GRPLIST; the list of memberships. Not doing so might break programs on the client nodes. It is possible to disable GRPLIST generation with a parameter in the configuration file.

Note that ``hesgen`` cannot generate the groups-of-groups variant of GRPLIST. That information simply doesn't exist in the standard system files.



NSS GRPLIST optimization
~~~~~~~~~~~~~~~~~~~~~~~~

The glibc's ``nss_hesiod`` module takes a conservative approach to parsing and validating GRPLIST RR contents.

It expects a record in that format::

    <username>.grplist      "groupname1:gid1[:groupname2:gid2:...]"

So essentially a colon-separated list of groupname and GID pairs, themselves colon-separated.

But there's no guarantee that the user didn't forget a groupname or GID somewhere in the list, nor that he didn't do a mistake and paste in an invalid groupname or GID, or a mismatched pair. And as all separators are the same, it's also impossible to resynchronize between pairs and detect missing entries.

So ``nss_hesiod`` takes every single entry in the list, checks whether it's a GID (integer) or not, and then looks up everything: first all the group names, then all the GIDs. As a result, any groupname:GID pair will trigger two separate lookups that will return the same record.

As it turns out, this is entirely unnecessary. Things work just as well when only one half of the pair is present (which half doesn't matter), and the number of DNS requests is halved.

So for optimization's sake, ``hesgen`` will only list the GIDs when generating user variant GRPLIST records. And at the same time this eliminates all sorts of potential issues with mismatching or missing pair members.




Implementation choices
----------------------

Things that we don't do (yet)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Support `Punycode <https://en.wikipedia.org/wiki/Punycode>`__ / `IDNA2008 <https://en.wikipedia.org/wiki/Internationalized_domain_name>`__ fields.

  Right now system user and group names must be composed of a subset of ASCII characters. The official rule is given in `POSIX.1-2017 <https://pubs.opengroup.org/onlinepubs/9699919799/>`__: `user names <https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap03.html#tag_03_437>`__, `group names <https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap03.html#tag_03_190>`__ and `portable filename character set <https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap03.html#tag_03_282>`__. Distros have either additional restrictions (e.g. no leading figure) or relaxed rules (Debian: ``^[^-~+:,\s][^:,\s]*$)``), which led to bugs like `this <https://github.com/systemd/systemd/issues/6237>`__. But those don't matter to Hesiod, what's important is the absence of non-ASCII characters.

  So as long as we only translate the system databases, those rules guarantee that we won't have to create records like ``mötley.crüe.user`` (although they were certainly using when creating their records). But Unicode record names might crop up in hand-edited files.

  The solution would be to detect non-ASCII names, and punycode them. But is this really useful right now?

  Note that this doesn't affect the record contents, only the names. UTF-8 characters are OK in the GECOS field, for example.


- Split large records.

  In this day and age the servers could do that themselves when they load the zones! Only dnsmasq is smart enough to do it.


- Support FILSYS AMD format.

  It seems that the Linux automounter would support FILSYS records in BSD AMD format, too. But the documentation is scarce, and honestly I can't be bothered to support yet another use case for FILSYS. There's enough.


- Generate other Hesiod records.

  Some of them might be partly obtainable from existing databases, but we're 



Things that we won't do
~~~~~~~~~~~~~~~~~~~~~~~

- Check for validity of the ``passwd`` and ``group`` files.

  Those are assumed to be modified via system tools, which ensure that there are no duplicates of any sort, the records are well formed, users aren't members of nonexistent groups, etc. *Caveat emptor* if you're hand-editing files, and *cave canem* when it comes back to bite you.


- Support Hesiod features that don't exist in standard system databases.

  Things like groups of groups aren't supported in system databases, so there's no way of generating them.


- Validate SOA record fields.

  Yeah. That's a pretty static record, and you should know what you're doing.

