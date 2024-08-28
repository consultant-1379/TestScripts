#!/bin/bash

BASEDIR=`dirname $0`
CLUSTERID=$1
NETSIM_VERSION=$2
NETSIM_PATCH_LIST=$3
NETSIM_HOST=$4
HOLDING_DIR_ON_JENKINS="${BASEDIR}/netsim_installation_files/${NETSIM_VERSION}"
TEMP_INSTALL_DIR_ON_NETSIM="/netsim/${NETSIM_VERSION}"


. ${BASEDIR}/../../functions

_fetch_required_netsim_patches() {
    wget ${SOFTWARE_URL}/Patches/index.html
    PATCH_LIST=$(echo $NETSIM_PATCH_LIST | sed 's/_/ /g')
    for PATCH_ID in $PATCH_LIST
    do
    	grep -A3 erified $HOLDING_DIR_ON_JENKINS/index.html | egrep $PATCH_ID | grep zip | sed -e 's/.*"\(.*\)".*/\1/g' |
    	while read PATCH
    	do
    	    echo ${SOFTWARE_URL}/Patches/$PATCH >> patch_urls
    	done
    done

    wget -i patch_urls
    rm -f patch_urls
    rm -f index.html
}

get_netsim_installation_files() {
    mkdir -p $HOLDING_DIR_ON_JENKINS
    cd $HOLDING_DIR_ON_JENKINS
    VER_NUM=`echo "$NETSIM_VERSION" | cut -c 3`
    SOFTWARE_URL="http://netsim.lmera.ericsson.se/tssweb/netsim6.${VER_NUM}/released/NETSim_UMTS.${NETSIM_VERSION}"
    _fetch_required_netsim_patches
}

do_not_install_some_patches() {
    P1="P04983_UMTS_R29A"
    P2="P05417_UMTS_R29D"
    echo "Script hardcoded to ignore following patches: $P1 $P2"
    rm -f $HOLDING_DIR_ON_JENKINS/${P1}.zip
    rm -f $HOLDING_DIR_ON_JENKINS/${P2}.zip
}

copy_patch_files_to_netsim() {
    scp_to_hosts "$NETSIMS" netsim "$HOLDING_DIR_ON_JENKINS/*" "$TEMP_INSTALL_DIR_ON_NETSIM"
}

if [ ! -z $NETSIM_HOST ]
then
    NETSIMS=$NETSIM_HOST
else
    get_netsims $CLUSTERID
fi
copy_ssh_keys_to_netsims $NETSIMS
get_netsim_installation_files
do_not_install_some_patches
copy_patch_files_to_netsim
write_properties_files_for_child_builds
