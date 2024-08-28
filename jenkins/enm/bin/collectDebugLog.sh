#!/bin/bash

###This script help you to collect extra level loggings for given SGs
### For more information, please check help page below

JBOSSCONFIGFILE="/ericsson/3pp/jboss/standalone/configuration/standalone-enm.xml"
JBOSSCLI="/ericsson/3pp/jboss/bin/jboss-cli.sh -c --commands="
PVTKEY="/root/.ssh/vm_private_key"


function howToMakeConfigFile()
{
   echo
   echo "This is the sample content of log info to be collected. Write the content to a file and pass the file as argument with -f option"
   echo "make sure the loginfo content line start with 'enablefor=' to identify by script"
   echo "### config file"
   echo "###enablefor=servicegroupname;loggername;loggerlevel"
   echo "###enablefor=servicegroupname;loggername-1,loggername-2,....;loggerlevel"
   echo "enablefor=mspm;com.ericsson.oss;DEBUG"
   echo "enablefor=mspm;com.ericsson.oss,org.jgroups;DEBUG"
   echo
}

function usage()
{
   echo "This script help you to collect extra level loggings for given SGs"

   echo "script -e/-d <UserId/Name> [-c <Dirname to copy logs>] -f <config file> [-t <time to disable log>]"
   echo "-e for enable debug logs and pass the eid/username as argument who is running the script"
   echo "-d for disable debug logs and pass the eid/username as argument who is running the script"
   echo "-c for collect the logs."
   echo "-r for read the current logger levels for provided sg and loggernames"
   echo "-f for pass the config file which contains VM name of specific application, Logging Class name(s), Loglevel."
   echo "-t for TIme to Disable logs (in seconds). The log collectiong will be disabled automatically after mentioned Time. IF disable logs should be taken care itself."

   echo "Examples:"
   echo "script -e <username> -f <congfigFile> -t <timetodisable log automatically> -c <directory of log to copy>"  #Enable logger and disable after mentioned time, and collect logs
   echo "script -e <username> -f <congfigFile> -t <timetodisable log automatically>" #Enable logger and disable after mentioned time.
   echo "script -e <username> -f <congfigFile>" #so you have to disable log manually"
   echo "script -d <username> -f <congfigFile> -t <timetodisable log automatically> -c <directory of log to copy>" #Log will be disabled after mentioned time
   echo "script -d <username> -f <congfigFile> -c <directory of log to copy>" #Disable logger immediately and collect logs
   echo "script -f <congfigFile> -c <directory of log to copy>" #only collect logs 
   echo "script -r -f <congfigFile>" #Read the logger level after enable or disable to make sure all ok

   howToMakeConfigFile

}

function callSsh()
{
   ip=$1
   command="$2"
   /usr/bin/ssh -q -o StrictHostKeyChecking=no -o ServerAliveInterval=200 -i ${PVTKEY} cloud-user@${ip} "${command}"
}


function executeCmd()
{
   echo "${FUNCNAME[0]} - Begin"
   instances="$1"
   LOGCMD="$(echo $2 | sed 's/)\//),\//g')"

   echo "Log command is:${LOGCMD}"

   for ip in ${instances};
   do
      echo "Updating Logging for instance: ${ip}"
      callSsh "${ip}" "${JBOSSCLI}${LOGCMD}"
   done

   echo "${FUNCNAME[0]} - End"
}


function collectLogs()
{
   echo "${FUNCNAME[0]} - Begin"
   CONFIG=$(awk -F'=' '/^enablefor=/ {print $2}' ${CONFIGFILE})
   LOGDIR=$1

   DIR="/ericsson/enm/dumps/${LOGDIR}/$(date +'%F')_$(date +'%H%M%S')";
   mkdir -p ${DIR} && chmod 777 ${DIR};

   JBOSSLOG="/ericsson/3pp/jboss/standalone/log/server.log*"
   MSGLOG="/var/log/messages"   

   for entry in ${CONFIG};
   do
      echo "Config entry is: ${entry}";

      sgname=$(echo ${entry} | cut -d';' -f1)
      instances=$(awk '{print $2}' /etc/hosts | egrep "\b${sgname}\b")

      for ip in $(awk '{print $2}' /etc/hosts | egrep "${instances}");
      do
         echo "============ ${ip} ============";

         if [[ $ip =~ "winfiol" ]]; then
            WINFIOLLOGS="/ericsson/log/winfiol-server/w*.log*"
            LOGSTOCOLLECT="${JBOSSLOG} ${MSGLOG} ${WINFIOLLOGS}"
         elif [[ $ip =~ "smrsserv" ]]; then
            SECURELOGS="/var/log/secure"
            LOGSTOCOLLECT="${JBOSSLOG} ${MSGLOG} ${SECURELOGS}"
         else
            LOGSTOCOLLECT="${JBOSSLOG} ${MSGLOG}"
         fi

         CMD="sudo tar -zcvf ${DIR}/${ip}.serverlog.tgz -P ${LOGSTOCOLLECT}"
         callSsh "${ip}" "${CMD}"
      done
   done

   echo -e "\nLogs copied to \"${DIR}\" in LMS \"$(hostname)\""
   echo -e "size of logs collected $(echo $(du -sh ${DIR}) | awk '{print $1}')\n"
   echo "${FUNCNAME[0]} - End"

}

function enableLog()
{
   echo "${FUNCNAME[0]} - Begin"

   CONFIG=$(awk -F'=' '/^enablefor=/ {print $2}' ${CONFIGFILE})
   for entry in ${CONFIG};
   do
      echo "Config entry is: ${entry}";

      sgname=$(echo ${entry} | cut -d';' -f1)
      loggernames=$(echo ${entry} | cut -d';' -f2)
      loglevel=$(echo ${entry} | cut -d';' -f3)

      instances=$(awk '{print $2}' /etc/hosts | egrep "\b${sgname}\b")
      LOCALJBOSSCONFIGFILE="/ericsson/enm/dumps/dl_${USER}_${sgname}_standalone-enm.xml"

      [ -f ${LOCALJBOSSCONFIGFILE} ] && rm -rf ${LOCALJBOSSCONFIGFILE} 
      touch ${LOCALJBOSSCONFIGFILE} && chmod 777 ${LOCALJBOSSCONFIGFILE}

      CMD="sudo bash -c \"sed -n -e '/<logger category=/{p;n;p}' ${JBOSSCONFIGFILE} >> ${LOCALJBOSSCONFIGFILE}\""
      callSsh "$(echo $instances | awk '{print $1}')" "${CMD}"

      echo "Copying the logger category info from standalon_enm.xml file in $sgname VM to local takes some time..."
      sleep 5

      if [ -s ${LOCALJBOSSCONFIGFILE} ]
      then
         readarray -t loggercategory <<< "$(sed -n -e '/<logger category=/{p;}' ${LOCALJBOSSCONFIGFILE} | awk -F'\"' '{print $2}')"

         CMD=""
         for logger in $(echo ${loggernames} | tr -s ',' '\n');
         do
            matched=0;

            for lc in "${loggercategory[@]}";
            do
               if [[ "${lc}" == "${logger}" ]];
               then
                  matched=1;
                  break;
               fi
            done

            if [ ${matched} -eq 1 ];
            then
               CMD+="/subsystem=logging/logger=${logger}:change-log-level\(level=${loglevel}\)";
            else
               CMD+="/subsystem=logging/logger=${logger}:add\(level=${loglevel}\)";
            fi
         done

         executeCmd "${instances}" "${CMD}"
      else
         echo "Logger category file:${LOCALJBOSSCONFIGFILE} does not exist or empty"
      fi
   done
   echo "${FUNCNAME[0]} - End"
}


function disableLog()
{
   echo "${FUNCNAME[0]} - Begin"

   CONFIG=$(awk -F'=' '/^enablefor=/ {print $2}' ${CONFIGFILE})
   for entry in ${CONFIG};
   do
      echo "Config entry is: ${entry}";

      sgname=$(echo ${entry} | cut -d';' -f1)
      loggernames=$(echo ${entry} | cut -d';' -f2)

      instances=$(awk '{print $2}' /etc/hosts | egrep "\b${sgname}\b")
      LOCALJBOSSCONFIGFILE="/ericsson/enm/dumps/dl_${USER}_${sgname}_standalone-enm.xml"

      if [ -s ${LOCALJBOSSCONFIGFILE} ]
      then
         readarray -t loggercategory <<< "$(sed -n -e '/<logger category=/{p;n;p}' ${LOCALJBOSSCONFIGFILE} | awk -F'\"' '{print $2}' | sed 'N;s/\n/ /')"

         CMD=""
         for logger in $(echo ${loggernames} | tr -s ',' '\n');
         do
            matched=0;

            for lc in "${loggercategory[@]}";
            do
               lcname=$(echo $lc | awk '{print $1}')

               if [[ "${lcname}" == "${logger}" ]];
               then
                  lclevel=$(echo $lc | awk '{print $2}')
                  matched=1;
                  break;
               fi
            done

            if [ ${matched} -eq 1 ];
            then
               CMD+="/subsystem=logging/logger=${logger}:change-log-level\(level=${lclevel}\)"
            else
               CMD+="/subsystem=logging/logger=${logger}:remove\(\)"
            fi
         done

         executeCmd "${instances}" "${CMD}"
      else
         echo "Logger category file:${LOCALJBOSSCONFIGFILE} does not exist or empty"
      fi
   done
   echo "${FUNCNAME[0]} - End"
}


function readLog()
{
   echo "${FUNCNAME[0]} - Begin"

   CONFIG=$(awk -F'=' '/^enablefor=/ {print $2}' ${CONFIGFILE})
   for entry in ${CONFIG};
   do
      echo "Config entry is: ${entry}";
      sgname=$(echo ${entry} | cut -d';' -f1)
      loggernames=$(echo ${entry} | cut -d';' -f2)
      
      instances=$(awk '{print $2}' /etc/hosts | egrep "\b${sgname}\b")

      CMD=""
      for logger in $(echo ${loggernames} | tr -s ',' '\n');
      do
         CMD+="/subsystem=logging/logger=${logger}:read-attribute\(name=level\)";
      done

      executeCmd "${instances}" "${CMD}"
   done
   echo "${FUNCNAME[0]} - End"
}


function cleanUp()
{
   echo "${FUNCNAME[0]} - Begin"

   CONFIG=$(awk -F'=' '/^enablefor=/ {print $2}' ${CONFIGFILE})
   for entry in ${CONFIG};
   do
      echo "Config entry is: ${entry}";
      sgname=$(echo ${entry} | cut -d';' -f1)
      [ -f /ericsson/enm/dumps/dl_${USER}_${sgname}_standalone-enm.xml ] && echo "deleting /ericsson/enm/dumps/dl_${USER}_${sgname}_standalone-enm.xml" && rm -f /ericsson/enm/dumps/dl_${USER}_${sgname}_standalone-enm.xml
   done

   echo "${FUNCNAME[0]} - End"
}


### Main

echo "Main - Begin - args: $0 $@"
ENABLE=0
DISABLE=0
COLLECT=0
READONLY=0
USER=""
TIMETODISABLE=0

while getopts "hre:d:c:t:f:" o;
do
   case "${o}" in
   e)
      ENABLE=1
      USER=${OPTARG}
      ;;
   d)
      DISABLE=1
      USER=${OPTARG}
      ;;      
   c)
      COLLECT=1
      LOGDIR=${OPTARG}
      ;;
   f)
      CONFIGFILE=${OPTARG}
      ;;
   t)
      TIMETODISABLE=${OPTARG}
      ;;         
   r)
      READONLY=1
      ;;         
   h | ?)
      usage;
      exit 1;
      ;;
   esac
done

echo "Parsed values: Enable=${ENABLE}, Disable=${DISABLE}, ReadLogger=${READONLY}, User=${USER}, ConfigFile=${CONFIGFILE}, TimeToDisable=${TIMETODISABLE}, LogCollect=${COLLECT}, LogCopyDir=${LOGDIR}"

if [ ${READONLY} -eq 1 ];
then
   [ -z "${CONFIGFILE}" ] && echo "Config file is missing...." && usage && exit 1;
   readLog
   exit 0;
fi

if [ ${ENABLE} -eq 1 ];
then
   [ -z "${USER}" ] && echo "User input is missing..." && usage && exit 1;
   [ -z "${CONFIGFILE}" ] && echo "Config file is missing...." && usage && exit 1;

   echo "Enable log by user:${USER}, and config file: ${CONFIGFILE}"

   enableLog

   if [ ${DISABLE} -eq 0 ];
   then
      if [ ${TIMETODISABLE} -gt 0 ];
      then
         echo "Disabling logs automatically as -t option passed with value to sleep ${TIMETODISABLE} seconds"
         sleep ${TIMETODISABLE};
         disableLog
         cleanUp
      else
         echo "The log collections must be disabled manually after your work is done."
      fi
   fi
fi

if [ ${DISABLE} -eq 1 ];
then
   [ -z "${USER}" ] && echo "User input is missing..." && usage && exit 1;
   [ -z "${CONFIGFILE}" ] && echo "Config file is missing...." && usage && exit 1;

   echo "Disable log by user:${USER}, and config file: ${CONFIGFILE}"

   if [ ${TIMETODISABLE} -gt 0 ];
   then
      echo "sleep for ${TIMETODISABLE} seconds"
      sleep ${TIMETODISABLE};
   fi

   disableLog
   cleanUp

fi

if [ ${COLLECT} -eq 1 ];
then
   echo "collect log"
   if [ -z "${LOGDIR}" ]; then
      echo "Pass the dir name to copy the logs.." && usage && exit 1;
   fi
   collectLogs ${LOGDIR}
fi

echo "Main - End"
