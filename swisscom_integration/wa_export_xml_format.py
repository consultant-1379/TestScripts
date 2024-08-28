#!/usr/bin/python
# 
# Workaround script to remove unwanted whitespace values and prettify the cm bulk export xml file (currently being exported as minified)
#
import re
import lxml
import lxml.etree as etree

# Update this value with the path to the bulk export XML file
XML_FILE = "/home/shared/nbicm1/TEST_MOUNT/LRAN_TOPOLOGY.xml"

def remove_whitespace():
	line = None
	
	# Open and parse the existing xml export file
	with open(XML_FILE, 'r') as xml_file:
		line = xml_file.read()

    # Remove white space values after any ">" characters and before any "<" characters
	# Example: ">  value  <" becomes ">value<"
	line = re.sub(r'\s+<', r'<', line)

	line = re.sub(r'>\s+', r'>', line)

	# Remove white space in any empty tags
	# Example "<   >" becomes "<>""
	line = re.sub(r'>\s+<', r'><', line)

	# Write the line back to file now that whitespace is removed 
	with open(XML_FILE, 'w') as xml_file:
	    xml_file.write(line)

def prettyify():	
	parser = etree.XMLParser(remove_blank_text=True)
	tree = None

	# Read the file in again so that we can prettify it
	with open(XML_FILE, 'r') as xml_file:
		tree = etree.parse(XML_FILE, parser)	

	# Re-write the file with pretty xml format
	with open(XML_FILE, 'w') as xml_file:
	    tree.write(XML_FILE, pretty_print=True)

def main():
	remove_whitespace()
	prettyify()

if __name__ == '__main__':
    main()


