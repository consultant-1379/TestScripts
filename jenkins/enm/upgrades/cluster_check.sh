#!/bin/bash

# Author: ejordba
# Simple script that runs enminst's vcs bash script and validates that the output comes back as ok and healthy.
# Should return a none zero exit code if not
echo "Checking cluster state.."
/opt/ericsson/enminst/bin/vcs.bsh --groups | tee cluster_health.txt

num_not_ok=0
for state in `cat cluster_health.txt | tail -n +8 | head -n -1 | sed 's/   */%/g' | cut -d% -f 8`
do
        if [[ $state == "OK" ]]; then
                continue
        else
                num_not_ok=$((num_not_ok + 1))
        fi
done

if [[ $num_not_ok -ne 0 ]]; then
        echo "*************************************************************"
        echo "FAILED: Not all clusters have responded with an 'OK' message!"
        echo "*************************************************************"
        #failed_checks=`cat cluster_health.txt | tail -n +8 | head -n -1 | grep -v OK`
        echo "Failed Groups:"
        cat cluster_health.txt | tail -n +5 | grep -v OK
        rm cluster_health.txt
        exit 1
else
        echo "*************************************"
        echo "*All clusters reporting OK from VCS!*"
        echo "*************************************"
        rm cluster_health.txt
fi
