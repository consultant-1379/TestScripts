
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
        email.send_user_creation_email(password)
        issue.add_comment("Access credentials for deployment {} have been sent to {}".format(
                                     deployment,issue.get_reporter_name()), 'S4_Team')
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
    myrg = random.SystemRandom()
    length = 8
    characters = string.ascii_letters + string.digits
    pw_charater_list = [myrg.choice(string.ascii_uppercase), myrg.choice(string.ascii_lowercase), myrg.choice(string.digits)]
    while len(pw_charater_list) < length:
        pw_charater_list.append(myrg.choice(characters))
    pw = ''.join(pw_charater_list)
    return pw