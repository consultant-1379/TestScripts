#!/bin/bash

create_snapshot() {
    /opt/ericsson/enminst/bin/enm_snapshots.bsh --action remove_snapshot
    /opt/ericsson/enminst/bin/enm_snapshots.bsh --action create_snapshot
}

create_snapshot
