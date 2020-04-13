#!/bin/ksh
# the purpose of this script is to check if there is a significant amount of emails in queue. This should not happen no matter witch gateway is the current carp master
# this is meant to be executed by monit
################################################################################

message_max=10
message_count=$(mailq | grep '|' | wc -l | tr -d ' ') 
if [ $message_count -le $message_max ]; then
  exit 0
else
 exit 1
fi

