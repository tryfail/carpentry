#!/bin/ksh
# the purpose of this script is to check if there are significant differences in sysctl config between primary and secondary
# this is meant to be executed by monit
################################################################################

. /etc/carpentry

####################
# check for significant differences in sysctl.conf
checksum_local=$(grep -Ev "^#|^$|^net.inet.carp.preempt=" /etc/sysctl.conf | cksum | cut -f 1 -d ' ')  
checksum_remote=$(${ssh_cmd} "$remote" "grep -Ev '^#|^$|^net.inet.carp.preempt=' /etc/sysctl.conf | cksum | cut -f 1 -d ' '" 2>&1)

res=$?
# check for errors
if [ "$res" -ne "0" ]; then
  echo "$checksum_remote" # any ssh errors will go here
  echo "Unhandled return code while checking remote checksum of sysctl.conf"
  exit 255
fi

# check if sums differ 
if [ "$checksum_local" != "$checksum_remote" ]; then
  echo "sysctl.conf: checksum of excluding preemption differs between primary and secondary"
  exit 1
fi

exit 0
