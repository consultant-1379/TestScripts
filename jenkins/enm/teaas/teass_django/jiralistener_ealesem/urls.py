from django.conf.urls import url

from . import views

urlpatterns = [
    url(r'^$', views.receive_jira_event, name='receive_jira_event'),
    url(r'^/sync/(?P<cluster_id>[0-9]+)/$', views.sync_jira_to_deployment, name='sync_jira_to_deployment'),
    url(r'^/bulkfieldchange/(?P<cluster_id>[0-9]+)/(?P<field>.+)/(?P<from_value>.+)/(?P<to_value>.+)/$', views.bulk_field_change, name='bulk_field_change')
]
