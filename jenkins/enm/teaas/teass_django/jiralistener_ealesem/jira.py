
import json
import re
import requests

def search_for_issues(json_for_query):
    jira_url = "https://jira-oss.seli.wh.rnd.internal.ericsson.com:443/rest/api/2/search"
    headers = {'Content-type': 'application/json'}
    response = requests.post(jira_url, headers=headers, json=json_for_query, auth=('S4_Team', 'S4_Team'))
    parsed_response = json.loads(response.content)
    jira_issues = []
    for json_issue in parsed_response['issues']:
        jira_issue = Jira_Issue(json_issue)
        jira_issues.append(jira_issue)
    return jira_issues


def get_issues_in_status(deployment, status):
    jql_query = "project = CIP and " \
                "component = TEaas and " \
                "'DE Team Name' = 'S4(performance)' and " \
                "Environment ~ {} and " \
                "status = '{}'".format(deployment, status)
    json_query = {"jql": jql_query,
                  "startAt":0,
                  "maxResults":1000}
    return search_for_issues(json_query)


class Jira_Issue:
    def __init__(self,json_issue):
        self.json_issue = json_issue
    def __str__(self):
        return self.get_key()

    def get_key(self):
        return self.json_issue.get('key')

    def get_project(self):
        return self.get_field('project','key')

    def get_type_of_server_access(self):
        if self.get_field('customfield_25604') is None:
            return 'Shared'
        return self.get_field('customfield_25604','value')

    def get_deployment_id(self):
        return self.find_deployment_id_string_in_environment_field(self.get_environment())

    def find_deployment_id_string_in_environment_field(self, environment):
        if environment is None:
            return None
        pattern = re.compile("\d{3}")
        match = re.search(pattern, environment)
        if match:
            return match.group(0)
        return None

    def get_field(self, field, subfield=None):
        if subfield is None:
            return self.json_issue['fields'].get(field)
        else:
            return self.json_issue['fields'][field].get(subfield)

    def get_environment(self):
        return self.get_field('environment')

    def get_status(self):
        return self.get_field('status','name')

    def get_reporter_email_address(self):
        return self.get_field('reporter','emailAddress')

    def get_reporter_name(self):
        return self.get_field('reporter','displayName')

    def get_assignee_email_address(self):
        return self.get_field('assignee','emailAddress')

    def get_assignee_name(self):
        return self.get_field('assignee','displayName')

    def get_transition_id(self, status):
        jira_transitions_url = "https://jira-oss.seli.wh.rnd.internal.ericsson.com:443/rest/api/2/issue/{}/transitions".format(self.get_key())
        response = requests.get(jira_transitions_url, auth=('S4_Team', 'S4_Team'))
        jsonResponse = json.loads(response.content)
        possible_transitions = jsonResponse['transitions']
        for transition in possible_transitions:
            if transition.get('name') == status:
                return transition.get('id')

    def set_status(self, to_value):
        transition_id = self.get_transition_id(to_value)
        jira_url = "https://jira-oss.seli.wh.rnd.internal.ericsson.com:443/rest/api/2/issue/{}/transitions".format(self.get_key())
        headers = {'Content-type': 'application/json'}
        json_data = {"transition":{"id":transition_id}}
        response = requests.post(jira_url, headers=headers, json=json_data, auth=('S4_Team', 'S4_Team'))

    def add_comment(self, comment, user):
        jira_url = "https://jira-oss.seli.wh.rnd.internal.ericsson.com:443/rest/api/2/issue/{}/comment".format(self.get_key())
        headers = {'Content-type': 'application/json'}
        r = requests.post(jira_url, headers=headers, json={'body': comment}, auth=(user, user))
        print r.status_code
