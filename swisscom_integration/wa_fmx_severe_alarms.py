#!/usr/bin/python
# 
# Workaround script to check the output of the alarms csv file (Created by a crontab script) and checks for a list of possible severe alarms. 
# If any of these severe alarms are found in the output file an email is sent to the specific address with the alarm type is the subject header 
#
# NOTE that the machine running this must have passwordless access to the MS
#
# Version 1.1

import subprocess
import sys

#EMAIL_RECIPIENT = "systems.operation@swisscom.com"
EMAIL_RECIPIENT = "FaultMgmt-OL.Mobile-Net@swisscom.com"
EMAIL_SENDER = "henmp-admin@swisscom.com"
ALARMS_FILE = "/home/shared/nbicm1/TEST_MOUNT/open_fm_alarms_output.scsv"


ALARM_TYPES_TO_CHECK = ["TemperatureAbnormal", "TemperatureExceptionalTakenOutOfService", "Resource Activation Timeout", "Service Degraded", "ServiceDegraded", "Service Unavailable", "ServiceUnavailable", "HW Fault", "PLMN Service Unavailable", "OperatingTemperatureTooHighCapacityReduced", "SFP Stability Problem", "UnreliableResource", "NumberOfHwEntitiesMismatch", "Suspected Sleeping Cell"]

# The emailer tool is available to use on the MS. Note that the body is mandatory
EMAIL_COMMAND = '/opt/ericsson/enmutils/bin/emailer "{SUBJECT}" "{SENDER}" "{RECIPIENT}" "{EMAIL_BODY}"'
SSH_CMD = "/usr/bin/ssh"

# Empty dummy file to use for the email body
EMAIL_BODY_PATH = "/tmp/fmx_email_body"

def check_for_severe_alarms_in_alarm_csv_and_send_mail_for_each():
	"""
	Reads each line in the alarm output csv file and if one of the "severe" alarms is found sends an email to the specified recipient (i.e. NOC) 
	with the alarm type as the subject. Note that for each severe alarm type found a separate email is sent i.e. one email per alarm

	"""
	# Open and parse the alarms csv file
	lines = None
	with open(ALARMS_FILE, 'r') as alarms_file:
		lines = alarms_file.readlines()
	for line in lines:
            line_as_list = line.split(";")
            if len(line) > 1:
                alarm_state = line_as_list[2]
                # if the alarm is not acknowledged and active
                if alarm_state.lower() == "active_unacknowledged":
                    for alarm in ALARM_TYPES_TO_CHECK:
                            if alarm in line:
                                    line_as_list = line.split(";")
                                    alarm_type = alarm
                                    node_name = line_as_list[4]
                                    email_body = line
                                    subject = "FMX alarm severity: {0} on {1}".format(alarm_type, node_name)
                                    print subject
                                    #_send_email(subject, email_body)

def _send_email(subject, body_text):
	"""
	SSH to the MS (Management Server), create the email body file, and run the emailer tool that is available there passing in the subject string to use.
	"""

	# Create the email body file (this is a mandatory argument for the emailer tool)
	_create_email_body_file(body_text)

	command = EMAIL_COMMAND.format(SUBJECT=subject, SENDER=EMAIL_SENDER, RECIPIENT=EMAIL_RECIPIENT, EMAIL_BODY=EMAIL_BODY_PATH)
	print "Sending email from MS host '{0}' with email command '{1}'\n".format(MS_HOST_IP, command)

	# SSH to the MS and send the email
	ssh = subprocess.Popen(["ssh", "root@{0}".format(MS_HOST_IP), command],
                       shell=False,
                       stdout=subprocess.PIPE,
                       stderr=subprocess.PIPE)

def _create_email_body_file(body_text):
	"""
	Creates the email body file with specific text on the MS for the emailer tool to use. This is a mandatory arg for the emailer tool.
	"""

	# SSH to the MS and create a dummy file
	command = "/bin/echo '{0}' > {1}".format(body_text, EMAIL_BODY_PATH)

	ssh = subprocess.Popen(["ssh", "root@{0}".format(MS_HOST_IP), command],
                       shell=False,
                       stdout=subprocess.PIPE,
                       stderr=subprocess.PIPE)	

def main():
	# The emailer tool on the MS requires a body file so create this once and re-use per email
	check_for_severe_alarms_in_alarm_csv_and_send_mail_for_each()

if __name__ == '__main__':
    main()
