#!/usr/bin/env python
#
# Deactivates and delete's all pm subscriptions based on given range and name
# Example clearing all PM_08 subscriptions ranging between 0 and 200
# Usage example: ./clearSubscriptions 0 200 08
#
import time, sys
from enmutils.lib import shell, init, config
from enmutils.bin import cli_app
init.global_init("int", "int", "")

start = int(sys.argv[1])
end = int(sys.argv[2])
name = sys.argv[3]

print "deactivating all PM_%s subscriptions" % name
cli_app._execute_cli_command("cmedit set * StatisticalSubscription administrationState=INACTIVE", None, False)

for i in range(start, end):
	# cli_app._execute_cli_command("cmedit set * statisticalSubscription.(name=='%s-PM_%s')" % (i,  sys.argv[1] ) administrationState=INACTIVE" % i, None, False)
	time.sleep(0.5)
	print "Deleting %s-PM_%s" % (i, name)
	cli_app._execute_cli_command("cmedit delete * StatisticalSubscription.(name=='%s-PM_%s'*)" % (i, name), None, False)

time.sleep(1)
print "Done"
