#!/usr/bin/env bash

BASEDIR=`dirname $0`

. ${BASEDIR}/../functions
source ${BASEDIR}/../common_variables.conf

CLI_APP=${ENM_UTILS_PATH}/bin/cli_app

setup_cmcli_aliases(){
    if[ -f ${CLI_APP} ]
        for ENTRY in ${ALIASES}; do

            ALIAS=${ENTRY} | cut -d':' -f1
            COMMAND=${ENTRY} | cut -d':' -f2

            ${CLI_APP} "alias \"${ALIAS}\" \"${COMMAND}\""
        done
}

setup_cmcli_aliases
