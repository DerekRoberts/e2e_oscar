#!/bin/bash
#
# Halt on error and unset variables
set -e -x -o nounset


# Set variables
#
E2E_DIFF=${E2E_DIFF:-off}
E2E_DIFF_DAYS=${E2E_DIFF_DAYS:-14}
TARGET=${TARGET:-192.168.1.193}


# Configure oscar12.properties
#
sed -i \
  -e "s/^#*E2E_DIFF *=.*/E2E_DIFF = ${E2E_DIFF}/" \
  -e "s/^#*E2E_DIFF_DAYS *=.*/E2E_DIFF_DAYS = ${E2E_DIFF_DAYS}/" \
  -e "s/^#*E2E_URL *=.*/E2E_URL = http:\/\/${TARGET}:3001\/records\/create/" \
/usr/share/tomcat6/oscar12.properties


# Start MySQL and import dumps
#
service mysql start
find /import/ -name "*.sql" | \
  while read IN
  do
    echo 'Processing:' ${IN}
    mysql --user=root --password=superInsecure oscar_12_1 < "${IN}"
  done
mysql --user=root --password=superInsecure -e 'commit;'


# Start Tomcat6
#
mkdir -p /tmp/tomcat6-tmp/
/sbin/setuser tomcat6 /usr/lib/jvm/java-6-oracle/bin/java \
  -Djava.util.logging.config.file=/var/lib/tomcat6/conf/logging.properties \
  -Djava.util.logging.manager=org.apache.juli.ClassLoaderLogManager \
  -Djava.awt.headless=true -Xmx1024m -Xms1024m -XX:MaxPermSize=512m -server \
  -Djava.endorsed.dirs=/usr/share/tomcat6/endorsed -classpath /usr/share/tomcat6/bin/bootstrap.jar \
  -Dcatalina.base=/var/lib/tomcat6 -Dcatalina.home=/usr/share/tomcat6 \
  -Djava.io.tmpdir=/tmp/tomcat6-tmp org.apache.catalina.startup.Bootstrap start
#
mysql --user=root --password=superInsecure -e 'drop database oscar_12_1;'
service mysql stop
