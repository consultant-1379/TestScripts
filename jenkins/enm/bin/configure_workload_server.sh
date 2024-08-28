#!/bin/bash 
 

_check_required_packages() { 
        echo
        echo "################################################"
        echo "$FUNCNAME - $(date)"

        echo "# Checking that required packaged are installed" 
        DIR="/var/tmp" 
        rpm -qa > $DIR/rpm.out 

        PACKAGES_REQUIRED="python-setuptools rsync wget openssh-clients openjdk"
        PACKAGES_MISSING=""

        for PACKAGE in $PACKAGES_REQUIRED
        do
                [[ -z $(egrep $PACKAGE $DIR/rpm.out) ]] && PACKAGES_MISSING="$PACKAGES_MISSING $PACKAGE" 
        done

        [[ ! -z $PACKAGES_MISSING ]] && { echo "Packages missing: $PACKAGES_MISSING"; echo "Following packages are required: $PACKAGES_REQUIRED"; echo "Exiting now"; exit 1; } 
}


_check_ntp_setup() {
        echo
        echo "################################################"
        echo "$FUNCNAME - $(date)"
 
        echo "# Checking NTP setup"
        NTP_FILE="/etc/ntp.conf" 
        NTP_SERVER1="server 159.107.173.12" 
        NTP_SERVER2="server 159.107.173.2" 
         
        [[ -z $(egrep "^$NTP_SERVER1" $NTP_FILE) ]] && { echo "$NTP_SERVER prefer"; REBOOT=1; } >> $NTP_FILE
        [[ -z $(egrep "^$NTP_SERVER2" $NTP_FILE) ]] && { echo "$NTP_SERVER2"; REBOOT=1; } >> $NTP_FILE
        [[ $REBOOT -eq 1 ]] && { echo "Config file updated with new servers. Restarting ntpd..."; echo "service ntpd restart"; echo "...done"; }

}


_checking_open_files_limit(){
        echo
        echo "################################################"
        echo "$FUNCNAME - $(date)"

        echo "# Checking limit of open files per process"
        echo "Note: Logic in confluence needs to be changed for this part"
        CURRENT_ULIMIT=$(ulimit -n)
        NEW_LIMIT=2048
        [[ $CURRENT_ULIMIT -ne 2048 ]] && { echo "Increasing # of open of files allowed per process to $NEW_LIMIT"; ulimit -n $NEW_LIMIT; ulimit -n; }
}


_checking_proxy_server_setup() {
        echo
        echo "################################################"
        echo "$FUNCNAME - $(date)"

        echo "# Removing HTTP Proxy server from bashrc if exists there"
        HTTP_PROXY="export http_proxy="
        HTTPS_PROXY="export https_proxy="
 
        BASHRC_FILE="/root/.bashrc"
        [[ -z $(egrep "$HTTP_PROXY" $BASHRC_FILE) ]] && { egrep -v $HTTP_PROXY $BASHRC_FILE > $BASHRC_FILE.tmp; mv $BASHRC_FILE.tmp $BASHRC_FILE; }
        [[ -z $(egrep "$HTTPS_PROXY" $BASHRC_FILE) ]] && { egrep -v $HTTPS_PROXY $BASHRC_FILE > $BASHRC_FILE.tmp; mv $BASHRC_FILE.tmp $BASHRC_FILE; }
}


_reading_LMS_HOST() {
        echo
        echo "################################################"
        echo "$FUNCNAME - $(date)"

        echo "# Reading LMS_HOST"
        LMS_HOST=$(source /root/.bashrc; echo $LMS_HOST)
        [[ -z $LMS_HOST ]] && { echo "LMS_HOST missing from .bashrc file...Exiting"; exit 1; }
}


_enable_passwordless_access_to_lms() {
        echo
        echo "################################################"
        echo "$FUNCNAME - $(date)"
 
        echo "# Enabling Password-less access to LMS"
        ENABLED_PASSWORDLESS_ACCESS_SCRIPT="/var/tmp/copy-rsa-key-to-remote-host.exp"
        [[ -f $ENABLED_PASSWORDLESS_ACCESS_SCRIPT ]] && $ENABLED_PASSWORDLESS_ACCESS_SCRIPT $LMS_HOST root 12shroot || { echo "Script not found: $ENABLED_PASSWORDLESS_ACCESS_SCRIPT"; exit 1; }
}


_fetch_torutilities_packages_from_nexus() {
        echo
        echo "################################################"
        echo "$FUNCNAME - $(date)"
  
        echo "# Fetching Torutilities packages from NEXUS"
        NEXUS_SERVER="https://arm901-eiffel004.athtem.eei.ericsson.se:8443"
        NEXUS_URL="$NEXUS_SERVER/nexus/content/repositories/enm_releases/com/ericsson/dms/torutility/"
        cd /var/tmp
        echo " - grab version of ERICtorutilities package from LMS"
        PRODUCTION_VERSION=$(ssh root@$LMS_HOST '/usr/bin/repoquery --qf  %{version} ERICtorutilities_CXP9030570' | tail -1 )

        echo " - fetch Production package"
        PRODUCTION_RPM=ERICtorutilities_CXP9030570
        wget -O /var/tmp/${PRODUCTION_RPM}-${PRODUCTION_VERSION}.rpm $NEXUS_URL/$PRODUCTION_RPM/$PRODUCTION_VERSION/${PRODUCTION_RPM}-${PRODUCTION_VERSION}.rpm

        echo " - fetch Internal package"
        INTERNAL_RPM=ERICtorutilitiesinternal_CXP9030579
        wget -O /var/tmp/${INTERNAL_RPM}-${PRODUCTION_VERSION}.rpm $NEXUS_URL/$INTERNAL_RPM/$PRODUCTION_VERSION/${INTERNAL_RPM}-${PRODUCTION_VERSION}.rpm
}


_install_torutilities_package() {
        echo
        echo "################################################"
        echo "$FUNCNAME - $(date)"

        echo "# Installing Packages"
        echo "- commented out currently"
        echo "rpm -ivh $PRODUCTION_RPM $INTERNAL_RPM"
}


_enable_passwordless_access_to_enm_virtual_machines() {
        echo
        echo "################################################"
        echo "$FUNCNAME - $(date)"
 
        echo "# Copy vm_private_key from LMS to allow passwordless access to VM's on ENM"
        echo "- commented out currently"
        echo "scp root@$LMS_HOST:/root/.ssh/vm_private_key /root/.ssh"
}


_installing_ddc_on_workload_server() {
        echo
        echo "################################################"
        echo "$FUNCNAME - $(date)"

        echo "# Installing DDC on this server"
        echo " - copy DDC package from LMS repo"
        echo "scp root@$LMS_HOST:/var/www/html/ENM_common/ERICddc_*.rpm /var/tmp"

        echo " - allowing DDC to install on non ENM or Netsim server"
        touch /var/tmp/DDC_GENERIC
 
        echo " - install DDC package"
        echo "- commented out currently"
        echo "rpm -ivh /var/tmp/ERICddc* --nodeps"
}


_enable_cron_to_copy_profiles-log_to_lms() { 
        echo
        echo "################################################"
        echo "$FUNCNAME - $(date)"

        echo "# Enable cron job to copy profiles.log files to be copied to LMS"
        echo "- commented out currently"
        echo "#*/31 * * * * scp /var/log/enmutils/profiles.log root@$LMS_HOST:/var/log/enmutils" > /etc/cron.d/enmutils_scp_profiles_log
        cat /etc/cron.d/enmutils_scp_profiles_log
}


_check_required_packages
_check_ntp_setup
_checking_open_files_limit
_checking_proxy_server_setup
_reading_LMS_HOST
_enable_passwordless_access_to_lms
_fetch_torutilities_packages_from_nexus
_install_torutilities_package
_enable_passwordless_access_to_enm_virtual_machines
_installing_ddc_on_workload_server
_enable_cron_to_copy_profiles-log_to_lms


echo "# Done"
