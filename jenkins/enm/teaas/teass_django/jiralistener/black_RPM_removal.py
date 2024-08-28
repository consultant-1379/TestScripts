from bs4 import BeautifulSoup
import requests
import jira
import deployments


def startCheck(self):
    # Gets the Resolved Ticket and creates jira issue object
    jql_query = "project = DETS and " \
                "component = 'Team Grifone' and " \
                "status = '{}'".format('Resolved')
    json_query = {"jql": jql_query,
                  "startAt": 0,
                  "maxResults": 1000}
    ResolvedTickets = jira.search_for_issues(json_query)

    # Creates string of DETS-XXXX
    TestString = ""
    for t in ResolvedTickets:
        DescriptionString = GetRPM(t.get_key(), t.get_deployment_id())
        # RPMLinks = FindRPMLinks(DescriptionString)
        # ServiceGroups = FindServiceGroups(DescriptionString)
        # RPMLinksForJenkinsJob = checkRPM(RPMLinks)

    # Sends email to users using jenkins job
    url = 'https://fem8s11-eiffel004.eiffel.gic.ericsson.se:8443/jenkins/view/S4/job/S4JLemailNonEricsson/buildWithParameters?'
    url += 'email_address=' + 'oisin.murphy@ericsson.com' + '&email_subject=' + 'BlackRPMTest'
    url += '&email_content=' + DescriptionString
    # x = requests.post(url, auth = ('S4USER','nBeCp6dyHvV2cZhJnbkBMsMz'))
    # print(x.status_code)


def GetRPM(key, Cid):
    # Gets Request off jira ticket and makes readable beatiful soup  object
    jira_link = "https://jira-oss.seli.wh.rnd.internal.ericsson.com/browse/" + key
    r = requests.get(jira_link, auth=('S4USER', 'nBeCp6dyHvV2cZhJnbkBMsMz'))
    soup = BeautifulSoup(r.text, features="lxml")

    RPMList = ""
    # Searches for links with "class=external-link" then using keyword ERIC to find RPM links
    for link in soup.findAll("a", attrs={"class": "external-link"}):
        if link.get('href').find("ERIC") != -1:
            RPMNAME = GetRPMName(link.get('href'))

            CXPNUMBERandVERSION = GetCXPandVersion(link.get('href'))

            CXPNUMBER = CXPNUMBERandVERSION[0: 10]

            VERSION = getVersion(CXPNUMBERandVERSION[12: 20])

            RPMList += CheckBlackRPM(RPMNAME, CXPNUMBER, VERSION, Cid)

    return ('HI')


def CheckBlackRPM(RPMNAME, CXPNUMBER, VERSION, Cid):
    if RPMisOnLMS(CXPNUMBER, VERSION, Cid):
        print "RPM is on LMS"
    return ""


def RPMisOnLMS(CXPNUMBER, VERSION, Cid):
    if Cid == '429' or Cid == '623' or Cid == '660':
        deployment = deployments.Deployment(Cid)
        LMSRPM = deployment.execute_command_on_lms("ls /var/www/html/ENM_services | grep " + CXPNUMBER)
        LMSRPMName = GetRPMName(LMSRPM[0])
        LMSRPMcxpver = GetCXPandVersion(LMSRPM[0])
        LSMRPMcxp = LMSRPMcxpver[0: 10]
        LSMRPMversion = getVersion(LMSRPMcxpver[0][12: 20])

    return True


def GetRPMName(info):
    start = info.find('ERIC')
    RPMNAME = info[start: (start + 50)]
    fixRPMName = RPMNAME.find("_")
    RPMNAME = RPMNAME[0: fixRPMName]
    print RPMNAME
    return RPMNAME


def GetCXPandVersion(info):
    start = info[0].find("CXP")
    CXPNUMBERandVERSION = info[0][start: (start + 20)]
    return CXPNUMBERandVERSION


def getVersion(CXPNUMBERandVERSION):
    VERSION = ""
    if CXPNUMBERandVERSION.find("/") != -1:
        splitValues = CXPNUMBERandVERSION.split("/")
        VERSION = splitValues[1]
    elif CXPNUMBERandVERSION.find("-") != -1:
        splitValues = CXPNUMBERandVERSION.split("-")
        VERSION = splitValues[1]
    return VERSION
