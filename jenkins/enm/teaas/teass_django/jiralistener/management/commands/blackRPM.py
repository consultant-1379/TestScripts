
from django.core.management.base import BaseCommand
from ... import black_RPM_removal

class Command(BaseCommand):
    help = 'Comments on tickets expiring today'

    def handle(self, *args, **kwargs):
        black_RPM_removal.startCheck(self)

