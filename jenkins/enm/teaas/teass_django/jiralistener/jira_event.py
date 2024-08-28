import json
import re
import jira


class JiraEvent:
    def __init__(self, request):
        self.request = request
        self.parsed_request = json.loads(request.body)
        self.event_type = self.parse_event_type()
        self.user_data = self.parsed_request['user']
        self.issue = jira.jiraIssue(self.parsed_request['issue'])
        if 'changelog' in self.parsed_request:
            self.changelog_data = self.parsed_request['changelog']
        else:
            self.changelog_data = None
        if 'comment' in self.parsed_request:
            self.comment_data = self.parsed_request['comment']
        else:
            self.comment_data = None

    def __str__(self):
        return self.request.body

    def parse_event_type(self):
        if self.parsed_request['webhookEvent'] == 'jira:issue_updated':
            return 'updated'
        elif self.parsed_request['webhookEvent'] == 'jira:issue_created':
            return 'created'
        elif self.parsed_request['webhookEvent'] == 'jira:issue_deleted':
            return 'deleted'

    def get_event_type(self):
        return self.event_type

    def get_issue(self):
        return self.issue

    def get_from_and_to_deployment_id(self):
        from_environment, to_environment = self.get_changed_fields_from_and_to_strings('environment')
        from_deployment_id = self.find_deployment_id_string_in_environment_field(from_environment)
        to_deployment_id = self.find_deployment_id_string_in_environment_field(to_environment)
        return from_deployment_id, to_deployment_id

    def find_deployment_id_string_in_environment_field(self, environment):
        if environment is None:
            return None
        pattern = re.compile("\d{3}")
        match = re.search(pattern, environment)
        if match:
            return match.group(0)
        return None

    def type_of_access_has_changed_from(self, type_of_server_access):
        return self.field_has_changed_from('Type of Server Access', type_of_server_access)

    def type_of_access_has_changed_to(self, type_of_server_access):
        return self.field_has_changed_to('Type of Server Access', type_of_server_access)

    def has_changelog(self):
        if self.changelog_data is not None:
            return True
        return False

    def status_has_changed_from(self, status):
        return self.field_has_changed_from('status', status)

    def status_has_changed_to(self, status):
        return self.field_has_changed_to('status', status)

    def get_changed_fields_from_and_to_strings(self, field):
        for change in self.changelog_data['items']:
            if change.get('field') == field:
                fromstr = change.get('fromString')
                return change.get('fromString'), change.get('toString')

    def field_has_changed(self, field):
        if self.changelog_data is not None:
            for change in self.changelog_data['items']:
                if change.get('field') == field:
                    return True
        return False

    def field_has_changed_from(self, field, value):
        if self.field_has_changed(field):
            from_value, to_value = self.get_changed_fields_from_and_to_strings(field)
            if from_value == value:
                return True
        return False

    def field_has_changed_to(self, field, value):
        if self.field_has_changed(field):
            from_value, to_value = self.get_changed_fields_from_and_to_strings(field)
            if to_value == value:
                return True
        return False
