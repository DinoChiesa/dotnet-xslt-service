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
NAME_PREFIX="${SERVICE_ROOT}-"

check_integrations_and_delete() {
  local intarr verarr
  printf "Looking at all integrations...\n"
  echo "--------------------" >>"$OUTFILE"
  printf "Looking at all integrations...\n" >>"$OUTFILE"
  intarr=($(integrationcli integrations list -r "$REGION" -p "$PROJECT" -t "$TOKEN" |
    grep "\"name\"" |
    sed -E 's/"name"://g' |
    tr -d ' "\t,' |
    sed -E 's@projects/[^/]+/locations/[^/]+/integrations/@@'))
  for a in "${intarr[@]}"; do
    printf "  Checking $a...\n" "$a" >>"$OUTFILE"
    if beginswith "$NAME_PREFIX" "$a"; then
      printf "  Checking %s...\n" "$a"
      echo "--------------------" >>"$OUTFILE"
      echo "Find versions of $a that are published." >>"$OUTFILE"

      verarr=($(integrationcli integrations versions list -n "$a" --filter "state=ACTIVE" -r "$REGION" -p "$PROJECT" -t "$TOKEN" |
        grep "\"name\"" |
        sed -E 's/"name"://g' |
        tr -d ' "\t,' |
        sed -E 's@projects/[^/]+/locations/[^/]+/integrations/[^/]+/versions/@@'))
      for v in "${verarr[@]}"; do
        printf "    unpublishing version %s...\n" "$v"
        echo "--------------------" >>"$OUTFILE"
        echo "integrationcli integrations versions unpublish -n $a -v $v -r $REGION -p $PROJECT" >>"$OUTFILE"
        integrationcli integrations versions unpublish -n "$a" -v "$v" -r "$REGION" -p "$PROJECT" -t "$TOKEN" >>"$OUTFILE" 2>&1
      done
      # finally, delete it
      printf "    deleting %s...\n" "$a"
      echo "--------------------" >>"$OUTFILE"
      echo "integrationcli integrations delete -n $a -r $REGION -p $PROJECT" >>"$OUTFILE"
      integrationcli integrations delete -n "$a" -r "$REGION" -p "$PROJECT" -t "$TOKEN" >>"$OUTFILE" 2>&1
    fi
  done
}

remove_iam_policy_bindings() {
  printf "Checking IAM Policy Bindings\n"

  IFS=',' read -r -a projects <<<"$APIGEE_PROJECTS"
  for APIGEE_PROJECT in "${projects[@]}"; do
    printf "  Checking policy bindings for project %s...\n" "$APIGEE_PROJECT"

    # shellcheck disable=SC2207
    echo "--------------------" >>"$OUTFILE"
    echo "gcloud projects get-iam-policy $PROJECT --flatten=bindings[].members |
        grep ${NAME_PREFIX} | grep -v deleted: | sed -E 's/ +members: *//g'" >>"$OUTFILE"
    members=($(
      gcloud projects get-iam-policy "$PROJECT" --flatten="bindings[].members" |
        grep "${NAME_PREFIX}" | grep -v "deleted:" | sed -E 's/ +members: *//g'
    ))
    echo "${members[@]}" >>"$OUTFILE"
    if [[ ${#members[@]} -gt 0 ]]; then
      ROLES_OF_INTEREST=("roles/integrations.integrationInvoker")
      for role in "${ROLES_OF_INTEREST[@]}"; do
        printf "    Checking role %s\n" "$role"
        for member in "${members[@]}"; do
          printf "    Removing IAM binding for %s\n" "$member"
          echo "--------------------" >>"$OUTFILE"
          echo "gcloud projects remove-iam-policy-binding ${PROJECT} \
            --member=$member --role=$role --all" >>"$OUTFILE"
          gcloud projects remove-iam-policy-binding "${PROJECT}" \
            --member="$member" --role="$role" --all >>"$OUTFILE" 2>&1
        done
      done
    else
      printf "    No bindings for members of interest...\n"
    fi
  done
}

# remove_service_accounts() {
#   echo "Checking service accounts"
#   echo "--------------------" >>"$OUTFILE"
#   echo "gcloud iam service-accounts list --project ${PROJECT} --format=value(email) | grep $NAME_PREFIX" >>"$OUTFILE"
#   mapfile -t ARR < <(gcloud iam service-accounts list --project "${PROJECT}" --format="value(email)" | grep "$NAME_PREFIX")
#   if [[ ${#ARR[@]} -gt 0 ]]; then
#     for sa in "${ARR[@]}"; do
#       echo "Deleting service account ${sa}"
#       echo "--------------------" >>"$OUTFILE"
#       echo "gcloud --quiet iam service-accounts delete ${sa} --project ${PROJECT}" >>"$OUTFILE"
#       gcloud --quiet iam service-accounts delete "${sa}" --project "${PROJECT}" >>"$OUTFILE" 2>&1
#     done
#   else
#     printf "  No service accounts of interest...\n"
#   fi
# }

remove_gcs_upload_bucket() {
  printf "Checking GCS bucket (%s)...\n" "gs://${UPLOAD_BUCKET}"
  echo "--------------------" >>"$OUTFILE"
  echo "gcloud storage buckets describe \"gs://${UPLOAD_BUCKET}\" --format=\"json(name)\" --project=\"$PROJECT\" --quiet" >>"$OUTFILE"
  if gcloud storage buckets describe "gs://${UPLOAD_BUCKET}" --format="json(name)" --project="$PROJECT" --quiet >>"$OUTFILE" 2>&1; then
    printf "Deleting that bucket...\n"
    echo "--------------------" >>"$OUTFILE"
    echo "gcloud storage rm --recursive \"gs://${UPLOAD_BUCKET}\" --project=\"$PROJECT\" --quiet" >>"$OUTFILE"
    if gcloud storage rm --recursive "gs://${UPLOAD_BUCKET}" --project="$PROJECT" --quiet >>"$OUTFILE" 2>&1; then
      printf "Done.\n"
    else
      printf "The delete did not succeed.\n"
    fi
  else
    printf "The bucket does not exist...\n"
  fi
}

remove_pubsub_topic() {
  local topic
  printf "Checking pubsub topic (%s)...\n" "${PUBSUB_TOPIC}"
  if gcloud pubsub topics describe "$PUBSUB_TOPIC" --project="$PROJECT" --format 'value(name)' >>"$OUTFILE" 2>&1; then
    printf "Deleting that topic...\n"
    if gcloud pubsub topics delete "$PUBSUB_TOPIC" --project="$PROJECT" >>"$OUTFILE" 2>&1; then
      printf "Done.\n"
    else
      printf "The delete did not succeed.\n"
    fi
  else
    printf "The topic does not exist...\n"
  fi
}

# ====================================================================
OUTFILE=$(mktemp /tmp/appint-sample.cleanup.out.XXXXXX)
printf "\nLogging to %s\n" "$OUTFILE"
printf "timestamp: %s\n" "$TIMESTAMP" >>"$OUTFILE"
check_shell_variables "PROJECT" "REGION" "SERVICE_ROOT" "UPLOAD_BUCKET"
check_required_commands jq curl gcloud grep sed tr

# it is necessary to get a token... if using curl or integrationcli for anything
TOKEN=$(gcloud auth print-access-token)
if [[ -z "$TOKEN" ]]; then
  printf "Could not get a token with the gcloud cli. See logs in %s\n" "$OUTFILE"
  printf "Could not get a token with the gcloud cli. See logs in %s\n" "$OUTFILE" >>"$OUTFILE"
  exit 1
fi

googleapis_whoami
maybe_install_integrationcli
check_integrations_and_delete
remove_iam_policy_bindings
#remove_service_accounts
# Removing service account will be done with the other cleanup script
remove_gcs_upload_bucket
remove_pubsub_topic

printf "\nAll the artifacts for the integration have now been removed.\n\n"
