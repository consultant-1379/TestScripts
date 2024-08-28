<?php
$filter=$_GET['filter'];

$dir="/var/www/html/TestScripts/jenkins/enm/teaas/calendar/json";
$jira_json_file="restcall.json";
header('Cache-Control: public');
header('Content-Type: text/plain');
readfile($dir."/".$jira_json_file);
exit;

if($filter=="ALL_TICKETS"){
	all_tickets();
	exit;
}
if($filter=="ON_HOLD"){
	on_hold_tickets();
	exit;
}
if($filter=="OPEN"){
	open_tickets();
	exit;
}
if($filter=="IN_PROGRESS"){
	in_progress_tickets();
	exit;
}
if($filter=="CLOSED"){
	closed_tickets();
	exit;
}
if($filter=="Testing"){
	in_testing_tickets();
	exit;
}
if($filter=="EXCLUSIVE"){
	exclusive_tickets();
	exit;
}
if(is_numeric($filter)){
	exclusive_tickets();
	exit;
}
if($filter=="CIP-19047"){
	test_ticket($filter);
	exit;
}
function all_tickets(){
	$json=shell_exec('curl -u S4_Team:S4_Team  -H "Content-Type: application/json" -H "Accept: application/json" -X POST -d \'{"maxResults":"150","jql": "project=CIP and component=TEaaS and \"DE Team Name\"=\"S4(Performance)\" and assignee!=unassigned and (status=TESTING or status=OPEN or status=\"IN PROGRESS\" or status=\"ON HOLD\") and created<30d"}\' https://jira-nam.lmera.ericsson.se/rest/api/2/search');
	//$json=shell_exec('curl -u S4_Team:S4_Team  -H "Content-Type: application/json" -H "Accept: application/json" -X POST -d \'{"jql": "project=CIP and component=TEaaS and \"DE Team Name\"=\"S4(Performance)\" and assignee!=unassigned"}\' https://jira-nam.lmera.ericsson.se/rest/api/2/search');
	echo $json;
}
function open_tickets(){
	$json=shell_exec('curl -u S4_Team:S4_Team  -H "Content-Type: application/json" -H "Accept: application/json" -X POST -d \'{"maxResults":"150","jql": "project=CIP and component=TEaaS and \"DE Team Name\"=\"S4(Performance)\" and assignee!=unassigned and status=OPEN"}\' https://jira-nam.lmera.ericsson.se/rest/api/2/search');
	echo $json;
}
function closed_tickets(){
	$json=shell_exec('curl -u S4_Team:S4_Team  -H "Content-Type: application/json" -H "Accept: application/json" -X POST -d \'{"maxResults":"500","jql": "project=CIP and component=TEaaS and \"DE Team Name\"=\"S4(Performance)\" and created<60d and assignee!=unassigned and status=CLOSED" }\' https://jira-nam.lmera.ericsson.se/rest/api/2/search');
	echo $json;
}
function in_progress_tickets(){
	$json=shell_exec('curl -u S4_Team:S4_Team  -H "Content-Type: application/json" -H "Accept: application/json" -X POST -d \'{"maxResults":"150","jql": "project=CIP and component=TEaaS and \"DE Team Name\"=\"S4(Performance)\" and assignee!=unassigned and status=\"IN PROGRESS\""}\' https://jira-nam.lmera.ericsson.se/rest/api/2/search');
	echo $json;
}
function in_testing_tickets(){
	//$json=shell_exec('curl -u S4_Team:S4_Team  -H "Content-Type: application/json" -H "Accept: application/json" -X POST -d \'{"maxResults":"150","jql": "project=CIP and component=TEaaS and \"DE Team Name\"=\"S4(Performance)\" and assignee!=unassigned and status=TESTING"}\' https://jira-nam.lmera.ericsson.se/rest/api/2/search');
	//echo $json;
	
	$dir="/var/www/html/TestScripts/jenkins/enm/teaas/calendar/json";
	$jira_json_file="restcall.json";
	
	header('Cache-Control: public');
	header('Content-Type: text/plain');
	readfile($dir."/".$jira_json_file);
	
}
function on_hold_tickets(){
	$json=shell_exec('curl -u S4_Team:S4_Team  -H "Content-Type: application/json" -H "Accept: application/json" -X POST -d \'{"maxResults":"150","jql": "project=CIP and component=TEaaS and \"DE Team Name\"=\"S4(Performance)\" and assignee!=unassigned and status=\"ON HOLD\""}\' https://jira-nam.lmera.ericsson.se/rest/api/2/search');
	echo $json;
}
function exclusive_tickets(){
	$json=shell_exec('curl -u S4_Team:S4_Team  -H "Content-Type: application/json" -H "Accept: application/json" -X POST -d \'{"maxResults":"150","jql": "project=CIP and component=TEaaS and \"DE Team Name\"=\"S4(Performance)\" and assignee!=unassigned and status!=CLOSED"}\' https://jira-nam.lmera.ericsson.se/rest/api/2/search');
	echo $json;
}
function test_ticket($issue){
	$dir="/var/www/html/TestScripts/jenkins/enm/teaas/calendar/json";
	$jira_json_file="restcall.json";
	header('Cache-Control: public');
	header('Content-Type: text/plain');	
	readfile($dir."/".$jira_json_file);
}


?>
