   118	21:21	pkg fetch -d -o /opt/bwm-ng/ bsnmp-ucd
   119	21:21	ls bwm-ng/
   120	21:21	ls bwm-ng/All/
   121	21:21	mkdir pkgs
   122	21:21	pkg fetch -d -o /opt/pkgs/ bsnmp-ucd
   123	21:22	pkg fetch -d -o /opt/pkgs/ iftop htop
   124	21:22	ll
   125	21:22	ll pkgs/All/
   126	21:23	pkg fetch -d -o /opt/pkgs/ iperf3
   127	21:23	pkg fetch -d -o /opt/pkgs/ rsync
   128	21:23	pkg fetch -d -o /opt/pkgs/ mtr
   129	21:25	ll pkgs/All/
   130	21:25	scp -P 8443 -r /opt/pkgs/ root@172.25.50.1:/home/noc/


pkg add /opt/pkgs/All/*
