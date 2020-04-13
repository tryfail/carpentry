#!/bin/ksh
# the purpose of this script is to check if there are significant differences in files that should always be synchronized between both gateways
# this is meant to be executed by monit
################################################################################

. /etc/carpentry

files_synced="/etc/pf.conf /etc/mail/aliases /etc/dhcpd.conf /var/unbound/etc/unbound.conf /etc/ifstated.conf /etc/pf.tables/blacklist.txt /etc/pf.tables/ntp_pool.txt /etc/doas.conf /etc/openvpn/carpentry.conf /root/bin/pf-restart.sh /root/bin/pf-tables-update.sh"

####################
# check for significant differences in each file

for file in $files_synced; do

  checksum_local=$(cksum "$file" | cut -f 1 -d ' ')  
  checksum_remote=$(${ssh_cmd} "$remote" "cksum \"$file\" 2>&1 | cut -f 1 -d ' '" 2>&1)  
  res=$?
  # check for errors
  if [ "$res" -ne "0" ]; then
    echo "$checksum_remote" # any ssh errors will go here
    echo "Unhandled return code while checking remote checksum of \"$file\""
    exit 255
  fi

  # check if sums differ 
  if [ "$checksum_local" != "$checksum_remote" ]; then
    echo "$file: checksum differs between primary and secondary"
    continue
  fi

done

exit 0
