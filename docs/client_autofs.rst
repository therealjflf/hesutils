
A tale of two models: AutoFS vs. FILSYS
=======================================

Hesiod defines the possibility of associating filesystems to users, and possibly groups, via FILSYS records. Those filesystems can then be mounted on demand. Linux and the \*BSD also offer the capability of mounting filesystems on demand, via ``autofs`` or ``automount``. But as it turns out, the models that they use are very different.



TL;DR
-----

If you want to use AutoFS with its Hesiod backend:

#. All the automounted filesystems must be mounted under a single common directory, for example all the user homes under ``/home``;

#. If you use ``hesgen`` to generate automatic FILSYS records, the *mount paths* must be ``<common directory>/<user name>``;

#. In ``/etc/auto.master``, add this line::

   <common directory>    hesiod

#. Never have more than one Hesiod-backed entry in ``auto.master``!




Hesiod model: everything is possible
------------------------------------

Hesiod associates filesystem mounts to an arbitrary name via FILSYS records. For example::

    jane.filsys    TXT    "NFS /export/home/jane nfsserver rw /home/jane"


The Hesiod documentation only gives examples of FILSYS records for user homes, but there is no limitation of any sort. The name of the FILSYS can be anything. User names have the advantage of being unique, which prevents namespace collisions.


The critical elements in that model are:

- The *key* to obtain the FILSYS record is an arbirary name. It is often a user name but there is no rule or limitation. It is not related in any way to any file path.

- The *time* of mount isn't specified. It could be on-access, or when a user logs in, etc.




AutoFS model: mount a predefined directory on access
----------------------------------------------------

AutoFS associates filesystem mounts with specific directories in the filesystem hierarchy. It is typically a two-step process:

1. In the master file, usually ``/etc/auto.master``, entries associate a *mount point* with a *map* (which can be a local file or obtained via a variety of remote mechanisms);

2. In each map file, entries associate a *key* with a mount device and mount options.


If the master *mount point* is ``/-``, then it takes a direct map where all paths are absolute (starting with ``/``). The mount paths are those absolute paths. Otherwise, the map is indirect and contains relative paths. Then the mount paths are ``<mount point from the master file>/<key from the map file>``. The thing called *mount point* in the master file is not in fact a mount point, but rather the directory that contains the real mount points.

The AutoFS daemon passes all that information to the kernel module, which sets up triggers on the specified directories (the *mount points* from the master map, and the absolute paths). Then when a user tries to access one of those paths, the trigger fires and the daemon mounts the corresponding filesystem.


Taking an example from the AutoFS configuration files, a line in ``/etc/auto.master`` could look like this::

    /misc   /etc/auto.misc

As the *mount point* is not ``/-``, the map is an indirect map.

And the map file ``/etc/auto.misc`` could contain this (in the traditional Sun format)::

    cd  -fstype=iso9660,ro,nosuid,nodev  :/dev/cdrom

The effect of that setup is to mount the local device ``/dev/cdrom`` when the user tries to access ``/misc/cdrom``, with the options ``fstype=iso9660,ro,nosuid,nodev``.


The critical elements of that model are:

- The *key* to know what to mount is the mount path. It is not related in any way to any user.

- The *time* of mount is when the mount path is accessed.




Hesiod support in AutoFS
------------------------

AutoFS supports fetching FILSYS records with the following syntax in the master file::

    <mount path>    hesiod

(Again, the *mount path* in that case is the **parent directory** of the actual mount paths.)

There is no easy way to iterate over all FILSYS records in a Hesiod domain, which would be required to use a direct map file. Also, direct maps are loaded only when the AutoFS daemon (re)starts, so any update to the FILSYS records on the Hesiod server would require restarting all the client AutoFS daemons! Therefore only indirect maps are supported. No map file is required, and the mount information is obtained on the fly from FILSYS records.


For example, let's have this in ``/etc/auto.master``::

    /mnt    hesiod

If you try accessing ``/mnt/joe`` or anything below it, this will appear in the AutoFS daemon logs::

    attempting to mount entry /mnt/joe
    lookup_mount: lookup(hesiod): looking up root="/mnt", name="joe"

And on your DNS server logs (in that case Dnsmasq), you will see a request for the FILSYS record::

    query[TXT] joe.filsys.hesiod from 127.0.0.1
    config joe.filsys.hesiod is TXT

(Here ``.hesiod`` is the LHS.RHS defined in ``/etc/hesiod.conf``.)


So the way AutoFS supports Hesiod is to use the *key*, which is the name of a subdirectory under the root *mount point*, as the name for the FILSYS record.

Importantly, **the mount path in the FILSYS record is ignored**. AutoFS already knows the mount path: ``<root mount point>/<key>``.




Reconciliating the two models
-----------------------------

Namespace mapping
~~~~~~~~~~~~~~~~~

The intersection of those two models is a strange place to be. The key that is used for the FILSYS request is not a full filesystem path, but only its last component. This opens the door to namespace collisions of all sorts.

Essentially, the various entries in ``auto.master`` can usually be though of as separate namespaces. The keys for each namespace are looked up in corresponding maps. But if you're using the Hesiod backend, there's just one flat key namespace. So all those seemingly separate AutoFS namespaces map to a single Hesiod one.

Some interesting effects:

- You can't have both ``/home/joe`` and ``/backup/joe``. If you try to define one root mount point as ``/``, then the keys will be ``home`` and ``backup`` and that won't work. If you define two root mount points as ``/home`` and ``/backup``, then the key will be ``joe`` in both cases, and therefore return the same FILSYS record.

- If you have two root mount points defined with a Hesiod backend, for example ``/home`` and ``/projects``, there will be no difference between the two and you will be able to mount anything anywhere. A FILSYS record named ``joe.filsys``? You'll be able to mount it as ``/home/joe`` as well as ``/projects/joe``. Remember, **the mount path in the FILSYS record is ignored**.

- As a corollary of the last point, there is a serious risk of data corruption when having multiple Hesiod-backed root mount points. Local devices *shouldn't* be able to be mounted more than once. Remote filesystems *should* allow safe simultaneous accesses when multi-mounted (some will protect against multi-mount on the same client). But even in that case, a user might accidentally multi-mount a remote share, then start deleting files in one to do some cleanup, believing that those are two completely distinct directories and the other one still has the data. And then you, the admin, will have a very bad day too when the emails start coming in.


The bottom line is: **never have more than one Hesiod-backed root mount point**!



Hesgen-generated records
~~~~~~~~~~~~~~~~~~~~~~~~

Hesgen is essentially user- and group-oriented. In that context, the most logical choice for FILSYS records is to use the user name as a key, just like in the standard documentation.


As explained in `Homepaths and FILSYS records <hes_filsys.rst>`_, ``hesgen`` uses three different home paths:

- the *passwd path*, in the original ``passwd`` file;
- the *export path*, which is the share path on the remote server;
- and the *mount path*, which is both the mount point on the client and the user home path when mounted there.


The *mount path* will be ignored by AutoFS, but as it is also the user's home directory in the USER and UID records, the remote filesystem must be mounted in that location. So **we have to make sure that the full AutoFS mount path matches our *mount path***.

The last path member in the *mount path* is the user name, and that's our key for the FILSYS record. Therefore it must also be our key in AutoFS. So the root mount path in ``/etc/auto.master`` must be the *mount path* minus the user name at the end.

Lost? Yeah, it took me a while, too.


Right, time for an example.

Let's say that we have those three users::

    jake:x:5000:5000:"Joliet" Jake Blues:/home/jake:/bin/bash
    elwood:x:5001:5001:Elwood Blues:/home/elwood:/bin/bash
    cleophus:x:5002:5200:Reverend Cleophus James:/home/cleophus:/bin/bash
                                                 ^^^^^^^^^^^^^^
                                                  passwd path

The *passwd path* there is ``/home/<user name>``.

The homes are exported to the client machines via NFS. The *export path* is ``/export/home/<user name>``. Let's say that the client configuration is a bit weird for historical reasons (as usual), and the directory containing the homes on the client is ``/mnt/nfs/home``. So the *mount path* is ``/mnt/nfs/home/<user name>``.

As usual the *mount path* is used in two different places:

- it replaces the *passwd path* in USER and UID records,
- and it is included -- but ignored -- in the FILSYS records.


We'll generate automatic FILSYS records with modifications of the *passwd path*. The configuration file contains just this::

    FILSYS=1
    FILSYSAUTO=1
    NFSSERVER=nfsserver
    HOMESEDEXPORT='s:^:/export:'
    HOMESEDMOUNT='s:^:/mnt/nfs:'
    OUTPUTFMT="bind"


Running ``hesgen`` gives us this (truncated for clarity)::

    ; Users
    jake.passwd       TXT    "jake:*:5000:5000::/mnt/nfs/home/jake:/bin/bash"
    elwood.passwd     TXT    "elwood:*:5001:5001::/mnt/nfs/home/elwood:/bin/bash"
    cleophus.passwd   TXT    "cleophus:*:5002:5200::/mnt/nfs/home/cleophus:/bin/bash"
                                                    ^^^^^^^^^^^^^^^^^^^^^^
                                                  mount path (home directory)
    
    ; Filesystems
    jake.filsys       TXT    "NFS /export/home/jake nfsserver rw /mnt/nfs/home/jake"
    elwood.filsys     TXT    "NFS /export/home/elwood nfsserver rw /mnt/nfs/home/elwood"
    cleophus.filsys   TXT    "NFS /export/home/cleophus nfsserver rw /mnt/nfs/home/cleophus"
    ^^^^^^^^                      ^^^^^^^^^^^^^^^^^^^^^              ^^^^^^^^^^^^^|^^^^^^^^
    Hesiod key                        export path            AutoFS:  root mount  |  key
                                                             Hesiod:       mount path


And there you can see where the two models intersect. The *mount path* in the FILSYS record is ignored by AutoFS as it uses its own mount path, but we have to make sure that the FILSYS mount path and the AutoFS mount path match. If they don't, the user's home directory will be invalid.

We know that the key used by AutoFS is the last path component. So the root mount point in ``/etc/auto.master`` must be the *mount path* minus the user name::

    /mnt/nfs/home   hesiod




Notes
-----

As the key to a filesystem in AutoFS is its mount point, there can only be one entry per key. If multiple FILSYS records are returned for that key, all but the last one will be ignored.

Hesgen tries to generate valid mount paths in the FILSYS records, even though they're ignored by AutoFS. They might still be useful with custom client mount scripts, for example.

