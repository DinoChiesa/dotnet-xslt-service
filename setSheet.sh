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

#set -x

source ./env.sh

if [[ $# -eq 0 ]]; then
  printf "\nProvide one argument - the basename of a sheet. Options:\n"
  ls sheets/*.xsl | sed -e 's/\.xsl//' | sed -e 's@sheets/@  @'
  printf "\n"
  exit 1
fi

XSL_FILE="./sheets/$1.xsl"

if [[ ! -f "$XSL_FILE" ]]; then
  printf "\nThe XSL Sheet (%s) does not exist.\n" "$XSL_FILE"
  exit 1
fi

# copy the file
if [[ "${TARGET}" = "local" ]]; then
  cp "$XSL_FILE" ./stylesheet1.xsl
else
  gcloud storage cp "$XSL_FILE" "gs://${BUCKET_NAME}/stylesheet1.xsl" --project="$PROJECT"
fi

# set the endpoint
if [[ "${TARGET}" = "local" ]]; then
  ENDPOINT="0:9090"
elif [[ -z "${TARGET}" ]]; then
  ENDPOINT=$(gcloud run services describe "${SERVICE}" --region "${REGION}" --project="${PROJECT}" --format 'value(status.url)')
fi

printf "\n\ninvoking reload on target: %s\n" "$ENDPOINT"

printf "\n\noutput:\n"

curl -i -X POST -H content-type:application/json \
  ${ENDPOINT}/reload -d {}

printf "\n\n"
