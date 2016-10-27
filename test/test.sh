#!/bin/bash
#
# Halt on error and unset variables
set -eu


# Usage: ./this_script.sh SQL_PATH DEL_DUMPS
#
# - SQL_PATH  = path to SQL for import, defaults to current dir
# - DEL_DUMPS = yes/no to deleting consumed SQL dumps

# Variables and parameters
#
SQL_PATH=${1:-""}
DEL_DUMPS=${2:-"no"}


# Use absolute paths, default to current directory
#
if [ -z "${SQL_PATH}" ]
then
    SQL_PATH=$( pwd )
else
    SQL_PATH=$( realpath ${SQL_PATH} )
fi


# CD.. and prep for Docker run
#
cd ..
sudo docker rm -fv e2o || true
sudo docker build -t e2o .


# Save record count and start time
#
RECORDS_BEFORE=$( sudo docker exec -ti gateway_db mongo query_gateway_development --eval 'db.records.count();' | grep -v -e "MongoDB" -e "connecting" )
TIME_BEFORE=$( date +%s )


# Drop records and run import container
#
sudo docker exec -ti gateway_db mongo query_gateway_development --eval 'db.records.drop();'
sudo docker run -ti --rm --name e2o -h e2o -e DEL_DUMPS=${DEL_DUMPS} --link gateway --volume ${SQL_PATH}:/import:rw e2o


# Save new record count and calculate run time
#
TIME_AFTER=$( date +%s )
TIME_TOTAL=$( expr ${TIME_AFTER} - ${TIME_BEFORE} )
RECORDS_AFTER=$( sudo docker exec -ti gateway_db mongo query_gateway_development --eval 'db.records.count();' | grep -v -e "MongoDB" -e "connecting" )


# Echo results
#
echo
echo "Before: ${RECORDS_BEFORE}"
echo " - drop -"
echo "After:  ${RECORDS_AFTER}"
echo
echo "Total time: ${TIME_TOTAL} seconds"
echo
