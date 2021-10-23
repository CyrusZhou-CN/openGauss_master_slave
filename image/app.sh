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

GAUSS_PORT=5432
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
    echo "check $name"
    echo "CMD:$cmd"
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
            # 打印进度,#docker LOGS 中进度条不刷新
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
    get_HOST_NAMES_IP
    if [[ ! -f "$GAUSSHOME/data/isconfig" ]]; then        
        rm -rf $GAUSSHOME/data
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

        gs_guc set -D $GAUSSHOME/data -c "port = ${GAUSS_PORT}"  \
        -c "listen_addresses = '*'" \
        -c "local_bind_address = '0.0.0.0'"  \
        -c "most_available_sync = on"  \
        -c "pgxc_node_name = '${HOSTNAME}'"  \
        -c "wal_level = logical"  \
        -c "password_encryption_type= 0"  \
        -c "synchronous_standby_names='*'"  \
        -c "max_wal_senders=16"  \
        -c "max_replication_slots=9"  \
        -c "wal_sender_timeout=0s" \
        -c "wal_receiver_timeout=0s"\
        -c "most_available_sync = on" \
        -c "remote_read_mode = off" \
        -c "application_name = '$HOSTNAME'" \
        -c "remote_read_mode = non_authentication"

        echo "enable_numa = false" >> "$GAUSSHOME/data/mot.conf"
        i=1
        if [[ -z $IP_CLUSTER_ARR ]]; then
            IP_CLUSTER_ARR="127.0.0.1"
        fi
        local len=$(($PEER_NUM - 1))
        for i in $(seq 0 ${len}); do
            gs_guc set -D $GAUSSHOME/data -c "replconninfo$(($i+1)) = 'localhost=${ip_arr[0]} localport=$(($GAUSS_PORT+1)) localheartbeatport=$(($GAUSS_PORT+5)) localservice=$(($GAUSS_PORT+4))  remotehost=${IP_CLUSTER_ARR[$i]} remoteport=$(($GAUSS_PORT+1)) remoteheartbeatport=$(($GAUSS_PORT+5)) remoteservice=$(($GAUSS_PORT+4))'"
        done
        
        #   TYPE    DATABASE        USER            ADDRESS          METHOD
        #   host    all             all             10.8.0.0/24      trust
        #   host    all             all             0.0.0.0/0        sha256
        #   host    all             all             10.8.0.0/24      trust
        gs_guc set -D $GAUSSHOME/data -h "host all $GAUSS_USER 0.0.0.0/0  md5"
        for subnet in $subnet_arr;do
            gs_guc set -D $GAUSSHOME/data -h "host all omm $subnet/24  trust"
        done
        echo "[step 3]: start single_node." 
        gs_ctl start -D $GAUSSHOME/data  -Z single_node -l logfile
        echo "[step 4]: CREATE USER $GAUSS_USER." 
        gsql -d postgres -c "CREATE USER $GAUSS_USER WITH SYSADMIN CREATEDB USEFT CREATEROLE INHERIT LOGIN REPLICATION IDENTIFIED BY '$GAUSS_PASSWORD';"
        echo "[step 5]: stop single_node." 
        gs_ctl stop -D $GAUSSHOME/data
        echo "[step 6]:first Start OpenGauss"
        first_Start_OpenGauss
        echo "[step 7]:change etcd config"
        set_etcd_config
        echo "[step 8]:change patroni config"
        set_patroni_config
        echo -e "\033[32m **********************Open Gauss initialization completed*************************\033[0m"        
        echo $(date) "- init ok" > $GAUSSHOME/data/isconfig
    fi
}


# 生成 IP_CLUSTER_ARR, CLUSTER_HOSTNAME_ARR
# 用 environment 设置: HOST_NAMES
get_HOST_NAMES_IP () {
    echo "----set HOST NAMES IP-----"
    HOST_NAMES_ARR=(${HOST_NAMES//,/ })
    IP_CLUSTER_ARR=()
    CLUSTER_HOSTNAME_ARR=()
    local len_hosts=${#HOST_NAMES_ARR[*]}
    echo "len_hosts:$len_hosts"
    set +e
    for i in $(seq 0 $(($len_hosts - 1))); do
        while :
        do
            local tempip=`host ${HOST_NAMES_ARR[$i]} | grep -Eo "[0-9]+.[0-9]+.[0-9]+.[0-9]+"`
            if [ -n "$tempip" ]; then            
                echo 'HOST_NAMES_ARR:'${HOST_NAMES_ARR[$i]}
                IP_CLUSTER_ARR[$i]="$tempip"
                CLUSTER_HOSTNAME_ARR[$i]=${HOST_NAMES_ARR[$i]}                    
                echo "HOST_NAME:${HOST_NAMES_ARR[$i]} HOST_IP:$tempip"
                break
            else
                sleep 1s
            fi
        done
    done
    set -e
    PEER_NUM=$len_hosts
    echo "export STANDBY_NUM=$PEER_NUM" >> $SOFT_HOME/.bashrc
}

get_ETCD_INITIAL_CLUSTER () {
    echo "----get_ETCD_INITIAL_CLUSTER-----"
    ETCD_INITIAL_CLUSTER="${HOSTNAME}=http://${HOST_IP}:2380"
    local len=$(($PEER_NUM - 1))
    for i in $(seq 0 ${len}); do
            echo "${i}  ${CLUSTER_HOSTNAME_ARR[$i]}  ${IP_CLUSTER_ARR[$i]}"
            ETCD_INITIAL_CLUSTER="${ETCD_INITIAL_CLUSTER},${CLUSTER_HOSTNAME_ARR[$i]}=http://${IP_CLUSTER_ARR[$i]}:2380"
    done
    echo "ETCD_INITIAL_CLUSTER:$ETCD_INITIAL_CLUSTER"
}

set_etcd_config() {
    get_ETCD_INITIAL_CLUSTER
    sed -i "/^data-dir:/c\data-dir: $SOFT_HOME/default.etcd" $SOFT_HOME/etcd.conf && \
    sed -i "/^name:/c\name: ${HOSTNAME}" $SOFT_HOME/etcd.conf && \
    sed -i "/^listen-peer-urls:/c\listen-peer-urls: http:\/\/${HOST_IP}:2380" $SOFT_HOME/etcd.conf && \
    sed -i "/^initial-advertise-peer-urls:/c\initial-advertise-peer-urls: http:\/\/${HOST_IP}:2380" $SOFT_HOME/etcd.conf && \
    sed -i "/^advertise-client-urls:/c\advertise-client-urls: http:\/\/${HOST_IP}:2379" $SOFT_HOME/etcd.conf && \
    sed -i "/^listen-client-urls:/c\listen-client-urls: http:\/\/${HOST_IP}:2379" $SOFT_HOME/etcd.conf && \
    sed -i "/^initial-cluster:/c\initial-cluster: ${ETCD_INITIAL_CLUSTER}" $SOFT_HOME/etcd.conf && \
    sed -i "/^initial-cluster-token:/c\initial-cluster-token: 'cluster1'" $SOFT_HOME/etcd.conf
    
    if [ -n "${INITIAL_CLUSTER_STATE}" ] && [ "${INITIAL_CLUSTER_STATE}" == "existing" ]; then
        sed -i "/^initial-cluster-state:/c\initial-cluster-state: 'existing'" $SOFT_HOME/etcd.conf
    fi
}

get_ETCD_HOSTS () {
    ETCD_HOSTS="${HOST_IP}:2379"
    for i in $(seq 0 $len); do
        ETCD_HOSTS="${ETCD_HOSTS},${IP_CLUSTER_ARR[$i]}:2379"
    done
}

set_patroni_config() {
    get_ETCD_HOSTS        
    sed -i "s/^name: name/name: $HOSTNAME/" $SOFT_HOME/patroni.yaml && \
    sed -i "s/^  listen: localhost:8008/  listen: $HOST_IP:8008/" $SOFT_HOME/patroni.yaml && \
    sed -i "s/^  connect_address: localhost:8008/  connect_address: $HOST_IP:8008/" $SOFT_HOME/patroni.yaml && \
    sed -i "s/^  host: localhost:2379/  hosts: $ETCD_HOSTS/" $SOFT_HOME/patroni.yaml && \
    sed -i "s/^  listen: localhost:16000/  listen: $HOST_IP:$GAUSS_PORT/" $SOFT_HOME/patroni.yaml && \
    sed -i "s#^  data_dir: /var/lib/opengauss/data#  data_dir: $GAUSSHOME/data#" $SOFT_HOME/patroni.yaml && \
    sed -i "s#^  bin_dir: /usr/local/opengauss/bin#  bin_dir: $GAUSSHOME/bin#" $SOFT_HOME/patroni.yaml && \
    sed -i "s#^  config_dir: /var/lib/opengauss/data#  config_dir: $GAUSSHOME/data#" $SOFT_HOME/patroni.yaml && \
    sed -i "s#^  custom_conf: /var/lib/opengauss/data/postgresql.conf#  custom_conf: $GAUSSHOME/data/postgresql.conf#" $SOFT_HOME/patroni.yaml && \
    sed -i "s/^  connect_address: localhost:16000/  connect_address: $HOST_IP:$GAUSS_PORT/" $SOFT_HOME/patroni.yaml && \
    sed -i "s/^      username: superuser/      username: $GAUSS_USER/" $SOFT_HOME/patroni.yaml && \
    sed -i "s/^      password: superuser_123/      password: $GAUSS_PASSWORD/" $SOFT_HOME/patroni.yaml && \
    sed -i "s/^      username: repl/      username: $GAUSS_USER/" $SOFT_HOME/patroni.yaml && \
    sed -i "s/^      password: repl_123/      password: $GAUSS_PASSWORD/" $SOFT_HOME/patroni.yaml && \
    sed -i "s/^      username: rewind/      username: $GAUSS_USER/" $SOFT_HOME/patroni.yaml && \
    sed -i "s/^      password: rewind_123/      password: $GAUSS_PASSWORD/" $SOFT_HOME/patroni.yaml
}

function set_environment() {    
    local path_env='export PATH=$GAUSSHOME/bin:$PATH:/home/omm/venv/bin'
    local ld_env='export LD_LIBRARY_PATH=$GAUSSHOME/lib:$LD_LIBRARY_PATH'
    local insert_line=2
    sed -i "/^\\s*export\\s*GAUSSHOME=/d" ~/.bashrc
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
    if [ X"$(grep 'export SOFT_HOME=/opt/software' ~/.bashrc)" == X"" ]
    then
        echo 'export SOFT_HOME=/opt/software' >> ~/.bashrc
    fi
    
    path_env_line=$(cat ~/.bashrc | grep -n 'export PATH=$GAUSSHOME/bin:$PATH' | awk -F ':' '{print $1}')
    ld_env_line=$(grep -n 'export LD_LIBRARY_PATH=$GAUSSHOME/lib:$LD_LIBRARY_PATH' ~/.bashrc | awk -F ':' '{print $1}')
    echo
    if [ $path_env_line -gt $ld_env_line ]
    then
        let insert_line=$ld_env_line
    else
        let insert_line=$path_env_line
    fi
    sed -i "$insert_line i\export GAUSSHOME=\$SOFT_HOME/openGauss" ~/.bashrc
    HOST_IP=$(ip addr | awk '/^[0-9]+: / {}; /inet.*global/ {print gensub(/(.*)\/(.*)/, "\\1", "g", $2)}')
    HOSTNAME=$(cat /etc/hostname)
    echo "export HOSTNAME=$HOSTNAME" >> ~/.bashrc
    echo "export HOST_IP=$HOST_IP" >> ~/.bashrc
    source ~/.bashrc
}

first_Start_OpenGauss() {
    echo -e "\033[32m ==> First Start OpenGauss $RUN_MODE  <== \033[0m"
    set +e
    while :
    do
        if [ $RUN_MODE == "master" ]; then
            echo -e "\033[32m ==> Start OpenGauss primary  <== \033[0m"
            gs_ctl restart -D "$GAUSSHOME/data" -M primary
        else 
            echo -e "\033[32m ==> Start OpenGauss standby  <== \033[0m"
            gs_ctl restart -D "$GAUSSHOME/data" -M standby
            gs_ctl build -D "$GAUSSHOME/data" -b full
        fi
        if [ $? -eq 0 ]; then
            break
        else
            echo -e "\033[31m ==> errcode=$?\033[0m"
            echo -e "\033[31m ==>build failed\033[0m"
            sleep 1s
        fi
    done
    if [ $RUN_MODE == "master" ]; then
        local -i count=0
        echo -e "\033[32m ==> Wait for the slave to completed  <== \033[0m"
        local len=$(($PEER_NUM - 1))
        for i in $(seq 0 ${len}); do
            checkStart "Check ${CLUSTER_HOSTNAME_ARR[$i]}" "echo start | telnet ${CLUSTER_HOSTNAME_ARR[$i]} 2380 | grep -c Connected" 1200
            let count=$count+1
        done
        #checkStart "check master" "echo start | gs_ctl query -D $GAUSSHOME/data | grep -c sync_percent | grep -c $count" 1200
    fi
    sleep 1s
    echo -e "\033[32m ==> Stop:first Start OpenGauss <== \033[0m"
    gs_ctl -D "$GAUSSHOME/data" -m fast -w stop
    set -e
}

function start_db(){
    echo -e "\033[32m ==> Start $(etcd --version | grep etcd) Server... \033[0m"
    etcd --config-file $SOFT_HOME/etcd.conf > $SOFT_HOME/etcd.log 2>&1 &
    echo -e "\033[32m ==> Start $(patroni --version) Server... \033[0m"
    # 实时输出日志
    #exec patroni  $SOFT_HOME/patroni.yaml  2>&1 | tee $SOFT_HOME/patroni.log 
    # 日志后台记录
    patroni $SOFT_HOME/patroni.yaml > $SOFT_HOME/patroni.log 2>&1 &    
    echo -e "\033[32m ==>$(gaussdb -V)<== \033[0m"
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
    #gs_ctl query -D $GAUSSHOME/data
    checkStart "Wait for all hosts to run OpenGauss" "echo start | patronictl -c $SOFT_HOME/patroni.yaml list | grep -c running | grep -c $(($PEER_NUM + 1))" 1200
    echo -e "\033[32m **********************Patroni List*************************\033[0m"
    patronictl -c $SOFT_HOME/patroni.yaml list
    echo -e "\033[32m ===========================================================\033[0m"
    netstat -tunlp
}
echo "==> START Service ..."

set_environment
init_db
start_db
status_db
echo -e "\033[32m ==> START Service SUCCESSFUL ... \033[0m"
tail -f /dev/null &
waitterm

echo -e "\033[31m ==> STOP Service\033[0m"
stop_db
echo -e "\033[31m ==> STOP Service SUCCESSFUL ...\033[0m"