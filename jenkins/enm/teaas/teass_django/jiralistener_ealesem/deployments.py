import json
import requests
import paramiko

credentials = {'431': '12shroot', '429': '60Kserver', '435': 'Zenas4', '436': '60Kserver', '623': '60Kserver', '660': '12shroot', '690': '60Kserver'}

class Deployment:
    def __init__(self,deployment_id):
        self.deployment_id = deployment_id
        self.lms_ip_address = self.lookup_lms_ip_address()
        self.haproxy_address = self.lookup_haproxy_address()
    def __str__(self):
        return self.deployment_id

    def lookup_lms_ip_address(self):
        url = "https://cifwk-oss.lmera.ericsson.se/generateTAFHostPropertiesJSON/?clusterId={}&tunnel=true".format(
            self.deployment_id)
        response = requests.get(url)
        jsonResponse = json.loads(response.content) 
        lms_ip_address = jsonResponse[0]['ip']
        return lms_ip_address

    def lookup_haproxy_address(self):
        stdout_lines, stderr_lines = self.execute_command_on_lms("getent hosts haproxy | awk '{print $3}'")
        return stdout_lines[0].split()[0]

    def get_haproxy_address(self):
        return self.haproxy_address

    def get_lms_ip_address(self):
        return self.lms_ip_address

    def get_deployment_id(self):
        return self.deployment_id

    def add_user(self, username, password, type_of_server_access):
        result = False
        if self.create_user_on_lms_of_deployment(username, password, type_of_server_access):
            result = True
        self.create_user_on_enm(username, password)
        return result

    def del_user(self, username):
        result = False
        if self.delete_user_on_lms_of_deployment(username):
            result = True
        self.delete_user_on_enm(username)
        return result

    def create_user_on_lms_of_deployment(self, username, password, type_of_server_access):
        if type_of_server_access == 'Exclusive':
            user_group = 'privileged_testers'
        else:
            user_group = 'testers'
        user_creation_command = "useradd -g {2} -m {0} && echo {1} | passwd --stdin {0}".format(username, password, user_group)
        stdout_lines, stderr_lines = self.execute_command_on_lms(user_creation_command)
        if stderr_lines:
            return False
        return True

    def delete_user_on_lms_of_deployment(self, username):
        user_deletion_command = "pkill -9 -U {0}; userdel -r {0}".format(username)
        stdout_lines, stderr_lines = self.execute_command_on_lms(user_deletion_command)
        if stderr_lines:
            return False
        return True

    def list_users_on_lms_of_deployment(self):
        list_users_command = "lslogins --output=USER | grep CIP"
        stdout_lines, stderr_lines = self.execute_command_on_lms(list_users_command)
        users = [line.rstrip('\n') for line in stdout_lines]
        return users

    def change_user_access(self, username, type_of_server_access):
        if type_of_server_access == 'Exclusive':
            user_group = 'privileged_testers'
        else:
            user_group = 'testers'
        user_modification_command = "usermod -g {} {}".format(user_group, username)
        
        stdout_lines, stderr_lines = self.execute_command_on_lms(user_modification_command)
        user_access = "usermod -aG wheel {}".format(username)
        self.execute_command_on_lms(user_access)
        if stderr_lines:
            return False
        return True

    def create_user_on_enm(self, username, password):
        enm_user_creation_command = "/opt/ericsson/enmutils/bin/user_mgr create {0} {1} ADMINISTRATOR,SECURITY_ADMIN".format(username,
                                                                                                              password)
        
        self.execute_command_on_lms(enm_user_creation_command)
        user_access = "usermod -aG wheel {}".format(username)
        self.execute_command_on_lms(user_access)

    def delete_user_on_enm(self, username):
        enm_user_deletion_command = "/opt/ericsson/enmutils/bin/user_mgr delete {0}".format(username)
        self.execute_command_on_lms(enm_user_deletion_command)

    def execute_command_on_lms(self, command):
        ssh = self.create_ssh_connection_to_deployment()
        ssh_stdin, ssh_stdout, ssh_stderr = ssh.exec_command(command)
        stdout_lines = ssh_stdout.readlines()
        stderr_lines = ssh_stderr.readlines()
        ssh.close()
        return stdout_lines, stderr_lines

    def create_ssh_connection_to_deployment(self):
        lms_ip_address = self.get_lms_ip_address()
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        root_password = credentials.get(self.deployment_id)
        ssh.connect(lms_ip_address, username='root', password='12shroot')
        return ssh
