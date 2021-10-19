# openGauss master slave 
openGauss_2.1.0 极简版 基于openeuler/openeuler:20.03</br>
## 使用方式
下载源码</br>
git clone https://github.com/lsqtzj/openGauss_master_slave.git</br>
cd openGauss_master_slave</br>
### 编译版本
docker-compose -f "docker-compose-build.yml" up -d --build</br>
### 容器版本 
docker-compose -f "docker-compose.yml" up -d</br>
![image](https://user-images.githubusercontent.com/4635861/137876048-c1fd20b2-257c-40ef-8974-6b04653bf90d.png)</br>
![image](https://user-images.githubusercontent.com/4635861/137875839-794355b6-81ea-4d57-96a3-ab4600dd11e1.png)
## openGauss 默认远程连接配置
管理员 / 密码：gauss / Gauss666</br>
## 集成pgAdmin4 6.0
http://localhost:9980/pgadmin4/browser/</br>
默认管理员 / 密码：admin@domain.com / admin</br>
![image](https://user-images.githubusercontent.com/4635861/137875941-3ad483a5-e8c8-401b-be26-fea4d90670db.png)