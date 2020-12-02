#!/bin/bash

# gce scanners

set -o pipefail  # trace ERR through pipes
set -o errtrace  # trace ERR through 'time command' and other functions

SEARCH_PHRASE=$1
SVC=$2

if [ "$#" -ne 2 ]
then
    echo "Usage: gce_scanners.sh <search_phrase> <scan_svc>"
    echo "search phrase - common word in the gcp project naming pattern"
    echo "scan for: os_finder"
    exit
fi

# find os of the vm

function os_finder() {
    GCP_PROJECT=$(gcloud projects list --format="get(projectId)"\
                --filter=$SEARCH_PHRASE)

    for proj in $GCP_PROJECT; do
      API_STATUS="$(gcloud services list --enabled --filter=NAME~compute.googleapis.com \
                    --project $proj)"
      if [ -z "$API_STATUS" ]
      then
        :
      else
        INSTANCES="$(gcloud compute instances list --project $proj --uri)"
        if [ -z "$INSTANCES" ]
        then
          :
        else
          for instance in $INSTANCES; do
            ZONE="$(echo $instance | cut -d '/' -f9)"
            NAME="$(echo $instance | cut -d "/" -f11)"
            OS="$(gcloud compute instances describe $NAME --zone $ZONE --project $proj \
                  --format=json | jq '.disks | .[] | .licenses | .[]' | cut -d "/" -f10 | tr '\n' ',')"
            echo "$NAME,$proj,$OS"
          done
        fi
      fi
    done
}

# execute function based on script argument

case $SVC in

  os_finder)
    os_finder
    ;;

esac