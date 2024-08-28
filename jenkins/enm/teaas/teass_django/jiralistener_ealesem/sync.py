
import deployments
import jira
import user


def sync_users_on_deployment_to_jira(cluster_id):
    if cluster_id in deployments.credentials.keys():
        print "User sync has been requested for deployment {}".format(cluster_id)
        deployment = deployments.Deployment(cluster_id)
        issues_in_testing_in_jira = jira.get_issues_in_status(deployment, 'Testing')
        users_in_testing_in_jira = [jira_issue.get_key() for jira_issue in issues_in_testing_in_jira]
        users_on_lms = deployment.list_users_on_lms_of_deployment()
        print "User list in Jira: {}".format(users_in_testing_in_jira)
        print "User list on LMS: {}".format(users_on_lms)
        for username in users_on_lms:
            if username not in users_in_testing_in_jira:
                user.remove_without_issue(username, deployment)
        for issue in issues_in_testing_in_jira:
            if issue.get_key() not in users_on_lms:
                user.create(issue, deployment)

