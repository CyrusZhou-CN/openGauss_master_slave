FROM openeuler/openeuler:20.03

EXPOSE 5432

WORKDIR /opt/software/openGauss
COPY ./image /tmp/

RUN yum -y update && yum -y install shadow-utils tar libaio-devel flex bison ncurses-devel glibc-devel patch libnsl readline-devel telnet
RUN groupadd -r dbgrp && useradd -g dbgrp omm
RUN mkdir -p /opt/software/openGauss
RUN tar -jxf /tmp/openGauss-*-openEuler-64bit.tar.bz2 -C /opt/software/openGauss
RUN rm -f /tmp/openGauss-*-openEuler-64bit.tar.bz2
RUN mv /tmp/app.sh /opt/software/openGauss/app.sh
RUN mv /tmp/set_environment.sh /opt/software/openGauss/set_environment.sh
RUN chown omm:dbgrp -R /opt/software/openGauss
RUN chmod +x /opt/software/openGauss/simpleInstall/install.sh
RUN chmod +x /opt/software/openGauss/app.sh
RUN chmod +x /opt/software/openGauss/set_environment.sh
RUN yum clean all 
ENV GAUSSHOME=/opt/software/openGauss
ENV PATH=$GAUSSHOME/bin:$PATH
ENV LD_LIBRARY_PATH=$GAUSSHOME/lib:$LD_LIBRARY_PATH
ENV GS_CLUSTER_NAME=dbCluster
ENV ulimit -n 1000000

CMD [ "/opt/software/openGauss/app.sh" ]