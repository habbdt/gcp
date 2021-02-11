#!/bin/bash

# enable firewall rules logging for gcp projects

set -o pipefail  # trace ERR through pipes
set -o errtrace  # trace ERR through 'time command' and other functions

SEARCH_PHRASE=$1

if [ $# -eq 0 ]
then
    echo "Usage: gcp_firewall_rules_enable_logging.sh <search_phrase>"
    echo "search phrase - common word in the gcp project naming pattern"
    echo "e.g. sh gke_scanner.sh facebook"
    exit
fi


function enable_logging() {
  GCP_PROJECT=$(gcloud projects list --format="get(projectId)" \
                  --filter=$SEARCH_PHRASE)

  for proj in $GCP_PROJECT; do
    FIREWALL_RULES="$(gcloud beta compute firewall-rules list \
                      --format="get(NAME)" --project $proj)"

    for fwrule in $FIREWALL_RULES; do
      FW_STATE_CHKR="$(gcloud beta compute firewall-rules describe $fwrule \
                        --project $proj  --format=json  | jq '.logConfig.enable')"

      if [[ "$FW_STATE_CHKR" == "true" ]]
      then
        echo "enabled, skipping, $fwrule in $proj"
      else
        ENABLE_LOGGING="$(gcloud beta compute firewall-rules update --enable-logging $fwrule \
                          --project $proj)"
        RETVAL=$?

        if [ $RETVAL -eq 0 ]
        then
          :
        else
          echo "error encountered while enabling logging for $fwrule in $proj" || :
        fi
      fi
    done
  done
}

# run

enable_logging