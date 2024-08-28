#!/bin/bash

DDC_DOWNLOAD_URL_PATH="https://arm1s11-eiffel004.eiffel.gic.ericsson.se:8443/nexus/content/repositories/releases/com/ericsson/cifwk/diagmon/ERICddc_CXP9030294/"

NETSIM=$1
DDC_RPM_FILE=$2

_usage() {
        echo "Script to install DDC on Netsim"
        echo "Usage: $0  netsim_machine  [ ddc_rpm_file ]"
        echo
        echo "Note: can download a particular DDC package VERSION (i.e. ddc_rpm_file) with the following command"
        echo "  # wget --http-user=USERID --ask-password $DDC_DOWNLOAD_URL_PATH/VERSION//ERICddc_CXP9030294-VERSION.rpm"
        echo "(replace VERSION with the required version to be downloaded)"
        echo
        exit 0

}




[[ -z $NETSIM ]] && _usage


echo "#### TASKS STARTED ####"


echo
echo "### Enabling password-less ssh access to $NETSIM"
/root/rvb/copy-rsa-key-to-remote-host.exp $NETSIM root

ssh $NETSIM date
[[ $? -ne 0 ]] && (echo "Problem with password-less access to $NETSIM ...cannot continue"; exit 1)

echo
echo "### Installing sysstat"
ssh $NETSIM "zypper --non-interactive rm sysstat"
ssh $NETSIM "zypper --non-interactive install sysstat"

echo
echo "### Installing cron entry to collect SAR data"
ssh $NETSIM 'echo "* * * * *    root [ -x /usr/lib64/sa/sa1 ] && exec /usr/lib64/sa/sa1 -S ALL 1 1" > /etc/cron.d/sysstat'
ssh $NETSIM 'echo "*/5 * * * *    root [ -x /usr/lib64/sa/sa2 ] && exec /usr/lib64/sa/sa2 -S ALL 1 1" >>/etc/cron.d/sysstat'
ssh $NETSIM "cat /etc/cron.d/sysstat"

echo
echo "### Copying ERICddc package to $NETSIM"
# [[ -z $DDC_RPM_FILE ]] && DDC_RPM_FILE=$(ls -rtl /var/www/html/ENM_common/ERICddc_*.rpm | tail -1 | awk '{print $NF}')
[[ -z $DDC_RPM_FILE ]] && DDC_RPM_FILE=$(ls -rtl /var/www/html/ENM_common/ERICddccore_*.rpm | tail -1 | awk '{print $NF}')
scp $DDC_RPM_FILE $NETSIM:/var/tmp/

echo
OLD_DDC=$(ssh $NETSIM rpm -qa | grep ddc_CXP)
echo "uninstalling" ${OLD_DDC}
ssh $NETSIM "rpm -e ${OLD_DDC}"
echo "### Installing DDC package on $NETSIM"
INSTALLED=$(ssh $NETSIM rpm -qa | egrep ddc)
[[ -z $INSTALLED ]] && OPTION="i" || OPTION="U"
echo OPTION=$OPTION
ssh $NETSIM "rpm -${OPTION}vh /var/tmp/ERICddccore*${VERSION}.rpm --nodeps" ;
echo "Turn on ddc service"
ssh $NETSIM "ssh $NETSIM  chkconfig ddc on"

if [ "$OPTION" == "U" ]; then
        echo
        echo "### Restarting DDC service"
        ssh $NETSIM "nohup service ddc restart > /dev/null 2>&1 &"
fi


echo
echo "### Checking to see if DDC service is started"
ssh $NETSIM  service ddc status

echo
echo "### Checking installed DDC version"
ssh $NETSIM  rpm -qa | egrep ddc

echo
echo "### Configure ntp"
NTP_FILE="/etc/ntp.conf"
NTP_SERVER1="server ranosdns2 prefer"
NTP_SERVER2="server ranosdns1"

ssh $NETSIM "sed -i 's/^server.*//' $NTP_FILE"
ssh $NETSIM "echo $NTP_SERVER1 >> $NTP_FILE"
ssh $NETSIM "echo $NTP_SERVER2 >> $NTP_FILE"
echo "### Config file updated with new servers. Restarting ntpd on $NETSIM..."
ssh $NETSIM "service ntp restart"
echo "...done"

echo "### Sync'ing with Master NTP servers"
ssh $NETSIM "/usr/sbin/rcntp ntptimeset"
echo "...done"

echo "#### TASKS COMPLETED ####"
