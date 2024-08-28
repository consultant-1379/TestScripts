#!/usr/bin/env python
import os
import sys
import paramiko
def help1():
    print("Pass correct number of arguments ./<pgm name> <deployment number> <workload vm name>")
    print("Example: ./cloud.py 5653 ieatwlvm7071")
if len(sys.argv) < 3:
    print("Error")
    help1()
    exit()
deployment_name=sys.argv[1]
wlvm=sys.argv[2]
f = open(".bashrc", "a")
f.write("#RVB:VAR - TERMINAL MODIFICATIONS")
f.write('\nexport HISTTIMEFORMAT="%h/%d - %H:%M:%S "')
f.write("\n#RVB:VAR - Changes prompt to include timestamp: e.g: [14:49:06 root@ieatlms5218:~ ]#")
f.write('\nPS1="[\\t \u@\h:\W ]# "')
f.write("\n#RVB:VAR - Updates PROMPT_COMMAND with history -a so that all commands ran as root update ~/.bash_history file")
f.write("\nPROMPT_COMMAND='history -a'")
f.write("\n#RVB:VAR - Modifies $PATH to include bin directories from enminst,enmutils and root/rvb for lazy invocation")
f.write("\nPATH=${PATH}:/opt/ericsson/enmutils/bin:/opt/ericsson/enminst/bin:/root/rvb/bin")
f.write("\nexport WORKLOAD_VM="+wlvm+".athtem.eei.ericsson.se")
f.write("\nalias connect_to_vm='ssh -o StrictHostKeyChecking=no root@$WORKLOAD_VM'")
f.write("\nalias sshvm='ssh -i /var/tmp/key_pair_vio_"+deployment_name+".pem'")
f.close()

#open and read the file after the appending:
f = open(".bashrc", "r")
print(f.read())
os.system('ssh-keygen -f /root/.ssh/id_rsa -N ""')
ssh = paramiko.SSHClient()
#bypass the yes/no reuirement while logging in
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname=wlvm+".athtem.eei.ericsson.se",username="root",password="12shroot")
ftp_client=ssh.open_sftp()
ftp_client.put("/root/.ssh/id_rsa.pub","/root/ms.pubkey")
ftp_client.close()
ssh.exec_command('cat /root/ms.pubkey>> /root/.ssh/authorized_keys')
os.system('export WORKLOAD_VM="'+wlvm+'.athtem.eei.ericsson.se"')
os.system("alias connect_to_vm='ssh -o StrictHostKeyChecking=no $WORKLOAD_VM'")
os.system("source ~/.bashrc")
#os.system("connect_to_vm")
print("Connect to vm setup done for root user")

