#!/bin/bash

echo
echo "Script to count PM files/symlinks in the file listing snapshots that are captured by this script: get_pmic_volume_file_listing.sh"
echo

if [ $# -lt 4 ]; then
    TODAY=$(date +%y%m%d)
    echo
    echo "Need to specify some arguments to this script"
    echo "USAGE: $0   DateOfSnapshot   ROP_Date   ROP_StartHour   ROP_EndHour "
    echo
    echo " e.g. To see the number of files actually collected (and symlinks produced) per ROP today"
    echo "  between the hours of 12am and 7am, based on a snapshot of a file listing of the PMIC volumes,"
    echo "   (assuming the snapshot of the file listing was taken at a later time):"
    echo "  then run the following:"
    echo "   $0 $TODAY $TODAY 0 7"
    echo
    exit 0
fi

DATE_OF_SNAPSHOT=$1
ROP_DATE=$2
ROP_START_HOUR=$3
ROP_END_HOUR=$4

PMIC_DATA_DIR="/ericsson/enm/dumps/PMIC_DATA_DIR"
[[ ! -d $PMIC_DATA_DIR ]] && mkdir $PMIC_DATA_DIR;

PMIC_SNAPSHOT_FILES="${PMIC_DATA_DIR}/pmic*.file_list.timestamps.$DATE_OF_SNAPSHOT"
SYMVOL_SNAPSHOT_FILE="${PMIC_DATA_DIR}/symvol.file_list.timestamps.$DATE_OF_SNAPSHOT"

WARNING=0
FILE_COMPRESSED=0
SYM_COMPRESSED=0

echo "Script Inputs:
    DATE_OF_SNAPSHOT=$DATE_OF_SNAPSHOT
    ROP_DATE=$ROP_DATE
    ROP_START_HOUR=$ROP_START_HOUR
    ROP_END_HOUR=$ROP_END_HOUR
"

# Some input checking
if [ $ROP_START_HOUR -gt $ROP_END_HOUR ]; then
    echo "The ROP_START_HOUR needs to be less then ROP_END_HOUR"
    exit 0
fi


echo "Script will check the following files:"

for FILE in $(ls ${PMIC_DATA_DIR} | egrep pmic.*file_list.timestamps.$DATE_OF_SNAPSHOT )
do
        FILE="$PMIC_DATA_DIR/$FILE"
        PMIC_FILE_LISTING_EXISTS=YES
        if [ $(echo ${FILE} | egrep '.gz$') ]; then
            EXT=".gz"
            ((FILE_COMPRESSED++))
        fi

    FILE_LISTING=$(ls -rtlh $FILE)
    FILE_SIZE=$(echo $FILE_LISTING | awk '{print $5}')
    [[ "$FILE_SIZE" = "0"  ]] && ((WARNING++))

    ls -rtlh $FILE

done

if [ -z $PMIC_FILE_LISTING_EXISTS ]; then
            echo "No PMIC volume file listing snapshot files exists: $PMIC_SNAPSHOT_FILES"
            exit 0

fi

if [ ! -f $SYMVOL_SNAPSHOT_FILE ]; then
    if [ -f "${SYMVOL_SNAPSHOT_FILE}.gz" ]; then
        EXT=".gz"
        ((SYM_COMPRESSED++))
    else 
        echo "No symbol volume file listing snapshot files exists: $FILE"
        exit 0
    fi
fi


FILE_LISTING=$(ls -rtlh $SYMVOL_SNAPSHOT_FILE$EXT)
FILE_SIZE=$(echo $FILE_LISTING | awk '{print $5}')
[[ "$FILE_SIZE" = "0"  ]] && ((WARNING++))

echo $FILE_LISTING

echo



# If files have zero file size, issue warning
[[ $WARNING -ne 0 ]] && echo "WARNING: One of more files have zero file size, indicating problem with data"  


[[ $SYM_COMPRESSED -gt 0 || $FILE_COMPRESSED -gt 0 ]] && GREP="zgrep" || GREP="egrep"




# Display the Table header
printf "%-6s %-10s | %-15s %-15s %-15s | %-15s %-15s | %-15s %-15s | %-15s \n" "ROP " "ROP " "XML_RAW"     "XML_RAW"         "XML_AVG  "  "XML_SYMLINK"  "XML_SYMLINK"     "CELL_RAW"    "CELL_RAW"        "CELL_SYMLINK" 
printf "%-6s %-10s | %-15s %-15s %-15s | %-15s %-15s | %-15s %-15s | %-15s \n" "DATE" "TIME" "FILE_COUNT"  "LAST_TIMESTAMP"  "FILE_SIZE"  "FILE_COUNT"   "LAST_TIMESTAMP"  "FILE_COUNT"  "LAST_TIMESTAMP"  "FILE_COUNT" 

XML_LAST_FILE_TIME=0
XML_SYM_LAST_FILE_TIME=0
OUTPUT_DIR="/ericsson/enm/dumps/.verify_pmic"
[[ ! -d $OUTPUT_DIR ]] && mkdir $OUTPUT_DIR
rm -rf $OUTPUT_DIR/*

# Display the table of values
for (( HOUR=$ROP_START_HOUR; HOUR<=$ROP_END_HOUR; HOUR++ )); do
        [[ $HOUR -lt 10 ]] && PADDING=0 || PADDING=""

        for ROP_START in 00 15 30 45; do
                COMMON_SEARCH_TERM="A20$ROP_DATE.$PADDING$HOUR$ROP_START"

                case $ROP_START in 
                        "00" ) ROP_END="15"; ROP_FINISH_HOUR=$HOUR; ;;
                        "15" ) ROP_END="30"; ROP_FINISH_HOUR=$HOUR; ;;
                        "30" ) ROP_END="45"; ROP_FINISH_HOUR=$HOUR; ;;
                        "45" ) ROP_END="00"; ROP_FINISH_HOUR=$((HOUR+1)) ;;
                esac 


                #Create mini command files to be run in parallel
                ROP_FILENAME=$OUTPUT_DIR/$ROP_DATE.$PADDING$ROP_START_HOUR$ROP_START

                CMD="$GREP -c XML.*$COMMON_SEARCH_TERM $PMIC_SNAPSHOT_FILES$EXT | awk -F: '{print \$NF}' | awk '{s+=\$1} END {print s}' > $ROP_FILENAME.XML_FILE_COUNT.res"
                echo "$CMD" > $ROP_FILENAME.XML_FILE_COUNT.cmd

                CMD="$GREP -c CELL.*$COMMON_SEARCH_TERM $PMIC_SNAPSHOT_FILES$EXT | awk -F: '{print \$NF}' | awk '{s+=\$1} END {print s}' > $ROP_FILENAME.CELL_FILE_COUNT.res" 
                echo "$CMD" > $ROP_FILENAME.CELL_FILE_COUNT.cmd

                CMD="$GREP -c XML.*$COMMON_SEARCH_TERM $SYMVOL_SNAPSHOT_FILE$EXT | awk -F: '{print \$NF}' | awk '{s+=\$1} END {print s}' > $ROP_FILENAME.XML_SYMLINK_FILE_COUNT.res"
                echo "$CMD" > $ROP_FILENAME.XML_SYMLINK_FILE_COUNT.cmd

                CMD="$GREP -c CELL.*$COMMON_SEARCH_TERM $SYMVOL_SNAPSHOT_FILE$EXT | awk -F: '{print \$NF}' | awk '{s+=\$1} END {print s}' > $ROP_FILENAME.CELL_SYMLINK_FILE_COUNT.res"
                echo "$CMD" > $ROP_FILENAME.CELL_SYMLINK_FILE_COUNT.cmd 

                CMD="$GREP XML.*$COMMON_SEARCH_TERM $PMIC_SNAPSHOT_FILES$EXT | awk '{print \$7}' | sort | cut -c1-12 | tail -1 > $ROP_FILENAME.XML_LAST_FILE_TIME.res"
                echo "$CMD" > $ROP_FILENAME.XML_LAST_FILE_TIME.cmd

                CMD="$GREP CELL.*$COMMON_SEARCH_TERM $PMIC_SNAPSHOT_FILES$EXT | awk '{print \$7}' | sort | cut -c1-12 | tail -1 > $ROP_FILENAME.CELL_LAST_FILE_TIME.res"
                echo "$CMD" > $ROP_FILENAME.CELL_LAST_FILE_TIME.cmd

                CMD="$GREP XML.*$COMMON_SEARCH_TERM $SYMVOL_SNAPSHOT_FILE$EXT | awk '{print \$7}' | sort | cut -c1-12 | tail -1 > $ROP_FILENAME.XML_SYM_LAST_FILE_TIME.res"
                echo "$CMD" > $ROP_FILENAME.XML_SYM_LAST_FILE_TIME.cmd

                CMD="$GREP XML.*$COMMON_SEARCH_TERM $PMIC_SNAPSHOT_FILES$EXT | awk '{print \$5}' | awk '{s+=\$1} END {print s}' > $ROP_FILENAME.XML_TOTAL_ROP_VOLUME.res"
                echo "$CMD" > $ROP_FILENAME.XML_TOTAL_ROP_VOLUME.cmd

                CMD="$GREP CELL.*$COMMON_SEARCH_TERM $PMIC_SNAPSHOT_FILES$EXT | awk '{print \$5}' | awk '{s+=\$1} END {print s}' > $ROP_FILENAME.CELL_TOTAL_ROP_VOLUME.res"
                echo "$CMD" > $ROP_FILENAME.CELL_TOTAL_ROP_VOLUME.cmd


                # Run all the queries now
                CMD_FILE_LIST=$(ls $ROP_FILENAME.*.cmd)
                PIDS=""
                for FILE in $CMD_FILE_LIST; do 
                        . $FILE &
                        PIDS="$PIDS $!"
                done

                wait $PIDS


                XML_FILE_COUNT=$(cat $ROP_FILENAME.XML_FILE_COUNT.res)
                CELL_FILE_COUNT=$(cat $ROP_FILENAME.CELL_FILE_COUNT.res)
                XML_SYMLINK_FILE_COUNT=$(cat $ROP_FILENAME.XML_SYMLINK_FILE_COUNT.res)
                CELL_SYMLINK_FILE_COUNT=$(cat $ROP_FILENAME.CELL_SYMLINK_FILE_COUNT.res)

                XML_LAST_FILE_TIME=$(cat $ROP_FILENAME.XML_LAST_FILE_TIME.res)
                CELL_LAST_FILE_TIME=$(cat $ROP_FILENAME.CELL_LAST_FILE_TIME.res)
                XML_SYM_LAST_FILE_TIME=$(cat $ROP_FILENAME.XML_SYM_LAST_FILE_TIME.res)
                XML_TOTAL_ROP_VOLUME=$(cat $ROP_FILENAME.XML_TOTAL_ROP_VOLUME.res)
                CELL_TOTAL_ROP_VOLUME=$(cat $ROP_FILENAME.CELL_TOTAL_ROP_VOLUME.res)

                [[ -z $XML_LAST_FILE_TIME ]] && XML_LAST_FILE_TIME=0
                [[ -z $XML_SYM_LAST_FILE_TIME ]] && XML_SYM_LAST_FILE_TIME=0
                [[ $XML_FILE_COUNT -ne 0 ]] && XML_AVERAGE_FILE_SIZE=$(echo $XML_TOTAL_ROP_VOLUME/$XML_FILE_COUNT | bc)

                rm -rf $OUTPUT_DIR/*
       
                printf "%-6s %-10s | %-15s %-15s %-15s | %-15s %-15s | %-15s %-15s | %-15s \n" "$ROP_DATE" "$PADDING$HOUR$ROP_START-$PADDING$ROP_FINISH_HOUR$ROP_END" "$XML_FILE_COUNT"  "$XML_LAST_FILE_TIME"  "$XML_AVERAGE_FILE_SIZE" "$XML_SYMLINK_FILE_COUNT"   "$XML_SYM_LAST_FILE_TIME"  "$CELL_FILE_COUNT"  "$CELL_LAST_FILE_TIME"  "$CELL_SYMLINK_FILE_COUNT"

        done;

done




echo
echo "To perform a manual check, try the following commands:-"
echo "XML checks:-"
echo "       Raw File Count:   # $GREP XML $PMIC_SNAPSHOT_FILES$EXT | egrep -c $COMMON_SEARCH_TERM"
echo "Time of Last Raw File:   # $GREP XML $PMIC_SNAPSHOT_FILES$EXT | egrep $COMMON_SEARCH_TERM | awk '{print \$7}' | sort | cut -c1-12 | tail -1"
echo "   SymLink File Count:   # $GREP XML $SYMVOL_SNAPSHOT_FILE$EXT | egrep -c $COMMON_SEARCH_TERM"

echo
echo "CELL checks:-"
echo "       Raw File Count:   # $GREP CELL $PMIC_SNAPSHOT_FILES$EXT | egrep -c $COMMON_SEARCH_TERM"
echo "Time of Last Raw File:   # $GREP CELL $PMIC_SNAPSHOT_FILES$EXT | egrep $COMMON_SEARCH_TERM | awk '{print \$7}' | sort | cut -c1-12 | tail -1"
echo "   SymLink File Count:   # $GREP CELL $SYMVOL_SNAPSHOT_FILE$EXT | egrep -c $COMMON_SEARCH_TERM"


echo
