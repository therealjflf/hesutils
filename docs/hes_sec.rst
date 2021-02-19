
Passwords and security concerns with Hesiod
===========================================

When planning for a Hesiod deployment, a systems architect must be aware of a certain number of potential issues and limitations. Most, if not all of them, can be mitigated by wise design and implementation choices.


They fall broadly into two categories:

- `DNS security concerns`_, for everything related to the underlying protocol;

- and `User authentication`_, for the peculiarities of Hesiod itself.


Note that while we're looking only at Hesiod here, other protocols (such as unsecured LDAP) have very similar issues. This page isn't about demonstrating that Hesiod is more or less secure than alternatives, but rather to help in securing Hesiod deployments.



DNS security concerns
---------------------

Security limitations in the DNS protocol have been known for decades, and there is a large body of work treating with that problem. We won't get into much details here as there is so much information available out there already.

A starting point for readers without any familiarity to the topic could be Cloudflare's introduction to DNS security: `<https://www.cloudflare.com/learning/dns/dns-security/>`__


Record authenticity
~~~~~~~~~~~~~~~~~~~

This is the answer to the questions:

- did my Hesiod answer come from the right server, or from somewhere else?

- has my Hesiod answer been modified between the DNS server and myself?

In other words, we want to be sure that we received an unmodified answer from the right server.


Without this guarantee, an attacker might be able to answer a Hesiod request with forged records, which could compromise system integrity: changed home directories, changed shells (executing an attacker-provided binary at login), changed group memberships, etc. Because of this, record authenticity is absolutely critical for a sane Hesiod deployment.


The DNS answer to this is called the `Domain Name System Security Extensions <https://en.wikipedia.org/wiki/Domain_Name_System_Security_Extensions>`__, or DNSSEC. With DNSSEC the records of a zone are signed with a private key, which allows the resolver to check whether the records have been tampered with.


On-wire data confidentiality
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

This is the answer to the question:

- has anyone been able to observe either my Hesiod request, or its answer?


Using DNSSEC, forged Hesiod answers would be rejected by the client's resolver. But as long as the requests and answers are transmitted in clear on the wire, a spy would be able to monitor them and obtain valuable information about the current state of the systems: who is logged in where, what are the group memberships, etc. This in turn could be useful to time attacks (when some specific people are not logged in, for example), or to obtain corporate information that could be used for phishing attacks. So while you may be able to get away with confidentiality in small deployments, it is necessary in larger, more critical ones.


The answer to this problem is to encrypt the Hesiod requests and answers between the client and the server. The two main techniques are `DNS-over-TLS <https://en.wikipedia.org/wiki/DNS_over_TLS>`__ and `DNS-over-HTTPS <https://en.wikipedia.org/wiki/DNS_over_HTTPS>`_.



User authentication
-------------------

Once we have the guarantee that we received unmodified records from the DNS servers, we can look at the next step: how do we authenticate users on client systems?

When a user logs in, the system performs two separate tasks:

- user authorization (who are you?);

- and user authentication (how can you prove that you are who you say you are?).

Most often this comes under the guise of a login name and a password.


There are other elements to user authorization, such as group memberships, home directory, shell, etc. All of those are provided in Hesiod records, so the first part, authorization, is taken care of. But what about authentication?


Password logins
~~~~~~~~~~~~~~~

The traditional computer authentication method is the password. When this was introduced to UNIX, graybeards were roaming freely in the glow of blinkenlights and suspenders answered the call of clacking teletype consoles. Life was simple. Passwords were hashed, and the resulting jumble was inserted in the second field of an ``/etc/passwd`` entry.

As it turned out, this didn't cut it. Increasing computing power made it easy to brute-force the hashes. Then the hashes were salted and computed with cryptographically-secure hash functions, to make things a bit more complicated. And finally the hashes were moved out of the ``/etc/passwd`` file, into ``/etc/shadow`` with reduced permissions.

With the original setup, the password hash would be transmitted via Hesiod with the rest of the ``passwd`` entry. That made *everybody's* hashes visible to an attacker sniffing the wire, which was immediately understood to be a major security weakness. So the good people at MIT's Project Athena came up with another tool to deal with authentication: `Kerberos <https://en.wikipedia.org/wiki/Kerberos_(protocol)>`_.


Today passwords are no longer present in ``/etc/password``. Moreover, passwords are no longer the only form of authentication. `Multi-factor authentication <https://en.wikipedia.org/wiki/Multi-factor_authentication>`_ is becoming a requirement in many larger sites, and hardware security dongles are fairly common. Hesiod has absolutely no way of representing such authentication mechanisms right now. We need something else. And while it has its defaults, Kerberos is one of the possible solutions (albeit not -- yet? -- for MFA).

As for the Hesutils, ``hesgen``  won't even try to insert the password hashes back into the ``passwd`` records -- in fact it will *always* overwrite the second field with ``*``, telling the client systems that password logins for that user are disabled and they should authenticate using a different method. So you need another authentication mechanism.

The bottom line is: kerberize.


SSH key logins
~~~~~~~~~~~~~~

If the client nodes are not interactive (like most compute clusters, or an army of IoT devices), it might be tempting to want to skip the whole password headache. The obvious shortcut there would be to mount the user homes over a network filesystem, let's say NFS, and have SSH key pairs in each user's home to do password-less, key-based SSH logging on client nodes. That's the easiest Hesiod setup.


That *sounds* nice, but let's go through the various steps of that procedure:

#. the user logs into a central control node;

#. the user starts an SSH connection to the remote node;

#. SSH transfers the user's public key to the remote node over an encrypted channel;

#. the SSH server on the remote node reads the user's private key in the user's (NFS) home to validate the public key it just received;

#. **the private key is transferred in clear** from the NFS server to the remote node.


The last step obliterates the security of that setup. Even sending password hashes is more secure than sending private keys in clear!

A possible answer to that last step is to encrypt all filesystem transfers. NFS can do that if you really want to, but if you're going that way why not invest that time and effort in a Kerberos setup instead?


There are a few situations where that simple setup can still be a valid solution:

- you don't care about security at all;

- all remote filesystem transfers are encrypted already, so there's not additional cost;

- or you're setting up Hesiod in a highly restricted network environment without any promiscuous interface, or vlans all over the place, etc etc -- so hopefully no chance of sniffing around.

Points one and three might be valid for a small VM setup on a single host, for example.
