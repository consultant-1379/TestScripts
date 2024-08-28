from enmutils_int.lib.profile import Profile
from requests.exceptions import HTTPError

from enmutils_int.lib.pm_subscriptions import StatisticalSubscription
from enmutils.lib.exceptions import TimeOutError, SubscriptionStatusError

from enmutils.lib.persistence import picklable_boundmethod


class PM_99(Profile):
    NAME = "PM_99"
    NUM_NODES = {}
    ROP_STR = 'FIFTEEN_MIN'
    ROLES = ["PM_Operator"]
    FILE_CONTAINING_LIST_OF_SUBSCRIPTIONS_TO_BE_DELETED = "/ericsson/enm/dumps/list_of_subscriptions_to_be_deleted"

    SCHEDULE_SLEEP = 60 * 60 * 6

    def run(self):
        user = self.create_users(1, self.ROLES)[0]

        self.state = "RUNNING"
        nodes = self.nodes["ERBS"]

        with open(PM_99.FILE_CONTAINING_LIST_OF_SUBSCRIPTIONS_TO_BE_DELETED) as infile:
            data = infile.read() 

        my_list = data.splitlines()

        for SUB_NAME in my_list:
            subscription = StatisticalSubscription(name=SUB_NAME, user=user)
            self.teardown_list.append(subscription)

            try:
                subscription.deactivate()
                subscription.delete()
            except (HTTPError, TimeOutError) as e:
                self.add_error_as_exception(e)

            if subscription in self.teardown_list:
                self.teardown_list.remove(subscription)

pm_99 = PM_99()


