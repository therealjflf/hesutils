
======
Hesadd
======

---------------------------
Add Hesiod users and groups
---------------------------

:Author:            JFLF
:Manual section:    8



Synopsis
========

    Usage:  hesadd <command> [options]
    
    Wrapper to useradd and groupadd that creates users and groups within the UID and
    GID ranges defined in the hesutils.conf configuration file.
    
    <command> is the name of the system command called to create the user or group.
    
    The wrapper itself takes no option. All [options] (including the names of users
    or groups to be created) are passed on unmodified as parameter to <command>.
    
    Commands:
      useradd           call the useradd command to create a user
      groupadd          call the groupadd command to create a group
    
    Aliases:
      hesuseradd        hesadd useradd
      hesgroupadd       hesadd groupadd



Description
===========

``Hesadd`` is a wrapper to ``useradd`` and ``groupadd`` that creates users and groups within the UID and GID ranges defined in the Hesutils configuration file.

Those users and groups can then be translated to Hesiod records with ``hesgen``.

See ``hesgen(1)`` and the Hesutils documentation for more details.

This command can only run as root.



Environment variables
=====================

``Hesadd`` reads the following optional environment variables::

    HESCFGFILE      alternate configuration file path (same as -c)


The order of priority for the configuration file path is:

    1. command line
    2. environment variable
    3. builtin default

The built-in default file paths are::

    configuration file      /etc/hesutils.conf



Files
=====

/etc/hesutils.conf



See also
========

.. Line blocks are required to force the RST parser to insert a newline before
   the hyperlink. But as a side effect it eats up the space between the blocks.
   Workaround: make all blocks line blocks.

| hesgen(1), hesinfo(1)

| The Hesutils documentation:
| `<https://gitlab.com/jflf/hesutils/-/blob/master/docs/index.rst>`_

