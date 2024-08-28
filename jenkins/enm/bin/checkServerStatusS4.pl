#!/usr/bin/perl

use strict;
use warnings;
use Cwd;
use Sys::Hostname;
use POSIX qw(strftime);
use File::Basename;

my @numNodes = '';
my @numIpv6Nodes = '';
my @numCells = '';
my $numERBS = '';
my $numRadioNodes = '';
my $numSGSN = '';
my $numMGW = '';
my $numRouter6672 = '';
my $numMiniIn = '';
my $numMiniOut = '';
my $FRONTHAUL6080 = '';
my $SBG = '';
my $Router6274 = '';
my $CISCOASR9K = '';
my $Router6675 = '';
my $RBS = '';
my $VEPG = '';
my $JUNIPERMX = '';
my $CSCF = '';
my $RadioTNode = '';
my $RNC = '';
my $MTAS = '';
my $SAPC = '';
my $EPG = '';
my $CISCOASR900 = '';
my $MSRBS_V1 = '';
my $supervisions = '';
my @enmVersion = '';
my @servicesStat = '';
my @fileSys = '';
my @healthCheck = '';
my @workloadStatus = '';
my $activeDb = '';
my @dbSize = '';

sub getNumberOfNodes {
	@numNodes = `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * CmFunction -t'`;
	return $numNodes[$#numNodes];
}

sub getNumberOfIpv6Nodes {
	return `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * CppConnectivityInformation.ipAddress;ComConnectivityInformation.ipAddress -t' | grep -c ':'`;
}

sub getSecurityLevel1 {
	return `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * Security.operationalSecurityLevel==LEVEL_1 -t' | grep 'LEVEL_1' | wc -l`;
}

sub getSecurityLevel2 {
	return `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * Security.operationalSecurityLevel==LEVEL_2 -t' | grep 'LEVEL_2' | wc -l`;
}

sub getNumberOfCells {
	@numCells = `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * EUtranCellFDD -t'`;
	return $numCells[$#numCells];
}

sub getdbSize {
	$activeDb = `/opt/ericsson/enminst/bin/vcs.bsh --groups | grep -i ONLINE | tail -1 | awk '{print \$3}'`;
	@dbSize = `/root/rvb/bin/checkServerStatusS4DbSize.exp $activeDb`;
	my @dbSizeSlice = @dbSize[$#dbSize-4 .. $#dbSize-2];
	return @dbSizeSlice;
}

sub getNumberOfERBS{
	$numERBS = `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * NetworkElement.neType==ERBS -t' | grep -i ERBS | wc -l`;
	return $numERBS;
}

sub getNumberOfRadioNodes {
	$numRadioNodes = `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * NetworkElement.neType==RadioNode -t' | grep -i RadioNode | wc -l`;
	return $numRadioNodes;
}

sub getNumberOfSGSN {
	$numSGSN = `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * NetworkElement.neType==SGSN-MME -t' | grep -i SGSN-MME | wc -l`;
	return $numSGSN;
}

sub getNumberOfMGW {
	$numMGW = `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * NetworkElement.neType==MGW -t' | grep -i MGW | wc -l`;
	return $numMGW;
}

sub getNumberOfRouter6672 {
	$numRouter6672 = `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * NetworkElement.neType==Router6672 -t' | grep -i Router6672 | wc -l`;
	return $numRouter6672;
}

sub getNumberOfMiniIn{
	$numMiniIn = `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * NetworkElement.neType==MINI-LINK-Indoor -t' | grep -i MINI-LINK-Indoor | wc -l`;
	return $numMiniIn;
}

sub getNumberOfMiniOut{
	$numMiniOut = `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * NetworkElement.neType==MINI-LINK-Outdoor -t' | grep -i MINI-LINK-Outdoor | wc -l`;
	return $numMiniOut; 
}

sub getNumberOfFRONTHAUL6080{
	$FRONTHAUL6080 = `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * NetworkElement.neType==FRONTHAUL-6080' | grep -i FRONTHAUL-6080 | wc -l`;
	return $FRONTHAUL6080; 
}

sub getNumberOfSBG{
	$SBG = `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * NetworkElement.neType==SBG -t' | grep -i SBG | wc -l`;
	return $SBG; 
}

sub getNumberOfRouter6274{
	$Router6274 = `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * NetworkElement.neType==Router6274 -t' | grep -i Router6274 | wc -l`;
	return $Router6274; 
}

sub getNumberOfCISCOASR9K{
	$CISCOASR9K = `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * NetworkElement.neType==CISCO-ASR9000 -t' | grep -i CISCO-ASR9000 | wc -l`;
	return $CISCOASR9K; 
}

sub getNumberOfRouter6675{
	$Router6675 = `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * NetworkElement.neType==Router6675 -t' | grep -i Router6675 | wc -l`;
	return $Router6675; 
}

sub getNumberOfRBS{
	$RBS = `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * NetworkElement.neType==RBS -t' | grep -i RBS | wc -l`;
	return $RBS; 
}

sub getNumberOfVEPG{
	$VEPG = `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * NetworkElement.neType==VEPG -t' | grep -i VEPG | wc -l`;
	return $VEPG; 
}

sub getNumberOfJUNIPERMX{
	$JUNIPERMX = `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * NetworkElement.neType==JUNIPER-MX -t' | grep -i JUNIPER-MX | wc -l`;
	return $JUNIPERMX; 
}

sub getNumberOfCSCF{
	$CSCF = `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * NetworkElement.neType==CSCF -t' | grep -i CSCF | wc -l`;
	return $CSCF; 
}

sub getNumberOfRadioTNode{
	$RadioTNode = `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * NetworkElement.neType==RadioTNode -t' | grep -i RadioTNode | wc -l`;
	return $RadioTNode; 
}

sub getNumberOfRNC{
	$RNC = `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * NetworkElement.neType==RNC -t' | grep -i RNC | wc -l`;
	return $RNC; 
}

sub getNumberOfMTAS{
	$MTAS = `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * NetworkElement.neType==MTAS -t' | grep -i MTAS | wc -l`;
	return $MTAS; 
}

sub getNumberOfSAPC{
	$SAPC = `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * NetworkElement.neType==SAPC -t' | grep -i SAPC | wc -l`;
	return $SAPC; 
}

sub getNumberOfEPG{
	$EPG = `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * NetworkElement.neType==EPG -t' | grep -i EPG | wc -l`;
	return $EPG; 
}

sub getNumberOfCISCOASR900{
	$CISCOASR900 = `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * NetworkElement.neType==CISCO-ASR900 -t' | grep -i CISCO-ASR900 | wc -l`;
	return $CISCOASR900; 
}

sub getNumberOfMSRBS_V1{
	$MSRBS_V1 = `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * NetworkElement.neType==MSRBS_V1 -t' | grep -i MSRBS_V1 | wc -l`;
	return $MSRBS_V1; 
}

sub getNumberOfERBSSynced{
	return `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * CmFunction.syncStatus==SYNCHRONIZED --neType=ERBS -t' | grep SYNCHRONIZED | wc -l`;
}

sub getNumberOfRadioNodesSynced {
	return `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * CmFunction.syncStatus==SYNCHRONIZED --neType=RadioNode -t' | grep SYNCHRONIZED | wc -l`;
}

sub getNumberOfSGSNSynced {
	return `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * CmFunction.syncStatus==SYNCHRONIZED --neType=SGSN-MME -t' | grep SYNCHRONIZED | wc -l`;
}

sub getNumberOfMGWSynced {
	return `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * CmFunction.syncStatus==SYNCHRONIZED --neType=MGW -t' | grep SYNCHRONIZED | wc -l`;
}

sub getNumberOfRouter6672Synced {
	return `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * CmFunction.syncStatus==SYNCHRONIZED --neType=Router6672 -t' | grep SYNCHRONIZED | wc -l`;
}

sub getNumberOfMiniInSynced{
	return `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * CmFunction.syncStatus==SYNCHRONIZED --neType=MINI-LINK-Indoor -t' | grep SYNCHRONIZED | wc -l`;
}

sub getNumberOfMiniOutSynced{
	return `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * CmFunction.syncStatus==SYNCHRONIZED --neType=MINI-LINK-Outdoor -t' | grep SYNCHRONIZED | wc -l`;
}

sub getNumberOfFRONTHAUL6080Synced{
	return `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * CmFunction.syncStatus==SYNCHRONIZED --neType=FRONTHAUL-6080 -t' | grep SYNCHRONIZED | wc -l`;
}

sub getNumberOfSBGSynced{
	return `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * CmFunction.syncStatus==SYNCHRONIZED --neType=SBG -t' | grep SYNCHRONIZED | wc -l`;
}

sub getNumberOfRouter6274Synced{
	return `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * CmFunction.syncStatus==SYNCHRONIZED --neType=Router6274 -t' | grep SYNCHRONIZED | wc -l`;
}

sub getNumberOfCISCOASR9KSynced{
	return `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * CmFunction.syncStatus==SYNCHRONIZED --neType=CISCO-ASR9K -t' | grep SYNCHRONIZED | wc -l`;
}

sub getNumberOfRouter6675Synced{
	return `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * CmFunction.syncStatus==SYNCHRONIZED --neType=Router6675 -t' | grep SYNCHRONIZED | wc -l`;
}

sub getNumberOfRBSSynced{
	return `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * CmFunction.syncStatus==SYNCHRONIZED --neType=RBS -t' | grep SYNCHRONIZED | wc -l`;
}

sub getNumberOfVEPGSynced{
	return `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * CmFunction.syncStatus==SYNCHRONIZED --neType=VEPG -t' | grep SYNCHRONIZED | wc -l`;
}

sub getNumberOfJUNIPERMXSynced{
	return `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * CmFunction.syncStatus==SYNCHRONIZED --neType=JUNIPER-MX -t' | grep SYNCHRONIZED | wc -l`;
}

sub getNumberOfCSCFSynced{
	return `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * CmFunction.syncStatus==SYNCHRONIZED --neType=CSCF -t' | grep SYNCHRONIZED | wc -l`;
}

sub getNumberOfRadioTNodeSynced{
	return `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * CmFunction.syncStatus==SYNCHRONIZED --neType=RadioTNode -t' | grep SYNCHRONIZED | wc -l`;
}

sub getNumberOfRNCSynced{
	return `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * CmFunction.syncStatus==SYNCHRONIZED --neType=RNC -t' | grep SYNCHRONIZED | wc -l`;
}

sub getNumberOfMTASSynced{
	return `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * CmFunction.syncStatus==SYNCHRONIZED --neType=MTAS -t' | grep SYNCHRONIZED | wc -l`;
}

sub getNumberOfSAPCSynced{
	return `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * CmFunction.syncStatus==SYNCHRONIZED --neType=SAPC -t' | grep SYNCHRONIZED | wc -l`;
}

sub getNumberOfEPGSynced{
	return `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * CmFunction.syncStatus==SYNCHRONIZED --neType=EPG -t' | grep SYNCHRONIZED | wc -l`;
}

sub getNumberOfCISCOASR900Synced{
	return `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * CmFunction.syncStatus==SYNCHRONIZED --neType=CISCO-ASR900 -t' | grep SYNCHRONIZED | wc -l`;
}

sub getNumberOfMSRBS_V1Synced{
	return `/opt/ericsson/enmutils/bin/cli_app 'cmedit get * CmFunction.syncStatus==SYNCHRONIZED --neType=MSRBS_V1 -t' | grep SYNCHRONIZED | wc -l`;
}

sub getSupervisions{
	$supervisions = `/opt/ericsson/enmutils/bin/network status`;
	$supervisions =~ s/\e\[[\d;]*m//g;
	return $supervisions;
}

sub getENMVersion {
	@enmVersion = `cat /etc/enm-version`;
	return @enmVersion;
}

sub getServicesStatus {
	@servicesStat = `/opt/ericsson/enminst/bin/vcs.bsh --groups | grep -Ei 'Invalid | FAULTED'`;
	if($#servicesStat >= 0){
		return @servicesStat;
	}else{
		return "The service groups are all right.";
	}
}

sub getFilesSystemStatus {
	@fileSys = `df -P | awk '+\$5 >= 80 {print}'`;
	if($#fileSys >= 0){
		return @fileSys;
	}else{
		return "The file system is all right.";
	}
	
}

sub getHealthCheck {
	@healthCheck = `/opt/ericsson/enminst/bin/enm_healthcheck.sh --action enminst_healthcheck`;
	return @healthCheck;
}

sub getWorkloadStatus{
	my $workloadStatus=`/opt/ericsson/enmutils/bin/workload status --info`;
	$workloadStatus =~ s/\e\[[\d;]*m//g;
	return $workloadStatus;
}

sub getHostname{
	my $host=hostname;
	return $host;
}

sub outPutToFile {
	my $dateStringFile = strftime "%d%m%Y", localtime;
	my $path = "/home";
	my $fileName = "sysCheck";
	open my $fh, ">", "$path/" . basename($fileName).$dateStringFile 
  		or die "Cannot open the file: $!";
	print $fh "=====================================================\n";
	print $fh "Host:  ",getHostname(),"\n";
	print $fh getENMVersion(),"\n";
	print $fh "Total number of nodes: \t\t\t",getNumberOfNodes();
	print $fh "Total number of Ipv6 nodes: \t\t",getNumberOfIpv6Nodes();
	print $fh "Total number of nodes in SL1: \t\t",getSecurityLevel1();
	print $fh "Total number of nodes in SL2: \t\t",getSecurityLevel2();
	print $fh "Cells: \t\t\t\t\t",getNumberOfCells();
	print $fh "DB size: \n",getdbSize(),"\n";
	print $fh "____________________________________________________\n\n";
	print $fh "ERBS nodes: \t\t\t\t",getNumberOfERBS();
	print $fh "Radio nodes: \t\t\t\t",getNumberOfRadioNodes();
	print $fh "SGSN-MME nodes: \t\t\t",getNumberOfSGSN();
	print $fh "MGW nodes: \t\t\t\t",getNumberOfMGW();
	print $fh "IPRouter6672 nodes: \t\t\t",getNumberOfRouter6672();
	print $fh "MINI-LINK-Indoor nodes: \t\t",getNumberOfMiniIn();
	print $fh "MINI-LINK-Outdoor nodes: \t\t",getNumberOfMiniOut();
	print $fh "FRONTHAUL-6080 nodes: \t\t",getNumberOfFRONTHAUL6080();
	print $fh "SBG nodes: \t\t\t\t",getNumberOfSBG();
	print $fh "Router6274 nodes: \t\t\t",getNumberOfRouter6274();
	print $fh "CISCO-ASR9K nodes: \t\t\t",getNumberOfCISCOASR9K();
	print $fh "Router6675 nodes: \t\t\t",getNumberOfRouter6675();
	print $fh "RBS nodes: \t\t\t\t",getNumberOfRBS();
	print $fh "VEPG nodes: \t\t\t\t",getNumberOfVEPG();
	print $fh "JUNIPER-MX nodes: \t\t\t",getNumberOfJUNIPERMX();
	print $fh "CSCF nodes: \t\t\t\t",getNumberOfCSCF();
	print $fh "RadioTNode nodes: \t\t\t",getNumberOfRadioTNode();
	print $fh "RNC nodes: \t\t\t\t",getNumberOfRNC();
	print $fh "MTAS nodes: \t\t\t\t",getNumberOfMTAS();
	print $fh "SAPC nodes: \t\t\t\t",getNumberOfSAPC();
	print $fh "EPG nodes: \t\t\t\t",getNumberOfSAPC();
	print $fh "CISCO-ASR900 nodes: \t\t\t",getNumberOfCISCOASR900();
	print $fh "MSRBS_V1 nodes: \t\t\t",getNumberOfMSRBS_V1();
	print $fh "____________________________________________________\n\n";
	if($numERBS>0){
		print $fh "ERBS nodes synced: \t\t\t",getNumberOfERBSSynced();
	}if($numRadioNodes>0){
		print $fh "Radio nodes synced: \t\t\t",getNumberOfRadioNodesSynced();
	}if($numSGSN>0){
		print $fh "SGSN-MME nodes synced: \t\t",getNumberOfSGSNSynced();
	}if($numMGW>0){
		print $fh "MGW nodes synced: \t\t\t",getNumberOfMGWSynced();
	}if($numRouter6672>0){
		print $fh "IPRouter6672 nodes synced: \t\t",getNumberOfRouter6672Synced();
	}if($numMiniIn>0){
		print $fh "MINI-LINK-Indoor nodes synced: \t",getNumberOfMiniInSynced();
	}if($numMiniOut>0){
		print $fh "MINI-LINK-Outdoor nodes synced: \t",getNumberOfMiniOutSynced();
	}if($FRONTHAUL6080>0){
		print $fh "FRONTHAUL-6080 nodes synced: \t",getNumberOfFRONTHAUL6080Synced();
	}if($SBG>0){
		print $fh "SBG nodes synced: \t\t\t",getNumberOfSBGSynced();
	}if($Router6274>0){
		print $fh "Router6274 nodes synced: \t\t",getNumberOfRouter6274Synced();
	}if($CISCOASR9K>0){
		print $fh "CISCO-ASR9K nodes synced: \t\t",getNumberOfCISCOASR9KSynced();
	}if($Router6675>0){
		print $fh "Router6675 nodes synced: \t\t",getNumberOfRouter6675Synced();
	}if($RBS>0){
		print $fh "RBS nodes synced: \t\t\t",getNumberOfRBSSynced();
	}if($VEPG>0){
		print $fh "VEPG nodes synced: \t\t\t",getNumberOfVEPGSynced();
	}if($JUNIPERMX>0){
		print $fh "JUNIPER-MX nodes synced: \t\t",getNumberOfJUNIPERMXSynced();
	}if($CSCF>0){
		print $fh "CSCF nodes synced: \t\t\t",getNumberOfCSCFSynced();
	}if($RadioTNode>0){	
		print $fh "RadioTNode nodes synced: \t\t",getNumberOfRadioTNodeSynced();
	}if($RNC>0){
		print $fh "RNC nodes synced: \t\t\t",getNumberOfRNCSynced();
	}if($MTAS>0){	
		print $fh "MTAS nodes synced: \t\t\t",getNumberOfMTASSynced();
	}if($SAPC>0){
		print $fh "SAPC nodes synced: \t\t\t",getNumberOfSAPCSynced();
	}if($EPG>0){
		print $fh "EPG nodes synced: \t\t\t",getNumberOfEPGSynced();
	}if($CISCOASR900>0){
		print $fh "CISCO-ASR900 nodes synced: \t\t",getNumberOfCISCOASR900Synced();
	}if($MSRBS_V1>0){
		print $fh "MSRBS_V1 nodes synced: \t\t",getNumberOfMSRBS_V1Synced();
	}
	print $fh "____________________________________________________\n";
	print $fh "\n",getSupervisions(),"\n";
	print $fh "____________________________________________________\n";
	print $fh "============Services Status============\n";
	print $fh "\n",getServicesStatus(),"\n";
	print $fh "============Files System Status============\n";
	print $fh "\n","Printing out only File Systems that exceed 80% use","\n",getFilesSystemStatus(),"\n";
	print $fh "============ENM Health Check============\n";
	print $fh "\n",getHealthCheck(),"\n";
	print $fh "============Workload Status=============\n";
	print $fh "\n",getWorkloadStatus(),"\n";
	print $fh "=====================================================\n";
	close $fh;
	print "done\n";
}

outPutToFile();