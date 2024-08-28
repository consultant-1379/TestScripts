#!/bin/bash
BASENAME=`dirname $0`

TEST_CLIENT_PATH="/opt/ericsson/com.ericsson.oss.nbi.fm/test_client/"

EVENT="1z1"
ALARM="1f1"
FILTER="\"'TEST_ALARM' \~ \$i\""
#TIME client remains subscribed for (minutes) - 23 hours
TIME=1380

NBI_HOSTS=`grep nbalarmirp /etc/hosts | cut -f2 -d$'\t'`

CMD="cd ${TEST_CLIENT_PATH}; ./testclient.sh subscribe category ${ALARM} filter ${FILTER} subscriptionTime ${TIME} >/tmp/test_client.out 2>&1 & "

for NBISVC in ${NBI_HOSTS};
do
    ${BASENAME}/../bin/ssh_to_vm_and_su_root.exp ${NBISVC} "${CMD}"
done
