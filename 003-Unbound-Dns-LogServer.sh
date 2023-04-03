

https://www.geoghegan.ca/unbound-adblock.html


sudo apt update
sudo apt upgrade -y
sudo apt install unbound wget curl vim -y




apt -y install locales-all
localectl set-locale LANG=en_US.UTF-8 LANGUAGE="en_US:en"
export LANG=en_US.UTF-8

cd /root/
vim .profile 	//export LANG=en_GB.UTF-8
vim .bashrc 	//export LANG=en_GB.UTF-8


echo "export LANG=en_US.UTF-8" >> .profile
echo "export LANG=en_US.UTF-8" >> .bashrc



systemctl enable unbound
systemctl start unbound


sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved.service
rm -fr /etc/resolv.conf
touch /etc/resolv.conf
echo "nameserver 127.0.0.1" > /etc/resolv.conf



http://103.115.101.218/apcl


root@Cyclone-UDNS1:/etc/unbound# cat unbound.conf
# Unbound configuration file for Debian.
#
# See the unbound.conf(5) man page.
#
# See /usr/share/doc/unbound/examples/unbound.conf for a commented
# reference config file.
#
# The following line includes additional configuration files from the
# /etc/unbound/unbound.conf.d directory.
include: "/etc/unbound/unbound.conf.d/*.conf"
#include: /etc/unbound/adblock.conf




root@Cyclone-UDNS1:/etc/unbound/unbound.conf.d# cat myunbound.conf
#
server:
port: 53
verbosity: 1
num-threads: 4
outgoing-range: 8192
num-queries-per-thread: 4096
msg-cache-size: 256M
interface: 0.0.0.0
rrset-cache-size: 512M
rrset-roundrobin: yes
cache-max-ttl: 86400
infra-host-ttl: 60
infra-lame-ttl: 120
so-reuseport: yes
msg-cache-slabs: 8
rrset-cache-slabs: 8
infra-cache-slabs: 8
key-cache-slabs: 8
access-control: 127.0.0.0/8 allow
access-control: 0.0.0.0/0 allow
username: unbound
directory: "/etc/unbound"
logfile: "/var/log/unbound.log"
log-queries: yes
log-time-ascii: yes
use-syslog: yes
hide-version: yes
so-rcvbuf: 16M
so-sndbuf: 16M
do-ip4: yes
do-ip6: no
do-udp: yes
do-tcp: yes
remote-control:
control-enable: yes
control-port: 953
control-interface: 0.0.0.0



systemctl restart unbound


cd ~

wget https://geoghegan.ca/pub/unbound-adblock/0.4/unbound-adblock.sh
useradd -s /sbin/nologin _adblock
install -m 755 -o root -g bin unbound-adblock.sh /usr/local/bin/unbound-adblock.sh

visudo
_adblock    ALL=(root) NOPASSWD: /bin/systemctl restart unbound



touch /etc/unbound/adblock.conf
chown _adblock:_adblock /etc/unbound/adblock.conf
sudo -u _adblock sh /usr/local/bin/unbound-adblock.sh -linux
sudo -u _adblock sh /usr/local/bin/unbound-adblock.sh -linux





root@Cyclone-UDNS1:/# vim /usr/bin/cyclone-unbound-reload.sh
#!/bin/bash
sudo -u _adblock sh /usr/local/bin/unbound-adblock.sh -linux
echo "server:" > /etc/unbound/unbound.conf.d/adblock.conf
cat /etc/unbound/adblock.conf >> /etc/unbound/unbound.conf.d/adblock.conf
systemctl restart unbound


chmod +x /usr/bin/cyclone-unbound-reload.sh




root@Cyclone-UDNS1:~# cat /opt/iplog_format.sh
#!/bin/bash
date_time=`date +%d-%m-%Y-%H%M%S`;
echo -e "Copying ..."
cp -r /var/log/syslog /opt/$date_time-unbound.log
sleep 1
echo -e "Rotating ..."
echo "" > /var/log/syslog
sleep 2
echo -e "Formating ..."
cat /opt/$date_time-unbound.log |grep unbound |grep info |grep IN > /opt/$date_time-unbound-temp.log
sleep 2
awk '{print $1,$2,$6,$7}' /opt/$date_time-unbound-temp.log > /opt/ipslog/$date_time-IPLog-UDNS1.txt
sleep 2
rm -fr /opt/$date_time-unbound.log
rm -fr /opt/$date_time-unbound-temp.log
echo -e "Format Done ..."





root@Cyclone-UDNS1:~# cat  /home/udns1/rsync_log.sh
#!/bin/bash
find /opt/ipslog/ -type f -ctime +3 -exec rm -fr {} \;
sleep 2
rsync -av --rsh='ssh -p7860' /opt/ipslog/ root@163.47.157.205:/vol1/data/UDNS1-LOG/


cat /etc/rsyslog.conf

###########################
#### GLOBAL DIRECTIVES ####
###########################

#
# Use traditional timestamp format.
# To enable high precision timestamps, comment out the following line.
#
# $ActionFileDefaultTemplate RSYSLOG_TraditionalFileFormat

$template myformat,"%TIMESTAMP:1:10:date-rfc3339% %TIMESTAMP:19:12:date-rfc3339% %syslogtag%%msg%\n"
$ActionFileDefaultTemplate myformat


# Filter duplicated messages
$RepeatedMsgReduction on


systemctl restart rsyslog


root@log:/data/UDNS1-LOG# cat /etc/unbound/unbound.conf.d/myunbound.conf
#
server:
port: 53
verbosity: 1
num-threads: 16
outgoing-range: 8192
num-queries-per-thread: 4096
msg-cache-size: 256M
interface: 0.0.0.0
rrset-cache-size: 512M
rrset-roundrobin: yes
cache-max-ttl: 86400
infra-host-ttl: 60
infra-lame-ttl: 120
so-reuseport: yes
msg-cache-slabs: 8
rrset-cache-slabs: 8
infra-cache-slabs: 8
key-cache-slabs: 8
access-control: 127.0.0.0/8 allow
access-control: 0.0.0.0/0 allow
username: unbound
directory: "/etc/unbound"
logfile: "/var/log/unbound.log"
log-queries: yes
log-time-ascii: yes
use-syslog: yes
hide-version: yes
so-rcvbuf: 16M
so-sndbuf: 16M
do-ip4: yes
do-ip6: no
do-udp: yes
do-tcp: yes
forward-zone:
        name: "."
        forward-addr: 8.8.8.8
        forward-addr: 9.9.9.9
        forward-addr: 1.1.1.1
remote-control:
control-enable: yes
control-port: 953
control-interface: 0.0.0.0











 150  chmod +x iplog_format.sh
  151  cd /home/
  152  ls
  153  cd udns1/
  154  ls
  155  vim rsync_log.sh
  156  chmod +x rsync_log.sh




/opt/ipslog/$date_time-Log-TeleWire-Router1.txt





cd ~
wget https://geoghegan.ca/pub/unbound-adblock/0.5/unbound-adblock.sh
useradd -s /sbin/nologin -d /var/empty _adblock
install -m 755 -o root -g bin unbound-adblock.sh /usr/local/bin/unbound-adblock
sed -i -e 's/'ksh'/'bash'/g' -e '1 s/ksh/bash/' /usr/local/bin/unbound-adblock



	# install -m 644 -o _adblock /dev/null /etc/unbound/adblock.rpz
	# install -d -o root  -m 755 /var/log/unbound-adblock
	# install -o _adblock -m 640 /dev/null /var/log/unbound-adblock/unbound-adblock.log
	# install -o _adblock -m 640 /dev/null /var/log/unbound-adblock/unbound-adblock.log.0.gz




	# visudo
	...
_adblock    ALL=(root) NOPASSWD: /usr/sbin/unbound-control -q status
_adblock    ALL=(root) NOPASSWD: /usr/sbin/unbound-control -q flush_zone unbound-adblock
_adblock    ALL=(root) NOPASSWD: /usr/sbin/unbound-control -q auth_zone_reload unbound-adblock
	...


systemctl restart unbound
sudo -u _adblock unbound-adblock -O linux





mysql -uradius -pf@hipc0re -h localhost -e "SELECT username FROM radius.radreply WHERE ATTRIBUTE='NAS-IP-Address' AND VALUE='103.118.85.130';" > username.txt



EMRAN HOSSEN




FAHSC02-21412022-12-21MR67368

