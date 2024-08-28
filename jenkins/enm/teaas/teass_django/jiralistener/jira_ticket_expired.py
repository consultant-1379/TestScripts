import jira
import requests

def startCheck(self):
	comment = """*REMINDER*
					Your time slot is expired. Access will be revoked at 1600 GMT this evening.
					If you want an extension please state why and for how long ASAP.
					*IMPORTANT*
					ALL FILES PRESENT IN YOUR DETS-xxxx USER DIRECTORY WILL BE DELETED. PLEASE SAVE THEM BEFORE 1600 GMT"""
	ResolvedAndExpired = jira.search_for_expiring_today()
	headers = {'Content-type': 'application/json'}
	for t in ResolvedAndExpired:
		jira_url = "https://jira-oss.seli.wh.rnd.internal.ericsson.com:443/rest/api/2/issue/{}/comment".format(t.get_key())
		r = requests.post(jira_url, headers=headers, json={'body': comment}, auth=('S4_Team', 'S4_Team'))
