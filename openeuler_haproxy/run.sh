#!/bin/bash

# modified haproxy.cfg file
temp_ip=$ips
temp_port=$ports
ip_arr=(${temp_ip//,/ })
port_arr=(${temp_port//,/ })
for i in "${!ip_arr[@]}";
do
    sed -i "/"ip$i"/s/# //g" /usr/local/haproxy/etc/haproxy.cfg
    sed -i "s/"ip$i"/${ip_arr[$i]}/g" /usr/local/haproxy/etc/haproxy.cfg
    sed -i "s/port$i/${port_arr[$i]}/g" /usr/local/haproxy/etc/haproxy.cfg
done

# modified rsyslog.conf file

#delete journal config
rm -rf /etc/rsyslog.d/listen.conf
sed -i 's/$ModLoad imjournal/\#ModLoad imjournal/' /etc/rsyslog.conf
sed -i 's/IMJournalStateFile imjournal.state/\#IMJournalStateFile imjournal.state/' /etc/rsyslog.conf
sed -i 's/OmitLocalLogging on/OmitLocalLogging off/' /etc/rsyslog.conf

sed -i 's/\#$ModLoad imudp/$ModLoad imudp/' /etc/rsyslog.conf
sed -i 's/\#$UDPServerRun 514/$UDPServerRun 514/' /etc/rsyslog.conf
echo "local0.*     /var/log/haproxy.log"  >> /etc/rsyslog.conf

sed -i 's/SYSLOGD_OPTIONS=\"\"/SYSLOGD_OPTIONS=\"-c 2 -r -m 0\"/' /etc/sysconfig/rsyslog

# start rsyslogd
rsyslogd
haproxy -f /usr/local/haproxy/etc/haproxy.cfg 
tail -f /usr/local/haproxy/etc/haproxy.cfg