#!/bin/bash

# Check we are user root before we do anything else.
[[ "$EUID" -ne 0 ]] && { echo "Only root user can run this script." ; exit 1; }

MEDIA_URL="https://cifwk-oss.lmera.ericsson.se/ENM/content/"
STORAGE_LOCATION="/ericsson/enm/dumps/"


_usage() {
        echo "Script that does a sanity check of SED vs Deployment Description"
        echo
        echo " Usage: $0 {  -d enm_product_set  |  -g server_id  |  -e path_to_enm_iso  |  -s path_to_sed  -f path_to_deploy_descr  }"
        echo
        echo "where"
        echo "  -d      Download ENM ISO from CIFWK site by providing relevant Product Set. Script will verify ISO not corrupt"
        echo "  -g      Get SED master file for specified Server ID from CIFWK website"
        echo "  -e      Extract Deployment Description from ENM ISO location"
        echo "  -s      SED to be used for validation"
        echo "  -f      Deployment Description to be used for validation" 
        echo
        echo "Note: There is now a MainTrack jenkins job that supposedly does this Sanity check on servers."
        echo "      It is located at:"
        echo "      https://fem114-eiffel004.lmera.ericsson.se:8443/jenkins/view/Utilities/job/DMTSanityCheck"
        echo
        exit 0 
}


_download_enm_iso() {
        RELEASE=$(echo $PRODUCT_SET | awk -F'.' '{print $1}')
        [[ "$(echo $RELEASE | egrep '^1[6789]')" == "" ]] && { echo "Doesnt seem to be a valid Product Set provided. Exiting"; exit; }

        SPRINT_NUMBER=$(echo $PRODUCT_SET | awk -F'.' '{print $2}')
        SPRINT="${RELEASE}.${SPRINT_NUMBER}"


        [[ ! -d $STORAGE_LOCATION ]] && mkdir $STORAGE_LOCATION

        FREE_SPACE=$(df -h $STORAGE_LOCATION | tail -1 | awk '{print $(NF-2)}' | awk -F'[A-Z]' '{print $1}')
        [[ $FREE_SPACE -lt 10 ]] && (echo "Insufficient space (${FREE_SPACE}GB) in $STORAGE_LOCATION to continue...exiting"; exit;)


        echo
        echo "#### Fetching the Product Set Info page from the Media server ($MEDIA_URL/$SPRINT/$PRODUCT_SET)"
        echo "Command Used: wget --no-check-certificate $MEDIA_URL/$SPRINT/$PRODUCT_SET -O $STORAGE_LOCATION/ps_info.$PRODUCT_SET"
        wget --no-check-certificate $MEDIA_URL/$SPRINT/$PRODUCT_SET -O $STORAGE_LOCATION/ps_info.$PRODUCT_SET
        ENM_ISO_URL=$( egrep iso $STORAGE_LOCATION/ps_info.$PRODUCT_SET | egrep enm | egrep Athlone | perl -pe 's/.*href=\"(.*ERICenm.*iso)\".*/$1/')
        ENM_ISO_FILE=$(echo $ENM_ISO_URL | awk -F'/' '{print $NF}')

        echo
        echo "#### Fetching the ENM ISO from here:"
        echo $ENM_ISO_URL
        echo "and storing in /software/autoDeploy/$ENM_ISO_FILE"
        echo "Command Used: wget --no-check-certificate $ENM_ISO_URL -O $STORAGE_LOCATION/$ENM_ISO_FILE"
        wget --no-check-certificate $ENM_ISO_URL -O $STORAGE_LOCATION/$ENM_ISO_FILE

        echo
        echo "#### Fetching the md5 file"
        echo "Command Used: wget --no-check-certificate $ENM_ISO_URL.md5 -O $STORAGE_LOCATION/$ENM_ISO_FILE.md5"
        wget --no-check-certificate $ENM_ISO_URL.md5 -O $STORAGE_LOCATION/$ENM_ISO_FILE.md5

        echo 
        echo "#### Checking MD5 values"
        MD5_VALUE_FROM_ISO_FILE=$(md5sum $STORAGE_LOCATION/$ENM_ISO_FILE | awk '{print $1}')
        echo MD5_VALUE_FROM_ISO_FILE=$MD5_VALUE_FROM_ISO_FILE
        MD5_VALUE_FROM_MD5_FILE=$(cat $STORAGE_LOCATION/$ENM_ISO_FILE.md5)
        echo MD5_VALUE_FROM_MD5_FILE=$MD5_VALUE_FROM_MD5_FILE

        [[ "$MD5_VALUE_FROM_ISO_FILE" == "$MD5_VALUE_FROM_MD5_FILE" ]] && echo "MD5 values match" || echo "Corrupt ISO. Problem with download. Try wget manually"

        echo
        echo "ENM ISO downloaded to following location:"
        ls -rtlh $STORAGE_LOCATION/$ENM_ISO_FILE

        exit 0
}



_download_master_sed() {

        echo
        echo "#### Fetching the master SED for $SERVERID..."
        SED_FILE="$STORAGE_LOCATION/SED_master"
        curl -s https://cifwk-oss.lmera.ericsson.se/api/deployment/$SERVERID/sed/master/generate/ > $SED_FILE
        echo "...done"

        SED_VERSION=$(head -1 $SED_FILE | awk '{print $NF}' | tr '\n' ' ' | tr '\r' ' ' | sed 's/ //g')
        NEW_SED_FILE="${SED_FILE}_version${SED_VERSION}_server${SERVERID}.cfg"
        mv $SED_FILE $NEW_SED_FILE

        echo "#### SED master (version $SED_VERSION) stored here:"
        ls -rtlh $NEW_SED_FILE
        echo

        exit 0

}
_extract_deployment_description_from_enm_iso() {

	PATH_TO_ENM_ISO=$STORAGE_LOCATION/$ENM_ISO
	[[ ! -f $PATH_TO_ENM_ISO ]] && (echo "ENM_ISO file not found"; exit )

        CMD_ARG="/opt/ericsson/enminst/log/cmd_arg.log"
        [[ ! -f $CMD_ARG ]] && { echo "enminst file $CMD_ARG not found"; exit 1; } 

        # Get the Deployment Description filename being used for this server - assuming that it doesnt change from 1st one ever used on it
        CURRENT_DD_FILE=$(for ITEM in $(head -1 $CMD_ARG); do echo -n $(echo $ITEM | egrep xml); done | awk -F'/' '{print $NF}')

        # Create mountpoint
        MOUNT_DIR="$STORAGE_LOCATION/enm_iso_mountpoint"
        [[ ! -d $MOUNT_DIR ]] && mkdir -p $MOUNT_DIR

        # Check if mountpoint is already mounted and if so, unmount it
        CHECK_IS_MOUNTED=$(mount | egrep enm_iso_mountpoint)
        [[ ! -z $CHECK_IS_MOUNTED ]] && umount $MOUNT_DIR

        # Mount the ENM ISO
        [[ -f $PATH_TO_ENM_ISO ]] && mount -o loop $PATH_TO_ENM_ISO $MOUNT_DIR

        # Get the Deployment Templates RPM from mounted ISO
        DEPLOY_TEMPLATES_RPM=$(find $MOUNT_DIR | egrep ERICenmdeploymenttemplates)

        # Extract all files from the DT RPM to current dir
        DT_DIR="$STORAGE_LOCATION/.extracted_software"
        [[ -d $DT_DIR ]] && rm -rf $DT_DIR; mkdir $DT_DIR
        PWD=$(pwd)
	cd $DT_DIR
        rpm2cpio $DEPLOY_TEMPLATES_RPM | cpio -idmv > /dev/null 2>/dev/null
        cd $PWD

        # Get the relevant DD from the RPM and make copy of it
        EXTRACTED_DD_FILE=$(find $DT_DIR | egrep $CURRENT_DD_FILE)
        cp -p $EXTRACTED_DD_FILE $STORAGE_LOCATION 
        DD_FILENAME=$(echo $EXTRACTED_DD_FILE | awk -F'/' '{print $NF}')
        NEW_DD_FILE=$STORAGE_LOCATION/$DD_FILENAME

        # Unmount ENM ISO, remove mountpoint and remove the extracted RPM artefacts
        umount $MOUNT_DIR
        rmdir $MOUNT_DIR
        rm -rf $DT_DIR

        echo "Deployment Description extracted from ENM ISO:"
        ls -rtl $NEW_DD_FILE

        exit 0
}



_validate_sed_against_deployment_description() {
        echo "Performing validation of SED against Deployment Description"

        [[ ! -f $SED_FILE ]] && (echo "SED file not found. Exiting"; exit 0 )
        [[ ! -f $DD_FILE ]] && (echo "DD file not found. Exiting"; exit 0 )


        echo 
        echo "Extracting parameters from Deployment Description file"
        DD_PARAMETERS=$(cat $DD_FILE | perl -ne 'while ($_ =~ m/%%(.*?)%%/g) { print "$1\n"; }' | sort -u )

        echo
        MISSING=0 
        echo "List of parameters that are listed in Deployment Description but not listed in SED File:"
        for PARAMETER in $DD_PARAMETERS; do 
                # Exclude some unimportant stuff
                [[ "$(echo $PARAMETER | egrep 'ERIC.*image|uuid_ms|vm_ssh_key')" != "" ]] && continue

                # Simplify the PARAMETER by removing "_password_encrypted"
                PARAMETER=$(echo $PARAMETER | sed 's/_password_encrypted//');

                # Print PARAMETER if it is not listed in SED
                [[ "$(egrep ^$PARAMETER $SED_FILE)" == "" ]] && { echo $PARAMETER; ((MISSING++)); }
        done 

        [[ $MISSING -ne 0 ]] && echo "SED missing some parameters that are listed in DD!!!" || echo " - no problems detected"

        echo

        EMPTY=0
        echo "List of parameter that dont have assigned values in SED but require a value according to Deployment Description:"

        for PARAMETER in $(cat -vet $SED_FILE | egrep '=\$|=\^M' | awk -F'=' '{print $1}'); do
                COUNT=$(egrep -c "%%${PARAMETER}%%" $DD_FILE)
                [[ $COUNT -ne 0 ]] && { echo $PARAMETER; ((EMPTY++)); }
        done

        echo
        [[ $EMPTY -ne 0 ]] && echo "SED has some manditory parameters that are not set and therefore upgrade will fail!!!" } || echo " - no problems detected"
	echo

  
        [[ $MISSING -gt 0 || $EMPTY -gt 0 ]] && exit 1 || exit 0

}

[[ $# -eq 0 ]] && _usage

while getopts "d:e:g:s:f:" opt; do
    case $opt in
        d ) PRODUCT_SET=$OPTARG; _download_enm_iso ;;
        e ) ENM_ISO=$OPTARG; _extract_deployment_description_from_enm_iso ;;
        g ) SERVERID=$OPTARG; _download_master_sed ;;
        s ) SED_FILE=$OPTARG ;;
        f ) DD_FILE=$OPTARG ;;
        * ) echo "Invalid input ${opt}"; _usage; exit 1 ;;
    esac
done


_validate_sed_against_deployment_description
