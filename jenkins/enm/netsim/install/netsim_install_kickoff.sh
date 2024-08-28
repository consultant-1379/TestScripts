#!/bin/bash

BASEDIR=`dirname $0`
CLUSTERID=$1
NETSIM_VERSION=$2
HOLDING_DIR_ON_JENKINS="/export/data/netsim_installation_files/${NETSIM_VERSION}"
TEMP_INSTALL_DIR_ON_NETSIM="/netsim/${NETSIM_VERSION}"


. ${BASEDIR}/../../functions

_fetch_so_called_verified_netsim_patches() {
    wget ${SOFTWARE_URL}/Patches/index.html
    grep -A3 Verified $HOLDING_DIR_ON_JENKINS/index.html | grep zip | sed -e 's/.*"\(.*\)".*/\1/g' |
    while read PATCH
    do
        echo ${SOFTWARE_URL}/Patches/$PATCH >> patch_urls
    done
    wget -i patch_urls
    rm -f patch_urls
    rm -f index.html
}

get_netsim_installation_files() {
    if [ -d $HOLDING_DIR_ON_JENKINS ]
    then
        rm -rf $HOLDING_DIR_ON_JENKINS
    fi
    mkdir -p $HOLDING_DIR_ON_JENKINS
    cd $HOLDING_DIR_ON_JENKINS
    MAIN_VER_NUM=$(($(echo "$NETSIM_VERSION" | cut -c 2)+4))
    VER_NUM=`echo "$NETSIM_VERSION" | cut -c 3`
    SOFTWARE_URL="http://netsim.lmera.ericsson.se/tssweb/netsim${MAIN_VER_NUM}.${VER_NUM}/released/NETSim_UMTS.${NETSIM_VERSION}"
    wget -nd -N --progress=dot:giga ${SOFTWARE_URL}/1_19089-FAB760956Ux.${NETSIM_VERSION}.zip
    wget -nd -N ${SOFTWARE_URL}/Unbundle.sh
    _fetch_so_called_verified_netsim_patches
}

do_not_install_some_patches() {
    rm -f $HOLDING_DIR_ON_JENKINS/P04983_UMTS_R29A.zip
    rm -f $HOLDING_DIR_ON_JENKINS/P05417_UMTS_R29D.zip
}

copy_installation_files_to_netsim() {
    execute_on_hosts "$NETSIMS" netsim "if [ -d $TEMP_INSTALL_DIR_ON_NETSIM ]; then rm -rf $TEMP_INSTALL_DIR_ON_NETSIM; fi; mkdir -p $TEMP_INSTALL_DIR_ON_NETSIM"
    scp_to_hosts "$NETSIMS" netsim "$HOLDING_DIR_ON_JENKINS/*" "$TEMP_INSTALL_DIR_ON_NETSIM"
}

get_netsims $CLUSTERID
copy_ssh_keys_to_netsims $NETSIMS
get_netsim_installation_files
do_not_install_some_patches
copy_installation_files_to_netsim
write_properties_files_for_child_builds
