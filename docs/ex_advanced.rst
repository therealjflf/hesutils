
Advanced examples
=================

A warning about FILSYS records
------------------------------

FILSYS records are only needed for auto-mounting the user home on remote nodes. This requires additional client configuration. However, Hesiod + AutoFS is currently very limited, as described in `A tale of two models: AutoFS vs. FILSYS <client_autofs.rst>`__. For simplicity's and sanity's sakes, you may want to think twice before using FILSYS records.

**If you mount the home directories at boot, you don't need FILSYS records!**

The following pages are mandatory reading to understand what follows:

- `The curious case of the multiple home paths <hes_homepaths.rst>`_
- `Homepaths and FILSYS records <hes_filsys.rst>`_

There is also a lot of documentation in the default configuration file. You should read the the description of all parameters presented below.



Enabling FILSYS record output
-----------------------------

FILSYS records in the ``hesgen`` output are controlled by multiple parameters.

The first one controls whether you want FILSYS records in the output at all. To write FILSYS records, set::

    FILSYS=1

It's useless on its own though, because there is no default FILSYS record for any user!

Let's use very simple configuration::

    $ cat /tmp/passwd
    joe:x:5000:5000:,,,:/home/joe:/bin/bash

    $ cat /tmp/group
    joe:x:5000:

    $ cat /tmp/hesutils.conf
    FULLMEMBERLIST=1
    USERGRPLIST=0
    OUTPUTFMT=bind
    CREATEZONE=0
    FILSYS=1

If we run ``hesgen`` with that, it gives us::

    $  ./hesgen -c /tmp/hesutils.conf -p /tmp/passwd -g /tmp/group

    ; Generated by hesgen on Wed Mar 17 21:33:15 CET 2021

    ; Users
    joe.passwd     TXT    "joe:*:5000:5000::/home/joe:/bin/bash"
    5000.uid       CNAME  joe.passwd

    ; Groups
    joe.group      TXT    "joe:x:5000:joe"
    5000.gid       CNAME  joe.group

    ; Filesystems

No FILSYS record was printed out, as we haven't created any yet.




Automatic FILSYS creation
-------------------------

The easiest way to create those FILSYS records is to use automatic FILSYS creation. This is enabled with this option::

    FILSYSAUTO=1

In a nutshell, automatic FILSYS creation uses the contents of a few parameters to build a FILSYS record for each user.


As a quick reminder, there are three different FILSYS formats::

    AFS  <export path>  <mount options>  <mount path>
    NFS  <export path>  <server>  <mount options>  <mount path>
    <FS type>  <device>  <mount options>  <mount path>

The two first are the classic ones. The third one is the generic one that can mount anything, including local devices and such. The generic ``<device>`` is anything that would be accepted as the first field in ``/etc/fstab``.

By default, the *export path* and the *mount path* are the same as the *passwd path*. We'll see later how to transform them.


To build the FILSYS records, ``hesgen`` takes the following parameters::

    FSTYPE=         # AFS or NFS -> classic, anything else -> generic
    NFSSERVER=      # only if FSTYPE=NFS
    FSDEVICE=       # only if generic
    FSMOUNTOPTS=


Let's try it. The configuration file is now this::

    FULLMEMBERLIST=1
    USERGRPLIST=0
    OUTPUTFMT=bind
    CREATEZONE=0
    FILSYS=1
    FILSYSAUTO=1
    FSTYPE=NFS
    NFSSERVER=nfsserver
    FSMOUNTOPTS=-

The ``-`` mount option tells the client automounter to use whatever the defaults are for that type of filesystem.

And we obtain that output::

    ; Users
    joe.passwd     TXT    "joe:*:5000:5000::/home/joe:/bin/bash"
    5000.uid       CNAME  joe.passwd

    ; Groups
    joe.group      TXT    "joe:x:5000:joe"
    5000.gid       CNAME  joe.group

    ; Filesystems
    joe.filsys     TXT    "NFS /home/joe nfsserver - /home/joe"

Which is precisely what we wanted.




FILSYS transformations
----------------------

Now comes the real problem. As decribed in `The curious case of the multiple home paths <hes_homepaths.rst>`_, when creating FILSYS records we are dealing with three separate paths:

- the **passwd path**, in the ``/etc/passwd`` entry for a user on the management system;

- the **export path** on the network FS server for that user, used in FILSYS records only;

- and the **mount path**, which is both the home path of the user on the client system, and the mount point of the FILSYS record for that user.


In an ideal, well-designed system, all three would be identical. This is the case in this picture:

.. image::  images/hes_homepaths1.png
    :alt:   All home paths identical
    :align: center

But real life is rarely that simple.



The sed transformations
~~~~~~~~~~~~~~~~~~~~~~~

As seen in the `Basic examples <ex_basic.rst>`_, ``hesgen`` has a mechanism to transform the *passwd path* into a different *mount path*. That's enough when FILSYS RR aren't needed, as there is no *export path* in those cases.

The parameter for that is::

    HOMESEDMOUNT=

There is an equivalent parameter to transform the *passwd path* into the *export path*, called::

    HOMESEDEXPORT=

Both of them are sed expressions.


Let's take this setup as an example:

.. image::  images/hes_homepaths2.png
    :alt:   All home paths different
    :align: center


All three paths are different:

- the *passwd path* is ``/nfs/userhomes/<username>``
- the *export path* is ``/export/home/<username>``
- the *mount path* is ``/home/<username>``


The sed commands to transform the *passwd path* into the other two are::

    $ echo /nfs/userhomes/user | sed 's#.*/#/export/home/#'
    /export/home/user

    $ echo /nfs/userhomes/user | sed 's#.*/#/home/#'
    /home/user

So our two parameters become::

    HOMESEDEXPORT='s#.*/#/export/home/#'
    HOMESEDMOUNT='s#.*/#/home/#'


Let's update our test files to match that setup::

    $ cat /tmp/passwd
    joe:x:5000:5000:,,,:/nfs/userhomes/joe:/bin/bash

    $ cat /tmp/group
    joe:x:5000:

    $ cat /tmp/hesutils.conf
    FULLMEMBERLIST=1
    USERGRPLIST=0
    OUTPUTFMT=bind
    CREATEZONE=0
    FILSYS=1
    FILSYSAUTO=1
    FSTYPE=NFS
    NFSSERVER=nfsserver
    FSMOUNTOPTS=-
    HOMESEDMOUNT='s#.*/#/export/home/#'
    HOMESEDEXPORT='s#.*/#/home/#'

Running ``hesgen`` again, we obtain the expected output::

    ; Users
    joe.passwd     TXT    "joe:*:5000:5000::/home/joe:/bin/bash"
    5000.uid       CNAME  joe.passwd

    ; Groups
    joe.group      TXT    "joe:x:5000:joe"
    5000.gid       CNAME  joe.group

    ; Filesystems
    joe.filsys     TXT    "NFS /export/home/joe nfsserver - /home/joe"



The map file and command
~~~~~~~~~~~~~~~~~~~~~~~~

Just like in the non-FILSYS case (see `Basic examples <ex_basic.rst>`_), there are two additional mechanisms to modify the output:

- the map file specified by the ``FSMAPFILE`` parameter;
- and the map command specified by the ``FSCOMMAND`` parameter.

The FSCOMMAND is called in the exact same way, with the user's passwd line pre-split at the colons::

    joe:x:5000:5000::/home/joe:

    $FSCOMMAND "joe" "x" "5000" "5000" "" "/home/joe" ""

Those mechanisms apply per user. For each user, the map file will be read if ``FSMAPFILE`` is defined, then the map command will be called if ``FSCOMMAND`` is defined.


The contents of the file and the output of the command are parsed to keep only lines starting with either the current username, or ``*``. Then what is done depends on the contents of the line.

#. ``<user name>|*``

   If nothing else appears in the line, then the FILSYS record for the current user is cleared.

#. ``<user name>  <mount path>``

   If there are only two fields and the first one is the username, then the *mount path* in the PASSWD record of the current user is changed to the value of the second field. If the first field is ``*``, then the line is ignored.

   This is the same behaviour as in the non-FILSYS case.

#. A line in one of the following formats::

    <user name>|*  AFS  <export path>  <mount options>  <mount path>
    <user name>|*  NFS  <export path>  <server>  <mount options>  <mount path>
    <user name>|*  <FS type>  <device>  <mount options>  <mount path>

   So essentially the full contents of a FILSYS record, after either the username or ``*``.

   If the first field is the username, the FILSYS record for that user is changed **and** the *mount path* in their PASSWD record is changed to the value of the last field.

   If the first field is ``*``, then only the FILSYS record for that user is changed.

If multiple lines match in either the map file or the output of the map command for the current user, then they're processed one after the other in order of appearance and their effects are cumulative.

**Note:** Empty lines and comments starting with ``#`` are ingnored, including inline comments.


Some examples of lines and their effect:

::
    *                       # clear FILSYS records for any user
                            # this effectively cancels AUTOFILSYS

::
    joe                     # clear joe's FILSYS record

::
    admin  /home/admin      # changes admin's home dir in the PASSWD record

::
    # overwrite joe's FILSYS record, and change the home dir in PASSWD
    joe  NFS /export/home/joe nfsserver - /home/joe

::
    # overwite any user's FILSYS record, but don't touch PASSWD
    *  NFS /export/projects/X42 nfsserver - /projects/X42


If you think that the whole thing is a bit overblow, you're right. But surprisingly it's incomplete as it stands. This convoluted mechanism was designed to support the full FILSYS model, where a user can have more than one filesystem. But it doesn't make much sense within the limitations of the AutoFS model, so multiple FILSYS per user hasn't been implemented in ``hesgen``.

I left the parsing and processing logic in the code because the codepath is shared with the non-FILSYS case (and this one is really useful), and if it ever happens that someone has a really twisted use case that can't be solved in any other way (I can't think of any).

If you are one of those poor souls, good luck. You're on your own.

