from django.http import HttpResponse

import issue_update
import sync
import bulk_change


def receive_jira_event(request):
    issue_update.incoming_event(request)
    return HttpResponse(status=200)


def sync_jira_to_deployment(request, cluster_id):
    sync.sync_users_on_deployment_to_jira(cluster_id)
    return HttpResponse(status=200)


def bulk_field_change(request, cluster_id, field, from_value, to_value):
    print "cluster_id = {}, field = {}, from_value= {}, to_value = {}".format(cluster_id, field, from_value, to_value)
    bulk_change.status(cluster_id, from_value, to_value)
    return HttpResponse(status=200)
