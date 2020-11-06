#!/bin/bash

# scan gcp projects for the gcs buckets with public iam permissions assigned
# if the output is null that means no gcs buckets with public IAM permissions

for proj in $(gcloud projects list --format="get(projectId)"); do
    echo "[*] scanning gcp project $proj"
    for bucket in $(gsutil ls -p $proj); do
        ACL="$(gsutil iam get $bucket)"
        echo "    $bucket"

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
