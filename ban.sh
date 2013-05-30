#!/bin/bash

cp /var/www/httpd-logs/xmages.net.access.log /var/www/httpd-logs/xmages.net.access.log.old
cat /dev/null > /var/www/httpd-logs/xmages.net.access.log
#cat /var/www/httpd-logs/xmages.net.access.log.old | awk '{print $1}' | sort | uniq -c | sort -k1gr | head -n10 | awk '{ if($1>100) print $2}'
for ip in `/bin/cat /var/www/httpd-logs/xmages.net.access.log.old | awk '{print $1}' | sort | uniq -c | sort -k1gr | head -n10 | awk '{ if($1>99) print $2}'`; do iptables -A INPUT -s $ip -j DROP; done

#for ip in `netstat -anp | grep ":80 " | awk '{print $5}' | cut -d":" -f 1 | sort | uniq -c | sort -nr | head -n 30 | awk '{ if ($2>40) print $2 }' | grep -vE "78.159.102.199|178.162.133.125|178.162.137.22|78.159.101.29|78.159.107.90|0.0.0.0"`; do iptables -A INPUT -s $ip -j DROP; done


serverip=`ifconfig | grep "inet addr" | awk '{print $2}' | cut -d: -f2 | grep 46 | xargs | sed -e 's/ /\|/g'`

for ip in `netstat -anp | grep ":80 " | awk '{print $5}' | cut -d":" -f 1 | sort | uniq -c | sort -nr | head -n 30 | awk '{ if ($2>40) print $2 }' | grep -vE "$serverip|0.0.0.0"`; do iptables -A INPUT -s $ip -j DROP; done


iptables-apply
