#!/bin/ksh

set -x 

. /etc/carpentry

find /etc/ssh -type f | grep -v config | xargs -I % scp -pr % $remote:/etc/ssh

echo "WARNING: manually test and restart sshd on the remote now"

