#!/bin/ksh

####################
# doc
# - this program does several noteworthy checks for dnsentry environments

# get our vars
. /etc/dnsentry

trigger_sync() {
  echo "`date`" >> /var/unbound/etc/monit-trigger-file
  sleep 5 # wait for things to happen
  # send both logs
  tail -n 50 /var/log/dnsentry.log /var/log/messages | mail -r "$mail_from" -s "dnsentry-log: synchronization requested" "$mail_destination"
}

####################
# rest of code

trigger_sync

# if all goes well. exit with 0 to not trigger monit
exit 0

