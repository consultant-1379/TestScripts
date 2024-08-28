#!/bin/bash

# Turn on that we do not want to check create command responses
#sed -i 's/skip_create_cmd_validation = false/skip_create_cmd_validation = true/g' /opt/ericsson/enmutils/.env/lib/python2.7/site-packages/enmutils/etc/properties.conf

set -ex
/opt/ericsson/enmutils/bin/node_populator create rvb-network --identity --verbose

/opt/ericsson/enmutils/bin/workload add rvb-network

# Enable FM and SHM management
/opt/ericsson/enmutils/bin/cli_app "cmedit set * InventorySupervision active=true"
