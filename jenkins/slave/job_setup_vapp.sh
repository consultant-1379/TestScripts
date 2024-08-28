#!/bin/bash
set -ex
HOST_IP=$1

# Split the IP using colon delimeter to get the IP and port
IFS=':' read -r -a HOST_PORT_LIST <<< "$HOST_IP"

VAPP_GW=${HOST_PORT_LIST[0]}
PORT=${HOST_PORT_LIST[1]}

# Make sure paramiko is installed (for copy_ssh_key.py) and then copy our public RSA key to the MS
#sudo /usr/bin/yum install -y python-paramiko
#chmod 0755 jenkins/slave/copy_ssh_key.py
/usr/bin/ssh-keygen -R $VAPP_GW > /dev/null 2>&1
/usr/bin/ssh-keyscan -H $VAPP_GW >> ~/.ssh/known_hosts 2> /dev/null
jenkins/slave/copy_ssh_key_dv.py $HOST_IP root 12shroot

# Copy the scripts that will run on the MS over (port forwarding through the vapp gateway)
/usr/bin/ssh -p $PORT root@${VAPP_GW} "mkdir -p /root/rvb"
/usr/bin/scp -P $PORT -rp jenkins/enm/* root@${VAPP_GW}:/root/rvb
