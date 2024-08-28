#!/usr/bin/python
import sys
import re
import os
import commands
__author__ = 'ejordba'

 # TODO Document functions

ENMUTILS_PATH   = '/opt/ericsson/enmutils/bin/'
ENMINST_PATH    = '/opt/ericsson/enminst/bin/'
SED_PATH        = '/bin/sed'

ENM_RELEASE_PATH            = '/etc/enm-history'
ENM_VERSION_HISTORY_PATH    = '/etc/enm-history'
LITP_RELEASE_PATH           = '/etc/litp-release'
LITP_VERSION_HISTORY_PATH   = '/etc/litp-history'


def run_shell_command(command, accepted_exit_codes=[0]):
    (rc, stdout) = commands.getstatusoutput(command)
    response_codes_accepted = [0] + accepted_exit_codes
    if rc not in response_codes_accepted:
        # TODO: use more appropiate try/except and logging
        print 'Shell command \'' + command + '\' returned a non zero exit code! (' + str(rc) + '), exiting execution!'
        sys.exit(rc)
    else:
        return [line for line in stdout.split('\n')]


def disable_colour_encoding():
    disable_command = 'sed -i -- \'s/print_color = true/print_color = false/g\' /opt/ericsson/enmutils/etc/properties.conf'
    (rc, stdout) = commands.getstatusoutput(disable_command)


def strip_ascii_encodings(user_string):
    # Unix equivalent: sed s/\x1B\[[0-9;]*[JKmsu]//g
    return re.sub(r'\x1B\[[0-9;]*[JKmsu]', '', user_string)


def get_enm_version_history():
    if os.path.isfile(ENM_VERSION_HISTORY_PATH):
        with open(ENM_VERSION_HISTORY_PATH, 'r') as enm_version_file:
            file_contents = []
            for line in enm_version_file:
                file_contents.append(line.strip('\n'))
            return file_contents
    else:
        raise IOError('File: ' + ENM_VERSION_HISTORY_PATH + ' not found on file system!')


def get_litp_version_history():
    litp_info_source = ''

    if os.path.isfile(LITP_VERSION_HISTORY_PATH):
        litp_info_source = LITP_VERSION_HISTORY_PATH
    elif os.path.isfile(LITP_RELEASE_PATH):
        litp_info_source = LITP_RELEASE_PATH
    else:
        raise IOError('Could not find a litp version or release file in /etc/ !')

    with open(litp_info_source, 'r') as litp_file:
            file_contents = []
            for line in litp_file:
                file_contents.append(line.strip('\n'))
            return file_contents

# TODO covert this to dictionary object returned
def get_sync_network_status():
    get_sync_status_cmd = ENMUTILS_PATH + 'network sync-status | grep NODES'
    shell_output = run_shell_command(get_sync_status_cmd)
    network_status = {}
    for line in shell_output:
        line = strip_ascii_encodings(line.strip(' \t').replace('\t', '').replace('NODES ', '').replace(' ', ''))
        network_status[line.split(':')[0]] = line.split(':')[1]

    return network_status


def get_workload_status():
    workload_status = {}
    get_status_of_workload_cmd = ENMUTILS_PATH + 'workload status'
    shell_output = run_shell_command(get_status_of_workload_cmd, [256])
    shell_output = shell_output[2:]
    output_list = []
    for line in shell_output:
        formatted_line = strip_ascii_encodings(line)
        formatted_line = re.sub("\t", " ", re.sub("\s\s+", "%%", formatted_line))
        output_list.append(formatted_line)
        details = formatted_line.strip('%%').split('%%')
        # crude check to make sure it's a line containing the profile and not the errors running onto the next line
        # TODO Improve this
        if len(details) < 6:
            pass
        else:
                profile_name = details[0]
                profile_name            = details[0]
                profile                 = {}
                profile['start time']   = details[1]
                profile['status']       = details[3]
                profile['result']       = details[4]
                profile['nodes']        = details[5]
                workload_status[profile_name] = profile
    return workload_status



if __name__ == '__main__':
    disable_colour_encoding()
    network_state = get_sync_network_status()
    workload_state = get_workload_status()
    enm_upgrade_history = get_enm_version_history()
    litp_history = get_litp_version_history()
    print litp_history

