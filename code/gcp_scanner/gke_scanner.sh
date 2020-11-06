#!/bin/bash

# fetches all the deployed container images from a gke cluster
# fetches services with external IPs

set -o pipefail  # trace ERR through pipes
set -o errtrace  # trace ERR through 'time command' and other functions

SEARCH_PHRASE=$1

if [ $# -eq 0 ]
then
    echo "Usage: gke_scanner.sh <search_phrase>"
    echo "search phrase - common word in the gcp project naming pattern"
    echo "e.g. sh gke_scanner.sh facebook"
    exit
fi

# check if the krew and image module in krew are installed

function gke_checker() {
    KREW="$(kubectl krew list images 2>&1 > /dev/null)"
    RETVAL=$?

    if [ $RETVAL -eq 0 ]
    then
      master_scanner
    else
      echo "Install krew : "
      echo "brew install krew"
      echo "kubectl krew install images"
      exit
    fi
}


# gcp projects

function project() {
    GCP_PROJECT=$(gcloud projects list --format="get(projectId)" \
                  --filter=$SEARCH_PHRASE)
}

# gke container images scanner

function  master_scanner() {
    project
    for proj in $GCP_PROJECT; do
      CLUSTERS="$(gcloud container clusters list \
                --project $proj --uri)"
      if [ -z "$CLUSTERS" ]; then
        :
      else
        for element in $CLUSTERS; do
          GKE_CLUSTER="$(echo $element | rev | cut -d "/" -f 1 | rev)"
          GKE_REGION="$(echo $element | rev | cut -d "/" -f 3 | rev)"
          #image_scan
          #k8s_services
          ingress_controller
        done
      fi
    done
}

# rbac scan

function image_scan() {
  gcloud container clusters get-credentials \
        $GKE_CLUSTER --region $GKE_REGION --project $proj 2>&1 > /dev/null

  echo "[*] Scanning $GKE_CLUSTER in the project $proj for container images"
  IMGS="$(kubectl images -A -c3)"
  echo "$GKE_CLUSTER:$proj"
  echo "$IMGS"
}

# services scan

function k8s_services() {
  gcloud container clusters get-credentials \
        $GKE_CLUSTER --region $GKE_REGION --project $proj 2>&1 > /dev/null

  echo "[*] Scanning $GKE_CLUSTER in the project $proj for the services with external IPs"
  SVCS="$(kubectl get services --all-namespaces -o json | jq -r '.items[] | { name: .metadata.name, ns: .metadata.namespace, ip: .status.loadBalancer?|.ingress[]?|.ip  }')"
  echo "$SVCS"
}

# ingress endpoints

function ingress_controller() {
  gcloud container clusters get-credentials \
        $GKE_CLUSTER --region $GKE_REGION --project $proj 2>&1 > /dev/null

  echo "[*] Scanning $GKE_CLUSTER in the project $proj for the ingress addresses"
  INGRESS="$(kubectl get ingress -A)"
  echo "$INGRESS"
}


# run

gke_checker