#!/bin/bash

#if [ $# -gt 0 ]
#then
#echo "  Syntax ERROR - No arguments required "
#echo "Eg:       ./dps_events_flow_invocation_Customer.sh Site Month Year" | sed "s/^/\t\t/g"
#echo "For Example ./.dps_events_flow_invocation_Customer.sh LMI_ENM433 01 19"
#echo
#echo "PRE-REQUISITES" | sed "s/^/\t\t/g"
#echo "==============" | sed "s/^/\t\t/g"
#echo "Ensure that the relevant DDp site is mounted" | sed "s/^/\t\t/g"
#echo
#exit 1
#fi
make_ddp_mount_dir () {
if [ ! -d /net/ddpi/data/stats ]; then
        mkdir -p /net/ddpi/data/stats
elif [ ! -d /net/ddpenm2/data/stats ]; then
        mkdir -p /net/ddpenm2/data/stats
elif [ ! -d /net/ddpenm3/data/stats ]; then
        mkdir -p /net/ddpenm3/data/stats
elif [ ! -d /net/ddpenm4/data/stats ]; then
        mkdir -p /net/ddpenm4/data/stats
elif [ ! -d /net/ddpenm5/data/stats ]; then
        mkdir -p /net/ddpenm5/data/stats
elif [ ! -d /net/ddpenm6/data/stats ]; then
        mkdir -p /net/ddpenm6/data/stats
elif [ ! -d /net/ddpenm7/data/stats ]; then
        mkdir -p /net/ddpenm7/data/stats
else
        echo -e "Job done. Mount directories for script exist"
fi
}

mount_ddp_to_lms(){
    [[ -z $(mount | egrep ddpi:) ]] && mount ddpi:/data/stats /net/ddpi/data/stats || echo "already mounted"
    [[ -z $(mount | egrep ddpenm2:) ]] && mount ddpenm2:/data/stats /net/ddpenm2/data/stats || echo "already mounted"
    [[ -z $(mount | egrep ddpenm3:) ]] && mount ddpenm3:/data/stats /net/ddpenm3/data/stats || echo "already mounted"
    [[ -z $(mount | egrep ddpenm4:) ]] && mount ddpenm4:/data/stats /net/ddpenm4/data/stats || echo "already mounted"
    [[ -z $(mount | egrep ddpenm5:) ]] && mount ddpenm5:/data/stats /net/ddpenm5/data/stats || echo "already mounted"
    [[ -z $(mount | egrep ddpenm6:) ]] && mount ddpenm6:/data/stats /net/ddpenm6/data/stats || echo "already mounted"
    [[ -z $(mount | egrep ddpenm7:) ]] && mount ddpenm7:/data/stats /net/ddpenm7/data/stats || echo "already mounted"

}


AWK=/bin/awk
CAT=/bin/cat
CLI_APP=/opt/ericsson/enmutils/bin/cli_app
ECHO=/bin/echo
EGREP=/bin/egrep
GREP=/bin/grep
MKDIR=/bin/mkdir
PRINTF=/usr/bin/printf
RM=/bin/rm
SORT=/bin/sort
TAIL=/usr/bin/tail
WC=/usr/bin/wc

#DDP="/net/ddp/data/stats/tor"
#Site name as stored in Relevant DDP Site
SITE=$2
DDPCUSTOMER=$1
DDP="/net/${DDPCUSTOMER}/data/stats/tor"
#DDP_MONTH=`date +%m`
RANGE1=$3
RANGE2=$4
DDP_MONTH=$5
#DDP_YR=`date +%y`
DDP_YR=$6
#BOLD='033[1m'


if [ "$1" = "-h" -o "$1" = "--h" -o "$1" = "-help" -o "$1" = "--help" ]
then
        # Help output to be printed if any of the following are entered: -h, --h, -help or --help
        $ECHO ""
        $ECHO "Script to check the Behaviour of a Deployment for a range of Days in a Month."
        $ECHO ""
        $ECHO "Usage   : # /.Deployment_Daily_Performance.sh [-h|--h|-help|--help]:  --->  Prints this help/usage information for this script"
        $ECHO ""
        $ECHO "Usage   : # .Deployment_Daily_Performance.sh DDP SITE DAY1 DAY2 MONTH YEAR"
        $ECHO " "
        $ECHO "Example : Here is how we dtermine the data for the 9th-10th March for a particular Verizon site on ddp2"
        $ECHO -e "\t# .Deployment_Daily_Performance.sh ddp2 Verizon_Azusa_azusca21enm-e-ec-c7kx-ms1_Core_LTE 09 10 03 19 "
        $ECHO ""
        $ECHO "          Note: This takes some time but returns a significant volume of Data with respect to Resource Usage, DPS Events, Network managed etc"
        $ECHO ""
        exit
fi


#for i in [${RANGE1}..${RANGE2}];
#for i in {01..31}
for i in $(eval echo "{$RANGE1..$RANGE2}")
do echo -e "\t _______________________________________________________________\n"
echo -e "\n\t|\tSite: $SITE\t\n\t\tDate: Day $i Month $DDP_MONTH Year 20$DDP_YR\t";
echo -e "\n\t|_______________________________________________________________|\n"
#sleep 3;

#echo -e "\n\nENM_version -->";
if [ -f $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/sw_inventory/ENM_version ]; then
        echo -e "\n\n<-- ENM_version -->";
        tail -1 $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/sw_inventory/ENM_version|grep -oP ENM.*|sed "s/^/\t/g";
fi

if [ -f $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/sw_inventory/enm_version ]; then
        echo -e "\n\n<-- ENM_version -->";
        tail -1 $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/sw_inventory/enm_version|grep -oP ENM.*|sed "s/^/\t/g";
fi


if [ -f $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/global.properties ]; then
        echo -e "\n<-- DPS Persistence Provider -->";
        grep  persistence $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/global.properties|awk -F "=" '{print $2}'|sed "s/^/\t/g";
#       grep neo4j_cluster $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/global.properties|awk -F "=" '{print $1,$2}'|sed "s/^/\t/g";
fi

#if [ -f $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/neo4j/cluster_overview.log ]; then
#       echo -e "\n\n<-- Neo4j Leadership pattern Status on $SITE -->";
#      echo -e "\n\t ---- Times observed as Leader -----";
#     cat $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/neo4j/cluster_overview.log|egrep 'LEADER' --colour|sort |uniq -c;
#fi
Unity=`find $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/ -maxdepth 2 -type d|grep -i unity`;
Clariion=`find $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/ -maxdepth 2 -type d|grep -i clariion`;

if [ -e "$Unity" ];
then
        echo -e "\n\n<-- Storage Type on $SITE is Unity: Significant Events from Unity Storage  -->\n";
	find $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/unity|grep json|xargs python -m json.tool|egrep -v 'test message to be sent back|is operating normally|does not have any iniators logged into the storage system|The storage system failed to communicate an event message via the Email server|Failed to send e-mail alert'|grep message|sort|uniq -c|sort -rnk1;
fi

if [ -e "$Clariion" ];
then
        echo -e "\n\n<-- Storage Type on $SITE is Clariion: Significant Events from Clariion Storage  -->\n";
        find $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/clariion/|grep getlog|xargs cat|egrep -v "Result: Success"|egrep -wi 'error' --colour|sort|uniq -c|sort -rnk1
fi

#echo -e "\n\n\t <--- Db Cluster Blade Aliases ---->";
if [ -f $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR//sw_inventory/LITP2_deployment_description.gz ]; then
        echo -e "\n\n\t <---- Number of Nodes in Deployment $SITE ---->\n";
        zcat $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR//sw_inventory/LITP2_deployment_description.gz|egrep 'litp:node id'|awk -F "<|>" '{print $2}'|grep -oP node.*|grep -c node|sed "s/^/\t\t/g";
        echo -e "\n\n\t <---- Clusters and Number of Nodes in $SITE ---->\n";
        zcat $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR//sw_inventory/LITP2_deployment_description.gz|egrep 'litp:node id'|awk -F "<|>|=|-" '{print $3}'|sort|uniq -c|sed "s/^/\t\t/g";
        echo -e "\n\n\t <---- Db Cluster Blade Aliases ---->\n";
        #zgrep -ri --colour litp.*db-._alias -A1 $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR//sw_inventory/LITP2_deployment_description.gz |awk -F ">|<|:|=|/|" '{print $3,$4}'|tail -11|sed "s/^/\t\t/g";
        zcat $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR//sw_inventory/LITP2_deployment_description.gz |grep --colour litp.*db-._alias -A1|awk -F ">|<|:|=|/|" '{print $3,$4}'|tail -11|sed "s/^/\t\t/g";
        echo -e "\n\t <---- Breakdown of Deployment Hardware in Physical Deployment: Includes LMS, NAS and Cluster Server Blades ---->\n";
        # find $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/|grep dmidecode.txt|xargs grep --colour "Product Name"|egrep -v "Product Name: KVM|NETSIM|WORKLOAD"|grep ${i}${DDP_MONTH}${DDP_YR}.* -oP|sed 's#/# #g'|sed 's#dmidecode.txt:##g'|sed 's#..0219##g'|column -t|uniq|sed "s/^/\t/g;
        find $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/ -maxdepth 5  -type f|grep dmidecode.txt|xargs egrep --colour "Product Name|CPU|Maximum Capacity"|egrep -v 'NETSIM|WORKLOAD|KVM|Socket Designation|svc-|scp-|esmon|visi|asr-|ebs-|solr|str-|evt-|aut-|openidm|sdncontroller|cnom|domain'|uniq -c|sed "s#/#\t#g"|sed 's#.*data##g'|sed "s#.*remotehosts##g"|sed "s#dmidecode.txt##g"|sed "s#.*tor_servers##g"|sed 's#_TOR.*server##g'|sed 's#NAS.*server#NAS #g'|sed 's#.*server#\tLMS#g'|sed "s#Version#Processor Version#g" |sed "s#Maximum Capacity#Memory Maximum Capacity#g";
        echo -e "\n\t <---- VCS Critical Events in Deployment $SITE ---->\n\n";
        find $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/ -maxdepth 5  -type f |egrep -v 'NETSIM|WORKLOAD'|grep engine_A.log|xargs cat|egrep --colour 'VCS ERROR|VCS WARNING'|grep -oP "VCS.*"|sort |uniq -c|grep -oP "VCS.*"|egrep -v "monitor procedure did not complete within the expected time|because online did not complete within the expected time|consistently failed to determine the resource status within the expected time"|egrep --colour "ERROR"|sed "s/^/\t/g";
        echo -e "\n\t <---- VCS Resource CPU and Memory Usage WARNINGs ---->\n\n";
        find $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/ -maxdepth 5 -type d -name 'vcs'|xargs egrep --colour 'VCS ERROR|VCS WARNING' -ri |grep -oP ":201.*"|sort |egrep --colour 'usage'|sed "s/^/\t\t/g";
fi

if [ -f $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR//sw_inventory/LITP2_deployment_description ]; then
        echo -e "\n\n\t <---- Number of Nodes in Deployment $SITE ---->\n";
        cat $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR//sw_inventory/LITP2_deployment_description|egrep 'litp:node id'|awk -F "<|>" '{print $2}'|grep -oP node.*|grep -c node|sed "s/^/\t\t/g";
        echo -e "\n\n\t <---- Clusters and Number of Nodes in $SITE ---->\n";
        cat $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR//sw_inventory/LITP2_deployment_description|egrep 'litp:node id'|awk -F "<|>|=|-" '{print $3}'|sort|uniq -c|sed "s/^/\t\t/g";
        echo -e "\n\n\t <---- Db Cluster Blade Aliases ---->\n";
        #zgrep -ri --colour litp.*db-._alias -A1 $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR//sw_inventory/LITP2_deployment_description.gz |awk -F ">|<|:|=|/|" '{print $3,$4}'|tail -11|sed "s/^/\t\t/g";
        cat $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR//sw_inventory/LITP2_deployment_description |grep --colour litp.*db-._alias -A1|awk -F ">|<|:|=|/|" '{print $3,$4}'|tail -11|sed "s/^/\t\t/g";
        echo -e "\n\t <---- Breakdown of Deployment Hardware in Physical Deployment: Includes LMS, NAS and Cluster Server Blades ---->\n";
        # find $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/|grep dmidecode.txt|xargs grep --colour "Product Name"|egrep -v "Product Name: KVM|NETSIM|WORKLOAD"|grep ${i}${DDP_MONTH}${DDP_YR}.* -oP|sed 's#/# #g'|sed 's#dmidecode.txt:##g'|sed 's#..0219##g'|column -t|uniq|sed "s/^/\t/g;
#        find $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/|grep dmidecode.txt|xargs grep --colour "Product Name"|egrep -v "Product Name: KVM|NETSIM|WORKLOAD"|grep -oP "${i}${DDP_MONTH}${DDP_YR}.*"|sed 's#/# #g'|sed 's#dmidecode.txt:##g'|sed 's#..0219##g'|column -t|uniq|sed "s/^/\t\t/g";
        find $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/  -maxdepth 5 -type f|grep dmidecode.txt|xargs egrep --colour "Product Name|CPU|Maximum Capacity"|egrep -v 'NETSIM|WORKLOAD|KVM|Socket Designation|svc-|scp-|esmon|visi|asr-|ebs-|solr|str-|evt-|aut-|openidm|cnom|sdncontroller|domain'|uniq -c|sed "s#/#\t#g"|sed 's#.*data##g'|sed "s#.*remotehosts##g"|sed "s#dmidecode.txt##g"|sed "s#.*tor_servers##g"|sed 's#_TOR.*server##g'|sed 's#NAS.*server#NAS #g'|sed 's#.*server#\tLMS#g'|sed "s#Version#Processor Version#g" |sed "s#Maximum Capacity#Memory Maximum Capacity#g";
        echo -e "\n\t <---- VCS Critical Events in Deployment $SITE ---->\n";
        find $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/ -maxdepth 5 -type f |egrep -v 'WORKLOAD|NETSIM'|grep engine_A.log|xargs cat|egrep --colour 'VCS ERROR|VCS WARNING'|grep -oP "VCS.*"|sort |uniq -c|grep -oP "VCS.*"|egrep -v "monitor procedure did not complete within the expected time|because online did not complete within the expected time|consistently failed to determine the resource status within the expected time"|egrep --colour "ERROR"|sed "s/^/\t\t/g";
        echo -e "\n\t <---- VCS Resource CPU and Memory Usage WARNINGs ---->\n\n";
        find $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/ -maxdepth 5 -type d -name 'vcs'|xargs egrep --colour 'VCS ERROR|VCS WARNING' -ri|grep -oP ":201.*"|sort |egrep --colour 'usage'|sed "s/^/\t\t/g";
fi

ESXI_FILE=`find $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/ -type f |grep esxi_metrics.txt|head -1`
if [ -e "$ESXI_FILE" ];
then
        echo -e "\n\n<-- VIO ESXI System Information on $SITE -->\n";
        find $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/ -type f|grep esxi -i|grep dmidecode|xargs cat|egrep --colour 'vim.host.Summary|Product Name|System Information|CPU|Size'|sed "s/Size/Memory Device Size/g"|sed "s#Version#Processor Version#g"|sed "s/^/\t/g";
#VIO ESXI Resource Metrics
        echo -e "\n\n<-- VIO ESXI Resource Metrics on $SITE for ${i}-${DDP_MONTH}-20${DDP_YR}-->\n\tVmWare Performance Mgmt Metric Daily Averages\n";

        for ESXI_Host in `find $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/remotehosts/ -maxdepth 1 -type d -name "*ESXI"|sed 's#/# #g'|awk '{print $NF}'`;
        do echo -e "\n\tESXI_HOST: $ESXI_Host\n";
        find $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/remotehosts/ -type f|grep $ESXI_Host|grep esxi_metrics.txt|xargs grep mem.usage.average|sed 's#;#\t#g'|awk '{sum+=$4} END { print "\t\tMemory Usage Daily Average (Percent) = ",sum/NR/100"%"'};
        find $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/remotehosts/ -type f|grep $ESXI_Host|grep esxi_metrics.txt|xargs grep cpu.usage.average|sed 's#;#\t#g'|awk '{sum+=$4} END { print "\t\tCPU Usage Daily Average (Percent) = ",sum/NR/100"%"}';
        find $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/remotehosts/ -type f|grep $ESXI_Host|xargs grep cpu.ready.summation|sed 's#;#\t#g'|awk '{sum+=$4} END { print "\t\tCPU Ready Summation Daily Average (Seconds) = ",sum/NR/1000" sec"}'
        if find $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/remotehosts/ -type f|grep $ESXI_Host|grep esxi_metrics.txt|xargs grep  -q cpu.costop.summation;
                then
                find $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/remotehosts/ -type f|grep $ESXI_Host|grep esxi_metrics.txt|xargs grep cpu.costop.summation|sed 's#;#\t#g'|awk '{sum+=$4} END { print "\t\tCPU Co-Stop Summation Daily Average (Seconds) = ",sum/NR/1000" sec"}';
                else
                echo -e "\t\tNo CPU Co-Stop Summation Daily Average Data";
        fi;
	        if find $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/remotehosts/ -type f|grep $ESXI_Host|grep esxi_metrics.txt|xargs grep  -q disk.write.average;
                then
                find $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/remotehosts/ -type f|grep $ESXI_Host|grep esxi_metrics.txt|xargs grep disk.write.average|sed 's#;#\t#g'|awk '{sum+=$4} END { print "\t\tDisk Write Daily Average (kiloBytesPerSecond) = ",sum/NR" kBytes/sec"}';
		find $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/remotehosts/ -type f|grep $ESXI_Host|grep esxi_metrics.txt|xargs grep disk.read.average|sed 's#;#\t#g'|awk '{sum+=$4} END { print "\t\tDisk Read Daily Average (kiloBytesPerSecond) = ",sum/NR" kBytes/sec"}';
		else
                echo -e "\t\tNo Disk Read/Write Daily Average Data";
        fi;



        done;

fi
SAM_FILE=`find $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/ -type f |grep servicereg|grep message|head -1`
if [ -e "$SAM_FILE" ];
then
        echo -e "\n\n<-- Simple Availability Manager Events on $SITE -->\n";
        find $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/ -type f|grep servicereg|grep message|xargs cat|grep SAM|egrep --colour 'Notifying|STARTED'|sed "s/^/\t/g";
        echo -e "\n\n\t<-- Service Registry Leadership Change Events on ${i}-${DDP_MONTH}-20${DDP_YR}-->\n";
        find $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/ -type f|grep servicereg|grep message|xargs cat|egrep --colour consul|egrep --colour 'raft: Node'|sed "s/^/\t/g";
        echo -e "\n\n\t<-- Consul Member HA Events on $SITE -->\n";
        find $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/ -type f|grep servicereg|grep message|xargs cat|egrep --colour consul|egrep --colour 'EventMemberFailed'|sort -nk2|sed "s/^/\t/g";
fi



# Determine key events from VIO and Cloud Workflow Log on a particular day
if [ -f $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/workflows.log  ]; then
        echo -e "\n\n<-- Key Workflow Events on $SITE -->\n";
        ls $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/workflows.log|xargs cat|sed 's#}#\n#g'|sed 's#{#\n#g'|grep --colour -oP .*eventTime|sort |uniq -c|sed 's#"##g'|sed 's#, eventTime##g'|grep -oP businessKey.*|sed "s/^/\t/g";
fi

if [ -f $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/workflows.log.gz  ]; then
        echo -e "\n\n<-- Key Workflow Events on $SITE -->\n";
        ls $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/workflows.log.gz|xargs zcat|sed 's#}#\n#g'|sed 's#{#\n#g'|grep --colour -oP .*eventTime|sort |uniq -c|sed 's#"##g'|sed 's#, eventTime##g'|grep -oP businessKey.*|sed "s/^/\t/g";
fi






#echo -e "\n\nNeo4j Leadership pattern Status -->";

if [ -f $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/neo4j/cluster_overview.log ]; then
        echo -e "\n\n<-- Neo4j Cluster Type on $SITE -->";
        grep neo4j_cluster $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/global.properties|awk -F "=" '{print $1,":\t",$2}'|sed "s/^/\t/g";
        echo -e "\n\n<-- Neo4j Leadership pattern Status on $SITE -->";
        echo -e "\n\t <--- Times observed as Leader --->";
        cat $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/neo4j/cluster_overview.log|egrep LEADER --colour|sort |uniq -c|sed "s/^/\t/g";
        echo -e "\n\n<-- Neo4j Leader-Follower pattern on on $SITE on ${i}-${DDP_MONTH}-20${DDP_YR}-->\n\t\tIn normal instances 96 reads would be anticipated for each instance over 24hrs\n";
        cat $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/neo4j/cluster_overview.log|egrep --colour '.*FOLLOWER|.*LEADER'|awk -F ":" '{print $1,$2}'|sort|uniq -c|sed "s/^/\t/g";

        echo -e "\n\n<-- Moving to Leader timings as determined by neo4j debug logs on ${i}-${DDP_MONTH}-20${DDP_YR}-->\n";
#        cat $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/neo4j/debug.*|sort -nk2|egrep --colour 'Moving to LEADER'
        egrep --colour 'Moving to' $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/neo4j/debug.*|grep debug.* -oP|grep ${DDP_YR}-${DDP_MONTH}-${i}|sort -nk2|grep --colour 'debug.*:201[8,9]'|sed "s/^/\t/g";
fi




# breakdown of Manged Elements for Site#
if [ -f $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/versant/dps_integration.object_count ]; then
        echo -e "\n<-- Breakdown of ManagedElements for ${SITE}: DPS Versant  -->";
        grep --colour -w ns_.*_ManagedElement $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/versant/dps_integration.object_count|grep -v "^0 "|sort -rnk1|column -t|sed "s/^/\t/g"


        if [ -f $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/versant/mo/ns_OSS_NE_DEF.Pt_NetworkElement.gz ]; then
                echo -e "\n<-- Breakdown of NetworkElements for ${SITE}: DPS Versant: Live Bucket  -->";
                zcat $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/versant/mo/ns_OSS_NE_DEF.Pt_NetworkElement.gz|egrep "bucketName.*Live|at_neType"|grep bucketName.*Live -A1|grep -oP at_neType.*|sed 's#..=##g'|sort|uniq -c|sort -rnk1|column -t|sed "s/^/\t/g";
        elif [ -f $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/versant/mo/ns_OSS_NE_DEF.Pt_NetworkElement ]; then
                echo -e "\n<-- Breakdown of NetworkElements for ${SITE}: DPS Versant: Live Bucket  -->";
                cat $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/versant/mo/ns_OSS_NE_DEF.Pt_NetworkElement|egrep "bucketName.*Live|at_neType"|grep bucketName.*Live -A1|grep -oP at_neType.*|sed 's#..=##g'|sort|uniq -c|sort -rnk1|column -t|sed "s/^/\t/g";
        else
                echo -e "";
        fi



        echo -e "\n<-- Subscriptions on $SITE Deployment: DPS Versant  -->";
        cat $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/versant/dps_integration.object_count|grep --colour Subscription|sed 's/\./\t/g'|awk '{print $1,$2,$3}'|grep -v ^0|sort -rnk1|column -t|sed "s/^/\t/g";
fi

# breakdown of Manged Elements for Site#
if [ -f $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/neo4j/mo.counts ]; then
        echo -e "\n<-- Breakdown of ManagedElements for ${SITE}: DPS Neo4j  -->";
        grep --colour ManagedElement -w $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/neo4j/mo.counts |awk '{print$2,$1}'|sort -rnk1|column -t|sed "s/^/\t/g"
        echo -e "\n<-- Subscriptions on $SITE Deployment:DPS Neo4j  -->";
        cat $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/neo4j/mo.counts|grep --colour Subscription|sed 's/:/\t/g'|sed 's/\./\t/g'|awk '{print $3,$1,$2}'|sort -rnk1|column -t|grep -v ^0|sed "s/^/\t/g";
fi

# breakdown of Network Elements for Site#
        if [ -f $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/neo4j/mo/OSS_NE_DEF:NetworkElement.gz ]; then
                echo -e "\n<-- Breakdown of NetworkElements for ${SITE}: DPS Neo4j: Live Bucket  -->";
                zcat $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/neo4j/mo/OSS_NE_DEF:NetworkElement.gz|sed 's#]#\n#g'|grep -oP Live.*SubNetwork|sed 's#Live", ##g'|sed 's#, "SubNetwork##g'|sort|uniq -c|sort -rnk1|sed "s/^/\t/g";
        elif [ -f $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/neo4j/mo/OSS_NE_DEF:NetworkElement ]; then
                echo -e "\n<-- Breakdown of NetworkElements for ${SITE}: DPS Neo4j: Live Bucket  -->";
                cat $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/neo4j/mo/OSS_NE_DEF:NetworkElement|sed 's#]#\n#g'|grep -oP Live.*SubNetwork|sed 's#Live", ##g'|sed 's#, "SubNetwork##g'|sort|uniq -c|sort -rnk1|sed "s/^/\t/g";
        else
                echo -e "";
        fi


#         echo -e "\n<-- Subscriptions on $SITE Deployment:DPS Neo4j  -->";
#         cat $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/neo4j/mo.counts|grep --colour Subscription|sed 's/:/\t/g'|sed 's/\./\t/g'|awk '{print $3,$1,$2}'|sort -rnk1|column -t|grep -v ^0|sed "s/^/\t/g";
# fi

# backup Operation
if [ -f $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/bur/opt/ericsson/itpf/bur/log/bos/bos.log ]; then
        echo -e "\n<-- Identify Backup and Result in bos.log for ${i}-${DDP_MONTH}-20${DDP_YR}. -->"
        cat $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/bur/opt/ericsson/itpf/bur/log/bos/bos.log*|grep --colour "Finished .BOSsystem_backupOperation.*" -oP|sort|uniq|sed "s/^/\t/g"
elif [ -f $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/bur/opt/ericsson/itpf/bur/log/bos/bos.log.gz ]; then
        echo -e "\n<-- Identify Backup and Result in bos.log for ${i}-${DDP_MONTH}-20${DDP_YR}. -->"
        zcat $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/bur/opt/ericsson/itpf/bur/log/bos/bos.log.gz|grep --colour "Finished .BOSsystem_backupOperation.*" -oP|sort|uniq|sed "s/^/\t/g"
else
        echo -e "\n<-- Identify Backup and Result in bos.log -->"
        echo -e "\tNo Backup Executed on Physical Deployment ${i}-${DDP_MONTH}-20${DDP_YR}.\n\tDoes not apply to Cloud or VIO Deployment Types.\n"
fi

MDT_FILE=`find $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/tor_servers/ -type f -name "mdt.log"|head -1`
if [ -e "$MDT_FILE" ]; then
# find /net/ddpenm2/data/stats/tor/LMI_ENM404/data/${i}0319/tor_servers/ -type f -name "mdt.log"
        echo -e "\n<--- MDT Activities on ${SITE}: ${i}-${DDP_MONTH}-20${DDP_YR} --->\n";
#        zcat $DDP/$SITE/analysis/${i}${DDP_MONTH}${DDP_YR}/enmlogs/*csv.gz |sed 's/#012/\n/g'| sed 's/#011/\t/g'|grep "@MDT@" --colour|egrep --colour "DeploymentDelta|XmlRepoWriter|Phase . completed|MDT@ ERROR"|sed "s/^/\t/g"
	find $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/tor_servers/ -type f -name "mdt.log"|xargs cat|sed "s/^/\t/g"|egrep -vi "DeploymentDelta.*Extracting models from Jar files|DeploymentDelta.*Extracting models from.*JAR"|egrep --colour "DeploymentDelta|XmlRepoWriter|Phase . completed|ERROR|WARN";
else
	echo -e "";
fi


        echo -e "\n<--- NAS Issues Identified on ${SITE}: ${i}-${DDP_MONTH}-20${DDP_YR} --->\n";
        zcat $DDP/$SITE/analysis/${i}${DDP_MONTH}${DDP_YR}/enmlogs/*csv.gz |grep -wi nas|sed 's/#012/\n/g'| sed 's/#011/\t/g'|egrep "@ ERROR"
        echo -e "\n<--- LVSROUTER Issues Identified on ${SITE}: ${i}-${DDP_MONTH}-20${DDP_YR} --->\n";
        zcat $DDP/$SITE/analysis/${i}${DDP_MONTH}${DDP_YR}/enmlogs/*csv.gz |grep 'lvsrouter.*@LVSROUTER@'|sed 's/#012/\n/g'| sed 's/#011/\t/g'|egrep "@ ERROR" -B1|sed "s/^/\t/g"
        echo -e "\n<--- JMS  Issues Identified on ${SITE}: ${i}-${DDP_MONTH}-20${DDP_YR} --->\n";
        echo -e "\n\t<--- JMS ERRORS: Queues/Topics Full --->\n";
        zcat $DDP/$SITE/analysis/${i}${DDP_MONTH}${DDP_YR}/enmlogs/*csv.gz|sed 's/#012/\n/g'| sed 's/#011/\t/g'|grep --colour @JMS@ERROR|grep -oP ADDRESS_FULL.*|sort|uniq -c;
        echo -e "\n\t<--- JMS ERRORS: Illegal State Message  --->\n";
        zcat $DDP/$SITE/analysis/${i}${DDP_MONTH}${DDP_YR}/enmlogs/*csv.gz|sed 's/#012/\n/g'| sed 's/#011/\t/g'|grep --colour @JMS@ERROR|grep -oP 'ILLEGAL_STATE.*Cannot find ref to ack'|sort |uniq -c;
        echo -e "\n\t<--- JMS WARNINGS: Messages sent to DLQ --->\n";
        zcat $DDP/$SITE/analysis/${i}${DDP_MONTH}${DDP_YR}/enmlogs/*csv.gz|sed 's/#012/\n/g'| sed 's/#011/\t/g'|grep --colour @JMS@WARN|grep -oP 'reached maximum delivery attempts.*from jms.*'|sort|uniq -c|sort -rnk1;
        echo -e "\n\t<--- JMS WARNINGS: Messages are being dropped --->\n";
        zcat $DDP/$SITE/analysis/${i}${DDP_MONTH}${DDP_YR}/enmlogs/*csv.gz|sed 's/#012/\n/g'| sed 's/#011/\t/g'|grep --colour @JMS@WARN|grep -v 'reached maximum delivery attempts.*'|grep -oP 'HQ222039: Messages are being dropped.*'|sed "s/^/\t/g";

# Determination of TERE Defined workload
PROFILE_LOG_GZ=`find $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/ -type f -name "profiles.log.gz"`
PROFILE_LOG=`find $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/ -type f -name "profiles.log"`

if [ -e "$PROFILE_LOG_GZ" ]; then
	echo -e "\n<--- TERE Defined scheduled Workload Profiles on ${SITE}: ${i}-${DDP_MONTH}-20${DDP_YR} --->\n";
	find $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/ -type f -name "profiles.log.gz"|xargs zcat|grep 'INFO.*Profile is running' -oP --colour|sort|uniq -c|sed 's#INFO - ##g'|sed 's# - Profile is running#\tScheduled Profile Run(s):#g'|sort -rnk1|awk '{print "\t",$1"\t"$3,$4,$5,$2}';
        echo -e "\n<--- Number of Errors detected for Workload Profiles --->\n";
        find $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/ -type f -name "profiles.log.gz"|xargs zcat|grep --colour -w ERROR|awk '{print $4,$6}'|sort|uniq -c|sort -rnk1|sed 's#ERROR#ERROR(S)#g'|sed "s/^/\t/g"
elif [ -e "$PROFILE_LOG" ]; then
	echo -e "\n<--- TERE Defined scheduled Workload Profiles on ${SITE}: ${i}-${DDP_MONTH}-20${DDP_YR} --->\n";
        find $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/ -type f -name "profiles.log"|xargs cat|grep 'INFO.*Profile is running' -oP --colour|sort|uniq -c|sed 's#INFO - ##g'|sed 's# - Profile is running#\tScheduled Profile Run(s):#g'|sort -rnk1|awk '{print "\t",$1"\t"$3,$4,$5,$2}';
        echo -e "\n<--- Number of Errors detected for Workload Profiles --->\n";
	find $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/ -type f -name "profiles.log"|xargs cat|grep --colour -w ERROR|awk '{print $4,$6}'|sort|uniq -c|sort -rnk1|sed 's#ERROR#ERROR(S)#g'|sed "s/^/\t/g"
else
	echo -e ""
fi


#echo -e "\nTotal Number of DPS Events:";

if [ -f $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/jms/dps.events.gz ]; then
        echo -e "\n<-- Total Number of DPS Events: -->";
        zgrep -c 20${DDP_YR}-${DDP_MONTH}-${i} $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/jms/dps.events.gz|sed "s/^/\t/g"
        echo -e "\n<-- Total Number of Successful DELTA Synchronisations in DPS: -->";
        zcat $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/jms/dps.events.gz|grep --colour "old value=DELTA; new value=SYNCHRONIZED" -c|sed "s/^/\t/g"
        echo -e "\n<-- Total Number of currentServiceState Alarm Ongoing Synchronisations in DPS: -->";
        zcat $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/jms/dps.events.gz|egrep --colour "Attribute name=currentServiceState; old value=IN_SERVICE; new value=SYNC_ONGOING" -c|sed "s/^/\t/g"

fi

if [ -f $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/jms/dps.events ]; then
        echo -e "\n<-- Total Number of DPS Events: -->";
        grep -c 20${DDP_YR}-${DDP_MONTH}-${i} $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/jms/dps.events|sed "s/^/\t/g";
        echo -e "\n<-- Total Number of Successful DELTA Synchronisations in DPS: -->";
        cat $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/jms/dps.events|grep --colour "old value=DELTA; new value=SYNCHRONIZED" -c|sed "s/^/\t/g"
        echo -e "\n<-- Total Number of currentServiceState Alarm Ongoing Synchronisations in DPS: -->";
        cat $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/jms/dps.events|egrep --colour "Attribute name=currentServiceState; old value=IN_SERVICE; new value=SYNC_ONGOING" -c |sed "s/^/\t/g"
fi


if [ -f $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/neo4j/OpenAlarmCount.txt ]; then
        echo -e "\n<-- OpenAlarms Overview: DPS Neo4j -->";
        echo -e "\n\t\tOpenAlarms: Lowest Value\n\t\t   Time\t   Value\n\t\t________________________\n"
        more $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/neo4j/OpenAlarmCount.txt|sort -nk2|head -1|sed "s/^/\t\t/g";
        echo -e "\n\t\tOpenAlarms: Highest Value\n\t\t   Time\t   Value\n\t\t________________________\n"
        more $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/neo4j/OpenAlarmCount.txt|sort -nk2|tail -1|sed "s/^/\t\t/g";
fi

if [ -f $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/versant/OpenAlarmCount.txt ]; then
        echo -e "\n<-- OpenAlarms Overview: DPS Versant -->";
        echo -e "\n\t\tOpenAlarms: Lowest Value\n\t\t   Time\t   Value\n\t\t________________________\n"
        more $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/versant/OpenAlarmCount.txt|sort -nk2|head -1|sed "s/^/\t\t/g";
        echo -e "\n\t\tOpenAlarms: Highest Value\n\t\t   Time\t   Value\n\t\t________________________\n"
        more $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/versant/OpenAlarmCount.txt|sort -nk2|tail -1|sed "s/^/\t\t/g";
fi



#echo -e "\nBreakdown of namespace hits";
if [ -f $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/jms/dps.events.gz ]; then
echo -e "\n<-- Breakdown of namespace hits -->"
zcat $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/jms/dps.events.gz|grep -oP "Namespace.*"|sed 's/scope./scope\n/g'|sed 's/nodeselection./nodeselection\n/g'|sed 's/Nodes_/Nodes\n/g'|grep --colour Namespace|awk -F ";" '{print "\t",$1,$2}'|sort |uniq -c|sort -rnk1|column -t|sed "s/^/\t/g"
fi

if [ -f $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/jms/dps.events ]; then
echo -e "\n<-- Breakdown of namespace hits -->\n"
cat $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/jms/dps.events|grep -oP "Namespace.*"|sed 's/scope./scope\n/g'|sed 's/nodeselection./nodeselection\n/g'|sed 's/Nodes_/Nodes\n/g'|grep --colour Namespace|awk -F ";" '{print "\t",$1,$2}'|sort |uniq -c|sort -rnk1|column -t|sed "s/^/\t/g"
fi

echo -e "\n<--- Optimistic Lock Transactions: --->\n"
zgrep "OptimisticLockException" $DDP/$SITE/analysis/${i}${DDP_MONTH}${DDP_YR}/enmlogs/*csv.gz|sed 's/#012/\n/g' | sed 's/#011/\t/g' |grep -oP '@svc-.*-.*@JBOSS@'|sort|uniq -c|sort -rnk 1| sed "s/^/\t/g"
echo -e "\n<--- Dead Lock Count: --->\n"
zgrep "DEADLOCK" $DDP/$SITE/analysis/${i}${DDP_MONTH}${DDP_YR}/enmlogs/*csv.gz|sed 's/#012/\n/g' | sed 's/#011/\t/g' |grep -oP '@svc-.*-.*@JBOSS@'|sort|uniq -c|sort -rnk 1| sed "s/^/\t/g"

#if [ -f $DDP/$SITE/analysis/${i}${DDP_MONTH}${DDP_YR}/enmlogs/*csv.gz ]; then
        echo -e "\n<-- Number of Failures to Invoke Flow Policy -->\n";
        zgrep --colour "invoke policy for .* and request .*TaskRequest" $DDP/$SITE/analysis/${i}${DDP_MONTH}${DDP_YR}/enmlogs/*csv.gz|sed 's/#012/\n/g'| sed 's/#011/\t/g'|grep --colour "invoke policy for .* and request MediationTaskRequest |invoke policy for .* and request PersistenceTaskRequest:" -oP|sort|uniq -c|sort -rnk1|head;
#fi

# breakdown of Versant Transaction issues
if [ -f $DDP/$SITE/data/${i}${DDP_MONTH}${DDP_YR}/TOR/clustered_data/versant/dps_integration.object_count ]; then
        echo -e "\n<-- Dead Transaction Breakdown: $SITE: DPS Versant  -->\n";
        zcat $DDP/$SITE/analysis/${i}${DDP_MONTH}${DDP_YR}/enmlogs/*csv.gz|sed 's/#012/\n/g' | sed 's/#011/\t/g'|egrep --colour -i 'Versant.*Admin.*WARNING'|grep -oP "Client Name.*XID"|sed 's#, XID##g'|sort|uniq -c|sort -nk1;
        echo -e "\n<-- Repaired Transaction Metrics: $SITE Deployment: DPS Versant  -->\n";
        zcat $DDP/$SITE/analysis/${i}${DDP_MONTH}${DDP_YR}/enmlogs/*csv.gz|sed 's/#012/\n/g' | sed 's/#011/\t/g'|egrep --colour -i 'Versant.*Admin.*repaired'|sed "s/^/\t/g";
fi



if [[ -z $1 ]];
then
    echo -e "\n\n\n\nIncorrect Parameter/Arguements or none at all passed to Deployment Performance script.\n\n\t********** Kep Calm and read below *********\n\n\tTry -help Option in order to see how script works, exiting...\n\n\n\n"
    exit 1
fi




echo -e "\n\t##############################################################\n"
done
echo "$0 - script complete - $(date)"

