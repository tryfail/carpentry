#!/bin/ksh
# - must be ksh because of output redirection

. /etc/carpentry

echo "triggered update of remote openvpn service" | logger -t $log_tag

# we want to copy all directories that have openvpn in their name within /etc
source_dirs="$(find /etc/ -maxdepth 1  | grep openvpn)"

# if have not exited because of errors copy to other carp host
# when source_file is a directory we have to copy to the above directory because scp does not replace
# not required when source_file is just a file
echo "triggered update of remote openvpn service: moving config to remote host" | logger -t $log_tag
for source_dir in $source_dirs; do
  dirname=$(dirname $source_dir)
  out=$(${rcp_cmd} "$source_dir" "$remote":$dirname 2>&1)
  res=$?
  if [ "$res" -ne "0" ]; then
    echo "$out" | logger -t $log_tag
    carpentry_exit
  fi
done

# we want to copy all hostname.tun* and hostname.tap* within /etc
source_files="$(find /etc/ -maxdepth 1 | grep -E  'hostname.tap[[:digit:]]+|hostname.tun[[:digit:]]')"

# if have not exited because of errors copy to other carp host
# when source_file is a directory we have to copy to the above directory because scp does not replace
# not required when source_file is just a file
echo "triggered update of remote openvpn service: moving all tun and tap interface configuration to remote host" | logger -t $log_tag
for source_file in $source_files; do
  out=$(${rcp_cmd} "$source_file" "$remote":"$source_file" 2>&1)
  res=$?
  if [ "$res" -ne "0" ]; then
    echo "$out" | logger -t $log_tag
    carpentry_exit
  fi
done

echo "triggered update of remote openvpn service: restarting openvpn interfaces on remote host" | logger -t $log_tag

source_ifs="$(find /etc/ -maxdepth 1 | grep -E  'hostname.tap[[:digit:]]+|hostname.tun[[:digit:]]' | grep -oE '[^\.]+$')"

for source_if in $source_ifs; do
  #res=$(${ssh_cmd} "$remote" "sh /etc/netstart $source_if 2>&1 | grep -v 'unbound(ok)'" 2>&1)
  res=$(${ssh_cmd} "$remote" "sh /etc/netstart $source_if" 2>&1) 
  # check for errors in output
  if [ -n "$res" ]; then
    echo $res | logger -t $log_tag
    carpentry_exit
  fi
done
# all good. be verbose when ending
echo "triggered update of remote openvpn service: completed without errors" | logger -t $log_tag
# trigger email
tail -n 50 "$carpentry_logfile" | mail -r "$mail_from" -s "$mail_subject" "$mail_destination"

exit 0

