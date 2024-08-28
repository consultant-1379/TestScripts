import requests

cluster_id_cloud = {'625', ''}


def postRequestCloud(clusterId, cmd_option, jira_ticket, usertype, mail1, mail2):
	url = 'https://fem8s11-eiffel004.eiffel.gic.ericsson.se:8443/jenkins/view/S4/job/S4_Users_Management/buildWithParameters?'
	url += 'clusterId=' + clusterId + '&deployment_type=Cloud&cmd_option=' + cmd_option
	url += '&jira_ticket=' + jira_ticket + '&usertype=' + usertype + '&mail_list=' + mail1 + ',' + mail2
	x = requests.post(url, auth=('S4USER', 'nBeCp6dyHvV2cZhJnbkBMsMz'))
	print(x.status_code)


def ApprovedMail(issue_key, deployment, team_loc):
	jira_url = "https://jira-oss.seli.wh.rnd.internal.ericsson.com/browse/{}".format(issue_key)
	content = '''
			<html>
				<body>
					<p>
						<a href='{0}'>{1}</a> has transitioned to Approved state for deployment {2}<br>
						Team Location: {3}<br>
					</p>
				</body>
			</html>
			'''.format(jira_url, issue_key, deployment, team_loc)
	subject = "{0} is Approved for {1}".format(issue_key, deployment)
	url = 'https://fem8s11-eiffel004.eiffel.gic.ericsson.se:8443/jenkins/view/S4/job/S4JLemailNonEricsson/buildWithParameters?'
	url += 'email_address=PDLTEAMGRI@pdl.internal.ericsson.com' + '&email_subject=' + subject
	url += '&email_content=' + content
	x = requests.post(url, auth=('S4USER', 'nBeCp6dyHvV2cZhJnbkBMsMz'))
	print(x.status_code)
