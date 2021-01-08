#!/bin/bash

# script to get the public ips associated with gce instances and
# external ips created separately for a gcp project


# master scanner for gcp resources

SEARCH_PHRASE=$1

if [ $# -eq 0 ]
then
    echo "Usage: gcp_public_ip.sh <search_phrase>"
    echo "search phrase - common word in the gcp project naming pattern"
    exit
fi


function project() {
    GCP_PROJECT=$(gcloud projects list --format="get(projectId)" --filter=$SEARCH_PHRASE)
}

function external_ip_checker() {
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
        gce_instances_extip
        gclb_frontend_ip
        external_ips
        cloudsql_ips
      fi
    done
}

# find external ip addresses attached to gce instances

function gce_instances_extip() {
      COMPUTE_EXTERNAL_IP="$(gcloud compute instances list --project=$proj \
                    --format="get(EXTERNAL_IP)"
                    )"
      for ext_ip in $COMPUTE_EXTERNAL_IP ; do
        if [ -n "$ext_ip" ]
        then
            echo "[!] public ip attached to gce instances is $ext_ip"
        fi
      done
}

# reserved external IPs

function external_ips() {
    EXTERNAL_IPS_RESERVED="$(gcloud compute addresses list --format="get(ADDRESS,STATUS)" \
                           --project $proj | tr -s '[:blank:]' ','
                          )"
    for ext_ip in $EXTERNAL_IPS_RESERVED ; do
      if [ -z "$ext_ip" ]
      then
        :
      else
        echo "[!] external ip address is $ext_ip"
      fi
    done
}

# cloud sql public IPs

function cloudsql_ips() {
    API_STATUS="$(gcloud services list --enabled --filter=NAME~sqladmin.googleapis.com \
                  --project $proj
                )"
    if [ -z "$API_STATUS" ]
    then
      :
    else
      SQL_INSTANCES="$(gcloud sql instances list --format=json --project=$proj \
                      |  jq '.[] | .ipAddresses |.[] | .ipAddress'
                      )"
      for ext_ip in $SQL_INSTANCES ; do
        if [ -n "$ext_ip" ]
        then
          echo "[!] cloudsql public ip is: $ext_ip"
        fi
      done
    fi
}

# gclb frontend external IP address

function gclb_frontend_ip() {
  FORWARDING_RULE_NAME="$(gcloud compute forwarding-rules list --project=$proj \
                        --format='csv(NAME,REGION)' | sed '1d')"

  for rule in $FORWARDING_RULE_NAME ; do
    NAME="$(echo $rule | cut -d "," -f1)"
    REGION="$(echo $rule | cut -d "," -f2)"

    if [ -z "$REGION" ]
    then
      GLOBAL_FW_IP="$(gcloud compute forwarding-rules describe $NAME \
                    --global  --format=json --project $proj | jq '.IPAddress')"
      echo "[!] gclb frontend external ip is: $GLOBAL_FW_IP"
    else
      REGIONAL_FW_IP="$(gcloud compute forwarding-rules describe $NAME \
                    --region $REGION --format=json --project $proj| jq '.IPAddress')"
      echo "[!] gclb frontend external ip is: $REGIONAL_FW_IP"
    fi
  done
}

# call function
external_ip_checker
