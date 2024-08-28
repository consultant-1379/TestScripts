#!/bin/bash

BIN_DIR=`dirname $0`
BIN_DIR=`cd ${BIN_DIR} ; pwd`
. ${BIN_DIR}/functions

createScanners() {
    
    CMD_FILE=/tmp/create_scanners.cmd
    if [ -r ${CMD_FILE} ] ; then
	rm ${CMD_FILE}
    fi

    for SIM in $LIST ; do
    # WRAN
	SIM_TYPE=`getSimType ${SIM}`
	SIM_NAME=`ls /netsim/netsimdir | grep ${SIM} | grep -v zip`

	if [ "${SIM_TYPE}" = "WRAN" ] ; then	    
	    cat >> ${CMD_FILE} <<EOF
.open ${SIM_NAME}

.selectnetype RNC
createscanner2:id=1,measurement_name="PREDEF.10000.UETR";
createscanner2:id=2,measurement_name="PREDEF.10001.UETR";
createscanner2:id=3,measurement_name="PREDEF.10002.UETR";
createscanner2:id=4,measurement_name="PREDEF.10003.UETR";
createscanner2:id=5,measurement_name="PREDEF.10004.UETR";
createscanner2:id=6,measurement_name="PREDEF.10005.UETR";
createscanner2:id=7,measurement_name="PREDEF.10006.UETR";
createscanner2:id=8,measurement_name="PREDEF.10007.UETR";
createscanner2:id=9,measurement_name="PREDEF.10008.UETR";
createscanner2:id=10,measurement_name="PREDEF.10009.UETR";
createscanner2:id=11,measurement_name="PREDEF.10010.UETR";
createscanner2:id=12,measurement_name="PREDEF.10011.UETR";
createscanner2:id=13,measurement_name="PREDEF.10012.UETR";
createscanner2:id=14,measurement_name="PREDEF.10013.UETR";
createscanner2:id=15,measurement_name="PREDEF.10014.UETR";
createscanner2:id=16,measurement_name="PREDEF.10015.UETR";
createscanner2:id=17,measurement_name="PREDEF.20000.CTR";
createscanner2:id=18,measurement_name="PREDEF.20001.CTR";
createscanner2:id=19,measurement_name="PREDEF.30000.GPEH";
createscanner2:id=20,measurement_name="PREDEF.30001.GPEH";
createscanner2:id=21,measurement_name="PREDEF.30002.GPEH";
createscanner2:id=22,measurement_name="PREDEF.30003.GPEH";
createscanner2:id=23,measurement_name="PREDEF.30004.GPEH";
createscanner2:id=24,measurement_name="PREDEF.30005.GPEH";
createscanner2:id=25,measurement_name="PREDEF.30006.GPEH";
createscanner2:id=26,measurement_name="PREDEF.30007.GPEH";
createscanner2:id=27,measurement_name="PREDEF.30008.GPEH";
createscanner2:id=28,measurement_name="PREDEF.30009.GPEH";
createscanner2:id=29,measurement_name="PREDEF.30010.GPEH";
createscanner2:id=30,measurement_name="PREDEF.30011.GPEH";
createscanner2:id=31,measurement_name="PREDEF.30012.GPEH";
createscanner2:id=32,measurement_name="PREDEF.30013.GPEH";
createscanner2:id=33,measurement_name="PREDEF.30014.GPEH";
createscanner2:id=34,measurement_name="PREDEF.30015.GPEH";
createscanner2:id=35,measurement_name="PREDEF.30016.GPEH";
createscanner2:id=36,measurement_name="PREDEF.30017.GPEH";
createscanner2:id=37,measurement_name="PREDEF.30018.GPEH";
createscanner2:id=38,measurement_name="PREDEF.30019.GPEH";
createscanner2:id=39,measurement_name="PREDEF.30020.GPEH";
createscanner2:id=40,measurement_name="PREDEF.30021.GPEH";
createscanner2:id=41,measurement_name="PREDEF.30022.GPEH";
createscanner2:id=42,measurement_name="PREDEF.30023.GPEH";
createscanner2:id=43,measurement_name="PREDEF.PRIMARY.STATS",state="ACTIVE";
createscanner2:id=44,measurement_name="PREDEF.SECONDARY.STATS",state="ACTIVE";

.selectnetype RBS
createscanner2:id=100,measurement_name="PREDEF.PRIMARY.STATS",state="ACTIVE";
createscanner2:id=110,measurement_name="PREDEF.RBS.GPEH";
EOF
	elif [ "${SIM_TYPE}" = "LTE" ] ; then
	    cat >> ${CMD_FILE} <<EOF
.open ${SIM_NAME}
.select network
.start
pmdata:disable;
createscanner2:id=1,measurement_name="PREDEF.10000.CELLTRACE";
createscanner2:id=2,measurement_name="PREDEF.10001.CELLTRACE";
createscanner2:id=3,measurement_name="PREDEF.10002.CELLTRACE";
createscanner2:id=4,measurement_name="PREDEF.10003.CELLTRACE";
createscanner2:id=5,measurement_name="PREDEF.10004.CELLTRACE";
createscanner2:id=6,measurement_name="PREDEF.10005.CELLTRACE";
createscanner2:id=100,measurement_name="PREDEF.STATS",state="ACTIVE";
EOF
	fi
    done

    if [ -e ${CMD_FILE} ] ; then
        log "INFO: Creating scanners"
        /netsim/inst/netsim_pipe < ${CMD_FILE} 
    fi
}

deleteScanners() {
    CMD_FILE=/tmp/delete_scanners.cmd
    if [ -r ${CMD_FILE} ] ; then
	rm ${CMD_FILE}
    fi

    for SIM in $LIST ; do	
	SIM_TYPE=`getSimType ${SIM}`
	SIM_NAME=`ls /netsim/netsimdir | grep ${SIM} | grep -v zip`
	
	log "INFO: Reading scanners in ${SIM}"

	NE_TYPE_LIST=""
	if [ "${SIM_TYPE}" = "WRAN" ] ; then
	    NE_TYPE_LIST="RNC RBS"		
	elif [ "${SIM_TYPE}" = "LTE" ] ; then
	    NE_TYPE_LIST="ERBS"
	fi

	echo ".open ${SIM_NAME}" >> ${CMD_FILE}

	for NE_TYPE in ${NE_TYPE_LIST} ; do
	    /netsim/inst/netsim_pipe <<EOF > /tmp/scannerlist.txt
.open ${SIM_NAME}
.select network
showscanners2;
EOF
	    echo ".select network" >> ${CMD_FILE}
	    # New a sort -u cause now we're get an output per NE
            cat /tmp/scannerlist.txt | awk '{ if ( $2 ~ /^PREDEF/ ) {print $1} }' | sort -un \
                | awk '{ printf "deletescanner2:id=%d;\n", $1; }' \
                >> ${CMD_FILE}
	done
    done    

    if [ -e ${CMD_FILE} ] ; then
        log "INFO: Deleting scanners"
        /netsim/inst/netsim_pipe < ${CMD_FILE} 
    fi
}

DEPLOY=0
ACTION=""
while getopts "a:s:d" flag ; do
    case "$flag" in
	a) ACTION="${OPTARG}";;
        d) DEPLOY=1;;
        s) SERVERS="${OPTARG}";;
	
	*) echo "ERROR: Unknown arg $flag"
	   exit 1;;
    esac
done

if [ -z "${ACTION}" ]; then
    echo  "ERROR: Usage $0 -g cfg -d [-s servers]"
    exit 1
fi

if [ ${DEPLOY} -eq 1 ] ; then
    if [ -z "${SERVERS}" ] ; then
	. ${CFG} > /dev/null
    fi
    if [ -z "${SERVERS}" ] ; then
	log "ERROR: SERVERS not set"
	exit 1
    fi

    for SERVER in ${SERVERS} ; do
	log ${SERVER}
	rsh -l netsim ${SERVER} "/netsim_users/pms/bin/scanners.sh -a ${ACTION} > /netsim_users/pms/logs/scanners.log 2>&1"
	rsh -l netsim ${SERVER} "grep -i error /netsim_users/pms/logs/scanners.log" | grep -i error > /dev/null
	if [ $? -eq 0 ] ; then
	    log "ERROR: Failed, see /netsim_users/pms/logs/scanners.log on ${SERVER} for more detail"
	    exit 1
	fi
    done
else
    . /netsim/netsim_cfg > /dev/null 2>&1

    if [ "${ACTION}" = "create" ] ; then
	deleteScanners
	createScanners
    else
	deleteScanners
    fi
fi

