#!/bin/bash

# Create cron entry to upload stats to DDPI
mkdir -p /etc/cron.d
echo "15 * * * * root /opt/ericsson/ddc/bin/ddcDataUpload -s ENM335 -d ddpenm2" > /etc/cron.d/ddc_upload
chmod 0644 /etc/cron.d/ddc_upload

# Create cron entry to monitor filesize every 30 mins
echo "*/30 * * * * root /root/rvb/5335enmRuns/filesize_monitor.sh" > /etc/cron.d/filesize_monitor

#Turn on DDC/DDP for SFS
touch /var/ericsson/ddc_data/config/MONITOR_SFS

#Turn on DDC/DDP for VNX
touch /var/ericsson/ddc_data/config/MONITOR_CLARIION


# Install the latest version of utilities
function update_enm_utils(){
         nexus='https://arm1s11-eiffel004.eiffel.gic.ericsson.se:8443/nexus'
         gr='com.ericsson.dms.torutility'
         art='ERICtorutilitiesinternal_CXP9030579'
         ver=`/usr/bin/repoquery -a --repoid=ms_repo --qf "%{version}" ERICtorutilities_CXP9030570`
         wget -O $art-$ver.rpm "$nexus/service/local/artifact/maven/redirect?r=releases&g=${gr}&a=${art}&v=${ver}&e=rpm"
         rpm -Uvh ERICtorutilitiesinternal_CXP9030579-${ver}.rpm
         art='ERICdeploymentvalidation_CXP9032314'
         wget -O $art-$ver.rpm "$nexus/service/local/artifact/maven/redirect?r=releases&g=${gr}&a=${art}&v=${ver}&e=rpm"
         rpm -Uvh ERICdeploymentvalidation_CXP9032314-${ver}.rpm
         rm `pwd`/ERICtorutilitiesinternal_CXP9030579-${ver}.rpm
         rm `pwd`/ERICdeploymentvalidation_CXP9032314-${ver}.rpm
}	

update_enm_utils

/opt/ericsson/enmutils/.deploy/update_enmutils_rpm -l

# Sleep for a 10 minutes to allow the VMs to come up
sleep 600

# Add LTE License file to enm
/opt/ericsson/enmutils/bin/cli_app 'lcmadm install file:LTE_5MHZ_SC.txt' /root/rvb/licenses/LTE_5MHZ_SC.txt
 Add SGSN License file to enm
/opt/ericsson/enmutils/bin/cli_app 'lcmadm install file:SGSN-MMEkSAU.txt' /root/rvb/licenses/SGSN-MMEkSAU.txt
 Add ER6000 License file to enm
/opt/ericsson/enmutils/bin/cli_app 'lcmadm install file: R6000-FAT1023440.txt' /root/rvb/licenses/R6000-FAT1023440.txt
 Add MGW License file to enm
/opt/ericsson/enmutils/bin/cli_app 'lcmadm install file: MGW-SCC-FAT1023444.txt' /root/rvb/licenses/MGW-SCC-FAT1023444.txt

# Check the state of the cluster
set -ex

#Setup ddc collection for NETSims
echo "ieatnetsimv5051-01=NETSIM
ieatnetsimv5051-02=NETSIM
ieatnetsimv5051-03=NETSIM
ieatnetsimv5051-04=NETSIM
ieatnetsimv5051-05=NETSIM
ieatnetsimv5051-06=NETSIM
ieatnetsimv5051-07=NETSIM
ieatnetsimv5051-09=NETSIM" > /var/ericsson/ddc_data/config/server.txt



#Copy across ssh public keys to NETSim for passwordless connections (required by DDC)
/usr/bin/expect -d /root/rvb/copy-rsa-key-to-netsim.exp ieatnetsimv5051-01
/usr/bin/expect -d /root/rvb/copy-rsa-key-to-netsim.exp ieatnetsimv5051-02
/usr/bin/expect -d /root/rvb/copy-rsa-key-to-netsim.exp ieatnetsimv5051-03
/usr/bin/expect -d /root/rvb/copy-rsa-key-to-netsim.exp ieatnetsimv5051-04
/usr/bin/expect -d /root/rvb/copy-rsa-key-to-netsim.exp ieatnetsimv5051-05
/usr/bin/expect -d /root/rvb/copy-rsa-key-to-netsim.exp ieatnetsimv5051-06
/usr/bin/expect -d /root/rvb/copy-rsa-key-to-netsim.exp ieatnetsimv5051-07
/usr/bin/expect -d /root/rvb/copy-rsa-key-to-netsim.exp ieatnetsimv5051-09


# Re-creating all the PM scanners on all the netsims (V-Farm)
## emicmcf - No point in trying this until/ if we setup PM configuration on netsims
#ssh netsim@ieatnetsimv5051-01 '/netsim_users/pms/bin/scanners.sh -a create'
#ssh netsim@ieatnetsimv5051-02 '/netsim_users/pms/bin/scanners.sh -a create'
#ssh netsim@ieatnetsimv5051-03 '/netsim_users/pms/bin/scanners.sh -a create'
#ssh netsim@ieatnetsimv5051-04 '/netsim_users/pms/bin/scanners.sh -a create'
#ssh netsim@ieatnetsimv5051-05 '/netsim_users/pms/bin/scanners.sh -a create'
#ssh netsim@ieatnetsimv5051-06 '/netsim_users/pms/bin/scanners.sh -a create'
#ssh netsim@ieatnetsimv5051-07 '/netsim_users/pms/bin/scanners.sh -a create'
#ssh netsim@ieatnetsimv5051-09 '/netsim_users/pms/bin/scanners.sh -a create'



#/opt/ericsson/enmutils/bin/smoker launcher
#/opt/ericsson/enmutils/bin/enm_check

function update_enm_utils(){
         nexus='https://arm1s11-eiffel004.eiffel.gic.ericsson.se:8443/nexus'
	 gr='com.ericsson.dms.torutility'
	 art='ERICtorutilitiesinternal_CXP9030579'
	 ver=`/usr/bin/repoquery -a --repoid=ms_repo --qf "%{version}" ERICtorutilities_CXP9030570`
         wget -O $art-$ver.rpm "$nexus/service/local/artifact/maven/redirect?r=releases&g=${gr}&a=${art}&v=${ver}&e=rpm"

         rpm -Uvh ERICtorutilitiesinternal_CXP9030579-${ver}.rpm

         art='ERICdeploymentvalidation_CXP9032314'

         wget -O $art-$ver.rpm "$nexus/service/local/artifact/maven/redirect?r=releases&g=${gr}&a=${art}&v=${ver}&e=rpm"

         rpm -Uvh ERICdeploymentvalidation_CXP9032314-${ver}.rpm

         rm `pwd`/ERICtorutilitiesinternal_CXP9030579-${ver}.rpm
         rm `pwd`/ERICdeploymentvalidation_CXP9032314-${ver}.rpm
}

