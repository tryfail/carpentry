#!/bin/ksh
# the purpose of this script is to monitor if primary can reach secondary
# this is meant to be executed by monit
################################################################################

. /etc/carpentry

####################

remote_connection=$(${ssh_cmd} "$remote" "rcctl check sshd" 2>&1)
res=$?

# check for errors
if [ $res -ne 0 ]; then
  echo "ssh to secondary: $remote_connection" # any ssh errors will go here
  exit 1
fi

exit 0
