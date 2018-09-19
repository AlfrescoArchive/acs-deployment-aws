#!/bin/bash

# Alfresco Enterprise ACS Deployment AWS
# Copyright (C) 2005 - 2018 Alfresco Software Limited
# License rights for this program may be obtained from Alfresco Software, Ltd.
# pursuant to a written agreement and any use of this program without such an
# agreement is prohibited.

if [ $# -gt 2 ]
  then
    echo "usage: endpoint.sh <url> <sleeping in second>"
fi

base_url=$1

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

share_url="$base_url/share/page"
echo "Share Endpoint is: $share_url"

echo "Checking SHARE reachability..."
STATUS=$(curl -s -o /dev/null -w ''%{http_code}'' $share_url)

RETRY=0
MAX_RETRY=20
SLEEP=30

if [ $# -eq 2 ]
  then
    SLEEP=$2
fi

while [ "$STATUS" != "200" ]; do
  if [ "$RETRY" -eq "$MAX_RETRY" ]; then
    echo "DNS resolution timed out"
    echo "DNS is not available - exit"
    exit 1
  fi
  echo "DNS is not ready yet." $(($MAX_RETRY - $RETRY)) "  Sleeping..."
  sleep $SLEEP
  STATUS=$(curl -s -o /dev/null -w ''%{http_code}'' $share_url)
  RETRY=`expr $RETRY + 1`
done

if [ "$STATUS" == "200" ]; then
  echo "Share Endpoint is reachable!"
else
  echo "Share Endpoint is reachable - exit"
  exit 1
fi