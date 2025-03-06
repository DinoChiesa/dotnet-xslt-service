#!/bin/bash

# Copyright 2023-2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

source ./lib/utils.sh

TIMESTAMP=$(date '+%Y%m%d-%H%M%S')

# shellcheck disable=SC2002
rand_string=$(cat /dev/urandom | LC_CTYPE=C tr -cd '[:alnum:]' | head -c 4 | tr '[:upper:]' '[:lower:]')
INTEGRATION_NAME="${SERVICE_ROOT}-${rand_string}"

check_and_maybe_create_gcs_connector() {
  # Inquire the GCS connectors in the Region + Project
  local CTOR_VERSION gcs_connectors newname urlbase proj_number
  echo "--------------------" >>"$OUTFILE"
  printf "Checking for GCS connectors...\n"
  printf "Checking for GCS connectors...\n" >>"$OUTFILE"
  CTOR_VERSION="projects/${PROJECT}/locations/global/providers/gcp/connectors/gcs/versions/1"
  urlbase="https://connectors.googleapis.com/v1/projects/${PROJECT}/locations/${REGION}/connections"
  CURL -X GET "${urlbase}"
  gcs_connectors=($(jq '(.connections[] | select(.connectorVersion == "'${CTOR_VERSION}'") | .name)' ${CURL_OUT} |
    tr -d ' "'))
  printf "\nGCS connectors:\n"
  for conn in "${gcs_connectors[@]}"; do
    printf "%s\n" "$conn"
  done
  if [[ ${#gcs_connectors[@]} -eq 0 ]]; then
    printf "no GCS connector found, creating one...\n"
    newname="gcs-1"
    proj_number=$(gcloud projects describe $PROJECT --format="value(projectNumber)")
    CURL -X POST "${urlbase}" -H 'Content-Type: application/json; charset=utf-8' \
      -d '{
      "connectorVersion": "'$CTOR_VERSION'",
      "logConfig": {
        "level": "ERROR"
      },
      "serviceAccount": "'$proj_number'-compute@developer.gserviceaccount.com",
      "labels": {
         "creator": "app-int-script",
      },
      "nodeConfig": {
         "minNodeCount": 1,
         "maxNodeCount": 2
      },
      "configVariables": [
        {
          "key": "project_id",
          "stringValue": "'$PROJECT'"
        }
      ]
    }'
    # Response to the above is something like:
    #
    # {
    #   "name": "projects/dchiesa-argolis-2/locations/us-west1/operations/operation-1741285023137-1d6cabed",
    #   "metadata": {
    #     "@type": "type.googleapis.com/google.cloud.connectors.v1.OperationMetadata",
    #     "createTime": "2025-03-06T18:17:04.848227146Z",
    #     "target": "projects/dchiesa-argolis-2/locations/us-west1/connections/gcs-2",
    #     "verb": "create",
    #     "requestedCancellation": false,
    #     "apiVersion": "v1"
    #   },
    #   "done": false
    # }

    if [[ ${CURL_RC} -ne 200 ]]; then
      printf "That failed. Couldn't create a GCS Connector.\n"
      cat ${CURL_OUT}
      exit 1
    fi

    lro_name=$(jq '.name' ${CURL_OUT} | tr -d ' "')
    if [[ -z "$lro_name" ]]; then
      printf "Hmmmm.... Cannot find the Long-running-operation ID....Not sure if that worked.\n"
    else
      printf "The LRO is \n  %s\n" "$lro_name"
      printf "Waiting for that to complete...\n"
      echo "gcloud services operations wait \"$lro_name\" --project=\"$PROJECT\"" >>"$OUTFILE"
      gcloud services operations wait "$lro_name" --project="$PROJECT" >>"$OUTFILE" 2>&1
    fi
  else
    printf "There is a suitable GCS connector available.\n"
  fi
}

# ====================================================================
OUTFILE=$(mktemp /tmp/appint-setup.out.XXXXXX)
printf "\nThis script will check for an available connector for Google Cloud Storage, and if\n"
printf "one is not available, it will create one. Creating a connector is known as a \"long running\n"
printf "operation\". It can take some time.\n"
printf "timestamp: %s\n" "$TIMESTAMP" >>"$OUTFILE"
printf "Logging to %s\n" "$OUTFILE"
check_shell_variables "PROJECT" "REGION"
check_required_commands jq curl gcloud grep sed tr

TOKEN=$(gcloud auth print-access-token)
if [[ -z "$TOKEN" ]]; then
  printf "Could not get a token with the gcloud cli. See logs in %s\n" "$OUTFILE"
  printf "Could not get a token with the gcloud cli. See logs in %s\n" "$OUTFILE" >>"$OUTFILE"
  exit 1
fi

googleapis_whoami

check_and_maybe_create_gcs_connector
