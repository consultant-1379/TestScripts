import json
import logging
import requests
import paramiko
import re

from logging.handlers import RotatingFileHandler

credentials = {'431': '12shroot', '429': '60Kserver', '435': 'Zenas4', '436': '60Kserver', '623': '60Kserver',
               '660': '12shroot', '690': '60Kserver', '656' : '12shroot', 'c15a003': 'CENM_eccd', '625': '12shroot',
               '679': '12shroot'}


def get_logger():
    log = logging.getLogger(__name__)
    log.setLevel(logging.DEBUG)
    return log


def init_log_config():
    log = logging.getLogger(__name__)
    log.setLevel(logging.DEBUG)

    formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(name)s - %(message)s')

    fh = RotatingFileHandler(__name__ + '.log', maxBytes=100000000, backupCount=5)
    fh.setLevel(logging.DEBUG)
    fh.setFormatter(formatter)
    fh.flush()
    log.addHandler(fh)

    ch = logging.StreamHandler()
    ch.setLevel(logging.INFO)
    ch.setFormatter(formatter)
    ch.flush()
    log.addHandler(ch)
    # return log


init_log_config()


class Deployment:
    def __init__(self, deployment_id):
        self.log = get_logger()
        self.log.info('Welcome to Deployment {}!'.format(deployment_id))
        self.deployment_id = deployment_id
        self.lms_ip_address = self.lookup_lms_ip_address()
        if not self.lms_ip_address:
            self.log.error('No LMS ip address detected!')
            exit(1)
        self.haproxy_address = "Not defined"
        if self.deployment_id != "656" and self.deployment_id != "c15a003" and self.deployment_id != "625":
            self.haproxy_address = self.lookup_haproxy_address()
            if not self.haproxy_address:
                self.log.error('No haproxy name resolved!')
                exit(1)
        self.workload_address = self.lookup_workload_address()
        if not self.workload_address:
            self.log.error('No workload ip address detected')
            exit(1)
        self.log.info('Deployment is initialized with id {}, LMS ip address {}, haproxy {} , workload {}'.format(
            self.deployment_id, self.lms_ip_address, self.haproxy_address, self.workload_address))

    def __str__(self):
        return self.deployment_id

    def lookup_lms_ip_address(self):
        dep_id = self.deployment_id
        if dep_id == "c15a003": #cloud doesn't use its cENM name but rather its cluster name here - 884
            dep_id = "870"

        if dep_id == "656":
            return "131.160.156.91"
        elif dep_id == "625":
            return "10.210.252.8"

        url = "https://ci-portal.seli.wh.rnd.internal.ericsson.com/generateTAFHostPropertiesJSON/?clusterId={}&tunnel=true".format(
            dep_id)
        try:
            response = requests.get(url)
        except requests.exceptions.RequestException as error:
            self.log.error('Get {} request failed with error:'.format(url))
            self.log.error(error)
            return None
        try:
            json_response = json.loads(response.content)
            return json_response[0]['ip']
        except ValueError as json_error:
            self.log.error('JSON decoding has failed: \n {}'.format(json_error))
            return None

    def lookup_haproxy_address(self):
        try:
            stdout_lines, stderr_lines = self.execute_command_on_lms("getent hosts haproxy | awk '{print $3}'")
            return stdout_lines[0].split()[0]
        except ValueError as error_ex:
            self.log.error('Failed to getent haproxy on LMS')
            return None

    def lookup_workload_address(self):
        if self.deployment_id == "c15a003":
            return "ieatwlvm12349"
        elif self.deployment_id == "656":
            return "ieatwlvm12443"
        elif self.deployment_id == "625":
            return "ieatwlvm12469"

        try:
            stdout_lines, stderr_lines = self.execute_command_on_lms(
                "cat /root/.bashrc | grep 'WORKLOAD_VM=' | awk -F '=' '{print $2}'")

            wlvm = stdout_lines[0].split()[0]
            if self.deployment_id != '679':
                return wlvm

            result = re.search('\"(.*).athtem.eei.ericsson.se\"', wlvm)
            return result.group(1).split()[0]
        except ValueError as error_ex:
            self.log.error('Failed to get workload address on LMS')
            return None

    def get_haproxy_address(self):
        return self.haproxy_address

    def get_lms_ip_address(self):
        return self.lms_ip_address

    def get_deployment_id(self):
        return self.deployment_id

    def add_user(self, username, password, type_of_server_access):
        result = False
        if self.deployment_id != '656' and self.deployment_id != 'c15a003' and self.deployment_id != '625':
            if self.create_user_on_lms_of_deployment(username, password, type_of_server_access):
                result = True
            if self.create_user_on_enm(username, password):
                result = True
        if self.create_user_on_workload_of_deployment(username, password, type_of_server_access):
            result = True
        return result

    def del_user(self, username):
        result = False
        if self.deployment_id != '656' and self.deployment_id != 'c15a003' and self.deployment_id != '625':
            if self.delete_user_on_lms_of_deployment(username):
                result = True
            if self.delete_user_on_enm(username):
                result = True
        if self.delete_user_on_workload_of_deployment(username):
            result = True
        return result
        # For now return True
        # return result

    def create_user_on_lms_of_deployment(self, username, password, type_of_server_access):
        if type_of_server_access == 'Exclusive' or 'Exclusive' in type_of_server_access:
            user_group = 'privileged_testers'
        else:
            user_group = 'testers'
        user_creation_command = "useradd -g {2} -m {0} && echo {1} | passwd --stdin {0}".format(username, password,
                                                                                                user_group)
        stdout_lines, stderr_lines = self.execute_command_on_lms(user_creation_command)
        if stderr_lines:
            self.log.error('Command "{}" produced error output'.format(user_creation_command))
            self.log.error(stderr_lines)
            return False
        else:
            self.log.info('LMS user {} has been created successfully'.format(username))
        return True

    def delete_user_on_lms_of_deployment(self, username):
        user_deletion_command = "pkill -9 -U {0}; userdel -r {0}".format(username)
        stdout_lines, stderr_lines = self.execute_command_on_lms(user_deletion_command)
        if stderr_lines:
            self.log.error('Command "{}" produced error output'.format(user_deletion_command))
            self.log.error(stderr_lines)
            return False
        else:
            self.log.info(
                'LMS user {} has been deleted successfully'.format(username))
        return True

    def create_user_on_workload_of_deployment(self, username, password, type_of_server_access):
        if type_of_server_access == 'Exclusive' or 'Exclusive' in type_of_server_access:
            user_group = 'privileged_testers'
        else:
            user_group = 'testers'

        if self.deployment_id == '679' or self.deployment_id == '625':
            user_creation_command = 'ssh root@{3} "useradd -g {2} -m {0} && echo {1} | passwd --stdin {0}"'.format(
                username, password, user_group, self.workload_address)
        else:
            user_creation_command = 'sshpass -p S4_W0rkl0ad ssh -q -t {3} "useradd -g {2} -m {0} && echo {1} | passwd --stdin {0}"'.format(
                username, password, user_group, self.workload_address)

        stdout_lines, stderr_lines = self.execute_command_on_lms(user_creation_command)
        self.log.info('Workload user {} has been created successfully'.format(username))
        return True

    def delete_user_on_workload_of_deployment(self, username):
        if self.deployment_id == '679' or self.deployment_id == '625':
            user_deletion_command = 'ssh root@{1} "pkill -9 -U {0}; userdel -r {0}"'.format(
                username, self.workload_address)
        else:
            user_deletion_command = 'sshpass -p S4_W0rkl0ad ssh -q -t {1} "pkill -9 -U {0}; userdel -r {0}"'.format(
                username, self.workload_address)
        stdout_lines, stderr_lines = self.execute_command_on_lms(user_deletion_command)
        self.log.info('Workload user {} has been deleted successfully'.format(username))
        return True

    def list_users_on_lms_of_deployment(self):
        list_users_command = "lslogins --output=USER | grep DETS"
        stdout_lines, stderr_lines = self.execute_command_on_lms(list_users_command)
        if stderr_lines:
            self.log.error('Command "{}" produced error output'.format(list_users_command))
            self.log.error(stderr_lines)
            return None
        users = [line.rstrip('\n') for line in stdout_lines]
        return users

    def change_user_access(self, username, type_of_server_access):
        if type_of_server_access == 'Exclusive':
            user_group = 'privileged_testers'
        else:
            user_group = 'testers'
        user_modification_command = "usermod -g {0} {1}".format(user_group, username)
        stdout_lines, stderr_lines = self.execute_command_on_lms(user_modification_command)
        if stderr_lines:
            self.log.error('Command "{0}" produced error output'.format(user_modification_command))
            self.log.error(stderr_lines)
        #user_access = "usermod -aG wheel {0}".format(username)
        #stdout_lines, stderr_lines = self.execute_command_on_lms(user_access)
        #if stderr_lines:
        #    self.log.error('Command "{0}" produced error output'.format(user_access))
        #    self.log.error(stderr_lines)
        #    return False
        return True

    def create_user_on_enm(self, username, password):
        result = True
        enm_user_creation_command = "/opt/ericsson/enmutils/bin/user_mgr create {0} {1} ADMINISTRATOR,SECURITY_ADMIN".format(
            username, password)
        stdout_lines, stderr_lines = self.execute_command_on_lms(enm_user_creation_command)
        if stderr_lines:
            self.log.error('Command "{}" produced error output'.format(enm_user_creation_command))
            self.log.error(stderr_lines)
            result = False
        #user_access = "usermod -aG wheel {}".format(username)
        #stdout_lines, stderr_lines = self.execute_command_on_lms(user_access)
        #if stderr_lines:
        #    self.log.error('Command "{}" produced error output'.format(user_access))
        #    self.log.error(stderr_lines)
        #    result = False
        #else:
        self.log.info('ENM user {} has been created successfully'.format(username))
        return result

    def delete_user_on_enm(self, username):
        result = True
        enm_user_deletion_command = "/opt/ericsson/enmutils/bin/user_mgr delete {0}".format(username)
        stdout_lines, stderr_lines = self.execute_command_on_lms(enm_user_deletion_command)
        if stderr_lines:
            self.log.error('Command "{}" produced error output'.format(enm_user_deletion_command))
            self.log.error(stderr_lines)
            result = False
        else:
            self.log.info('ENM user {} has been deleted successfully'.format(username))
        return result

    def execute_command_on_lms(self, command):
        ssh = self.create_ssh_connection_to_deployment()
        ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(command)
        stdout_lines = ssh_stdout.readlines()
        stderr_lines = ssh_stderr.readlines()
        ssh.close()
        return stdout_lines, stderr_lines

    def create_ssh_connection_to_deployment(self):
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        # root_password = credentials.get(self.deployment_id)
        ssh.connect(self.lms_ip_address, username='root', password='12shroot')
        return ssh
