
===
Hes
===

-------------------------------------------
Query all Hesiod records attached to a name
-------------------------------------------

:Author:            JFLF
:Manual section:    1


Synopsis
========

    Usage:  hes <name> [<name> ...]
    
    This command queries all possible Hesiod record types for the given names, and
    prints out the record contents.
    
    It relies on "hesinfo", which is part of the "hesiod" package in most Linux
    distributions. The upstream Hesiod server is configured in the system-wide
    Hesiod configuration file, typically "/etc/hesiod.conf".



Description
===========

This is a reimplementation of the MIT's Athena command of the same name.

It simply loops over all possible Hesiod record types for each name passed in parameter, and displays the results.



Files
=====

/etc/hesiod.conf



See also
========

.. Line blocks are required to force the RST parser to insert a newline before
   the hyperlink. But as a side effect it eats up the space between the blocks.
   Workaround: make all blocks line blocks.

| hesinfo(1)

| The Hesutils documentation:
| `<https://gitlab.com/jflf/hesutils/-/blob/master/docs/index.rst>`_

