#!/bin/bash

# find resources by network tags

NTAG=$1
SEARCH_TERM=$2

if [ "$#" -ne 2 ]
then
    echo "Usage: find_by_tags.sh <network_tag> <search_term>"
    echo "search_term: search using common term in the gcp project naming pattern e.g. 3m-prod"
    exit
fi

# projects function

function project() {
    GCP_PROJECT=$(gcloud projects list --format="get(projectId)" --filter=$SEARCH_PHRASE)
}

# find GCE instances by network tags

function network_tags() {
    project
    for proj in $GCP_PROJECT; do
      echo "[*] scanning project $proj"
      API_STATUS="$(gcloud services list --enabled --filter=NAME~compute \
                    --project $proj
                  )"
      if [ -z "$API_STATUS" ]
      then
        :
      else
        RESOURCE="$(gcloud compute instances list --project=$proj \
                  --filter='-tags =$NTAG'
               )"
        if [ -z "$RESOURCE" ]
        then
          :
        else
          echo "[x] resource tag $NTAG is present in project $proj"
        fi
      fi
    done
}

# call function

network_tags