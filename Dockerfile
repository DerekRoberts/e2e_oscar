# Dockerfile for the PDC's Endpoint collection of services
#
#
# Imports OSCAR SQL dumps and exports deidentified E2E to a Gateway container.
#
# Example:
# sudo docker pull pdcbc/endpoint
# sudo docker run -d --name=gateway --restart=always \
#   -v /encrypted/volumes/:/volumes/
#   -e GATEWAY_ID=9999 \
#   -e DOCTOR_IDS=11111,22222,...,99999
#   pdcbc/endpoint
#
#
FROM phusion/passenger-ruby19
MAINTAINER derek.roberts@gmail.com


################################################################################
# System and packages
################################################################################


# Update system and packages
#
ENV TERM xterm
ENV DEBIAN_FRONTEND noninteractive
RUN echo 'deb http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main' \
      >> /etc/apt/sources.list.d/webupd8team-java-trusty.list; \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys EEA14886; \
    echo oracle-java6-installer shared/accepted-oracle-license-v1-1 \
      select true | /usr/bin/debconf-set-selections; \
    apt-get update; \
    apt-get install --no-install-recommends -y \
      libmysql-java \
      mysql-server \
      oracle-java6-installer \
      tomcat6; \
    apt-get autoclean; \
    apt-get clean; \
    rm -rf \
      /var/tmp/* \
      /var/lib/apt/lists/* \
      /tmp/* \
      /usr/share/doc/ \
      /usr/share/doc-base/ \
      /usr/share/man/


# Configure Tomcat6
#
ENV JAVA_HOME="/usr/lib/jvm/java-6-oracle"
ENV CATALINA_HOME="/usr/share/tomcat6"
ENV CATALINA_BASE="/var/lib/tomcat6"
#
RUN mkdir -p \
      ${CATALINA_HOME}/server/classes/ \
      ${CATALINA_HOME}/shared/classes/


################################################################################
# Setup
################################################################################


# OSCAR 12 WebARchive (.war) and properties
#
COPY ./oscar/oscar12.properties /usr/share/tomcat6/
WORKDIR ${CATALINA_BASE}/webapps/
COPY ./oscar/oscar12.war.* ./
RUN cat oscar12.war.* > oscar12.war; \
    rm oscar12.war.*


# Start MySQL and create database
#
WORKDIR /database/
COPY ./mysql/ .
RUN service mysql start; \
    mysqladmin -u root password superInsecure; \
    mysql --user=root --password=superInsecure -e 'create database oscar_12_1'; \
    mysql --user=root --password=superInsecure oscar_12_1 < /database/oscar_12_1.sql; \
    rm -rf \
      /tmp/* \
      /var/tmp/*


################################################################################
# Scripts and Crontab
################################################################################


# Cron script - OSCAR SQL/E2E import/export
#
RUN SCRIPT=/run_export.sh; \
    ( \
      echo "#!/bin/bash"; \
      echo "#"; \
      echo "# Halt on error and unset variables"; \
      echo "set -e -x -o nounset"; \
      echo ""; \
      echo ""; \
      echo "# Set variables"; \
      echo "#"; \
      echo "E2E_DIFF=\${E2E_DIFF:-off}"; \
      echo "E2E_DIFF_DAYS=\${E2E_DIFF_DAYS:-14}"; \
      echo "TARGET=\${TARGET:-192.168.1.193}"; \
      echo ""; \
      echo ""; \
      echo "# Configure oscar12.properties"; \
      echo "#"; \
      echo 'sed -i \'; \
      echo '  -e "s/^#*E2E_DIFF *=.*/E2E_DIFF = ${E2E_DIFF}/" \'; \
      echo '  -e "s/^#*E2E_DIFF_DAYS *=.*/E2E_DIFF_DAYS = ${E2E_DIFF_DAYS}/" \'; \
      echo '  -e "s/^#*E2E_URL *=.*/E2E_URL = http:\/\/${TARGET}:3001\/records\/create/" \'; \
      echo "/usr/share/tomcat6/oscar12.properties"; \
      echo ""; \
      echo ""; \
      echo "# Start MySQL and import dumps"; \
      echo "#"; \
      echo "service mysql start"; \
      echo 'find /import/ -name "*.sql" | \'; \
      echo "  while read IN"; \
      echo "  do"; \
      echo "    echo 'Processing:' \${IN}"; \
      echo '    mysql --user=root --password=superInsecure oscar_12_1 < "${IN}"'; \
      echo "  done"; \
      echo "mysql --user=root --password=superInsecure -e 'commit;'"; \
      echo ""; \
      echo ""; \
      echo "# Start Tomcat6"; \
      echo "#"; \
      echo "mkdir -p /tmp/tomcat6-tmp/"; \
      echo "/sbin/setuser tomcat6 /usr/lib/jvm/java-6-oracle/bin/java \\"; \
      echo "  -Djava.util.logging.config.file=/var/lib/tomcat6/conf/logging.properties \\"; \
      echo "  -Djava.util.logging.manager=org.apache.juli.ClassLoaderLogManager \\"; \
      echo "  -Djava.awt.headless=true -Xmx1024m -Xms1024m -XX:MaxPermSize=512m -server \\"; \
      echo "  -Djava.endorsed.dirs=/usr/share/tomcat6/endorsed -classpath /usr/share/tomcat6/bin/bootstrap.jar \\"; \
      echo "  -Dcatalina.base=/var/lib/tomcat6 -Dcatalina.home=/usr/share/tomcat6 \\"; \
      echo "  -Djava.io.tmpdir=/tmp/tomcat6-tmp org.apache.catalina.startup.Bootstrap start"; \
      echo "#"; \
      echo "mysql --user=root --password=superInsecure -e 'drop database oscar_12_1;'"; \
      echo "service mysql stop"; \
    )  \
      >> ${SCRIPT}; \
    chmod +x ${SCRIPT}


################################################################################
# Volumes, ports and start command
################################################################################


# Volumes
#
RUN mkdir -p /import/
VOLUME /volumes/


# Initialize
#
WORKDIR /
CMD ["/run_export.sh"]
