FROM lsqtzj/openeuler_httpd:v2.4.51

EXPOSE 80

WORKDIR /opt
COPY ./openeuler_pgadmin4/pgadmin4-6.0.tar.gz pgadmin4-6.0.tar.gz
COPY ./openeuler_pgadmin4/mod_wsgi-4.9.0.tar.gz mod_wsgi-4.9.0.tar.gz 
COPY ./openeuler_pgadmin4/pgAdmin4.conf /etc/httpd/conf/extra/pgAdmin4.conf

RUN yum update -y
RUN yum install -y python3-pip python3-devel
RUN tar vfx pgadmin4-6.0.tar.gz
RUN  echo -e "LOG_FILE = '/var/log/pgadmin4/pgadmin4.log'\n\
SQLITE_PATH = '/var/lib/pgadmin4/pgadmin4.db'\n\
SESSION_DB_PATH = '/var/lib/pgadmin4/sessions'\n\
STORAGE_DIR = '/var/lib/pgadmin4/storage'\n\
SERVER_MODE = True" > /opt/pgadmin4-6.0/web/config_local.py

RUN tar xvfz mod_wsgi-4.9.0.tar.gz
RUN cd mod_wsgi-4.9.0 && ./configure --with-python=/usr/bin/python3.7 && make -j4 && make install && cd ..
RUN echo "LoadModule wsgi_module /usr/lib64/httpd/modules/mod_wsgi.so" >> /etc/httpd/conf/httpd.conf
RUN echo "Include /etc/httpd/conf/extra/pgAdmin4.conf" >> /etc/httpd/conf/httpd.conf
RUN sed -i "4 i<a href='/pgadmin4'>pgAdmin4 6.0</a>" /var/www/html/index.html

RUN python3 -m venv /opt/pgadmin4-6.0/venv && \
    source /opt/pgadmin4-6.0/venv/bin/activate && \
    pip install -r /opt/pgadmin4-6.0/requirements.txt --use-feature=2020-resolver && \
    /opt/pgadmin4-6.0/venv/bin/python3 -m pip install --upgrade pip

RUN rm -rf mod_wsgi-4.9.0  mod_wsgi-4.9.0.tar.gz pgadmin4-6.0.tar.gz

COPY ./openeuler_pgadmin4/main.sh main.sh
RUN chown -R www:www /opt/pgadmin4-6.0
RUN yum clean all

ENV PGADMIN_DEFAULT_EMAIL="admin@domain.com"
ENV PGADMIN_DEFAULT_PASSWORD="admin"

ENTRYPOINT [ "/opt/main.sh"]
CMD ["/bin/bash"]