#!/bin/bash

#  ___                              _      ___ _    _  __
# | _ \___  ___ _ _ _ __  __ _ _ _ ( )___ | __| |  | |/ /
# |  _/ _ \/ _ \ '_| '  \/ _` | ' \|/(_-< | _|| |__| ' <
# |_| \___/\___/_| |_|_|_\__,_|_||_| /__/ |___|____|_|\_\
#
#
# search stackdriver logs for supplied search word.
# a.k.a poorman's elk solution.

SEARCH_PHRASE=$1
LOGS_FILTER=$2

if [ "$#" -ne 2 ]
then
    echo "Usage: cloud_logging_scanner.sh.sh <search_phrase>"
    echo "SEARCH_PHRASE - common word in the gcp project naming pattern"
    echo "LOGS_FILTER - search for centain info in logs e.g. callerIp"
    exit
fi


function project() {
    GCP_PROJECT=$(gcloud projects list --format="get(projectId)"\
                --filter=$SEARCH_PHRASE)
}

function logs_scanner() {
    project
    for proj in $GCP_PROJECT; do
      echo "[*] scanning project $proj"
      API_STATUS="$(gcloud services list --enabled --filter=NAME~logging.googleapis.com \
                    --project $proj
                  )"
      if [ -z "$API_STATUS" ]
      then
        :
      else
        gcloud beta logging read --project $proj \
             --freshness=30d  | grep $LOGS_FILTER >> /tmp/$proj.txt
      fi
    done
}

# run function
logs_scanner