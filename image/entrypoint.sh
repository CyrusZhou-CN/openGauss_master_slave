#!/bin/bash
#set -e
if [[ ! -f "$GAUSSHOME/data/isconfig" ]]; then
    chown -R omm:dbgrp /opt/software/openGauss/data
    chown -R omm:dbgrp /opt/software/openGauss/logs
    chmod -R 0700 /opt/software/openGauss/data
    chmod -R 0700 /opt/software/openGauss/logs
fi
su omm -s /bin/bash -c '/bin/bash /opt/software/app.sh'