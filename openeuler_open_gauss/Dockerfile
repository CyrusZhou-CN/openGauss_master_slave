FROM lsqtzj/openeuler_python:20.03

EXPOSE 5432

WORKDIR /opt/software/openGauss
COPY ./image /tmp/

RUN groupadd -r dbgrp && useradd -g dbgrp omm && \
    mkdir -p /opt/software/openGauss && \
    tar -jxf /tmp/openGauss-*-openEuler-64bit.tar.bz2 -C /opt/software/openGauss && \
    rm -f /tmp/openGauss-*-openEuler-64bit.tar.bz2 && \
    mv /tmp/app.sh /opt/software/openGauss/app.sh && \
    mv /tmp/set_environment.sh /opt/software/openGauss/set_environment.sh

RUN tar -zxvf /tmp/patroni-*.tar.gz -C /opt/software/ && \
    rm -f /tmp/patroni-*.tar.gz && \
    mv /opt/software/patroni-* /opt/software/patroni

RUN tar -zxvf /tmp/haproxy-*.tar.gz -C /opt/software/ && \
    rm -f /tmp/haproxy-*.tar.gz && \
    mv /opt/software/haproxy-* /opt/software/haproxy

RUN chown omm:dbgrp -R /opt/software/openGauss  && \
    chmod +x /opt/software/openGauss/simpleInstall/install.sh && \
    chmod +x /opt/software/openGauss/app.sh && \
    chmod +x /opt/software/openGauss/set_environment.sh
    
ENV GAUSSHOME=/opt/software/openGauss
ENV PATH=$GAUSSHOME/bin:$PATH
ENV LD_LIBRARY_PATH=$GAUSSHOME/lib:$LD_LIBRARY_PATH
ENV GS_CLUSTER_NAME=dbCluster
ENV ulimit -n 1000000

ENTRYPOINT [ "/opt/software/openGauss/app.sh" ]
CMD ["/bin/bash"]