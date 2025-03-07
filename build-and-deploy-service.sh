#!/bin/bash
# -*- mode:shell-script; coding:utf-8; -*-

# Copyright © 2024,2025 Google LLC.
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

source ./lib/utils.sh

OUTFILE=$(mktemp /tmp/xslt-service-deploy.out.XXXXXX)
SA_REQUIRED_ROLES=("roles/storage.objectViewer" "roles/storage.objectCreator" "roles/storage.objectUser")

check_and_maybe_create_sa() {
  local ROLE ARR
  printf "Checking for service account %s...\n" "$SA_EMAIL"
  printf "Checking for service account %s...\n" "$SA_EMAIL" >>"$OUTFILE"
  echo "gcloud iam service-accounts describe \"$SA_EMAIL\" --project=\"$PROJECT\" --quiet" >>"$OUTFILE"
  if gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT" --quiet >>"$OUTFILE" 2>&1; then
    printf "That service account exists...\n"
  else
    printf "Creating service account %s ...\n" "${SERVICE_ACCOUNT}"
    printf "Creating service account %s...\n" "${SERVICE_ACCOUNT}" >>"$OUTFILE"
    echo "gcloud iam service-accounts create \"${SERVICE_ACCOUNT}\" --project=\"${PROJECT}\" --quiet" >>"$OUTFILE"
    gcloud iam service-accounts create "${SERVICE_ACCOUNT}" --project="${PROJECT}" --quiet >>"$OUTFILE" 2>&1

    if [[ ${#SA_REQUIRED_ROLES[@]} -ne 0 ]]; then
      printf "There can be errors if all these changes happen too quickly, so we need to sleep a bit...\n"
      sleep 12
    fi
  fi
}

check_and_maybe_create_gcs_bucket() {
  local bucket_name
  bucket_name=$1
  printf "Checking GCS bucket (%s)...\n" "gs://${bucket_name}"
  if gcloud storage buckets describe "gs://${bucket_name}" --format="json(name)" --project="$PROJECT" --quiet >"$OUTFILE" 2>&1; then
    printf "That bucket already exists.\n"
  else
    printf "Creating the bucket...\n"
    gcloud storage buckets create "gs://${bucket_name}" --default-storage-class="standard" --location="${REGION}" --project="$PROJECT" --quiet >"$OUTFILE" 2>&1
  fi
}

clean_files() {
  rm -f "${example_name}/*.*~"
  rm -fr "${example_name}/bin"
  rm -fr "${example_name}/obj"
  manage_linked_files rm
}

# need this if mounting a GCS bucket into the container for configuration files or other data.
grant_roles_to_sa_on_gcs_bucket() {
  local ROLE ARR bucket_name
  bucket_name="$1"
  if [[ ${#SA_REQUIRED_ROLES[@]} -ne 0 ]]; then
    printf "Checking for required roles....\n"
    printf "Checking for required roles....\n" >>"$OUTFILE"

    # I could not get the --filter argument to work here. :<
    # shellcheck disable=SC2076
    ARR=($(gcloud storage buckets get-iam-policy "gs://${bucket_name}" --project="${PROJECT}" \
      --flatten="bindings[].members" |
      grep -v deleted |
      grep -A 1 members |
      grep -A 1 "$SA_EMAIL" |
      grep role | sed -e 's/role: //'))

    for j in "${!SA_REQUIRED_ROLES[@]}"; do
      ROLE=${SA_REQUIRED_ROLES[j]}
      printf "  check role... %s...\n" "$ROLE"
      printf "  check role... %s...\n" "$ROLE" >>"$OUTFILE"
      if ! [[ ${ARR[*]} =~ "${ROLE}" ]]; then
        printf "    Adding role %s...\n" "${ROLE}"
        printf "    Adding role %s...\n" "${ROLE}" >>"$OUTFILE"
        gcloud storage buckets add-iam-policy-binding "gs://${bucket_name}" \
          --member="serviceAccount:${SA_EMAIL}" --project="${PROJECT}" --role="${ROLE}" --quiet >/dev/null 2>&1
      else
        printf "    That role is already set on the bucket...\n"
      fi
    done

  else
    printf "There are no roles to grant to the SA on the bucket ...\n"
  fi
}

manage_linked_files() {
  # There are some linked files in the build. These are re-used across
  # multiple projects. The `gcloud run deploy` command does not handle those
  # automatically.  So when using that, we need to copy the linked files,
  # then `gcloud run deploy` , then remove the files.  If we do it that way,
  # then we do not want the build in google cloud to try to resolve these
  # linked files - the targets of the links won't exist, but the files
  # will be present anyway.  So this condition handles that.

  local linked linked_files action
  action="$1"
  linked_files=($(grep Link ${example_name}/*.csproj | sed -r 's@</?Link>@@g'))
  if [[ "$action" == "copy" ]]; then
    for linked in "${linked_files[@]}"; do
      cp "./common/${linked}" "${example_name}"
    done
  fi
  if [[ "$action" == "rm" ]]; then
    for linked in "${linked_files[@]}"; do
      rm -f "./${example_name}/${linked}"
    done
  fi
}

copy_files_to_bucket() {
  local bname extensions file ext
  extensions=("xsl" "json")
  printf "Copying files to the bucket %s\n" "$APPCONFIG_BUCKET"
  printf "Copying files to the bucket %s\n" "$APPCONFIG_BUCKET" >>"$OUTFILE"
  for ext in "${extensions[@]}"; do
    for file in "${example_name}"/*."${ext}"; do
      if [[ -f "$file" ]]; then # Check if it's a regular file
        bname=$(basename "$file")
        gcloud storage cp "$file" "gs://${APPCONFIG_BUCKET}/${bname}" --project="$PROJECT"
        echo "Copied: $file"
      fi
    done
  done
}

# ====================================================================

# the following will set example_name
validate_arg_as_sample_dir "$1"

check_required_commands gcloud grep sed tr
check_shell_variables PROJECT REGION SERVICE_ROOT APPCONFIG_BUCKET

# derived variables
SERVICE_ACCOUNT="${SERVICE_ROOT}"
SA_EMAIL="${SERVICE_ROOT}@${PROJECT}.iam.gserviceaccount.com"
SERVICE="${SERVICE_ROOT}-${example_name}"

printf "Logging to %s\n" "$OUTFILE"

check_and_maybe_create_sa

check_and_maybe_create_gcs_bucket "$APPCONFIG_BUCKET"

grant_roles_to_sa_on_gcs_bucket "$APPCONFIG_BUCKET"

copy_files_to_bucket

clean_files

# printf "Building the service...\n"
# printf "Building the service...\n" >>"$OUTFILE"
# dotnet publish "./$example_name"

manage_linked_files copy

#Find the service account identified by <project-number>@cloudbuild.gserviceaccount.com;
#Edit the service account and add the Cloud Functions Admin and Service Account User roles.

printf "Deploying the service to Cloud run\n"
printf "Deploying the service to Cloud run\n" >>"$OUTFILE"
echo "gcloud run deploy \"${SERVICE}\" \
  --source \"./$example_name\" \
  --project \"${PROJECT}\" \
  --concurrency 5 \
  --cpu 1 \
  --memory '512Mi' \
  --min-instances 0 \
  --max-instances 1 \
  --allow-unauthenticated \
  --update-build-env-vars=\"GCLOUD_BUILD=1\" \
  --region \"${REGION}\" \
  --service-account \"${SA_EMAIL}\" \
  --timeout 380 \
  --set-env-vars \"APP_CONFIG=/mnt/mounted-config\" \
  --add-volume \"name=volume_config,type=cloud-storage,bucket=${APPCONFIG_BUCKET}\" \
  --add-volume-mount \"volume=volume_config,mount-path=/mnt/mounted-config\"" >>$OUTFILE

# Note: mounting filesystems, such as GCS buckets, implicitly requires the gen2
# runtime.  And in that case, must specify 512Mi memory minimum.
gcloud run deploy "${SERVICE}" \
  --source "./${example_name}" \
  --project "${PROJECT}" \
  --concurrency 5 \
  --cpu 1 \
  --memory '512Mi' \
  --min-instances 0 \
  --max-instances 1 \
  --allow-unauthenticated \
  --update-build-env-vars="GCLOUD_BUILD=1" \
  --region "${REGION}" \
  --service-account "${SA_EMAIL}" \
  --timeout 380 \
  --set-env-vars "APP_CONFIG=/mnt/mounted-config" \
  --add-volume "name=volume_config,type=cloud-storage,bucket=${APPCONFIG_BUCKET}" \
  --add-volume-mount "volume=volume_config,mount-path=/mnt/mounted-config"

manage_linked_files rm
