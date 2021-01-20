#!/bin/bash

# find users with programmtic access and access key last used

set -o pipefail  # trace ERR through pipes
set -o errtrace  # trace ERR through 'time command' and other functions

FIND_INFO=$1

if [ "$#" -ne 1 ]
then
    echo "Usage: aws-users-information-scrape.sh <search_for>"
    echo "search_for: get-access-key-last-used-info"
    exit
fi


function get-access-key-last-used-info() {
    USERS="$(aws iam list-users --output text | awk '{print $NF}')"

    for usr in $USERS ; do
      ACCESSKEYID="$(aws iam list-access-keys --user $usr | \
                     jq '.AccessKeyMetadata | .[] | .AccessKeyId')"

      ACCESSKEYLASTUSED="$(aws iam get-access-key-last-used --access-key-id $ACCESSKEYID \
                          jq '.AccessKeyLastUsed.LastUsedDate')"

      ACCESSKEYMETADAT="$(aws iam list-access-keys --user $usr | \
                          jq '.AccessKeyMetadata | .[] | .UserName + "," + .AccessKeyId + "," + .Status + "," + .CreateDate')"

      echo "Username,AccessKeyId,Status,CreateDate,AccessKeyLastUsed"
      echo "$ACCESSKEYMETADAT,$ACCESSKEYLASTUSED"
    done
}


# execute function based on script argument

case $FIND_INFO in

  get-access-key-last-used-info)
    get-access-key-last-used-info
    ;;

esac