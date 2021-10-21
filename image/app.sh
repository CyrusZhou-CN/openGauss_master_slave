#!/bin/bash
#set -e

source /etc/profile
# default config
if [ -z "${GAUSS_PASSWORD}" ]; then
    echo "Error: No PASSWORD environment"
    exit 0
fi
if [ -z "${GAUSS_USER}" ]; then
    echo "Error: No GAUSS USER environment"
    exit 0
fi
if [ -z "${NODE_NAME}" ]; then
    echo "Error: No NODE_NAME environment"
    exit 0
fi

if [ -z "${RUN_MODE}" ]; then
    echo "Error: No RUN_MODE environment"
    exit 0
fi

port=5432
waitterm() {
        local PID
        # any process to block
        tail -f /dev/null &
        PID="$!"
        # setup trap, could do nothing, or just kill the blocker
        trap "kill -TERM ${PID}" TERM INT
        # wait for signal, ignore wait exit code
        wait "${PID}" || true
        # clear trap
        trap - TERM INT
        # wait blocker, ignore blocker exit code
        wait "${PID}" 2>/dev/null || true
}

function checkStart() {
    local name=$1
    local cmd=$2
    local timeout=$3
    #隐藏光标
    printf "\e[?25l" 
    i=0
    str=""
    bgcolor=43
    space48="                       "    
    echo "$name check ... [$cmd]"
    isrun=0
    while [ $timeout -gt 0 ]
    do
        ST=`eval $cmd`
        if [ "$ST" -gt 0 ]; then
            isrun=1
            break
        else
            percentstr=$(printf "%3s" $i)
            totalstr="${space48}${percentstr}${space48}"
            leadingstr="${totalstr:0:$i+1}"
            trailingstr="${totalstr:$i+1}"
            #打印进度,#docker中进度条不刷新
            printf "\r\e[30;47m${leadingstr}\e[37;40m${trailingstr}\e[0m"
            let i=$i+1
            str="${str}="
            sleep 1
            let timeout=$timeout-1
        fi
    done
    echo ""
    if [ $isrun == 1 ]; then
        echo -e "\033[32m $name start successful \033[0m" 
    else
        echo -e "\033[31m $name start timeout \033[0m"
    fi
    #显示光标
    printf "\e[?25h""\n"
}

function init_db() {
    if [[ ! -f "$GAUSSHOME/data/isconfig" ]]; then
        echo "[step 1]: init data node"    
        gs_initdb -D $GAUSSHOME/data --nodename=$NODE_NAME -E UTF-8 --locale=en_US.UTF-8 -U omm  -w $GAUSS_PASSWORD
        echo "[step 2]: config datanode."    
        local -a ip_arr
        local -i index=0
        local -a subnet_arr
        for line in $(/sbin/ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $2}'|tr -d "addr:")
        do
            ip_arr[index]=$line
            subnet_arr[index]=$(echo $line | sed 's/\([0-9]*\.[0-9]*\.[0-9]*\.\)[0-9]*/\10/')
            let index=$index+1
        done
        #清除数组重复值
        subnet_arr=($(echo ${subnet_arr[*]} | sed 's/ /\n/g' | sort |uniq))
        sed -i "/^#listen_addresses/c\listen_addresses = '*'"  $GAUSSHOME/data/postgresql.conf
        sed -i "/^#port/c\port = $port"  $GAUSSHOME/data/postgresql.conf
        sed -i "/^#local_bind_address/c\local_bind_address = '0.0.0.0'"  $GAUSSHOME/data/postgresql.conf
        sed -i "/^#most_available_sync/c\most_available_sync = on"  $GAUSSHOME/data/postgresql.conf
        sed -i "/^pgxc_node_name/c\pgxc_node_name = opengauss_master"  $GAUSSHOME/data/postgresql.conf
        sed -i "/^wal_level/c\wal_level = logical"  $GAUSSHOME/data/postgresql.conf
        sed -i "/^#password_encryption_type/c\password_encryption_type = 0"  $GAUSSHOME/data/postgresql.conf
        i=1
        if [[ -z $REMOTEHOST ]]; then
            REMOTEHOST="127.0.0.1"
        fi

        for server in $REMOTEHOST; do
            echo "replconninfo$i = 'localhost=${ip_arr[0]} localport=$(($port+1)) localheartbeatport=$(($port+5)) localservice=$(($port+4))  remotehost=${server} remoteport=$(($port+1)) remoteheartbeatport=$(($port+5)) remoteservice=$(($port+4))'" | tee -a $GAUSSHOME/data/postgresql.conf
            let i=$i+1            
        done
        ADDRESS=$(echo ${ip_arr[0]} | sed 's/\([0-9]*\.[0-9]*\.[0-9]*\.\)[0-9]*/\10/')
        echo "remote_read_mode = non_authentication" | tee -a $GAUSSHOME/data/postgresql.conf
        #     TYPE    DATABASE        USER            ADDRESS          METHOD
        #echo "host    all             all             10.8.0.0/24          trust" | tee -a $GAUSSHOME/data/pg_hba.conf
        #echo "host    all             all             0.0.0.0/0            sha256"| tee -a $GAUSSHOME/data/pg_hba.conf
        #echo "host    all             all             10.8.0.0/24          trust"| tee -a $GAUSSHOME/data/pg_hba.conf
        echo "host    all             $GAUSS_USER      0.0.0.0/0            md5"| tee -a $GAUSSHOME/data/pg_hba.conf
        for subnet in $subnet_arr;do
            echo "host    all             omm             $subnet/24          trust"| tee -a $GAUSSHOME/data/pg_hba.conf
        done
        echo "[step 3]: start single_node." 
        gs_ctl start -D $GAUSSHOME/data  -Z single_node -l logfile
        echo "[step 4]: CREATE USER $GAUSS_USER." 
        gsql -d postgres -c "CREATE USER $GAUSS_USER WITH SYSADMIN CREATEDB USEFT CREATEROLE INHERIT LOGIN REPLICATION IDENTIFIED BY '$GAUSS_PASSWORD';"
        echo "[step 5]: stop single_node." 
        gs_ctl stop -D $GAUSSHOME/data
        echo "ok" > $GAUSSHOME/data/isconfig
    fi
}
function start_db(){
    echo $RUN_MODE 
    if [ $RUN_MODE == "master" ]; then
        echo "[start primary data node.]"
        gs_ctl start -D $GAUSSHOME/data -M primary
        local -i count=0
        for server in $REMOTEHOST; do
            checkStart "check $server" "echo start | telnet $server 5432 | grep -c Connected" 1200
            let count=$count+1    
        done
        checkStart "check master" "echo start | gs_ctl query -D $GAUSSHOME/data | grep -c sync_percent | grep -c $count" 1200
    else
        echo "[build and start slave data node.]"
        checkStart "check master" "echo start | telnet master 5432 | grep -c Connected" 1200        
        gs_ctl build -D $GAUSSHOME/data -b full
        checkStart "check slave" "echo start | gs_ctl query -D $GAUSSHOME/data | grep -c sync_percent" 1200
    fi
}

function stop_db(){
    if [ $RUN_MODE == "master"  ]; then
        echo "[start primary data node.]"
        gs_ctl stop -D $GAUSSHOME/data -M primary
    else
        echo "[build and start slave data node.]"
        gs_ctl stop -D $GAUSSHOME/data -M standby
    fi
    
}

function status_db(){
    ps ux | grep gaussdb
    gs_ctl query -D $GAUSSHOME/data
}

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

echo "==> START ..."

set_environment
init_db
start_db
status_db

echo -e "\033[32m ==> START SUCCESSFUL ... \033[0m"
netstat -tunlp
tail -f /dev/null &
# wait TERM signal
waitterm

echo "==> STOP"
stop_db
echo "==> STOP SUCCESSFUL ..."