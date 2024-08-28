#!/bin/bash -e

STORAGE_LOCATION="/ericsson/enm/dumps/"

_usage() {
        echo "Script to run DMT Sanity Checker"
        echo "Usage: $0 -p product_set [ -d ]"
        echo
        echo " where "
        echo "     -p       product_set will be checked to determine if SED MASTER needs to updated for this deployment"
        echo "     -d       download ENM ISO. It may already have been downloaded so this is optional to avoid a re-download"
        echo
        echo "  e.g. $0 -p 16.15.59 -d"
        echo "  - will download ENM ISO corresponding to that product set and do a sanity check using that"
        echo
        echo "Note: script is designed to be run on the deployment that is being checked to avoid confusion etc"
        echo
        exit 0
}


_download_enm_iso() {
        echo
        echo "# Downloading the ENM ISO corresponding to the Product Set:"
        COMMAND="/root/rvb/bin/validate_sed_against_dd.sh -d $PRODUCT_SET"
        echo " - Executing command:"
        echo "# $COMMAND"
        $COMMAND 

        [[ $? -ne 0 ]] && { echo "Problem downloading ENM ISO"; exit 1; }
        return 0
}


_download_sed() {
        echo 
        echo "# Downloading the SED (MASTER) for this deployment:"
        COMMAND="/root/rvb/bin/validate_sed_against_dd.sh -g $CLUSTER_ID"
        echo " - Executing command:"
        echo "# $COMMAND"
        $COMMAND

        [[ $? -ne 0 ]] && { echo "Problem downloading SED"; exit 1; } 
        return 0
}


_extract_dd() {
        echo
        echo "# Extracting the deployment description from the downloaded ENM ISO:"
        PATH_TO_ENM_ISO=$(ls -rtl $STORAGE_LOCATION | egrep 'ERICenm.*iso$' | tail -1 | awk '{print $NF}')
	[[ -z $PATH_TO_ENM_ISO ]] && { echo "No ENM ISO file found in $STORAGE_LOCATION ... need to specify -d option...exiting"; exit 1; }

        COMMAND="/root/rvb/bin/validate_sed_against_dd.sh -e $PATH_TO_ENM_ISO"
        echo " - Executing command:"
        echo "# $COMMAND"
        $COMMAND

        [[ $? -ne 0 ]] && { echo "Problem extracting DD from ENM ISO"; exit 1; }
        return 0
}


_check_sed_against_dd() {
        echo
        echo "# Checking SED against DD:"
        PATH_TO_DD=$(ls -rtl $STORAGE_LOCATION/*_dd.xml | tail -1 | awk '{print $NF}')
        PATH_TO_SED=$(ls -rtl $STORAGE_LOCATION/SED_master_version*cfg | tail -1 | awk '{print $NF}')
        COMMAND="/root/rvb/bin/validate_sed_against_dd.sh -s $PATH_TO_SED -f $PATH_TO_DD"
        echo " - Executing command:"
        echo "# $COMMAND"
        $COMMAND

        [[ $? -ne 0 ]] && { echo "SED not compatible with DD - needs to be investigated"; exit 1; }
        return 0
}


_get_cluster_id() {
        DDP_CONFIG_FILE="/var/ericsson/ddc_data/config/ddp.txt"
        CLUSTER_ID=$(cat $DDP_CONFIG_FILE | perl -pe 's/lmi_ENM(...)/$1/')
        [[ ! -z $CLUSTER_ID ]] && return 0 || { echo "DDP config file not populated $DDP_CONFIG_FILE ...unexpected situation...cant figure out cluster ID...exiting"; exit 1; }
}


_print_header() {
        echo "Running DMT Sanity Checker with following details:"
        echo " - Deployment: $CLUSTER_ID"
        echo " - Product Set: $PRODUCT_SET"
        return 0
 
}


_check_number_of_enm_iso_files() {
	NUM_OF_ENM_ISO_FILES=$(ls -rtlh $STORAGE_LOCATION | egrep ERICenm | egrep -c 'iso$')
	if [ $NUM_OF_ENM_ISO_FILES -gt 1 ]; then
		echo "Note: Multiple ENM ISO files exist at $STORAGE_LOCATION - remove unnecessary ones"
		ls -rtlh $STORAGE_LOCATION | egrep ERICenm | egrep 'iso$'
	fi
	return 0
}
			 

[[ $# -eq 0 ]] && _usage

while getopts "p:d" opt; do
    case $opt in
        p ) PRODUCT_SET=$OPTARG ;;
        d ) DOWNLOAD_ISO=1 ;; 
        * ) echo "Invalid input ${opt}"; _usage; exit 1 ;;
    esac
done



_get_cluster_id
_print_header
[[ $DOWNLOAD_ISO -eq 1 ]] && _download_enm_iso
_extract_dd
_download_sed
_check_sed_against_dd

echo 
echo "# No problems found - No changes required in DMT"

echo 
_check_number_of_enm_iso_files
