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
SA_REQUIRED_ROLES=("roles/integrations.integrationInvoker")

get_gcs_connector() {
  # Inquire the GCS connectors in the Region + Project
  local CTOR_VERSION gcs_connectors newname urlbase proj_number
  CTOR_VERSION="projects/${PROJECT}/locations/global/providers/gcp/connectors/gcs/versions/1"
  urlbase="https://connectors.googleapis.com/v1/projects/${PROJECT}/locations/${REGION}/connections"
  CURL -X GET "${urlbase}"
  gcs_connectors=($(jq '(.connections[] | select(.connectorVersion == "'${CTOR_VERSION}'") | .name)' ${CURL_OUT} |
    tr -d ' "'))
  if [[ ${#gcs_connectors[@]} -eq 0 ]]; then
    printf "no GCS connector found, you will need to create one.\n"
    exit 1
  else
    GCS_CONNECTOR="${gcs_connectors[0]}"
    printf "Found GCS connector:\n  %s\n" "$GCS_CONNECTOR"
  fi
}

verify_sa_exists() {
  local sa_email
  sa_email="$1"
  printf "Checking for service account %s...\n" "$sa_email"
  printf "Checking for service account %s...\n" "$sa_email" >>"$OUTFILE"
  echo "gcloud iam service-accounts describe \"$sa_email\" --project=\"$PROJECT\" --quiet" >>"$OUTFILE"
  if gcloud iam service-accounts describe "$sa_email" --project="$PROJECT" --quiet >>"$OUTFILE" 2>&1; then
    printf "That service account exists...\n"
  else
    printf "That service account does not exist. Please run deploy-service.sh first..\n"
    exit 1
  fi
}

check_and_grant_sa_roles() {
  local ROLE ARR sa_email
  sa_email="$1"
  if [[ ${#SA_REQUIRED_ROLES[@]} -ne 0 ]]; then
    printf "Checking for required roles....\n"
    printf "Checking for required roles....\n" >>"$OUTFILE"

    # I could not get the --filter argument to work here. :<
    # shellcheck disable=SC2076
    ARR=($(gcloud projects get-iam-policy "${PROJECT}" \
      --flatten="bindings[].members" |
      grep -v deleted |
      grep -A 1 members |
      grep -A 1 "$sa_email" |
      grep role | sed -e 's/role: //'))

    for ROLE in "${SA_REQUIRED_ROLES[@]}"; do
      printf "  check role... %s...\n" "$ROLE"
      printf "  check role... %s...\n" "$ROLE" >>"$OUTFILE"
      if ! [[ ${ARR[*]} =~ "${ROLE}" ]]; then
        printf "    Adding role %s...\n" "${ROLE}"
        printf "    Adding role %s...\n" "${ROLE}" >>"$OUTFILE"
        gcloud projects add-iam-policy-binding "${PROJECT}" --condition=None \
          --member="serviceAccount:$sa_email" --role="${ROLE}" --quiet >/dev/null 2>&1
      else
        printf "    That role is already set...\n"
      fi
    done
  else
    printf "There are no roles to grant to the SA ...\n"
  fi
}

check_and_maybe_create_gcs_upload_bucket() {
  printf "Checking GCS bucket (%s)...\n" "gs://${UPLOAD_BUCKET}"
  echo "--------------------" >>"$OUTFILE"
  echo "gcloud storage buckets describe \"gs://${UPLOAD_BUCKET}\" --format=\"json(name)\" --project=\"$PROJECT\" --quiet" >>"$OUTFILE"
  if gcloud storage buckets describe "gs://${UPLOAD_BUCKET}" --format="json(name)" --project="$PROJECT" --quiet >>"$OUTFILE" 2>&1; then
    printf "That bucket already exists.\n"
  else
    printf "Creating the bucket...\n"
    echo "--------------------" >>"$OUTFILE"
    echo "gcloud storage buckets create \"gs://${UPLOAD_BUCKET}\" --default-storage-class=standard --location=\"${REGION}\" --project=\"$PROJECT\" --quiet" >>"$OUTFILE"
    gcloud storage buckets create "gs://${UPLOAD_BUCKET}" --default-storage-class=standard --location="${REGION}" --project="$PROJECT" --quiet >>"$OUTFILE" 2>&1
    # The following sets up a notification to pubsub on object finalization.
    # If the topic doesn't exist in the GCP project, this command creates it.
    printf "...and a notification...\n"
    echo "--------------------" >>"$OUTFILE"
    echo "gcloud storage buckets notifications create \"gs://${UPLOAD_BUCKET}\" --topic=\"${PUBSUB_TOPIC}\" --project=\"$PROJECT\" --quiet --event-types=\"OBJECT_FINALIZE\"" >>"$OUTFILE"
    gcloud storage buckets notifications create "gs://${UPLOAD_BUCKET}" --topic="${PUBSUB_TOPIC}" --project="$PROJECT" --quiet --event-types="OBJECT_FINALIZE" >>"$OUTFILE" 2>&1
  fi
}

replace_keywords_in_template() {
  local TMP
  TMP=$(mktemp /tmp/appint-setup.tmp.out.XXXXXX)
  echo "--------------------" >>"$OUTFILE"
  echo "replace_keywords_in_template" >>"$OUTFILE"
  echo "FULL_SA_EMAIL = ${FULL_SA_EMAIL}" >>"$OUTFILE"
  echo "EMAIL_ADDR = ${EMAIL_ADDR}" >>"$OUTFILE"
  echo "GCP_PROJECT = ${PROJECT}" >>"$OUTFILE"
  echo "REGION = ${REGION}" >>"$OUTFILE"
  echo "INTEGRATION_NAME = ${INTEGRATION_NAME}" >>"$OUTFILE"
  echo "XSLT_CIRCLE_URI = ${XSLT_CIRCLE_URI}" >>"$OUTFILE"
  echo "XSLT_CLAIMS_URI = ${XSLT_CLAIMS_URI}" >>"$OUTFILE"
  echo "GCS_CONNECTOR = ${GCS_CONNECTOR}" >>"$OUTFILE"
  echo "PUBSUB_TOPIC = ${PUBSUB_TOPIC}" >>"$OUTFILE"

  # sed "s/@@AUTH_CONFIG@@/${AUTH_CONFIG}/g" $INTEGRATION_FILE >$TMP && cp $TMP $INTEGRATION_FILE
  # the following is needed only if running the integration as this SA.
  sed "s/@@FULL_SA_EMAIL@@/${FULL_SA_EMAIL}/g" $INTEGRATION_FILE >$TMP && cp $TMP $INTEGRATION_FILE
  sed "s/@@EMAIL_ADDR@@/${EMAIL_ADDR}/g" $INTEGRATION_FILE >$TMP && cp $TMP $INTEGRATION_FILE
  sed "s/@@GCP_PROJECT@@/${PROJECT}/g" $INTEGRATION_FILE >$TMP && cp $TMP $INTEGRATION_FILE
  sed "s/@@REGION@@/${REGION}/g" $INTEGRATION_FILE >$TMP && cp $TMP $INTEGRATION_FILE
  sed "s/@@INTEGRATION_NAME@@/${INTEGRATION_NAME}/g" $INTEGRATION_FILE >$TMP && cp $TMP $INTEGRATION_FILE
  sed "s|@@XSLT_CIRCLE_URI@@|${XSLT_CIRCLE_URI}|g" $INTEGRATION_FILE >$TMP && cp $TMP $INTEGRATION_FILE
  sed "s|@@XSLT_CLAIMS_URI@@|${XSLT_CLAIMS_URI}|g" $INTEGRATION_FILE >$TMP && cp $TMP $INTEGRATION_FILE
  sed "s|@@GCS_CONNECTOR@@|${GCS_CONNECTOR}|g" $INTEGRATION_FILE >$TMP && cp $TMP $INTEGRATION_FILE
  sed "s/@@PUBSUB_TOPIC@@/${PUBSUB_TOPIC}/g" $INTEGRATION_FILE >$TMP && cp $TMP $INTEGRATION_FILE
  rm -f $TMP
}

replace_content_files_in_template() {
  echo "--------------------" >>"$OUTFILE"
  echo "replace_content_files_in_template" >>"$OUTFILE"
  local TMP
  TMP=$(mktemp /tmp/appint-setup.tmp.out.XXXXXX)

  # This slurps in a content file and inserts it into the appropriate place in
  # the template. For now, content files include various JavaScript, Jsonnet, and
  # possibly the email text body template.

  jq --arg content "$(cat ./integration-content/xslt-first-node.jsonnet)" \
    '(.taskConfigs[] | select(.task == "JsonnetMapperTask" and .taskId == "1") | .parameters).template.value.stringValue = $content' $INTEGRATION_FILE >$TMP && cp $TMP $INTEGRATION_FILE

  jq --arg content "$(cat ./integration-content/set-connector-payload.js)" \
    '(.taskConfigs[] | select(.task == "JavaScriptTask" and .taskId == "4") | .parameters).script.value.stringValue = $content' $INTEGRATION_FILE >$TMP && cp $TMP $INTEGRATION_FILE

  jq --arg content "$(cat ./integration-content/get-xml-content.js)" \
    '(.taskConfigs[] | select(.task == "JavaScriptTask" and .taskId == "6") | .parameters).script.value.stringValue = $content' $INTEGRATION_FILE >$TMP && cp $TMP $INTEGRATION_FILE

  jq --arg content "$(cat ./integration-content/set-target-uri.js)" \
    '(.taskConfigs[] | select(.task == "JavaScriptTask" and .taskId == "7") | .parameters).script.value.stringValue = $content' $INTEGRATION_FILE >$TMP && cp $TMP $INTEGRATION_FILE

  jq --arg content "$(cat ./integration-content/initial-field-mapping.json)" \
    '(.taskConfigs[] | select(.task == "FieldMappingTask" and .taskId == "2") | .parameters).FieldMappingConfigTaskParameterKey.value.jsonValue = $content' $INTEGRATION_FILE >$TMP && cp $TMP $INTEGRATION_FILE

  jq --arg content "$(cat ./integration-content/plaintext-firstnode.xsl)" \
    '(.integrationConfigParameters[] | select(.parameter.key == "`CONFIG_first-node-name-xsl`") | .parameter).defaultValue.stringValue = $content' $INTEGRATION_FILE >$TMP && cp $TMP $INTEGRATION_FILE
  jq --arg content "$(cat ./integration-content/plaintext-firstnode.xsl)" \
    '(.integrationConfigParameters[] | select(.parameter.key == "`CONFIG_first-node-name-xsl`") | .value).stringValue = $content' $INTEGRATION_FILE >$TMP && cp $TMP $INTEGRATION_FILE

  jq --arg content "$(cat ./integration-content/confirmation-email.txt)" \
    '(.taskConfigs[] | select(.task == "EmailTask" and .taskId == "9") | .parameters).TextBody.value.stringValue = $content' $INTEGRATION_FILE >$TMP && cp $TMP $INTEGRATION_FILE

  rm -f $TMP
}

# ====================================================================
OUTFILE=$(mktemp /tmp/appint-setup.out.XXXXXX)
printf "\nThis is the setup for the App Int XSLT Example.\n\n"
printf "timestamp: %s\n" "$TIMESTAMP" >>"$OUTFILE"
printf "Logging to %s\n" "$OUTFILE"
check_shell_variables "PROJECT" "REGION" "SERVICE_ROOT" "UPLOAD_BUCKET" "EMAIL_ADDR" "PUBSUB_TOPIC"
check_required_commands jq curl gcloud grep sed tr

printf "random seed: %s\n" "$rand_string"
printf "random seed: %s\n" "$rand_string" >>"$OUTFILE"

TOKEN=$(gcloud auth print-access-token)
if [[ -z "$TOKEN" ]]; then
  printf "Could not get a token with the gcloud cli. See logs in %s\n" "$OUTFILE"
  printf "Could not get a token with the gcloud cli. See logs in %s\n" "$OUTFILE" >>"$OUTFILE"
  exit 1
fi

googleapis_whoami
get_gcs_connector
check_and_maybe_create_gcs_upload_bucket
maybe_install_integrationcli

FULL_SA_EMAIL="${SERVICE_ROOT}@${PROJECT}.iam.gserviceaccount.com"
verify_sa_exists "$FULL_SA_EMAIL"
check_and_grant_sa_roles "$FULL_SA_EMAIL"

# Replace all the keywords
INTEGRATION_FILE="${SERVICE_ROOT}-${rand_string}.json"
cp ./integration-content/xslt-handler-v9-template.json "$INTEGRATION_FILE"
chmod 644 "$INTEGRATION_FILE"

# set parameters for endpoints etc
echo "--------------------" >>"$OUTFILE"
XSLT_CIRCLE_URI=$(gcloud run services describe "${SERVICE_ROOT}-circle" \
  --region "${REGION}" --project="${PROJECT}" \
  --format 'value(status.url)')
XSLT_CLAIMS_URI=$(gcloud run services describe "${SERVICE_ROOT}-claims-with-rules" \
  --region "${REGION}" --project="${PROJECT}" \
  --format 'value(status.url)')
echo "XSLT_CIRCLE_URI = ${XSLT_CIRCLE_URI}" >>"$OUTFILE"
echo "XSLT_CLAIMS_URI = ${XSLT_CLAIMS_URI}" >>"$OUTFILE"
echo "FULL_SA_EMAIL = ${FULL_SA_EMAIL}" >>"$OUTFILE"
echo "GCS_CONNECTOR = ${GCS_CONNECTOR}" >>"$OUTFILE"

replace_keywords_in_template
replace_content_files_in_template

echo "creating integration..."
echo "--------------------" >>"$OUTFILE"
echo "integrationcli integrations create -f $INTEGRATION_FILE -n $INTEGRATION_NAME -p $PROJECT -r $REGION" >>"$OUTFILE"
integrationcli integrations create -f "$INTEGRATION_FILE" -n "$INTEGRATION_NAME" -p "$PROJECT" -r "$REGION" -t "$TOKEN" >>"$OUTFILE" 2>&1

# If we try to list versions straightaway, sometimes it does not work
sleep 2

snapshotarr=($(integrationcli integrations versions list -n "$INTEGRATION_NAME" -r "$REGION" -p "$PROJECT" -t "$TOKEN" |
  jq '.integrationVersions[].snapshotNumber'))

if [[ ${#snapshotarr[@]} -gt 0 ]]; then
  snapshot="${snapshotarr[0]}"
  printf "The Integration has been created. Now let's wait a bit before publishing snapshot %s.\n\n" "$snapshot"
  sleep 5
  echo "--------------------" >>"$OUTFILE"
  echo "integrationcli integrations versions publish -n $INTEGRATION_NAME -s $snapshot --latest=false -r $REGION -p $PROJECT" >>"$OUTFILE"

  if ! integrationcli integrations versions publish -n "$INTEGRATION_NAME" -s "$snapshot" --latest=false -r "$REGION" -p "$PROJECT" -t "$TOKEN" >>"$OUTFILE" 2>&1; then
    printf "The publish attempt failed. For diagnostics, check the output file $OUTFILE \n"
    exit 1
  fi

  printf "The Integration has been published. Now let's wait a bit for it to become available.\n\n"
  sleep 8

  console_link="https://console.cloud.google.com/integrations/edit/$INTEGRATION_NAME/locations/${REGION}?project=$PROJECT"
  printf "\nTo view the uploaded integration on Cloud Console, open this link:\n    %s\n\n" "$console_link"
  printf "\n\n"

else
  printf "Failed retrieving versions of the Integration we just created. Check the log file?\n"
  printf "==> %s\n" "$OUTFILE"
  exit 1
fi
