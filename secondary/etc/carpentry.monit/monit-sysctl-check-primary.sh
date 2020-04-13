#!/bin/ksh
# the purpose of this script is to check if there are significant differences in sysctl config between primary and secondary
# this is meant to be executed by monit
################################################################################

####################
# check for preemption on localhost

preempt_matched_rc=$(grep -E "^net.inet.carp.preempt=1" /etc/sysctl.conf 2>&1)
res=$?
if [ $res -ne 0 -o "$preempt_matched_rc" = "grep: /etc/sysctl.conf: No such file or directory" ]; then
  echo "sysctl.conf: carp preemption unset on primary. Acceptable for maintenance"
  exit 1
fi


preempt_matched_rc=$(sysctl | grep -E "^net.inet.carp.preempt=1")
res=$?
if [ $res -ne 0 ]; then
  echo "sysctl runtime: carp preemption unset on primary. Acceptable for maintenance"
  exit 1
fi

exit 0
