#!/bin/bash

# scan gcs features

set -o pipefail # trace ERR through pipes
set -o errtrace # trace ERR through 'time command' and other functions

SEARCH_PHRASE=$1
GCS_SCAN=$2

if [ "$#" -ne 2 ]; then
  echo "Usage: gcs_generic_scanner.sh <search_phrase> <gcs_search>"
  echo "search phrase - common word in the gcp project naming pattern"
  echo "GCS_SEARCH: BACKEND_BUCKETS"
  exit
fi

# scan backend buckets

function BACKEND_BUCKETS() {
  GCP_PROJECT=$(gcloud projects list --format="get(projectId)" \
    --filter=$SEARCH_PHRASE)

  for proj in $GCP_PROJECT; do
    API_STATUS="$(gcloud services list --enabled --filter=NAME~compute.googleapis.com \
      --project $proj)"
    if [ -z "$API_STATUS" ]; then
      :
    else
      echo "[x] scanning project $proj for gcs buckets $GCS_SCAN"
      BACKEND_BUCKETS="$(gcloud compute backend-buckets list  --project=$proj)"
      if [ -z "$BACKEND_BUCKETS" ]
      then
        :
      else
        echo "[x] project $proj backend buckets (gclb)"
        echo "$BACKEND_BUCKETS"
      fi
    fi
  done
}


# execute function based on script argument

case $GCS_SCAN in

  BACKEND_BUCKETS)
    BACKEND_BUCKETS
    ;;

esac
