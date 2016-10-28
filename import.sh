#!/bin/bash
#
# Halt on error and unset variables
#
set -eux


# Check parameters
#
if [ $# -ne 1 ]
then
    echo
    echo "This script consumes SQL files and exports E2E to a Gateway."
    echo
    echo "Usage: "
    echo "  ./import.sh PATH"
    echo
    echo "Path:"
    echo "  Location of SQL dumps to consume"
    echo
    echo "Optional variables:"
    echo "  TAG=latest [default], dev or any other Docker tags"
    echo "  DEL=no [default], yes will delete consumed files"
    echo
    echo "Notes:"
    echo "  Gateway and Gateway database containers already"
    echo "  be present and running in Docker containers."
    echo "  Consumed files are renamed with a timestamp."
    echo
    exit
fi


# Save SQL_PATH, converts to absolute
#
SQL_PATH=$( realpath "${1}" )
TAG=${TAG:-"latest"}
DEL=${DEL:-"no"}


# Pull Docker image
#
sudo docker pull hdcbc/e2e_oscar:"${TAG}"


# Save record count and start time
#
RECORDS_BEFORE=$( sudo docker exec -ti gateway_db mongo query_gateway_development --eval 'db.records.count();' | grep -v -e "MongoDB" -e "connecting" )
TIME_BEFORE=$( date +%s )


# Run import container
#
sudo docker run -ti --rm --name e2o -h e2o -e DEL_DUMPS="${DEL}" --link gateway --volume "${SQL_PATH}":/import:rw hdcbc/e2e_oscar:"${TAG}"


# Save new record count and calculate run time
#
TIME_AFTER=$( date +%s )
TIME_TOTAL=$( expr "${TIME_AFTER}" - "${TIME_BEFORE}" )
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
