#!/bin/bash
#set -e

function set_environment() {
    local path_env='export PATH=$GAUSSHOME/bin:$PATH'
    local ld_env='export LD_LIBRARY_PATH=$GAUSSHOME/lib:$LD_LIBRARY_PATH'
    local insert_line=2
    sed -i "/^\\s*export\\s*GAUSSHOME=/d" ~/.bashrc
    # set PATH and LD_LIBRARY_PATH
    if [ X"$(grep 'export PATH=$GAUSSHOME/bin:$PATH' ~/.bashrc)" == X"" ]
    then
        echo $path_env >> ~/.bashrc
    fi
    if [ X"$(grep 'export LD_LIBRARY_PATH=$GAUSSHOME/lib:$LD_LIBRARY_PATH' ~/.bashrc)" == X"" ]
    then
        echo $ld_env >> ~/.bashrc
    fi
    if [ X"$(grep 'export GS_CLUSTER_NAME=dbCluster' ~/.bashrc)" == X"" ]
    then
        echo 'export GS_CLUSTER_NAME=dbCluster' >> ~/.bashrc
    fi
    if [ X"$(grep 'ulimit -n 1000000' ~/.bashrc)" == X"" ]
    then
        echo 'ulimit -n 1000000' >> ~/.bashrc
    fi
    # set GAUSSHOME
    path_env_line=$(cat ~/.bashrc | grep -n 'export PATH=$GAUSSHOME/bin:$PATH' | awk -F ':' '{print $1}')
    ld_env_line=$(grep -n 'export LD_LIBRARY_PATH=$GAUSSHOME/lib:$LD_LIBRARY_PATH' ~/.bashrc | awk -F ':' '{print $1}')
    echo
    if [ $path_env_line -gt $ld_env_line ]
    then
        let insert_line=$ld_env_line
    else
        let insert_line=$path_env_line
    fi
    sed -i "$insert_line i\export GAUSSHOME=/opt/software/openGauss" ~/.bashrc
    source ~/.bashrc
}
set_environment