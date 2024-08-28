from django.core.management.base import BaseCommand 
from ... import jira_ticket_expired

class Command(BaseCommand):
    help = 'Comments on tickets expiring today'

    def handle(self, *args, **kwargs):
        jira_ticket_expired.startCheck(self)
