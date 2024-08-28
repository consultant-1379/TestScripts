<?php

	$dir="/var/www/html/TestScripts/jenkins/enm/teaas/calendar/json";
	$jira_json_file="restcall.json";
	
	$issue="CIP-19047";
	$file_handler = fopen($dir."/".$jira_json_file, "w") or die("Unable to open file!");
	//$json=shell_exec('curl -u S4_Team:S4_Team  -H "Content-Type: application/json" -H "Accept: application/json" -X POST -d \'{"expand":["changelog"],"maxResults":"150","jql": "project=CIP and component=TEaaS and \"DE Team Name\"=\"S4(Performance)\" and issue='.$issue.'"}\' https://jira-nam.lmera.ericsson.se/rest/api/2/search');
	$json=shell_exec('curl -u S4_Team:S4_Team  -H "Content-Type: application/json" -H "Accept: application/json" -X POST -d \'{"expand":["changelog"],"maxResults":"250","jql": "project=CIP and component=TEaaS and \"DE Team Name\"=\"S4(Performance)\" and assignee!=unassigned and (status=TESTING or status=OPEN or status=\"IN PROGRESS\" or status=\"ON HOLD\") and created<30d"}\' https://jira-nam.lmera.ericsson.se/rest/api/2/search');
	
	echo $json;
	fwrite($file_handler, $json);



?>