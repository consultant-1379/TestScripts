import smtplib
from email.mime.text import MIMEText
import os

class Mail:
    def __init__(self, issue, deployment):
        self.ercans_email_address = "ercan.ogrady@ericsson.com"
        self.deployment = deployment
        self.issue_reporter_name = issue.get_reporter_name()
        self.to = [issue.get_reporter_email_address(), issue.get_assignee_email_address()]
        self.to_in_case_of_failure = [issue.get_assignee_email_address(), self.ercans_email_address]
        self.issue_assignee_name = issue.get_assignee_name()
        self.sender = "{}@ericsson.com".format(issue.get_assignee_email_address().split("@")[0])
        self.issue_key = issue.get_key()
        self.jira_url = "https://jira-nam.lmera.ericsson.se/browse/{}".format(self.issue_key)
        self.dmt_url = "https://cifwk-oss.lmera.ericsson.se/dmt/clusters/{}/details/".format(deployment)
        self.ddp_url = "https://ddpenm3.athtem.eei.ericsson.se/php/index.php?site=ENM{}".format(deployment)
        self.enm_gui_url = "https://{}".format(deployment.get_haproxy_address())
        self.ssh_hyperlink = "ssh://{}@{}".format(self.issue_key, deployment.get_lms_ip_address())
        self.sudo_url = "https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/4/html/Security_Guide/s3-wstation-privileges-limitroot-sudo.html"

    def send_user_creation_email(self, password):
        html_message_content = '''
                                <html>
                                    <head></head>
                                    <body>
                                        <p>Hi {0},<br><br>
                                           Regarding ticket <a href='{1}'>{3}</a>.<br><br>
                                           A user has been created for you on deployment <a href='{2}'>{4}</a>.<br><br>
                                           Username: <b>{3}</b><br>
                                           Password: <b>{6}</b><br><br>
                                           Credentials are valid for both LMS (<a href='{7}'>{7}</a>) and <a href='{8}'>
                                           ENM GUI</a><br>
                                           The LMS user has
                                           <a href='{9}'>sudo</a>
                                            rights and the ENM user is an administrator.<br>
                                           To SSH to a VM you will need to do <br>
                                           sudo ssh -i /root/.ssh/vm_private_key cloud-user@whatever-vm<br><br>
                                           This user and its home directory <b><em>will be deleted when <a href='{1}'>{3}</a>
                                           moves out of its testing slot</em></b>.<br>
                                           Feel free to change the password.<br><br>
                                           You can view this deployment on <a href='{10}'>DDP</a>.<br><br>
                                           Regards,<br>
                                           {11}
                                        </p>
                                     </body>
                                 </html>
                                '''.format(self.issue_reporter_name,
                                           self.jira_url,
                                           self.dmt_url,
                                           self.issue_key,
                                           self.deployment,
                                           self.deployment.get_lms_ip_address(),
                                           password,
                                           self.ssh_hyperlink,
                                           self.enm_gui_url,
                                           self.sudo_url,
                                           self.ddp_url,
                                           self.issue_assignee_name)
        subject = "{}: Access to deployment {}".format(self.issue_key, self.deployment)
        self.send_mail(self.sender, self.to, subject, html_message_content)

    def send_user_deletion_email(self):
        html_message_content = '''
                                <html>
                                    <head></head>
                                    <body>
                                        <p>Hi {0},<br><br>
                                           Regarding ticket <a href='{1}'>{2}</a>.<br>
                                           This ticket has been moved out of its testing slot.<br><br>
                                           The user {2} has been deleted from deployment {3}.<br>
                                           All processes owned by the user have been killed and the home directory
                                           has been deleted.<br><br>
                                           Regards,<br>
                                           {4}
                                        </p>
                                    </body>
                                </html>
                                '''.format(self.issue_reporter_name,
                                           self.jira_url,
                                           self.issue_key,
                                           self.deployment,
                                           self.issue_assignee_name)
        subject = "{}: Access revoked on deployment {}".format(self.issue_key, self.deployment)
        self.send_mail(self.sender, self.to, subject, html_message_content)

    def send_user_creation_failure_mail(self):
        self.send_failure_mail("creation")

    def send_user_deletion_failure_mail(self):
        self.send_failure_mail("deletion")

    def send_failure_mail(self,creation_deletion):
        html_message_content = '''
                                <html>
                                    <head></head>
                                    <body>
                                        <p>Hi {0},<br><br>
                                           There has been some kind of problem.
                                           There was a failure in {4} of user {2} on deployment {3} for
                                           ticket <a href='{1}'>{2}</a>.<br><br>
                                           Regards,<br>
                                           {0}
                                        </p>
                                    </body>
                                </html>
                                '''.format(self.issue_assignee_name,
                                           self.jira_url,
                                           self.issue_key,
                                           self.deployment,
                                           creation_deletion)
        subject = "{}: User {} FAILURE on {}".format(self.issue_key, creation_deletion, self.deployment)
        self.send_mail(self.sender, self.to_in_case_of_failure, subject, html_message_content)

    def send_issue_approved_mail(self):
        html_message_content = '''
                                <html>
                                    <head></head>
                                    <body>
                                           <a href='{0}'>{1}</a> has transitioned to Approved state.<br><br>
                                        </p>
                                    </body>
                                </html>
                                '''.format(self.jira_url,
                                           self.issue_key)
        subject = "{} is Approved".format(self.issue_key)
        self.send_mail("PDLTEAMGRI@pdl.internal.ericsson.com", ["PDLTEAMGRI@pdl.internal.ericsson.com"], subject, html_message_content)

    def send_mail(self, sender, recipient_list, subject, message):
        msg = MIMEText(message, 'html')
        msg['Subject'] = subject
        msg['From'] = sender
        msg['To'] = ", ".join(recipient_list)
        rec = '","'.join(recipient_list)
        s = smtplib.SMTP('localhost')
        s.sendmail(sender, recipient_list, msg.as_string())
        print 'PLEASE'
        s.quit()
        for r in recipient_list:
            
            os.system('echo \'{"parameter": [{"name":"email_address", "value": "'+r+'" },{"name":"email_subject", "value": "'+subject+'"}, {"name":"email_content","value":"'+"".join(str(message).splitlines())+'"}]}\' > /root/TestScripts/jenkins/enm/teaas/teass_django/jiralistener/log.txt')
        
        #os.system("echo 'HELLLLOOOOO' > /root/TestScripts/jenkins/enm/teaas/teass_django/jiralistener/log.txt")
            os.system('curl -s -X POST https://fem120-eiffel004.lmera.ericsson.se:8443/jenkins/job/S4JLemailNonEricsson/build --user ciexadm200:1dbef125ddea84e9cf0791d2dc83aca6 --data-urlencode json=\'{"parameter": [{"name":"email_address", "value": "'+r+'" },{"name":"email_subject", "value": "'+subject+'"}, {"name":"email_content","value":"'+"".join(str(message).splitlines())+'"}]}\'') 

