#!/bin/ksh
# the purpose of this script is to check if it is possible to resolve external DNS records on the primary
# this is meant to be executed by monit
################################################################################

. /etc/carpentry

####################
# check for invalid carp

dns_query=$(dig +tries=2 +time=2 @199.43.135.53 an.example.com 2>&1) 2>&1
res=$?
# check for errors
if [ $res -ne 0 ]; then
  echo "external dns check: $dns_query" # any ssh errors will go here
  echo "Unhandled return code while checking remote DNS records"
  exit 1
fi

exit 0

