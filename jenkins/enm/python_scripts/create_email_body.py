#!/usr/bin/python
__author__ = 'ejordba'

import get_enm_deployment_details
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

#TODO figure out how to get stylesheet to load in outlook properly
def create_css_segment():
    return """<head><style type="text/css"><!--
                .tg  {border-collapse:collapse;border-spacing:0;border-color:#999;}
                .tg td{font-family:Arial, sans-serif;font-size:14px;padding:10px 5px;border-style:solid;border-width:0px;overflow:hidden;word-break:normal;border-color:#999;color:#7F7F7F;background-color:#FFFFFF;border-top-width:1px;border-bottom-width:1px;}
                .tg th{font-family:Arial, sans-serif;font-size:14px;font-weight:normal;padding:10px 5px;border-style:solid;border-width:0px;overflow:hidden;word-break:normal;border-color:#999;color:#fff;background-color:#7b0663;border-top-width:1px;border-bottom-width:1px;}
                .tg .tg-9hbo{font-weight:bold;vertical-align:top}
                .tg .tg-6k2t{background-color:#FFFFFF;vertical-align:top}
        --></style></head>
        <body>"""


def open_table():
    return "<table class=\"tg\" border=\"1\">"


def close_table():
    return " </table>\n"


def new_table_row():
    return "<tr>"


def end_table_row():
    return "</tr>\n"


def add_table_header(user_string):
    return "<th class=\"tg-9hbo\">" + str(user_string) + "</th>\n"


def add_table_column(user_string):
    return "<td class=\"tg-6k2t\">" + str(user_string) + "</td>"


def add_para(user_string):
    return "<p>" + str(user_string) + "</p>\n"


def add_h3_tag(user_string):
    return "<h3>" + str(user_string) + "</h3>\n"

def add_break_tag():
    return "</br>\n"


def bug_song(filename):
    #filename.write(create_css_segment())
    filename.write(add_para('99 little bugs in the code.'))
    filename.write(add_para('99 little bugs in the code.'))
    filename.write(add_para('Take one down, patch it around...'))
    filename.write(add_para('127 little bugs in the code.'))


def create_upgrade_path_table(filename):

    enm_upgrade_path    = get_enm_deployment_details.get_enm_version_history()
    litp_upgrade_path   = get_enm_deployment_details.get_litp_version_history()

    filename.write(add_h3_tag('Upgrade Path'))
    filename.write(open_table())
    filename.write(new_table_row())
    filename.write(add_table_header('ENM Upgrade Path'))
    filename.write(add_table_header('LITP Upgrade Path'))
    filename.write(end_table_row())

    filename.write(new_table_row())
    filename.write('<td>')
    for line in reversed(enm_upgrade_path):
        filename.write(add_para(line))
    filename.write('</td>')
    filename.write('<td>')
    for line in reversed(litp_upgrade_path):
        filename.write(add_para(line))
    filename.write('</td>')
    filename.write(end_table_row())

    filename.write(close_table())
    filename.write(add_break_tag())


def create_network_status_table(filename):
    network_status = get_enm_deployment_details.get_sync_network_status()
    filename.write(add_h3_tag('Network'))
    filename.write(open_table())
    filename.write(new_table_row())
    filename.write(add_table_header('Network Status'))
    filename.write(add_table_header('Count'))
    filename.write(end_table_row())

    for state, count in network_status.iteritems():
        filename.write(new_table_row())
        filename.write(add_table_column(state))
        filename.write(add_table_column(count))
        filename.write(end_table_row())

    filename.write(close_table())
    filename.write(add_break_tag())


def write_workload_status(filename):
    workload = get_enm_deployment_details.get_workload_status()
    filename.write(add_h3_tag('Workload'))
    filename.write(open_table())
    filename.write(new_table_row())
    filename.write(add_table_header('Profile'))
    filename.write(add_table_header('Status'))
    filename.write(add_table_header('No. Nodes'))
    filename.write(add_table_header('Initiated at'))
    filename.write(end_table_row())

    for profile, state in workload.iteritems():
        filename.write(new_table_row())
        filename.write(add_table_column(profile))
        filename.write(add_table_column(state['status']))
        filename.write(add_table_column(state['nodes']))
        filename.write(add_table_column(state['start time']))
        filename.write(end_table_row())
    filename.write(close_table())


def main():

    email_body_file = open('/tmp/email-report-body.html', 'w')

    #bug_song(email_body_file)
    create_upgrade_path_table(email_body_file)
    create_network_status_table(email_body_file)
    write_workload_status(email_body_file)
    email_body_file.write('</body></html>')
    email_body_file.close()

    # body = ''

    # with open("/tmp/email-report-body.html", "r") as content:
    #     for line in content.readlines():
    #         body = body+line
    #
    # msg = MIMEMultipart('alternative')
    # mail_body = MIMEText(body, 'html')
    # msg.attach(body)
    #
    # msg.

if __name__ == '__main__':
    main()