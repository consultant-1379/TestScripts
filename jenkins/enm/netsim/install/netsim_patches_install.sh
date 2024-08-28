#!/bin/bash

[[ ! $# -eq 3 ]] && { echo "Usage: $0 <netsim> <netsim_version> <netsim_patch_list>"; exit 0; }

BASEDIR=`dirname $0`
NETSIM=$1
NETSIM_VERSION=$2
NETSIM_PATCH_LIST=$3
TEMP_INSTALL_DIR_ON_NETSIM="/netsim/${NETSIM_VERSION}"


. ${BASEDIR}/../../functions


install_netsim_patches() {
    PATCH_LIST=$(echo $NETSIM_PATCH_LIST | sed 's/_/ /g')
    for PATCH_ID in $PATCH_LIST
    do 
            PATCH_FILE=$(ssh netsim@$NETSIM "ls -rtl $TEMP_INSTALL_DIR_ON_NETSIM | egrep .*${PATCH_ID}_.*zip | tail -1 | awk '{print \$NF}'" | tail -1)
            [[ -z $PATCH_FILE ]] && { echo "Expected patch file for $PATCH_ID not found on $NETSIM ... exiting"; exit 1; }

            echo
            echo "Creating command file to install patch"
            echo "echo \".install patch $TEMP_INSTALL_DIR_ON_NETSIM/$PATCH_FILE force\" | /netsim/inst/netsim_pipe" > install_${PATCH_ID}.cmd

            echo
            echo "Copying command file to $NETSIM"
            scp install_${PATCH_ID}.cmd netsim@$NETSIM:$TEMP_INSTALL_DIR_ON_NETSIM/

            echo
            echo "Installing Patch: $PATCH_ID on $NETSIM"
            ssh netsim@$NETSIM "bash $TEMP_INSTALL_DIR_ON_NETSIM/install_${PATCH_ID}.cmd"

    done
}

show_patches_on_netsim() {
    for PATCH_ID in $PATCH_LIST
    do 
    	echo
    	echo "Creating command file to check patch install"
    	echo "echo \".show patch info\" | /netsim/inst/netsim_pipe | grep $PATCH_ID"  > check_install_${PATCH_ID}.cmd
	
	echo
	echo "Copying command file to netsim"
	scp check_install_${PATCH_ID}.cmd netsim@$NETSIM:$TEMP_INSTALL_DIR_ON_NETSIM/
	
    	echo
    	echo "Checking that Patch is reported as being installed by netsim"
    	RESULT=$(ssh netsim@$NETSIM "bash $TEMP_INSTALL_DIR_ON_NETSIM/check_install_${PATCH_ID}.cmd")
    	[[ -z "echo $RESULT | egrep $PATCH_ID" ]] && { echo "Patch $PATCH_ID doesnt appear to be installed"; exit 1; } || echo "$RESULT"

    done

}

cleanup_files() {
    for PATCH_ID in $PATCH_LIST
    do
        ssh netsim@$NETSIM "rm -f $TEMP_INSTALL_DIR_ON_NETSIM/*${PATCH_ID}*.cmd $TEMP_INSTALL_DIR_ON_NETSIM/*${PATCH_ID}*.zip"
        rm -f *{$PATCH_ID}*.cmd 

    done
}

copy_ssh_keys_to_netsims $NETSIM
install_netsim_patches
show_patches_on_netsim
cleanup_files

