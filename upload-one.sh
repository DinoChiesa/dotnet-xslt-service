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

# ====================================================================
validdirs=("circle" "claims-simple" "claims-with-rules")
selected_dir="${validdirs[$((RANDOM % ${#validdirs[@]}))]}"
selected_file=$(getRandomContentFile $selected_dir)
printf "Selected %s\n" "$selected_file"
bname=$(basename $selected_file)

gcloud storage cp "$selected_file" "gs://${UPLOAD_BUCKET}/${bname}" --project="$PROJECT" 

