FROM openeuler/openeuler:20.03


WORKDIR /opt
COPY ./openeuler_python/python/ /tmp/

RUN yum -y update && yum -y install shadow-utils tar libaio-devel flex bison \
    ncurses-devel glibc-devel patch libnsl readline-devel telnet \
    make gcc zlib zlib-static zlib-devel && \
    yum clean all   

# 编译安装 openssl
RUN tar -zxvf /tmp/openssl-*.tar.gz -C /opt/ && rm -rf /tmp/openssl-*.tar.gz && \
    cd /opt/openssl-* && \
    ./config --prefix=/usr/local/openssl && \
    make -j4 && make install && \
    ln -sf /usr/local/openssl/bin/openssl /usr/bin/openssl && \
    ln -sf /usr/local/openssl/include/openssl /usr/include/openssl && \
    ln -sf /usr/local/openssl/lib/libssl.so /usr/lib64/libssl.so && \
    echo "/usr/local/openssl/lib" >> /etc/ld.so.conf && \
    ldconfig -v

# 编译安装 Python
RUN tar -xvf /tmp/Python-*.tar.xz -C /opt/ && rm -rf /tmp/Python-*.tar.xz && \
    cd /opt/Python-* && \
    ./configure -prefix=/usr/local/python3.10 --with-openssl=/usr/local/openssl --enable-optimizations && \
    make -j4 && make install && \
    ln -sf /usr/local/python3.10/bin/python3.10 /usr/bin/python3.10 && \
    ln -sf /usr/local/python3.10/bin/pip3 /usr/bin/pip3 && \
    ln -sf /usr/local/python3.10/bin/pip3 /usr/bin/pip && \
    ln -sf /usr/local/python3.10/bin/python3.10 /usr/bin/python && \
    /usr/local/python3.10/bin/python3 -m pip install --upgrade pip
    
# 清除安装包
RUN rm -rf /tmp/* /opt/*

CMD ["/bin/bash"]