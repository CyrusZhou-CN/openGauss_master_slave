FROM lsqtzj/openeuler_python:20.03

EXPOSE 5432

WORKDIR /opt/software
COPY ./image /tmp/

RUN groupadd -r dbgrp && useradd -g dbgrp omm && \
    mkdir -p /opt/software/openGauss && \
    tar -jxf /tmp/openGauss-*-openEuler-64bit.tar.bz2 -C /opt/software/openGauss && \
    rm -f /tmp/openGauss-*-openEuler-64bit.tar.bz2 && \
    mv /tmp/app.sh /opt/software/openGauss/app.sh

RUN tar -zxvf /tmp/patroni-*.tar.gz -C /opt/software/ && \
    rm -f /tmp/patroni-*.tar.gz && \
    mv /opt/software/patroni-* /opt/software/patroni

RUN tar -zxvf /tmp/haproxy-*.tar.gz -C /opt/software/ && \
    rm -f /tmp/haproxy-*.tar.gz && \
    mv /opt/software/haproxy-* /opt/software/haproxy

ADD ./image/openGauss-2.1.0-openEuler-64bit-Libpq.tar.gz /opt/software/openGauss
ADD ./image/openGauss-2.1.0-openEuler-x86_64-Python.tar.gz /opt/software/openGauss

RUN tar -xzvf /tmp/etcd-*-linux-amd64.tar.gz -C /tmp/ && \
    rm -rf /tmp/etcd-*-linux-amd64.tar.gz && \
    cd /tmp/etcd-*-linux-amd64 && cp ./etcd* /usr/bin && \
    rm -rf /tmp/etcd-*-linux-amd64

RUN mv /opt/software/openGauss/psycopg2 /usr/local/python3.7/lib/python3.7/site-packages/psycopg2
RUN cd /opt/software/patroni && pip install wheel && pip install -r requirements.txt && \
    python setup.py build && python setup.py install

RUN chown omm:dbgrp -R /opt/software  && \
    chmod +x /opt/software/openGauss/simpleInstall/install.sh && \
    chmod +x /opt/software/openGauss/app.sh && \
    mv /opt/software/openGauss/app.sh /opt/software/app.sh
    
ENV GAUSSHOME=/opt/software/openGauss
ENV PATH=$GAUSSHOME/bin:$PATH:/usr/local/python3.7/bin
ENV LD_LIBRARY_PATH=$GAUSSHOME/lib:$LD_LIBRARY_PATH
ENV GS_CLUSTER_NAME=dbCluster
ENV ulimit -n 1000000
USER omm
ENTRYPOINT [ "/opt/software/app.sh" ]
CMD ["/bin/bash"]