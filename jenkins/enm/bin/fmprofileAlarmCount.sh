#!/bin/sh

DATE=$1
TOTAL=0

for i in {1..3}
do

   array1=(`zgrep "^${DATE} " /var/log/enmutils/daemon/fm_0${i}.log* | grep "alarmburst:" | grep " Executed command" |cut -d',' -f4 | sort | uniq -c | sort -nr | cut -d'=' -f2`) #awk '{print $2}'`)
   echo "   Check number of alarms by Profile FM_0${i} and numer of alarms in array: ${array1[@]}"

   for j in "${array1[@]}"
   do
      TIMES=`zgrep "^${DATE} " /var/log/enmutils/daemon/fm_0${i}.log* | grep alarmburst | grep " Executed command " | grep "num_alarms=${j}" | cut -d"'" -f6,7,8 | sed "s/'//g" | sed 's/ /</g' | sed 's/[^<]//g' | awk 'BEGIN{sum=0} {sum+=length} END {printf "%d\n", sum}'`

      MUL=`echo "${j}*${TIMES}" | bc -l`
      TOTAL=`echo "${TOTAL}+${MUL}" | bc -l`
   done
done

echo
echo "Total number of alarms processed by FM profile is: ${TOTAL}"
echo
