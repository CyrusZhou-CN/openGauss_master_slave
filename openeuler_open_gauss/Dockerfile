FROM openeuler/openeuler:20.03

EXPOSE 5432

WORKDIR /opt/software/openGauss
COPY ./image /tmp/

RUN yum -y update && yum -y install shadow-utils tar libaio-devel flex bison ncurses-devel glibc-devel patch libnsl readline-devel telnet
RUN yum clean all 
RUN groupadd -r dbgrp && useradd -g dbgrp omm && \
    mkdir -p /opt/software/openGauss && \
    tar -jxf /tmp/openGauss-*-openEuler-64bit.tar.bz2 -C /opt/software/openGauss && \
    rm -f /tmp/openGauss-*-openEuler-64bit.tar.bz2 && \
    mv /tmp/app.sh /opt/software/openGauss/app.sh && \
    chown omm:dbgrp -R /opt/software/openGauss && \
    chmod +x /opt/software/openGauss/simpleInstall/install.sh && \
    chmod +x /opt/software/openGauss/app.sh

ENV GAUSSHOME=/opt/software/openGauss
ENV PATH=$GAUSSHOME/bin:$PATH
ENV LD_LIBRARY_PATH=$GAUSSHOME/lib:$LD_LIBRARY_PATH
ENV GS_CLUSTER_NAME=dbCluster
ENV ulimit -n 1000000

USER omm
ENTRYPOINT [ "/opt/software/openGauss/app.sh" ]
CMD ["/bin/bash"]