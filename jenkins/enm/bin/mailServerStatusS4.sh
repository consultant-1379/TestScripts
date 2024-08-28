#!/bin/bash
#!/usr/sbin/sendmail

PATH=/bin:/usr/bin:/usr/lib:/usr/local/bin
export PATH
umask 022

CLUSTERID=$1
currDate=`date +%d%m%Y`


from="$HOSTNAME"
sendTo="PDLDUNAMLO@pdl.internal.ericsson.com"
subject="$CLUSTERID Daily Server Status Update"
boundary="ZZ_/afg6432dfgkl.94531q"
body="Daily server status attached to this email for $HOSTNAME"
declare -a attachments
attachments=( "/home/sysCheck$currDate" )


get_mimetype(){
  file --mime-type "$1" | sed 's/.*: //' 
}

# headers
{

printf '%s\n' "From: $from
To: $sendTo
Subject: $subject
Mime-Version: 1.0
Content-Type: multipart/mixed; boundary=\"$boundary\"

--${boundary}
Content-Type: text/plain; charset=\"US-ASCII\"
Content-Transfer-Encoding: 7bit
Content-Disposition: inline

$body
"
while IFS= read -r line; do echo "$line"; done < /home/sysCheck$currDate

for file in "${attachments[@]}"; do

  [ ! -f "$file" ] && echo "Warning: attachment $file not found, skipping" >&2 && continue

  mimetype=$(get_mimetype "$file") 
 
  printf '%s\n' "--${boundary}
Content-Type: $mimetype
Content-Transfer-Encoding: base64
Content-Disposition: attachment; filename=\"$file\"
"
 
  base64 "$file"
  echo
done
 
printf '%s\n' "--${boundary}--"
 
} | sendmail -t -oi 
