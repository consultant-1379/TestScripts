TAG="VersantTrans"
function run_vt(){
FILE=/ericsson/enm/dumps/.upgrade_ongoing
if [ ! -f ${FILE} ] ; then
        logger INFO "${TAG}" "Running Versant Transactions script"
        su - versant -c "source /ericsson/versant/bin/envsettings.sh"
        TODAY=`date +%Y%m%d`
        #source /ericsson/versant/bin/envsettings.sh

        echo "##############################" >> /ericsson/enm/dumps/longesttransactions_rvb_"${TODAY}".log
        date >> /ericsson/enm/dumps/longesttransactions_rvb_"${TODAY}".log
        echo "##############################" >> /ericsson/enm/dumps/longesttransactions_rvb_"${TODAY}".log
        echo "" >> /ericsson/enm/dumps/longesttransactions_rvb_"${TODAY}".log
        echo "############Longest Lasting Transactions" >> /ericsson/enm/dumps/longesttransactions_rvb_"${TODAY}".log
        su - versant -c "/ericsson/versant/bin/dbtool -nosession -trans -info -xidAscii dps_integration"|grep svc-|sort -rnk5|head -30 >> /ericsson/enm/dumps/longesttransactions_rvb_"${TODAY}".log
        echo "###########Total Number of Transactions" >> /ericsson/enm/dumps/longesttransactions_rvb_"${TODAY}".log
        su - versant -c "/ericsson/versant/bin/dbtool -nosession -trans -info -xidAscii dps_integration"|grep -c svc- >> /ericsson/enm/dumps/longesttransactions_rvb_"${TODAY}".log
        echo "###########MSPM Transactions" >> /ericsson/enm/dumps/longesttransactions_rvb_"${TODAY}".log
        su - versant -c "/ericsson/versant/bin/dbtool -nosession -trans -info -xidAscii dps_integration"|grep -c mspm >> /ericsson/enm/dumps/longesttransactions_rvb_"${TODAY}".log
        echo "" >> /ericsson/enm/dumps/longesttransactions_rvb_"${TODAY}".log
        echo "##########All Transaction Occurences###########" >> /ericsson/enm/dumps/longesttransactions_rvb_"${TODAY}".log
        echo "" >> /ericsson/enm/dumps/longesttransactions_rvb_"${TODAY}".log
        su - versant -c "/ericsson/versant/bin/dbtool -nosession -trans -info -xidAscii dps_integration"|grep  svc-|awk '{print $NF}'|sort|uniq -c >> /ericsson/enm/dumps/longesttransactions_rvb_"${TODAY}".log
        echo "##############################" >> /ericsson/enm/dumps/longesttransactions_rvb_"${TODAY}".log
        echo "#########Total Connections##############" >> /ericsson/enm/dumps/longesttransactions_rvb_"${TODAY}".log
        su - versant -c "/ericsson/versant/bin/vstats -connections -database dps_integration" |grep -c Session >> /ericsson/enm/dumps/longesttransactions_rvb_"${TODAY}".log

        echo "Largest Number of Connections" >> /ericsson/enm/dumps/longesttransactions_rvb_"${TODAY}".log
        su - versant -c "/ericsson/versant/bin/vstats -connections -database dps_integration"|grep svc-|awk '{print $NF}'|sort|uniq -c|sort -rnk1|head -15 >> /ericsson/enm/dumps/longesttransactions_rvb_"${TODAY}".log

        echo "" >> /ericsson/enm/dumps/longesttransactions_rvb_"${TODAY}".log
        echo "######Lock Tables#############" >> /ericsson/enm/dumps/longesttransactions_rvb_"${TODAY}".log
        su - versant -c "/ericsson//versant/bin/dbtool   -locks -table dps_integration"| egrep 'Client: db1-service|Number of locks' >> /ericsson/enm/dumps/longesttransactions_rvb_"${TODAY}".log
else
        logger INFO "${TAG}" "Upgrade ongoing not running this script"
fi
}





function start_check(){

  #To be implemented when multiple databases are introduced
  #VERSANT_PID=$(ps -ef | $GREP 'cleanbe\|vserver' | $GREP ${DB_NAME})
  CLEANBE_PID=$(pgrep cleanbe)
  OBE_PID=$(pgrep obe)
  #if obe /cleanbe process exist
  if [ ! -z ${CLEANBE_PID} ] && [ ! -z ${OBE_PID} ]; then
        run_vt
  else
        logger INFO "${TAG}" "Versant not running Here!!!!"
  fi

}

#MAIN
start_check
