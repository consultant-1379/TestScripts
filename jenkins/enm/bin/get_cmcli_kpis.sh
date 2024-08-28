#!/bin/bash


# Quick script which calculates  the average of the STKPI's CMCLI_01 & CM_Change_01


CMCLI_SUM=`grep "STKPI_CMCLI_01" /var/log/messages | awk '{print $8}' | cut -d':' -f2 | paste -sd+ | bc`
CMCLI_SAMPLES=`grep "STKPI_CMCLI_01" /var/log/messages| wc -l`
CMCLI_AVG=`echo "${CMCLI_SUM}/${CMCLI_SAMPLES}"| bc`

CM_CHANGE_SUM=`grep "STKPI_CM_Change_01" /var/log/messages | awk '{print $8}' | cut -d':' -f2 | paste -sd+ | bc`
CM_CHANGE_SAMPLES=`grep "STKPI_CM_Change_01" /var/log/messages| wc -l`
CM_CHANGE_AVG=`echo "${CM_CHANGE_SUM}/${CM_CHANGE_SAMPLES}"| bc`


echo "*************************************"
echo "          STKPI_CMCLI_01"
echo "*************************************"
echo "Summation of ${CMCLI_SAMPLES} samples: ${CMCLI_SUM}"
echo "Calculated average: ${CMCLI_AVG}"
echo ""
echo ""
echo "*************************************"
echo "          STKPI_CM_CHANGE_01"
echo "*************************************"
echo "Summation of ${CM_CHANGE_SUM} samples: ${CM_CHANGE_SAMPLES}"
echo "Calculated average: ${CM_CHANGE_AVG}"

echo ""
echo ""
echo "NOTE: Be sure to validate the samples read from /var/log/messages"
echo ""
