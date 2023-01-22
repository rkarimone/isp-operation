# isp-operation
ISP OPERATIONAL TECHNOLOGY


# https://www.cyberciti.biz/faq/how-to-install-a-wireguard-vpn-client-in-a-freebsd-jail/

# WireGurad Client on FreeBSD
```

pkg update
pkg upgrade

pkg search wireguard
pkg install wireguard

cd /usr/local/etc/wireguard/

vim /usr/local/etc/wireguard/wg0.conf


sysrc wireguard_interfaces="wg0"
sysrc wireguard_enable="YES"

service wireguard start

ping -c 4 ping 172.16.0.1

```

# BDCOM Switch LACP+TRUNK

```
!
interface Port-aggregator 1
switchport mode trunk
!
interface GigaEthernet0/1
switchport mode trunk
aggregator-group 1 mode lacp
!
interface GigaEthernet0/2
switchport mode trunk
aggregator-group 1 mode lacp
!
!
```
