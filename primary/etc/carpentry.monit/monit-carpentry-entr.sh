#!/bin/ksh
# the purpose of this script is to check if the amount of entr processes currently in execution is similar to what is defined in /etc/rc.d/carpentry
# this is meant to be executed by monit
################################################################################

. /etc/carpentry

####################
# functions

check_entr_process_count() {
  # get the amount of lines in the service file that look like they contain a fork involving entr
  res_theoretical=$(cat /etc/rc.d/carpentry | grep /usr/local/bin/entr | grep -Ev 'pkill|grep|daemon|pexp|^[[:blank:]]+#'|wc -l)
  res_current=$(pgrep -f /usr/local/bin/entr | wc -l)

  if [ $res_theoretical -ne  $res_current ]; then
    echo "Number of entr declared processes in service file and currently running does not match. Quiting!"
    exit 1
  fi
}

####################
# main

# this is helpful to track zombie processes and other states that should not exist
check_entr_process_count

# if all goes well. exit with 0 to not trigger monit
exit 0

