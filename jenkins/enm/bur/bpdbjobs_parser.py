#!/usr/bin/python
#
# bpdbreport.py
#
# Take input from bpdbjobs -report -all_columns
# and change info into human readable format
#


import os
import re
import csv
import sys
import time
import types
import getopt
import string
import cPickle
import fileinput
import traceback

# definitions for indexed job columns
job_type  = {   '0' : 'Backup',
                '1' : 'Archive',
                '2' : 'Restore',
                '3' : 'Verify',
                '4' : 'Duplicate',
                '5' : 'Import',
                '6' : 'DB Backup',
                '7' : 'Vault'
            }
job_state = { '0' : 'Queued', '1' : 'Active', '2' : 'Re-Queued', '3' : 'Done' }
sched_type = { '0': 'Full', '1' : 'Differential', '2' : 'User Backup', '3' : 'User Archive', '4' : 'Cumulative' }
sub_type = {'0': 'Immediate', '1': 'Scheduled', '2': 'User-Initiated' }
retention_units = { '0': 'Unknown', '1': 'Days', '2': 'Unknown' }



def usage():
    print >>sys.stderr, '''\nbpdbreport.py usage:

    bpdbreport.py [switches] <filelist> | -

    -a                       all data format (includes try information)
    -d                       run in debug mode (outputs to stderr)
    -f format_file           column output format file
    -s dd/mmm/yyyy           define start time (default is epoch)
    -e dd/mmm/yyyy           define end time (default is current localtime)
    -h                       print this help and exit
    --hoursago hours         sets start time to number of hours ago
                               --hoursago and -s/-e should be mutually
                               exclusive, but they aren't yet. Use only
                               one or the other.
    --mdy                    change verbose date output format to mm/dd/yyyy
    --shelve_dicts filename  output dictonary to a python pickle object
                               This option implies -q
    --show_active            show Done and Active jobs
                               (may show duplicates if multiple files are used)
    --show_all               show All jobs
                               (may show duplicates if multiple files are used)
    -q                       quiet (no output to stdout)
    --usage                  print detailed help message and exit
    -v                       verbose (human readable output)

    Default output is the first 32 columns from bpdbjobs -report -all_columns
    formatted data. Columns can be defined by format file (see --usage for
    sample format file)

    examples:
        get all entries in verbose format from stdin:
            bpdbreport.py -s 05/may/2003 -e 05/jun/2003 -v -

        get data from file named all_columns.output and display columns defined
        in sample.fmt file
            bpdbreport.py -f sample.fmt all_columns.output

    Lines that generate bad data (mostly because of bugs or bad commas) will
    spit out error lines to stderr in the format of:
        ERROR: inputline
'''



def detailed_usage():
    usage()
    print >>sys.stderr, '''

# sample format file for column output
# This will skip all lines that start with # and
# all whitespace lines.
# Any lines that are incorrect will be dropped

jobid
jobtype
state
status
class
sched
client
server
start
elapsed
end
stunit
try
operation
kbytes
files
path_last_written
percent
jobpid
owner
subtype
classtype
schedtype
priority
group
master_server
retention_units
retention_period
compression
kbyteslastwritten
fileslastwritten
filelistcount
parentjob
kbpersec
copy
robot
vault
profile
session
ejecttapes
srcstunit
srcserver
srcmedia
dstmedia
stream
suspendable
resumable
restartable
datamovement
frozenimage
backupid
killable
controllinghost'''


def sec_to_hms( input ):
    input = seconds = int(input)
    hours = seconds / 3600
    seconds = seconds - hours*3600
    minutes = seconds / 60
    seconds = seconds - minutes*60
    return (hours,minutes,seconds)




def process_line(buffer):
    dict = {}
    idx = 0
    info_labels = ( 'jobid', 'jobtype', 'state', 'status', 'class', 'sched',
                    'client', 'server', 'start', 'elapsed', 'end', 'stunit',
                    'try', 'operation', 'kbytes', 'files', 'path_last_written',#17
                    'percent', 'jobpid', 'owner', 'subtype', 'classtype',
                    'schedtype', 'priority', 'group', 'master_server',
                    'retention_units', 'retention_period', 'compression',
                    'kbyteslastwritten', 'fileslastwritten', 'filelistcount' )
    try_labels1 = ( 'trypid', 'trystunit', 'tryserver', 'trystarted', 'tryelapsed',
                    'tryended', 'trystatus', 'trystatusdescription', 'trystatuscount' )
    try_labels2 = ( 'trybyteswritten','tryfileswritten' )
    info_labels4x = ( 'parentjob', 'kbpersec', 'copy', 'robot', 'vault', 'profile',
                    'session', 'ejecttapes', 'srcstunit', 'srcserver', 'srcmedia',
                    'dstmedia', 'stream' )
    info_labels5x = ( 'suspendable','resumable','restartable','datamovement',
                    'frozenimage','backupid','killable','controllinghost' )


    for label in info_labels:
        dict[label] = buffer[idx]
        idx += 1

    try:
        if dict['filelistcount'] > 0:
            for f in range ( idx, idx+int(dict['filelistcount']) ):
                try:
                    dict['filelist'].append(buffer[idx])
                except:
                    dict['filelist'] = [buffer[idx]]
                idx += 1
        dict['trycount'] = buffer[idx]
        idx += 1

        for job_try in range(1,int(dict['trycount'])+1):
            try_idx = 'try'+str(job_try)
            dict[try_idx] = {}
            for trylabel in try_labels1:
                dict[try_idx][trylabel] = buffer[idx]
                idx += 1
            if dict[try_idx]['trystatuscount'] > 0:
                for f in range ( idx, idx+int(dict[try_idx]['trystatuscount']) ):
                    try:
                        dict[try_idx]['trystatuslines'].append(buffer[idx])
                    except:
                        dict[try_idx]['trystatuslines'] = [buffer[idx]]
                    idx += 1
            for trylabel in try_labels2:
                dict[try_idx][trylabel] = buffer[idx]
                idx += 1
        try:
            for label in info_labels4x:
                dict[label] = buffer[idx]
                idx += 1
        except:
            pass
        try:
            for label in info_labels5x:
                dict[label] = buffer[idx]
                idx += 1
        except:
            pass

        return dict, 0, False
    except:
        return dict, sys.exc_info(),buffer



def get_output_cols( format_file ):
    try:
        col_fp = open( format_file, 'r' )
    except:
        print >>sys.stderr, 'could not open format file'
        return None

    for line in col_fp:
        line = line.rstrip('\n')
        buf = line.split('#',1)
        if buf[0]:
            try:
                col_fmt.append(buf[0].strip())
            except:
                col_fmt = [buf[0].strip()]
    col_fp.close()
    return col_fmt


def print_dict(d,k,t):
    if debug_mode:
        print >>sys.stderr,'DEBUG:   ',k,'{'
        keys = d.keys()
        keys.sort()
        for item in keys:
            if type(d[item]) is types.DictType:
                print_dict(d[item],item,t+1)
            elif type(d[item]) is types.ListType:
                print_list(d[item],item,t+1)
            else:
                print >>sys.stderr,'DEBUG:   ','\t'*t+item,':',d[item]
        print >>sys.stderr,'DEBUG:   ','}'
    else:
        print k,'{'
        keys = d.keys()
        keys.sort()
        for item in keys:
            if type(d[item]) is types.DictType:
                print_dict(d[item],item,t+1)
            elif type(d[item]) is types.ListType:
                print_list(d[item],item,t+1)
            else:
                if verbose:
                    print '\t'*t+item,':',readability( item, d[item] )
                else:
                    print '\t'*t+item,':',d[item]
        print '}'


def print_list(l,k,t):
    if debug_mode:
        idx = 0
        print >>sys.stderr,'DEBUG:   ','\t'*(t-1)+k,'{'
        for item in l:
            if type(item) is types.DictType:
                print_dict(l[idx],item,t+1)
            elif type(item) is types.ListType:
                print_list(l[idx],item,t+1)
            else:
                print >>sys.stderr,'DEBUG:   ','\t'*t+l[idx]
            idx += 1
        print >>sys.stderr,'DEBUG:   ','\t'*(t-1)+'}'
    else:
        idx = 0
        print '\t'*(t-1)+k,'{'
        for item in l:
            if type(item) is types.DictType:
                print_dict(l[idx],item,t+1)
            elif type(item) is types.ListType:
                print_list(l[idx],item,t+1)
            else:
                if verbose:
                    print '\t'*t+readability( item, l[idx] )
                else:
                    print '\t'*t+l[idx]
            idx += 1
        print '\t'*(t-1)+'}'

def output_data( d,col_fmt_input ):
    list4x = [ 'parentjob', 'kbpersec', 'copy', 'robot', 'vault', 'profile',
            'session', 'ejecttapes', 'srcstunit', 'srcserver', 'srcmedia',
            'dstmedia', 'stream' ]
    list5x = [ 'suspendable','resumable','restartable','datamovement',
            'frozenimage','backupid','killable','controllinghost' ]

    keys = d.keys()
    keys.sort()

    if all_data:
        for key in keys:
            print key,'{'
            k = d[key].keys()
            k.sort()
            for item in k:
                if type(d[key][item]) is types.ListType:
                    print_list(d[key][item],item,1)
                elif type(d[key][item]) is types.DictType:
                    print_dict(d[key][item],item,1)
                else:
                    if verbose:
                        print item,':',readability( item, d[key][item] )
                    else:
                        print item,':',d[key][item]
            print '}*** END',key,'***\n'
        return

    for key in keys:
        col_fmt = col_fmt_input
        nbuVersion = get_nbuVersion(d[key])

        if not col_fmt:
            col_fmt = [ 'jobid', 'jobtype', 'state', 'status', 'class', 'sched',
                    'client', 'server', 'start', 'elapsed', 'end', 'stunit',
                    'try', 'operation', 'kbytes', 'files', 'path_last_written',
                    'percent', 'jobpid', 'owner', 'subtype', 'classtype',
                    'schedtype', 'priority', 'group', 'master_server',
                    'retention_units', 'retention_period', 'compression',
                    'kbyteslastwritten', 'fileslastwritten', 'filelistcount' ]
            if nbuVersion == '4x':
                for item in list4x:
                    col_fmt.append(item)
            elif nbuVersion == '5x':
                for item in list4x:
                    col_fmt.append(item)
                for item in list5x:
                    col_fmt.append(item)

        col_out = ''
        for column in col_fmt:
            if verbose:
                data = readability(column, d[key][column])
                col_out += data+','
            else:
                col_out += d[key][column]+','
        col_out = col_out.rstrip(',')
        print col_out


def get_nbuVersion(key):
    if key.has_key('suspendable'):
        nbuVersion = '5x'
    elif key.has_key('kbpersec'):
        nbuVersion = '4x'
    else:
        nbuVersion = '3x'
    return nbuVersion


def print_header( col_fmt,d ):
    ''' This pretty much assumes a 5.1 header for the csv output'''
    if not col_fmt:
        col_fmt = [ 'jobid', 'jobtype', 'state', 'status', 'class', 'sched',
                'client', 'server', 'start', 'elapsed', 'end', 'stunit',
                'try', 'operation', 'kbytes', 'files', 'path_last_written',
                'percent', 'jobpid', 'owner', 'subtype', 'classtype',
                'schedtype', 'priority', 'group', 'master_server',
                'retention_units', 'retention_period', 'compression',
                'kbyteslastwritten', 'fileslastwritten', 'filelistcount',
                'parentjob', 'kbpersec', 'copy', 'robot', 'vault', 'profile',
                'session', 'ejecttapes', 'srcstunit', 'srcserver', 'srcmedia',
                'dstmedia', 'stream', 'suspendable','resumable','restartable',
                'datamovement', 'frozenimage','backupid','killable','controllinghost' ]

    col_out = ''
    for header in col_fmt:
        col_out += header.upper()+','
    col_out = col_out.rstrip(',')
    print col_out


def readability( key, string ):
    try:
        if key == 'jobtype':
            string = job_type[string]
        elif key == 'state':
            string = job_state[string]
        elif key == 'schedtype':
            string = sched_type[string]
        elif key == 'subtype':
            string = sub_type[string]
        elif key in ['start','end','trystarted','tryended']:
            if mdy:
                string = time.strftime( '%m/%d/%Y %H:%M:%S', time.localtime(int(string)))
            else:
                string = time.strftime( '%d/%b/%Y %H:%M:%S', time.localtime(int(string)))
        elif key in ['elapsed','tryelapsed']:
            (h,m,s) = sec_to_hms(string)
            string = '%d:%02d:%02d' % (h,m,s)
    except:
        pass
    return string


def output_debug_dict( d ):
    keys = d.keys()
    keys.sort()

    print >>sys.stderr, 'DEBUG:   ', d['jobid'],'{'
    for key in keys:
        if type(d[key]) is types.ListType:
            print_list(d[key],key,1)
        elif type(d[key]) is types.DictType:
            print_dict(d[key],key,1)
        else:
            print >>sys.stderr, 'DEBUG:   ', key,':',d[key]
    print >>sys.stderr, 'DEBUG:   }*** END',d['jobid'],'***'
    return



if __name__ == '__main__':
    try:
        opts, args = getopt.getopt(sys.argv[1:],
                                    "f:s:e:hvxadq", ["hoursago=","shelve_dicts=", "show_active", "show_all", "usage", "mdy"])
    except getopt.GetoptError:
        # print help information to stderr and exit:
        usage()
        sys.exit(2)
    if not args:
        for o, a in opts:
            if o == "-h":
                usage()
                sys.exit()
            if o == "--usage":
                detailed_usage()
                sys.exit()
        print >>sys.stderr, '\nArgument list can not be empty'
        print >>sys.stderr, 'use "-" for stdin'

        usage()
        sys.exit(1)

    # Check to see if filenames are valid files
    argflag = False
    for arg in args:
        if arg != '-':
            if not os.path.exists(arg):
                argflag = True
                print >>sys.stderr, '\nFile', arg, 'does not exist.'
    if argflag:
        usage()
        sys.exit(1)

    # Commandline argument defaults
    all_data        = False                         # -a
    debug_mode      = False                         # -d
    xplicite        = False                         # -x (not used yet)
    verbose         = False                         # -v
    mdy             = False                         # --mdy
    start_date      = 0                             # -s
    show_active     = False                         # --show_active
    show_all        = False                         # --show_all
    end_date        = time.mktime(time.localtime()) # -e
    format_file     = ''                            # -f
    col_fmt         = ''                            # parsed column output string
    shelve_dicts    = False                         # shelve data for future use
    output          = True                          # -q default output, option turns it off

    for o, a in opts:
        if o == "-h":
            usage()
            sys.exit()
        if o == "--usage":
            detailed_usage()
            sys.exit()
        if o == "-f":
            format_file = a
        if o == "-d":
            debug_mode = True
        if o == "--shelve_dicts":
            shelve_dicts = True
            output = False
            pkl = a
        if o == "-q":
            output = False
        if o == "-v":
            verbose = True
        if o == "--show_active":
            show_active = True
        if o == "--show_all":
            show_all = True
            show_active = False
        if o == "--mdy":
            mdy = True
        if o == "--hoursago":
            hoursago = a
            start_date = end_date - int(hoursago) * 3600
        if o == "-s":
            try:
                start_date = time.mktime(time.strptime(a, '%d/%b/%Y'))
            except:
                print >>sys.stderr, '\nDate values must be in dd/mmm/yyyy format'
                usage()
                sys.exit(1)
        if o == "-e":
            try:
                end_date = time.mktime(time.strptime(a, '%d/%b/%Y'))
                end_date += 86399   # Add 23:59:59 to enddate to include that day
            except:
                print >>sys.stderr, '\nDate values must be in dd/mmm/yyyy format'
                usage()
                sys.exit(1)
        if o == "-a":
            all_data = True
        if o == "-x":
            xplicite = True

    done_master = {}
    active_master = {}
    queued_master = {}
    requeued_master = {}

    try:
        if debug_mode:
            print >>sys.stderr, 'DEBUG: Options and Arguments:'
            for o,a in opts:
                print >>sys.stderr, 'DEBUG:   ', o, a
        for inputline in fileinput.input(args):
            try:
                for line in csv.reader([inputline], escapechar='\\'):
                    try:
                        d, exc, buf_debug = process_line(line)
                        if exc:
                            raise
                    except:
                        if debug_mode:
                            print >>sys.stderr, 'DEBUG:  ', '*'*30
                            print >>sys.stderr, 'DEBUG:   Filename:            ', fileinput.filename()
                            print >>sys.stderr, 'DEBUG:   Line Number:         ', fileinput.lineno()
                            print >>sys.stderr, 'DEBUG:   Exception:           ', exc[0]
                            print >>sys.stderr, 'DEBUG:   Exception:           ', exc[1]
                            print >>sys.stderr, 'DEBUG:   Dict Contents:       '
                            output_debug_dict(d)
                            print >>sys.stderr, 'DEBUG:   ', buf_debug
                            print >>sys.stderr, 'DEBUG:   ', line
                            print >>sys.stderr, 'DEBUG:  ', '*'*30
                        else:
                            print >>sys.stderr, 'ERROR: ', line
                    else:
                        try:
                            if int(d['start']) >= start_date and int(d['start']) <= end_date:
                                # To make this cleaner, maybe cross check dicts based on
                                # the assumption that Done jobs are the most important?
                                if int(d['state']) == 0:
                                    if not queued_master.get(d['jobid']):
                                        try:
                                            queued_master[d['jobid']].append(d)
                                        except:
                                            queued_master[d['jobid']] = d
                                elif int(d['state']) == 1:
                                    if not active_master.get(d['jobid']):
                                        try:
                                            active_master[d['jobid']].append(d)
                                        except:
                                            active_master[d['jobid']] = d
                                elif int(d['state']) == 2:
                                    if not requeued_master.get(d['jobid']):
                                        try:
                                            requeued_master[d['jobid']].append(d)
                                        except:
                                            requeued_master[d['jobid']] = d
                                elif int(d['state']) == 3:
                                    if not done_master.get(d['jobid']):
                                        try:
                                            done_master[d['jobid']].append(d)
                                        except:
                                            done_master[d['jobid']] = d
                        except:
                            if debug_mode:
                                exc = sys.exc_info()
                                print >>sys.stderr, 'DEBUG:  ', '*'*30
                                print >>sys.stderr, 'DEBUG:   Filename:            ', fileinput.filename()
                                print >>sys.stderr, 'DEBUG:   Line Number:         ', fileinput.lineno()
                                print >>sys.stderr, 'DEBUG:   Exception:           ', exc[0]
                                print >>sys.stderr, 'DEBUG:   Exception:           ', exc[1]
                                print >>sys.stderr, 'DEBUG:   Dict Contents:       '
                                output_debug_dict(d)
                                print >>sys.stderr, 'DEBUG:   ', buf_debug
                                print >>sys.stderr, 'DEBUG:   ', line
                                print >>sys.stderr, 'DEBUG:  ', '*'*30
                            else:
                                print >>sys.stderr, 'ERROR: ', line
            except:
                print >>sys.stderr, 'ERROR: ', inputline

        if format_file:
            col_fmt = get_output_cols(format_file)
        if output:
            if not all_data:
                print_header(col_fmt,done_master)
            output_data(done_master, col_fmt)
            if show_active:
                output_data(active_master, col_fmt)
            if show_all:
                output_data(active_master, col_fmt)
                output_data(queued_master, col_fmt)
                output_data(requeued_master, col_fmt)
        if shelve_dicts:
            fp_output = open(pkl, 'wb')
            cPickle.dump(done_master,fp_output,1)
            fp_output.close()

    except KeyboardInterrupt:   # Catch premature ^C
        traceback.print_tb(sys.exc_traceback)
        sys.exit(3)

# modeline vim:set ts=4 sw=4 et:
