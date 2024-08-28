#!/bin/env python
'''
This script will collect all BUR logs and creates tar.gz files from them.
LITP_EXPORT_FILE does not exist before the backup has been run so this
script will fail if it is executed before any backup
'''
import getpass
import sys
import os
import shutil
import time
import subprocess
import pexpect
import json
import datetime
from optparse import OptionParser


sys.path.insert(0, "/opt/ericsson/itpf/bur/lib/")
# from bur_model.api import BUR_MODEL
from bur_model.api import BUR_MODEL, Cluster
from bos.SFSService import SFSService

#List of files to collect
files_list = '"/opt/ericsson/itpf/bur/log/ /opt/ericsson/itpf/bur/data/measurement_backup_FilesystemThroughput.data /opt/ericsson/itpf/bur/data/measurement_restore_FilesystemThroughput.data"'
#Store SFS hostnames for scp filtering
SFS_HOST = []

BACKUPFILE = "measurement_backup_FilesystemThroughput.data"
RESTOREFILE = "measurement_restore_FilesystemThroughput.data"

if os.path.exists("/opt/ericsson/itpf/bur/data/litp2inventory.xml"):
    LITP_EXPORT_FILE = "/opt/ericsson/itpf/bur/data/litp2inventory.xml"
else:
    print "Can't fine LITP_EXPORT_FILE. Make sure backup is done before running this script"
    sys.exit(1)

class CollectLogs(object):
    DURATION = 0
    DATA = 0

    def get_user(self):
        ''' This will get the currwent username
        Return: String with current username in it
        '''
        current_user = getpass.getuser()
        return current_user


    def create_dirs(self):
        '''
        This will create temporary directories to store log files.
        Return: Nothing
        '''
        tmp_dir = "/tmp/burlogs"
        if os.path.exists(tmp_dir):
            print "Removing existing folder"
            print "Creating temporary directory to store files. " + tmp_dir
            shutil.rmtree(tmp_dir)
            os.makedirs(tmp_dir)
        else:
            print "Creating temporary directory to store files. " + tmp_dir
            os.makedirs(tmp_dir)


    def get_hosts(self):
        '''
        This will get all the hosts from litp model
        Return: list of hosts
        '''
        hosts = {}
        #Loop hosts from litp model
        bur_node_list = BUR_MODEL.get_all_nodes()
        for bur_node in bur_node_list:
            if bur_node.get_cluster_type() == Cluster.TYPE_SFS:
                for phys_node in bur_node.get_sfs_physical_nodes():
                    hosts[phys_node.get_hostname()] = phys_node.get_ip_address()
                    SFS_HOST.append(phys_node.get_hostname())
            else: hosts[bur_node.get_node_name()] = bur_node.get_ip_address()
        return hosts

    def collect_logs(self,type):
        '''
        This will create a directory for each node under tmp_dir and collects the logs
        Return: Nothing. Just creates the tar.gz files from collected logs
        '''
        tmp_dir = "/tmp/burlogs"
        print "Log collection starting..."
        nodes = self.get_hosts()
        for key,val in nodes.iteritems():
                print "Processing node: " + key
                _dir = tmp_dir + "/" + key + "/"
                os.makedirs(_dir)
                if key in SFS_HOST:
                    self.scp_files_sfs(val, files_list, _dir)
                else:
                    self.scp_files(val, files_list, _dir)

        #put if clause here if stats are wanted
        if type == "backup":
            print "Printing backup statistics"
            for key, val in nodes.iteritems():
                _dir = tmp_dir + "/" + key + "/"
                if key in SFS_HOST:
                    _file = _dir + BACKUPFILE
                    time.sleep(1)
                    self.printStats(_file, key)
                else:
                    _file = _dir + BACKUPFILE
                    time.sleep(1)
                    self.printStats(_file, key)
        if type == "restore":
            print "Printing restore statistics"
            for key, val in nodes.iteritems():
                _dir = tmp_dir + "/" + key + "/"
                if key in SFS_HOST:
                    _file = _dir + RESTOREFILE
                    time.sleep(1)
                    self.printStats(_file, key)
                else:
                    _file = _dir + RESTOREFILE
                    time.sleep(1)
                    self.printStats(_file, key)

        #make a tar gzip file
        _date = time.strftime("%d%m%Y")
        _file = '/tmp/bur_logs_'+_date+'.tar.gz'
        command = 'tar cfz ' + _file + " " + tmp_dir
        p = subprocess.Popen([command], shell=True)

        print "logs can be found from %s and tar.gz file from %s" %(tmp_dir, _file)


    def scp_files(self, host, files_list, destination):
        '''
        This will use scp to collect logs from the host provided as parameter
        Return: Nothing
        '''
        command = 'scp -r -q brsadm@'+host+":"+files_list+" "+destination
        p = subprocess.Popen([command], shell=True)

    def scp_files_sfs(self, host, files_list, destination):
        '''
        This will use scp as support user to collect logs from SFS physical hosts
        Return: Nothing
        '''
        _pass = "symantec"
        command = 'scp -r -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null support@' + host + ":" + files_list + " " + destination

        try:
            child = pexpect.spawn(command)
            i = child.expect(["Password:", pexpect.EOF])

            if i == 0:  # send password
                child.sendline(_pass)
                child.expect(pexpect.EOF)
            elif i == 1:
                print "Got the key or connection timeout"
                pass
        except Exception as e:
            print "Oops Something went wrong buddy"
            print e

    def printStats(self, file, host):
        '''
        :param file: This will be the backupfile or restorefile
        :return: Nothing. Prints the stats
        '''
        try:
            jsonfile = json.loads(open(file).read())

            print '%-30s %-30s' %('HOSTNAME:',host)
            for rows in jsonfile['fss']:
                print '%-30s %-100s' %('Mount Point:', rows['backup_mount_point'])
                print '%-30s %-100s' %('Duration:', self.calcDuration(rows['start_time'], rows['end_time']))
                print '%-30s %-100s' %('File System Size (MB):', str(rows['filesystem_size']))
                print '%-30s %-100s' %('File System Used (MB):', str(rows['filesystem_used_size']))
                print '%-30s %-100s' %('Throughput:', str(rows['throughput']))
                self.DATA += rows['filesystem_used_size']
                print '\n'

            print '%-30s %-100s' %('TOTAL DURATION:', str(datetime.timedelta(seconds=collector.DURATION)))
            print '%-30s %-100s' %('TOTAL DATA (MB):',str(collector.DATA))
            print "================================\n"
            collector.DATA = 0
            collector.DURATION = 0
        except:
            print "There was problems to load input file: " + file + " for host " + host

    def calcDuration(self, starttime, endtime):
        '''
        :param starttime: time when the backup/restore has started
        :param endtime:  time when the backup/restore has finnished
        :return:
        '''
        _starttime = sum(int(x) * 60 ** i for i, x in enumerate(reversed(starttime.split(":"))))
        _stoptime = sum(int(x) * 60 ** i for i, x in enumerate(reversed(endtime.split(":"))))

        #Incase the backup went over midnight
        if _stoptime < _starttime:
            secs = (84600 - _starttime + _stoptime)
            if secs > self.DURATION:
                self.DURATION = secs
            return str(datetime.timedelta(seconds=secs))
        else:
            secs = (_stoptime - _starttime)
            if secs > self.DURATION:
                self.DURATION = secs
            return str(datetime.timedelta(seconds=secs))

    def main(self):

        if collector.get_user() != "brsadm":
            print "Only brsadm user can run this script."
            sys.exit(1)

        BUR_MODEL.parse_model(LITP_EXPORT_FILE)
        BUR_MODEL.set_sfs_node_loader(SFSService)
        collector.create_dirs()

        parser = OptionParser()
        parser.add_option('-t', action='store')

        (options, args) = parser.parse_args()
        if options.t == "backup":
            collector.collect_logs("backup")

        if options.t == "restore":
            collector.collect_logs("restore")



# === MAIN ===#
if __name__ == "__main__":
    collector = CollectLogs()
    collector.main()