#!/bin/ksh
# the purpose of this script is to monitor if pfsync is working properly
# this is meant to be executed by monit
################################################################################

. /etc/carpentry

# percentage in decimal format with decimal dot
ratio_min=0.93
ratio_max=1.03
# when remote_states < 100. window of states, since percentages are not useful
ratio_window=3

####################
# get state counts
states_local=$(pfctl -si | grep entries | grep -o -E '[[:digit:]]+')
states_remote=$(${ssh_cmd} "$remote" "pfctl -si | grep entries | grep -o -E '[[:digit:]]+'" 2>&1)
res=$?

# check for errors
if [ $res -ne 0 ]; then
  echo "$states_remote" # any ssh errors will go here
  echo "Unhandled return code while checking remote pf statistics"
  exit 255
fi

####################
# if states < 100, allow up to ratio_window difference of states


if [ $states_remote -lt 100 ]; then

  states_max=$(($states_remote+$ratio_window))
  states_min=$(($states_remote-$ratio_window))
  if [ $states_local -gt $states_max -o $states_local -lt $states_min ]; then
    echo "pf states: the ratio of states between secondary ($states_remote) and primary $(states_local) is not within an acceptable range"
    exit 1
  else
   exit 0
  fi

fi


####################
# if states > 100, compare based on percentage

ratio=$(echo "$states_remote / $states_local" | bc -l)
# outputs:
# - 0 if within range
# - 1 if outside of ration_min and ratio_max range
ratio_unacceptable=$(echo "$ratio > $ratio_max || $ratio < $ratio_min" | bc -l)

if [ $remote_states -gt 100 -a "$ratio_unacceptable" -eq 1 ]; then 
  echo "pf states: the ratio of states between secondary ($states_remote) and primary $(states_local) is not within an acceptable range"
  exit 1
else
  exit 0
fi

