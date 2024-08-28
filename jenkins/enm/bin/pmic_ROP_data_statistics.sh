#!/bin/bash
###############################################################
## Scrtipt: PMIC Data statistics AND Failed to collect Nodes ##
## Author : rajesh.chiluveru@ericsson.com                    ##
###############################################################
CLUSTER=`grep -ri san_siteId /software/autoDeploy/*site*|head -1 | awk -F '=ENM' '{print $2}'`
NETSIM=`grep netsim /root/rvb/deployment_conf/5${CLUSTER}.conf | head -1 | awk -F "\"" '{print $2}' | awk -F "-" '{print $1}'`
DATE=`date +%Y%m%d`
TIME=$1
pd=`date -d "1 day ago" +%Y%m%d`
rm -f /ericsson/enm/dumps/rop_*${pd}*.txt
nas_vip_enm_1=`grep -ri nas_vip_enm_1 /software/autoDeploy/*site*|head -1 | awk -F '=' '{print $2}'`
nas_vip_enm_2=`grep -ri nas_vip_enm_2 /software/autoDeploy/*site*|head -1 | awk -F '=' '{print $2}'`

if [ ! -f /ericsson/enm/dumps/rop_${DATE}_${TIME}_file_list.txt ]
then
	mkdir -p /ericsson/pmic1
	mkdir -p /ericsson/pmic2
	mount ${nas_vip_enm_1}:/vx/ENM${CLUSTER}-pm1 /ericsson/pmic1
	mount ${nas_vip_enm_2}:/vx/ENM${CLUSTER}-pm2 /ericsson/pmic2
	echo
	echo "Generating list of PM Files collected for the ${TIME} ROP and loading into /ericsson/enm/dumps/rop_${DATE}_${TIME}_file_list.txt"
	echo
	time find /ericsson/pmic*/ -name [AB]${DATE}.${TIME}* |xargs ls -ltr > /ericsson/enm/dumps/rop_${DATE}_${TIME}_file_list.txt
	t1=`echo ${TIME}|cut -c1-2`
	t2=`echo ${TIME}|cut -c3-4`
		if [ $t2 -eq 0 ]
		then
		t3=`expr $t2 + 14`
			for i in 00 01 02 03 04 05 06 07 08 09 10 11 12 13 14
			do
			find /ericsson/pmic*/ebm/data/ -name [AB]${DATE}.${t1}${i}*|xargs ls -ltr >> /ericsson/enm/dumps/rop_onemnt_${DATE}_${TIME}_file_list.txt
			done
		else
		t3=`expr $t2 + 14`
			for ((j=$t2;j<=$t3;j++))
			do
			find /ericsson/pmic*/ebm/data/ -name [AB]${DATE}.${t1}${j}* |xargs ls -ltr >> /ericsson/enm/dumps/rop_onemnt_${DATE}_${TIME}_file_list.txt
			done	

		fi

echo "Completed generating list of PM Files collected for the ${TIME} ROP."
umount /ericsson/pmic1
umount /ericsson/pmic2
rmdir /ericsson/pmic1
rmdir /ericsson/pmic2
fi

echo
echo "Determining the number of each node type. Please wait....."
echo
NUM_ERBS=`cli_app 'cmedit get * NetworkElement -netype=ERBS -cn' | tail -1 | awk '{print $1}'`
NUM_RADIONODE=`cli_app 'cmedit get * NetworkElement -netype=RadioNode -cn' | tail -1 | awk '{print $1}'`
NUM_MGW=`cli_app 'cmedit get * NetworkElement -netype=MGW -cn' | tail -1 | awk '{print $1}'`
NUM_SGSNMME=`cli_app 'cmedit get * NetworkElement -netype=SGSN-MME -cn' | tail -1 | awk '{print $1}'`
NUM_Router6672=`cli_app 'cmedit get * NetworkElement -netype=Router6672 -cn' | tail -1 | awk '{print $1}'`

echo "ERBS: ${NUM_ERBS}"
echo "RadioNode: ${NUM_RADIONODE}"
echo "MGW: ${NUM_MGW}"
echo "SGSN-MME: ${NUM_SGSNMME}"
echo "Router6672: ${NUM_Router6672}"
echo
echo "PM Stats File ::"
echo "***********************"
echo "Total Stats files for MGW  :`grep -i K3C /ericsson/enm/dumps/rop_${DATE}_${TIME}_file_list.txt | grep -c statsfile`/${NUM_MGW} "
echo "Total Stats files for SGSN :`grep -i sgsn /ericsson/enm/dumps/rop_${DATE}_${TIME}_file_list.txt | grep -c statsfile`/${NUM_SGSNMME}"
echo "Total Stats files for RadioNode/DG2 :`grep -i dg2 /ericsson/enm/dumps/rop_${DATE}_${TIME}_file_list.txt| grep -c statsfile`/${NUM_RADIONODE}"
echo "Total Stats files for ERBS :`grep -i ERBS /ericsson/enm/dumps/rop_${DATE}_${TIME}_file_list.txt | grep statsfile.xml | egrep -vi "dg2|sgsn|k3c"|wc -l`/${NUM_ERBS}"
echo "Total Stats files for SPITFIRE :`grep -i SPF /ericsson/enm/dumps/rop_${DATE}_${TIME}_file_list.txt|wc -l`/${NUM_Router6672}"
echo
echo "PM CELLTRACE (HIGH PRIORITY)"
echo "*****************************"
echo "Total CellTrace (high prio) files for RadioNode/DG2 :`grep CELLTRACE /ericsson/enm/dumps/rop_${DATE}_${TIME}_file_list.txt|grep -i dg2 /ericsson/enm/dumps/rop_${DATE}_${TIME}_file_list.txt| grep -c celltracefile_DUL1_3`/${NUM_RADIONODE}"
echo "Total CellTrace (high prio) files for ERBS :`grep CELLTRACE /ericsson/enm/dumps/rop_${DATE}_${TIME}_file_list.txt|grep -vi dg2 /ericsson/enm/dumps/rop_${DATE}_${TIME}_file_list.txt| grep -c celltracefile_DUL1_3`/${NUM_ERBS}"
echo
echo "PM CELLTRACE (LOW PRIORITY)"
echo "******************************"
echo "Total CellTrace (low prio) files for ERBS :`grep CELLTRACE /ericsson/enm/dumps/rop_${DATE}_${TIME}_file_list.txt|grep -vi dg2 /ericsson/enm/dumps/rop_${DATE}_${TIME}_file_list.txt| grep -c celltracefile_DUL1_1`/${NUM_ERBS}"
echo "Total CellTrace (low prio) files for RadioNode/DG2 :`grep CELLTRACE /ericsson/enm/dumps/rop_${DATE}_${TIME}_file_list.txt|grep -i dg2 /ericsson/enm/dumps/rop_${DATE}_${TIME}_file_list.txt| grep -c celltracefile_DUL1_1`/${NUM_RADIONODE}"
echo
echo "PM CTUM COLLECTION"
echo "*******************"
echo "Total CTUM files for ${NUM_SGSNMME} SGSN-MME nodes collected in this ROP: `grep -i SGSN /ericsson/enm/dumps/rop_${DATE}_${TIME}_file_list.txt|grep -c ctum`"
echo
echo "PM UETrace COLLECTION"
echo "**********************"
echo "Total UETrace files for ERBS (Out of 480 Nodes): `grep -ci uetracefile /ericsson/enm/dumps/rop_${DATE}_${TIME}_file_list.txt`"
echo "Total UETrace files for ${NUM_SGSNMME} SGSN-MME nodes collected in this ROP: `grep -i ue_trace /ericsson/enm/dumps/rop_${DATE}_${TIME}_file_list.txt|wc -l`"
echo
echo "PM EBM COLLECTION"
echo "*******************"
echo "Total EBM files for ${NUM_SGSNMME} SGSN-MME nodes collected in this ROP: `grep -i ebm /ericsson/enm/dumps/rop_${DATE}_${TIME}_file_list.txt|wc -l`"
echo
echo "PM EBSM COLLECTION"
echo "*******************"
echo "Total EBSM files for ${NUM_SGSNMME} SGSN-MME nodes collected in this ROP: `grep -i ebsm /ericsson/enm/dumps/rop_${DATE}_${TIME}_file_list.txt|wc -l`"
echo
cli_app 'cmedit get * networkelement.neType==RadioNode'|grep FDN|cut -d"=" -f2|sort -u > /ericsson/enm/dumps/all_dg2ERBS.txt
cli_app 'cmedit get * networkelement.neType==ERBS'|grep FDN|cut -d"=" -f2|sort -u > /ericsson/enm/dumps/all_ERBS.txt
cli_app 'cmedit get * networkelement.neType==SGSN-MME'|grep FDN|cut -d"=" -f2|sort -u > /ericsson/enm/dumps/all_sgsn.txt
cli_app 'cmedit get * networkelement.neType==Router6672'|grep FDN|cut -d"=" -f2|sort -u > /ericsson/enm/dumps/all_SPFRER.txt1
sed -i 's/$/,ManagedElement/g' /ericsson/enm/dumps/all_SPFRER.txt1
cat /ericsson/enm/dumps/all_SPFRER.txt1|sort -u > /ericsson/enm/dumps/all_SPFRER.txt

echo " ******* 15 Min ROP Data Statistics for ${TIME} ROP ************* "
echo
a=`cat /ericsson/enm/dumps/rop_${DATE}_${TIME}_file_list.txt|grep dg2|grep statsfile|awk '{ sum += $5/1024 } END { print (sum/1024) }'`
a1=`echo "scale=2;$a"|bc`
a1_1=`echo "scale=2;$a/1024"|bc`
echo "RadioNode_Stats           ==> $a1 MB"

b=`cat /ericsson/enm/dumps/rop_${DATE}_${TIME}_file_list.txt|grep dg2|grep -i celltracefile_DUL1_1|awk '{ sum += $5/1024 } END { print (sum/1024) }'`
b1=`echo "scale=2;$b/1024"|bc`
echo "RadioNode_CTR_LowPrio     ==> $b1 "

c=`cat /ericsson/enm/dumps/rop_${DATE}_${TIME}_file_list.txt|grep dg2|grep -i celltracefile_DUL1_3|awk '{ sum += $5/1024 } END { print (sum/1024) }'`
c1=`echo "scale=2;$c/1024"|bc`
echo "RadioNode_CTR_HigPrio     ==> $c1 "

d=`cat /ericsson/enm/dumps/rop_${DATE}_${TIME}_file_list.txt|grep -v 'dg2|pERBS'|grep ERBS|grep -i stats|awk '{ sum += $5/1024 } END { print (sum/1024) }'`
d1=`echo "scale=2;$d/1024"|bc`
echo "ERBS_Stats                ==> $d1 "

e=`cat /ericsson/enm/dumps/rop_${DATE}_${TIME}_file_list.txt|egrep -v 'dg2|pERBS'|grep ERBS|grep -i celltracefile_DUL1_1|awk '{ sum += $5/1024 } END { print (sum/1024) }'`
e1=`echo "scale=2;$e/1024"|bc`
echo "ERBS_CTR_LowPrio          ==> $e1 "

f=`cat /ericsson/enm/dumps/rop_${DATE}_${TIME}_file_list.txt|egrep -v 'dg2|pERBS'|grep ERBS|grep -i celltracefile_DUL1_3|awk '{ sum += $5/1024 } END { print (sum/1024) }'`
f1=`echo "scale=2;$f/1024"|bc`
echo "ERBS_CTR_HigPrio          ==> $f1 "

g=`cat /ericsson/enm/dumps/rop_${DATE}_${TIME}_file_list.txt|egrep -v 'dg2|pERBS'|grep ERBS|grep -i uetrace|awk '{ sum += $5/1024 } END { print (sum/1024) }'`
g1=`echo "scale=2;$g/1024"|bc`
echo "ERBS_UETRACE              ==> $g1 "

h=`cat /ericsson/enm/dumps/rop_${DATE}_${TIME}_file_list.txt|grep -i sgsn|grep -i stats|awk '{ sum += $5/1024 } END { print (sum/1024) }'`
h1=`echo "scale=2;$h/1024"|bc`
echo "SGSN_Stats                ==> $h1 "

k=`cat /ericsson/enm/dumps/rop_${DATE}_${TIME}_file_list.txt|grep -i sgsn|grep -i ebsm|awk '{ sum += $5/1024 } END { print (sum/1024) }'`
k1=`echo "scale=2;$k/1024"|bc`
echo "SGSN_EBSM                 ==> $k1 "

l=`cat /ericsson/enm/dumps/rop_${DATE}_${TIME}_file_list.txt|grep -i sgsn|grep -i ue_trace|awk '{ sum += $5/1024 } END { print (sum/1024) }'`
l1=`echo "scale=2;$l/1024"|bc`
echo "SGSN_UETRACE              ==> $l1 "

m=`cat /ericsson/enm/dumps/rop_${DATE}_${TIME}_file_list.txt|grep -i sgsn|grep -i ctum|awk '{ sum += $5/1024 } END { print (sum/1024) }'`
m1=`echo "scale=2;$m/1024"|bc`
echo "SGSN_CTUM                 ==> $m1 "

n=`cat /ericsson/enm/dumps/rop_${DATE}_${TIME}_file_list.txt|grep -i k3c|grep -i stat|awk '{ sum += $5/1024 } END { print (sum/1024) }'`
n1=`echo "scale=2;$n/1024"|bc`
echo "MGW_Stats                 ==> $n1 "
echo "-------------------------------------"
TT=`echo " $a1_1 + $b1 + $c1 + $d1 + $e1 + $f1 + $g1 + $h1 + $k1 + $l1 + $m1 + $n1 "|bc`
echo " Total 15 min Data        === $TT GB "
echo "------------------------------------"

t1=`echo ${TIME}|cut -c1-2`
t2=`echo ${TIME}|cut -c3-4`
	if [ $t2 -eq 0 ]
	then
	t3=`expr $t2 + 14`
	else
	t3=`expr $t2 + 14`
	fi

echo
echo "***** ONE Min Data Statistics for ROP from ${t1}${t2} TO ${t1}${t3} *********** "
echo

	if [ -f /ericsson/enm/dumps/rop_onemnt_${DATE}_${TIME}_file_list.txt ]
	then
	j=`cat /ericsson/enm/dumps/rop_onemnt_${DATE}_${TIME}_file_list.txt |grep -i sgsn|grep -i ebm|awk '{ sum += $5/1024 } END { print (sum/1024) }'`
	j1=`echo "scale=2;$j/1024"|bc`
	echo "SGSN_EBM data for ROP from ${t1}${t2} TO ${t1}${t3}  ==> $j1 GB "
	else
	echo "SGSN_EBM data for ROP from ${t1}${t2} TO ${t1}${t3}  ==> 0 GB "
	echo "There are NO EBM files collected in ROP ${TIME}.Please troubleshoot "
	echo
	fi

echo
echo "**** List of Nodes Failed to Collect ROP ${TIME} Files *********"
echo
   for node in dg2ERBS sgsn SPFRER
   do
   grep -i $node /ericsson/enm/dumps/rop_${DATE}_${TIME}_file_list.txt |grep stats|awk -F"/" '{print $5}'|cut -d"=" -f3|sort -u > /ericsson/enm/dumps/data_$node.txt
   a1=`comm -23 /ericsson/enm/dumps/all_${node}.txt /ericsson/enm/dumps/data_${node}.txt|wc -l`
	if [ $a1 -ne 0 ]
	then
		echo "**** There is/are $a1  $node Node Failed To collect PMIC files in given ROP ${TIME} ****"
		if [ $a1 -le 20 ]
		then
		echo "**** Below are Failed To COllect $node Nodes . PLZ troubleshoot **** "
		comm -23 /ericsson/enm/dumps/all_${node}.txt /ericsson/enm/dumps/data_${node}.txt
		echo
		else
	      comm -23 /ericsson/enm/dumps/all_${node}.txt /ericsson/enm/dumps/data_${node}.txt > /ericsson/enm/dumps/${node}_Failed.txt
		echo "**** CHECK failed to collect $node nodes in file /ericsson/enm/dumps/${node}_Failed.txt"
		echo
		fi
	fi

   done

cat /ericsson/enm/dumps/rop_${DATE}_${TIME}_file_list.txt |egrep -v 'pERBS|dg2'|grep ERBS|grep stats|awk -F"/" '{print $5}'|cut -d"=" -f3|sort -u > /ericsson/enm/dumps/data_ERBS.txt
cat /ericsson/enm/dumps/rop_${DATE}_${TIME}_file_list.txt |egrep -v 'pERBS|dg2'|grep ERBS|grep -i celltrace|awk -F"/" '{print $5}'|cut -d"=" -f3|sort -u > /ericsson/enm/dumps/data_ctr_ERBS.txt
a2=`comm -23 /ericsson/enm/dumps/all_ERBS.txt /ericsson/enm/dumps/data_ERBS.txt|wc -l`
a3=`comm -23 /ericsson/enm/dumps/all_ERBS.txt /ericsson/enm/dumps/data_ctr_ERBS.txt|wc -l`
	if [ $a2 -ne 0 -o $a3 -ne 0 ]
	then
	echo "**** There is/are $a2 ERBS Node Failed To collect PMIC files in given ROP ${TIME} ****"
		if [ $a2 -le 20 -a $a3 -le 20 ]
		then
		echo "**** Below are Failed to Collect ERBS Nodes Stats. PLZ troubleshoot **** "
		comm -23 /ericsson/enm/dumps/all_ERBS.txt /ericsson/enm/dumps/data_ERBS.txt
		echo "**** Below are Failed to Collect ERBS Nodes CTR. PLZ troubleshoot **** "
		comm -23 /ericsson/enm/dumps/all_ERBS.txt /ericsson/enm/dumps/data_ctr_ERBS.txt
		echo
		else
		comm -23 /ericsson/enm/dumps/all_ERBS.txt /ericsson/enm/dumps/data_ERBS.txt > /ericsson/enm/dumps/ERBS_Failed.txt
		comm -23 /ericsson/enm/dumps/all_ERBS.txt /ericsson/enm/dumps/data_ctr_ERBS.txt > /ericsson/enm/dumps/ERBS_CTR_Failed.txt
		echo "**** CHECK Failed to collect ERBS nodes in file /ericsson/enm/dumps/ERBS_Failed.txt AND /ericsson/enm/dumps/ERBS_CTR_Failed.txt"
		echo
		fi
	fi
