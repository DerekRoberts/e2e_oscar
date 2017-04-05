#!/bin/bash
#
# Halt on error and unset variables
#
set -eu


# Set variables
#
DEL_DUMPS=${DEL_DUMPS:-"yes"}
E2E_DIFF=${E2E_DIFF:-"off"}
E2E_DIFF_DAYS=${E2E_DIFF_DAYS:-"14"}
TARGET=${TARGET:-"gateway"}


# Make sure all operations happen in /import/
#
cd /import/


# Convert seconds to days:hours:minutes:seconds
#
function secondsDHMS {
    local I=$1
    local D=$(( I/60/60/24 ))
    local H=$(( I/60/60%24 ))
    local M=$(( I/60%60 ))
    local S=$(( I%60 ))
    printf '%02d:%02d:%02d:%02d' $D $H $M $S
    echo " d:h:m:s"
}


# Start logging
#
T_START=${SECONDS}
LOGFILE="/import/import.log"
echo "" | sudo tee -a "${LOGFILE}"


# Extract .XZ files
#
find /import/ -name "*.xz" | \
  while read IN
  do
    echo "$(date +%Y-%m-%d-%T) Extracting:" "${IN}" | sudo tee -a "${LOGFILE}"
    unxz "${IN}"
  done


# Extract .TAR files (.tgz, .gz and .bz2)
#
find /import/ -name "*.tgz" -o -name "*.gz" -o -name "*.bz2" | \
while read IN
do
  echo "$(date +%Y-%m-%d-%T) Extracting:" "${IN}" | sudo tee -a "${LOGFILE}"
  tar -xvf "${IN}" -C /import/
done


# Move any SQL files into /import/ directory
#
find /import/ -mindepth 2 -name "*.sql" -exec mv {} /import/ \;


# Nothing to do without SQL files to process
#
if [ ! -s /import/*.sql ]
then
    echo "$(date +%Y-%m-%d-%T) No SQL files found to process.  Exiting." | sudo tee -a "${LOGFILE}"
    exit
fi


# Random SQL password
#
SQL_PW=$( cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1 )


# Configure oscar12.properties
#
sed -i \
  -e "s/^#*E2E_DIFF *=.*/E2E_DIFF = ${E2E_DIFF}/" \
  -e "s/^#*E2E_DIFF_DAYS *=.*/E2E_DIFF_DAYS = ${E2E_DIFF_DAYS}/" \
  -e "s/^#*E2E_URL *=.*/E2E_URL = http:\/\/${TARGET}:3001\/records\/create/" \
  -e "s/^#*db_password *=.*/db_password = ${SQL_PW}/" \
/usr/share/tomcat6/oscar12.properties


# Start MySQL, set temp password and set up OSCAR database
#
cd /oscar_db/
service mysql start
mysql --user=root --password=superInsecure -e "use mysql; update user set password=PASSWORD('${SQL_PW}') where User='root'; flush privileges;"


# Import SQL, export E2E and delete/rename SQL (see $DEL_DUMPS=yes/no)
#
find /import/ -name "*.sql" | \
  while read IN
  do
    # Rename SQL file
    #
    PROCESSING="${IN}"-processing
    mv "${IN}" "${PROCESSING}"

    # Import SQL and log
    #
    echo "$(date +%Y-%m-%d-%T) ${IN} import started" | sudo tee -a "${LOGFILE}"
    T_SQL_START=${SECONDS}
    mysql --user=root --password="${SQL_PW}" oscar_12_1 < "${PROCESSING}"
    T_SQL_TOTAL=$( expr ${SECONDS} - ${T_SQL_START} )
    T_SQL_DHMS="$( secondsDHMS ${T_SQL_TOTAL} )"
    echo "$(date +%Y-%m-%d-%T) ${IN} import finished" | sudo tee -a "${LOGFILE}"
    echo "  SQL import time = "${T_SQL_TOTAL}" seconds" | sudo tee -a "${LOGFILE}"
    echo "                  = "${T_SQL_DHMS} | sudo tee -a "${LOGFILE}"
    echo "" | sudo tee -a "${LOGFILE}"

    # Export E2E and log
    #
    echo "$(date +%Y-%m-%d-%T) ${IN} export started" | sudo tee -a "${LOGFILE}"
    T_E2E_START=${SECONDS}
    mkdir -p /tmp/tomcat6-tmp/
    /sbin/setuser tomcat6 /usr/lib/jvm/java-6-oracle/bin/java \
        -Djava.util.logging.config.file=/var/lib/tomcat6/conf/logging.properties \
        -Djava.util.logging.manager=org.apache.juli.ClassLoaderLogManager \
        -Djava.awt.headless=true -Xmx512m -Xms64m -XX:MaxPermSize=256m -server \
        -Djava.endorsed.dirs=/usr/share/tomcat6/endorsed -classpath /usr/share/tomcat6/bin/bootstrap.jar \
        -Dcatalina.base=/var/lib/tomcat6 -Dcatalina.home=/usr/share/tomcat6 \
        -Djava.io.tmpdir=/tmp/tomcat6-tmp org.apache.catalina.startup.Bootstrap start
    T_E2E_TOTAL=$( expr ${SECONDS} - ${T_E2E_START} )
    T_RATIO=$( echo ${T_E2E_TOTAL}/${T_SQL_TOTAL} | node -p )
    T_E2E_DHMS="$( secondsDHMS ${T_E2E_TOTAL} )"
    echo "$(date +%Y-%m-%d-%T) ${IN} export finished" | sudo tee -a "${LOGFILE}"
    echo "  E2E export time = "${T_E2E_TOTAL}" seconds" | sudo tee -a "${LOGFILE}"
    echo "                  = "${T_E2E_DHMS} | sudo tee -a "${LOGFILE}"
    echo "  E2E:SQL ratio   = "${T_RATIO}"x" | sudo tee -a "${LOGFILE}"
    echo "" | sudo tee -a "${LOGFILE}"

    # Rename or delete imported SQL
    #
    if [ "${DEL_DUMPS}" = "no" ]
    then
        mv "${PROCESSING}" "${IN}"-imported$(date +%Y-%m-%d-%T)
        echo "$(date +%Y-%m-%d-%T) ${IN} renamed" | sudo tee -a "${LOGFILE}"
    else
        rm "${PROCESSING}"
        echo "$(date +%Y-%m-%d-%T) ${IN} removed" | sudo tee -a "${LOGFILE}"
    fi
  done


# Drop database, log and shut down
#
mysql --user=root --password="${SQL_PW}" -e 'drop database oscar_12_1;'
echo "$(date +%Y-%m-%d-%T) OSCAR database dropped" | sudo tee -a "${LOGFILE}"
service mysql stop
echo "$(date +%Y-%m-%d-%T) Complete" | sudo tee -a "${LOGFILE}"
T_TOTAL=$( expr ${SECONDS} - ${T_START} )
T_DHMS="$( secondsDHMS ${T_TOTAL} )"
echo "  Processing time = "${T_TOTAL}" seconds" | sudo tee -a "${LOGFILE}"
echo "                  = "${T_DHMS} | sudo tee -a "${LOGFILE}"
echo "" | sudo tee -a "${LOGFILE}"
