FROM openeuler/openeuler:20.03

EXPOSE 80

WORKDIR /opt

COPY ./openeuler_httpd/httpd-2.4.51.tar.bz2 httpd-2.4.51.tar.bz2

RUN yum update -y
RUN yum install -y wget apr-devel apr-util-devel pcre-devel gcc make tar gcc-c++ lua-devel \
    pcre openssl openssl-devel zlib unzip cmake ncurses-devel expat-devel libjpeg openldap-devel \
    libjpeg-devel libpng libxml2 libxml2-devel curl-devel libtool libtool-ltdl libtool-ltdl-devel \
    libevent libevent-devel zlib-static zlib-devel autoconf gd perl freetype freetype-devel \
    doxygen libuuid-devel python rpm-build libdb-devel mysql5-devel nss-devel postgresql-devel sqlite-devel unixODBC-devel
RUN yum clean all

RUN rpmbuild -tb httpd-2.4.51.tar.bz2
RUN yum localinstall -y /root/rpmbuild/RPMS/x86_64/*.rpm
RUN rm -rf httpd-2.4.51.tar.bz2
RUN rm -rf /root/rpmbuild/BUILD/*
RUN rm -rf /root/rpmbuild/BUILDROOT/*
RUN rm -rf /root/rpmbuild/RPMS/*
RUN rm -rf /root/rpmbuild/SOURCES/*
RUN rm -rf /root/rpmbuild/SPECS/*
RUN rm -rf /root/rpmbuild/SRPMS/*
RUN groupadd www && useradd -g www www -s /bin/false 
RUN sed -i "/^User daemon/c\User www"  /etc/httpd/conf/httpd.conf
RUN sed -i "/^Group daemon/c\Group www"  /etc/httpd/conf/httpd.conf
RUN sed -i "/^#ServerName/c\ServerName localhost:80" /etc/httpd/conf/httpd.conf

RUN echo "<html><body>" > /var/www/html/index.html && \
    echo "<h1>openEuler" >> /var/www/html/index.html && \
    cat /etc/os-release | grep -Po '(?<=VERSION=).*' | sed 's/"//g'| sed 's/$/<\/h1>/' >> /var/www/html/index.html && \
    httpd -V | sed '1 s/^/<h2>/' | sed '1 s/$/<\/h2>/' | sed '2,$ s/$/<\/br>/'| tee -a /var/www/html/index.html && \
    httpd -M | sed '1 s/^/<h2>/' | sed '1 s/$/<\/h2>/' | sed '2,$ s/$/<\/br>/'| tee -a /var/www/html/index.html && \
    echo "</body></html>" >> /var/www/html/index.html && \
    true

COPY ./openeuler_httpd/main.sh main.sh
RUN chmod +x /opt/main.sh

ENV PATH=$PATH:/etc/apache/bin/
ENTRYPOINT [ "/opt/main.sh"]
CMD ["/bin/bash"]