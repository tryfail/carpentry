#!/bin/ksh
# - must be ksh because of output redirection
################################################################################

. /etc/carpentry


table_sync=0
if [ "$1" = "-t" ]; then
  table_sync=1
fi

echo "triggered update of remote pf: checking config on local host" | logger -t $log_tag
res=$(pfctl -nf /etc/pf.conf 2>&1)
# check for errors
if [ -n "$res" ]; then
  echo $res | logger -t $log_tag
  carpentry_exit
fi

# if have not exited because of errors copy to other carp gateway
# when source_file is a directory we have to copy to the above directory because scp does not replace
# not required when source_file is just a file
if [ $table_sync -eq 1 ]; then # copy tables
  echo "triggered update of remote pf: moving file-persisted tables to remote host" | logger -t $log_tag
  source_dir="/etc/pf.tables"
  dirname=$(dirname $source_dir)
  out=$(${rcp_cmd} "$source_dir" "$remote":$dirname 2>&1)
  res=$?
  if [ "$res" -ne "0" ]; then
    echo "$out" | logger -t $log_tag
    carpentry_exit
  fi
fi

echo "triggered update of remote pf: moving config to remote host" | logger -t $log_tag
source_file="/etc/pf.conf"
out=$(${rcp_cmd} "$source_file" "$remote":"$source_file" 2>&1)
res=$?
if [ "$res" -ne "0" ]; then
  echo "$out" | logger -t $log_tag
  carpentry_exit
fi

echo "triggered update of remote pf: checking config on remote host" | logger -t $log_tag
res=$(${ssh_cmd} "$remote" "pfctl -nf /etc/pf.conf 2>&1" 2>&1 )
# check for errors
if [ -n "$res" ]; then
  echo $res | logger -t $log_tag
  carpentry_exit
fi

echo "triggered update of remote pf: restarting pf on remote host" | logger -t $log_tag
out=$(${ssh_cmd} "$remote" "/bin/sh /root/bin/pf-restart.sh 2>&1" 2>&1)
res=$?
# check for errors
if [ "$res" -ne "0" ]; then
  echo $res | logger -t $log_tag
  carpentry_exit
fi

# all good. be verbose when ending
echo "triggered update of remote pf: completed without errors" | logger -t $log_tag
# trigger email
tail -n 50 "$carpentry_logfile" | mail -r "$mail_from" -s "$mail_subject" "$mail_destination"

exit 0

