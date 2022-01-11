docker run -d -tid --name openeuler_mariadb -e MARIADB_RANDOM_ROOT_PASSWORD=true -e MARIADB_USER=admin -e MARIADB_PASSWORD=admin123@  --privileged=true lsqtzj/openeuler_mariadb  /sbin/init
docker exec -it openeuler_mariadb /bin/bash
