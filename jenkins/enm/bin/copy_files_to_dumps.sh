/bin/bash

copy_files_to_dumps_dir() {
    echo "$FUNCNAME - $(date)"
    REPODIR=${BASENAME}/../dumps_dir
    DUMPSDIR=/ericsson/enm/dumps/.scripts
    /bin/mkdir -p ${DUMPSDIR}
    # Copy everything from the dumps_dir in repo to dumps on MS
    FILES=`ls ${REPODIR}`
    for FILE in ${FILES}
    do
        /bin/cp $REPODIR/${FILE} ${DUMPSDIR}
        chmod 755 ${DUMPSDIR}/*
    done
}

copy_files_to_dumps_dir
