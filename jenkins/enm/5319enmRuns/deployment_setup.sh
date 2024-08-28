#!/bin/bash

# Create cron entry to upload stats to DDPI
mkdir -p /etc/cron.d
#echo "0 * * * * root /opt/ericsson/ddc/bin/ddcDataUpload -s ENM319" > /etc/cron.d/ddc_upload
echo "30 0-22 * * * root /opt/ericsson/ddc/bin/ddcDataUpload -s ENM330 -d ddpenm2" > /etc/cron.d/ddc_upload
echo "10 23 * * * root /opt/ericsson/ddc/bin/ddcDataUpload -s ENM330 -d ddpenm2" >> /etc/cron.d/ddc_upload
chmod 0644 /etc/cron.d/ddc_upload

#Add date to history file
echo 'export HISTTIMEFORMAT="%h/%d - %H:%M:%S "' >> ~/.bashrc

#Collect DDC data from netsims
echo "ieatnetsimv5030-01.athtem.eei.ericsson.se=NETSIM" >> /var/ericsson/ddc_data/config/server.txt
echo "ieatnetsimv5030-02.athtem.eei.ericsson.se=NETSIM" >> /var/ericsson/ddc_data/config/server.txt

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

         #temp workaround to revert to older version
         #/opt/ericsson/enmutils/.deploy/update_enmutils_rpm 4.23.12 --prod-and-int-only
}

update_enm_utils to latest version
/opt/ericsson/enmutils/.deploy/update_enmutils_rpm -l


# Add License file to enm
/opt/ericsson/enmutils/bin/cli_app 'lcmadm install file:LTE_5MHZ_SC.txt' /root/rvb/licenses/LTE_5MHZ_SC.txt
# Add SGSN License file to enm
/opt/ericsson/enmutils/bin/cli_app 'lcmadm install file:SGSN-MMEkSAU.txt' /root/rvb/licenses/SGSN-MMEkSAU.txt

touch /var/ericsson/ddc_data/config/MONITOR_SFS
touch /var/ericsson/ddc_data/config/MONITOR_CLARIION


echo $@
for HOST in $@
do
        echo 'Copying LMS RSA keys to: '$HOST
        /usr/bin/expect -d /root/rvb/copy-rsa-key-to-netsim.exp $HOST
done


# Check the state of the cluster
#set -ex
#/opt/ericsson/enmutils/bin/enm_check
#/opt/ericsson/enmutils/bin/smoker launcher
/opt/ericsson/enminst/bin/enm_healthcheck.sh --action vcs_service_group_healthcheck




