#!/usr/bin/python

import datetime

day = '27/Jul/20'
today = datetime.datetime.today()
my_date = datetime.datetime.strptime(day, '%d/%b/%y')
if(my_date <= today) :
	print('expired')
else :
	print('not expired')

dateString="""
<span data-name="Planned End Date" id="customfield_25009-val" data-fieldtype="datepicker" data-fieldtypecompletekey="com.atlassian.jira.plugin.system.customfieldtypes:datepicker">
                                                                                  <span title="24/Mar/20"><time datetime="2020-03-24">24/Mar/20</time></span>
                                                                 </span>
"""
indexStart =  dateString.index('title=') + 7
indexEnd = indexStart + 9
print dateString[indexStart : indexEnd]
