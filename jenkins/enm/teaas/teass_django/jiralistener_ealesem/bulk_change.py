
import deployments
import jira


def status(cluster_id, from_value, to_value):
    if cluster_id in deployments.credentials.keys():
        issues = jira.get_issues_in_status(cluster_id, from_value)
        for issue in issues:
            print "setting status on {}".format(issue.get_key())
            issue.set_status(to_value)