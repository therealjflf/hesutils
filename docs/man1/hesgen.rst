
======
Hesgen
======

---------------------------
Generate Hesiod DNS records
---------------------------

:Author:            JFLF
:Manual section:    1


Synopsis
========

Usage:  hesgen [options]

Options:

  -h                display this help message and exit
  -v                run in verbose mode
  -t                test the configuration file and exit
  -d                don't print out the date in the output
  -c <filename>     use an alternate configuration file
  -p <filename>     use an alternate passwd file
  -g <filename>     use an alternate group file



Description
===========

``Hesgen`` reads the system's user and group databases, and translates them to Hesiod records.

Hesiod records, if any, are printed to stdout. All other messages (warnings, error, verbose messages) are printed to stderr.

The following Hesiod record types can be generated::

    passwd
    uid
    group
    gid
    grplist
    filsys

``Hesgen`` can write records in the format supported by various DNS forwarders and servers::

    dnsmasq
    unbound
    bind 9

The output format, as well as numerous other options directing the translation to Hesiod records, is set in the Hesutils configuration file, typically ``/etc/hesutils.conf``. All configuration parameters are documented in the file.



Environment variables
=====================

``Hesgen`` reads the following optional environment variables::

    HESCFGFILE      alternate configuration file path (same as -c)
    HESPASSWDFILE   alternate passwd file (same as -p)
    HESGROUPFILE    alternate group file (same as -g)


The order of priority for the various file paths is:

    1. command line
    2. environment variable
    3. builtin default

The built-in default file paths are::

    configuration file      /etc/hesutils.conf
    passwd file             /etc/passwd
    group file              /etc/group



Notes
=====

The GRPLIST records generated are non-standard. They follow the practice of the GNU libc's NSS module, which differs from available documents. See the Hesutils documentation for more details.



Files
=====

/etc/hesutils.conf



See also
========

.. Line blocks are required to force the RST parser to insert a newline before
   the hyperlink. But as a side effect it eats up the space between the blocks.
   Workaround: make all blocks line blocks.

| hesadd(8), hesinfo(1)

| The Hesutils documentation:
| `<https://gitlab.com/jflf/hesutils/-/blob/master/docs/index.rst>`_

