<?php
//    https://arm1s11-eiffel004.eiffel.gic.ericsson.se:8443/nexus/service/local/repositories/releases/content/com/ericsson/oss/servicegroupcontainers/ERICenmsgnetworkexplorer_CXP9031630/1.19.2/ERICenmsgnetworkexplorer_CXP9031630-1.19.2.rpm 


$step=$_GET['step'];


if($step=="update_old_rpm_name"){
	$old_rpm_name=$_GET['old_rpm_name'];
	$jira_ticket_id=$_GET['jira_ticket_id'];
	$timestamp=$_GET['timestamp'];
	$log_file_name=$_GET['log_file_name'];
	
	// Put entry in DB
	$con = mysql_connect("localhost","root","") or die(mysqlConnectError());
	if(mysql_select_db("s4_rpm")){
	
	
	}
	else{
		echo "{\"LEVEL\":\"ERROR\",\"MESSAGE\":\"DB Connection Error\"}";
		die(mysqlSelectDBError());
	}
	
	$query="UPDATE installation set orignal_rpm='".$old_rpm_name."',log_file_name='".$log_file_name."' where jira_ticket_id='".$jira_ticket_id."' and timestamp=".$timestamp."";
	
	
	$mysql_result = mysql_query($query);
	
	if(!$mysql_result){
	
		echo 1;
	
	}
	else{
	
		echo 0;
	}
	
}

if($step=="update_logs"){

	$b64Logs=$_POST['b64logs'];
	$jira_ticket_id=$_GET['jira_ticket_id'];
	$timestamp=$_GET['timestamp'];

	// Put entry in DB
	$con = mysql_connect("localhost","root","") or die(mysqlConnectError());
	if(mysql_select_db("s4_rpm")){


	}
	else{
		echo "{\"LEVEL\":\"ERROR\",\"MESSAGE\":\"DB Connection Error\"}";
		die(mysqlSelectDBError());
	}

	$query="UPDATE installation set log='".$b64Logs."' where jira_ticket_id='".$jira_ticket_id."' and timestamp=".$timestamp."";


	$mysql_result = mysql_query($query);

	if(!$mysql_result){

		echo 1;

	}
	else{

		echo 0;
	}
}
if($step=="update_status"){
	$status=$_GET['status'];
	$jira_ticket_id=$_GET['jira_ticket_id'];
	$timestamp=$_GET['timestamp'];

	// Put entry in DB
	$con = mysql_connect("localhost","root","") or die(mysqlConnectError());
	if(mysql_select_db("s4_rpm")){

		
	}
	else{
		echo "{\"LEVEL\":\"ERROR\",\"MESSAGE\":\"DB Connection Error\"}";
		die(mysqlSelectDBError());
	}

	echo $query="UPDATE installation set status='".$status."' where jira_ticket_id='".$jira_ticket_id."' and timestamp=".$timestamp."";


	$mysql_result = mysql_query($query);

	if(!$mysql_result){

		echo 1;

	}
	else{

		echo 0;
	}

}
if($step=="populate_datatable"){
	
	$deployment_id=$_GET['deployment_id'];
	$con = mysql_connect("localhost","root","") or die(mysqlConnectError());
	if(mysql_select_db("s4_rpm")){
	
	
	}
	else{
		echo "{\"LEVEL\":\"ERROR\",\"MESSAGE\":\"DB Connection Error\"}";
		die(mysqlSelectDBError());
	}

	
	$aColumns = array( 'id','uid','deployment_id','jira_ticket_id', 'rpm_url', 'orignal_rpm','service_groups','status','timestamp','actions'  );
	
	
	$sIndexColumn = "id";
	
	$sTable = installation;
	
	
	$sQuery="SELECT id,uid,deployment_id,jira_ticket_id,rpm_url,orignal_rpm,service_groups,status,timestamp, 'actions' as actions from installation where deployment_id='".$deployment_id."'";
	$rResult = mysql_query( $sQuery);
	
	/*
	 * No Entries found
	*/
	$num_rows = mysql_num_rows($rResult);
	
	
	/* Data set length after filtering */
	$sQuery = "
	 SELECT FOUND_ROWS()
	";
	$rResultFilterTotal = mysql_query( $sQuery);
	$aResultFilterTotal = mysql_fetch_array($rResultFilterTotal);
	$iFilteredTotal = $aResultFilterTotal[0];
	
	/* Total data set length */
	$sQuery = "
		SELECT COUNT(".$sIndexColumn.")
			FROM   $sTable
			";
	$rResultTotal = mysql_query( $sQuery);
	$aResultTotal = mysql_fetch_array($rResultTotal);
	$iTotal = $aResultTotal[0];
	
	
	/*
	* Output
	*/
	$output = array(
	 "columns" => $aColumns
	 );
	
	 while ( $aRow = mysql_fetch_array( $rResult ) )
	 {
	 $row = array();
	 for ( $i=0 ; $i<count($aColumns) ; $i++ )
	 {
	 if ( $aColumns[$i] == "version" )
	 {
	 /* Special output formatting for 'version' column */
	 	$row[] = ($aRow[ $aColumns[$i] ]=="0") ? '-' : $aRow[ $aColumns[$i] ];
	 }
	 else if ( $aColumns[$i] != ' ' )
	 {
	 /* General output */
	 $row[] = $aRow[$aColumns[$i]];
	
	 }
	  }
	   $output['data'][] = $row;
	 }
	
	 echo json_encode( $output );
	 exit;
	
}
if($step==1){

	$deployment_id=$_GET['deploymentid'];
	$rpm_url=$_GET['rpmurl'];
	$step_1_script="/var/www/html/TestScripts/jenkins/enm/teaas/rpm/bash/step_1.sh";
	
	
	$shell=shell_exec(${step_1_script}." ".$deployment_id." ".$rpm_url);
	echo $shell;
	exit;
	
}
if($step=="jira"){
	
	$json=shell_exec('curl -u S4_Team:S4_Team  -H "Content-Type: application/json" -H "Accept: application/json" -X POST -d \'{"maxResults":"250","jql": "project=CIP and component=TEaaS and \"DE Team Name\"=\"S4(Performance)\" and assignee!=unassigned "}\' https://jira-nam.lmera.ericsson.se/rest/api/2/search');
	echo $json;
}
if($step==2){

	$deployment_id=$_GET['deploymentid'];
	$rpm_url=$_GET['rpmurl'];
	$jira_ticket_id=$_GET['jira_ticket'];
	$service_groups=$_GET['service_groups'];
	$install_type=$_GET['install_type'];
	$uid=$_COOKIE['uid'];

	$install_rpm_script="/var/www/html/TestScripts/jenkins/enm/teaas/rpm/bash/apply_rpm.sh";
		
	
	// Put entry in DB 
	$con = mysql_connect("localhost","root","") or die(mysqlConnectError());
	if(mysql_select_db("s4_rpm")){
		
		
	}
	else{
		echo "{\"LEVEL\":\"ERROR\",\"MESSAGE\":\"DB Connection Error\"}";
		die(mysqlSelectDBError());
	}
	
	$timestamp=time();
	$query="INSERT INTO installation  (`id`,`uid`,`deployment_id`,`jira_ticket_id`,`rpm_url`,`install_type`,`service_groups`,`timestamp`,`status`) VALUES ('','".$uid."','".$deployment_id."','".$jira_ticket_id."','".$rpm_url."','".$install_type."','".$service_groups."','".$timestamp."','STARTED')";
	
	$mysql_result = mysql_query($query);
	
	if(!$mysql_result){

			echo "{\"LEVEL\":\"ERROR\",\"MESSAGE\":\"DB Insert Error ".mysql_error()."\"}";
						
	}
	else{
		
		//Kick off the install
		$shell=shell_exec($install_rpm_script." ".$deployment_id." ".$rpm_url." ".$jira_ticket_id." ".$install_type." ".$service_groups." ".$timestamp." >/dev/null &");
		echo "{\"LEVEL\":\"SUCCESS\",\"MESSAGE\":\"${jira_ticket_id} Installation Started\"}";
	}
	

	exit;

}

if(isset($_GET['rollback_orignal_rpm'])){

	$id=$_GET['rollback_orignal_rpm'];
	


	
	$con = mysql_connect("localhost","root","") or die(mysqlConnectError());
	
	if(mysql_select_db("s4_rpm")){
	
	}
	else{
		echo "{\"LEVEL\":\"ERROR\",\"MESSAGE\":\"DB Connection Error\"}";
		die(mysqlSelectDBError());
	}
	
	$query="SELECT * FROM installation where id =".$id;
	
	$mysql_result = mysql_query($query);
	
	$count=0;
	$rows = array();
	while($r = mysql_fetch_assoc($mysql_result)) {
		
		$rows[] = $r;
		$deployment_id=$r['deployment_id'];
		$orignal_rpm=$r['orignal_rpm'];
		$jira_ticket_id=$r['jira_ticket_id'];
		$service_groups=$r['service_groups'];
		$install_type=$r['install_type'];
	}
	
	
	
	//Check ssh connection  ???????????????????????? TO DO
	$check_ssh_script="/var/www/html/TestScripts/jenkins/enm/teaas/rpm/bash/check_ssh.sh";
	$MSIP=substr(shell_exec("wget -q -O - --no-check-certificate \"https://cifwk-oss.lmera.ericsson.se/generateTAFHostPropertiesJSON/?clusterId=".$deployment_id."&tunnel=true\" | awk -F',' '{print $1}' | awk -F':' '{print $2}' | sed -e \"s/\\\"//g\" -e \"s/ //g\" "),0,-1);
	
	$shell_exit_code=shell_exec($check_ssh_script." ".$MSIP);
	if($shell_exit_code!=0){
		
		echo "{\"LEVEL\":\"ERROR\",\"MESSAGE\":\"SSH to LMS failed\"}";
		exit;
	
	}
	
	
	
	
	$rollback_rpm_script="/var/www/html/TestScripts/jenkins/enm/teaas/rpm/bash/rollback_rpm.sh";


	// Put entry in DB
	$con = mysql_connect("localhost","root","") or die(mysqlConnectError());
	if(mysql_select_db("s4_rpm")){


	}
	else{
		echo "{\"LEVEL\":\"ERROR\",\"MESSAGE\":\"DB Connection Error\"}";
		die(mysqlSelectDBError());
	}

	$timestamp=time();
	
	$query="INSERT INTO installation  (`id`,`deployment_id`,`jira_ticket_id`,`rpm_url`,`install_type`,`service_groups`,`timestamp`,`status`) VALUES ('','".$deployment_id."','".$jira_ticket_id."','".$orignal_rpm."','".$install_type."','".$service_groups."','".$timestamp."','STARTED')";
	$mysql_result = mysql_query($query);
	
	
	//$query="UPDATE installation set status='ROLLBACK' where id='".$id."'";
	
	//$mysql_result = mysql_query($query);

	if(!$mysql_result){

		echo "{\"LEVEL\":\"ERROR\",\"MESSAGE\":\"DB Insert Error ".mysql_error()."\"}";
		exit;

	}
	else{
		
		
			$timestamp=time();
			$shell=shell_exec($rollback_rpm_script." ".$deployment_id." ".$orignal_rpm." ".$jira_ticket_id." ".$install_type." ".$service_groups." ".$timestamp." >/dev/null &");
			echo "{\"LEVEL\":\"SUCCESS\",\"MESSAGE\":\"${jira_ticket_id} Rollback Started\"}";
			exit;
	
		
		
		exit;
	}




}


if($_POST['get_detailed_logs']){
	

	$deployment_id=$_POST['get_detailed_logs'];
	$con = mysql_connect("localhost","root","") or die(mysqlConnectError());
	
	if(mysql_select_db("s4_rpm")){

	}
	else{
		echo "{\"LEVEL\":\"ERROR\",\"MESSAGE\":\"DB Connection Error\"}";
		die(mysqlSelectDBError());
	}
	

	$id=$_POST['get_detailed_logs'];
	
	$query="SELECT log FROM installation where id =".$id;
	
	$mysql_result = mysql_query($query);
	
	$count=0;
	$rows = array();
	while($r = mysql_fetch_assoc($mysql_result)) {
		$rows[] = $r;
		$b64Logs=$r['log'];
	}
	
	
	if($b64Logs==""){
		$b64Logs="RGV0YWlsZWQgbG9ncyB3aWxsIGFycml2ZSBhZnRlciB0aGUgam9iIGhhcyBmaW5pc2hlZC4gWW91IGNhbiBtb25pdG9yIHRoZSBSUE0gaW5zdGFsbGF0aW9uIHVzaW5nIHRoZSBtb25pdG9yIGljb24gb24gdGhlIHJpZ2h0LCBpZiB0aGUgam9iIGlzIHN0aWxsIG9uZ29pbmluZwo=";
	}
	$JSON_RESPONSE = array( 'LEVEL'=>'SUCCESS', 'MESSAGE' =>$b64Logs );		
	echo json_encode($JSON_RESPONSE);
	exit;
	
}
if($_POST['get_shortened_monitoring_logs']){

	$id=$_POST['get_shortened_monitoring_logs'];
	$con = mysql_connect("localhost","root","") or die(mysqlConnectError());

	if(mysql_select_db("s4_rpm")){

	}
	else{
		echo "{\"LEVEL\":\"ERROR\",\"MESSAGE\":\"DB Connection Error\"}";
		die(mysqlSelectDBError());
	}


	

	$query="SELECT * FROM installation where id =".$id;

	$mysql_result = mysql_query($query);

	$count=0;
	$rows = array();
	while($r = mysql_fetch_assoc($mysql_result)) {
		$rows[] = $r;
		$log_file_name=$r['log_file_name'];
		$deployment_id=$r['deployment_id'];
	}
	

	if($log_file_name==""){
		$shell="U3RpbGwgd2FpdGluZyBvbiBsb2dzIHRvIGFycml2ZQo=";
	}
	else{
		
		$MSIP=substr(shell_exec("wget -q -O - --no-check-certificate \"https://cifwk-oss.lmera.ericsson.se/generateTAFHostPropertiesJSON/?clusterId=".$deployment_id."&tunnel=true\" | awk -F',' '{print $1}' | awk -F':' '{print $2}' | sed -e \"s/\\\"//g\" -e \"s/ //g\" "),0,-1);
		$shell=shell_exec("ssh  -t -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes  root@".$MSIP." \" cat $log_file_name  | tail -n 10 |  sed 's/$/<br>/' | base64 \""); //cat ".$log_file_name." | tail -n 10 |  sed 's/$/<br>/' | base64");
	}
	
	
	$JSON_RESPONSE = array( 'LEVEL'=>'SUCCESS', 'MESSAGE' =>$shell );
	echo json_encode($JSON_RESPONSE);
	exit;

}
?>