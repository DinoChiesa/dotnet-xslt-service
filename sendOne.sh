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

# the following will set example_name
validate_arg_as_sample_dir "$1"

printf "example_name: %s\n" "$example_name"
# derived variables
SA_EMAIL="${SERVICE_ROOT}-${example_name}@${PROJECT}.iam.gserviceaccount.com"
SERVICE="${SERVICE_ROOT}-${example_name}"

check_required_commands gcloud date grep

if [[ "${TARGET}" = "local" ]]; then
  printf "TARGET=local...\n"
  ENDPOINT="0:9090"
elif [[ -z "${TARGET}" ]]; then
  printf "TARGET is not specified, will attempt to send to remote Cloud Run service...\n"
  setEndpointForRemoteService
fi

randomfile=$(getRandomContentFile $example_name)
printf "Selected file %s\n" "${randomfile}"

printf "\ninput:\n"
cat "${randomfile}"

printf "\n\nsending to target: %s\n" "$ENDPOINT"

printf "\n\noutput:\n"

curl -i -X POST -H content-type:application/xml \
  ${ENDPOINT}/xml \
  --data-binary @"${randomfile}"

printf "\n\n"
