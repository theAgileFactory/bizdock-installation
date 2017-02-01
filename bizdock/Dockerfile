FROM centos:7

MAINTAINER Marc Schaer

# Set the locale
RUN localedef --quiet -c -i en_US -f UTF-8 en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8
ENV LC_ALL en_US.UTF-8

#Port
EXPOSE 8080

#Create volumes
VOLUME /opt/start-config/
VOLUME /opt/artifacts/maf-file-system/

#epel-repo
RUN yum update -y && yum install -y --setopt=tsflags=nodocs epel-release && yum clean all

#Install required and useful packages
RUN yum install -y --setopt=tsflags=nodocs bc which unzip tar mariadb telnet wget curl bzip2 xz java-1.8.0-openjdk && yum clean all

#mysql configuration
RUN echo -e "[client]\ndefault-character-set=utf8\n" >> /etc/my.cnf

RUN mkdir -p /opt/maf/maf-desktop/server
RUN mkdir -p /tmp/deadletters/ && mkdir -p /tmp/deadletters-reprocessing

#Add compiled files
ADD bizdock/*.zip /opt/maf/
ADD bizdock/*.jar /opt/maf/
RUN unzip /opt/maf/merged-dbmdl-framework-$(ls /opt/maf/merged-dbmdl-framework-*.zip | cut -d '-' -f 4-5 | cut -d '.' -f 1-3).zip -d /opt/maf/dbmdl-framework && chmod u+x /opt/maf/dbmdl-framework/scripts/*
RUN unzip /opt/maf/merged-maf-dbmdl-$(ls /opt/maf/merged-maf-dbmdl-*.zip | cut -d '-' -f 4-5 | cut -d '.' -f 1-3).zip -d /opt/maf/maf-dbmdl && chmod u+x /opt/maf/maf-dbmdl/scripts/*
RUN unzip /opt/maf/merged-maf-desktop-$(ls /opt/maf/merged-maf-desktop-*.zip | cut -d '-' -f 4-5 | cut -d '.' -f 1-3).zip -d /opt/maf/maf-desktop
RUN unzip /opt/maf/maf-desktop/play-apps/maf-desktop-app-dist.zip -d /opt/maf/maf-desktop/server && chmod u+x /opt/maf/maf-desktop/server/maf-desktop-app-dist/bin/maf-desktop-app

ADD bizdock/startup.sh bizdock/update_bashrc.sh /opt/scripts/

RUN chmod u+x /opt/scripts/startup.sh && chmod u+x /opt/scripts/update_bashrc.sh 

ENTRYPOINT [ "/opt/scripts/startup.sh" ]
