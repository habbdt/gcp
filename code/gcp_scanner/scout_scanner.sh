#!/bin/bash

# run scout suite against the gcp projects

set -o pipefail  # trace ERR through pipes
set -o errtrace  # trace ERR through 'time command' and other functions

# scoutSuite scanner
# https://github.com/nccgroup/ScoutSuite
# https://github.com/nccgroup/ScoutSuite/wiki/Setup
# this script assume the scoutSuite is installed on the base OS from where
# this script will run.

SEARCH_PHRASE=$1

if [ $# -eq 0 ]
then
    echo "Usage: scout_scanner.sh <search_phrase>"
    echo "search phrase - common word in the gcp project naming pattern"
    echo "e.g. sh scout_scanner.sh facebook"
    exit
fi

# scoutSuite function

function scoutSuiteRun() {
    ORG="$(gcloud organizations list  --format="get(ID)" \
          | cut -d "/" -f2)"
    GCP_PROJECT=$(gcloud projects list --format="get(projectId)" \
                  --filter=$SEARCH_PHRASE)

    date=$(date '+%Y-%m-%d')
    if [ -d "/tmp/scoutSuite-$date" ]
    then
      :
    else
      mkdir -p /tmp/scoutSuite-$date
    fi

    for proj in $GCP_PROJECT; do
      echo "[x] running scoutSuite for project $proj"
      scout gcp --user-account -f --max-workers 50 --report-dir /tmp/scoutSuite-$date \
          --organization-id $ORG --project-id $proj  --no-browser 2>&1 > /dev/null
      exit
    done
}

# run

scoutSuiteRun
