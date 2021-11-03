FROM openeuler/openeuler:20.03

ENV TIME_ZOME Asia/Shanghai
ENV LANG=zh_CN.utf8

ADD ./openeuler_haproxy/run.sh /usr/local
COPY ./openeuler_haproxy/haproxy.cfg /usr/local/haproxy/etc/
RUN yum -y install gcc gcc-c++ make glibc glibc-devel pcre pcre-devel diffutils\
        openssl openssl-devel systemd-devel zip unzip zlib zlib-devel git rsyslog glibc-common \
        && yum clean all \
        && mkdir -p /usr/local/src/ \
        && cd /usr/local/src \
        && git clone --branch v2.4.0 https://github.com/haproxy/haproxy.git \
        && cd /usr/local/src/haproxy \
        && make ARCH=x86_64 TARGET=linux-glibc USE_OPENSSL=1 USE_ZLIB=1 \
        USE_SYSTEMD=1 USE_CPU_AFFINITY=1 PREFIX=/usr/local/haproxy \
        && make install PREFIX=/usr/local/haproxy \
        && cp haproxy /usr/sbin/ \
        && chmod 777 /usr/local/run.sh

EXPOSE 7000 5000 5001
CMD ["/usr/local/run.sh"]
