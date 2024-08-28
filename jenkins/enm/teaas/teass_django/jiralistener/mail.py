import smtplib
import time
import os
from email.mime.text import MIMEText


class Mail:
    def __init__(self, issue, deployment):
        self.support_mail = "oisin.murphy@ericsson.com"
        self.deployment = deployment
        self.deployment_id = issue.get_deployment_id()
        self.issue_reporter_name = issue.get_reporter_name()
        self.issue_key = issue.get_key()
        self.sender = "oisin.murphy@ericsson.com"
        self.jira_url = "https://jira-oss.seli.wh.rnd.internal.ericsson.com/browse/{}".format(self.issue_key)
        self.sudo_url = "https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/4/html/Security_Guide/s3-wstation-privileges-limitroot-sudo.html"
        component = issue.get_component(0)
        ignorable = self.check_pENM_team_ticket(component)
        print "pENM team ticket? {0}".format(ignorable)
        if not ignorable:
            self.to = [issue.get_reporter_email_address(), issue.get_assignee_email_address()]
            self.to_in_case_of_failure = [issue.get_assignee_email_address(), self.support_mail]
            self.issue_assignee_name = issue.get_assignee_name()
            if self.deployment_id == "c15a003":
                self.workloadVM = "{}@ieatwlvm12349".format(self.issue_key)
                self.ssh_hyperlink = "eccd@10.150.141.12 (CENM_eccd) and then from /home/eccd directory run this command to get onto c15a003 cluster <br/>-> ssh -i c15a003.pem eccd@10.150.137.189"
                self.dmt_url = "https://ci-portal.seli.wh.rnd.internal.ericsson.com/dmt/clusters/870/"
                self.ddp_url = "https://ddpenm6.athtem.eei.ericsson.se/php/index.php?site=LMI_ieatenmc15a003_enm15a3&oss=tor"
                self.enm_gui_url = "<br/>"
            elif self.deployment_id == "656":
                self.workloadVM = "{}@ieatwlvm12443".format(self.issue_key)
                self.ssh_hyperlink = "root@131.160.156.91 (shroot12)"
                self.ddp_url = "https://ddpenm2.athtem.eei.ericsson.se/php/index.php?site=LMI_vio-5656&oss=tor"
                self.dmt_url = "https://ci-portal.seli.wh.rnd.internal.ericsson.com/dmt/clusters/656"
                self.enm_gui_url = "<br/>"
            elif self.deployment_id == "625":
                self.workloadVM = "{}@ieatwlvm12469".format(self.issue_key)
                self.ssh_hyperlink = "root@10.210.252.8 (12shroot)"
                self.ddp_url = "https://ddpenm2.athtem.eei.ericsson.se/php/index.php?site=LMI_vio-5625&oss=tor"
                self.dmt_url = "https://ci-portal.seli.wh.rnd.internal.ericsson.com/dmt/clusters/625"
                self.enm_gui_url = "<br/>"
            else:
                self.workloadVM = "{}@{}".format(self.issue_key, deployment.lookup_workload_address())
                self.ssh_hyperlink = "{}@{}".format(self.issue_key, deployment.get_lms_ip_address())
                self.ddp_url = "https://ddpenm3.athtem.eei.ericsson.se/php/index.php?site=LMI_ENM{}&oss=tor".format(deployment)
                self.dmt_url = "https://ci-portal.seli.wh.rnd.internal.ericsson.com/dmt/clusters/{}".format(deployment)
                self.enm_gui_url = "<a href='https://{}'>ENM GUI</a><br>".format(deployment.get_haproxy_address())

    def check_pENM_team_ticket(self, component):
        matchables = ['ENM Test Environment Physical Support', 'Orchestration Install', 'Orchestration Firmware', 'ENM Test Environment Physical ChangeMgt', 'ENM Rack Environment Rollout', 'GEN8toGEN10Migration', 'HWchanges', 'GEN10hwReplacementNASinstall', 'ENM Test Environment pENM Firmware UG']
        if component in matchables:
            return True
        return False

    def send_user_creation_email(self, dep_id, password):
        print "Deployment email created for: " + dep_id
        if dep_id == "656" or dep_id == "c15a003":
            self.send_656_cloud_user(password)
        else:
            self.send_pENM_user(password)

    def get_mail_template(self, cf):
        path = "mail_templates/" + cf
        script_dir = os.path.dirname(__file__)
        c = open(os.path.join(script_dir, path), 'r')
        template = c.read()
        c.close()
        return template


    def send_pENM_user(self, password):
        try:
            html = self.get_mail_template("mail_creation_template.html")
            mailf = html.format(self.issue_reporter_name,
                                self.jira_url,
                                self.dmt_url,
                                self.issue_key,
                                self.deployment_id,
                                self.deployment.get_lms_ip_address(),
                                password,
                                self.ssh_hyperlink,
                                self.enm_gui_url,
                                self.sudo_url,
                                self.ddp_url,
                                self.issue_assignee_name,
                                self.workloadVM)
        except ValueError:
            print "issue with email creation"
            print mailf
        subject = "{}: Access to deployment {}".format(self.issue_key, self.deployment)
        self.send_mail(self.sender, self.to, subject, mailf)

    def send_656_cloud_user(self, password):
        try:
            html = self.get_mail_template("mail_vio_cenm_creation_template.html")
            mailf = html.format(self.issue_reporter_name,
                               self.jira_url,
                               self.dmt_url,
                               self.issue_key,
                               self.deployment_id,
                               self.deployment.get_lms_ip_address(),
                               password,
                               self.ssh_hyperlink,
                               self.enm_gui_url,
                               self.sudo_url,
                               self.ddp_url,
                               self.issue_assignee_name,
                               self.workloadVM)
        except ValueError:
            print "issue with email creation"
            print mailf
        subject = "{}: Access to deployment {}".format(self.issue_key, self.deployment)
        self.send_mail(self.sender, self.to, subject, mailf)

    def send_user_deletion_email(self):
        try:
            html = self.get_mail_template("mail_deletion_template.html")
            mailf = html.format(self.issue_reporter_name,
                                           self.jira_url,
                                           self.issue_key,
                                           self.deployment_id,
                                           self.issue_assignee_name)
        except ValueError:
            print "issue with email creation"
            print mailf
        subject = "{}: Access revoked on deployment {}".format(self.issue_key, self.deployment)
        self.send_mail(self.sender, self.to, subject, mailf)

    def send_user_creation_failure_mail(self):
        self.send_failure_mail("creation")

    def send_user_deletion_failure_mail(self):
        self.send_failure_mail("deletion")

    def send_failure_mail(self, creation_deletion):
        try:
            html = self.get_mail_template("mail_failure_template.html")
            mailf = html.format(self.issue_assignee_name,
                                           self.jira_url,
                                           self.issue_key,
                                           self.deployment_id,
                                           creation_deletion)
        except ValueError:
            print "issue with email creation"
            print mailf
        subject = "{}: User {} FAILURE on {}".format(self.issue_key, creation_deletion, self.deployment)
        self.send_mail(self.sender, self.to_in_case_of_failure, subject, mailf)

    def send_issue_approved_mail(self, issue):
        try:
            html = self.get_mail_template("mail_approval_template.html")
            mailf = html.format(self.jira_url,
                           self.issue_key,
                           self.deployment_id,
                           issue.get_team_loc())
        except ValueError:
            print "issue with email creation"
            print mailf
        subject = "Ticket {} has been Approved".format(self.issue_key)
        self.send_mail(self.sender, ["PDLTEAMGRI@pdl.internal.ericsson.com"], subject, mailf)

    def send_issue_resolved_mail(self, issue):
        try:
            html = self.get_mail_template("mail_resolved_template.html")
            mailf = html.format(self.jira_url,
                                self.issue_key,
                                self.deployment_id)
            recipient = str(issue.get_assignee_email_address())
        except ValueError:
            print "issue with email creation"
            print mailf
        subject = "Black RPMs to be removed for {}".format(self.issue_key)
        self.send_mail(self.sender, [recipient], subject, mailf)

    def send_new_pENM_task_mail(self, issue):
        try:
            html = self.get_mail_template("mail_new_penm_task_template.html")
            mailf = html.format(self.issue_key)
        except ValueError:
            print "issue with email creation"
            print mailf
        subject = "New Task ticket created - {}".format(self.issue_key)
        print "sending new task mail"
        self.send_mail(self.sender, ["PDLTEAMGRI@pdl.internal.ericsson.com"], subject, mailf)

    def send_new_pENM_support_mail(self, issue):
        try:
            html = self.get_mail_template("mail_penm_support_template.html")
            mailf = html.format(self.issue_key)
        except ValueError:
            print "issue with email creation"
            print mailf
        subject = "New pENM Support ticket created - {}".format(self.issue_key)
        self.send_mail(self.sender, ["PDLTEAMGRI@pdl.internal.ericsson.com"], subject, mailf)

    def send_mail(self, sender, recipient_list, subject, message):
        msg = MIMEText(message, 'html')
        msg['Subject'] = subject
        msg['From'] = "jiralistener@ericsson.com"
        msg['To'] = ", ".join(recipient_list)
        try:
            s = smtplib.SMTP("smtp-central.internal.ericsson.com", 25)
            print "sending mail..."
            s.sendmail(sender, recipient_list, msg.as_string())
            time.sleep(5)
#            for r in recipient_list:
#                os.system(
#                    'echo \'{"parameter": [{"name":"email_address", "value": "' + r + '" },{"name":"email_subject", "value": "' + subject + '"}, {"name":"email_content","value":"' + "".join(
#                        str(message).splitlines()) + '"}]}\' > /root/TestScripts/jenkins/enm/teaas/teass_django/jiralistener/log.txt')
                # os.system("echo 'HELLLLOOOOO' > /root/TestScripts/jenkins/enm/teaas/teass_django/jiralistener/log.txt")
#                os.system(
#                    'curl -s -X POST https://fem8s11-eiffel004.eiffel.gic.ericsson.se:8443/jenkins/view/S4/job/S4JLemailNonEricsson/build --data-urlencode json=\'{"parameter": [{"name":"email_address", "value": "' + r + '" },{"name":"email_subject", "value": "' + subject + '"}, {"name":"email_content","value":"' + "".join(
#                        str(message).splitlines()) + '"}]}\'')
        except Exception as e:
            # Print any error messages to stdout
            s.quit()
            print(e)
            print "Could not send mail..."
            return
        finally:
            print "email sent!"
            s.quit()
