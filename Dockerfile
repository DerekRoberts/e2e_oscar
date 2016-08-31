# Dockerfile for the PDC's Endpoint collection of services
#
#
# Imports OSCAR SQL dumps and exports deidentified E2E to a Gateway container.
#
# Example:
# sudo docker pull hdcbc/gateway
# sudo docker run -d --name=gateway --restart=always \
#   -v /encrypted/volumes/:/volumes/
#   -e GATEWAY_ID=9999 \
#   -e DOCTOR_IDS=11111,22222,...,99999
#   hdcbc/gateway
#
#
FROM phusion/passenger-ruby19
MAINTAINER derek.roberts@gmail.com


################################################################################
# System and packages
################################################################################


# Environment variables
#
ENV TERM xterm
ENV DEBIAN_FRONTEND noninteractive
ENV JAVA_HOME="/usr/lib/jvm/java-6-oracle"
ENV CATALINA_HOME="/usr/share/tomcat6"
ENV CATALINA_BASE="/var/lib/tomcat6"


# Update system, add PPA and install packages
#
RUN add-apt-repository -y ppa:webupd8team/java; \
    echo oracle-java6-installer shared/accepted-oracle-license-v1-1 \
      select true | /usr/bin/debconf-set-selections; \
    apt-get update; \
    apt-get install --no-install-recommends -y \
      libmysql-java \
      mysql-server \
      oracle-java6-installer \
      oracle-java6-set-default \
      tomcat6; \
    apt-get autoclean; \
    apt-get clean; \
    rm -rf \
      /var/tmp/* \
      /var/lib/apt/lists/* \
      /tmp/* \
      /usr/share/doc/ \
      /usr/share/doc-base/ \
      /usr/share/man/ \
      /var/cache/oracle-jdk6-installer


# Configure Tomcat6
#
RUN mkdir -p \
      ${CATALINA_HOME}/server/classes/ \
      ${CATALINA_HOME}/shared/classes/ \
      ${CATALINA_BASE}/webapps/


################################################################################
# Setup
################################################################################


# Assemble WebARchive (.war)
#
COPY ./app/oscar12.war.* ./
RUN cat /oscar12.war.* > ${CATALINA_BASE}/webapps/oscar12.war; \
    rm /oscar12.war.*


# Start MySQL and create database
#
COPY ./app/oscar_12_1.sql ./
RUN service mysql start; \
    mysqladmin -u root password superInsecure; \
    mysql --user=root --password=superInsecure -e 'create database oscar_12_1'; \
    mysql --user=root --password=superInsecure oscar_12_1 < /oscar_12_1.sql; \
    rm -rf \
      /oscar_12_1.sql \
      /tmp/* \
      /var/tmp/*


# Copy properties and entrypoint
#
COPY ./config/oscar12.properties /usr/share/tomcat6/
COPY ./config/entrypoint.sh /


################################################################################
# Volumes, ports and start command
################################################################################


# Initialize
#
VOLUME /import/
CMD ["/entrypoint.sh"]
