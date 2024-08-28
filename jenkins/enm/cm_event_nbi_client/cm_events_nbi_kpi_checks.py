#!/usr/bin/env python

# Event rate verification for the CM Events NBI interface
# With -b flag, runs "Read multiple events from CM Events NBI interface" test
# With -f flag, runs "Create and delete filters" test
# With -l flag, runs "Check SOLR latency" test
# Reports on any KPIs exceeded.
# If Ctrl-C pressed, waits to end of loop to stop. If second Ctrl-C pressed, stops immediately.
# If repeated runs are requested, the code sleeps between runs so that the next run starts
# "period" seconds after the previous one started.  If the run takes longer than "period"
# seconds, the next run will start immediately.

import sys
import signal
import argparse
import cookielib
import urllib
import urllib2
import httplib
import json
import time
from dateutil import parser
import subprocess
import os
import re
import syslog
import logging
import random
import socket
from StringIO import StringIO
from contextlib import closing
from datetime import datetime, timedelta

# Globals
ha_proxy_https_port = 443
force_loop_exit = False
current_enm_ip = None
ip_type = socket.AF_INET
ha_proxy_verified_ips = []

# Map verbosity count to a syslog log level
lmap = {0:syslog.LOG_INFO, 1:syslog.LOG_DEBUG}
# Map sylog log levels to text descriptions of them for stdout logging
llmap = {syslog.LOG_EMERG:"EMERGENCY",
         syslog.LOG_ALERT:"ALERT",
         syslog.LOG_CRIT:"CRITICAL",
         syslog.LOG_ERR:"ERROR",
         syslog.LOG_WARNING:"WARNING",
         syslog.LOG_NOTICE:"NOTICE",
         syslog.LOG_INFO:"INFO",
         syslog.LOG_DEBUG:"DEBUG"}

def check_ha_proxy(ha_ip, ip_ver):
    '''
    Description:
        Check availability of HA_Proxy server and stop the execution if
        is not present.
    Args:
        ha_ip (list): IP addresses of HA_Proxy server.
        ip_ver (object): IP version (IPv4 or IPv6)
    '''

    global ha_proxy_verified_ips

    if ha_ip not in ha_proxy_verified_ips:

        ha_proxy_verified_ips.append(ha_ip)

        with closing(socket.socket(ip_ver, socket.SOCK_STREAM)) as sock:
            sock.settimeout(5)
            if sock.connect_ex((ha_ip, ha_proxy_https_port)) == 0:
                pass
            else:
                logmsg(syslog.LOG_ERR, 'Error reaching HA-Proxy server with '
                                       'IP ' + ha_ip, tag='Filter')
                sys.exit(1)

############################################################
# Get a list of addresses for a family/stack type
############################################################
def get_all_addresses_info(family):
    return socket.getaddrinfo(args.evserver, args.port, family, 0,
                              socket.IPPROTO_TCP)

############################################################
# Iterate and tokenize the many IP address info. lines to
# extract just the actual address values.
############################################################
def get_ipvX_addresses(family):
    return [line[4][0] for line in get_all_addresses_info(family)]

############################################################
# Select an Event NBI Server
############################################################
def select_evserver():
    global current_enm_ip
    global ip_type
    prefix = ''
    suffix = ''

    if args.stack_type == 1:
        stack = socket.AF_INET
    elif args.stack_type == 2:
        stack = socket.AF_INET6
    elif args.stack_type == 3:
        stack = random.choice([socket.AF_INET, socket.AF_INET6])
    elif args.stack_type == 4:
        stack = ip_type
    else:
        logmsg(syslog.LOG_INFO,
               'Invalid stack type - will use IPv4 addresses')

    if stack == socket.AF_INET6:
        prefix = '['
        suffix = ']'

    ip = random.choice(get_ipvX_addresses(stack))

    check_ha_proxy(ip, stack)
    current_enm_ip = ip

    return prefix + ip + suffix

############################################################
# Get Config mgmt event URL
############################################################
def get_cfg_mgmt_event_url():
    return 'https://%s/config-mgmt/event' % select_evserver()

############################################################
# Log message
############################################################
def logmsg(level, msg, tag='Events'):
    global current_enm_ip
    # Send a log message to syslog, and optionally standard out
    # By default here, logging is LOG_INFO level or above.
    # if one "-v", send LOG_DEBUG or above.
    # if two or more "-v"s, assume only 1
    if level <= lmap[min(len(lmap)-1, args.verbosity)]:
        if current_enm_ip:
            preamble = "%s NBI_CM_%s:" % (current_enm_ip, tag)
        else:
            preamble = "NBI_CM_%s:" % tag

        syslog.syslog(level, "%s %s" % (preamble, msg))

        if not args.quiet:
            # Show the tag in the screen output
            if current_enm_ip:
                print("%s %s-%s: %s %s" % (get_iso_time(), llmap[level],
                                           tag, current_enm_ip, msg))
            else:
                print("%s %s-%s: %s" % (get_iso_time(), llmap[level], tag,
                                        msg))

############################################################
# Get the current time as an ISO 8601 string with millisecond accuracy
############################################################
def get_iso_time():
    # Get the desired time (as a float). strftime doesn't support fractional seconds,
    # so format the integral part to ISO 8601 with strftime, with a %03d formatting
    # string in the output. Put 1000 times the fractional part of the time into that format.
    a0 = time.time()
    # Get whole seconds
    a1 = int(a0)
    # Get fractional second part
    a2 = a0 - a1
    # Convert seconds-since-epoch to date structure
    a3 = time.strftime("%Y-%m-%dT%H:%M:%S.%%03dZ",time.gmtime(a1))
    return a3 % int(1000*a2)

############################################################
# Control-C handler - sets flag on first press, exits on second
############################################################
def catchCtrlC(signal, frame):
    # Handle Ctrl-C being pressed.
    # If first time, set the force_loop_exit flag to True, so that when all of the tests on
    # this loop have been run, the script will simply fall out.
    # If Ctrl-C pressed and the flag has already been set, exit immediately.
    global force_loop_exit
    if force_loop_exit:
        logmsg(syslog.LOG_INFO, "Script immediate exit on double Ctrl-C")
        sys.exit(0)
    else:
        print("Ctrl-C pressed")
        force_loop_exit = True

############################################################
# Code to enhance argument parsing (allows pre-formatted option help)
############################################################
class RawDescriptionSmartFormatter(argparse.RawDescriptionHelpFormatter):

    # Description will be printed out as is (no formatting)
    # Normal option help will be as usual (newlines and extra whiteapce stripped)
    # Options with help starting "R|" will have, for example, "\n" respected
    # and the "R|" stripped.
    def _split_lines(self, text, width):
        if text.startswith('R|'):
            return text[2:].splitlines()
        # this is the RawTextHelpFormatter._split_lines
        return argparse.HelpFormatter._split_lines(self, text, width)

############################################################
# Parse the command-line arguments
############################################################
def parse_cmd_line():
    parser = argparse.ArgumentParser(description='CM Events NBI Rate Verifier',
                    formatter_class=RawDescriptionSmartFormatter,
                    epilog='''Examples:
Arguments: -s localhost -p 1234
   connect to enmapache.athtem.eei.ericsson.se for CM Events NBI, localhost:1234
   for the solr database, and run all checks with 10 CM Events NBI clients and
   the default password, logging at INFO level
Arguments: -e cmeventserver.com -c 5 -n "secret" -v -t 10
   connect to cmeventserver.com for CM Events, to solr:8983 for database, and
   run event read checks with 5 CM Events NBI clients and the supplied password,
   log at DEBUG level, with 60 seconds between runs
Arguments: -e cmeventserver.com -l -q
   connect with default servers, and run message latency check once, suppressing
   screen output (but keeping syslog output)
Arguments: -e cmeventserver.com -f -c 500 -t 3600 -k
   connect with default servers, and run filter creation/deletion timing checks
   with 500 filters, every hour, and continuing even after errors''')
# Argparse automatically adds: ('-h', '--help', action='store_true', help='show usage')
    parser.add_argument('-e', '--evserver', default='enmapache.athtem.eei.ericsson.se', metavar="host", help='Event NBI Server (default: %(default)s)')
    parser.add_argument('-s', '--server', default='solr', metavar="solrhost", help='solr database server (default: %(default)s)')
    parser.add_argument('-p', '--port', type=int, default=8983, metavar="n", help='solr database listen port (default: %(default)d)')
    parser.add_argument('-b', '--evtest', action="store_true", help="Test for CM Events NBI read time")
    parser.add_argument('-l', '--latency', action="store_true", help="WARNING: This parameter queries Solr, resulting in performance downgrade. Test for detection-to-storage latency")
    parser.add_argument('-f', '--filterkpi', action="store_true", help="R|Test for filter creation and deletion times.\n*** If no specific test selected, all tests will be run")

    parser.add_argument('-BS', '--EVENTSKPI', type=float, default=40, metavar="secs", help="KPI in seconds for Single Event Read Client (default: %(default)d)")
    parser.add_argument('-BP', '--EVENTPKPI', type=float, default=40, metavar="secs", help="KPI in seconds for Parallel Event Read Clients (default: %(default)d)")
    parser.add_argument('-L', '--LATENCYKPI', type=float, default=30, metavar="secs", help="KPI in seconds for SOLR Latency (default: %(default)d)")
    parser.add_argument('-F', '--FILTERKPI', type=float, default=30, metavar="secs", help="KPI in seconds for Filter creation/deletion (default: %(default)d)")

    parser.add_argument('-n', '--nbi_password', default="TestPassw0rd", metavar="pass", help='password for CM Events NBI access (default: %(default)s)')
    parser.add_argument('-t', '--period', type=float, default=None, metavar="n", help='time in seconds (optionally with fractional seconds) between test run loops. If omitted, only run once')
    parser.add_argument('-c', '--clientcount', type=int, default=10, metavar="n", help='number of parallel NBI clients to be run (default: %(default)d)')
    parser.add_argument('-u', '--filtercount', type=int, default=100, metavar="n", help='number of filters to create and delete (default: %(default)d)')
    parser.add_argument('-i', '--clientdelay', type=float, default=0.5, metavar="n", help='time in seconds (optionally with fractional seconds) between starting each parallel client, to allow time for the cookie generation to take place reliably. Set to 0 for all to start simultaneously.  If value too large, the first clients will have finished before the later ones start.')
    parser.add_argument('-r', '--evread', type=int, default=50000, metavar="n", help='maximum number of events to retrieve (default: %(default)d)')
    parser.add_argument('-m', '--evtimeout', type=int, default=180, metavar="t", help='timeout for NBI CM Events interface requests (default: %(default)d)')
    parser.add_argument('-a', '--stattimeout', type=int, default=20, metavar="t", help='WARNING: This parameter queries Solr, resulting in performance downgrade. timeout for SOLR STATUS request (default: %(default)d)')
    parser.add_argument('-z', '--minimizecookies', action="store_true", help="minimize the number of cookies requested (default is to request one for each NBI Interface call, this flag limits it to once per loop)")
    parser.add_argument('-k', '--keeprunning', action="store_true", help="keep running after errors (default is to terminate the script)")
    parser.add_argument('-v', '--verbosity', action="count", default=0, help="increase output verbosity (repeat for Debug)")
    parser.add_argument('-q', '--quiet', action="store_true", help="suppress screen output (logging still goes to syslog)")
    parser.add_argument('-st', '--stack_type', type=int, default=3, help='the type of IP address(es) to be used. 1 for single stack IPv4, 2 for single stack IPv6, 3 for Dual Stack, 4 for parallel IPv4 and IPv6, (default: %(default)d)')
    parser.add_argument('-ss', '--skip_solr', action="store_true", help="Skip solr database connections")
    parser.add_argument('-sq', '--solrquery', action="store_true", help=("WARNING: Enabling this parameter performs queries against Solr which result in performance downgrade"))

    # Parse the arguments.  Exits if help is called, or there is a problem
    args = parser.parse_args()

    # If no test type flags given, set all to True
    if not args.evtest and not args.latency and not args.filterkpi:
        args.evtest = True
        args.latency = True
        args.filterkpi = True

    return args

############################################################
# Format Solr base URL
############################################################
def get_solr_base_url():
    return 'http://%s:%d/solr' % (args.server, args.port)

############################################################
# Send a status request to the database
############################################################
def curl_get_status():
    # Retrieves the status of the database, and returns the numeric status ID
    # If the request throws an exception, return -6
    # If the body is not JSON, return -1
    # If the status cannot be found, return -2
    # If the status is non-zero, return -3
    # If the status is 0, get the number of items:
    #   If the number of items is not found, return -4
    #   Else return the number
    url = get_solr_base_url() + '/admin/cores?action=STATUS&core=cm_events_nbi&wt=json&indent=true&memory=true'
    try:
        c = urllib2.urlopen(url, timeout=args.stattimeout)
    except httplib.HTTPException, e:
        logmsg(syslog.LOG_ERR, 'HTTPException = ' + str(e.code))
        return -6
    except urllib2.HTTPError, e:
        logmsg(syslog.LOG_ERR, 'HTTPError = %d - %s for URL %s' % (e.code, e.read(), url))
        return -6
    except urllib2.URLError, e:
        if hasattr(e, 'code') and hasattr(e, 'reason'):
            logmsg(syslog.LOG_ERR, 'URLError = ' + str(e.code) + ':' + str(e.reason) + ' for URL ' + url)
        else:
            logmsg(syslog.LOG_ERR, '%s for URL %s' % (str(e), url))
        return -6
    except Exception:
        import traceback
        logmsg(syslog.LOG_ERR, 'generic exception: ' + traceback.format_exc())
        return -6

    body = c.read()

    c.close()
    c = None

    # Look for the numeric status code
    try:
        # Convert received string to a JSON object
        bj = json.loads(body)
        # Read the status = 0 for OK
        try:
            rc = bj['responseHeader']['status']
            if rc == 0:
                try:
                    # Status OK, so read the number of events in the database
                    rc = bj['status']['cm_events_nbi']['index']['numDocs']
                except:
                    return -4
            else:
                rc = -3
        except:
            rc = -2
    except:
        rc = -1

    logmsg(syslog.LOG_DEBUG, 'Return code from status call %d' % rc)
    logmsg(syslog.LOG_DEBUG, 'Return data from status call: %s' % body)
    return rc

############################################################
# Send a request to the database to list items
############################################################
def curl_run_reader():
    # Retrieves the number of items returned in the message, if OK status in response
    # If the request throws an exception, return -6
    # If status code is retrieved but is not an integer, return -2
    # If the status code part cannot be found, return -1
    # If the status is non-zero, return -3
    # If the status is 0, get the number of items:
    #   If the number of items is not found, return -4
    #   If the number is not integral, return -5
    #   Else return the number
    buffer = StringIO()
    url = get_solr_base_url() + '/cm_events_nbi/select?q=*'
    try:
        c = urllib2.urlopen(url, timeout=args.evtimeout)
    except httplib.HTTPException, e:
        logmsg(syslog.LOG_ERR, 'HTTPException = ' + str(e.code))
        return -6
    except urllib2.HTTPError, e:
        logmsg(syslog.LOG_ERR, 'HTTPError = %d - %s for URL %s' % (e.code, e.read(), url))
        return -6
    except urllib2.URLError, e:
        if hasattr(e, 'code') and hasattr(e, 'reason'):
            logmsg(syslog.LOG_ERR, 'URLError = ' + str(e.code) + ':' + str(e.reason) + ' for URL ' + url)
        else:
            logmsg(syslog.LOG_ERR, '%s for URL %s' % (str(e), url))
        return -6
    except Exception:
        import traceback
        logmsg(syslog.LOG_ERR, 'generic exception: ' + traceback.format_exc())
        return -6

    body = c.read()

    c.close()
    c = None

    # If OK return, look for the count of messages read
    m = re.search('<int name="status">(\d+)</int>', body)
    if m:
        # Found a status pattern - if a zero int, get number of items
        try:
            rc = int(m.group(1))
            if rc == 0:
                n = re.search('<result[^>]* numFound="(\d+)"', body)
                if n:
                    # Found a pattern - if an int, get number of items
                    try:
                        rc = int(n.group(1))
                    except:
                        rc = -5
                else:
                    rc = -4
            else:
                rc = -3
        except:
            rc = -2
    else:
        rc = -1

    logmsg(syslog.LOG_DEBUG, 'Number of items in database: %d' % rc)
    logmsg(syslog.LOG_DEBUG, 'Return data from list all items call begins: %s' % body[:200])
    return rc

############################################################
# Send a request to get the number of items in the last minute
############################################################
def curl_run_get_rate():
    # Retrieves the number of items in the last minute, if OK status in response
    # If the request throws an exception, return -6
    # If status code is retrieved but is not an integer, return -2
    # If the status code part cannot be found, return -1
    # If the status is non-zero, return -3
    # If the status is 0, get the number of items:
    #   If the number of items is not found, return -4
    #   If the number is not integral, return -5
    #   Else return the number
    buffer = StringIO()
    url = get_solr_base_url() + '/cm_events_nbi/select?q=eventRecordTimestamp%3A%5BNOW-60000MILLISECONDS+TO+NOW%5D?wt=json?rows=1000000'
    try:
        c = urllib2.urlopen(url, timeout=args.evtimeout)
    except httplib.HTTPException, e:
        logmsg(syslog.LOG_ERR, 'HTTPException = ' + str(e.code))
        return -6
    except urllib2.HTTPError, e:
        logmsg(syslog.LOG_ERR, 'HTTPError = %d - %s for URL %s' % (e.code, e.read(), url))
        return -6
    except urllib2.URLError, e:
        if hasattr(e, 'code') and hasattr(e, 'reason'):
            logmsg(syslog.LOG_ERR, 'URLError = ' + str(e.code) + ':' + str(e.reason) + ' for URL ' + url)
        else:
            logmsg(syslog.LOG_ERR, '%s for URL %s' % (str(e), url))
        return -6
    except Exception:
        import traceback
        logmsg(syslog.LOG_ERR, 'generic exception: ' + traceback.format_exc())
        return -6

    body = c.read()

    c.close()
    c = None

    # If OK return, look for the count of messages read
    m = re.search('<int name="status">(\d+)</int>', body)
    if m:
        # Found a status pattern - if a zero int, get number of items
        try:
            rc = int(m.group(1))
            if rc == 0:
                n = re.search('<result[^>]* numFound="(\d+)"', body)
                if n:
                    # Found a pattern - if an int, get number of items
                    try:
                        rc = int(n.group(1))
                    except:
                        rc = -5
                else:
                    rc = -4
            else:
                rc = -3
        except:
            rc = -2
    else:
        rc = -1

    logmsg(syslog.LOG_DEBUG, 'Number of items in last 60 seconds: %d' % rc)
    logmsg(syslog.LOG_DEBUG, 'Return data from list recent items call begins: %s' % body[:200])
    return rc

############################################################
# Count the current number of filters
############################################################
def curl_get_filter_count(cookie_header):
    # Get the current number of filters
    # If the request throws an exception, return -6

    # Get a list of filters
    # [root@cloud-ms-1 ~]# curl -k -H "Content-Type: application/json" -X GET --cookie cookie.txt "https://enmapache.athtem.eei.ericsson.se:443/config-mgmt/event/filters"
    # {"_links":{"self":{"href":"/event/filters/"}},"filters":[{"filterId":"XOAP543CRK4JK","filterDescription":"Filters all the events with operationType:UPDATE and moClass:CmNodeHeartbeatSupervision.","filterName":"UPDATE_CheckKpiCreateTimeTaken","_links":{"_self":{"_href":"/event/filters/XOAP543CRK4JK"}}},{"filterId":"ROK3F7MD77ILG","filterDescription":"Filters all the events with operationType:UPDATE and moClass:CmNodeHeartbeatSupervision.","filterName":"UPDATE_CheckKpiCreateTimeTaken","_links":{"_self":{"_href":"/event/filters/ROK3F7MD77ILG"}}}]}[root@cloud-ms-1 ~]#
    rc = 0
    url = get_cfg_mgmt_event_url() + '/filters'

    try:
        opener = urllib2.build_opener(urllib2.HTTPHandler(debuglevel=0), urllib2.HTTPSHandler(debuglevel=0))
        uc = get_url_request(url, cookie_header)
        c = opener.open(uc, timeout=args.evtimeout)
    except httplib.HTTPException, e:
        logmsg(syslog.LOG_ERR, 'HTTPException = ' + str(e.code))
        rc = -6
    except urllib2.HTTPError, e:
        logmsg(syslog.LOG_ERR, 'HTTPError = %d - %s for URL %s' % (e.code, e.read(), url))
        rc = -6
    except urllib2.URLError, e:
        if hasattr(e, 'code') and hasattr(e, 'reason'):
            logmsg(syslog.LOG_ERR, 'URLError = ' + str(e.code) + ':' + str(e.reason) + ' for URL ' + url)
        else:
            logmsg(syslog.LOG_ERR, '%s for URL %s' % (str(e), url))
        rc = -6
    except Exception:
        import traceback
        logmsg(syslog.LOG_ERR, 'generic exception: ' + traceback.format_exc())
        rc = -6

    if rc == 0:
        body = c.read()

        c.close()
        c = None

        rc = -1

        try:
            # Get the filter count
            bj = json.loads(body)
            rc = len(bj['filters'])
        except:
            pass

    if rc >= 0:
        logmsg(syslog.LOG_DEBUG, 'Count of persistent filters: %d' % (rc))
        logmsg(syslog.LOG_DEBUG, 'Return data from count filters (%d bytes) begins: %s' % (len(body), body[:1000]))
    else:
        logmsg(syslog.LOG_DEBUG, 'Return code from creating filters: %d' % (rc))

    return rc

############################################################
# Get the time taken to create and delete up to 1000 filters
############################################################
def curl_get_filter_timing(cookie_header):
    # Time how long it takes to create and delete 1000 filters
    # If the request throws an exception, return -6

    # Create a filter
    # [root@cloud-ms-1 ~]# curl -k -H "Content-Type: application/json" -X POST --data-binary "@filter.json" --cookie cookie.txt "https://enmapache.athtem.eei.ericsson.se/config-mgmt/event/filters"
    # {"_links":{"self":{"href":"/event/filters/ROK3F7MD77ILG"}},"filterClauses":[{"attrName":"operationType","operator":"eq","attrValue":"UPDATE"},{"attrName":"moClass","operator":"eq","attrValue":"CmNodeHeartbeatSupervision"}],"filterDescription":"Filters all the events with operationType:UPDATE and moClass:CmNodeHeartbeatSupervision.","filterId":"ROK3F7MD77ILG","filterName":"UPDATE_CheckKpiCreateTimeTaken"}[root@cloud-ms-1 ~]#

    # Get a list of filters
    # [root@cloud-ms-1 ~]# curl -k -H "Content-Type: application/json" -X GET --cookie cookie.txt "https://enmapache.athtem.eei.ericsson.se:443/config-mgmt/event/filters"
    # {"_links":{"self":{"href":"/event/filters/"}},"filters":[{"filterId":"XOAP543CRK4JK","filterDescription":"Filters all the events with operationType:UPDATE and moClass:CmNodeHeartbeatSupervision.","filterName":"UPDATE_CheckKpiCreateTimeTaken","_links":{"_self":{"_href":"/event/filters/XOAP543CRK4JK"}}},{"filterId":"ROK3F7MD77ILG","filterDescription":"Filters all the events with operationType:UPDATE and moClass:CmNodeHeartbeatSupervision.","filterName":"UPDATE_CheckKpiCreateTimeTaken","_links":{"_self":{"_href":"/event/filters/ROK3F7MD77ILG"}}}]}[root@cloud-ms-1 ~]#
    # Delete a filter
    # [root@cloud-ms-1 ~]# curl -k -H "Content-Type: application/json" -X DELETE --cookie cookie.txt "https://enmapache.athtem.eei.ericsson.se:443/config-mgmt/event/filters/ROK3F7MD77ILG"

    # Get an empty filter list
    # [root@cloud-ms-1 ~]# curl -k -H "Content-Type: application/json" -X GET --cookie cookie.txt "https://enmapache.athtem.eei.ericsson.se:443/config-mgmt/event/filters"
    # {"_links":{"self":{"href":"/event/filters/"}},"filters":[]}[root@cloud-ms-1 ~]#

    rc = 0
    filter_kpi_failcount = 0
    buffer = StringIO()
    url = get_cfg_mgmt_event_url() + '/filters'
    filterids = []

    create_filter_json = '{ "filterClauses": [ { "attrName": "operationType", "attrValue": "UPDATE", "operator": "eq" }, { "attrName": "moClass", "attrValue": "CmNodeHeartbeatSupervision", "operator": "eq" } ], "filterDescription": "Filters all the events with operationType:UPDATE and moClass:CmNodeHeartbeatSupervision.", "filterName": "UPDATE_CheckKpiCreateTimeTaken" }'

    # Check that there aren't already too many filters
    filter_max = 100

    if not args.skip_solr:
        orig_filter_count = curl_get_filter_count(cookie_header)
        if orig_filter_count < 0:
            logmsg(syslog.LOG_ERR, 'Error %d getting filter count' %
                   orig_filter_count, tag='Filter')
            rc = -6
        elif orig_filter_count >= filter_max:
            # Already 100 filters, so set temporary error to suppress creation
            logmsg(syslog.LOG_INFO, 'Already %d persistent filters so none '
                                    'added' % filter_max, tag='Filter')
            rc = -5

    if rc == 0:
        f_maxtim = 0
        f_mintim = 9999999
        f_tottim = 0
        for filterloop in range(args.filtercount):  # was: - orig_filter_count):
            stim = time.time()
            if rc == 0:
                try:
                    opener = urllib2.build_opener(urllib2.HTTPHandler(debuglevel=0), urllib2.HTTPSHandler(debuglevel=0))
                    uc = get_url_request(url, cookie_header)
                    c = opener.open(uc, data=create_filter_json, timeout=args.evtimeout)
                except httplib.HTTPException, e:
                    logmsg(syslog.LOG_ERR, 'HTTPException = ' + str(e.code), tag='Filter')
                    rc = -6
                except urllib2.HTTPError, e:
                    logmsg(syslog.LOG_ERR, 'HTTPError = %d - %s for URL %s' % (e.code, e.read(), url), tag='Filter')
                    rc = -6
                except urllib2.URLError, e:
                    if hasattr(e, 'code') and hasattr(e, 'reason'):
                        logmsg(syslog.LOG_ERR, 'URLError = ' + str(e.code) + ':' + str(e.reason) + ' for URL ' + url, tag='Filter')
                    else:
                        logmsg(syslog.LOG_ERR, '%s for URL %s' % (str(e), url), tag='Filter')
                    rc = -6
                except Exception:
                    import traceback
                    logmsg(syslog.LOG_ERR, 'generic exception: ' + traceback.format_exc(), tag='Filter')
                    rc = -6

            etim = time.time() - stim

            if rc == 0:
                body = c.read()

                c.close()
                c = None

                try:
                    # Get the filter ID
                    bj = json.loads(body)
                    fid = bj['filterId']
                    filterids.append(fid)
                    if f_maxtim < etim:
                        f_maxtim = etim
                    if f_mintim > etim:
                        f_mintim = etim
                    f_tottim += etim
                    if etim > args.FILTERKPI:
                        filter_kpi_failcount += 1
                except:
                    rc = -1

    if len(filterids) > 0:
        # Report min, max and mean time taken to create N filters
        logmsg(syslog.LOG_INFO, 'Number of persistent filters added: %d' % len(filterids), tag='Filter')
        if len(filterids) > 0:
            if filter_kpi_failcount > 0:
                kpimsg = " KPI_Fail is > %.1f seconds for %d filters" % (args.FILTERKPI, filter_kpi_failcount)
            else:
                kpimsg = ""
            logmsg(syslog.LOG_INFO, 'Min/Max/Mean seconds for each filter to be created: %.1f/%.1f/%.1f%s' % (f_mintim, f_maxtim, f_tottim/len(filterids), kpimsg), tag='Filter')

    # Try to delete filters created here (even if there has been an error reported).
    if len(filterids) > 0:
        # Assume no error, and if ther's an error deleting, pass that through to the end of the method.
        rc = 0
        filter_kpi_failcount = 0

        # Now delete filters
        f_maxtim = 0
        f_mintim = 9999999
        f_tottim = 0
        for filterid in filterids:
            if rc == 0:
                stim = time.time()
                try:
                    opener = urllib2.build_opener(urllib2.HTTPHandler(debuglevel=0), urllib2.HTTPSHandler(debuglevel=0))
                    url_delete_filter = "%s/%s" % (url, filterid)
                    uc = get_url_request(url_delete_filter, cookie_header)
                    uc.get_method = lambda: 'DELETE'
                    c = opener.open(uc, timeout=args.evtimeout)
                except httplib.HTTPException, e:
                    logmsg(syslog.LOG_ERR, 'HTTPException = ' + str(e.code), tag='Filter')
                    rc = -6
                except urllib2.HTTPError, e:
                    logmsg(syslog.LOG_ERR, 'HTTPError = %d - %s for URL %s' % (e.code, e.read(), url_delete_filter), tag='Filter')
                    rc = -6
                except urllib2.URLError, e:
                    if hasattr(e, 'code') and hasattr(e, 'reason'):
                        logmsg(syslog.LOG_ERR, 'URLError = ' + str(e.code) + ':' + str(e.reason) + ' for URL ' + url_delete_filter, tag='Filter')
                    else:
                        logmsg(syslog.LOG_ERR, '%s for URL %s' % (str(e), url_delete_filter), tag='Filter')
                    rc = -6
                except Exception:
                    import traceback
                    logmsg(syslog.LOG_ERR, 'generic exception: ' + traceback.format_exc(), tag='Filter')
                    rc = -6

                etim = time.time() - stim

                if rc == 0:
                    body = c.read()

                    c.close()
                    c = None

                    if f_maxtim < etim:
                        f_maxtim = etim
                    if f_mintim > etim:
                        f_mintim = etim
                    f_tottim += etim
                    if etim > args.FILTERKPI:
                        filter_kpi_failcount += 1

    if rc == 0:
        # Report min, max and mean time taken to delete N filters
        if len(filterids) > 0:
            if filter_kpi_failcount > 0:
                kpimsg = " KPI_Fail is > %.1f seconds for %d filters" % (args.FILTERKPI, filter_kpi_failcount)
            else:
                kpimsg = ""
            logmsg(syslog.LOG_INFO, 'Min/Max/Mean seconds for each filter to be deleted: %.1f/%.1f/%.1f%s' % (f_mintim, f_maxtim, f_tottim/len(filterids), kpimsg), tag='Filter')

    # There were already too many filters, so say we created none
    if rc == -5:
        rc = 0

    # If OK return, look for the count of messages read
    #if rc >= 0:
        # Return was OK - check for doc count

    return rc

############################################################
# Get the maximum latency in the database (between Detection and Record time)
############################################################
def curl_get_max_latency():
    # Retrieve the maximum latency in the last 'period' (if None, 60 seconds), if OK status in response
    # If the request throws an exception, return -6
    # If time difference not found , return -3
    # If no documents returned, return -2
    # If status not found, return -1
    # Else return the status code as 0 followed by the time over which latency checked,
    # the minimum, maximum, mean latency periods in that time,
    # the number of event entries checked, and the number of entries outtside the KPI
    rc = 0
    latency_kpi_fail = 0
    body = ''
    buffer = StringIO()
    url = get_solr_base_url() + '/cm_events_nbi/select?'
    if args.period is None:
        latency_period = 60.0
    else:
        latency_period = args.period
    urlquery = 'eventRecordTimestamp:[NOW-%dMILLISECONDS TO NOW]' % (latency_period*1000)

    try:
        #url = '%s%s' % (url, urllib.urlencode({'q':urlquery, 'wt':'json', 'rows':'1000000', 'indent':'true', 'sort':'sub(eventRecordTimestamp,eventDetectionTimestamp) desc'}))
        url = '%s%s' % (url, urllib.urlencode({'q':urlquery, 'wt':'json', 'rows':'1000000', 'indent':'true', 'fl':'eventRecordTimestamp,eventDetectionTimestamp'}))
        # "operationType":"DELETE",
        # "eventRecordTimestamp":"2016-03-18T10:30:13.471Z",
        # "eventDetectionTimestamp":"2016-03-18T10:30:13.158Z",
        # "targetName":"ERBS01",
        # "moClass":"EUtranCellFDD",
        # "moFDN":"SubNetwork=ENM1,MeContext=LTE01ERBS00001,ManagedElement=1,ENodeBFunction=1,EUtranCellFDD=1",
        # "id":"589cb1cc-e038-47d5-9bdc-beffc9a2a7bb",
        # "_version_":1529135249201561600},

        c = urllib2.urlopen(url, timeout=args.evtimeout)
    except httplib.HTTPException, e:
        logmsg(syslog.LOG_ERR, 'HTTPException = ' + str(e.code), tag='Latency')
        rc = -6
    except urllib2.HTTPError, e:
        logmsg(syslog.LOG_ERR, 'HTTPError = %d - %s for URL %s' % (e.code, e.read(), url), tag='Latency')
        rc = -6
    except urllib2.URLError, e:
        if hasattr(e, 'code') and hasattr(e, 'reason'):
            logmsg(syslog.LOG_ERR, 'URLError = ' + str(e.code) + ':' + str(e.reason) + ' for URL ' + url, tag='Latency')
        else:
            logmsg(syslog.LOG_ERR, '%s for URL %s' % (str(e), url), tag='Latency')
        rc = -6
    except Exception:
        import traceback
        logmsg(syslog.LOG_ERR, 'generic exception: ' + traceback.format_exc(), tag='Latency')
        rc = -6

    # Set up default return values
    dtsmax = -1
    dtsmin = 9999999
    dtsmean = 0
    dtstot = 0
    rc_docs = 0

    if rc == 0:
        body = c.read()

        c.close()
        c = None

        # Now parse the returned body to get the maximum latency
        rc = -1
        try:
            bj = json.loads(body)
            rc = bj['responseHeader']['status']
            if rc == 0:
                rc_docs = bj['response']['numFound']
                if rc_docs > 0:
                    # First get latency time in milliseconds (saves repeated calc below)
                    latencykpi_milli = args.LATENCYKPI * 1000
                    # Step through the docs, looking for the minimum, maximum and total latency
                    for docnum in range(rc_docs):
                        tsr = bj['response']['docs'][docnum]['eventRecordTimestamp']
                        tsd = bj['response']['docs'][docnum]['eventDetectionTimestamp']
                        dtsr = parser.parse(tsr, fuzzy=True)
                        dtsd = parser.parse(tsd, fuzzy=True)
                        thisdiff = abs(dtsr - dtsd)
                        thisdiff = (thisdiff.days*86400+thisdiff.seconds)*1000 + thisdiff.microseconds/1000
                        if thisdiff > dtsmax:
                            dtsmax = thisdiff
                        if thisdiff < dtsmin:
                            dtsmin = thisdiff
                        dtstot += thisdiff
                        if thisdiff > latencykpi_milli:
                            latency_kpi_fail += 1
        except:
            pass

    # If OK return, look for the count of messages read
    if rc == 0:
        # Return was OK - check for doc count
        if rc_docs > 0:
            # Got docs - if we got a max value, get mean difference
            if dtsmax >= 0:
                dtsmean = (dtstot + 0.0) / rc_docs
            else:
                rc = -3
        else:
            rc = -2
    else:
        rc = -1

    if rc == 0:
        # At this point we know that the max, min and count values are valid
        logmsg(syslog.LOG_DEBUG, 'Min/Max/Mean latency in last %.1f seconds: %d/%d/%0.1f with %d KPI fails' % (latency_period, dtsmin, dtsmax, dtsmean, latency_kpi_fail))

    logmsg(syslog.LOG_DEBUG, 'Return data from get latency (%d bytes) with code %d begins: %s' % (len(body), rc, body[:1000]))

    return rc, latency_period, dtsmin, dtsmax, dtsmean, rc_docs, latency_kpi_fail

# Class to suppress redirection
class NoRedirection(urllib2.HTTPErrorProcessor):

    def http_response(self, request, response):
        return response

    https_response = http_response

############################################################
# Get a cookie for the CM Events NBI interface
############################################################
def curl_get_nbi_cookie():
    # Get a cookie from the CM Events NBI interface, return in cookie_header variable
    # If the request throws an exception, return -6
    # Else return 0
    rc = 0
    cookie_text_file = 'cookie.%d.txt' % os.getpid()
    cmd = '/usr/bin/curl --insecure --request POST --cookie-jar %s \'https://%s/login?IDToken1=Administrator&IDToken2=%s\'' % (cookie_text_file, args.evserver, args.nbi_password)

    try:
        os.remove(cookie_text_file)
    except:
        pass
    try:
        c = subprocess.call(cmd, shell=True)
    except subprocess.CalledProcessError, e:
        logmsg(syslog.LOG_ERR, "Error %d calling command %s, output was %s" % (e.returncode, e.cmd, e.output))
        rc = -6
    except Exception:
        import traceback
        logmsg(syslog.LOG_ERR, 'generic exception: ' + traceback.format_exc())
        rc = -6

    cookie_header = None

    if rc == 0:
        # Command worked, so assume cookie text file has been written
        if os.path.exists(cookie_text_file):
            # Now read the cookies into the header
            try:
                with open(cookie_text_file) as f:
                    content = [x.strip('\n') for x in f.readlines()]
                r = re.compile(r"^(\S+)\s*(\S+)\s*(\S+)\s*(\S+)\s*(\S+)\s*(\S+)\s*(\S+)$")
                for l in content:
                    if len(l) == 0 or l[0] == "#":
                        continue
                    m = r.search(l)
                    if m is None:
                        logmsg(syslog.LOG_ERR, 'Error parsing cookie file %s, line %s' % (cookie_text_file, l))
                        rc = -3
                        break
                    else:
                        # Got a line - get the end of it
                        if cookie_header:
                            cookie_header = '%s; %s=%s' % (cookie_header, m.group(6), m.group(7))
                        else:
                            cookie_header = '%s=%s' % (m.group(6), m.group(7))

                # All read, so now remove the file
                try:
                    os.remove(cookie_text_file)
                except:
                    pass
            except:
                logmsg(syslog.LOG_ERR, "Error parsing cookie file %s" % cookie_text_file)
                rc = -4
        else:
            logmsg(syslog.LOG_ERR, "Error cookie file %s not found" % cookie_text_file)
            rc = -5


    logmsg(syslog.LOG_DEBUG, 'Return code from get cookies: %d' % rc)
    if rc == 0:
        logmsg(syslog.LOG_DEBUG, 'Return header from get cookies: %s' % cookie_header)

    return rc, cookie_header

############################################################
# Construct URL Request
############################################################
def get_url_request(url, cookie_header):
    uc = urllib2.Request(url)
    uc.add_header("Cookie", cookie_header)
    uc.add_header("Content-Type", "application/json")
    uc.add_header("Host", args.evserver)
    return uc

############################################################
# Returns the date in UTC Zulu format as a string
############################################################
def yesterday_date():
    yesterday = datetime.utcnow() - timedelta(1)
    return yesterday.strftime("%Y-%m-%dT%H:%M:%S.000Z")

############################################################
# Send a request to CM Events NBI to retrieve up to 50,000 events
############################################################
def curl_get_nbi_events(cookie_header):
    # Retrieves up to 50,000 events from the NBI interface, if OK status in response
    # If the request throws an exception, return -6
    # If the request cannot be parsed, return -1
    #   Else count the number of items in the body,
    #        return the start and end times
    #        and return the number
    buffer = StringIO()
    rc = 0
    bj = None
    bj_status = "UNKNOWN"
    stim = 0.0
    etim = 0.0

    stim = time.time()

    filter_clauses = '[{"attrName":"eventDetectionTimestamp","operator":"gt","attrValue":"%s"}]' %(yesterday_date())
    encoded_clauses = urllib.quote_plus(filter_clauses)
    url = 'https://%s/config-mgmt/event/events?orderBy=eventDetectionTimestamp&limit=%d&filterClauses=%s' %(args.evserver, args.evread, encoded_clauses)
    logmsg(syslog.LOG_DEBUG, 'url to get events: %s' % url)
    try:
        proxy_handler = urllib2.ProxyHandler({})
        opener = urllib2.build_opener(urllib2.HTTPHandler(debuglevel=0),
                                      urllib2.HTTPSHandler(debuglevel=0),
                                      proxy_handler)
        uc = get_url_request(url, cookie_header)
        c = opener.open(uc, timeout=args.evtimeout)
    except httplib.HTTPException, e:
        logmsg(syslog.LOG_ERR, 'HTTPException = ' + str(e.code))
        rc = -6
    except urllib2.HTTPError, e:
        logmsg(syslog.LOG_ERR, 'HTTPError = %d - %s for URL %s' % (e.code, e.read(), url))
        rc = -6
    except urllib2.URLError, e:
        if hasattr(e, 'code') and hasattr(e, 'reason'):
            logmsg(syslog.LOG_ERR, 'URLError = ' + str(e.code) + ':' + str(e.reason) + ' for URL ' + url)
        else:
            logmsg(syslog.LOG_ERR, '%s for URL %s' % (str(e), url))
        rc = -6
    except Exception:
        import traceback
        logmsg(syslog.LOG_ERR, 'generic exception: ' + traceback.format_exc())
        rc = -6

    if rc == 0:
        body = c.read()

        c.close()
        c = None

        etim = time.time()

        # If OK return, look for the number of messages read,
        # and the read status (PARTIAL, if there were more than the requested number of events)
        rc = -1
        try:
            bj = json.loads(body)
            rc = len(bj['events'])
            bj_status = bj['status']
        except:
            pass

    logmsg(syslog.LOG_DEBUG, 'Return code for getting NBI events (status %s): %d' % (bj_status, rc))
    if rc >= 0:
        logmsg(syslog.LOG_DEBUG, 'Return data for getting NBI events (%d characters): %s' % (len(body), body[:1000]))
    return rc, stim, etim, bj_status

def run_parallel_get_nbi_events(cookie_header):
    # Run a "curl_get_nbi_events" to read up to --evread events (default 50,000) and time it
    # This is run as a forked child of the main script
    # Return the start time, stop time and number of events to the caller,
    # by writing the result to a file based on the PID
    # Times are in floating point seconds since the epoch
    # Negative numbers of events are used to report errors

    mypid = os.getpid()
    outf = "rge%d.txt" % mypid
    stim = 0.0
    etim = 0.0
    rgc = 0
    rge = -1

    # If no cookie_header passed in, get one for this client
    if cookie_header is None:
        rgc, cookie_header = curl_get_nbi_cookie()

    if rgc >= 0:
        # Read events from the interface using the cookie header
        rge, stim, etim, rge_status = curl_get_nbi_events(cookie_header)

    # If either call failed, rge (return code from getting events) will still be -1
    with open(outf,"a") as f:
        f.write('%d %f %f %d \n' % (rgc, stim, etim, rge))

    # terminate this child with an ok response (errors reported in returned data, not return code here)
    # Use _exit() rather than exit() because we are in a child.
    os._exit(0)

def run_parallel_calls(bg_count = 10, cookie_header=None):
    # Issue the required number of calls to run_parallel_get_nbi_events() in the background

    childpids = []
    for rch in range(bg_count):
        rf = os.fork()
        if rf == 0:
            # In child - set off a data read
            run_parallel_get_nbi_events(cookie_header)
            # The above function will exit
        else:
            # In parent - remember the child's PID
            childpids.append(rf)
            # and wait a while before starting the next one
            time.sleep(args.clientdelay)

    # Loop through children for up to 120 seconds, waiting for them to finish
    wait_for_child_pids(120, childpids, 'Parallel batch')

    # Now get the times and counts
    ch_count = 0
    ch_mintim = 9999999.0
    ch_maxtim = 0.0
    ch_tottim = 0.0
    ch_minrecs = 9999999
    ch_maxrecs = 0
    ch_totrecs = 0
    event_kpi_failcount = 0
    pat = re.compile("[ \n]")
    for ch in childpids:
        # If this child has finished - read and delete its record
        inpf = "rge%d.txt" % ch
        if os.path.isfile(inpf):
            try:
                with open(inpf,"r") as f:
                    inlin = f.read()
                # Read cookie status, start time, end time and event count
                a, b, c, d = pat.split(inlin)[0:4]
                a = int(a)
                b = float(b)
                c = float(c)
                d = int(d)
                if a == 0 and d >= 0:
                    t = c - b
                    if d < ch_minrecs:
                        ch_minrecs = d
                    if d > ch_maxrecs:
                        ch_maxrecs = d
                    if t < ch_mintim:
                        ch_mintim = t
                    if t > ch_maxtim:
                        ch_maxtim = t
                    ch_tottim += t
                    if t > args.EVENTPKPI:
                        event_kpi_failcount += 1
                    ch_totrecs += d
                    ch_count += 1
                # All done, delete the file
                os.unlink(inpf)
            except:
                logmsg(syslog.LOG_WARNING, "Problem reading child file %s for process %d" % (inpf, ch))
        else:
            logmsg(syslog.LOG_WARNING, "Could not find child file %s for process %d" % (inpf, ch))
            # Kill child, but don't worry if it doesn't die
            try:
                os.kill(ch)
            except:
                pass

    logmsg(syslog.LOG_INFO, 'Starting %d parallel clients, with %.1f sec delay, to retrieve up to %d events each' % (bg_count, args.clientdelay, args.evread))
    logmsg(syslog.LOG_INFO, 'Successful parallel clients: %d' % ch_count)
    if ch_count == 0:
        logmsg(syslog.LOG_WARNING, "No child processes successful")
    else:
        if event_kpi_failcount > 0:
            kpimsg = " KPI_Fail is > %.1f seconds for %d clients" % (args.EVENTPKPI, event_kpi_failcount)
        else:
            kpimsg = ""
        logmsg(syslog.LOG_INFO, 'Min/Max/Mean seconds for each client to retrieve events: %.1f/%.1f/%.1f%s' % (ch_mintim, ch_maxtim, ch_tottim/ch_count, kpimsg))
        logmsg(syslog.LOG_INFO, 'Min/Max/Mean number of events retrieved for each client: %d/%d/%.1f' % (ch_minrecs, ch_maxrecs, ch_totrecs / ch_count))


# Loop through children for up to 120 seconds, waiting for them to finish
def wait_for_child_pids(maxwait, childpids, description):
    # Loop through children for up to maxwait seconds, waiting for them to finish

    currwait = 0
    while currwait < maxwait:
        allrun = True
        for ch in childpids:
            try:
                cpid, cstat = os.waitpid(ch, os.WNOHANG)
            except:
                # Child already dead - pretend it has just stopped
                cpid = ch
                cstat = 0
            if cpid == 0:
                # This chid is still running
                allrun = False
                break
        if allrun:
            break
        time.sleep(1)
        currwait += 1

    if currwait >= maxwait:
        logmsg(syslog.LOG_WARNING, "Error, %s Timed out waiting for all children to finish" % description)


if __name__ == "__main__":
    args = parse_cmd_line()

    log = logging.getLogger("cm_events_kpi_check")

    msg = "Solr Server:Port = %s:%d" % (args.server, args.port)
    if args.filterkpi:
        msg = "%s, Filter count = %d" % (msg, args.filtercount)
    if args.evtest:
        msg = "%s, Client count = %d" % (msg, args.clientcount)
    logmsg(syslog.LOG_DEBUG, msg)

    # Set up handler to cacth Ctrl-C gracefully
    signal.signal(signal.SIGINT, catchCtrlC)

    while True:
        loop_start_time  = time.time()

        if not args.skip_solr and args.stattimeout:
            rc = curl_get_status()
            if rc < 0:
                logmsg(syslog.LOG_ERR, "Status request returned code %d" % rc)
            if not args.keeprunning:
                sys.exit(1)
            logmsg(syslog.LOG_INFO, 'Database record count: %d' % rc)

        if not args.skip_solr and args.solrquery:
        # Read the contents of the database table
            rcr = curl_run_reader()
            # Return codes less than 0 indicate an error
            if rcr < 0:
                logmsg(syslog.LOG_ERR, 'Reading table items failed with code %d' % rcr)
                sys.exit(1)

        if not args.skip_solr:
            rrr = curl_run_get_rate()
            if rrr < 0:
                logmsg(syslog.LOG_ERR, 'Reading run rate failed with code %d' % rrr)
                if not args.keeprunning:
                    sys.exit(1)
            else:
                # Report event rate over the past minute
                logmsg(syslog.LOG_INFO, "Events per second over last 60 seconds: %.1f " % (rrr / 60.0))

        if not args.skip_solr and args.latency:
            # We are checking for latency in the database
            rgl, rgtime, rgmin, rgmax, rgmean, rgcount, rgkpifail = curl_get_max_latency()
            if rgl == -2:
                logmsg(syslog.LOG_INFO, 'No messages in last %.1f seconds to check latency' % rgtime, tag='Latency')
            elif rgl < 0:
                logmsg(syslog.LOG_ERR, 'Failed to get maximum latency of database entries, with code %d' % rgl, tag='Latency')
            else:
                if rgkpifail > 0:
                    kpimsg = " KPI_Fail is > %.1f seconds for %d database entries" % (args.LATENCYKPI, rgkpifail)
                else:
                    kpimsg = ""
                logmsg(syslog.LOG_INFO, 'Min/Max/Mean latency of %d database entries over %.1f seconds: %d/%d/%0.1f milliseconds%s' % (rgcount, rgtime, rgmin, rgmax, rgmean, kpimsg), tag='Latency')

        # Ensure any old cookie for previous loop discarded
        cookie_header = None

        if args.minimizecookies:
            # Get a single cookie to connect to the interface for all requests in this loop
            rgc, cookie_header = curl_get_nbi_cookie()
            if rgc < 0:
                logmsg(syslog.LOG_ERR, 'Getting cookie from CM Events NBI interface failed with code %d' % rgc)
                if not args.keeprunning:
                    sys.exit(1)
                cookie_header = None

        if args.filterkpi:
            # We are checking for filter creation and deletion times

            if not args.minimizecookies:
                # Get a cookie to connect to the interface
                rgc, cookie_header = curl_get_nbi_cookie()
                if rgc < 0:
                    logmsg(syslog.LOG_ERR, 'Getting cookie from CM Events NBI interface for filters failed with code %d' % rgc)
                    if not args.keeprunning:
                        sys.exit(1)
                    cookie_header = None

            if cookie_header is not None:
                # Logging performed within function.
                rgf = curl_get_filter_timing(cookie_header)

        if args.evtest:
            # We are checking time taken on the CM Events NBI interface

            if not args.minimizecookies:
                # Get a cookie to connect to the interface
                rgc, cookie_header = curl_get_nbi_cookie()
                if rgc < 0:
                    logmsg(syslog.LOG_ERR, 'Getting cookie from CM Events NBI interface for events failed with code %d' % rgc)
                    if not args.keeprunning:
                        sys.exit(1)
                    cookie_header = None

            # Commenting out the following lines due to [TORF-191999 Update load script to run 10 clients (not 11)]
            # The reason the lines have not been removed yet is because there may be a senerio which needs them.
            #
            #if cookie_header is not None:
                # Now read up to --evread (default 50,000) events through the NBI interface
            #    rge, stim, etim, rge_status = curl_get_nbi_events(cookie_header)
            #    if rge >= 0:
            #        if (etim - stim) > args.EVENTSKPI:
            #            kpimsg = " KPI_Fail is > %.1f seconds" % args.EVENTSKPI
            #        else:
            #            kpimsg = ""
            #        logmsg(syslog.LOG_INFO, "NBI read %s: %d items in %.1f seconds%s" % (rge_status, rge, etim - stim, kpimsg))

            # If not minimizing the number of cookies requested, discard the previous cookie
            # - the called code will grab a new one per client
            if not args.minimizecookies:
                cookie_header = None

            # Run parallel processes to read the data (defaults to 10 calls)
            # run_parallel_calls(bg_count = args.clientcount,
            # cookie_header=cookie_header)

        # Run parallel processes to read the data (defaults to 10 calls)
        # If parallel is selected, -st = 4
        if args.stack_type == 4:

            rf = os.fork()
            if rf == 0:
                # In child - connect with IPv4
                ip_type = socket.AF_INET
                run_parallel_calls(bg_count=args.clientcount,
                                  cookie_header=cookie_header)
                os._exit(0)
            else:
                # In parent - connect with IPv6
                ip_type = socket.AF_INET6
                run_parallel_calls(bg_count=args.clientcount,
                                   cookie_header=cookie_header)

                # Loop through children for up to 800 seconds, waiting for them to finish
                wait_for_child_pids(800, [rf], 'IPv4 -v- IPv6')
        else:
        # parallel not selected. -st = 1,2, or 3
            run_parallel_calls(bg_count=args.clientcount,
                               cookie_header=cookie_header)


        if args.period is None or force_loop_exit:
            # We are only running once or Ctrl-C pressed once - exit the "forever" loop
            if force_loop_exit:
                logmsg(syslog.LOG_INFO, "Script exit on Ctrl-C")
            break
        else:
            # We are running forever - sleep until the specified time after loop_start_time
            # If we are already past that time, continue immediately
            next_loop_wait = loop_start_time + args.period - time.time()
            if next_loop_wait > 0:
                time.sleep(next_loop_wait)