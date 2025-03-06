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

# Array of environment variable names to check
env_vars_to_check=(
  "PROJECT"
  "REGION"
  "SERVICE_ROOT"
  "BUCKET_NAME"
)

remove_service_accounts() {
  local sa found_saccts SA_NAME_PATTERN
  SA_NAME_PATTERN="${SERVICE_ROOT}-"
  echo "Checking service accounts"
  echo "--------------------" >>"$OUTFILE"
  echo "gcloud iam service-accounts list --project ${PROJECT} --format=value(email)" >>"$OUTFILE"
  found_saccts=($(gcloud iam service-accounts list --project "$PROJECT" --format="value(email)"))
  for sa in "${found_saccts[@]}"; do
    if beginswith "${SA_NAME_PATTERN}" "${sa}"; then
      printf "Deleting service account %s\n" "${sa}"
      echo "--------------------" >>"$OUTFILE"
      echo "gcloud --quiet iam service-accounts delete ${sa} --project ${PROJECT}" >>"$OUTFILE"
      gcloud --quiet iam service-accounts delete "${sa}" --project "${PROJECT}" >>"$OUTFILE" 2>&1
    fi
  done
}

delete_crun_service() {
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

# ====================================================================
OUTFILE=$(mktemp /tmp/apigee-tally-job.cleanup.out.XXXXXX)
printf "\nLogging to %s\n" "$OUTFILE"
printf "timestamp: %s\n" "$TIMESTAMP" >>"$OUTFILE"
check_shell_variables "${env_vars_to_check[@]}"
check_required_commands gcloud grep sed tr

delete_crun_service

remove_service_accounts

printf "\nAll the artifacts for this sample have now been removed.\n\n"
