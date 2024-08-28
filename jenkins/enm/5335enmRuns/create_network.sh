#!/bin/bash
/opt/ericsson/enmutils/bin/workload remove all

set -ex
/opt/ericsson/enmutils/bin/node_populator create rvb-network --verbose
/opt/ericsson/enmutils/bin/workload add rvb-network

