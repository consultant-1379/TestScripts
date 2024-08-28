#!/bin/bash

LITPADMIN_OLD=passw0rd
LITPADMIN_NEW=12shroot
ROOT_OLD=litpc0b6lEr
ROOT_NEW=12shroot

reset_host_password()
{
    local _hn_=$1
    local _kh_=${HOME}/.ssh/known_hosts
    grep -E "^${_hn_},.*" ${_kh_} > /dev/null 2>&1
    if [ $? -eq 0 ] ; then
        sed -i "/^${_hn_},.*/d" ${_kh_}
        echo "Removed ${_hn_} from ${_kh_}"
    fi
    python reset_passwords.py --hostname=${_hn_} --litpadmin_old=${LITPADMIN_OLD} --litpadmin_new=${LITPADMIN_NEW} --root_old=${ROOT_OLD} --root_new=${ROOT_NEW} 2>&1
}

if [ "${1}" ] ; then
    reset_host_password "${1}"
else
    _cpath_="/deployments/enm/clusters"
    for _cluster_ in `litp show -p ${_cpath_} | grep -E "\s+/.*$"| tr -d ' /'` ; do
        _basepath_="${_cpath_}/${_cluster_}/nodes"
        for _node_ in `litp show -p ${_basepath_} | grep -E "\s+/.*$" | tr -d ' /'` ; do
            _hostname_=`litp show -p ${_basepath_}/${_node_} | grep "hostname:" | awk -F: '{print $2}' | tr -d ' '`
            reset_host_password "${_hostname_}"
        done
    done
fi

python reset_passwords.py --enable_root_ssh
