
Client-side record caching
==========================

Rationale
---------

For performance reasons, it might be necessary to cache Hesiod records on the clients for a certain amount of time.

For example, the Glibc Hesiod NSS module doesn't cache the Hesiod answers, regardless of the DNS TTL. That leads to a *lot* of requests:

- each file or directory ``stat`` will trigger two lookups: UID and GID;

- any user info lookup will trigger UID and primary GID lookups, plus all secondary group lookups;

- if both group names and GIDs are included in the user's GRPLIST, that's two lookups per secondary group.

So ``ls -l`` on a large directory causes a storm of requests to the server. It's nothing that a modern DNS server in a small site cannot handle, but it will be a problem in a larger site. Moreover the latency of requests will be an issue for reactivity of client systems, especially if interactive.

The workaround for those issues is to cache the records locally, for some short length of time (even a few seconds is enough to smooth out a large directory listing).


There are two strategies:

1. use a `Local DNS resolver`_ daemon that caches TXT queries;

2. or use a `Caching daemon`_ that caches authentication information.

They both have advantages and inconvenients, see `Where to cache`_ for more details.




Caching decisions
-----------------

TTL
~~~

The TTL of A, AAAA, MX, NS records and such are usually long, as those don't change often.

For Hesiod records, the TTL should be a lot shorter. Users might still be able to stay connected or even log back onto the client machines after being removed from the zone if their records are still in the cache (depending on what is used for authentication), so you don't want them to be cached for too long. Therefore the maximum TTL will depend on site policies and risk assessment.

On the other hand, a very short TTL will cause problems if there is a network issue. The cache can answer queries while the upstream resolvers are unreachable, until the TTL expires. The shorter the TTL, the faster the cache will go stale.

**Note**: There is no *guarantee* that the cache will help during a network outage, but it *might*. If a record's TTL expires 1 second after the network goes down, the cache will be essentially useless. Having long TTL improves the probability of having still-valid cached records, but it doesn't guarantee it.


As rough ballparks, I might suggest those values for both positive TTL:

- Wired network, redundant DNS servers: 60 to 300 seconds (1 to 5 minutes)

- Wired network, single DNS server: 300 to 600 seconds (5 to 10 minutes)

- Wireless network: 600 to 1200 seconds (10 to 20 minutes)


Negative TTL should be a lot shorter, 60 seconds or less. Missing records will stay missing during network outages, nothing changes. But if your negative TTL is too long, you might bite yourself inadvertently. When a client caches a negative answer for a passwd entry, it effectively locks out that user for the duration of the negative TTL. That can happen by accident, during a network outage or maybe because you forgot to push the records to the DNS server after adding a new user. In those cases you want the negative TTL to be no longer than, say, the time needed to get a coffee and think a bit about how badly you need holidays right now.



Where to cache
~~~~~~~~~~~~~~

Local DNS resolvers:

- can support modern DNS security features (DNSSEC, DoT / DoH, etc), see `Passwords and security concerns with Hesiod <hes_sec.rst>`__;
- may cache raw TXT records, which would still need to be processed later (converted to passwd and group structs);
- usually respect the DNS TTL of the records.

Caching daemons:

- have no notion of resolvers, the Hesiod NSS module uses the system's resolver which by default is the glibc's insecure resolver;
- cache processed passwd and group entries;
- have no notion of DNS TTL but define the caching TTL in their configuration files.


So the best setup uses both: a local resolver for the DNS safety features (which benefits everything, not just Hesiod), and a caching daemon for low-latency passwd and group answers.

If there can be only one for some reason, then the best option is to have a validating, caching local DNS resolver. It will have a slightly higher latency than a caching daemon, but much less than no caching at all, and the validating resolver will benefit the whole system.

**Note:** When using both, and if the DNS resolver is caching, the total Hesiod TTL becomes ``<DNS TTL> + <caching daemon TTL>``. You will need to factor that in, especially as by default caching daemon configurations have multi-hours TTL.




Local DNS resolver
------------------

Many recursive resolvers can run locally on clients for caching purposes. Even BIND can do it (I'll leave that as homework for you, dear reader). For now I'll focus on two common ones: Dnsmasq and Unbound.


Dnsmasq
~~~~~~~

Dnsmasq's primary DNS role is that of a caching recursive resolver. It supports DNSSEC validation, but neither DNS-over-TLS nor DNS-over-HTTPS (neither as a client nor as a server).

**Dnsmasq doesn't cache TXT records.** It should always be used together with a caching daemon.

Dnsmasq generally has a sane default configuration, and is essentially ready-to-run. Note that DNSSEC validation is disabled out-of-the-box and needs to be enabled in the configuration file if wanted.

On clients where the upstream DNS servers can change, you will need some sort of `resolvconf <https://en.wikipedia.org/wiki/Resolvconf>`__ to do the old switcheroo automatically when Dnsmasq starts: make ``/etc/resolv.conf`` point to the local resolver instead of the upstream servers, and the local resolver to the upstream servers. All Linux and \*BSD have a variant or another.

The following options might be useful (see the `manpage <https://thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html>`__ for details)::

    clear-on-reload
    dns-loop-detect

    # Recommended but can break some setups
    stop-dns-rebind
    domain-needed
    bogus-priv

    # Enable DNSSEC
    conf-file=/usr/share/dnsmasq-base/trust-anchors.conf
    dnssec
    dnssec-check-unsigned



Unbound
~~~~~~~

Unbound is a feature-rich validating, caching DNS resolver. It supports pretty much everything under the sun, including DNSSEC and DNS-over-TLS/HTTPS.

Unbound caches TXT records, including Hesiod data. It respects DNS TTL (if it falls within the configurable upper and lower TTL boundaries). DNSSEC validation is enabled by default, and you'll need to mark your Hesiod zone as insecure if your records aren't signed.

At least on Debian Unbound ships with an additional systemd unit called ``unbound-resolvconf``, which does the same job as a normal resolvconf. Otherwise there are configuration examples on the internet to set up different flavours of resolvconf.

Typically, the result will be a configuration snippet including a catch-all forward zone::

    forward-zone:
        name: "."
        forward-addr: <upstream server IPs>


If your Hesiod DNS server is always accessible on the same IP address, you can also define a dedicated forward zone for the domain::

    forward-zone:
        name: "<LHS.RHS>"
        forward-addr: <Hesiod server IP>

Even better, if your server is authoritative for the domain you can set up a stub zone::

    stub-zone:
        name: "<LHS.RHS>"
        stub-host: <Hesiod NS hostname with final dot>
        # or stub-addr: <Hesiod server IP>

Effectively both variants create a split-horizon DNS setup. 

With Unbound you can configure per-zone TLS transport, thus mandating encryption on all traffic between the client and the Hesiod server. Most excellent!

See the ``unbound.conf`` `manpage <https://manpages.ubuntu.com/manpages/focal/en/man5/unbound.conf.5.html>`__ for *many* more options.




Caching daemon
--------------

NSCD
~~~~

NSCD, the Name Server Caching Daemon, is part of the glibc. It can cache user and group information, as well as hosts. NSCD doesn't cache authentication data (such as Kerberos), for that you need `SSSD`_.

It has been around for ages, but it acquired a bad reputation a long time ago that it never really managed to shake off. This `blog entry <https://jameshfisher.com/2018/02/05/dont-use-nscd/>`__ provides a bit more background on the reasons for that reputation (in a nutshell: NSS modules failing ungracefully crash NSCD).

Note that Debian and Ubuntu ship both the standard NSCD, and a rewritten version called `UNSCD <https://busybox.net/~vda/unscd/>`__ that "does not hang" -- or so says the `manpage <https://manpages.ubuntu.com/manpages/focal/en/man1/nscd.1.html>`__. It may be wise to use that one instead of normal NSCD.

I never had any real problem with normal NSCD myself after years of use (on wired networks, with interface bonding and various failover mechanisms -- that might have helped). For that reason, and because the \*NSCD are straightforward to configure and use, they are still worth considering in a new deployment.


Whatever documentation exists is scattered in manpages.

UNSCD:

- `<https://manpages.ubuntu.com/manpages/focal/en/man1/nscd.1.html>`__

NSCD:

- `<https://manpages.ubuntu.com/manpages/focal/en/man8/nscd.8.html>`__
- `<https://manpages.ubuntu.com/manpages/focal/en/man5/nscd.conf.5.html>`__


The databases that NSCD can cache depend on the version and, apparently, the phase of the Moon:

- The RHEL / CentOS 7 `manpage <https://man.linuxtool.net/centos7/u3/man/5_nscd.conf.html>`__ says ``passwd, group, hosts, services or netgroup``;
- The manpage for ``nscd.conf`` in Debian and Ubuntu (link above) says ``passwd, group, or hosts``;
- The NSCD configuration file in Debian says ``Currently supported cache names (services): passwd, group, hosts, services``;
- The NSCD configuration file in Debian includes entries for passwd, group, hosts, services *and netgroups*;
- The UNSCD configuration file includes entries for passw, group and hosts, but mentions that "hosts caching is broken with gethostby* calls, hence is now disabled by default".

The only things that really interest us with Hesiod are passwd and group, which are available in all cases.

Example configuration for UNSCD::

    enable-cache            passwd  yes
    positive-time-to-live   passwd  600
    negative-time-to-live   passwd  30
    suggested-size          passwd  1001
    check-files             passwd  yes

    enable-cache            group   yes
    positive-time-to-live   group   600
    negative-time-to-live   group   30
    suggested-size          group   1001
    check-files             group   yes

    enable-cache            hosts   no

Example configuration for NSCD::

    enable-cache            passwd      yes
    positive-time-to-live   passwd      600
    negative-time-to-live   passwd      30
    suggested-size          passwd      1001
    check-files             passwd      yes
    persistent              passwd      no
    shared                  passwd      yes
    max-db-size             passwd      33554432
    auto-propagate          passwd      yes

    enable-cache            group       yes
    positive-time-to-live   group       600
    negative-time-to-live   group       30
    suggested-size          group       1001
    check-files             group       yes
    persistent              group       no
    shared                  group       yes
    max-db-size             group       33554432
    auto-propagate          group       yes

    enable-cache            hosts       no
    enable-cache            services    no
    enable-cache            netgroup    no

**Note:** In the entries above, ``persistent`` is set to ``no`` (default is ``yes``). This assumes that NSCD doesn't crash (often), and conveniently lets you clear the cache by restarting the service. If you run NSCD in paranoia mode, you will want to set those entries back to ``yes``.

**Note:** NSCD's hosts cache doesn't cache TXT records, so if you enable it you won't have to worry about having an even longer max Hesiod TTL. But if you want host caching, you should really set up a local caching DNS resolver.



SSSD
~~~~

From the `website <https://sssd.io/>`__:

    SSSD is a system daemon. Its primary function is to provide access to local or remote identity and authentication resources through a common framework that can provide caching and offline support to the system. It provides several interfaces, including NSS and PAM modules or a D-Bus interface.

In a nutshell SSSD can be thought of as the successor to NSCD. It offers many more features, but is also much more complex.

SSSD supports a ``proxy`` provider for both identity and authentication, which can load NSS modules and use them to request information. But the Glibc's Hesiod NSS module isn't compatible with SSSD (as of glibc 2.24 and SSSD 1.15). The NSS module doesn't include the calls that don't make sense with Hesiod, for example ``_nss_hesiod_getpwent_r``, used to iterate over all passwd entries (which is not possible with Hesiod). But even when setting ``enumerate = FALSE`` in ``sssd.conf``, SSSD will check for the presence of all NSS functions, and fail if not found.

The error messages in ``/var/log/sssd/sssd_hesiod.log`` are::

[sssd[be[hesiod]]] [proxy_id_load_symbols] (0x0010): Failed to load _nss_hesiod_getpwent_r, error: /lib/x86_64-linux-gnu/libnss_hesiod.so.2: undefined symbol: _nss_hesiod_getpwent_r.
[sssd[be[hesiod]]] [sssm_proxy_id_init] (0x0010): Unable to load NSS symbols [80]: Accessing a corrupted shared library
[sssd[be[hesiod]]] [dp_target_run_constructor] (0x0010): Target [id] constructor failed [80]: Accessing a corrupted shared library
[sssd[be[hesiod]]] [be_process_init] (0x0010): Unable to setup data provider [1432158209]: Internal Error
[sssd[be[hesiod]]] [main] (0x0010): Could not initialize backend [1432158209]

So for now SSSD is not usable as a caching daemon for Hesiod data.

