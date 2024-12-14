#!/bin/bash
# -*- mode:shell-script; coding:utf-8; -*-

# Copyright © 2024 Google LLC.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

source ./env.sh

OUTFILE=$(mktemp /tmp/rules-engine-deploy.out.XXXXXX)

SA_REQUIRED_ROLES=("roles/storage.objectViewer" "roles/storage.objectCreator" "roles/storage.objectUser")

check_and_maybe_create_gcs_bucket() {
  printf "Checking GCS bucket (%s)...\n" "gs://${BUCKET_NAME}"
  if gcloud storage buckets describe "gs://${BUCKET_NAME}" --format="json(name)" --project="$PROJECT" --quiet >"$OUTFILE" 2>&1; then
    printf "That bucket already exists.\n"
  else
    printf "Creating the bucket...\n"
    gcloud storage buckets create "gs://${BUCKET_NAME}" --default-storage-class="standard" --location="${REGION}" --project="$PROJECT" --quiet >"$OUTFILE" 2>&1
  fi
}

clean_files() {
  rm -f *.*~
  rm -fr bin
  rm -fr obj
}

check_and_maybe_create_sa() {
  local ROLE
  local ARR
  if gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT" --quiet >"$OUTFILE" 2>&1; then
    printf "That service account exists...\n"
  else
    printf "Creating that service account ...\n"
    gcloud iam service-accounts create "${SERVICE_ACCOUNT}" --project="${PROJECT}" --quiet >"$OUTFILE" 2>&1

    if [[ ${#SA_REQUIRED_ROLES[@]} -ne 0 ]]; then
      printf "There can be errors if all these changes happen too quickly, so we need to sleep a bit...\n"
      sleep 12
    fi

  fi
}

# need this if mounting a GCS bucket into the container for configuration files or other data.
grant_roles_to_sa_on_gcs_bucket() {
  local ROLE
  local ARR
  if [[ ${#SA_REQUIRED_ROLES[@]} -ne 0 ]]; then
    printf "Checking for required roles....\n"

    # I could not get the --filter argument to work here. :<
    # shellcheck disable=SC2076
    ARR=($(gcloud storage buckets get-iam-policy "gs://${BUCKET_NAME}" --project="${PROJECT}" \
      --flatten="bindings[].members" |
      grep -v deleted |
      grep -A 1 members |
      grep -A 1 "$SA_EMAIL" |
      grep role | sed -e 's/role: //'))

    for j in "${!SA_REQUIRED_ROLES[@]}"; do
      ROLE=${SA_REQUIRED_ROLES[j]}
      printf "  check... %s...\n" "$ROLE"
      if ! [[ ${ARR[*]} =~ "${ROLE}" ]]; then
        printf "    Adding role %s...\n" "${ROLE}"
        gcloud storage buckets add-iam-policy-binding "gs://${BUCKET_NAME}" \
          --member="serviceAccount:${SA_EMAIL}" --project="${PROJECT}" --role="${ROLE}" --quiet >/dev/null 2>&1
      else
        printf "    That role is already set on the bucket...\n"
      fi
    done

  else
    printf "There are no roles to grant to the SA on the bucket ...\n"
  fi
}

# ====================================================================

clean_files

check_and_maybe_create_sa

check_and_maybe_create_gcs_bucket

grant_roles_to_sa_on_gcs_bucket

gcloud storage cp ./sheets/1.xsl "gs://${BUCKET_NAME}/stylesheet1.xsl" --project="$PROJECT"

# Note: if mounting filesystems, such as GCS buckets, This implies the gen2
# runtime.  And in that case, must specify 512Mi memory minimum,
gcloud run deploy "${SERVICE}" \
  --source . \
  --project "${PROJECT}" \
  --concurrency 5 \
  --cpu 1 \
  --memory '512Mi' \
  --min-instances 0 \
  --max-instances 1 \
  --allow-unauthenticated \
  --region "${REGION}" \
  --service-account "${SA_EMAIL}" \
  --timeout 300 \
  --set-env-vars "APP_CONFIG=/mnt/mounted-config" \
  --add-volume "name=volume_config,type=cloud-storage,bucket=${BUCKET_NAME}" \
  --add-volume-mount "volume=volume_config,mount-path=/mnt/mounted-config"
