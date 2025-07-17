############### 2025 ############# UBUNTU 24.04 ###################################
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
|Resolve Language+DNS Issue ||▼
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

apt update
apt upgrade
apt install rsyslog vim mtr nano


# Fix UTF8 Lanaguace Issue
apt -y install locales locales-all
localectl set-locale LANG=en_US.UTF-8 LANGUAGE="en_US:en"
export LANG=en_US.UTF-8
cd /root/
echo "export LANG=en_US.UTF-8" >> .profile
echo "export LANG=en_US.UTF-8" >> .bashrc


# Fix default dns resolver #

sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved.service
rm -fr /etc/resolv.conf
touch /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf



~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
|| LOGGING TO SYSLOG with Proper TimeStamp ||▼
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



vim /etc/rsyslog.conf

### Create Custome Log Format with the following....
#
#$template myformat,"%timegenerated:1:10:date-rfc3339% %timegenerated:19:12:date-rfc3339% %syslogtag%%msg%\n" (Ubuntu 22.04)
$template myformat,"%FROMHOST-IP% - %HOSTNAME% - %timegenerated:1:10:date-rfc3339% %timegenerated:19:12:date-rfc3339% %syslogtag%%msg%\n"
$ActionFileDefaultTemplate myformat


# Include all config files in /etc/rsyslog.d/
#
$IncludeConfig /etc/rsyslog.d/*.conf


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
|| MODIFYING OTHER CONFIGURATION ||▼
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

mkdir -p /mnt/logdrive
chown -R syslog:syslog /mnt/logdrive 
chown -R syslog:syslog /mnt/logdrive/


sudo vim /etc/rsyslog.d/network-logs.conf

## /etc/rsyslog.d/network-logs.conf
#################
#### MODULES ####
#################

# provides UDP syslog reception
module(load="imudp")
input(type="imudp" port="514")

# provides TCP syslog reception
module(load="imtcp")
input(type="imtcp" port="514")


########### new log collection method #################
#$template RemoteInputLogs, "/mnt/logdrive/logs-collect/%FROMHOST-IP%-%HOSTNAME%/%$year%-%$month%-%$day%-%$hour%.log"
$template RemoteInputLogs, "/mnt/logdrive/%FROMHOST-IP%-%HOSTNAME%/%$year%-%$month%-%$day%-%$hour%.log"
if ($msg contains 'established') then
*.* ?RemoteInputLogs


## For lxc container need to execute the following lines
chmod -R 777 /mnt/logdrive
sed -i '/imklog/s/^/#/' /etc/rsyslog.conf

apt install apparmor-utils
aa-complain /etc/apparmor.d/usr.sbin.rsyslogd



##### Next 3-Lines for proxmox CT ####
systemctl disable ssh.socket
systemctl enable ssh.service
systemctl restart ssh.service

#### Restart the services
sudo systemctl restart rsyslog
sudo systemctl status rsyslog





########### LOG ROTATION #########################################

root@log-abuzz:~# cat /etc/logrotate.d/rsyslog
/var/log/syslog
/var/log/mail.info
/var/log/mail.warn
/var/log/mail.err
/var/log/mail.log
/var/log/daemon.log
/var/log/kern.log
/var/log/auth.log
/var/log/user.log
/var/log/lpr.log
/var/log/cron.log
/var/log/debug
/var/log/messages
/mnt/logdrive/logs-collect/*.log
{
        rotate 8
        hourly
        missingok
        notifempty
        compress
        delaycompress
        sharedscripts
        postrotate
        /usr/lib/rsyslog/rsyslog-rotate
        endscript
}


########### LOG ROTATION #########################################



#########################################################################################################
###### Client End Configuration
#########################################################################################################

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
|MIKROTIK-CONFIGURATION ||▼ (OPTION-1)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

### Config In MikrotTik
system logging action add bsd-syslog=yes name=remotelogsrv1 remote=103.xxx.yy.237 syslog-facility=local6 target=remote
system logging set 0 topics=info,!firewall,!script
system logging add action=remotelogsrv1 topics=script
system logging add action=remotelogsrv1 topics=firewall
system logging add action=remotelogsrv1 topics=account
ip firewall mangle add action=log chain=prerouting connection-state=established protocol=tcp src-address=10.0.0.0/8 tcp-flags=fin


#ip firewall mangle add action=log chain=prerouting connection-state=established protocol=tcp src-address=10.0.0.0/8 tcp-flags=fin
#ppp profile set *0 on-up=":foreach dev in=[ppp active print detail as-value where name=\$user ] do={\r\n    /log info (\"PPPLOG \$user \" . (\$dev->\"caller-id\") . \" \" . (\$dev->\"address\"));\r\n}"

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
|MIKROTIK-CONFIGURATION ||▼ (OPTION-2)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

/ip firewall filter add action=log chain=forward connection-state=new dst-port=80,443 protocol=tcp out-interface=vlan3520-IPT
/system logging action add name=LOG252 remote=157.15.61.151 target=remote src-address=103.138.250.73
/system logging add action=LOG252 topics=firewall
/user add name=logapi group=read password=GoodPw@20xx


