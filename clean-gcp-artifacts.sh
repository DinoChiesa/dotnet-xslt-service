#!/bin/bash

# Copyright © 2023-2025 Google LLC
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

delete_crun_services() {
  local svc found_svcs SERVICE_NAME_PATTERN
  SERVICE_NAME_PATTERN="${SERVICE_ROOT}-"
  printf "Checking Cloud Run jobs...\n"
  found_svcs=($(gcloud run services list --region "$REGION" --project "$PROJECT" --format="value(name)"))
  for svc in "${found_svcs[@]}"; do
    if beginswith "${SERVICE_NAME_PATTERN}" "$svc"; then
      printf "Deleting Cloud Run service %s...\n" "$svc"
      echo "--------------------" >>"$OUTFILE"
      echo "gcloud run services delete ${svc} --quiet --region $REGION --project $PROJECT" >>"$OUTFILE"
      if gcloud run services delete "${svc}" --quiet --region "$REGION" --project "$PROJECT" >>"$OUTFILE" 2>&1; then
        printf "Success\n"
      else
        printf "Failed...\n"
      fi
    fi
  done
}


remove_service_account() {
  local SERVICE_ACCOUNT SA_EMAIL
  SERVICE_ACCOUNT="${SERVICE_ROOT}"
  SA_EMAIL="${SERVICE_ROOT}@${PROJECT}.iam.gserviceaccount.com"

  printf "Checking service account...\n"
  echo "--------------------" >>"$OUTFILE"
  echo "gcloud iam service-accounts describe \"$SA_EMAIL\" --project ${PROJECT} --format=value(email)" >>"$OUTFILE"
  if gcloud iam service-accounts describe "$SA_EMAIL" --project "$PROJECT" >>"$OUTFILE" 2>&1; then
    printf "Found. deleting it...\n"
    echo "gcloud --quiet iam service-accounts delete ${SA_EMAIL} --project ${PROJECT}" >>"$OUTFILE"
    if gcloud --quiet iam service-accounts delete "${SA_EMAIL}" --project "${PROJECT}" >>"$OUTFILE" 2>&1; then
      printf "Success\n"
    else
      printf "Failed...\n"
    fi
  else
    printf "did not find a service account...\n"
  fi
}

remove_gcs_appconfig_bucket() {
  printf "Checking GCS bucket (%s)...\n" "gs://${APPCONFIG_BUCKET}"
  echo "--------------------" >>"$OUTFILE"
  echo "gcloud storage buckets describe \"gs://${APPCONFIG_BUCKET}\" --format=\"json(name)\" --project=\"$PROJECT\" --quiet" >>"$OUTFILE"
  if gcloud storage buckets describe "gs://${APPCONFIG_BUCKET}" --format="json(name)" --project="$PROJECT" --quiet >>"$OUTFILE" 2>&1; then
    printf "Deleting that bucket...\n"
    echo "--------------------" >>"$OUTFILE"
    echo "gcloud storage buckets delete \"gs://${APPCONFIG_BUCKET}\" --location=\"${REGION}\" --project=\"$PROJECT\" --quiet" >>"$OUTFILE"
    if gcloud storage buckets delete "gs://${APPCONFIG_BUCKET}" --location="${REGION}" --project="$PROJECT" --quiet >>"$OUTFILE" 2>&1; then
      printf "Done.\n"
    else
      printf "The delete did not succeed.\n"
    fi
  else
    printf "The bucket does not exist...\n"
  fi
}


# ====================================================================
OUTFILE=$(mktemp /tmp/apigee-tally-job.cleanup.out.XXXXXX)
printf "\nLogging to %s\n" "$OUTFILE"
printf "timestamp: %s\n" "$TIMESTAMP" >>"$OUTFILE"
check_shell_variables "PROJECT" "REGION" "SERVICE_ROOT" "APPCONFIG_BUCKET"
check_required_commands gcloud grep sed tr

delete_crun_services

remove_service_account

printf "\nAll the artifacts for this sample have now been removed.\n\n"
