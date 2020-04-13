#!/bin/ksh
# the purpose of this script is to check if it is possible to resolve external DNS records on the secondary via the primary
# this is meant to be executed by monit
################################################################################

primary="192.168.110.101"

################################################################################
# check for carp master
out=$(ifconfig | grep 'status: master')
res=$?

if [ $res -eq 0 ]; then # skip if master
  exit 0
fi

dns_query=$(dig +tries=2 +time=2 @$primary www.example.com 2>&1) 2>&1
res=$?
# check for errors
if [ $res -ne 0 ]; then
  echo "external dns check: $dns_query"
  echo "Unhandled return code while checking remote DNS records"
  exit 1
fi

exit 0


