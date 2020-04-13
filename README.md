
# doc: carpentry

This document covers the carpentry project. 'carpentry' is a way of managing CARP gateways that must run local services due to network environment limitations. This fills in the role of a configuration management system for a pair of carp gateways. Some of the services that must be hosted on the carp gateways, are not mature enough to deal with this specific environment. To make-up for these limitations, this project leverages the base system and entr(8) to increase the quality of management. 

Part of the project is useful to regular CARP environments. For example, see:
- pf.conf synchronization
- in-memory and file-persisted pf table synchronization
- state monitoring with ifstated
- state monitoring with monit
- checklist for setting up CARP

## design

### carp gateways

- two carp gateways configured for failover. One is primary and other is secondary
- unidirectional synchronizations. Always from primary to secondary. Synchronizations:
  - unbound configuration
  - dhcpd configuration
  - pf.conf and respective tables
  - in-memory pf tables
  - vpn servers and clients
  - anything else that you may want to add
- services:
  - internal DNS via unbound
  - client OpenVPN
  - server OpenVPN
  - ntpd
  - dhcpd
  - email relay for backup carp gateway
- monitoring via monit

### pf tables

There are a few kinds of pf tables and each require different handling:
- in-memory tables
  - const: cannot be changed, thus cannot be synchronized unless it in pf.conf (persist or not)
  - non-const: can be synced with script
- file-persisted tables in pf.conf
  - watched with a different process in /etc/rc.d/carpentry, and managed with the same script as pf.conf
- tables in pf.conf
  - monitored with pf.conf script and in-memory tables script

### pitfalls

- this does not scale to more carp gateways, it is about increasing the quality of service and management for two-gateways environments
- when monitoring directories (e.g. /etc/openvpn) for changes with entr, only file changes will trigger the respective script execution. This does not include: adding new files to any of the monitored directories
  - also a problem with unbound
- naming pitfall, because the same vlanid may be on multiple interfaces, but with different addressing
- the secondary may:
  - fill up the logs partition really quickly, because it does not have access to the internet and some things fail. Watch the size of partitions after configuring openvpn
  - keep thousands of emails in queue. Monitor with monit
  - fail to deliver mail
- this setup is very tailored and when you need to change low-level configurations like management address ranges in use by the carp gateways, might as well read the checklist from the start
- getting email out of the system is easy if you allow relaying from the secondary. However, when the secondary becomes carp master, you will still want to get email out of the system, but your configuration may not work
- resynchronization the configuration after the primary has been down for some time can be a pitfall, because configurations need to be manually migrated to primary again
- see the comment near 'return block log' in pf.conf'  about having to add rules in multiple interfaces, because of the default policy

### dynamically-loaded configuration via ifstated

There are three components that have dynamically-loaded configuration via ifstated depending on carp state:
- /etc/resolv.conf
- /etc/mail/smtpd.conf
- /etc/ntpd.conf

### when to restart carpentry

Restart carpentry after adding files that should be watched:
  - adding files listed in /etc/rc.d/carpentry
  - adding files to already monitored directories. Note that some on some occasions this is not required. For example, easy-rsa scripts usually make changes to the watched easy-rsa/pki/indext.txt file


## sample switching and connections

192.168.0.100

### vlans and networks

100 - 192.168.100.0/24
110 - 192.168.110.0/24
120 - 192.168.120.0/24
130 - 192.168.130.0/24
999 - 192.168.0.0/24

### ports

- 4 and 5: trunk for vlan100, vlan120, vlan130
- 6 and 7: trunk for vlan999 untagged and pfsync/management on vlan110
- 8: vlan999 uplink

### carps

192.168.0.103   # wan
192.168.100.103 # lan
192.168.120.103 
192.168.130.103 

### primary

192.168.0.101   # wan
192.168.100.101 # lan1
192.168.110.101 # management
192.168.120.101 # users
192.168.130.101 # users 2

- uplink trunk: re0
- downlink trunk: em0

### secondary

192.168.0.102   # wan
192.168.100.102 # lan1
192.168.110.102 # management
192.168.120.102 # users
192.168.130.102 # users 2

- uplink trunk: em0
- downlink trunk: em1


## procedure pre-carp

- install
- create vlans on the switch and configure ports according to trunk plans
- two interface on each host
  - uplink
  - links to internal network
  - management vlan or interface over which primary can contact secondary
- ~/.ssh
- sysctl.conf
- cat /etc/sysctl.conf | grep -Eo "^[^#]+" |tr ' ' '\n' |xargs -I % sysctl %
- pkg_add entr openvpn nmap easy-rsa mtr monit
- fw_update
- syspatch
- reboot
- test ping on internal interfaces
- email configuration # both
  - aliases
  - internet relay
  - email test # both
    - mail -r 'SOURCE-ADDRESS' -s 'subject' 4fxtbpdwjlb6@gmail.com
- syslog config # primary
  - touch /var/log/carpentry.log # primary
  - rcctl restart syslogd # primary
- ssh # secondary
  - ssh-keygen -C gwprimary # primary
  - allow ssh as root in a conditional Match block, Otherwise, do not allow ssh root login # secondary
```
PermitRootLogin no

Match Address 192.168.110.101
  PermitRootLogin without-password
```
- rcctl reload sshd # secondary
- authorized_keys # secondary
- initial ssh connection from primary to secondary. Use the same hostname that will be used in carpentry config
- /etc/carpentry # primary: configure
  - mail
  - destination host
  - pf tables to synchronize
- /etc/carpentry.bin # primary
  - copy scripts
  - chmod -R 700 /etc/carpentry.bin
- /etc/rc.d/carpentry # primary
  - chmod u+x 
  - enable and disable features by removing comments
- /etc/pf.if
  - chmod 600
  - adapt to primary and secondary if interface naming differs. Otherwise, try to keep same name and function per interface to avoid complexity
  - tun interfaces
- /etc/pf.conf # initial configuration without carpentry
  - cp /etc/pf.conf /etc/pf.conf.previous
  - configure pf.conf as per template
  - pfctl -nf /etc/pf.conf
  - echo `"$(whereis pfctl) -f /etc/pf.conf.previous" | at + 2 minutes`
  - pfctl -f /etc/pf.conf
  - test ssh to gw1
    - if failed: wait until the old rules are loaded. After that, retry to edit pf.conf and repeat
    - if success: atrm -a
- motd
  - add the following to /etc/motd: WANRING: this is a carpentry firewall pair

## setting up the carps and synchronizations

- carp wan interfaces # primary
  - route default del # the upcoming netstart will replace it
  - sh /etc/netstart carp0
  - test ssh to carp address
  - remove address from physical wan_if so that only the carp address is usable
    - addd 'up' to the file
    - this is required for example for openvpn, because otherwise the service will reply from the physical address instead of the carp address and the vpn service will not function
  - ifconfig re0 192.168.0.101 delete
  - route 192.168.0.101 del
  - sh /etc/netstart 
  - sh /etc/netstart tunX
- configure openvpn # primary
  - test vpn from the wan side to the carp interface
  - chmod 755 /etc/openvpn # this is required because we will be using scp with the root user to move the configuration to the secondary. This implies that `_openvpn` needs access and ownerships are not kept when using scp
  - add the openvpn directory to the openvpn line in /etc/rc.d/carpentry, so that that the output of the find command is piped intro entr including all directories that should trigger a synchronization.
- check that email generated from the carp gateways is being received
- add "# managed by carpentry" at the top files that are being managed
  - /etc/openvpn/<server>.conf
  - pf.conf
  - unbound.conf zones
  - dhcpd.conf
- add /etc/hostname.pfsync0 # both
  - sh /etc/netstart.pfsync0
  - connect to the vpn on the carp gateways to generate sample traffic
  - on the secondary that should not be receiving traffic from wan_if do `pfctl -ss`. The output should include states about the VPN port that the secondary is not directly seeing
- carp wan interfaces # secondary
  - copy from primary and change:
    - advskew to 250
    - carpdev 'parent' interface if needed
  - route del default # the upcoming netstart will replace it
  - sh /etc/netstart carp0
  - the previous address is no longer usable, so adjust your access to use some type of ssh jump
  - remove address from physical wan_if so that only the carp address is usable
    - addd 'up' to the file
    - this is required for example for openvpn, because otherwise the service will reply from the physical address instead of the carp address and the vpn service will not function
  - ifconfig re0 192.168.0.101 delete
  - route del 192.168.0.102 
  - sh /etc/netstart 
- fix SSH design issue on the secondary. Because of carp, if a gateway changes we will be prompted for the SSH key of another gateway when accessing the usual carp address. This means that we will get an inconvenient error
  - WARNING: might lose connectivity during the next command due to rekeying, ...
  - find /etc/ssh -type f | grep -v config | xargs -I % scp -pr % root@192.168.110.102:/etc/ssh # primary
  - rcctl restart sshd # secondary
  - clear /root/.ssh/known_hosts # primary
  - clear ~/.ssh/known_hosts # your computer
- add carp for user vlan120
  - create /etc/hostname.vlan120 initially with each hosting having an address in the vlan without carp
  - sh /etc/netstart vlan120
  - ping remote
  - ifconfig vlan120 down
  - /etc/hostname.carp120
  - sh /etc/netstart vlan120
  - sh /etc/netstart carp120
  - check carp state
  - add interfaces to pf.if and pf.conf
  - add rules to pf.conf
  - reload pf
- dhcpd
  - configure dhcpd # primary
    - add configuration pertaining to vlan120
    - rcctl enable dhcpd
    - rcctl set dhcpd flags -Y 192.168.110.102 -y 192.168.110.101
    - rcctl start dhcpd
  - configure dhcpd # secondary
    - rcctl enable dhcpd
    - rcctl set dhcpd flags -y 192.168.110.102 -Y 192.168.110.101
    - rcctl start dhcpd
  - ksh -x /etc/carpentry.bin/dhcp..
- adding a client vpn: the available carp gateway will connect to the remote vpn
  - mkdir /etc/openv-client-<CLIENT>
  - /etc/hostname.tunX
  - add /etc/openv-client-<CLIENT> to the /etc/rc.d/carpenty openvpn-related line
  - rcctl restart carpentry
- pf tables
  - cron update tables by DNS # primary
    - `0 * * * * /root/bin/pf-tables-update.sh 1>/dev/null 2>/dev/null`
  - cron # primary
    - `*/15 * * * * /bin/ksh /etc/carpentry.bin/pf-tables-memory.sh`
  - file-persisted tables
    - mkdir /etc/pf.tables # both
    - chmod 700 /etc/pf.tables # both
    - ideally create files <TABLENAME>.txt # primary
- mail: we need to keep two valid configurations on each gateway, for states master and backup
  - primary
    - configure simple relay local email to remote host 
    - aliases and newaliases 
    - test send email: mail -r 4fXTbpDwJLb6@gmail.com -s ok 4fXTbpDwJLb6@gmail.com # primary
    - create exclusion in order for secondary to able to send email
    - cp smtpd.conf smtpd.conf.carp-master 
    - adapt the smtpd.conf.carp-backup configuration created in the following section and copy it to primary
  - secondary
    - configure relay to primary
    - aliases and newaliases 
    - cp smtpd.conf smtpd.conf.carp-backup
    - adapt the smtpd.conf.carp-master configuration created in the previous section and copy it to secondary
  - copy the ifstated.conf configuration template # both
    - change source and destination address # both
    - ifstated -n # both
    - rcctl enable ifstated # both
    - rcctl start ifstated # both
  - force carp demotion like in the upgrade documentation
    - tail -f /var/log/maillog
    - confirm that service restarted with carp state change
    - confirm mailq empty with carp state change
- ntp for secondary
  - much like mail we need two types of configurations that will be switched around with ifstated
  - configure primary to serve ntp on pfsync's interface address # primary
  - test carp master can get time from the internet (using constraints) or lan host (probably without constraints)
    - ntpdctl -sa # should show 'clock synced' after around 3 minutes
    - usually, need a table populated with addresses from the constraints remote server
    - watchout for blocks on port 123/udp or 443/tcp
    - rdate -pv 192.168.110.101 # secondary
- unbound synchronization: the /etc/carpentry.bin/unbound.sh script a.k.a. dnsentry
  - ref: merged from the dnsentry project
  - check dnsentry documentation for setup # currently unavailable to the
  - configure unbound # primary
    - make sure access is blocked from the outside and any other interfaces at pf.conf, since we will not be using unbound access-control by default and will be listening on all addresses
    - /var/unbound/etc/unbound.conf # both
      - pidfile: "/var/unbound/unbound.pid" # so that we do not copy it over with etc/ and monit monitoring
      - make sure your unbound configuration is compatible across multiple hosts with different interfaces addresses
    - after everything works as expected, the resolv.conf of secondary should point to the primary so that this host can update its tables after restarting pf.conf (upon synchronization) and by cron
  - rcctl enable unbound # secondary
- carpentry
  - rcctl enable carpentry # primary
  - rcctl start carpentry # primary
- reboot test
  - care about the pitfalls of rebooting a carp gateway with preemption. See the section about upgrading carp gateways


## alerts with monit

- monitrc: /etc/monitrc
  - Note: in general, /etc/monitrc differs between primary and secondary, because only some of the scripts are relevant to each. Scripts that are relevant to both, are suffixed with 'primary' or 'secondary'
  - /etc/monitrc # both: configure
    - source, destination and mail-format signature
    - delay between executions. Should be of 5 minutes or above, because some scripts dump all monitored pf tables)
  - mkdir /etc/carpentry.monit # both
    - copy scripts
    - chmod -R 700 /etc/carpentry.monit
  - rcctl enable monit # both
  - rcctl start monit # both
  - some of the monitored parameters are the following. Some of thems are easily configurable within the respective script:
    -  mails in queue
    - sysctl.conf bad on second hosts
    - scripts differ: root bin, pf, dhcp, unbound, vpn, ifstated
    - interfaces differ: different amount of hostname.carpX files
    - cannot reach secondary
    - invalid carp
    - pfsync states
    - pf tables in memory 
    - DNS: query to external


## making significant changes to pf.conf without losing access to the gateway

In general, even if a rule like the following is loaded, it will not kill an SSH session:
`block quick from any to any`

However, new sessions will be rejected. Both incoming and outgoing.

An alternative is to use a time-based try-fail mechanism like the following:
1. create a job to rollback rules
2. load experimental rules
3. Either cancel the job if the rules are appropriate or wait for the timeout.

WARNING: Some server are more complex and require manually turning some knobs such as loading the pf tables.

### list jobs

`atq`

### create restore job

This will persist even without disowning the process or using tmux on OpenBSD 6.3

```
cp /etc/pf.conf /etc/pf.conf.old
vi /etc/pf.conf
pf -nf /etc/pf.conf
echo "$(whereis pfctl) -f /etc/pf.conf.old" | at + 2 minutes
pf -f /etc/pf.conf
```

### if successful

If you still have access on a new SSH sessions after loading the pf rules, do:

```
atq
atrm -a
```


## post-setup: adding interfaces, vlans and  carps

- start by adding VLANs at all the switches that need to know about the VLAN
- decide on which interface you want the VLAN to arrive or use a physical port with the native vlan
- primary:
  - Note: some of this has to be done simultaneously on primary and secondary according to the next list header
  - add hostname.vlanX
  - configure a temporary address to verify connectivity to secondary
  - sh /etc/netstart hostname.vlanX
  - after verifying connectivity, remove the address from the vlanX interface, because it will be configured in the caprX interface
  - create carp interface
  - sh /etc/netstart hostname.carpX
  - add the interfaces to pf.if
  - create any relevant macros in /etc/pf.conf
    - gw addresses
    - network range to internal networks table
  - check pf and verify that it was loaded correctly in secondary
  - verify that primary is carp master for the carp
- secondary:
  - create hostname.vlanX
  - configure a temporary address to verify connectivity to secondary
  - sh /etc/netstart hostname.vlanX
  - after verifying connectivity, remove the address from the vlanX interface, because it will be configured in the caprX interface
  - create carp interface
  - sh /etc/netstart hostname.carpX
  - add the interfaces to pf.if
  - verify that primary is carp master for the carp and that the carp state is secondary
- add a test host to the interface
- create DHCP range
- restart unbound so the process listens on the new interface # primary
  - add a comment within the unbound.conf file so that a restart is triggered on the secondary


## backups

There are a few different backup layers that can be used. However, by default, a dailt backup of /etc is created at /var/backups of most of /etc's files, but does not include carpentry.bin or carpentry.monit. There are a few more mechanisms available in daily(8).

It is trivial to add network-based backups via the management/pfsync vlan, since both hosts are there.

What to consider when planning the backups:
- you might need to 'consolidate' the carp gateways if you take too long to recover the primary
- /root/bin # both
- all of /etc # both
- /var/cron
- /var/log # for convenience only
- /var/backup # package lists, ...
- partition-level dumps are convenient


## consolidating the carp gateways

Consolidation is required, when the primary has been unavailable for some time and configuration changes have been manually made on the secondary. It is usually just a matter of taking the backup of the primary and applying the more recent files from the secondary on top of that backup.


## upgrading the carp gateways

- this section applies to an internet-based upgrade, but it is trivial to adapt it to that situation 
- this section does not apply to syspatch, but it is trivial to adapt it to that situation
- ideally, only change carp master as much as needed, so follow the procedure. In summary, this means:
  - if upgrading secondary:
    - one pair of changes of carp master at the very end of all upgrades in order to perform connectivity tests
  - if upgrading primary:
    - initial carp master change to secondary, before any upgrades are done
    - final carp master change to return primary to carp master, after all upgrades are done

### pre-upgrade procedure 

- read the release notes and version-specific upgrade documentation, which will affect the upgrade procedure
- decide if you need to follow the regular (offline) upgrade procedure or if it is enough to do the upgrade on the live system
- prepare the SSH access to each of the gateways in the event of a failover. I usually do this by connecting to the externally exposed SSH service
```
Host carp-primary
    User yes
    HostName 192.168.0.103
Host carp-secondary
    User yes
    HostName 192.168.110.102
    ProxyCommand ssh carp-primary -W %h:22
Host carp-primary-upgrade
    User yes
    HostName 192.168.110.101
    ProxyCommand ssh carp-primary -W %h:22
```
- prepare access to the gateways in the event of losing network connectivity through your existing access
- if required, decide to which network you will be temporarily connecting (without changing cables) the gateway in order to update packages, patches and system

### upgrading the secondary

- get internet connectivity. Need to get sets and update packages. The following is the configuration to use an existing user's VLAN to the upgrade. It is a bad idea to try to do this upgrade by chaning rules on the management or pfsync VLAN, if you are using this VLAN for access
```
netstat -rn
route del default
ifconfig carp120 down
ifconfig carp120 destroy
ifconfig vlan120 inet 192.168.120.102 netmask 255.255.255.0
ifconfig
route add default 192.168.120.103
ping 192.168.120.103
ping www.sapo.pt
pfctl -d
```
- here I usually do the live upgrade option in tmux
- upon reboot do the same configuration as previously to get internet connectivity
- ...
- installboot <BOOTDISK>
- syspatch
- pkg_add -u
- ...
- reboot
- forced failover tests: either like defined in 'upgrading the primary' or by turning off the LEDs :> 

### upgrading the primary

- net.inet.carp.preempt=0
  - /etc/sysctl.conf
  - CLI: sysctl net.inet.carp.preempt=0
- demote on primary
  - Warning: very important to have all carp interfaces in the same group for this part
  - ifconfig -g carp carpdemote 50
  - if for some reason need to abort upgrade
    - ifconfig -g carp -carpdemote 50
- do the upgrade procedure as documented in section 'upgrading secondary' with the addition of the following to remove invalid routes:
```
ifconfig carp0 down
ifconfig carp0 destroy
```
- after doing all upgrades and before the final reboot, re-activate preemption in /etc/sysctl.conf
- reboot


## troubleshooting

- monit log
- tail -f /var/log/carpentry.log -f /var/log/messages -f /var/log/maillog -f /var/log/daemon # primary
- tail -f /var/log/auth.log -f /var/log/messages -f /var/log/secure -f /var/log/daemon # secondary
- netstat -sp carp
- tcpdump -netti vlanX # look for carp traffic
- tcpdump -netti pflog0 # blocks

