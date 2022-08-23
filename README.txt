                                  Description

   vpnmgr is a tool for remotely operating an OpenVPN server to access
   multiple VLANs on a single interface. It can handle multiple banks of
   VLANs, one on each interface. Connectivity authorization is delegated to a
   Certificate Authorirty (CA) on a per-VPN basis. Management authorization
   can be controlled at VLAN, bank or server level, through SSH keys. vpnmgr
   can be made aware of port-forwarding relationships so it can be placed
   behind a firewall.

   The software is made available under a 3-clause BSD licence.

   Currently, all VPNs must be Layer-2/TAP-based, with each VPN client
   occupying one address of a pool designated for VPN clients. Certificate
   Revocation Lists (CRLs) are supported.

                                    Example

   Suppose you have a machine with three physical interfaces. eth0 is the
   management interface, which grants you SSH access. eth1 connects to a
   private network hosting distinct VLANs — perhaps one managed by OpenStack.
   eth2 is an interface reachable by the Internet in general (but we'll use
   an impossible 257.4.25.8 here). You want authenticated users to connect
   with OpenVPN via eth2 ports 10000 to 10099, and find themselves on VLANs
   on eth1. You can provide these details to vpnmgr as static configuration:

 SERVERNAME[default]=257.4.25.8
 IFACE[default]=eth1
 PORTRANGES[default]=10000-10099

   Now, suppose that VLAN 43 on eth1 has just been defined to have the subnet
   10.11.12/24, and .10 to .40 have been allocated for VPN clients. Users
   with certificates from a given CA are permitted to access this VLAN using
   this address pool, and you have been given a CA certificate ca.crt from
   that CA to authenticate them.

   From a host that can SSH into the management interface, you can run:

 vpnmgr create --vlan=43 --ca=ca.crt \
               --network=10.11.12.10-10.11.12.40/24 \
               --enable

   This creates a new VPN to access VLAN 43, to grant access to certificates
   from the CA, and to assign clients to the designated address pool. You can
   now get a partial OpenVPN configuration client-config.ovpn with:

 vpnmgr config --vlan=43 --ovpn=client-config.ovpn

   You supply this configuration to potential users, who combine it with
   their credentials (such as a PKCS#12 file) from the CA to form a complete
   configuration:

 sudo openvpn --config client-config.ovpn \
              --pkcs12 my-creds.p12

   You can temporarily disable a VPN with:

 vpnmgr update --vlan=43 --disable

   Or change the CRL with:

 vpnmgr update --vlan=43 --crl=new-file.crl

   Check the status:

 vpnmgr status --vlan=43

   Destroy the VPN:

 vpnmgr destroy --vlan=43

   List existing VPNs:

 vpnmgr list

                                  Installation

Preparation

   Make sure you know how to set up key-based authentication over SSH. Also
   familiarize yourself with public key infrastructures (PKIs). easyrsa 3 is
   a self-contained package for managing a PKI, i.e., generating private
   keys, certificate-signing requests, certificates, and
   certificate-authority (CA) certificates.

   Also, we assume you have SSH access to an account on the server host, and
   can execute sudo within it. We'll call the server host server, and your
   sudo-capable account on it me. These specific instructions assume that
   your SSH public key is present on a line in ~me/.ssh/authorized_keys or
   ~me/.ssh/authorized_keys2 (allowing you key-based access to that account),
   and identified with the trailing comment bloggs@localhost.

   Any host you use as a management client we'll call client, and your
   account on it me. sudo access is convenient (and assumed for these
   instructions on installation), but not necessary after installation.

Software

   You need OpenVPN installed on the server, of course:

 sudo apt-get install openvpn

   To install vpnmgr on the server or management client, you need some
   compilation tools:

 sudo apt-get install build-essential par

   You also need Binodeps:

 git clone https://github.com/simpsonst/binodeps.git /tmp/binodeps
 cd /tmp/binodeps
 make
 sudo make install

   Install vpnmgr on server or client with:

 git clone https://github.com/simpsonst/vpnmgr.git
 cd vpnmgr
 cat <<EOF
 PREFIX=/usr/local
 CFLAGS += -O2 -g    
 CFLAGS += -std=gnu11
 CPPFLAGS += -D_XOPEN_SOURCE=600
 CPPFLAGS += -D_GNU_SOURCE=1
 CPPFLAGS += -pedantic -Wall -W -Wno-unused-parameter
 CPPFLAGS += -Wno-missing-field-initializers
 CXXFLAGS += -O2 -g
 CXXFLAGS += -std=gnu++11
 EOF
 make
 sudo make install

Server configuration

   On the server host, you must create a context for server state in the form
   of a separate account, whose name is vpns by default. This account must
   not be me, or you will lock yourself out of the host! As a precaution,
   open a separate terminal to SSH into me@server, and get a root prompt:

 sudo -i

   This ensures that, if the next step goes wrong, you still have a way to
   clean up the mess.

   The following command creates the server context:

 sudo /usr/local/share/vpnmgr/installation vpnmgr.pub -m bloggs@localhost

   It creates the account vpns if it doesn't exist, and limits SSH access to
   it to only keys from the sudo-capable account with a comment matching
   bloggs@localhost. You can also specify a wildcard, e.g., -m bloggs\*, and
   override the account name with -u name.

   Now check that you can still use me@server by opening a third SSH
   terminal, and executing:

 sudo echo yes

   If you can still sudo, you're okay. If not, use your earlier root shell to
   fix the problem. (installation writes a file into /etc/sudoers.d/ so that
   the vpns account can perform some limited privileged operations. This is
   likely to be the source of any sudo-related problems.)

   Static configuration goes in /etc/vpnmgr.sh by default, and is sourced by
   Bash upon each management operation. This defines the (private) interfaces
   that physically attach to the VLAN-carrying networks, and the (public)
   interfaces that OpenVPN clients connect through. Each mapping between a
   public and private network is called a bank, and the default settings
   assume a bank called default.

   At a bare minimum, you need to specify the private interface and the UDP
   ports of the public interface that a bank will use. The defaults for the
   default bank are:

 IFACE[default]=eth1
 PORTRANGES[default]=12000-12100
 VLANS[default]=1-4095
 SERVERNAME[default]="$HOSTNAME"
 INTERNALNAME[default]="${SERVERNAME[default]}"

   Set IFACE to the private interface. Set SERVERNAME to the IP address or
   DNS name of the public interface. Set PORTRANGES to the pool of UDP ports
   that OpenVPN will listen on for clients. Set VLANS to narrow down the
   range of VLAN ids supported. IFACE and PORTRANGES are required to define a
   bank other than default. VLANS and PORTRANGES can be comma-separated
   ranges, e.g., 100-200,556,1000-1200.

   The OpenVPN servers that vpnmgr sets up need Diffie Hellman parameters, a
   private key and an identifying certificate installed on the server to
   operate. vpnmgr also needs the CA certificate of the CA that signs the
   server's certificate (used only to build OpenVPN client configuration
   files). Each bank may have separate settings for these, though they all
   default to what the default bank uses:

 DHFILE[default]=/etc/openvpn/dh1024.pem
 SERVERCERT[default]=/etc/openvpn/server.crt
 SERVERKEY[default]=/etc/openvpn/server.key
 CACERT[default]=/etc/openvpn/ca.crt

   The OpenVPN docs say to do the following to create the DH parameters:

 openssl dhparam -out dh2048.pem 2048

   Consult OpenSSL docs about creating a private key (server.key, with access
   mode 0600) and an associated certificate-signing request from it (usually
   with a .csr suffix). The .csr file should be sent securely to a CA for
   signing, yielding a certificate that can be used as server.crt. The CA
   should also be able to provide its CA-certificate, to be used as ca.crt. I
   will try and summarize the steps here at some point.

   You'll need to generate a key pair once:

 openssl genrsa -nodes -out server.key 2048

   server.key holds the private key, and so it should be held securely on the
   server. The public key can be derived from the same file. You should only
   need to repeat this step if you think your private key has been
   compromised (i.e., someone has got it).

   Generate a certificate signing request (CSR) from the public key:

 openssl req -new -key server.key -out server.csr

   You'll be asked to fill in various fields describing your organization
   that will appear in the final certificate. The common name is usually the
   most important one, as it is typically the one that is checked by the
   client to confirm who it is talking to. The certificate will also contain
   the public key, affirming that the key pair belongs to the entity
   described by these fields.

   Securely send your CSR to the CA for signing as a server, and they will
   send back the certificate, server.crt, which does not need to be held
   securely. Also get the CA's certificate, ca.crt.

   easyrsa 3 can be used to create a Certificate Authority.

   Internally, when VPNs are created, vpnmgr creates a number of software
   bridges and interfaces within the server. Their names in the default bank
   are prefixed with vlanbr, vlan and vlantap. For other banks, the default
   replaces vlan with the bank name. However, as these names are tightly
   limited in length, you might want to override them. For example:

 BRIFACE[extra]=exbr
 VLIFACE[extra]=ex
 TAPIFACE[extra]=extap

   When a client calls, the server process displays a greeting, including the
   hostname. To override the hostname displayed, set SERVERTITLE:

 SERVERTITLE="Example Corp."

Management client configuration

   On me@client, automate invocation of the server agent over SSH. Add an
   entry to ~/.ssh/config to contain the following:

 Host vpns
 User vpns
 Hostname me@server
 ForwardX11 no

   Run a test with:

 vpnmgr test

   (In the first instance, this might prompt you to accept the public key of
   the SSH server.)

Port-forwarding UDP ranges

   If VPN access to the server is through a firewall with port forwarding,
   set SERVERNAME to the public address of the firewall, and INTERNALNAME to
   the IP/DNS name of the interface on server that the firewall forwards to.
   If the internal and external UDP port differ, specify the external ports
   in PORTRANGES, and attach the mapping to the internal range.

   For example, suppose the external interface of the firewall is eth1, with
   DNS name vpns.example.org and IP 257.4.25.8, and its UDP ports 12000-12100
   are mapped to 15000-15100 on 10.20.30.40. These would be among vpnmgr's
   static configuration:

 PORTRANGES[default]=12000-12100:15000
 INTERNALNAME[default]=10.20.30.40
 SERVERNAME[default]=vpns.example.org

   Port-forwarding ranges seems a little tricky. If your internal and
   external ports are the same, you should be able to do something like this:

 sudo iptables -A PREROUTING -t nat -i eth1 \
               -p udp -d 257.4.25.8 --dport 12000:12100 \
               -j DNAT --to-destination 10.20.30.40
 sudo iptables -A POSTROUTING -t nat -o eth1 \
               -p udp -d 257.4.25.8 --sport 12000:12100 \
               -j SNAT --to-source 10.20.30.40

   If the internal and external ranges are not the same, I found that this
   didn't work as expected:

 sudo iptables -t nat -A PREROUTING -i eth1 \
               -p udp -d 257.4.25.8 --dport 12000:12100 \
               -j DNAT --to-destination 10.20.30.40:15000-15100
 sudo iptables -t nat -A POSTROUTING -o eth1 \
               -p udp -d 257.4.25.8 --sport 15000:15100 \
               -j SNAT --to-source 10.20.30.40:12000-12100

   Anything coming in on 12000-12100 was mapped to 15000. I was forced to
   write a pair of rules for each port. Surely there's a way…?

   You might also have to open the internal ports if you have a broadly
   restrictive firewall:

 sudo iptables -A FORWARD \
               -p udp -d 10.20.30.40 --dport 15000:15100 \
               -j ACCEPT
 sudo iptables -A FORWARD \
               -p udp -s 10.20.30.40 --sport 15000:15100 \
               -j ACCEPT

   If the firewall can't be used as the server's default gateway, you need to
   direct packets on the server based on source port. One way to do that is
   to use an auxiliary routing table that uses the firewall as the default
   gateway, direct marked packets to the auxiliary table, and get IPTables to
   mark the appropriate packets. You can optionally create an alias for the
   auxiliary table's number (200, let's say) in /etc/iproute2/rt_tables:

 200 fw-route

   (This alias is used in the next two commands.)

   Set the firewall (10.20.30.55, say) as the default gateway:

 sudo ip route add 0/0 via 10.20.30.55 table fw-route

   Make marked packets use the auxiliary table (picking 4 out of a hat as the
   mark):

 sudo ip rule add prio 100 from all fwmark 4 table fw-route

   Finally, mark the OpenVPN traffic (the internal interface, IP and port
   range) so that it uses the auxiliary table:

 sudo iptables -t mangle -A OUTPUT -o eth2 -p udp -s 10.20.30.40 --sport 15000:15100 -j MARK --set-mark 4

                           Command-line documentation

   The vpnmgr command is followed by a subcommand, then several options. All
   options are permitted on all commands, but are ignored where redundant.

   --server=ssh-host-id

   -s ssh-host-id

           Specify which server to contact.

           ssh-host-id may be any valid hostname, or an entry in your
           ~/.ssh/config file. The default is vpns.

   -i ssh-key-file

           Specify the SSH identify file to use when contacting the server.
           By default, identity is left to your SSH client.

   --bank=bank

   -b bank

           Specify the VPN bank to operate on. The default is default.

   --no-bank

   +b

           Specify that the server is to be operated on as a whole, rather
           than a specific bank. This is required when configuring
           authorization for the server.

   --vlan=vlan-id-set

   -v vlan-id-set

           Specify which VLAN to operate on.

           Ranges such as 1-40,50,60-70 can be specified in some cases,
           implying that one VLAN may be chosen arbitrarily from the set. The
           default is not to operate on a specific VLAN set.

   --port=port-set

   -p port-set

           Specify which UDP ports to use when creating a VPN.

           Ranges such as 1-40,50,60-70 can be specified, implying that one
           port may be chosen arbitrarily from the set. The default is to use
           any available port.

   --network=start-end/masklen

   -n start-end/masklen

   --no-network

           Specify the IP range for clients.

           start is the first IP address, and end is the last. The netmask is
           derived from masklen. The network prefix is derived by applying
           the netmask to start and end, which must yield the same result.
           For example: 10.11.12.10-10.11.12.40/24. The default is not to set
           the IP range.

   --ca=ca-cert-file

   --no-ca

           Specify the CA certificate that will authenticate clients.

           The file must be in PEM format. The default is not to set the CA
           certificate.

   --authz=authz-file

   --no-authz

           Specify the authorization file in YAML. This is used to impose
           additional requirements on client certificates, beyond being
           signed by the CA.

           A simple condition has the fields key (which identifies a field of
           the subject DN of the certificate) and value (which specifies an
           exact value to match). A node whose key is and must have an array
           of conditions to match, and all must be true, or the result is
           false. A node whose key is or must have an array of conditions to
           match, and all must be false, or the result is true. An example:

 and:
 - key: C
   value: "GB"
 - key: ST
   value: "Doncashire"
 - key: L
   value: "Doncaster"
 - or:
   - key: CN
     value: bloggsj
   - key: CN
     value: fruity

           For the config command, this specifies where locally to write the
           current authorization fetched from the server.

   --crl=crl-file

   --no-crl

           Specify the certificate revocation list (CRL).

           The file must be in PEM format. The default is not to set the CRL.

   --dns=dns-servers

   --no-dns

           Push DNS servers to OpenVPN clients, or stop pushing DNS servers.
           dns-servers must be a comma-separated list of IP addresses.

   --domain=domain-name

   --no-domain

           Push a DNS search domain to OpenVPN clients, or stop pushing.

   --gateway=gateway-ip

   --no-gateway

   --metric=integer

   --no-metric

   --route=subnet

           Modify the routing table pushed to OpenVPN clients. --gateway sets
           the gateway for subsequent --route options, causing the route to
           be added or its gateway changed. --no-gateway causes subsequent
           --route options to remove routes. --metric sets the metric for
           subsequent --route options, causing the metric to be set on new or
           modified routes. --no-metric prevents setting of the metric for
           subsequent --route options.

   --enable

   --disable

           Enable or disable the VPN.

           The default is not to change the VPN's status.

   --ovpn=ovpn-file

           Specify where to write an OpenVPN configuration file.

   --match=pattern

   -m pattern

           Add a pattern to match against comments in SSH authorization file.

           The files ~/.ssh/authorized_keys and ~/.ssh/authorized_keys2 are
           scanned. The comment is everything after the Base-64 key itself.

           This option can be used multiple times cumulatively.

   --public=ssh-pubkey

   -P ssh-pubkey

           Add SSH public keys in ssh-pubkey.

           This option can be used multiple times cumulatively.

   All SSH public keys identified by --match and --public options are used in
   the authorization commands admin, manage, read and forbid.

Management authorization

   Authorization is applied for each user independently at three levels:

     * server
     * bank: a specific bank within the server
     * VPN: a specific VLAN within a bank

   Four ranks of authorization exist:

     * admin: The user can do anything, including altering the authorization
       of others.
     * manage: The user can do anything, except altering authorization,
       unless in a contained lower level.
     * read: The user can read settings.
     * forbid: The user can do nothing.

   A given user may have, say, admin rank within a bank, but manage rank
   within a VPN of a different bank. VPN creation and deletion require manage
   rank within a bank. VPN update requires only manage rank within that VPN.

   The following subcommands set the management authorization of the
   identified users:

   admin --no-bank --bank --vlan --match --public

   manage --no-bank --bank --vlan --match --public

   read --no-bank --bank --vlan --match --public

   forbid --no-bank --bank --vlan --match --public

           Grant identified users the rank admin, manage, read, or forbid on
           the specified VPN, bank or server.

           The admin rank is required on the specified VPN, bank or server,
           or manage on the containing entity. It should be impossible to
           remove your own admin rank, unless implied at a higher containing
           level.

Creation, update and deletion of VPNs

   create --bank --vlan --port --network --ca --authz --crl --enable

           Create a new VPN.

           A port and VLAN id will be chosen from the union of those
           specified by the bank and those on the command line. The new VPN
           will be disabled by default.

           The manage rank for the specified bank is required.

   config --bank --vlan --authz

           Fetch the certificate authorization file.

   update --bank --vlan --network --ca --authz --crl --enable --disable

           Update an existing VPN.

           A single VLAN must be specified. Only when a VPN has the
           --network, --ca and --enable settings will it be activated. If
           --network, --ca are modified on an active VPN, it is restarted.

           The manage rank for the specified VPN is required.

   destroy --bank --vlan

           Destroy a VPN.

           A single VLAN must be specified.

           The manage rank for the specified bank is required.

VPN status

   list --bank --vlan

           List existing VPNs in the specified bank.

           The list is limited to the selected VLANs. Each line of output has
           the following form: 301 12046 ACTIVE That's the VLAN id, the UDP
           port, and ACTIVE or INACTIVE.

   status --bank --vlan

           Get the service status of a VPN.

           The command systemctl status is run on the VPN subservice, and its
           output returned.

           The manage rank for the specified bank is required.

   clients --bank --vlan

           Get the OpenVPN status of a VPN, which looks something like this:

 TITLE,OpenVPN 2.4.4 x86_64-pc-linux-gnu SSL (OpenSSL) LZO LZ4 EPOLL PKCS11 MH/PKTINFO AEAD built on May 14 2019
 TIME,Mon Feb 17 23:05:00 2020,1581980700
 HEADER,CLIENT_LIST,Common Name,Real Address,Virtual Address,Virtual IPv6 Address,Bytes Received,Bytes Sent,Connected Since,Connected Since (time_t),Username,Client ID,Peer ID
 HEADER,ROUTING_TABLE,Virtual Address,Common Name,Real Address,Last Ref,Last Ref (time_t)
 GLOBAL_STATS,Max bcast/mcast queue length,0
 END

           (This is format specified by the --status-version 2 option in the
           OpenVPN documentation.)

           The manage rank for the specified bank is required.

Generating client configuration

   config --bank --vlan --ovpn

           Generate an OpenVPN configuration file.

   For example, to generate VLAN 103's configuration, run:

 vpnmgr config --vlan=103 --ovpn=client-config.ovpn

   …and send the generated file client-config.ovpn to each VPN client.

   Any VPN client host will obviously need OpenVPN installed. On Ubuntu,
   that's just:

 sudo apt install openpvn

   The client is authenticated by providing a private key and a cerificate of
   its public key signed by the CA that the VPN has been configured to use
   with the --ca switch on vpnmgr create or vpnmgr update. The key and
   certificate can be provided separately to openvpn:

 sudo openvpn --config client-config.ovpn \
              --key me.pem --cert me.crt

   They also might have been packaged together in a PKCS#12 file:

 sudo openvpn --config client-config.ovpn \
              --pkcs12 me.p12

   If you want to obey DNS DHCP options specified by the server (using --dns
   and --domain), you might need extra options that depend on the client OS.
   For systems using systemd, these would be:

 script-security 2
 up /etc/openvpn/update-systemd-resolved
 down /etc/openvpn/update-systemd-resolved
 down-pre

   If you keep those in a file, say, systemd.ovpn, you can merge them with
   the server-supplied configuration and your credentials:

 sudo openvpn --config client-config.ovpn \
              --pkcs12 me.p12 \
              --config systemd.ovpn
