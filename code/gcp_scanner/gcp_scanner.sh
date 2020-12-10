#!/bin/bash

# master scanner for gcp resources

GCP_SERVICE=$1
SEARCH_TERM=$2

if [ "$#" -ne 2 ]
then
    echo "Usage: master-scanner.sh <service_name> <search_term>"
    echo "Services: ORG, BQ, GKE, GCE, GCS, CF, SERVICES, PUBLIC_IPS, SHARED_VPC, PROJECTS_IAM, \
          EXTERNAL_IPS, SERVICE_ACCOUNTS_KEYS, LOGGING_SINKS, LOGGING_LIST, ORG_IAM_IDENTITY, PROJECT_IAM_IDENTITY"
    echo "search_term: search using common term in the gcp project naming pattern e.g. 3m-prod"
    exit 1
fi


# general projects checker function

function project() {
    GCP_PROJECT=$(gcloud projects list --format="get(projectId)" \
                  --filter=$SEARCH_TERM)
}


# gcp organization structure
function ORG() {
    ORG="$(gcloud organizations list --format="get(ID)" \
          | cut -d "/" -f2)"

    if [ -z "$ORG" ]
    then
      echo "No organization present, checking for projects!!!"
      echo "Best practice: Configure organization"
      project
      echo "$GCP_PROJECT"
    else
      echo "[x] Scanning organization $ORG for folders and projects"
      FOLDER="$(gcloud resource-manager folders list --organization=$ORG)"
      if [ -z "$FOLDER" ]
      then
        echo "[!] No folder present for the organization $ORG"
        echo "[x] Scanning organization $ORG for GCP projects"
        project
        echo "$GCP_PROJECT"
      else
        echo "[x] Organization $ORG has following folders"
        echo "$FOLDER"
        project
        echo "[x] Organization $ORG has following projects"
        echo "$GCP_PROJECT"
      fi
    fi
}

# organization level IAM roles and permissions

function ORG_IAM_IDENTITY() {
  ORG="$(gcloud organizations list --format="get(ID)" \
          | cut -d "/" -f2)"

  ORG_IAM="$(gcloud organizations get-iam-policy $ORG \
       --flatten="bindings[].members" --format="csv(bindings.role,bindings.members)")"
  for i in $ORG_IAM; do
    echo "$ORG","$i"
  done
}

# project level IAM roles and permissions

function PROJECT_IAM_IDENTITY() {
  echo "hello"
  project
  for proj in $GCP_PROJECT; do
    PROJ_IAM="$(gcloud projects get-iam-policy $proj \
    --flatten="bindings[].members" --format="csv(bindings.role,bindings.members,type)")"
    for p in $PROJ_IAM; do
      echo "$proj","$p"
    done
  done
}

# services function

function SERVICES() {
  project
  for proj in $GCP_PROJECT; do
    echo "[*] Scanning project $proj for enabled services"
    ENABLED_SERVICES="$(gcloud services list --enabled --project $proj --format='get(TITLE)')"
    echo "$ENABLED_SERVICES"
  done
}

# public ip function

function PUBLIC_IPS() {
    project
    for proj in $GCP_PROJECT; do
      echo "[*] scanning project $proj for public ip"
        for ext_ip in $(gcloud compute instances list --project=$proj --format="get(EXTERNAL_IP)") ; do
          if [ -n "$ext_ip" ]
          then
            echo "[!] public ip address is $ext_ip"
          fi
        done
done
}

# logging sink checker : list all the sinks except _Default and _Required

function LOGGING_SINKS() {
    project
    echo "Project,Name,Writer Identity,Destination"
    for proj in $GCP_PROJECT; do
      #echo "[x] scanning project $proj for logging sinks (_Default and _Required excluded)"
      #check if logging.googleapis.com api is enabled or not
      API_STATUS="$(gcloud services list --enabled \
                  --filter=NAME~logging.googleapis.com \
                  --format='get(NAME)' --project=$proj)"

      if [ -z "$API_STATUS" ]
      then
        :
      else
        SINKS="$(gcloud beta logging sinks list \
              --filter="NAME!=_Required AND NAME!=_Default"\
              --project $proj --format="get(NAME)"
            )"
        if [ -z "$SINKS" ]
        then
          echo "$proj,_Default&Required_loggingbucket,SystemDefault,SystemDefault"
        else
          for sink in $SINKS; do
            SINKS_TGT="$(gcloud beta logging sinks describe $sink \
                    --format="csv[no-heading](name,writerIdentity,destination)" \
                    --project $proj
            )"
            echo "$proj,$SINKS_TGT"
          done
        fi
      fi
    done
}


# list logs in projects. For reporting creating two
# separate function LOGGING_SINKS LOGGING_LIST

function LOGGING_LIST() {
    project
    for proj in $GCP_PROJECT; do
      API_STATUS="$(gcloud services list --enabled \
                  --filter=NAME~logging.googleapis.com \
                  --format='get(NAME)' --project=$proj)"
      if [ -z "$API_STATUS" ]
      then
        :
      else
        LOGSLIST="$(gcloud alpha logging logs list --project $proj)"
        echo "[x] scanning project $proj for the list of the logs"
        echo "$LOGSLIST"
      fi
    done
}

# cloud function scanner - check the existence of the CF and IAM roles associated with CF

function CF() {
    project
    for proj in $GCP_PROJECT; do
      API_STATUS="$(gcloud services list --enabled \
                  --filter=NAME~cloudfunctions.googleapis.com \
                  --format='get(NAME)' --project=$proj)"
      if [ -z "$API_STATUS" ]
      then
        :
      else
        #echo "[*] scanning project $proj for cloud functions"
        CLOUD_FUNCTION="$(gcloud  functions list --project=$proj \
        --format="csv(NAME,STATUS)"
        )"
        if [ -z "$CLOUD_FUNCTION" ]
        then
          #echo "cloud function api is enabled but no is function created"
          :
        else
          echo "[*] scanning project $proj for cloud functions"
          echo "$CLOUD_FUNCTION"
        fi
      fi
    done
}

# shared vpc check

function SHARED_VPC() {
    project
    PROD_NET_PROJ="$(gcloud compute shared-vpc associated-projects \
                  list projectGcp-net-prod --format="csv(id)")"
    NONPROD_NET_PROJ="$(gcloud compute shared-vpc associated-projects \
                  list projectGcp-net-nonprod --format="csv(id)")"
    for proj in $GCP_PROJECT; do
      echo "[*] scanning project $proj for shared vpc"
      if [[ "$PROD_NET_PROJ" =~ "$proj" ]]
      then
        echo "prod vpc"
      elif [[ "$NONPROD_NET_PROJ" =~ "$proj"  ]]
      then
        echo "nonprod vpc"
      else
        echo "NO VPC!"
      fi
    done
}

# check if bq dataset made public

function BQ() {
  project
  for proj in $GCP_PROJECT; do
    API_STATUS="$(gcloud services list --enabled --filter=NAME~bigquery --project $proj)"
    if [ -z "$API_STATUS" ]
    then
      :
    else
      echo "[*] scanning project $proj for bq datasets permissions"
      for dataset in $(bq ls --project_id  $proj); do
          BQ_ACL="$(bq show  $proj:$dataset)"
          all_users="$(echo $BQ_ACL | grep allUsers)"
          all_auth="$(echo $BQ_ACL | grep allAuthenticatedUsers)"
          echo "    $dataset"
          if [ -z "$all_users" ]
          then
                :
          else
                echo "[!] Open to all users: $dataset"
          fi

          if [ -z "$all_auth" ]
          then
                :
          else
                echo "[!] Open to all authenticated users: $dataset"
          fi
      done
    fi
done
}

# check if gcs buckets have public permissions

function GCS() {
    project
    for proj in $GCP_PROJECT; do
    echo "[*] scraping project $proj"
    for bucket in $(gsutil ls -p $proj); do
        echo "    $bucket"
        ACL="$(gsutil iam get $bucket)"

        all_users="$(echo $ACL | grep allUsers)"
        all_auth="$(echo $ACL | grep allAuthenticatedUsers)"

        if [ -z "$all_users" ]
        then
              :
        else
              echo "[!] Open to all users: $bucket"
        fi

        if [ -z "$all_auth" ]
        then
              :
        else
              echo "[!] Open to all authenticated users: $bucket"
        fi
    done
done
}

# list gke clusters

function GKE() {
    project
    for proj in $GCP_PROJECT; do
      API_STAT="$(gcloud services list --enabled --format="get(NAME)" \
                --filter=NAME~container.googleapis.com --project $proj)"
      if [ -z "$API_STAT" ]
      then
        :
      else
        echo "[*] scanning project $proj for k8s clusters"
        K8S="$(gcloud container clusters list  --project $proj)"
        echo "$K8S"
      fi
done
}

# gke container images

function krew_checker() {
    KREW="$(kubectl krew list images 2>&1 > /dev/null)"
    RETVAL=$?

    if [ $RETVAL -eq 0 ]
    then
      rbac_scanner
    else
      echo "install krew : "
      echo "brew install krew"
      echo "kubectl krew install rbac-lookup"
      exit
    fi
}


# scan all projects for the IAM
function PROJECTS_IAM() {
  project
  for proj in $GCP_PROJECT; do
      echo "[*] scanning project $proj for iam policy"
      IAM="$(gcloud projects get-iam-policy $proj)"
      echo "$IAM"
done
}

# find all the external ips
function EXTERNAL_IPS() {
    project
    for proj in $GCP_PROJECT; do
      API_STAT="$(gcloud services list --enabled --format="get(NAME)" \
                --filter=NAME~container.googleapis.com --project $proj)"
      if [ -z "$API_STAT" ]
      then
        :
      else
        EXTERNAL_IPS="$(gcloud  compute addresses list --project \
                      $proj --format="get(NAME,ADDRESS,STATUS)")"
        if [ -z "$EXTERNAL_IPS" ]
        then
          :
        else
          echo "[*] scanning project $proj for external ips"
          echo "$EXTERNAL_IPS"
        fi
      fi
    done
}

# scan service accounts for user managed keys

function SERVICE_ACCOUNTS_KEYS() {
    project
    for proj in $GCP_PROJECT; do
    echo "[*] scanning project $proj for service accounts keys - user managed"
    LIST_SAS="$(gcloud  iam service-accounts list  --project $proj \
                --format="get(EMAIL)")"
    for user_mng in $LIST_SAS ; do
      USER_MNG="$(gcloud  iam service-accounts keys list --iam-account=$user_mng \
                --managed-by user)"
      if [ -z "$USER_MNG" ]
      then
        :
      else
        echo "$user_mng \n $USER_MNG"
      fi
    done
done
}

# execute function based on script argument

case $GCP_SERVICE in

  ORG)
    ORG
    ;;

  SERVICES)
    SERVICES
    ;;

  PUBLIC_IPS)
    PUBLIC_IPS
    ;;

  CF)
    CF
    ;;

  SHARED_VPC)
    SHARED_VPC
    ;;

  BQ)
    BQ
    ;;

  GCS)
    GCS
    ;;

  GKE)
    GKE
    ;;

  PROJECTS_IAM)
    PROJECTS_IAM
    ;;

  EXTERNAL_IPS)
    EXTERNAL_IPS
    ;;

  SERVICE_ACCOUNTS_KEYS)
    SERVICE_ACCOUNTS_KEYS
    ;;

  LOGGING_SINKS)
    LOGGING_SINKS
    ;;

  LOGGING_LIST)
    LOGGING_LIST
    ;;

  ORG_IAM_IDENTITY)
    ORG_IAM_IDENTITY
    ;;

  PROJECT_IAM_IDENTITY)
    PROJECT_IAM_IDENTITY
    ;;

  ALL)
    ORG
    SERVICES
    PUBLIC_IPS
    CF
    SHARED_VPC
    BQ
    GCS
    GKE
    PROJECTS_IAM
    EXTERNAL_IPS
    SERVICE_ACCOUNTS_KEYS
    LOGGING_SINKS
    LOGGING_LIST
    ORG_IAM_IDENTITY
    PROJECT_IAM_IDENTITY
    ;;
esac
