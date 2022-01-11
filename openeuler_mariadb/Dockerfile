FROM openeuler/openeuler:20.03  AS base

WORKDIR /opt

FROM base AS builder
RUN yum -y install wget tar 

RUN wget https://archive.mariadb.org/mariadb-10.7.1/source/mariadb-10.7.1.tar.gz
RUN tar -zvxf mariadb-10.7.1.tar.gz

RUN yum -y install cmake make gcc gcc-c++ ncurses-devel openssl-devel openssl libevent 
RUN mkdir -p /var/lib/mysql
RUN cd mariadb-10.7.1 && \
	cmake . -DDEFAULT_CHARSET=utf8 \
	-DCMAKE_INSTALL_PREFIX=/usr/local/mysql \
	-DMYSQL_DATADIR=/var/lib/mysql \
	-DSYSCONFDIR=/etc -DWITHOUT_TOKUDB=1 \
	-DMYSQL_UNIX_ADDR=/tmp/mysql.sock \
	-DDEFAULT_COLLATION=utf8_general_ci && make -j4 && make install

RUN wget https://sourceforge.net/projects/pwgen/files/pwgen/2.08/pwgen-2.08.tar.gz
RUN tar -zvxf pwgen-2.08.tar.gz
RUN cd pwgen-2.08 && ./configure && make && make install

FROM base AS runtime

RUN yum -y install lsb initscripts shadow-utils && groupadd -r mysql && useradd -r -g mysql mysql

COPY --from=builder /usr/local/bin/pwgen /usr/local/bin/pwgen
COPY --from=builder /usr/local/mysql /usr/local/mysql
RUN chown -R mysql:mysql /usr/local/mysql \
	&& mkdir -p /var/run/mysqld \
	&& chown mysql:mysql /var/run/mysqld

# RUN cd /usr/local/mysql && \
# 	./scripts/mysql_install_db --user=mysql --datadir=/var/lib/mysql \
# 	&& chown -R root . 

RUN mkdir -p /etc/mysql && \
	cp /usr/local/mysql/support-files/mysql.server /etc/init.d/mysqld &&\
	cp /usr/local/mysql/support-files/wsrep.cnf  /etc/mysql/my.cnf

RUN set -ex; \
	if [ ! -L /etc/mysql/my.cnf ]; then sed -i -e '/includedir/i[mariadb]\nskip-host-cache\nskip-name-resolve\n' /etc/mysql/my.cnf; \
# 10.5+
	else sed -i -e '/includedir/ {N;s/\(.*\)\n\(.*\)/[mariadbd]\nskip-host-cache\nskip-name-resolve\n\n\2\n\1/}' \
                /etc/mysql/mariadb.cnf; fi
EXPOSE 3306
RUN mkdir /docker-entrypoint-initdb.d

VOLUME /var/lib/mysql
ARG MARIADB_MAJOR=10.7
ENV MARIADB_MAJOR $MARIADB_MAJOR
ARG MARIADB_VERSION=1:10.7.1+maria~focal
ENV MARIADB_VERSION $MARIADB_VERSION

ENV PATH=$PATH:/usr/local/mysql/bin/
COPY docker-entrypoint.sh /usr/local/bin/
COPY ./main.sh /opt/main.sh
ENTRYPOINT ["/opt/main.sh"]
EXPOSE 3306
CMD ["/opt/main.sh"]