# CONFIG SNMP with Observium Agent ### In Ubuntu/Debian ###

# get packages
apt update
apt-get install snmpd xinetd vim libwww-perl telnet -y

mkdir -p /opt/observium && cd /opt
wget http://www.observium.org/observium-community-latest.tar.gz
tar zxvf observium-community-latest.tar.gz

#find /opt/observium/ -type f -name "distro"
cp -r /opt/observium/scripts/observium_agent_xinetd /etc/xinetd.d/observium_agent

# change "only_from" to match your observium server ip
vim /etc/xinetd.d/observium_agent

service observium_agent
{
        type           = UNLISTED
        port           = 36602
        socket_type    = stream
        protocol       = tcp
        wait           = no
        user           = root
        server         = /usr/bin/observium_agent

        # configure the IPv[4|6] address(es) of your Observium server here:
        only_from      = 127.0.0.1 192.168.105.163

        # Don't be too verbose. Don't log every check. This might be
        # commented out for debugging. If this option is commented out
        # the default options will be used for this service.
        log_on_success =

        disable        = no
}

chmod +x /etc/xinetd.d/observium_agent

cp -r /opt/observium/scripts/observium_agent /usr/bin/observium_agent
chmod +x /usr/bin/observium_agent

mkdir -p /usr/lib/observium_agent/local
cp -r /opt/observium/scripts/agent-local/* /usr/lib/observium_agent/local/
chmod +x /usr/lib/observium_agent/local/*

/etc/init.d/xinetd restart

[ Change in Observium Server ]

vim /opt/observium/config.php 		// add the following line //
$config['poller_modules']['unix-agent'] = 1;



sed -e "/SNMPDOPTS=/ s/^#*/SNMPDOPTS='-Lsd -Lf \/dev\/null -u snmp -p \/var\/run\/snmpd.pid'\n#/" -i /etc/default/snmpd

mv /etc/snmp/snmpd.conf /etc/snmp/snmpd.conf.org
cat >/etc/snmp/snmpd.conf <<EOL
# SNMP v2c community
agentAddress udp:161 
com2sec local     localhost           snmp-public-key
com2sec mynetwork 192.168.0.0/16      snmp-public-key
com2sec mynetwork 172.16.0.0/12       snmp-public-key
group MyRWGroup v1         local
group MyRWGroup v2c        local
group MyROGroup v1         mynetwork
group MyROGroup v2c        mynetwork
view all    included  .1    80
access MyROGroup ""      any       noauth    exact  all    none   none
access MyRWGroup ""      any       noauth    exact  all    all    none
syslocation Bangladesh
syscontact admin@domain.com
extend .1.3.6.1.4.1.2021.7890.1 distro /usr/bin/distro 
EOL


cp -r /opt/observium/scripts/distro /usr/bin/
chmod +x /usr/bin/distro



/etc/init.d/xinetd restart
/etc/init.d/snmpd restart 


[Testing the agent] // Telnet output should be displayed // Run same test from observium server //
telnet localhost 36602


// Run same test from observium server // Telnet output should be displayed //
telnet <observium-server-ip> 36602


###### if all ok now remove observium installation files/folder ### from snmp client pc/server/workstation ###
rm -fr /opt/observium*


~~~ Thank You ~~~
