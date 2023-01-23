
## Install FreeBSD 13.1 - 64bit 

Login into server by SSH


pkg update
pkg upgrade

pkg install  vim iftop htop mtr iperf3 mc nano bwm-ng


portsnap fetch extract update


cat /etc/sysctl.conf

#
net.inet.ip.forwarding=1
net.inet.ip.redirect=0
#net.inet.ip.fw.one_pass=0
net.inet.tcp.mssdflt=1460
net.inet.tcp.minmss=536
net.inet.tcp.syncache.rexmtlimit=0
net.inet.ip.maxfragpackets=0
net.inet.ip.maxfragsperpacket=0
net.inet.tcp.abc_l_var=44
net.inet.ip.intr_queue_maxlen=2048
net.route.netisr_maxqlen=2048
kern.ipc.maxsockbuf=614400000
kern.coredump=0
net.inet.raw.maxdgram=16384
net.inet.raw.recvspace=16384
kern.ipc.somaxconn=2048
net.inet.tcp.syncookies=0
net.inet.tcp.tso=1
net.inet.tcp.recvspace=4194304
net.inet.tcp.sendspace=4194304
net.inet.tcp.sendbuf_max=16777216
net.inet.tcp.recvbuf_max=16777216
net.inet.tcp.sendbuf_auto=1
net.inet.tcp.recvbuf_auto=1
net.inet.tcp.sendbuf_inc=524288
net.inet.tcp.recvbuf_inc=524288
net.inet.tcp.hostcache.expire=1
net.inet.tcp.cc.algorithm=htcp
security.bsd.see_other_uids=0
security.bsd.see_other_gids=0
net.inet.udp.blackhole=1
net.inet.tcp.blackhole=2
net.inet.tcp.isn_reseed_interval=4500
#
net.inet.tcp.rfc6675_pipe=1
hw.intr_storm_threshold=25000000
#


root@BSDGW2:~ # cat /etc/ipfw-isp1gw1.sh
#!/bin/sh
ipfw -q -f flush
ipfw -f pipe flush
ipfw -f nat flush
ipfw -q disable one_pass

fwcmd="ipfw -q add"

ipfw -q add 50 pass all from any to any via lo0
ipfw -q add 51 deny all from any to 127.0.0.0/8
ipfw -q add 52 deny ip from 127.0.0.0/8 to any


######## Configure NAT
ipfw -q nat 10 config ip 43.230.123.57


### BLOCK RULES
ipfw -q add 90 deny tcp from any to any 25 in
ipfw -q add 91 deny tcp from any to any 25 out
ipfw -q add 92 deny tcp from any to any 67 in
ipfw -q add 93 deny tcp from any to any 67 out


### UPLLOAD CONTROL-ALL IP
ipfw -q pipe 105 config bw 10Mbit/s mask src-ip 0xffffffff
ipfw -q add 105 pipe 105 ip from any to any out via ix1.450

ipfw -q pipe 106 config bw 10Mbit/s mask src-ip 0xffffffff
ipfw -q add 106 pipe 106 ip from any to any out via ix1.451


ipfw -q pipe 111 config bw 10Mbit/s
ipfw -q add 111 pipe 111 ip from any to any out via ng0

ipfw -q pipe 112 config bw 10Mbit/s
ipfw -q add 112 pipe 112 ip from any to any out via ng1

### INTERNET-NAT

ipfw -q add 10001 nat 10 ip from 10.20.30.0/24 to any out via re2
ipfw -q add 10002 nat 10 ip from 10.16.32.0/24 to any out via re2
ipfw -q add 10003 nat 10 ip from 10.20.24.0/30 to any out via re2
ipfw -q add 10070 nat 10 ip from any to 43.230.123.57  in via re2 ## IN

