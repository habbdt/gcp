#!/bin/bash

# use this script to find what are the level of access a
# compromised service account has on a given GCP project.
# search for leaked service account private key in the Github using following search string.
# "auth_provider_x509_cert_url" AND "project_id:<search_string_project_name>"
# prerequisites: the following steps must be completed before running the script.
#[1] copy the service account's private key in a text file (e.g. sa.json)
#[2] configure gcloud authentication using the SA key.
#    gcloud auth activate-service-account --key-file=sa.json
#    gcloud config set project <gcp_project_name>

set -o pipefail  # trace ERR through pipes
set -o errtrace  # trace ERR through 'time command' and other functions

PROJ=$1

if [ "$#" -ne 1 ]
then
    echo "Usage: yes | ./gcp_enum_compromised_cred.sh <gcp_project_name>"
    echo "NOTE: yes is MUST, otherwise the script will prompt for input"
    exit
fi

function reconnaissance() {
  echo "[x] scanning for organization"
  CMD="$(gcloud organizations list 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for gcp projects"
  CMD="$(gcloud projects list 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for gcp project ancestors"
  CMD="$(gcloud projects get-ancestors $PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for gcp project ancestors IAM policy"
  CMD="$(gcloud projects get-ancestors-iam-policy $PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning enabled services in the project"
  CMD="$(gcloud services list --enabled --project=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for all IAM policies using cloud asset api"
  CMD="$(gcloud beta asset search-all-iam-policies  2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for all cloud resources"
  CMD="$(gcloud beta asset search-all-resources  2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for IAM policy associated with the project"
  CMD="$(gcloud projects get-iam-policy $PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for available service accounts"
  CMD="$(gcloud iam service-accounts list --project=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for gce compute instanes"
  CMD="$(gcloud compute instances list --project=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for compute images"
  CMD="$(gcloud compute images list  --project=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for gke clusters list"
  CMD="$(gcloud container clusters list --project=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for gcr container registries"
  CMD="$(gcloud container images list --project=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for artifact registries"
  CMD="$(gcloud artifacts repositories  list --project=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for appengine instanes"
  CMD="$(gcloud app instances list --project=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo  "[x] scanning for appengine services"
  CMD="$(gcloud app services list --project=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for vpc networks"
  CMD="$(gcloud compute networks list  --project=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for vpc subnets"
  CMD="$(gcloud compute networks subnets list --project=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for the firewall rules"
  CMD="$(gcloud compute firewall-rules list  --project=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for shared vpc"
  CMD="$(gcloud compute shared-vpc list-associated-resources  --project=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for vpc peering"
  CMD="$(gcloud compute networks peerings list --project=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for cloud endpoint services"
  CMD="$(gcloud endpoints services list --project=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for cloud dns zones"
  CMD="$(gcloud dns managed-zones list  --project=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for dns project info"
  CMD="$(gcloud dns project-info describe $PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for cloud functions"
  CMD="$(gcloud functions list --regions=us-east4 --project=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for cloud sql instances"
  CMD="$(gcloud sql instances list --project=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for bigquery datasets"
  CMD="$(bq ls  --project_id=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning bigtable instances"
  CMD="$(gcloud bigtable instances  list --project=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for bigtable clusters"
  CMD="$(gcloud bigtable clusters list --project=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for cloud composer environment list"
  CMD="$(gcloud composer environments list --locations=us-east4 --project=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for cloud composer operations list"
  CMD="$(gcloud composer operations list --locations=us-east4 --project=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for dataproc clusters"
  CMD="$(gcloud dataproc clusters list --region=us-east4 --project=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for dataproc jobs"
  CMD="$(gcloud dataproc jobs list --region=us-east4 --project=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for dataproc operations"
  CMD="$(gcloud dataproc operations list --region=us-east4 --project=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for the kms keyring"
  CMD="$(gcloud kms keyrings list --location=global --project=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for cloud logging"
  CMD="$(gcloud logging logs list --project=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for cloud logging sinks"
  CMD="$(gcloud logging sinks list --project=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for pubsub topics"
  CMD="$(gcloud pubsub topics list --project=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for pubsub subscriptions"
  CMD="$(gcloud pubsub subscriptions list --project=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for ai-platform access"
  CMD="$(gcloud ai-platform jobs list  --project=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for gcs buckets"
  CMD="$(gsutil ls -p $PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for cloud spanner instances"
  CMD="$(gcloud spanner instances list --project=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for cloud source repositories"
  CMD="$(gcloud source repos list --project=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for cloud builds"
  CMD="$(gcloud builds list  --project=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for dataflow jobs"
  CMD="$(gcloud dataflow jobs list --region=us-east4 --project=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for datastore indexes"
  CMD="$(gcloud datastore indexes list --project=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for gcloud deployment manager deployments list"
  CMD="$(gcloud deployment-manager deployments list --project=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for domains verified users"
  CMD="$(gcloud domains list-user-verified --project=$PROJ 2>&1 > /dev/null)"
  echo $?

  echo "[x] scanning for redis instances list"
  CMD="$(gcloud redis instances list --region=us-east4 --project=$PROJ 2>&1 > /dev/null)"
  echo $?
}

# call function

reconnaissance || true