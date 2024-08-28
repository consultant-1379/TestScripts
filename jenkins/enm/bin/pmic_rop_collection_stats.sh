#!/bin/bash

CLUSTER=`grep -ri san_siteId /software/autoDeploy/*site*|head -1 | awk -F '=ENM' '{print $2}'`
NETSIM=`grep netsim /root/rvb/deployment_conf/5${CLUSTER}.conf | head -1 | awk -F "\"" '{print $2}' | awk -F "-" '{print $1}'`
DATE=`date +%Y%m%d`
TIME=$1

nas_vip_enm_1=`grep -ri nas_vip_enm_1 /software/autoDeploy/*site*|head -1 | awk -F '=' '{print $2}'`
nas_vip_enm_2=`grep -ri nas_vip_enm_2 /software/autoDeploy/*site*|head -1 | awk -F '=' '{print $2}'`

if [ -d /ericsson/enm/dumps/pmic_collect_stats/ ]; then
	echo "/ericsson/enm/dumps/pmic_collect_stats/ already exists"
else
	echo "Creating directory /ericsson/enm/dumps/pmic_collect_stats/"
	mkdir -p /ericsson/enm/dumps/pmic_collect_stats/
fi

mkdir -p /ericsson/pmic1
mkdir -p /ericsson/pmic2
mount ${nas_vip_enm_1}:/vx/ENM${CLUSTER}-pm1 /ericsson/pmic1
mount ${nas_vip_enm_2}:/vx/ENM${CLUSTER}-pm2 /ericsson/pmic2

echo "Determining the number of each node type. Please wait....."
	for TYPE in `/opt/ericsson/enmutils/bin/cli_app "cmedit get * NetworkElement.neType" | grep neType | cut -d":" -f2 | sort -u`; do echo -en "${TYPE}:\t"; /opt/ericsson/enmutils/bin/cli_app "cmedit get * NetworkElement -ne=${TYPE} -cn" | tail -1;done| sed "s/^/\t/g"

NUM_ERBS=`cli_app 'cmedit get * NetworkElement -netype=ERBS -cn' | tail -1 | awk '{print $1}'`
NUM_LTE_DG2=`cli_app 'cmedit get * NetworkElement -ne=RadioNode' |grep -ci dg2`
NUM_MSRBS=`cli_app 'cmedit get * NetworkElement -ne=RadioNode' |grep -ci MSRBS`
NUM_MGW=`cli_app 'cmedit get * NetworkElement -netype=MGW -cn' | tail -1 | awk '{print $1}'`
NUM_SGSNMME=`cli_app 'cmedit get * NetworkElement -netype=SGSN-MME -cn' | tail -1 | awk '{print $1}'`
NUM_Router6672=`cli_app 'cmedit get * NetworkElement -netype=Router6672 -cn' | tail -1 | awk '{print $1}'`
NUM_RBS=`cli_app 'cmedit get * NetworkElement -ne=RBS -cn' | tail -1 | awk '{print $1}'`
NUM_RNC=`cli_app 'cmedit get * NetworkElement -ne=RNC -cn' | tail -1 | awk '{print $1}'`
NUM_EPG=`cli_app 'cmedit get * NetworkElement -ne=EPG -cn' | tail -1 | awk '{print $1}'`
NUM_MTAS=`cli_app 'cmedit get * NetworkElement -ne=MTAS -cn' | tail -1 | awk '{print $1}'`

#echo "ERBS: ${NUM_ERBS}"
#echo "RadioNode: ${NUM_RADIONODE}"
#echo "MGW: ${NUM_MGW}"
#echo "SGSN-MME: ${NUM_SGSNMME}"
#echo "Router6672: ${NUM_Router6672}"

echo "Generating list of PM Files collected for the ${TIME} ROP and loading into /ericsson/enm/dumps/pmic_collect_stats/rop_${TIME}_file_list.txt"
time find /ericsson/pmic*/ -name [AB]${DATE}.${TIME}* > /ericsson/enm/dumps/pmic_collect_stats/rop_${TIME}_file_list.txt
echo "Completed generating list of PM Files collected for the ${TIME} ROP."

echo
echo -n "Total # PM Files collected in the ${TIME} ROP: "
cat /ericsson/enm/dumps/pmic_collect_stats/rop_${TIME}_file_list.txt | wc -l

echo
echo "PM STATS COLLECTION"
echo ---------------------
echo -n "Total Stats files for MGW (Out of ${NUM_MGW} Nodes): "
egrep -i "K3C" /ericsson/enm/dumps/pmic_collect_stats/rop_${TIME}_file_list.txt | grep -c statsfile

echo -n "Total Stats files for SGSN (Out of ${NUM_SGSNMME} Nodes): "
egrep -i "SGSN" /ericsson/enm/dumps/pmic_collect_stats/rop_${TIME}_file_list.txt | grep -c statsfile

echo -n "Total Stats files for RadioNode/DG2 (Out of ${NUM_LTE_DG2} Nodes): "
egrep -i "dg2" /ericsson/enm/dumps/pmic_collect_stats/rop_${TIME}_file_list.txt | grep -c statsfile

echo -n "Total Stats files for MSRBS (Out of ${NUM_MSRBS} Nodes): "
egrep "XML" /ericsson/enm/dumps/pmic_collect_stats/rop_${TIME}_file_list.txt | grep statsfile.xml | grep MSRBS |wc -l

echo -n "Total Stats files for ERBS (Out of ${NUM_ERBS} Nodes): "
egrep "XML" /ericsson/enm/dumps/pmic_collect_stats/rop_${TIME}_file_list.txt | grep statsfile.xml | grep ERBS |egrep -vi "dg2|sgsn|k3c" | wc -l

echo -n "Total Stats files for RBS (Out of ${NUM_RBS} Nodes): "
egrep "XML" /ericsson/enm/dumps/pmic_collect_stats/rop_${TIME}_file_list.txt | grep statsfile.xml | grep "RNC[0-9][0-9]RBS" |egrep -vi "dg2|sgsn|k3c"|wc -l

echo -n "Total Stats files for Router6672 (Out of ${NUM_Router6672} Nodes): "
egrep statsfile /ericsson/enm/dumps/pmic_collect_stats/rop_${TIME}_file_list.txt | grep -c "SPFRER6000"

echo -n "Total Stats files for EPG (Out of ${NUM_EPG} Nodes): "
egrep statsfile /ericsson/enm/dumps/pmic_collect_stats/rop_${TIME}_file_list.txt | grep -c "EPG"

echo -n "Total Stats files for MTAS (Out of ${NUM_MTAS} Nodes): "
egrep statsfile /ericsson/enm/dumps/pmic_collect_stats/rop_${TIME}_file_list.txt | grep -c "MTAS"

echo -n "Total Stats files for RNC (Out of ${NUM_RNC} Nodes): "
egrep "XML" /ericsson/enm/dumps/pmic_collect_stats/rop_${TIME}_file_list.txt | grep statsfile.xml | grep "RNC[0-9]" |egrep -vi "dg2|rbs|sgsn|k3c"|wc -l

echo -n "Total CTR files for RNC (Out of ${NUM_RNC} Nodes): "
egrep -c "ctrfile" /ericsson/enm/dumps/pmic_collect_stats/rop_${TIME}_file_list.txt

echo -n "Total UETR files for RNC (Out of ${NUM_RNC} Nodes): "
egrep -c "uetrfile" /ericsson/enm/dumps/pmic_collect_stats/rop_${TIME}_file_list.txt

echo -n "Total GPEH files for RNC (Out of ${NUM_RNC} Nodes): "
egrep "gpehfile" /ericsson/enm/dumps/pmic_collect_stats/rop_${TIME}_file_list.txt | grep -vc RBS

echo -n "Total GPEH files for RBS (Out of ${NUM_RBS} Nodes): "
egrep "gpehfile" /ericsson/enm/dumps/pmic_collect_stats/rop_${TIME}_file_list.txt | grep -c RBS

echo
echo "PM CELLTRACE (HIGH PRIORITY)"
echo -----------------------------
echo -n "Total CellTrace (high prio) files for RadioNode/DG2 (Out of ${NUM_LTE_DG2} Nodes): "
egrep -i "dg2" /ericsson/enm/dumps/pmic_collect_stats/rop_${TIME}_file_list.txt | grep -c celltracefile_DUL1_3

echo -n "Total CellTrace (high prio) files for ERBS (Out of ${NUM_ERBS} Nodes): "
egrep -i CELLTRACE /ericsson/enm/dumps/pmic_collect_stats/rop_${TIME}_file_list.txt | grep -vi dg2 | grep -c celltracefile_DUL1_3

echo
echo "PM CELLTRACE (LOW PRIORITY)"
echo -----------------------------
echo -n "Total CellTrace (low prio) files for ERBS (Out of ${NUM_ERBS} Nodes): "
egrep -i CELLTRACE /ericsson/enm/dumps/pmic_collect_stats/rop_${TIME}_file_list.txt | grep -vi dg2 | grep -c celltracefile_DUL1_1
echo -n "Total CellTrace (low prio) files for RadioNode/DG2 (Out of ${NUM_LTE_DG2} Nodes): "
egrep -i CELLTRACE /ericsson/enm/dumps/pmic_collect_stats/rop_${TIME}_file_list.txt | grep -i dg2 | grep -c celltracefile_DUL1_1


echo
echo "PM CTUM COLLECTION"
echo -----------------------------
echo -n "Total CTUM files for ${NUM_SGSNMME} SGSN-MME nodes collected in this ROP: "
egrep -i "SGSN" /ericsson/enm/dumps/pmic_collect_stats/rop_${TIME}_file_list.txt | grep -c ctum

echo
echo "PM UETrace COLLECTION"
echo ----------------------
echo -n "Total UETrace files for ERBS (Out of 480 Nodes): "
egrep -ci "uetracefile" /ericsson/enm/dumps/pmic_collect_stats/rop_${TIME}_file_list.txt
echo -n "Total UETrace files for ${NUM_SGSNMME} SGSN-MME nodes collected in this ROP: "
egrep -ci "ue_trace" /ericsson/enm/dumps/pmic_collect_stats/rop_${TIME}_file_list.txt

echo
echo "PM EBM COLLECTION"
echo ------------------
echo -n "Total EBM files for ${NUM_SGSNMME} SGSN-MME nodes collected in this ROP: "
egrep -ci "ebm" /ericsson/enm/dumps/pmic_collect_stats/rop_${TIME}_file_list.txt

echo
echo "PM EBSM COLLECTION"
echo -----------------------------
echo -n "Total EBSM files for ${NUM_SGSNMME} SGSN-MME nodes collected in this ROP: "
egrep  -c "ebsm" /ericsson/enm/dumps/pmic_collect_stats/rop_${TIME}_file_list.txt

umount /ericsson/pmic1
umount /ericsson/pmic2
rmdir /ericsson/pmic1
rmdir /ericsson/pmic2
