#!/bin/bash

CELLDUMPFILE="/netsim_users/pms/etc/celldumpfile"
EUTRANCELLFILE="/netsim_users/pms/etc/eutrancellfdd_list.txt"

_parse_dump_file() {
    if [ -e "$EUTRANCELLFILE" ]; then rm $EUTRANCELLFILE; fi
    grep EUtranCellFDD "$1" | grep -v dumpmotree |
    awk -F= '{print$2}' | 
    while read CELL
    do
        NODE=`echo $CELL | awk -F- '{print $1}'`
        case "$NODE" in
            *dg2*|*pERBS* ) echo "SubNetwork=NETSimW,ManagedElement=$NODE,ENodeBFunction=1,EUtranCellFDD=${CELL}" >> "$2";;
            * ) echo "$(grep -A1 'MIB prefix' "$1" | grep $NODE),ManagedElement=1,ENodeBFunction=1,EUtranCellFDD=${CELL}" >> "$2";;
        esac
    done
}

if egrep -v '^Sub' "$EUTRANCELLFILE" || [ "$1" == "refresh" ]
then
    if [ -e "$CELLDUMPFILE" ]; then rm $CELLDUMPFILE; fi
    ls /netsim/netsimdir | 
    sed -n 's/\(.*\)\.zip/\1/p' | 
    while read SIM
    do
        echo -e '.select network\nstatus;\ndumpmotree:motypes="EUtranCellFDD,Lrat:EUtranCellFDD,MSRBS_V1_eNodeBFunction:EUtranCellFDD";' | 
        /netsim/inst/netsim_pipe -sim $SIM -v | 
        tee -a $CELLDUMPFILE
    done
    _parse_dump_file "$CELLDUMPFILE" "$EUTRANCELLFILE"
fi
