

import deployments
import jira_event
import user
import calljenkins
import requests
import os
import mail
import jira
import json

from bs4 import BeautifulSoup

def incoming_event(request):
    event = jira_event.JiraEvent(request)
    issue = event.get_issue()
    issue_key = issue.get_key()
    issue_label = issue.get_label()
    project = issue.get_project()
    component = str(issue.get_component(0))
    pENMtask = pENM_Task_Check(component)

    if issue_label == "TeamGrifoneTest":
        print "Ignoring test Ticket"
        return

    if project == 'DETS':
        if event.get_event_type() == 'updated':
            if not pENMtask:
                #pENM_task_updated(event)
                #comm = get_comment('new_penm_task_comment.txt')
                #issue.add_comment(comm, "S4_Team")
                #else:
                s4_issue_updated(event)
        elif event.get_event_type() == 'created':
            if checkTask(issue_key) and issue.get_type_of_server_access() == "Exclusive weekend":
                print "New ticket created! Access type = " + issue.get_type_of_server_access()
                assign_from_rota(issue)
                #s4_new_ticket_comment(issue)
            elif component == 'ENM Test Environment Physical Support':
                print "New pENM Support Ticket created!"
                print issue.get_deployment_id()
                email = mail.Mail(issue, issue.get_deployment_id())
                email.send_new_pENM_support_mail(issue)
                #comm = get_comment('new_penm_task_comment.txt')
                #issue.add_comment(comm, "S4_Team")
            elif pENMtask:
                print "New pENM Task Ticket created!"
                print issue.get_deployment_id()
                email = mail.Mail(issue, issue.get_deployment_id())
                email.send_new_pENM_task_mail(issue)
                # post comment on ticket
                #comm = get_comment('new_penm_task_comment.txt')
                #issue.add_comment(comm, "S4_Team")
    #elif project == 'PNTC':
    #    s3_issue_updated(event)


def s4_issue_updated(event):
    if event.has_changelog:
        if event.field_has_changed('status'):
            state_change(event)
        elif event.get_issue().get_status() == 'Testing' and event.field_has_changed('environment'):
            deployment_change(event)
        elif event.get_issue().get_status() == 'Testing' and event.field_has_changed('Type of Server Access'):
            type_of_access_change(event)


def s3_issue_updated(event):
    if event.has_changelog:
        if event.field_has_changed('status'):
            if event.status_has_changed_to('Closed'):
                issue = event.get_issue()
                s3_request_feedback(issue)

# customfield_25008 is the planned start date param in jira ticket's JSON structure.
def pENM_task_updated(event):
    if event.has_changelog:
        if event.field_has_changed('Planned Start Date'):
            print(event.get_issue().get_field("Planned Start Date"))
            if event.field_has_changed_from('Planned Start Date', None):
                # Move ticket to 'Planned'
                issue = event.get_issue()
                issue.set_status('Planned')


def pENM_Task_Check(component):
    matches = ['Orchestration Install', 'Orchestration Firmware', 'ENM Test Environment Physical ChangeMgt', 'ENM Rack Environment Rollout', 'GEN8toGEN10Migration', 'HWchanges', 'GEN10hwReplacementNASinstall', 'ENM Test Environment pENM Firmware UG']
    if str(component) in matches:
        return True
    return False

def assign_from_rota(issue):
    issue_territory = issue.get_team_loc()
    rota_eu = ["EMACARA", "EMUROIS", "ESTMANN", "EVINVOL"]
    rota_in = ["ZVALDHA", "ZARCKAL", "ZYERKEE", "ZNXXNAN", "ZMMRXAX", "ZKHARUH", "ZHBSAIA", "XSURPAD", "ZABDVAH"]
    try:
        script_dir = os.path.dirname(__file__)
        rota_file = open(os.path.join(script_dir, "ea_rota.txt"), "r")
    except Exception as e:
        print "ERROR: Could not assign user to " + issue.get_key()
        return

    line = rota_file.readline()
    rota_file.close()
    nums = line.split(',')
    eur = int(nums[0])
    ind = int(nums[1])
    print "to be assigned: EU: {}, IN: {}".format(rota_eu[eur], rota_in[ind])

    assignee = ""
    european = False
    if "Athlone" in issue_territory or "Genoa" in issue_territory or "Dublin" in issue_territory:
        # European rota
        assignee = rota_eu[eur]
        european = True
    else:
        # Indian rota
        assignee = rota_in[ind]

    if assignee == "":
        print "ERROR: Assignee could not be assigned to: " + issue.get_key()
    else:
        assigned = assign_team_member(issue, assignee)
        if assigned:
            if european:
                eur = eur + 1
            else:
                ind = ind + 1
            update_rota(eur, ind, len(rota_eu), len(rota_in))

def assign_team_member(issue, assignee):
    attempt = 0
    updated = False
    jira_update_url = "https://jira-oss.seli.wh.rnd.internal.ericsson.com/rest/api/2/issue/"
    assign_data = ("{\"fields\": {\"assignee\": {\"name\": \"" + assignee + "\"}}}")
    headers = {"Content-Type": "application/json"}
    while not updated and attempt < 3:
        try:
            print "attempting to assign {} to {}...".format(assignee, issue.get_key())
            response = requests.put(jira_update_url + issue.get_key(), auth=("S4_Team", "S4_Team"), data=assign_data,
                                    headers=headers)
            updated = True
            print "{} has been assigned to: {}".format(assignee, issue.get_key())
        except Exception as e:
            attempt += 1
            if attempt >= 3:
                print "ERROR: Too many requests - could not assign " + str(assignee) + " to: " + str(issue.get_key())

    return updated


def update_rota(eur, ind, rota_eu_len, rota_in_len):
    # write to rota file with updated rota nums
    if eur >= rota_eu_len:
        eur = 0
    if ind >= rota_in_len:
        ind = 0
    script_dir = os.path.dirname(__file__)
    rota_file = open(os.path.join(script_dir, "ea_rota.txt"), "w")
    rota_file.write("{},{}".format(eur, ind))
    rota_file.close()
    print "Rota Updated!"

def state_change(event):
    issue = event.get_issue()
    issue_key = issue.get_key()
    email = mail.Mail(issue, deployments.Deployment(issue.get_deployment_id()))
    print "issues_key = {}".format(issue_key)
    if issue.get_deployment_id() in deployments.credentials.keys():
        deployment = deployments.Deployment(issue.get_deployment_id())
        if event.status_has_changed_from('Testing'):
            print "{} has transitioned from testing state on deployment {}".format(issue_key, deployment)
            user.remove(issue, deployment)
        elif event.status_has_changed_to('Testing'):
            print "{} has transitioned to testing state on deployment {}".format(issue_key, deployment)
            user.create(issue, deployment)
    if issue.get_deployment_id() in calljenkins.cluster_id_cloud:
        if event.status_has_changed_from('Testing'):
            calljenkins.postRequestCloud(issue.get_deployment_id(), 'delete', issue.get_key(), 'testers',
                                         issue.get_reporter_email_address(), issue.get_assignee_email_address())
        elif event.status_has_changed_to('Testing'):
            issue.add_comment("Access credentials for deployment {} have been sent to {}".format(issue.get_deployment_id(),issue.get_reporter_name()),'S4_Team')
            calljenkins.postRequestCloud(issue.get_deployment_id(), 'create', issue.get_key(), 'testers',
                                         issue.get_reporter_email_address(), issue.get_assignee_email_address())
    # COMMENTS ON JIRA TICKET
    if event.status_has_changed_to('Resolved'):
        temp_feedback(issue)
        #send mail to assignee
        email.send_issue_resolved_mail(issue)
    elif event.status_has_changed_from('Resolved') and event.status_has_changed_to('Closed'):
        temp_feedback(issue)
    if event.status_has_changed_to('Approved'):
        print "Ticket approved!!"
        #calljenkins.ApprovedMail(issue_key, issue.get_deployment_id(), issue.get_team_loc())
        email.send_issue_approved_mail(issue)
    if event.status_has_changed_to('Suitable KGB+N'):
        s4_kgb_comment(issue)


def get_comment(cf):
    path = "comment_templates/" + str(cf)
    script_dir = os.path.dirname(__file__)
    c = open(os.path.join(script_dir, path), 'r')
    comment = c.read()
    c.close()
    return comment

def temp_feedback(issue):
    comment = get_comment("resolved_comment.txt")
    issue.add_comment(comment, "S4_Team")


def s3_request_feedback(issue):
    request_feedback(issue, 'S3_Team')


def s4_request_feedback(issue):
    s4_feedback(issue, 'S4_Team')


def request_feedback(issue, reporter):
    comment = get_comment("feedback_comment.txt")
    issue.add_comment(comment, reporter)


def s4_feedback(issue, reporter):
    reporter = issue.get_reporter_name()
    comment = str(reporter) + "feedback_comment.txt"
    issue.add_comment(comment, reporter)


def thank_for_feedback(issue, reporter):
    feedback_comment = """Thank you for your feedback. This ticket is now closed."""
    issue.add_comment(feedback_comment, reporter)


def s4_new_ticket_comment(issue):
    comment = get_comment("new_ticket_comment.txt")
    issue.add_comment(comment, 'S4_Team')


def s4_kgb_comment(issue):
    comment = get_comment("kgb_comment.txt")
    cmt = comment.format(issue.get_reporter_username())
    issue.add_comment(cmt, 'S4_Team')


def checkTask(key):
    url = "https://jira-oss.seli.wh.rnd.internal.ericsson.com/browse/" + key
    try:
        response = requests.get(url, auth=('S4_Team', 'S4_Team'))
    except requests.exceptions.RequestException as error:
        print 'Get {} request failed with error:'.format(url)
        print error
    try:
        # json_response = json.loads(response.body)
        soup = BeautifulSoup(response.content, 'html.parser')
        soup = soup.find(id="type-val")
        soup = soup.text
        soup = soup.strip()
        if soup == 'Task':
            return True
        else:
            return False
    except ValueError as json_error:
        print('JSON decoding has failed: \n {}'.format(json_error))


def deployment_change(event):
    issue = event.get_issue()
    issue_key = issue.get_key()
    from_deployment_id, to_deployment_id = event.get_from_and_to_deployment_id()
    print "{} already in testing state has had an environment update from {} to {}".format(issue_key,
                                                                                           from_deployment_id,
                                                                                           to_deployment_id)
    if from_deployment_id in deployments.credentials.keys():
        from_deployment = deployments.Deployment(from_deployment_id)
        user.remove(issue, from_deployment)
    if to_deployment_id in deployments.credentials.keys():
        to_deployment = deployments.Deployment(to_deployment_id)
        user.create(issue, to_deployment)


def type_of_access_change(event):
    issue = event.get_issue()
    issue_key = issue.get_key()
    if event.type_of_access_has_changed_to('Shared'):
        deployment = deployments.Deployment(issue.get_deployment_id())
        print "{} already in testing state on deployment {} has changed to Shared type".format(issue_key, deployment)
        deployment.change_user_access(issue_key, 'Shared')
    elif event.type_of_access_has_changed_to('Exclusive') or event.type_of_access_has_changed_to(
            'Exclusive weekend') or event.type_of_access_has_changed_to('Exclusive evening'):
        deployment = deployments.Deployment(issue.get_deployment_id())
        print "{} already in testing state on deployment {} has change to Exclusive type".format(issue_key, deployment)
        deployment.change_user_access(issue_key, 'Exclusive')
