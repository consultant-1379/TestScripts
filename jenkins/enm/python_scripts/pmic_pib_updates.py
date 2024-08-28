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
Function to update pib values
for stats retention
and number of dirs created for symlinks
'''


def update_pib(minutes, dirs):
    stats_retention = 'pmicStatisticalFileRetentionPeriodInMinutes'
    stats_subdir = 'maxSymbolicLinkSubdirs'
    events_subdir = 'pmicEventsMaxSymbolicLinkSubdirs'
    (ret, out) = commands.getstatusoutput(pib_path + ' read --name=' + stats_retention +
                                          ' --service_identifier=pm-service ' + pib_pmic_path)
    print 'Retention period was', out
    print 'Updating the file retention of PMIC'
    (ret, out) = commands.getstatusoutput(pib_path + ' update --name=' + stats_retention +
                                          ' --value=' + minutes + ' --service_identifier=pm-service ' + pib_pmic_path)
    print 'Retention period is', out
    print
    (ret, out) = commands.getstatusoutput(pib_path + ' read --name=' + stats_subdir +
                                          ' --service_identifier=pm-service ' + pib_pmic_path)
    print 'Number of stats sym directories was', out
    print 'Updating the number of sym link directories for eniq stats'
    (ret, out) = commands.getstatusoutput(pib_path + ' update --name=' + stats_subdir +
                                          ' --value=' + dirs +
                                          ' --service_identifier=pm-service ' + pib_pmic_path)
    print 'Number of stats sym directories is', out
    print
    print 'Number of events sym directories was', out
    (ret, out) = commands.getstatusoutput(pib_path + ' update --name=' + events_subdir +
                                          ' --service_identifier=pm-service ' + pib_pmic_path)
    print 'Updating the number of sym link directories for eniq events'
    (ret, out) = commands.getstatusoutput(pib_path + ' update --name=' + events_subdir +
                                          ' --value=' + dirs +
                                          ' --service_identifier=pm-service ' + pib_pmic_path)
    print 'Number of sym directories is', out
    print

'''
Function to update the retention for
both stats and events sym links.
'''


def update_sym_retention(minutes):
    pmic_events_symbolic_link_retention_period_in_minutes = 'pmicEventsSymbolicLinkRetentionPeriodInMinutes'
    pmic_symbolic_link_retention_period_in_minutes = 'pmicSymbolicLinkRetentionPeriodInMinutes'
    (ret, out) = commands.getstatusoutput(pib_path + ' read --name='
                                          + pmic_events_symbolic_link_retention_period_in_minutes +
                                          ' --service_identifier=pm-service ' + pib_pmic_path)
    print 'Events sym link retention time was', out
    (ret, out) = commands.getstatusoutput(pib_path + ' read --name='
                                          + pmic_symbolic_link_retention_period_in_minutes +
                                          ' --service_identifier=pm-service ' + pib_pmic_path)
    print 'Stats sym link retention time was', out
    print 'Updating sym link retention to', minutes, 'mins.'
    (ret, out) = commands.getstatusoutput(pib_path + ' update --name='
                                          + pmic_events_symbolic_link_retention_period_in_minutes +
                                          ' --value=' + minutes +' --service_identifier=pm-service ' + pib_pmic_path)
    print 'Events sym link retention time is', out
    (ret, out) = commands.getstatusoutput(pib_path + ' update --name='
                                          + pmic_symbolic_link_retention_period_in_minutes +
                                          ' --value=' + minutes +' --service_identifier=pm-service ' + pib_pmic_path)
    print 'Stats sym link retention time is', out
    print


'''
Main takes input from user
first input is used for stats retention
second input is used for number of sym directories
if a 3rd input is entered then retention of sys links is changed
'''


def main():
    update_pib(sys.argv[1], sys.argv[2])
    if len(sys.argv) == 4:
        update_sym_retention(sys.argv[3])
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

