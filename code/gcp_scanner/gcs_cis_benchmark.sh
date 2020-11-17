#!/bin/bash

# gcs cis benchmark

set -o pipefail # trace ERR through pipes
set -o errtrace # trace ERR through 'time command' and other functions

SEARCH_PHRASE=$1
GCS_SCAN=$2

if [ "$#" -ne 2 ]; then
  echo "Usage: gcs_cis_benchmark.sh <search_phrase> <gcs_search>"
  echo "search phrase - common word in the gcp project naming pattern"
  echo "GCS_SEARCH: GCS_PUBLIC, CIS_CHK, UNIFORM_BUCKET_ACCESS"
  exit
fi

# master cis scanner - section 5

function MASTER_SCANNER() {
  GCP_PROJECT=$(gcloud projects list --format="get(projectId)" \
    --filter=$SEARCH_PHRASE)

  for proj in $GCP_PROJECT; do
    API_STATUS="$(gcloud services list --enabled --filter=NAME~storage-component.googleapis.com \
      --project $proj)"
    if [ -z "$API_STATUS" ]; then
      :
    else
      echo "[CIS51] scanning project $proj for gcs bucket $GCS_SCAN"
      if [[ "$GCS_SCAN" == "CIS_CHK" ]]; then
        CIS_CHK
      else
        $GCS_SCAN
      fi
    fi
  done
}

function CIS_CHK() {
  # GCP - CIS : 5.1
  echo "scanning - gcp - cis : 5.1 compliance"
  GCS_PUBLIC

  # GCP - CIS: 5.2
  echo "scanning - gcp - cis : 5.2 compliance"
  UNIFORM_BUCKET_ACCESS
}

#5.1 Ensure that Cloud Storage bucket is not anonymously or publicly accessible
# scan gcp projects for the gcs buckets with public iam permissions assigned
# if the output is null that means no gcs buckets with public IAM permissions

function GCS_PUBLIC() {
  for bucket in $(gsutil ls -p $proj); do
    ACL="$(gsutil iam get $bucket)"
    echo "    $bucket"

    all_users="$(echo $ACL | grep allUsers)"
    all_auth="$(echo $ACL | grep allAuthenticatedUsers)"

    if [ -z "$all_users" ]; then
      :
    else
      echo "[!] Open to all users: $bucket"
    fi

    if [ -z "$all_auth" ]; then
      :
    else
      echo "[!] Open to all authenticated users: $bucket"
    fi
  done
}

# gsutil  uniformbucketlevelaccess get gs://security-command-center-exports.us-central1.tapad.com | grep Enabled | awk '{print $NF}'

# 5.2 Ensure that Cloud Storage buckets have uniform bucket-level access
#enabled

function UNIFORM_BUCKET_ACCESS() {
    for bucket in $(gsutil ls -p $proj); do
      UNIFORM_ACL="$(gsutil uniformbucketlevelaccess get $bucket \
                   | grep Enabled | awk '{print $NF}')"
      if [[ "$UNIFORM_ACL" == "False" ]]
      then
        echo "[!] bucket $bucket in $project has FINE-GRAINED ACL"
      elif [[ "$UNIFORM_ACL" == "True" ]]
      then
        echo "[x] bucket $bucket in $project has UNIFORM ACL"
      else
        :
      fi
    done
}

# run function

MASTER_SCANNER
