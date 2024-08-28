#!/bin/bash

echo "Script to extract data from last_undefined_vm image on blade"
echo

if [ "$(whoami)" != "root" ]; then
        echo "Need to be root user to run this script - exiting"
        echo
        exit 0
fi

if [ ! -z $1 ]; then 
        SG=$1
        echo "Service Group specified: $SG"
else
        echo "No service Group specified - checking all existing images"
fi
echo

IMAGE_LOCATION="/var/lib/libvirt/instances"

if [ ! -d $IMAGE_LOCATION ]; then
        echo "The last_undefined_vm image location was not found on this server: $IMAGE_LOCATION"
        echo " - script need to be run on a blade where these images are stored"
        exit 0
fi

# Only return list of files related to ServiceGroup if that has been requested, otherwise, return full list of files found
if [ ! -z $SG ]; then
        LIST_OF_IMAGE_FILES=$(find $IMAGE_LOCATION | egrep last_undefined_vm | egrep "qcow2" | egrep $SG )
else
        LIST_OF_IMAGE_FILES=$(find $IMAGE_LOCATION | egrep last_undefined_vm | egrep "qcow2" )
fi


if [ "$LIST_OF_IMAGE_FILES" == "" ]; then

        if [ ! -z $SG ]; then
                MSG="for $SG"
        fi

        echo "No last_undefined_vm image files found in $IMAGE_LOCATION $MSG"
        echo 
        exit 0
fi


for FILE in $LIST_OF_IMAGE_FILES; do 

        SVC=$(echo $FILE | awk -F'/' '{print $6}'); 
        FILE_EXT=$(echo $FILE | awk -F'.' '{print $NF}'); 

        echo "$SVC image file found: "
        ls -rtlh $FILE

        OUTPUT_DIR=/ericsson/enm/dumps/last_undefined_vm-extracted_data/$SVC/$(hostname)/$FILE_EXT; 
        JBOSS_LOGS_DIR=/ericsson/3pp/jboss/standalone/
        ERICSSON_LOGS_DIR=/ericsson/


        if [ ! -d $OUTPUT_DIR ]; then 

                echo "Extracting data from the last_undefined_vm image file using following commands..."

                mkdir -p $OUTPUT_DIR/var
                COMMAND="virt-copy-out -a $FILE /var/log /$OUTPUT_DIR/var"
                echo 1. $COMMAND
                $COMMAND

                COMMAND="virt-copy-out -a $FILE /tmp /$OUTPUT_DIR/"
                echo 2. $COMMAND
                $COMMAND

                if [ "$SVC" == "openidm" ]; then
                        mkdir -p $OUTPUT_DIR/$ERICSSON_LOGS_DIR
                        COMMAND="virt-copy-out -a $FILE  $ERICSSON_LOGS_DIR/log /$OUTPUT_DIR/$ERICSSON_LOGS_DIR"
                        echo 3. $COMMAND
                        $COMMAND
                else
                        mkdir -p $OUTPUT_DIR/$JBOSS_LOGS_DIR
                        COMMAND="virt-copy-out -a $FILE  $JBOSS_LOGS_DIR/log /$OUTPUT_DIR/$JBOSS_LOGS_DIR"
                        echo 3. $COMMAND
                        $COMMAND
                fi

                if [ "$(echo $SVC | egrep ebsmcontroller)" != "" ]; then
                                mkdir -p $OUTPUT_DIR/$ERICSSON_LOGS_DIR
                        COMMAND="virt-copy-out -a $FILE  $ERICSSON_LOGS_DIR/log /$OUTPUT_DIR/$ERICSSON_LOGS_DIR"
                        echo 4. $COMMAND
                        $COMMAND
                fi

                echo "...done"
                echo

                echo -n "Compressing extracted files to save on disk usage..."
		find /$OUTPUT_DIR/ -type f -exec gzip {} \;
                echo "done"
                echo 

                echo "Data has been extracted to following folder: "
                echo "$OUTPUT_DIR"
                echo 

        else 

                echo "Data already extracted to $OUTPUT_DIR"
                echo 

        fi


done;

echo

