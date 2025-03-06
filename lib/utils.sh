#!/bin/bash
# Copyright 2024-2025 Google LLC
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

APPINT_ENDPT=https://integrations.googleapis.com

beginswith() { case $2 in "$1"*) true ;; *) false ;; esac }

maybe_install_integrationcli() {
  # versions get updated regularly. I don't know how to check for latest.
  # So the safest bet is to just unconditionally install.
  #  if [[ ! -d "$HOME/.apigeecli/bin" ]]; then
  printf "Installing latest integrationcli...\n"
  curl --silent -L https://raw.githubusercontent.com/GoogleCloudPlatform/application-integration-management-toolkit/main/downloadLatest.sh | sh -
  # fi
  export PATH=$PATH:$HOME/.integrationcli/bin
}

CURL() {
  [[ -z "${CURL_OUT}" ]] && CURL_OUT=$(mktemp /tmp/appint-setup-script.curl.out.XXXXXX)
  [[ -f "${CURL_OUT}" ]] && rm ${CURL_OUT}
  #[[ $verbosity -gt 0 ]] && echo "curl $@"
  echo "--------------------" >>"$OUTFILE"
  echo "curl $@" >>"$OUTFILE"
  [[ $verbosity -gt 0 ]] && echo "curl $@"
  CURL_RC=$(curl -s -w "%{http_code}" -H "Authorization: Bearer $TOKEN" -o "${CURL_OUT}" "$@")
  [[ $verbosity -gt 0 ]] && echo "==> ${CURL_RC}"
  echo "==> ${CURL_RC}" >>"$OUTFILE"
  cat "${CURL_OUT}" >>"$OUTFILE"
}

googleapis_whoami() {
  # for diagnostic purposes only
  CURL -X GET "https://www.googleapis.com/oauth2/v1/userinfo?alt=json"
  if [[ ${CURL_RC} -ne 200 ]]; then
    printf "cannot inquire userinfo"
    cat ${CURL_OUT}
    exit 1
  fi

  printf "\nGoogle access token info:\n"
  cat ${CURL_OUT}
}

check_shell_variables() {
  local MISSING_ENV_VARS
  MISSING_ENV_VARS=()
  for var_name in "$@"; do
    if [[ -z "${!var_name}" ]]; then
      MISSING_ENV_VARS+=("$var_name")
    fi
  done

  [[ ${#MISSING_ENV_VARS[@]} -ne 0 ]] && {
    printf -v joined '%s,' "${MISSING_ENV_VARS[@]}"
    printf "You must set these environment variables: %s\n" "${joined%,}"
    exit 1
  }

  printf "Settings in use:\n"
  for var_name in "$@"; do
    printf "  %s=%s\n" "$var_name" "${!var_name}"
  done
  printf "\n"
}

check_required_commands() {
  local missing
  missing=()
  for cmd in "$@"; do
    #printf "checking %s\n" "$cmd"
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done
  if [[ -n "$missing" ]]; then
    printf -v joined '%s,' "${missing[@]}"
    printf "\n\nThese commands are missing; they must be available on path: %s\nExiting.\n" "${joined%,}"
    exit 1
  fi
}

getRandomContentFile() {
  local dir_to_search data_dir data_files selected_file
  if [[ -z "$1" ]]; then
    dir_to_search="."
  else
  dir_to_search="$1"
    fi 
  # Directory containing the JSON files
  data_dir="${dir_to_search}/sampledata"

  # Find all JSON files in the directory
  data_files=(${data_dir}/${DATAKEY}*.xml)

  if [[ ${#data_files[@]} -eq 0 ]]; then
    printf "Cannot find any files to send.\n"
    exit 1
  fi

  # randomly select a file
  selected_file="${data_files[$((RANDOM % ${#data_files[@]}))]}"

  echo "${selected_file}"
}

setRemoteEndpoint_NoCache() {
  check_shell_variables "SERVICE_ROOT" "REGION" "PROJECT"
  printf "querying Cloud run for the endpoint...\n"
  echo "gcloud run services describe \"${SERVICE}\" \
    --region \"${REGION}\" --project=\"${PROJECT}\" \
    --format 'value(status.url)'"
  ENDPOINT=$(gcloud run services describe "${SERVICE}" \
    --region "${REGION}" --project="${PROJECT}" \
    --format 'value(status.url)')
  printf "got %s\n" "$ENDPOINT"
}

setEndpointForRemoteService() {
  local current_timestamp fresh_filename files ftimestamp time_diff

  current_timestamp=$(date +%s)
  fresh_filename=".remote-endpoint-${SERVICE}-${current_timestamp}"

  # Enable nullglob to handle cases with no matching files
  shopt -s nullglob

  # get all files matching a filespec, or empty set if none
  files=(.remote-endpoint-${SERVICE}-*)

  if [[ ${#files[@]} -eq 0 ]]; then
    printf "no cached endpoint...\n"
    setRemoteEndpoint_NoCache

  elif [[ ${#files[@]} -eq 1 && -f "${files[0]}" ]]; then
    # There is only one file. Is it "fresh"?
    # Extract the timestamp from the filename.
    ftimestamp=$(echo "${files[0]}" | grep -oE '[0-9]{10}')
    time_diff=$((current_timestamp - ftimestamp))

    if [[ $time_diff -gt 115 ]]; then
      printf "the cached endpoint is stale...\n"
      rm -f "${files[0]}"
      setRemoteEndpoint_NoCache
    else
      # The file is recent. Rename it to keep it fresh, and return it.
      mv "${files[0]}" $fresh_filename
      ENDPOINT=$(cat "$fresh_filename")
      printf "using cached endpoint: %s\n" "$ENDPOINT"
    fi

  else
    # There is more than one file. Remove all and start again.
    printf "cleaning the cached endpoint files...\n"
    for file in "${files[@]}"; do
      rm -f "$file"
    done
    setRemoteEndpoint_NoCache
  fi

  [[ ! -f "$fresh_filename" ]] && echo "$ENDPOINT" >$fresh_filename
}

validate_arg_as_sample_dir() {
  local arg1 found validdirs
  arg1="$1"
  validdirs=("circle" "claims-simple" "claims-with-rules")
  printf -v joined '%s,' "${validdirs[@]}"
  if [[ -z "$1" ]]; then
    printf "Specify which example you want to deploy: %s\n" "${joined%,}"
    exit 1
  fi
  example_name="$arg1"

  # check
  found=0
  for item in "${validdirs[@]}"; do
    if [[ "$item" == "$example_name" ]]; then
      found=1
      break # Exit the loop once found
    fi
  done

  if [[ "$found" -ne 1 ]]; then
    printf "You specified '%s'\n" "$arg1"
    printf "You must specify one of these as the example you want to deploy: %s\n" "${joined%,}"
    exit 1
  fi
}
