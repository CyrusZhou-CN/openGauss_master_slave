# 单机运行
docker run -p 5432:5432 -e 'GAUSS_USER=gauss'  -e 'GAUSS_PASSWORD=Gauss666' -d --name OpenGaussTest lsqtzj/openeuler_open_gauss:latest
# openGauss 高可用集群说明
openGauss 极简版 基于openeuler/openeuler:20.03</br>
包括 patroni自动主备切换，haproxy 负载均衡， pgAdmin4 管理工具</br>
必须保证有两个以上的openGauss容器运行。
## 博客地址
https://blog.csdn.net/lsqtzj/article/details/120850420
## 使用方式
下载源码</br>
git clone https://github.com/CyrusZhou-CN/openGauss_master_slave.git</br>
cd openGauss_master_slave</br>
### 编译版本
docker-compose -f "docker-compose-build.yml" up -d --build</br>
### 容器版本 
docker-compose -f "docker-compose.yml" up -d</br>
![image](https://user-images.githubusercontent.com/4635861/137876048-c1fd20b2-257c-40ef-8974-6b04653bf90d.png)</br>
![image](https://user-images.githubusercontent.com/4635861/137875839-794355b6-81ea-4d57-96a3-ab4600dd11e1.png)
### 系统默认密码
用户名/密码 root / root 、omm / omm
## openGauss 默认远程连接配置
管理员 / 密码：gauss / Gauss666</br>
## 集成pgAdmin4 6.0
http://localhost:9980/pgadmin4/browser/</br>
默认管理员 / 密码：admin@domain.com / admin</br>
![image](https://user-images.githubusercontent.com/4635861/137875941-3ad483a5-e8c8-401b-be26-fea4d90670db.png)
# 添加 patroni 自动主备切换
etcd Version: 3.5.1</br>
patroni Version 2.0.2
# 加入 HAProxy 数据库读写负载均衡
http://localhost:7000/ 监控
## 数据库配置
haproxy:5000   读写</br>
haproxy:5001   读</br>
![image](https://user-images.githubusercontent.com/4635861/139657547-abb4cf92-2c86-4920-9fd8-4a029a5534fd.png) 
## openGauss 更新到 3.0.0 版本
docker-compose 基本配置 放到 .env 文件中。
## 添加数据持久化
默认保存在 ./data 目录
### 容器目录说明
/opt/software/openGauss/data/db 数据库目录
/opt/software/openGauss/data/conf 配置文件目录
/opt/software/openGauss/logs 日志目录
## 改进新加主机功能
如：新添加 slave03 主机，打开docker-compose.yml 文件复制 slave02 节点的配置，用来创建新主机。
### 1. 添加节点
```
...
slave03:
    image:  lsqtzj/openeuler_open_gauss:${OPEN_GAUSS_VERSION}
    restart: always
    container_name: slave03
    hostname: slave03
    networks:
      gauss:
        ipv4_address: 10.8.0.13
    environment:
      TZ: Europe/Rome #Asia/Shanghai 时区
      GAUSS_USER: ${GAUSS_USER}
      GAUSS_PASSWORD: ${GAUSS_PASSWORD}
      NODE_NAME: datanode4
      RUN_MODE: "slave"
      HOST_NAMES: ${HOST_NAMES}
    volumes:
      - ./data/slave03/data:/opt/software/openGauss/data      
      - ./data/slave03/logs:/opt/software/openGauss/logs
    depends_on:
      - master
...
```  
### 2.修改变量
修改 .env 文件添加新主机
```
...
HOST_NAMES=master,slave01,slave02,slave03
HOST_IPS=10.8.0.10,10.8.0.11,10.8.0.12
HAPROXY_IPS=10.8.0.10,10.8.0.11,10.8.0.12,10.8.0.13
HAPROXY_PORTS=5432,5432,5432,5432
...
```
### 初始化数据
#### 只有 RUN_MODE: "master" ，首次启动容器时有效
#### GAUSS_DATABASE: test # 初始化数据库 \c 切换数据库 要输入密码，所以加这个参数用来创建数据库
```
volumes:
      - ./test.sql:/docker-entrypoint-initdb.d/test.sql # 初始化数据表
```

