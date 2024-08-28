#!bin/bash/sh

#script to fetch netsim vm details

for i in `grep netsim /var/ericsson/ddc_data/config/server.txt | grep -oP "ieat.*[0-9]{2,4}[a-z]?"`;do echo $i;done |sort|uniq> /root/rvb/bin/netsim_rootspacecheck/netsim_list.txt

