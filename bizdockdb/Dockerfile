FROM mariadb:10.1

MAINTAINER Marc Schaer <marc.schar@the-agile-factory.com>

#Create volumes for storing cron jobs and the database dumps
VOLUME /var/opt/db/cron/
VOLUME /var/opt/db/dumps/

#Install crontabs for sqlbump jobs
RUN apt-get update && apt-get install cron -y

#mysql configuration
RUN sed -i "s|\[mysqld\]|\[mysqld\]\nmax_connections = 500\ninnodb_buffer_pool_size = 1073741824\ninnodb_file_per_table=ON\nsymbolic-links=1\n|g" /etc/mysql/my.cnf
RUN sed -i "s/port[ \t]*=[ \t0-9]*/port = 3306/g" /etc/mysql/my.cnf

ADD bizdockdb/startup.sh /opt/startup.sh
RUN chmod +x /opt/startup.sh

ENTRYPOINT [ "/opt/startup.sh" ]
