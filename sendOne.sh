#!/bin/bash
# -*- mode:shell-script; coding:utf-8; -*-

#set -x

source ./env.sh

getRandomContentFile() {
  # Directory containing the JSON files
  json_dir="./sampledata"

  # Find all JSON files in the directory
  data_files=("$json_dir"/*.xml)

  # Get a random file
  random_file="${data_files[$((RANDOM % ${#data_files[@]}))]}"

  echo "${random_file}"
}

getRemoteEndpoint_NoCache() {
  gcloud run services describe "${SERVICE}" \
    --region "${REGION}" --project="${PROJECT}" \
    --format 'value(status.url)'
}

getRemoteEndpoint() {
  local current_timestamp fresh_filename files ENDPOINT ftimestamp time_diff

  current_timestamp=$(date +%s)
  fresh_filename=".remote-endpoint-${current_timestamp}"

  # Enable nullglob to handle cases with no matching files
  shopt -s nullglob

  # get all files matching a filespec, or empty set if none
  files=(.remote-endpoint-*)

  if [[ ${#files[@]} -eq 0 ]]; then
    ENDPOINT=$(getRemoteEndpoint_NoCache)

  elif [[ ${#files[@]} -eq 1 && -f "${files[0]}" ]]; then
    # There is only one file. Is it "fresh"?
    # Extract the timestamp from the filename.
    ftimestamp=$(echo "${files[0]}" | grep -oE '[0-9]{10}')
    time_diff=$((current_timestamp - ftimestamp))

    if [[ $time_diff -gt 115 ]]; then
      rm -f "${files[0]}"
      ENDPOINT=$(getRemoteEndpoint_NoCache)
    else
      # The file is recent. Rename it to keep it fresh, and return it.
      mv "${files[0]}" $fresh_filename
      ENDPOINT=$(cat "$fresh_filename")
    fi

  else
    # There is more than one file. Remove all and start again.
    for file in "${files[@]}"; do
      rm -f "$file"
    done
    ENDPOINT=$(getRemoteEndpoint_NoCache)
  fi

  [[ ! -f "$fresh_filename" ]] && echo "$ENDPOINT" >$fresh_filename
  echo $ENDPOINT
}

if [[ "${TARGET}" = "local" ]]; then
  ENDPOINT="0:9090"
elif [[ -z "${TARGET}" ]]; then
  ENDPOINT=$(getRemoteEndpoint)
fi

randomfile=$(getRandomContentFile)
printf "Selected %s\n" "${randomfile}"

printf "\ninput:\n"
cat "${randomfile}"

printf "\n\nsending to target: %s\n" "$ENDPOINT"

printf "\n\noutput:\n"

curl -i -X POST -H content-type:application/xml \
  ${ENDPOINT}/xml \
  --data-binary @"${randomfile}"

printf "\n\n"
