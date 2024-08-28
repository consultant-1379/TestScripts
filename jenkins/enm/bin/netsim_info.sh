#!/bin/bash

netsim=$1
echo
echo -en "\e[0;32m${netsim}\n==================\n\e[0m"

ssh  -o StrictHostKeyChecking=no root@${netsim} "
        echo
        echo -e "\""\e[0;35mGenstats Healthcheck, sa1 & sa2 cron details:\e[0m\t"\""| sed 's/^/\t/g'
        echo 'Genstats HC' | sed 's/^/\t\t/g'
        grep 'genstat_report.sh' /var/spool/cron/tabs/netsim  | sed 's/^/\t\t/g'
        echo -e '\nsa1 & sa2 crons under crontab' | sed 's/^/\t\t/g'
        grep sa[12] /var/spool/cron/tabs/root  | sed 's/^/\t\t/g'
        echo -e '\nsa1 and sa2 crons under /etc/cron.d/sysstat' | sed 's/^/\t\t/g'
        grep "\""sa[12]"\"" /etc/cron.d/sysstat | sed 's/^/\t\t/g'
"

ssh  -o StrictHostKeyChecking=no netsim@${netsim} "
        echo -en "\""\e[0;35m\nNetsim Version:\e[0m\t"\"" | sed 's/^/\t/g';
        cat /netsim/simdepContents/netsimVersionFromPortal;

        echo -en "\""\e[0;35mNSS Version:\e[0m\t"\"" | sed 's/^/\t/g';
        cat /netsim/simdepContents/nssProductSetVersion;

        echo -en "\""\e[0;35mNRM Version:\e[0m\t"\""| sed 's/^/\t/g';
        cat /netsim/simdepContents/NRMDetails | paste - - ;

        echo -en "\""\e[0;35mNRM Size:\e[0m\t"\""| sed 's/^/\t/g';
        cat /netsim/simdepContents/NRMSize.content;

        echo -en "\""\e[0;35mOTP Version:\e[0m\t"\""| sed 's/^/\t/g';
        cat /netsim/inst/platf_indep_otp/erlang_otp_used

        echo -en "\""\e[0;35mGenStats RPM:\e[0m\t"\""| sed 's/^/\t/g';
        grep ERICnetsimpmcpp /netsim_users/pms/logs/periodic_healthcheck.log | tail -1 | grep -oP genStats.*
        #Or run script: /netsim_users/pms/bin/genStatsRPMVersion.sh

        echo
        echo -en "\""\e[0;35mNetsim Uptime:\e[0m\t"\""| sed 's/^/\t/g';
        uptime

        echo
        echo -e "\""\e[0;35mOldest Prmnresponse_xxxx.resp file on netsim:\e[0m\t"\""| sed 's/^/\t/g';
        ls -ltr /netsim/inst/prmnresponse/ | head -2 | grep -v total | sed 's/^/\t\t/g';
        echo -e "\""\e[0;35mPrmnresponse retention time in /netsim/.bashrc file:\e[0m\t"\""| sed 's/^/\t/g';
        ls -l /netsim/.bashrc | sed 's/^/\t\t/g';
        cat /netsim/.bashrc | sed 's/^/\t\t/g';

        echo
        echo -e "\""\e[0;35mList of simulations:\e[0m\t"\""| sed 's/^/\t/g';
        ls -ltr /netsim/netsim_dbdir/simdir/netsim/netsimdir/ | awk '{print $NF}' | grep -v total | sed 's/^/\t\t/g';

        echo
        echo -e "\""\e[0;35mList of Erlang Crashes:\e[0m\t"\""| sed 's/^/\t/g';
        ls -ltr /netsim/inst/ | grep erl_crash* | sed 's/^/\t\t/g';

        echo
        echo -e "\""\e[0;35mNetsim Patch Info:\e[0m"\""| sed 's/^/\t/g';
        #echo ".show patch info" | /netsim/inst/netsim_shell | sed 's/^/\t\t/g'
        cat /netsim/inst/installation_report | sed 's/^/\t\t/g'
        echo

        echo
        echo -e "\""\e[0;35mNetsim Disk Usage:\e[0m\t"\""| sed 's/^/\t/g';
        df -hP | sed 's/^/\t\t/g'

        echo
        echo -e "\""\e[0;35mCurrent CPU Usage:\e[0m\t"\""| sed 's/^/\t/g';
        sar -u 2 5 | sed 's/^/\t\t/g';

        echo
        echo -e "\""\e[0;35mServer Load Config:\e[0m\t"\""| sed 's/^/\t/g';
        echo ".show serverloadconfig" | /netsim/inst/netsim_shell | sed 's/^/\t\t/g'

        echo
        echo -e "\""\e[0;35mGenstats Periodic Healthcheck Info:\e[0m"\""| sed 's/^/\t/g';
        #/netsim_users/hc/bin/genstat_report.sh -p true
        cat /netsim_users/pms/logs/periodic_healthcheck.log | tail -14 | sed 's/^/\t\t/g'
        echo
"

echo -e "\e[0;35mChecking for any stopped nodes:\e[0m\t"| sed 's/^/\t/g';

        SIMS_NOT_STARTED=$(ssh -o StrictHostKeyChecking=no netsim@${netsim} "echo '.show allsimnes' | /netsim/inst/netsim_shell | grep 'not started' | cut -d' ' -f1")

        if [[ ${SIMS_NOT_STARTED} == "" ]] ;
        then
                echo "INFO: All nodes are successfully started." | sed 's/^/\t\t/g'
        else
                echo "ERROR: The following nodes are not started. Please check" | sed 's/^/\t\t/g'
                echo ${SIMS_NOT_STARTED} | sed 's/^/\t\t\t/g'
        fi

        echo

#Netsim Kernel messages:
#for i in `grep kernel /var/log/messages|awk '{print $NF}'|sort | uniq`; do grep kernel /var/log/messages|grep "${i}$" | tail -5;done | sort -nk2

#* * * * * /netsim_users/hc/bin/genstat_report.sh -p true >> /netsim_users/pms/logs/periodic_healthcheck.log 2>&1

#Check crons on netsims
#for i in {01..05};do echo ieatnetsimv5004-$i;ssh root@ieatnetsimv5004-$i 'echo genstats;grep genstat_report.sh /var/spool/cron/tabs/netsim;echo -e "\nroot cron";grep sa[12] /var/spool/cron/tabs/root;echo -e "\nsysstat";grep sa[12] /etc/cron.d/sysstat';echo;done

#Established TCP connections
#lsof | grep -c "TCP.*ESTABLISHED"

#lsof| grep "netconf-tls.*ESTABLISHED" -c
#beam.smp  44668     netsim  136u     IPv4           15336476      0t0        TCP 10.154.208.214:netconf-tls->ieatENM5404-67.athtem.eei.ericsson.se:60064 (ESTABLISHED)
#beam.smp  44988     netsim   25u     IPv6           15250665      0t0        TCP [fd70:e1dd:bbc4:42:53::10f]:netconf-tls->ieatENM5404-115.athtem.eei.ericsson.se:53138 (ESTABLISHED)

#Netsim Healthcheck
#/var/simnet/HC/enm-ni-simdep/scripts/netsimHealthCheck.sh