docker run -d -tid --name openeuler_redis  --privileged=true lsqtzj/openeuler_redis  /sbin/init
docker exec -it openeuler_redis /bin/bash
