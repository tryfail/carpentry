#!/bin/ksh
# the purpose of this script is to monitor if the pre-determined pf tables are being synchronized
# this is meant to be executed by monit
################################################################################

. /etc/carpentry

################################################################################
# functions

function check_remote_changes {

  for table_name in $pf_table_names; do

    # to be reused later
    table_content_local=$(pfctl -t $table_name -T show 2>&1)
    table_content_remote="$(${ssh_cmd} $remote pfctl -t $table_name -T show 2>&1 )"
    res=$?
    # check for errors
    if [ "$res" -ne "0" -a "$table_content_remote" != 'pfctl: Table does not exist.' ]; then
      # var table... will contain any ssh errors
      echo "monit pf tables compare: there was some error in connecting to the remote host"
      echo "$table_content_remote"
      exit 1
    fi

    if [ "$table_content_local" != "$table_content_remote" ]; then
      echo "monit pf tables compare: the content of $table_name differs between gateways"
      exit 1
    fi    

  done
}

################################################################################
# main

# no tables to compare
if [ -z "$pf_table_names" ]; then
  exit 0
fi

check_remote_changes

exit 0


