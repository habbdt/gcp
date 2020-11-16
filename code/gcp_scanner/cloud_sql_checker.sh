#!/bin/bash

# cloud sql scanner

set -o pipefail  # trace ERR through pipes
set -o errtrace  # trace ERR through 'time command' and other functions

SEARCH_PHRASE=$1
SQL_SEARCH=$2

if [ "$#" -ne 2 ]
then
    echo "Usage: cloud_sql_checker.sh <search_phrase> <sql_search>"
    echo "search phrase - common word in the gcp project naming pattern"
    echo "SQL_SEARCH: DBUSERS"
    exit
fi

# gcp project finder

function project() {
    GCP_PROJECT=$(gcloud projects list --format="get(projectId)"\
                --filter=$SEARCH_PHRASE)
}

# find all the database users

function DBUSERS() {
    project
    for proj in $GCP_PROJECT; do
      API_STATUS="$(gcloud services list --enabled --filter=NAME~sqladmin.googleapis.com \
                    --project $proj)"
      if [ -z "$API_STATUS" ]
      then
        :
      else
        echo "[*] scanning project $proj for database users"
        INSTANCES="$(gcloud sql instances list --project $proj \
                    --format="get(NAME)")"
        for instance in $INSTANCES; do
          USER_CHECKER="$(gcloud sql users list --instance=$instance\
                       --project=$proj  --format="get(NAME)" | sort | uniq)"
          if [ -z "$USER_CHECKER" ]
          then
            :
          else
            echo "[x] instance $instance in project $proj has users: "
            echo "$USER_CHECKER"
          fi
        done
      fi
    done
}


# execute function based on script argument

case $SQL_SEARCH in

  DBUSERS)
    DBUSERS
    ;;

esac