#!/bin/bash
set -ex
MS_IP=$1

set +x
[[ ! -z $2 ]] && PASSWORD=$2 || PASSWORD="12shroot"
set -x

# Make sure paramiko is installed (for copy_ssh_key.py) and then copy our public RSA key to the MS
sudo /usr/bin/yum install -y python-paramiko
chmod 0755 jenkins/slave/copy_ssh_key.py
/usr/bin/ssh-keygen -R $MS_IP > /dev/null 2>&1
/usr/bin/ssh-keyscan -H $MS_IP >> ~/.ssh/known_hosts 2> /dev/null

echo "jenkins/slave/copy_ssh_key.py $MS_IP root <PASSWORD>"
set +x
jenkins/slave/copy_ssh_key.py $MS_IP root $PASSWORD
set -x

# Copy the scripts that will run on the MS over
/usr/bin/ssh root@${MS_IP} "rm -rf /root/rvb; mkdir -p /root/rvb"
/usr/bin/scp -rp jenkins/enm/* root@${MS_IP}:/root/rvb
