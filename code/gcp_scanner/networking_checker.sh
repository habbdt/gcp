#!/bin/bash

# this script checks for presence of shared vpc
# if there is a shared vpc present, it list out the
# host project and associated guest projects

set -o pipefail  # trace ERR through pipes
set -o errtrace  # trace ERR through 'time command' and other functions

SEARCH_PHRASE=$1
NET_SVC=$2

if [ "$#" -ne 2 ]
then
    echo "Usage: shared_vpc_checker.sh <search_phrase> <net_svc>"
    echo "search phrase - common word in the gcp project naming pattern"
    echo "net_svc: shared_vpc_finder, vpc_peering_finder, quadzeros_fwrules"
    exit
fi

# gcp project finder

function project() {
    GCP_PROJECT=$(gcloud projects list --format="get(projectId)"\
                --filter=$SEARCH_PHRASE)
}

# shared vpc finder function

function shared_vpc_finder() {
    project
    for proj in $GCP_PROJECT; do
      API_STATUS="$(gcloud services list --enabled --filter=NAME~compute.googleapis.com \
                    --project $proj)"
      if [ -z "$API_STATUS" ]
      then
        :
      else
        echo "[*] scanning project $proj"
        VPC_CHECKER="$(gcloud compute shared-vpc list-associated-resources $proj 2>&1 > /dev/null)"
        RET_VAL=$?
        if [ $RET_VAL -ne 0 ]
        then
          echo "[!] project $proj is not a host project for shared vpc"
        else
          echo "[x] project $proj SHARED VPC HOST PROJECT"
          ASSOCITAED_PROJ="$(gcloud compute shared-vpc list-associated-resources $proj)"
          echo "[x] ASSOCITED PROJECTS"
          echo "$ASSOCITAED_PROJ"
        fi
      fi
    done
}

# vpc peering finder

function vpc_peering_finder() {
    project
    for proj in $GCP_PROJECT; do
      API_STATUS="$(gcloud services list --enabled --filter=NAME~compute.googleapis.com \
                    --project $proj)"
      if [ -z "$API_STATUS" ]
      then
        :
      else
        PEERING="$(gcloud compute networks peerings list --project=$proj)"
        if [ -z "$PEERING" ]
        then
          :
        else
          echo "[x] project $proj has VPC PEERING - DETAILS BELOW"
          echo "$PEERING"
        fi
      fi
    done
}

# find any firewall rules with quad zeros

function quadzeros_fwrules() {
    project
    for proj in $GCP_PROJECT; do
      API_STATUS="$(gcloud services list --enabled --filter=NAME~compute.googleapis.com \
                    --project $proj)"
      if [ -z "$API_STATUS" ]
      then
        :
      else
        QUAD_ZERO="$(gcloud compute firewall-rules list --project $proj\
                    --format="table(name,network,direction,priority,sourceRanges.list())"  \
                    --filter=SOURCE_RANGES~0.0.0.0)"
        echo "[!] project $proj has FIREWALL RULES WITH QUAD_ZEROS IN SOURCE_RANGES"
        echo "$QUAD_ZERO"
      fi
    done
}

# execute function based on script argument

case $NET_SVC in

  shared_vpc_finder)
    shared_vpc_finder
    ;;

  vpc_peering_finder)
    vpc_peering_finder
    ;;

  quadzeros_fwrules)
    quadzeros_fwrules
    ;;

esac