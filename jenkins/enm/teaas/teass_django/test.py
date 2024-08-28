#!/usr/bin/python
import requests
from bs4 import BeautifulSoup

def check_task(key):
	url = "https://jira-oss.seli.wh.rnd.internal.ericsson.com/browse/" + key
	try:
	   response = requests.get(url, auth=('S4_Team','S4_Team'))
	except requests.exceptions.RequestException as error:
	   print('Get {} request failed with error:'.format(url))
            
	try:
   	   # json_response = json.loads(response.body)
   	   soup = BeautifulSoup(response.content,'html.parser')
	   soup = soup.find(id="type-val")
	   soup = soup.text
	   soup = soup.strip()
	   print(soup)
	   if soup == 'Task' :
		return True
	   else :
		return False
	except ValueError as json_error:
	   print('JSON decoding has failed: \n {}'.format(json_error))

if check_task("CIP-39385"):
	print("it is a Task")
            
