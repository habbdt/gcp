#!/bin/bash

# check service accounts with exported private keys

TIME=$1
SEARCH_TERM=$2

if [ "$#" -ne 2 ]
then
    echo "Usage: gcp_service_accounts_scanner.sh <time> <search_term>"
    echo "time: ALL, 6MON (6m), 1YEAR(1y), 2YEAR(2y), 3YEAR(3y), 4YEAR(4y), 5YEAR(5y), ..so on"
    echo "ALL: List all the service accounts with all the exported keys \
          regardless of the time those were created"
    echo "6MON:  List all the service accounts with exported keys created 6 months ago  "
    echo "1YEAR: List all the service accounts with exported keys created 12 months ago "
    echo "2YEAR: List all the service accounts with exported keys created 24 months ago "
    echo "3YEAR: List all the service accounts with exported keys created 36 months ago "
    echo "4YEAR: List all the service accounts with exported keys created 48 months ago "
    echo "5YEAR: List all the service accounts with exported keys created 60 months ago "
    echo "search_term: search using common term in the gcp project naming pattern e.g. 3m-prod"
    exit
fi

# general projects checker function

function project() {
    GCP_PROJECT=$(gcloud projects list --format="get(projectId)" \
                  --filter=$SEARCH_TERM)
}

# scan service accounts for user managed keys

function SERVICE_ACCOUNTS_KEYS() {
    project
    for proj in $GCP_PROJECT; do
    LIST_SAS="$(gcloud  iam service-accounts list  --project $proj \
                --format="get(EMAIL)")"
    for user_mng in $LIST_SAS ; do
      if [[ "$TIME" == "ALL" ]]
      then
        USER_MNG="$(gcloud  iam service-accounts keys list --iam-account=$user_mng \
                  --managed-by user)"
        if [ -z "$USER_MNG" ]
        then
          :
        else
          echo "[*] scanning project $proj for service accounts keys - user managed (ALL)"
          echo "$user_mng \n $USER_MNG"
        fi
      else
        DATE_DEF="$(date -v -$TIME "+%Y-%m-%d")"
        USER_MNG="$(gcloud  iam service-accounts keys list --iam-account=$user_mng \
                  --managed-by user --created-before=$DATE_DEF)"
        if [ -z "$USER_MNG" ]
        then
          :
        else
          echo "[*] scanning project $proj for service accounts keys - user managed - older than $TIME"
          echo "$user_mng \n $USER_MNG"
        fi
      fi
    done
done
}

# call the function

SERVICE_ACCOUNTS_KEYS