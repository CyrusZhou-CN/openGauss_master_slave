FROM openeuler/openeuler:20.03  AS base

WORKDIR /opt

FROM base AS builder
RUN yum -y install wget tar make gcc gcc-c++

RUN wget https://download.redis.io/releases/redis-6.2.6.tar.gz
RUN tar -zvxf redis-6.2.6.tar.gz

RUN cd redis-6.2.6 && \
	make -j4 && make PREFIX=/usr/local/redis install

FROM base AS runtime

COPY --from=builder /usr/local/redis /usr/local/redis
COPY --from=builder /opt/redis-6.2.6/redis.conf /usr/local/redis/bin/redis.conf

EXPOSE 6379

ENV PATH=$PATH:/usr/local/redis/bin
COPY main.sh /opt/main.sh
RUN chmod +x /opt/main.sh

EXPOSE 3306
ENTRYPOINT [ "/opt/main.sh"]
CMD ["/bin/bash"]