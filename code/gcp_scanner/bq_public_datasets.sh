#!/bin/bash

# scan Priceline BQ datasets - made public or outsiders added provided access to the dataset

set -o pipefail # trace ERR through pipes
set -o errtrace # trace ERR through 'time command' and other functions

SEARCH_PHRASE=$1

if [ "$#" -ne 1 ]; then
  echo "Usage: bq_public_datasets.sh <search_phrase>"
  echo "search phrase - common word in the gcp project naming pattern"
  exit
fi

for proj in $(gcloud projects list --format="get(projectId)" --filter=$SEARCH_PHRASE); do
    echo "[*] scanning project $proj for bq datasets"
    API_STATUS="$(gcloud services list --enabled --filter=NAME~bigquery --project $proj)"
    if [ -z "$API_STATUS" ]
    then
      :
    else
      for dataset in $(bq ls --project_id  $proj); do
          BQ_ACL="$(bq show  $proj:$dataset)"
          all_users="$(echo $BQ_ACL | grep allUsers)"
          all_auth="$(echo $BQ_ACL | grep allAuthenticatedUsers)"

          if [ -z "$all_users" ]
          then
                :
          else
                echo "[!] Open to all users: $dataset"
          fi

          if [ -z "$all_auth" ]
          then
                :
          else
                echo "[!] Open to all authenticated users: $dataset"
          fi
      done
    fi
done