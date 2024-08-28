import random
import string

import mail


def create(issue, deployment):
    type_of_server_access = issue.get_type_of_server_access()
    username = issue.get_key()
    print "Going to create user {} on deployment {}".format(username, deployment)
    password = generate_random_password()
    email = mail.Mail(issue, deployment)
    if deployment.add_user(username, password, type_of_server_access):
        print username + ", " + password + " has been created on " + issue.get_deployment_id()
        email.send_user_creation_email(issue.get_deployment_id(), password)
        issue.add_comment("Access credentials for deployment {} have been sent to {}".format(
            deployment, issue.get_reporter_name()), 'S4_Team')
    else:
        email.send_user_creation_failure_mail()


def remove(issue, deployment):
    username = issue.get_key()
    print "Going to delete user {} on deployment {}".format(username, deployment)
    email = mail.Mail(issue, deployment)
    if deployment.del_user(username):
        email.send_user_deletion_email()
    else:
        email.send_user_deletion_failure_mail()


def remove_without_issue(username, deployment):
    print "Going to delete user {} on deployment {}".format(username, deployment)
    deployment.del_user(username)


def generate_random_password():
    specials = ['_', '-', '#', '@']
    # get random password pf length 9 with letters, digits, and symbols
    characters = string.ascii_letters + string.digits
    password = "".join(random.choice(characters) for i in range(9))
    pw = list(password)
    for i in range(3):
        ind = random.randrange(1, 8)
        pw[ind] = specials[random.randrange(3)]
    password = "".join(pw)
    return password
