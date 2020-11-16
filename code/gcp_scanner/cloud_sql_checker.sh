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
    echo "SQL_SEARCH: DBUSERS, PUB_AUTHZ_NETWORK, CIS_CHK, INVENTORY"
    exit
fi

# master function for the cloud sql scanner

function MASTER_SCANNER() {
    GCP_PROJECT=$(gcloud projects list --format="get(projectId)"\
                --filter=$SEARCH_PHRASE)

    for proj in $GCP_PROJECT; do
      API_STATUS="$(gcloud services list --enabled --filter=NAME~sqladmin.googleapis.com \
                    --project $proj)"
      if [ -z "$API_STATUS" ]
      then
        :
      else
        echo "[*] scanning project $proj for cloud sql $SQL_SEARCH"
        INSTANCES="$(gcloud sql instances list --project $proj \
                    --format="get(NAME)")"
        if [[ "$SQL_SEARCH" == "CIS_CHK" ]]
        then
          CIS_CHK
        else
          $SQL_SEARCH
        fi
      fi
    done
}

# cis benchmark
# for rational of each checks, check the description above the funtion(s)

function CIS_CHK() {
#  # GCP - CIS : 6.1.1 & 6.5
  echo "scanning - gcp - cis : 6.1.1 compliance"
  PUB_AUTHZ_NETWORK

  # GCP - CIS: 6.4
  echo "scanning - gcp - cis : 6.4 compliance"
  CIS64

  # GCP - CIS: 6.6
  echo "scanning - gcp - cis : 6.6 compliance"
  CIS66

  # GCP - CIS: 6.7
  echo "scanning - gcp - cis : 6.7 compliance"
  CIS67
}

# find all the database users

function DBUSERS() {
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
}

# scan for authorized networks for cloud sql instances
# If you don't use the cloud sql proxy, and you are connecting your
# client from your own public IP address, you need to add your
# client's public address as an authorized network.
# Without authorized network it is not possible to connect to a SQL
# instances directly using mysql/psql client.
# 6.5 Ensure that Cloud SQL database instances are not open to the world
# the following check covers both 6.5 and 6.1

function PUB_AUTHZ_NETWORK() {
    for instance in $INSTANCES; do
      AUTHZ_CHKR="$(gcloud sql instances describe $instance \
                    --project $proj --format=json | jq \
                    '.settings.ipConfiguration.authorizedNetworks')"
#                    '.settings.ipConfiguration.authorizedNetworks | .[] |.value')"
      if [[ $AUTHZ_CHKR == "null" ]]
      then
        echo "instance $instance in project $proj has NO autz nets"
      else
        echo "instance $instance in project $proj has authorizedNetworks"
        SCRUB="$(echo $AUTHZ_CHKR | jq '.[] | .value')"
        echo "$SCRUB"
      fi
    done
}

# 6.4 Ensure that the Cloud SQL database instance requires all incoming
#connections to use SSL

function CIS64() {
    for instance in $INSTANCES; do
      SQL_SSL="$(gcloud sql instances describe $instance --project $proj \
                --format=json | jq '.settings.ipConfiguration.requireSsl')"

      if [[ "$SQL_SSL" == "null" || "$SQL_SSL" == "false" ]]
      then
        echo "[FAILED-CIS664]: instance $instance on project $proj SSL NOT ENABLED"
      else
        echo "[PASSED-CIS664]: instance $instance on project $proj, ssl enabled"
      fi
    done
}

# 6.6 Ensure that Cloud SQL database instances do not have public IPs

function CIS66() {
  for instance in $INSTANCES; do
    SQL_PUB_CHKR="$(gcloud sql instances describe $instance \
                  --project=$proj  --format=json \
                  | jq -r '.ipAddresses | .[] | select(.type == "PRIMARY") | .type'
                  )"

    SQL_PUB_IPS="$(gcloud sql instances describe $instance \
                  --project=$proj  --format=json \
                  | jq -r '.ipAddresses | .[] | select(.type == "PRIMARY") | .ipAddress'
                  )"

    if [[ "$SQL_PUB_CHKR" == "PRIMARY" ]]
    then
      echo "[FAILED-CIS66]: instance $instance on project $proj : PUBLIC IP $SQL_PUB_IPS"
    elif [ -z "$SQL_PUB_CHKR" ]
    then
      echo "[PASSED-CIS66]: instance $instance on project $proj: no public ip"
    else
      :
    fi
  done

}

# 6.7 Ensure that Cloud SQL database instances are configured with
#automated backups (Scored)

function CIS67() {
    for instance in $INSTANCES; do
      BACKUP_CONFIG="$(gcloud sql instances describe $instance \
                      --project=$proj  --format=json \
                     | jq '.settings|.backupConfiguration.enabled')"

      if [[ "$BACKUP_CONFIG" == "true" ]]
      then
        echo "[PASSED-CIS67]: instance $instance on project $proj: backup configured"
      else
        echo "[FAILED-CIS67]: instance $instance on project $proj : NO BACKUP"
      fi
    done
}

# sql inventory - nNAME,DATABASE_VERSION,PRIMARY_ADDRESS,PRIVATE_ADDRESS,STATUS,backendType

function INVENTORY() {
    for instance in $INSTANCES; do
      SQL_INV="$(gcloud sql instances list  --project $proj \
               --format='csv(PROJECT,NAME,DATABASE_VERSION,PRIMARY_ADDRESS,PRIVATE_ADDRESS,STATUS,backendType)
               (PROJECT,NAME,DATABASE_VERSION,PRIMARY_ADDRESS,PRIVATE_ADDRESS,STATUS,backendType)')"
      echo "$SQL_INV"
    done
}

# run script
MASTER_SCANNER