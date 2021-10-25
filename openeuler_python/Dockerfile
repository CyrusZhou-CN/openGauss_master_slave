FROM openeuler/openeuler:20.03


WORKDIR /opt
COPY ./openeuler_python/python/ /tmp/

RUN yum -y update && yum -y install shadow-utils tar libaio-devel flex bison \
    ncurses-devel glibc-devel patch libnsl readline-devel telnet gdbm-devel libpcap-devel xz-devel libffi-devel\
    zlib-devel bzip2-devel openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel\
    make gcc zlib zlib-static zlib-devel python3-psycopg2 python3-devel 
# bash: passwd: command not found
# bash: service: command not found
RUN yum install -y passwd initscripts sudo && \
    yum clean all
# 编译安装 openssl
RUN tar -zxvf /tmp/openssl-*.tar.gz -C /opt/ && rm -rf /tmp/openssl-*.tar.gz && \
    cd /opt/openssl-* && \
    ./config --prefix=/usr/local/openssl shared enable-ssl3 enable-ssl3-method && \
    make -j4 && make install && \
    ln -sf /usr/local/openssl/bin/openssl /usr/bin/openssl && \
    ln -sf /usr/local/openssl/include/openssl /usr/include/openssl && \
    ln -sf /usr/local/openssl/lib/libssl.so /usr/lib64/libssl.so && \
    echo "/usr/local/openssl/lib" >> /etc/ld.so.conf && \
    chmod -R 777 /usr/local/openssl && \
    chmod -R 777 /usr/bin/openssl && \
    chmod -R 777 /usr/include/openssl && \
    chmod -R 777 /usr/lib64/libssl.so && \
    ldconfig -v

# 编译安装 Python
RUN tar -xvf /tmp/Python-*.tar.xz -C /opt/ && rm -rf /tmp/Python-*.tar.xz && \
    cd /opt/Python-* && \
    ./configure -prefix=/usr/local/python3.7 --with-openssl=/usr/local/openssl --enable-optimizations && \
    make -j4 && make install && \
    ln -sf /usr/local/python3.7/bin/python3.7 /usr/bin/python3.7 && \
    ln -sf /usr/local/python3.7/bin/python3.7 /usr/bin/python3 && \
    ln -sf /usr/local/python3.7/bin/python3.7 /usr/bin/python && \
    ln -sf /usr/local/python3.7/bin/pip3 /usr/bin/pip3 && \
    ln -sf /usr/local/python3.7/bin/pip3 /usr/bin/pip && \
    /usr/local/python3.7/bin/python3 -m pip install --upgrade pip && \
    /usr/local/python3.7/bin/python3 -m pip install --upgrade setuptools
# 解决yum dnf出错问题
RUN cp -rf /usr/lib/python3.7/site-packages/dnf-plugins /usr/local/python3.7/lib/python3.7/site-packages/dnf-plugins && \
    cp -rf /usr/lib/python3.7/site-packages/fros-1.1-py3.7.egg-info /usr/local/python3.7/lib/python3.7/site-packages/fros-1.1-py3.7.egg-info && \
    cp -rf /usr/lib/python3.7/site-packages/pyfros /usr/local/python3.7/lib/python3.7/site-packages/pyfros && \
    cp -rf /usr/lib/python3.7/site-packages/pyparsing-2.4.7.dist-info /usr/local/python3.7/lib/python3.7/site-packages/pyparsing-2.4.7.dist-info && \
    cp -rf /usr/lib/python3.7/site-packages/dnf /usr/local/python3.7/lib/python3.7/site-packages/dnf && \
    cp -rf /usr/lib64/python3.7/site-packages/libdnf /usr/local/python3.7/lib/python3.7/site-packages/libdnf && \
    cp -rf /usr/lib64/python3.7/site-packages/rpm /usr/local/python3.7/lib/python3.7/site-packages/rpm && \
    cp -rf /usr/lib64/python3.7/site-packages/rpm-4.15.1-py3.7.egg-info  /usr/local/python3.7/lib/python3.7/site-packages/rpm-4.15.1-py3.7.egg-info && \
    cp -rf /usr/lib64/python3.7/site-packages/libcomps /usr/local/python3.7/lib/python3.7/site-packages/libcomps && \
    cp -rf /usr/lib64/python3.7/site-packages/gpg /usr/local/python3.7/lib/python3.7/site-packages/gpg && \
    cp -rf /usr/lib64/python3.7/site-packages/gpg-1.14.0-py3.7.egg-info  /usr/local/python3.7/lib/python3.7/site-packages/gpg-1.14.0-py3.7.egg-info && \
    cp -rf /usr/lib64/python3.7/site-packages/hawkey /usr/local/python3.7/lib/python3.7/site-packages/hawkey &&\
    chmod -R 777 /usr/local/python3.7 &&\
    chmod -R 777 /usr/lib/python3.7  &&\
    chmod -R 777 /usr/lib64/python3.7
# 清除安装包
RUN rm -rf /tmp/* /opt/*
RUN rm -rf /usr/lib64/libssl* && \
    cp /usr/local/openssl/lib/libssl* /usr/lib64 && \
    chmod -R 777 /usr/lib64/libssl*

CMD ["/bin/bash"]