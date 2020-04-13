#!/bin/ksh

set -A pkgs_openbsd firmware.openbsd.org ocsp.usertrust.com ftp.rnl.tecnico.ulisboa.pt ftp.eu.openbsd.org ftp.fr.openbsd.org anoncvs.openbsd.org pool.sks-keyservers.net

for d in "${pkgs_openbsd[@]}";
do
   ip=`dig -4 +short +time=1 $d`
   echo $d $ip
   /sbin/pfctl -t pkgs_openbsd -T add $ip
done

set -A pkgs_debian ocsp.usertrust.com deb.debian.org ftp.pt.debian.org security.debian.org ftp.debian.org backports.debian.org pt.archive.ubuntu.com security.ubuntu.com pool.sks-keyservers.net

for d in "${pkgs_debian[@]}";
do
   ip=`dig -4 +short +time=1 $d`
   echo $d $ip
   /sbin/pfctl -t pkgs_debian -T add $ip
done

set -A ntp_pool pool.ntp.org time.google.com
for d in "${pool_ntp[@]}";
do
   ip=`dig -4 +short +time=1 $d`
   echo $d $ip
   /sbin/pfctl -t pool_ntp -T add $ip
done

set -A ntp_constraints www.google.com time.cloudflare.com
for d in "${ntp_constraints[@]}";
do
   ip=`dig -4 +short +time=1 $d`
   echo $d $ip
   /sbin/pfctl -t ntp_constraints -T add $ip
done



