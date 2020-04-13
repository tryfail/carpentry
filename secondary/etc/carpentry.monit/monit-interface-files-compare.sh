#!/bin/ksh
# the purpose of this script is to check if there are significant differences in interface files that should always be similar between both gateways
# this is meant to be executed by monit
# TODO: currently only checking differences in counts
################################################################################

. /etc/carpentry

# WARNING: never include any suffix digits here
interface_types="pfsync carp tun vlan tap"

####################
# check for significant differences in file counts for each interface type

for interface_type in $interface_types; do

  counts_local=$(find /etc/ -maxdepth 1 | grep -E "hostname.$interface_type[0-9]+$" | wc -l | tr -d ' ')
  counts_remote=$(${ssh_cmd} "$remote" "find /etc/ -maxdepth 1 | grep -E "hostname.$interface_type[0-9]+$" | wc -l | tr -d ' '" 2>&1)
  res=$?
  # check for errors
  if [ "$res" -ne "0" ]; then
    echo "$counts_remote" # any ssh errors will go here
    echo "Unhandled return code while checking remote interface counts of type $interface_type"
    continue
  fi

  # check if sums differ 
  if [ "$counts_local" != "$counts_remote" ]; then
    echo "$interface_type: counts differ between primary ($counts_local) and secondary ($counts_remote)"
    continue
  fi

done

exit 0
