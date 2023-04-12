
01- Install Ubuntu 20.04/22.04 (VM/LXC Container) and Install Unbound

apt update
apt upgrade -y
apt install unbound wget curl vim sudo rsyslog -y


02- Fix System Default Language

apt -y install locales-all
localectl set-locale LANG=en_US.UTF-8 LANGUAGE="en_US:en"
export LANG=en_US.UTF-8

cd /root/

echo "export LANG=en_US.UTF-8" >> .profile
echo "export LANG=en_US.UTF-8" >> .bashrc

systemctl enable unbound
systemctl start unbound


03- Fix default dns resolver

sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved.service
rm -fr /etc/resolv.conf
touch /etc/resolv.conf
echo "nameserver 127.0.0.1" > /etc/resolv.conf


04- Configure Unbound Config Files

root@# cat /etc/unbound/unbound.conf
# Unbound configuration file for Debian.
# /etc/unbound/unbound.conf.d directory.
include: "/etc/unbound/unbound.conf.d/*.conf"


root@# cd /etc/unbound/unbound.conf.d
root@# vim myunbound.conf
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
forward-zone:
        name: "."
        forward-addr: 8.8.8.8
        forward-addr: 1.1.1.1
remote-control:
control-enable: yes
control-port: 953
control-interface: 0.0.0.0



systemctl restart unbound


05- APPLY ADSENSE BLOCK

cd /root/
wget https://geoghegan.ca/pub/unbound-adblock/0.4/unbound-adblock.sh
useradd -s /sbin/nologin _adblock
install -m 755 -o root -g bin unbound-adblock.sh /usr/local/bin/unbound-adblock.sh
touch /etc/unbound/adblock.conf
chown _adblock:_adblock /etc/unbound/adblock.conf
chmod +x /usr/local/bin/unbound-adblock.sh

vim /etc/sudoers

# User privilege specification
root    ALL=(ALL:ALL) ALL
_adblock    ALL=(root) NOPASSWD: /bin/systemctl restart unbound

chown _adblock /usr/local/bin/unbound-adblock.sh
sudo -u _adblock sh /usr/local/bin/unbound-adblock.sh -linux


# vim /usr/local/bin/unbound-adblock.sh

vim /usr/bin/cyclone-unbound-reload.sh
#!/bin/bash
sudo -u _adblock sh /usr/local/bin/unbound-adblock.sh -linux
echo "server:" > /etc/unbound/unbound.conf.d/adblock.conf
cat /etc/unbound/adblock.conf >> /etc/unbound/unbound.conf.d/adblock.conf
systemctl restart unbound

chmod +x /usr/bin/cyclone-unbound-reload.sh
unbound-checkconf /etc/unbound/unbound.conf.d/myunbound.conf
/usr/bin/cyclone-unbound-reload.sh
tail -f /var/log/syslog



06- UNBOUND LOGGING TO SYSLOG with Proper TimeStamp


vim /etc/rsyslog.conf

###########################
#### GLOBAL DIRECTIVES ####
###########################

#
# Use traditional timestamp format.
# To enable high precision timestamps, comment out the following line.
#
# $ActionFileDefaultTemplate RSYSLOG_TraditionalFileFormat
#
### Create Custome Log Format with the following....
#
$template myformat,"%TIMESTAMP:1:10:date-rfc3339% %TIMESTAMP:19:12:date-rfc3339% %syslogtag%%msg%\n"
$ActionFileDefaultTemplate myformat
# Filter duplicated messages
$RepeatedMsgReduction on

sudo systemctl restart rsyslog

sudo mkdir /opt/ipslog

root@# vim /opt/iplog_format.sh
#!/bin/bash
isp_name=`BTSL`
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
awk '{print $1,$2,$6,$7}' /opt/$date_time-unbound-temp.log > /opt/ipslog/$date_time-IPLog-$isp_name.txt
sleep 2
rm -fr /opt/$date_time-unbound.log
rm -fr /opt/$date_time-unbound-temp.log
echo -e "Format Done ..."


sudo chmod +x /opt/iplog_format.sh


## In clinet mikrotik
/ip firewall nat add action=dst-nat chain=dstnat comment=_DNS_Forward_ dst-port=53 protocol=tcp to-addresses=100.64.100.110 to-ports=53	
/ip firewall nat add action=dst-nat chain=dstnat comment=_DNS_Forward_ dst-port=53 protocol=udp to-addresses=100.64.100.110 to-ports=53	
/ip firewall nat add action=dst-nat chain=dstnat comment=_DNS_Forward_ dst-port=853 protocol=tcp to-addresses=100.64.100.110 to-ports=53	
/ip firewall nat add action=dst-nat chain=dstnat comment=_DNS_Forward_ dst-port=853 protocol=udp to-addresses=100.64.100.110 to-ports=53



root@# vim  /usr/bin/rsync_log.sh
#!/bin/bash
find /opt/ipslog/ -type f -ctime +1 -exec rm -fr {} \;
sleep 2
#rsync -av --rsh='ssh -p7860' /opt/ipslog/ root@163.47.157.205:/vol1/data/UDNS1-LOG/
rsync -av /opt/ipslog/ /mnt/log_store


sudo chmod +x /usr/bin/rsync_log.sh
sudo /usr/bin/rsync_log.sh


sudo vim /etc/crontab
#
15 *    * * *   root    /opt/iplog_format.sh
15 4    * * *   root    /home/udns1/rsync_log.sh
#
25 4    * * *   root    /usr/bin/cyclone-unbound-reload.sh





https://www.geoghegan.ca/unbound-adblock.html



