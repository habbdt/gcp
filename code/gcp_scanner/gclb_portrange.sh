#!/bin/bash

###############README############
# script to scan gclbs port range
#################################

SEARCH_TERM=$1

if [ "$#" -ne 1 ]
then
    echo "Usage: gclb_portrange.sh  <search_term>"
    exit 1
fi

# gclb port forwarding scanner

function gclb_portrange() {
    GCP_PROJECT="$(gcloud projects list --format="get(projectId)" \
                  --filter=$SEARCH_TERM)"

    for proj in $GCP_PROJECT; do
      API_STATUS="$(gcloud services list --enabled --filter=NAME~compute \
                    --project $proj)"
      if [ -z "$API_STATUS" ]
      then
        :
      else
        GCLB_NAME="$(gcloud compute forwarding-rules list --project $proj --format='get(NAME)')"
        if [ -z "$GCLB_NAME" ]
        then
          echo "[!] NO GCLB CONFIGURED FOR PROJECT $proj"
        else
          echo "proj, gclb_name, ip_address, kind, port_range"
          for gclb in $GCLB_NAME; do
            PORT_FORWARDING_RULE="$(gcloud compute forwarding-rules describe $gclb --global --project $proj\
                                    --format=json | \
                                    jq -r '[.name,.IPAddress,.kind,.portRange] | @csv')"
            echo "$proj, $PORT_FORWARDING_RULE"
          done
        fi
      fi
    done
}

# run
gclb_portrange