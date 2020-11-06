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
        external_ips
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
                            | tr -s '[:blank:]' ','
                          )"
    for ext_ip in $EXTERNAL_IPS_RESERVED ; do
      if [ -n "$ext_ip" ]
      then
        echo "[!] external ip address is $ext_ip"
      fi
    done
}

external_ip_checker
