FROM lsqtzj/openeuler_python:20.03

EXPOSE 5432 8008

WORKDIR /opt/software
COPY ./image /tmp/

RUN groupadd -r dbgrp && useradd -g dbgrp omm && \
    mkdir -p /opt/software/openGauss && \
    tar -jxf /tmp/openGauss-*-openEuler-64bit.tar.bz2 -C /opt/software/openGauss && \
    rm -f /tmp/openGauss-*-openEuler-64bit.tar.bz2 && \
    mv /tmp/app.sh /opt/software/app.sh && \
    mv /tmp/etcd.conf.sample /opt/software/etcd.conf && \
    mv /tmp/patroni.yaml.sample /opt/software/patroni.yaml
    
# 解决patroni找不到gs_isready问题
RUN mv /tmp/gs_isready /opt/software/openGauss/bin/gs_isready && \
    mv /tmp/libreadline.so.6.2 /usr/lib64/libreadline.so.6.2 && \
    ln -sf /usr/lib64/libreadline.so.6.2 /usr/lib64/libreadline.so.6 && \
    chmod 777 /usr/lib64/libreadline.so.6

RUN mv /tmp/patroni_openGauss /opt/software/patroni_openGauss

RUN tar -zxvf /tmp/haproxy-*.tar.gz -C /opt/software/ && \
    rm -f /tmp/haproxy-*.tar.gz && \
    mv /opt/software/haproxy-* /opt/software/haproxy
RUN tar -zxvf /tmp/psycopg2-*.tar.gz -C /opt/software/ && \
    rm -f /tmp/psycopg2-*.tar.gz && \
    mv /opt/software/psycopg2-* /opt/software/psycopg2

ADD ./image/openGauss-2.1.0-openEuler-64bit-Libpq.tar.gz /opt/software/openGauss

RUN tar -xzvf /tmp/etcd-*-linux-amd64.tar.gz -C /tmp/ && \
    rm -rf /tmp/etcd-*-linux-amd64.tar.gz && \
    cd /tmp/etcd-*-linux-amd64 && cp ./etcd* /usr/bin && \
    rm -rf /tmp/etcd-*-linux-amd64

RUN chown omm:dbgrp -R /opt/software  && \
    chown omm:dbgrp -R /tmp/*  && \
    chmod -R 700 /tmp/*  && \
    chmod -R 700 /opt/software  && \
    chmod +x /opt/software/openGauss/simpleInstall/install.sh && \
    chmod +x /opt/software/app.sh 

# 解决 host: command not found
RUN mv /tmp/host /usr/bin/host && \
    mv /tmp/libdns.so.1102.1.2 /usr/lib64/libdns.so.1102.1.2 && \
    ln -sf /usr/lib64/libdns.so.1102.1.2 /usr/lib64/libdns.so.1102 && \
    mv /tmp/liblwres.so.160.0.2 /usr/lib64/liblwres.so.160.0.2 && \
    ln -sf /usr/lib64/liblwres.so.160.0.2 /usr/lib64/liblwres.so.160 && \
    mv /tmp/libbind9.so.160.0.8 /usr/lib64/libbind9.so.160.0.8 && \
    ln -sf /usr/lib64/libbind9.so.160.0.8 /usr/lib64/libbind9.so.160 && \
    mv /tmp/libisccfg.so.160.2.1 /usr/lib64/libisccfg.so.160.2.1 && \
    ln -sf /usr/lib64/libisccfg.so.160.2.1 /usr/lib64/libisccfg.so.160 && \
    mv /tmp/libisc.so.169.0.3 /usr/lib64/libisc.so.169.0.3 && \
    ln -sf /usr/lib64/libisc.so.169.0.3 /usr/lib64/libisc.so.169 && \
    mv /tmp/libcrypto.so.1.0.2k /usr/lib64/libcrypto.so.1.0.2k && \
    ln -sf /usr/lib64/libcrypto.so.1.0.2k /usr/lib64/libcrypto.so.10 && \
    mv /tmp/libidn.so.11.6.11 /usr/lib64/libidn.so.11.6.11 && \
    ln -sf /usr/lib64/libidn.so.11.6.11 /usr/lib64/libidn.so.11 && \
    mv /tmp/libGeoIP.so.1.5.0 /usr/lib64/libGeoIP.so.1.5.0 && \
    ln -sf /usr/lib64/libGeoIP.so.1.5.0 /usr/lib64/libGeoIP.so.1 

RUN chmod 777 /usr/lib64/libdns.so.1102 /usr/lib64/liblwres.so.160 /usr/lib64/libisccfg.so.160 /usr/lib64/libisc.so.169\
    /usr/lib64/libcrypto.so.10 /usr/lib64/libidn.so.11 /usr/lib64/libGeoIP.so.1 /usr/lib64/libbind9.so.160

USER omm

ENV SOFT_HOME=/opt/software
ENV GAUSSHOME=$SOFT_HOME/openGauss
ENV PATH=$GAUSSHOME/bin:$PATH:/usr/local/python3.7/bin
ENV LD_LIBRARY_PATH=$GAUSSHOME/lib:$LD_LIBRARY_PATH
ENV GS_CLUSTER_NAME=dbCluster
ENV ulimit -n 1000000

RUN python3 -m venv /home/omm/venv && \
    source /home/omm/venv/bin/activate && \
    pip install wheel && \
    /home/omm/venv/bin/python3 -m pip install --upgrade pip && \   
    cd /opt/software/psycopg2 && \
    python setup.py build && python setup.py install && \
    cd /opt/software/patroni_openGauss && \
    pip install -r requirements.txt && \
    python setup.py build && python setup.py install && \
    rm -rf /opt/software/patroni_openGauss /opt/software/psycopg2

ENTRYPOINT [ "/opt/software/app.sh" ]
CMD ["/bin/bash"]