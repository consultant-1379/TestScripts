#!/usr/bin/python

import commands
import sys

pib_path = '/ericsson/pib-scripts/etc/config.py'

'''
Function to find out what svc's pmserv is on and returns one of them
'''


def get_svc(service_group):
    print '\nFinding', service_group
    print
    (ret, out) = commands.getstatusoutput("litp show -p /deployments/enm/clusters/svc_cluster/services/"+service_group +
                                          "| grep node")
    if ret != 0:
        print'Could not find ' + service_group + "'s location"
        sys.exit(1)
    out = out.replace("node_list: ", "")
    out = out.replace("\t", "")
    word_list = out.split(",")
    return word_list[1]

'''
Function to read pib values
for stats retention
and number of dirs created for symlinks and symlinks retention time.
'''
def read_pib():
    stats_retention = 'pmicStatisticalFileRetentionPeriodInMinutes'
    events_retention = 'pmicCelltraceFileRetentionPeriodInMinutes'
    stats_subdir = 'maxSymbolicLinkSubdirs'
    events_subdir = 'pmicEventsMaxSymbolicLinkSubdirs'
    pmic_events_symbolic_link_retention_period_in_minutes = 'pmicEventsSymbolicLinkRetentionPeriodInMinutes'
    pmic_symbolic_link_retention_period_in_minutes = 'pmicSymbolicLinkRetentionPeriodInMinutes'

    (ret, out) = commands.getstatusoutput(pib_path + ' read --name=' + stats_retention +
                                          ' --service_identifier=pm-service ' + pib_pmic_path)
    print 'Stats retention period is', out

    (ret, out) = commands.getstatusoutput(pib_path + ' read --name=' + events_retention +
                                          ' --service_identifier=pm-service ' + pib_pmic_path)
    print 'Events retention period is', out

    (ret, out) = commands.getstatusoutput(pib_path + ' read --name=' + stats_subdir +
                                          ' --service_identifier=pm-service ' + pib_pmic_path)
    print 'Number of stats sym directories is', out

    (ret, out) = commands.getstatusoutput(pib_path + ' read --name=' + events_subdir +
                                          ' --service_identifier=pm-service ' + pib_pmic_path)
    print 'Number of events sym directories is', out

    (ret, out) = commands.getstatusoutput(pib_path + ' read --name=' +
                                          pmic_events_symbolic_link_retention_period_in_minutes +
                                          ' --service_identifier=pm-service ' + pib_pmic_path)
    print 'Events sym link retention time is', out

    (ret, out) = commands.getstatusoutput(pib_path + ' read --name=' + pmic_symbolic_link_retention_period_in_minutes +
                                          ' --service_identifier=pm-service ' + pib_pmic_path)
    print 'Stats sym link retention time is', out


'''
Main calls read_pib function
'''


def main():
    read_pib()
    sys.exit(0)


'''
Function to Set values
'''


def definition():
    global pib_pmic_path
    pmsvc = get_svc("pmserv")
    pib_pmic_path = '--app_server_address=' + pmsvc + '-pmserv:8080'


if __name__ == '__main__':
    definition()
    main()

