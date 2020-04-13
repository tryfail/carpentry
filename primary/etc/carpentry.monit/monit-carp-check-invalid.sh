#!/bin/ksh
# the purpose of this script is to check if there any invalid carp interfaces on either gateway
# this is meant to be executed by monit
################################################################################

. /etc/carpentry

####################
# check for invalid carp
ifconfig_local=$(ifconfig carp | grep -E 'status: invalid|carp: INVALID')
ifconfig_local_rc=$?
ifconfig_remote=$(${ssh_cmd} "$remote" "ifconfig carp | grep -E 'status: invalid|carp: INVALID'" 2>&1)
ifconfig_remote_rc=$?

# check for errors
if [ $ifconfig_remote_rc -ne 0 -a -n "$ifconfig_remote" ]; then
  echo "$ifconfig_remote" # any ssh errors will go here
  echo "Unhandled return code while checking remote carp ifconfig"
  exit 255
fi

if [ $ifconfig_local_rc -eq 0 -o $ifconfig_remote_rc -eq 0 ]; then # an invalid carp was cound
  echo "An invalid carp was found either local or remote"
  echo "local carp:"
  echo $ifconfig_local
  echo "remote carp:"
  echo $ifconfig_remote
  exit 1
fi

exit 0
