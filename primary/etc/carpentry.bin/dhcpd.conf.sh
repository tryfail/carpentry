#!/bin/ksh
# - must be ksh because of output redirection
################################################################################

. /etc/carpentry

source_file="/etc/dhcpd.conf"

# checking for errors before copying
echo "triggered update of remote dhcpd service: checking config on local host" | logger -t $log_tag
res=$(dhcpd -n 2>&1) 
if [ -n "$res" ]; then
  echo $res | logger -t $log_tag
  carpentry_exit
fi

# if have not exited because of errors copy to other carp host
# when source_file is a directory we have to copy to the above directory because scp does not replace
# not required when source_file is just a file
echo "triggered update of remote dhcpd service: moving config to remote host" | logger -t $log_tag
dirname=$(dirname $source_file)
out=$(${rcp_cmd} "$source_file" "$remote":$dirname 2>&1)
res=$?
if [ "$res" -ne "0" ]; then
  echo "$out" | logger -t $log_tag
  carpentry_exit
fi

# checking for errors after copying
echo "triggered update of remote dhcpd service: checking config on remote host" | logger -t $log_tag
res=$(${ssh_cmd} "$remote" "dhcpd -n 2>&1")
# check for errors
if [ -n "$res" ]; then
  echo $res | logger -t $log_tag
  carpentry_exit
fi

echo "triggered update of remote dhcpd service: restarting dhcpd on remote host" | logger -t $log_tag
res=$(${ssh_cmd} "$remote" "rcctl restart dhcpd 2>&1 | grep -v 'dhcpd(ok)'" 2>&1)
# check for errors
if [ -n "$res" ]; then
  echo $res | logger -t $log_tag
  carpentry_exit
fi

# all good. be verbose when ending
echo "triggered update of remote dhcpd service: completed without errors" | logger -t $log_tag
# trigger email
tail -n 50 "$carpentry_logfile" | mail -r "$mail_from" -s "$mail_subject" "$mail_destination"

exit 0

