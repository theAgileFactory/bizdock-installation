FROM centos:7

MAINTAINER Pierre-Yves Cloux <pierre-yves.cloux@the-agile-factory.com>

#Install the EPEL repository
RUN yum update -y && yum install -y --setopt=tsflags=nodocs epel-release && yum clean all

#Required packages
# java-1.8.0-openjdk-devel : full JDK
# wget : user to download activator
# unzip : for unzipping various installations packages
RUN yum install -y --setopt=tsflags=nodocs java-1.8.0-openjdk-devel wget unzip && yum clean all

#Install play
ADD bizdockutils/install_play.sh /tmp/install_play.sh
RUN chmod u+x /tmp/install_play.sh;/tmp/install_play.sh

#Launching once activator and creating an application
RUN cd /opt/ && /opt/activator/activator new tmpapp play-java
RUN cd /opt/tmpapp && /opt/activator/activator playGenerateSecret

ADD bizdockutils/crypto.sh /opt/crypto.sh
RUN chmod u+x /opt/crypto.sh
