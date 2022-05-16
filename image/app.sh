#!/bin/bash
#set -e

source /etc/profile
# default config
if [ -z "${GAUSS_PASSWORD}" ]; then
    echo "Error: No GAUSS_PASSWORD environment"
    echo "Example: -eGAUSS_PASSWORD=Gauss666"
    exit 0
fi
if [ -z "${GAUSS_USER}" ]; then
    echo "Error: No GAUSS_USER environment"
    echo "Example: -eGAUSS_USER=gauss"
    exit 0
fi
if [ -z "${RUN_MODE}" ]; then
    RUN_MODE="standard"
fi
if [ $RUN_MODE != "standard" ]; then
    if [ -z "${NODE_NAME}" ]; then
        echo "Error: No NODE_NAME environment"
        exit 0
    fi

    if [ -z "${HOST_NAMES}" ]; then
        echo "Error: No HOST_NAMES environment"
        exit 0
    fi
    if [ -z "${HOST_IPS}" ]; then
        echo "Error: No HOST_IPS environment"
        exit 0
    fi
fi
if [ -z "${SOFT_HOME}" ]; then
    SOFT_HOME=/opt/software
    GAUSSHOME=$SOFT_HOME/openGauss
fi

LOGS_HOME=$GAUSSHOME/logs
GAUSS_CONF=$GAUSSHOME/data/conf
GAUSS_DB=$GAUSSHOME/data/db

if [[ ! -d "$LOGS_HOME" ]]; then
    mkdir -p $LOGS_HOME
fi
if [[ ! -d "$GAUSS_CONF" ]]; then
    mkdir -p $GAUSS_CONF
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
    echo "check $name ..."
    echo "CMD: $cmd"
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
        return 0
    else
        echo -e "\033[31m $name start timeout \033[0m"
        return 1
    fi
    #显示光标
    printf "\e[?25h""\n"
}
function config_datanode(){
    if [ $RUN_MODE != "standard" ]; then    
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
    fi
    gs_guc set -D $GAUSS_DB -c "port = ${GAUSS_PORT}"  \
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
    if [ $RUN_MODE != "standard" ]; then
        i=1
        if [[ -z $IP_CLUSTER_ARR ]]; then
            IP_CLUSTER_ARR="127.0.0.1"
        fi
        local len=$(($PEER_NUM - 1))
        for i in $(seq 0 ${len}); do
            gs_guc set -D $GAUSS_DB -c "replconninfo$(($i+1)) = 'localhost=${ip_arr[0]} localport=$(($GAUSS_PORT+1)) localheartbeatport=$(($GAUSS_PORT+5)) localservice=$(($GAUSS_PORT+4))  remotehost=${IP_CLUSTER_ARR[$i]} remoteport=$(($GAUSS_PORT+1)) remoteheartbeatport=$(($GAUSS_PORT+5)) remoteservice=$(($GAUSS_PORT+4))'"
        done
        
        #   TYPE    DATABASE        USER            ADDRESS          METHOD
        #   host    all             all             10.8.0.0/24      trust
        #   host    all             all             0.0.0.0/0        sha256
        #   host    all             all             10.8.0.0/24      trust
    fi
    gs_guc set -D $GAUSS_DB -h "host all $GAUSS_USER 0.0.0.0/0  md5"
    if [ $RUN_MODE != "standard" ]; then
        for subnet in $subnet_arr;do
            gs_guc set -D $GAUSS_DB -h "host all omm $subnet/24  trust"
        done
    fi
}
function init_db() {    

    if [[ ! -f "$GAUSS_CONF/init_db" ]]; then
        if [[ ! -f "$GAUSS_DB/config_single_node" ]]; then
            rm -Rf $GAUSS_DB
            if [ $RUN_MODE != "standard" ]; then
                echo "[step 1]: init data node"
                gs_initdb -D $GAUSS_DB --nodename=$NODE_NAME -E UTF-8 --locale=en_US.UTF-8 -U omm  -w $GAUSS_PASSWORD
                config_datanode
                echo "enable_numa = false" >> "$GAUSS_DB/mot.conf"
                echo "[step 3]: start single_node." 
                gs_ctl start -D $GAUSS_DB  -Z single_node -l logfile
                echo "[step 4]: CREATE USER $GAUSS_USER." 
                gsql -d postgres -c "CREATE USER $GAUSS_USER WITH SYSADMIN CREATEDB USEFT CREATEROLE INHERIT LOGIN REPLICATION IDENTIFIED BY '$GAUSS_PASSWORD';"
                if [ $RUN_MODE == "master" ]; then
                    echo -e "\033[32m ********************** docker entrypoint initdb *************************\033[0m" 
                    # master 初始化数据库            
                    if [ "$GAUSS_DATABASE" ]; then
                        gsql -d postgres -c "CREATE DATABASE $GAUSS_DATABASE WITH OWNER = $GAUSS_USER ENCODING = 'UTF8' CONNECTION LIMIT = -1;"
                        # 字符串转小写
                        GAUSS_DATABASE=$(echo $GAUSS_DATABASE | tr 'A-Z' 'a-z')
                        for f in /docker-entrypoint-initdb.d/*; do
                            case "$f" in
                                *.sql) echo "[Entrypoint] running $f"; gsql -U $GAUSS_USER -W $GAUSS_PASSWORD -d $GAUSS_DATABASE -f "$f" && echo ;;
                                *)     echo "[Entrypoint] ignoring $f" ;;
                            esac
                            echo
                        done
                    fi
                fi
                echo $(date) "- single_node ok" > $GAUSS_DB/config_single_node
                set +e
                while :
                do
                    echo "[step 5]: stop single_node."
                    if [[ ! -f "$GAUSS_DB/postmaster.pid" ]]; then
                        # 防止服务已停止导致死循环
                        break
                    fi
                    gs_ctl -D $GAUSS_DB -m fast -w stop
                    if [ $? -eq 0 ]; then
                        break
                    else
                        echo -e "\033[31m ==> errcode=$?\033[0m"
                        echo -e "\033[31m ==>build failed\033[0m"
                        sleep 1s                        
                    fi
                done            
                set -e
                echo "[step 6]:first Start OpenGauss"
                first_Start_OpenGauss
            else
                echo "[step 1]: init data"
                gs_initdb -D $GAUSS_DB --nodename='single_node' -E UTF-8 --locale=en_US.UTF-8 -U omm  -w $GAUSS_PASSWORD
                config_datanode
                gs_ctl start -D $GAUSS_DB
                echo "[step 4]: CREATE USER $GAUSS_USER." 
                gsql -d postgres -c "CREATE USER $GAUSS_USER WITH SYSADMIN CREATEDB USEFT CREATEROLE INHERIT LOGIN REPLICATION IDENTIFIED BY '$GAUSS_PASSWORD';"
                echo -e "\033[32m ********************** docker entrypoint initdb *************************\033[0m" 
                # 初始化数据库            
                if [ "$GAUSS_DATABASE" ]; then
                    gsql -d postgres -c "CREATE DATABASE $GAUSS_DATABASE WITH OWNER = $GAUSS_USER ENCODING = 'UTF8' CONNECTION LIMIT = -1;"
                    # 字符串转小写
                    GAUSS_DATABASE=$(echo $GAUSS_DATABASE | tr 'A-Z' 'a-z')
                    for f in /docker-entrypoint-initdb.d/*; do
                        case "$f" in
                            *.sql) echo "[Entrypoint] running $f"; gsql -U $GAUSS_USER -W $GAUSS_PASSWORD -d $GAUSS_DATABASE -f "$f" && echo ;;
                            *)     echo "[Entrypoint] ignoring $f" ;;
                        esac
                        echo
                    done
                fi
            fi
        fi
        echo -e "\033[32m **********************Open Gauss initialization completed*************************\033[0m"        
        echo $(date) "- init ok" > $GAUSS_CONF/init_db
    else
        if [ $RUN_MODE != "standard" ]; then
            config_datanode
        fi
    fi
}

# 生成 IP_CLUSTER_ARR, CLUSTER_HOSTNAME_ARR
# 用 environment 设置: HOST_NAMES
get_HOST_NAMES_IP () {
    echo "----set HOST NAMES IP-----"    
    HOST_NAMES_ARR=(${HOST_NAMES//,/ })
    HOST_IPS_ARR=(${HOST_IPS//,/ })
    # 删除本机
    HOSTNAME=$(cat /proc/sys/kernel/hostname)
    HOST_NAMES_ARR=(${HOST_NAMES_ARR[*]/$HOSTNAME})    
    HOST_IPS_ARR=(${HOST_IPS_ARR[*]/$HOST_IP})

    IP_CLUSTER_ARR=()
    CLUSTER_HOSTNAME_ARR=()
    local len_hosts=${#HOST_NAMES_ARR[*]}
    echo "len_hosts:$len_hosts"
    set +e
    for i in $(seq 0 $(($len_hosts - 1))); do
        while :
        do
            tempip=${HOST_IPS_ARR[$i]}
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
    local len=$(($PEER_NUM - 1))
    ETCD_INITIAL_CLUSTER="${HOSTNAME}=http://${HOST_IP}:2380"
    CLIENT_URLS="http://${HOST_IP}:2379"
    for i in $(seq 0 ${len}); do        
        echo "${i}  ${CLUSTER_HOSTNAME_ARR[$i]}  ${IP_CLUSTER_ARR[$i]}"
        if [ -z "${ETCD_INITIAL_CLUSTER}" ]; then
            ETCD_INITIAL_CLUSTER="${CLUSTER_HOSTNAME_ARR[$i]}=http://${IP_CLUSTER_ARR[$i]}:2380"
            CLIENT_URLS="http://${IP_CLUSTER_ARR[$i]}:2379"
        else
            ETCD_INITIAL_CLUSTER="${ETCD_INITIAL_CLUSTER},${CLUSTER_HOSTNAME_ARR[$i]}=http://${IP_CLUSTER_ARR[$i]}:2380"
            CLIENT_URLS="${CLIENT_URLS},http://${IP_CLUSTER_ARR[$i]}:2379"
        fi
    done
    echo "ETCD_INITIAL_CLUSTER:$ETCD_INITIAL_CLUSTER"
}

set_etcd_config() {
    get_HOST_NAMES_IP
    get_ETCD_INITIAL_CLUSTER
    cp $SOFT_HOME/etcd.conf.sample $GAUSS_CONF/etcd.conf
    sed -i "/^data-dir:/c\data-dir: '$SOFT_HOME/default.etcd'" $GAUSS_CONF/etcd.conf
    sed -i "/^name:/c\name: '${HOSTNAME}'" $GAUSS_CONF/etcd.conf 
    sed -i "/^listen-peer-urls:/c\listen-peer-urls: 'http:\/\/0.0.0.0:2380'" $GAUSS_CONF/etcd.conf 
    sed -i "/^initial-advertise-peer-urls:/c\initial-advertise-peer-urls: 'http:\/\/${HOST_IP}:2380'" $GAUSS_CONF/etcd.conf 
    sed -i "/^advertise-client-urls:/c\advertise-client-urls: 'http://0.0.0.0:2379,http://0.0.0.0:4001'" $GAUSS_CONF/etcd.conf
    sed -i "/^listen-client-urls:/c\listen-client-urls: 'http://0.0.0.0:2379,http://0.0.0.0:4001'" $GAUSS_CONF/etcd.conf
    sed -i "/^initial-cluster:/c\initial-cluster: '${ETCD_INITIAL_CLUSTER}'" $GAUSS_CONF/etcd.conf
    sed -i "/^initial-cluster-token:/c\initial-cluster-token: 'cluster1'" $GAUSS_CONF/etcd.conf
    sed -i "/^log-level:/c\#log-level: debug" $GAUSS_CONF/etcd.conf
    sed -i "/^cors:/c\cors: '*'" $GAUSS_CONF/etcd.conf
}

get_ETCD_HOSTS () {
    ETCD_HOSTS="${HOST_IP}:2379"
    for i in $(seq 0 $len); do
        ETCD_HOSTS="${ETCD_HOSTS},${IP_CLUSTER_ARR[$i]}:2379"
    done
}

set_patroni_config() {
    get_ETCD_HOSTS
    cp $SOFT_HOME/patroni.yaml.sample $GAUSS_CONF/patroni.yaml
    sed -i "s/^name: name/name: $HOSTNAME/" $GAUSS_CONF/patroni.yaml
    sed -i "s/^  listen: localhost:8008/  listen: $HOST_IP:8008/" $GAUSS_CONF/patroni.yaml
    sed -i "s/^  connect_address: localhost:8008/  connect_address: $HOST_IP:8008/" $GAUSS_CONF/patroni.yaml
    sed -i "s/^  host: localhost:2379/  hosts: $ETCD_HOSTS/" $GAUSS_CONF/patroni.yaml
    sed -i "s/^  listen: localhost:16000/  listen: $HOST_IP:$GAUSS_PORT/" $GAUSS_CONF/patroni.yaml
    sed -i "s#^  data_dir: /var/lib/opengauss/data#  data_dir: $GAUSS_DB#" $GAUSS_CONF/patroni.yaml
    sed -i "s#^  bin_dir: /usr/local/opengauss/bin#  bin_dir: $GAUSSHOME/bin#" $GAUSS_CONF/patroni.yaml
    sed -i "s#^  config_dir: /var/lib/opengauss/data#  config_dir: $GAUSS_DB#" $GAUSS_CONF/patroni.yaml
    sed -i "s#^  custom_conf: /var/lib/opengauss/data/postgresql.conf#  custom_conf: $GAUSS_DB/postgresql.conf#" $GAUSS_CONF/patroni.yaml
    sed -i "s/^  connect_address: localhost:16000/  connect_address: $HOST_IP:$GAUSS_PORT/" $GAUSS_CONF/patroni.yaml
    sed -i "s/^      username: superuser/      username: $GAUSS_USER/" $GAUSS_CONF/patroni.yaml
    sed -i "s/^      password: superuser_123/      password: $GAUSS_PASSWORD/" $GAUSS_CONF/patroni.yaml
    sed -i "s/^      username: repl/      username: $GAUSS_USER/" $GAUSS_CONF/patroni.yaml
    sed -i "s/^      password: repl_123/      password: $GAUSS_PASSWORD/" $GAUSS_CONF/patroni.yaml
    sed -i "s/^      username: rewind/      username: $GAUSS_USER/" $GAUSS_CONF/patroni.yaml
    sed -i "s/^      password: rewind_123/      password: $GAUSS_PASSWORD/" $GAUSS_CONF/patroni.yaml
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
            # echo -e "\033[32m ==> Start OpenGauss primary  <== \033[0m"
            # gs_ctl restart -D "$GAUSS_DB" -M primary
            # local len=$(($PEER_NUM))
            # checkStart "check slave" "echo start | gs_ctl query -D $GAUSS_DB | grep -c sync_percent | grep -c $len" 12000
            break
        else 
            echo -e "\033[32m ==> Start OpenGauss standby  <== \033[0m"
            gs_ctl restart -D "$GAUSS_DB" -M standby
            echo -e "\033[32m ==> Wait for the master to completed  <== \033[0m"
            checkStart "connect to server master" "echo start | gs_ctl build -D "$GAUSS_DB" -b full | grep -c 'connect to server success, build started.'" 15
            echo -e "\033[32m ==> Stop:first Start OpenGauss <== \033[0m"
            gs_ctl -D "$GAUSS_DB" -m fast -w stop
        fi
        if [ $? -eq 0 ]; then
            break
        else
            echo -e "\033[31m ==> errcode=$?\033[0m"
            echo -e "\033[31m ==>build failed\033[0m"
            sleep 1s
        fi
    done
    sleep 1s
    set -e
}
function start_etcd(){
    set_etcd_config
    echo -e "\033[32m ==> Start $(etcd --version | grep etcd) Server... \033[0m"
    etcd --config-file $GAUSS_CONF/etcd.conf > $LOGS_HOME/etcd.log 2>&1 &
    # etcdctl --endpoints=${CLIENT_URLS} endpoint status --write-out=table

}
function start_db(){
    if [ $RUN_MODE != "standard" ]; then
        echo "change patroni config"
        set_patroni_config    
        echo -e "\033[32m ==> Start $(patroni --version) Server... \033[0m"
        exec patroni $GAUSS_CONF/patroni.yaml 2>&1 | tee $LOGS_HOME/patroni.log
        #nohup patroni $GAUSS_CONF/patroni.yaml  | tee $LOGS_HOME/patroni.log 2>&1 &        
    else
        echo -e "\033[32m ==> Start $(gaussdb -V)<== \033[0m"
        gs_ctl restart -D "$GAUSS_DB"  -M primary
    fi
    echo -e "\033[32m ==> $(gaussdb -V)<== \033[0m"
}

function stop_db(){
    if [ $RUN_MODE != "standard" ]; then
        echo -e "\033[31m ==> Stop $(etcd --version | grep etcd) Server... \033[0m"
        kill -9 $(ps -ef|grep etcd|gawk '$0 !~/grep/ {print $2}' |tr -s '\n' ' ')
        echo -e "\033[31m ==> Stop $(patroni --version) Server... \033[0m"
        kill -9 $(ps -ef|grep patroni|gawk '$0 !~/grep/ {print $2}' |tr -s '\n' ' ')
        echo -e "\033[31m ==> Stop $(gaussdb -V)<== \033[0m"
        gs_ctl stop -D $GAUSS_DB
    else
        echo -e "\033[31m ==> Stop $(gaussdb -V)<== \033[0m"
        gs_ctl stop -D "$GAUSS_DB"
    fi
}

function status_db(){
    # local len=$(($PEER_NUM))
    # checkStart "check slave" "echo start | gs_ctl query -D $GAUSS_DB | grep -c sync_percent | grep -c $len" 12000
    # echo -e "\033[32m **********************Patroni List*************************\033[0m"
    # patronictl -c $GAUSS_CONF/patroni.yaml list
    # echo -e "\033[32m ===========================================================\033[0m"
    netstat -tunlp
}
echo "==> START Service ..."
set_environment
if [ $RUN_MODE != "standard" ]; then    
    start_etcd
fi
init_db
start_db
status_db
echo -e "\033[32m ==> START Service SUCCESSFUL ... \033[0m"
tail -f /dev/null &
waitterm

echo -e "\033[31m ==> STOP Service\033[0m"
stop_db
echo -e "\033[31m ==> STOP Service SUCCESSFUL ...\033[0m"