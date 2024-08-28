
import deployments
import jira_event
import mail
import user


def incoming_event(request):
    event = jira_event.JiraEvent(request)
    issue = event.get_issue()
    issue_key = issue.get_key()
    if issue_key == 'CIP-17288' or issue_key == 'CIP-17598' or issue_key == 'PNTC-2136':
        print event
    if event.get_event_type() == 'updated':
        project = issue.get_project()
        if project == 'CIP':
            s4_issue_updated(event)
        elif project == 'PNTC':
            s3_issue_updated(event)


def s4_issue_updated(event):
    if event.has_changelog:
        if event.field_has_changed('status'):
            state_change(event)
        elif event.get_issue().get_status() == 'Testing' and event.field_has_changed('environment'):
            deployment_change(event)
        elif event.get_issue().get_status() == 'Testing' and event.field_has_changed('Type of Server Access'):
            type_of_access_change(event)


def s3_issue_updated(event):
    if event.has_changelog:
        if event.field_has_changed('status'):
            if event.status_has_changed_to('Closed'):
                issue = event.get_issue()
                s3_request_feedback(issue)


def state_change(event):
    issue = event.get_issue()
    issue_key = issue.get_key()
    if issue.get_deployment_id() in deployments.credentials.keys():
        deployment = deployments.Deployment(issue.get_deployment_id())
        if event.status_has_changed_from('Testing'):
            print "{} has transitioned from testing state on deployment {}".format(issue_key, deployment)
            user.remove(issue, deployment)
        elif event.status_has_changed_to('Testing'):
            print "{} has transitioned to testing state on deployment {}".format(issue_key, deployment)
            user.create(issue, deployment)
    if event.status_has_changed_to('Resolved'):
        s4_request_feedback(issue)
    elif event.status_has_changed_from('Resolved') and event.status_has_changed_to('Closed'):
        thank_for_feedback(issue, 'S4_Team')
    if event.status_has_changed_to('Approved'):
        email = mail.Mail(issue, None)
        email.send_issue_approved_mail()


def s3_request_feedback(issue):
    request_feedback(issue, 'S3_Team')


def s4_request_feedback(issue):
    request_feedback(issue, 'S4_Team')


def request_feedback(issue, user):
    feedback_comment = """Were you satisfied with the service provided?
                               Please edit the Service Rating field in this Jira and leave feedback in the Feedback field.
                               Thanks."""
    issue.add_comment(feedback_comment, user)


def thank_for_feedback(issue, user):
    feedback_comment = """Thank you for your feedback. This ticket is now closed."""
    issue.add_comment(feedback_comment, user)


def deployment_change(event):
    issue = event.get_issue()
    issue_key = issue.get_key()
    from_deployment_id, to_deployment_id = event.get_from_and_to_deployment_id()
    print "{} already in testing state has had an environment update from {} to {}".format(issue_key,
                                                                                           from_deployment_id,
                                                                                           to_deployment_id)
    if from_deployment_id in deployments.credentials.keys():
        from_deployment = deployments.Deployment(from_deployment_id)
        user.remove(issue, from_deployment)
    if to_deployment_id in deployments.credentials.keys():
        to_deployment = deployments.Deployment(to_deployment_id)
        user.create(issue, to_deployment)


def type_of_access_change(event):
    issue = event.get_issue()
    issue_key = issue.get_key()
    if event.type_of_access_has_changed_from('Exclusive'):
        deployment = deployments.Deployment(issue.get_deployment_id())
        print "{} already in testing state on deployment {} has changed from Exclusive".format(issue_key, deployment)
        deployment.change_user_access(issue_key, 'Shared')
    elif event.type_of_access_has_changed_to('Exclusive'):
        deployment = deployments.Deployment(issue.get_deployment_id())
        print "{} already in testing state on deployment {} has change to Exclusive".format(issue_key, deployment)
        deployment.change_user_access(issue_key, 'Exclusive')
