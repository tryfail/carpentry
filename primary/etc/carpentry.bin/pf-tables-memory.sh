#!/bin/ksh

# optimizations
# - the slowest task in this code is creating new tables. Even without adding new addresses, creating a table takes 1 to 1.5 seconds
# - creating and adding a table with 30k addresses takes roughly 7 seconds. This also applies to updating the table, whenever there are changes
################################################################################
# our vars

. /etc/carpentry

################################################################################
# functions

function check_remote_changes {

  for table_name in $pf_table_names; do
    # always create the tables defined in /etc/carpentry, because it is not acceptable to define tables to be synced and them not being created on all hosts 
    out=$(pfctl -t $table_name -T add 2>&1 | grep 'created')
    res=$?
    if [ "$res" -eq "0" ]; then
      echo "triggered update of remote pf tables: table $table_name was created on localhost after detected missing" | logger -t $log_tag
    fi

    # to be reused later
    table_content_local=$(pfctl -t $table_name -T show 2>&1)
    table_content_remote="$(${ssh_cmd} $remote pfctl -t $table_name -T show 2>&1 )"
    res=$?
    # check for errors
    if [ "$res" -ne "0" -a "$table_content_remote" != 'pfctl: Table does not exist.' ]; then
      # var table... will contain any ssh errors
      echo $table_content_remote | logger -t $log_tag
      carpentry_exit
    fi

    if [ "$table_content_local" != "$table_content_remote" ]; then
      push_changes
    fi    

  done
}

####################

function push_changes {

  # use the size of input to decide on which copy methd to use
  # cannot always use replace, which is faster and less prone to error, because of the ARG_MAX and xargs limitations
  # argmax is ~260k character, which is about 18K ipv4 addresses without CIDR
  # Note: '-n 10000' speficifies that each execution of xargs will use up to 10000 arguments, because there seems to be some slowness in doing more than that. However, the '-s $xargs_max' applies first and it means up to $xargs_max characters will be used as arguments. This means that xargs is called between TOTAL_ARGS_NUMBER/10000 and TOTAL_ARGS_CHARACTERS/$xargs_max number of times instead
  # 20211025-1400: removed if/else that included a feature to use pfctl...replace. Unfortunately, 'replace' is more performant but it is not as useful
  
  out=$(${ssh_cmd} "$remote" "pfctl -q -t $table_name -T kill")
  res=$?
  # check for errors
  if [ "$res" -ne "0" -a "$table_content_remote" != 'pfctl: Table does not exist.' ]; then
    echo $out | logger -t $log_tag
    carpentry_exit
  fi

  out=$(pfctl -t $table_name -T show 2>&1 | ${ssh_cmd} "$remote" "xargs -n 10000 -s $xargs_max pfctl -q -t $table_name -T add")
  res=$?
  # check for errors
  if [ "$res" -ne "0" ]; then
    echo $out | logger -t $log_tag
    carpentry_exit
  fi
  echo "triggered update of remote pf tables: large table $table_name was updated" | logger -t $log_tag

}

################################################################################
# main

time_start=$(date '+%s')

# defined in the kernel. maximum number of characters in the arguments that are passed to the command that xargs calls
typeset -i xargs_max
xargs_max=$(getconf ARG_MAX)
xargs_max=$xargs_max-10000 # max xargs


# no tables to copy
if [ -z "$pf_table_names" ]; then
  exit 0
fi

echo "triggered update of remote pf tables: comparing each table on each host before making changes" | logger -t $log_tag
check_remote_changes

time_end=$(date '+%s')
time_duration=$((time_end - time_start))
if [ $time_duration -gt 15 ]; then # might want to check this out 
  echo "triggered update of remote pf tables: execution took $time_duration seconds" | logger -t $log_tag
fi

exit 0


