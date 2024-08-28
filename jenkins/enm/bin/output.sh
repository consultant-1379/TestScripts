#!bin/bash/sh

#Script to save output of netsim_rootspace.sh in a file

echo -e "\e[0;35m"Netsim operations can take some time. Please be patient!.....":\e[0m\t"| sed 's/^/\t/g'

sh /root/rvb/bin/netsim_rootspacecheck/netsim_rootspace.sh > /root/rvb/bin/netsim_rootspacecheck/output_file.txt

echo ""

echo -e The details are stored in "\e[0;32m/root/rvb/bin/netsim_rootspacecheck/output_file.txt\e[0m"

echo ""