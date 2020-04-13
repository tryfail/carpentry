#!/bin/ksh

out=$(pfctl -nf /etc/pf.conf 2>&1)
res=$?
if [ $res -ne 0 ]; then
  echo "$out" | logger -t $log_tag
  echo "pf restart: Failed at testing pf.conf. Quiting!"
  exit 1
fi

out=$(pfctl -f /etc/pf.conf 2>&1)
res=$?
if [ $res -ne 0 ]; then
  echo "$out" | logger -t $log_tag
  echo "pf restart: Failed at loading pf.conf. Quiting!"
  exit 1
fi

/root/bin/pf-tables-update.sh

echo "pf restart: restarted with new config and refreshed tables"
exit 0


