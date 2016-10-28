#!/bin/bash
#
# Halt on error and unset variables
#
set -eu


# Check parameters
#
if [ $# -ne 1 ]
then
    echo
    echo "This script consumes SQL files and exports E2E to a Gateway."
    echo
    echo "Usage: "
    echo "  [VARS] ./import.sh PATH"
    echo 
    echo "Path:"
    echo "  Location of SQL dumps to consume"
    echo
    echo "Optional variables:"
    echo "  TAG   = latest [default], dev or any other Docker tags"
    echo "  DEL   = no [default], yes will delete consumed files"
    echo "  PULL  = yes [default], no will not update the Docker image"
    echo "  NUKE  = no [default], yes will drop all MongoDb records (testing)"
    echo "  BUILD = no [default], yes will build and use a local image (testing)"
    echo
    echo "Notes:"
    echo "  Gateway and Gateway database containers already"
    echo "  be present and running in Docker containers."
    echo "  Consumed files are renamed with a timestamp."
    echo
    exit
fi


# Set import directory and ensure absolute path
#
SQL_PATH=$( realpath "${1}" )


# Variables SQL delete, Docker and Mongo record drops (testing)
#
DEL=${DEL:-"no"}
TAG=${TAG:-"latest"}
PULL=${PULL:-"yes"}
NUKE=${NUKE:-"no"}
BUILD=${BUILD:-"no"}


# If BUILD=yes, build and use local image, otherwise use Docker Hub
#
if [ "${BUILD}" = "yes" ]
then
    sudo docker build -t local_e2e_oscar .
    IMAGE="local_e2e_oscar"
else
    IMAGE="hdcbc/e2e_oscar:${TAG}"
fi


# Pull Docker image, unless specified otherwise or using BUILD=yes
#
[ "${PULL}" = "no" ]|| [ "${BUILD}" = "yes" ]|| \
    sudo docker pull hdcbc/e2e_oscar:"${TAG}"


# Nuke MongoDb records, but only if explicity specified (w/ NUKE=yes)
#
[ "${NUKE}" != "yes" ]|| \
    sudo docker exec -ti gateway_db mongo query_gateway_development --eval 'db.records.drop();'


# Beginning record count and start time
#
RECORDS_BEFORE=$( sudo docker exec -ti gateway_db mongo query_gateway_development --eval 'db.records.count();' | grep -v -e "MongoDB" -e "connecting" )
TIME_BEFORE=$( date +%s )


# Run import container
#
sudo docker run -ti --rm --name e2o -h e2o -e DEL_DUMPS="${DEL}" --link gateway --volume "${SQL_PATH}":/import:rw "${IMAGE}"


# Updated record count and total time
#
TIME_AFTER=$( date +%s )
TIME_TOTAL=$( expr "${TIME_AFTER}" - "${TIME_BEFORE}" )
RECORDS_AFTER=$( sudo docker exec -ti gateway_db mongo query_gateway_development --eval 'db.records.count();' | grep -v -e "MongoDB" -e "connecting" )


# Clean up sample10.sql files, if used for testing
#
if [ ! -s ./test/sample10.sql ]
then
    rm ./test/sample10.sql-imported* || true
    git checkout ./test/sample10.sql
fi


# Echo results
#
echo
echo "Records"
echo "  Before:  ${RECORDS_BEFORE}"
echo "  After:   ${RECORDS_AFTER}"
echo
echo "Export time"
echo "  Seconds: ${TIME_TOTAL}"
echo
