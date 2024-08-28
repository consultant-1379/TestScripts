#!/bin/bash

source /root/djangoenv/bin/activate
python /root/TestScripts/jenkins/enm/teaas/teass_django/manage.py jira_expired
