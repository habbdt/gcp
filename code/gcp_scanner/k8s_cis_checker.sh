#!/bin/bash

# k8s cis checker

SEARCH_PHRASE=$1

if [ $# -eq 0 ]
then
    echo "Usage: k8s_cis_checker.sh <search_phrase>"
    echo "search phrase - common word in the gcp project naming pattern"
    echo "e.g. sh k8s_cis_checker.sh facebook"
    exit
fi

# master function to iterate through clusters and nodepools

function project() {
    GCP_PROJECT=$(gcloud projects list --format="get(projectId)" --filter=$SEARCH_PHRASE)
}

# cis benchmark checker function

function cis_checker() {
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
          NODE_POOL="$(gcloud container node-pools list --cluster $GKE_CLUSTER \
            --region $GKE_REGION --project $proj --format="get(NAME)")"
          echo "[*] CIS Benchmarking $GKE_CLUSTER"
          cis653
          cis662
          cis663
          cis665
          cis683
          cis655
          cis651
          cis622
          cis621
          cis631
        done
      fi
    done
}

# 6.5.3 Ensure Node Auto-Upgrade is enabled for GKE nodes (Scored)

function cis653() {
  for npool in $NODE_POOL; do
    AUTO_UPGRADE=$(gcloud container node-pools describe $npool \
      --cluster $GKE_CLUSTER --region $GKE_REGION --project $proj \
      --format=json | jq '.management.autoUpgrade')

    if [[ $AUTO_UPGRADE == "true" ]]; then
      echo "[PASSED] 6.5.3 Ensure Node Auto-Upgrade is enabled for GKE nodes (Scored)"
      echo "autoUpgrade: $AUTO_UPGRADE, $npool"
    else
      echo "[FAILED] 6.5.3 Ensure Node Auto-Upgrade is enabled for GKE nodes, $npool"
    fi
  done
}

# 6.6.2 Ensure use of VPC-native clusters (Scored)

function cis662() {
  VPC_NATIVE=$(gcloud container clusters describe $GKE_CLUSTER \
      --region $GKE_REGION --format json --project $proj|
      jq '.ipAllocationPolicy.useIpAliases'
  )


  if [[ $VPC_NATIVE == "true" ]]; then
    echo "[PASSED] 6.6.2 Ensure use of VPC-native clusters (Scored)"
    echo "useIpAliases : $VPC_NATIVE"
  else
    echo "[FAILED] 6.6.2 Ensure use of VPC-native clusters (Scored)"
  fi
}

# 6.6.3. Ensure Master Authorized Networks is Enabled

function cis663() {
  MASTER_AUTHORIZED=$(
    gcloud container clusters describe $GKE_CLUSTER \
      --region $GKE_REGION --format json --project $proj|
      jq '.masterAuthorizedNetworksConfig.enabled'
  )

  MASTER_NETWORKS=$(
    gcloud container clusters describe $GKE_CLUSTER \
      --region $GKE_REGION --format json --project $proj|
      jq '.masterAuthorizedNetworksConfig.cidrBlocks | .[] | .cidrBlock' |
      tr '\n' ','
  )

  if [[ $MASTER_AUTHORIZED == "true" ]]; then
    echo "[PASSED] 6.6.3. Ensure Master Authorized Networks is Enabled"
    echo "masterAuthorizedNetworksConfig : $MASTER_AUTHORIZED"
    echo "Networks : $MASTER_NETWORKS"
  else
    echo "[FAILED] 6.6.3. Ensure Master Authorized Networks is Enabled"
  fi
}

# 6.6.5. Ensure clusters are created with Private Nodes

function cis665() {
  PRIVATE_NODE=$(
    gcloud container clusters describe $GKE_CLUSTER \
      --region $GKE_REGION --format json --project $proj|
      jq '.privateClusterConfig.enablePrivateNodes'
  )

  if [[ $PRIVATE_NODE == "true" ]]; then
    echo "[PASSED] 6.6.5. Ensure clusters are created with Private Nodes"
    echo "enablePrivateNodes : $PRIVATE_NODE"
  else
    echo "[FAILED] 6.6.5. Ensure clusters are created with Private Nodes"
  fi
}

# 6.8.3. Consider managing Kubernetes RBAC users with Google Groups for GKE.

function cis683() {
  RBAC_GGROUPS=$(
    gcloud container clusters describe $GKE_CLUSTER \
      --region $GKE_REGION --format json --project $proj|
      jq '.authenticatorGroupsConfig.enabled'
  )

  RBAC_GGROUPSEC=$(
    gcloud container clusters describe $GKE_CLUSTER \
      --region $GKE_REGION --format json --project $proj|
      jq '.authenticatorGroupsConfig.securityGroup'
  )

  if [[ $RBAC_GGROUPS == "true" ]]; then
    echo "[PASSED] 6.8.3. Consider managing Kubernetes RBAC users with Google Groups for GKE."
    echo "authenticatorGroupsConfig.enabled : $RBAC_GGROUPSEC"
  else
    echo "[FAILED] 6.8.3. Consider managing Kubernetes RBAC users with Google Groups for GKE."
  fi
}

# 6.5.5 Ensure Shielded GKE Nodes are Enabled with Secure Boot

function cis655() {
  SHIELDED_NODE=$(
    gcloud container clusters describe $GKE_CLUSTER \
      --region $GKE_REGION --format json --project $proj |
      jq '.shieldedNodes.enabled'
  )

  SECURE_BOOT=$(
    gcloud container clusters describe $GKE_CLUSTER \
      --region $GKE_REGION --format json --project $proj|
      jq '.nodeConfig.shieldedInstanceConfig.enableSecureBoot'
  )

  if [[ $SHIELDED_NODE == "true" && $SECURE_BOOT == "true" ]]; then
    echo "[PASSED] 6.5.5 Ensure Shielded GKE Nodes are Enabled with Secure Boot"
    echo "shieldedNodes.enabled : $SHIELDED_NODE"
    echo "enableSecureBoot : $SECURE_BOOT"
  else
    echo "[FAILED] 6.5.5 Ensure Shielded GKE Nodes are Enabled"
  fi
}

# 6.5.1 Ensure Container-Optimized OS (COS) is used for GKE node  images (Scored)

function cis651() {
  COS=$(
    gcloud container clusters describe $GKE_CLUSTER \
      --region $GKE_REGION --format json --project $proj|
      jq '.nodeConfig.imageType'
  )

  if [[ $COS =~ "COS" ]]; then
    echo "[PASSED] 6.5.1 Ensure Container-Optimized OS (COS) is used for GKE node  images "
    echo "imageType : $COS"
  else
    echo "[FAILED] 6.5.1 Ensure Container-Optimized OS (COS) is used for GKE node  images "
  fi
}

# 6.2.2. Prefer using dedicated Google Cloud Service Accounts and Workload Identity

function cis622() {
  WORKLOAD_IDENTITY=$(
    gcloud container clusters describe $GKE_CLUSTER \
      --region $GKE_REGION --format json --project $proj|
      jq '.workloadIdentityConfig.workloadPool'
  )

  if [[ $WORKLOAD_IDENTITY =~ "svc.id.goog" ]]; then
    echo "[PASSED] 6.2.2. Prefer using dedicated Google Cloud Service Accounts and Workload Identity"
    echo "workloadPool : $WORKLOAD_IDENTITY"
  else
    echo "[FAILED] 6.2.2. Prefer using dedicated Google Cloud Service Accounts and Workload Identity"
  fi
}

# 6.2.1. Prefer not running GKE clusters using the Compute Engine default service account.

function cis621() {
  SVC_ACCOUNT_CHKR=$(gcloud container clusters describe $GKE_CLUSTER \
      --region $GKE_REGION --format json --project $proj |
      jq '.config.serviceAccount'
  )

  if [[ $SVC_ACCOUNT_CHKR == "null" ]]; then
    echo "[PASSED] 6.2.1. Prefer not running GKE clusters using the Compute Engine default service account."
  else
    echo "[FAILED] 6.2.1. Prefer not running GKE clusters using the Compute Engine default service account."
  fi
}

# 6.3.1 Ensure Kubernetes Secrets are encrypted using keys managed in Cloud KMS (Scored)

function cis631() {
    KMS_ENCR=$(gcloud container clusters describe $GKE_CLUSTER \
      --region $GKE_REGION --format json --project $proj|
      jq '.databaseEncryption.state'
    )

    if [[ $KMS_ENCR =~ "ENCRYPTED" ]]
    then
      echo "[PASSED] 6.3.1 Ensure Kubernetes Secrets are encrypted using keys managed in Cloud KMS"
      echo "databaseEncryption.state : $KMS_ENCR"
    else
      echo "[FAILED] 6.3.1 Ensure Kubernetes Secrets are encrypted using keys managed in Cloud KMS"
    fi
}

# run

cis_checker
