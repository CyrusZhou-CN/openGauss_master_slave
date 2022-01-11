FROM openeuler/openeuler:20.03 AS base

EXPOSE 80
WORKDIR /opt
FROM base AS builder
RUN yum -y install wget tar make gcc autoconf systemd-devel openjpeg-devel gcc-c++ \
        pcre-devel zlib-devel libxml2 libxml2-devel openssl openssl-devel bzip2 bzip2-devel \
        libcurl libcurl-devel libjpeg libjpeg-devel libpng libpng-devel freetype freetype-devel \
        gmp gmp-devel readline readline-devel libxslt libxslt-devel

RUN wget https://nginx.org/download/nginx-1.21.5.tar.gz
RUN wget https://www.php.net/distributions/php-5.6.6.tar.gz
RUN wget https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.16.tar.gz
RUN wget https://sourceforge.net/projects/mcrypt/files/Libmcrypt/2.5.8/libmcrypt-2.5.8.tar.gz
RUN wget https://sourceforge.net/projects/mhash/files/latest/download/mhash-0.9.9.9.tar.gz
RUN tar -zvxf nginx-1.21.5.tar.gz
RUN tar -zvxf php-5.6.6.tar.gz
RUN tar -zvxf libiconv-1.16.tar.gz
RUN tar zxvf libmcrypt-2.5.8.tar.gz
RUN tar -zxvf mhash-0.9.9.9.tar.gz

RUN cd nginx-1.21.5 && ./configure --prefix=/usr/local/nginx  && make && make install
RUN rm -Rf nginx-1.21.5 nginx-1.21.5.tar.gz

COPY  ./php/zend-loader-php5.6-linux-x86_64_update1.tar.gz zend-loader-php5.6-linux-x86_64_update1.tar.gz
RUN tar -zxvf zend-loader-php5.6-linux-x86_64_update1.tar.gz
RUN mkdir -p /usr/local/zend/ && cp zend-loader-php5.6-linux-x86_64/*.so /usr/local/zend/

RUN cd libiconv-1.16 && ./configure --prefix=/usr/local/libiconv && make -j 2&& make install

RUN cd libmcrypt-2.5.8 && ./configure && make && make install && ldconfig && cd libltdl/ && ./configure --enable-ltdl-install && make && make install

RUN cd mhash-0.9.9.9 && ./configure && make -j 2 && make install

RUN cd php-5.6.6 &&  ./configure --prefix=/usr/local/php \
        --with-config-file-path=/usr/local/php/etc \
        --enable-fpm \
        --enable-gd-native-ttf \
        --with-mysql=mysqlnd \
        --with-mysqli=mysqlnd \
        --with-pdo-mysql=mysqlnd \
        --with-curl	\
        --with-zlib \
        --with-zlib-dir \
        --with-libxml-dir \
        --with-freetype-dir \
        --with-jpeg-dir \
        --with-png-dir \
        --with-iconv=/usr/local/libiconv \
        --with-gd && make -j 2 ZEND_EXTRA_LIBS='-liconv' && make install

RUN  set -e;\
        cd php-5.6.6 &&cp php.ini-production /usr/local/php/etc/php.ini;\
        sed -i 's/post_max_size = 8M/post_max_size = 50M/g' /usr/local/php/etc/php.ini;\
        sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 50M/g' /usr/local/php/etc/php.ini;\
        sed -i 's/;date.timezone =/date.timezone = PRC/g' /usr/local/php/etc/php.ini;\
        sed -i 's/short_open_tag = Off/short_open_tag = On/g' /usr/local/php/etc/php.ini;\
        sed -i 's/; cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /usr/local/php/etc/php.ini;\
        sed -i 's/; cgi.fix_pathinfo=0/cgi.fix_pathinfo=0/g' /usr/local/php/etc/php.ini;\
        sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /usr/local/php/etc/php.ini;\
        sed -i 's/max_execution_time = 30/max_execution_time = 300/g' /usr/local/php/etc/php.ini;\
        sed -i 's/register_long_arrays = On/;register_long_arrays = On/g' /usr/local/php/etc/php.ini;\
        sed -i 's/magic_quotes_gpc = On/;magic_quotes_gpc = On/g' /usr/local/php/etc/php.ini;\
        sed -i 's/disable_functions =.*/disable_functions = passthru,exec,system,chroot,scandir,chgrp,chown,shell_exec,proc_open,proc_get_status,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,stream_socket_server/g' /usr/local/php/etc/php.ini;\
        ln -sf /usr/local/php/bin/php /usr/bin/php;\
        ln -sf /usr/local/php/bin/phpize /usr/bin/phpize;\
        ln -sf /usr/local/php/sbin/php-fpm /usr/bin/php-fpm;\
        { echo '[Zend Optimizer]';\
                echo 'zend_extension=/usr/local/zend/ZendGuardLoader.so';\
                echo 'zend_extension=/usr/local/zend/opcache.so';\
                echo 'zend_loader.enable=1';\
                echo 'zend_loader.disable_licensing=0';\
                echo 'zend_loader.obfuscation_level_support=3';\
                echo 'zend_loader.license_path=';\
        } >> /usr/local/php/etc/php.ini

FROM base AS runtime
RUN yum -y install shadow-utils && groupadd -r www && useradd -r -g www www
COPY  --from=builder /usr/local/nginx   /usr/local/nginx
COPY  --from=builder /usr/local/php  /usr/local/php
COPY  --from=builder /usr/local/zend /usr/local/zend
COPY  --from=builder /usr/local/libiconv /usr/local/libiconv
COPY  ./php/php-fpm.conf  /usr/local/php/etc/php-fpm.conf
RUN     ln -s /usr/local/php/bin/php /usr/bin/php;\
        ln -s /usr/local/php/bin/phpize /usr/bin/phpize;\
        ln -s /usr/local/php/sbin/php-fpm /usr/bin/php-fpm;
RUN chmod 755 /usr/local/php/etc/php-fpm.conf && chmod 755 /usr/local/php/etc/php.ini
COPY ./nginx/nginx.conf /usr/local/nginx/conf/nginx.conf
COPY ./main.sh main.sh
RUN chmod +x /opt/main.sh
RUN mkdir -p /www/wwwroot/default && mkdir /www/wwwlogs && \
        set -e;\
        { echo '<head>';\
        echo '<title>Welcome to nginx!</title>';\
        echo '<style>';\        
        echo 'html { color-scheme: light dark; }';\
        echo 'body {width:950px; margin: 10 auto;';\
        echo 'font-family: Tahoma, Verdana, Arial, sans-serif; }';\
        echo '</style>';\
        echo '</head>';\
        echo '<body>';\
        echo "<h1>openEuler"  && \    
        cat /etc/os-release | grep -Po '(?<=VERSION=).*' | sed 's/"//g'| sed 's/$/<\/h1>/';\
        echo '<h1>Welcome to nginx!</h1>';\
        echo '<h2>';\
        echo $(nginx -v);\
        echo '</h2>';\            
        echo '<p>If you see this page, the nginx web server is successfully installed and';\
        echo 'working. Further configuration is required.</p>';\
        echo '<p>For online documentation and support please refer to';\
        echo '<a href="http://nginx.org/">nginx.org</a>.<br/>';\
        echo 'Commercial support is available at';\
        echo '<a href="http://nginx.com/">nginx.com</a>.</p>';\
        echo '<p><em>Thank you for using nginx.</em></p>';\
        echo '<?php';\
        echo 'phpinfo();';\
        echo '?>';\
        echo '</body>';\
        echo '</html>';\
        } >> /www/wwwroot/default/index.php

RUN chown -R www:www /www
VOLUME /www

ENV PATH=$PATH:/usr/local/nginx/sbin/:/usr/local/php/sbin
ENTRYPOINT [ "/opt/main.sh"]
CMD ["/bin/bash"]