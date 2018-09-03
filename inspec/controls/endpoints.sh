#!/bin/bash

if [ $# -gt 2 ]
  then
    echo "usage: endpoint.sh <url> <sleeping in second>"
fi

base_url=$1

echo "Share Endpoint is: $base_url/share/page"

acs_url="$base_url/alfresco/service/index"
echo "Alfresco Endpoint is: $acs_url"

echo "Checking ACS reachability..."
STATUS=$(curl -s -o /dev/null -w ''%{http_code}'' $acs_url)

RETRY=0
MAX_RETRY=20
SLEEP=30

if [ $# -eq 2 ]
  then
    SLEEP=$2
fi

while [ "$STATUS" != "401" ]; do
  if [ "$RETRY" -eq "$MAX_RETRY" ]; then
    echo "DNS resolution timed out"
    echo "DNS is not available - exit"
    exit 1
  fi
  echo "DNS is not ready yet. Retry:" $(($MAX_RETRY - $RETRY)) "  Sleeping..."
  sleep $SLEEP
  STATUS=$(curl -s -o /dev/null -w ''%{http_code}'' $acs_url)
  RETRY=`expr $RETRY + 1`
done

if [ "$STATUS" == "401" ]; then
  echo "Alfresco Endpoint is reachable!"
else
  echo "Alfresco Endpoint is reachable - exit"
  exit 1
fi