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

randomfile=$(getRandomContentFile)
printf "Selected %s\n" "${randomfile}"

printf "\ninput:\n"
cat "${randomfile}"

if [[ "${TARGET}" = "local" ]]; then
  ENDPOINT="0:9090"
elif [[ -z "${TARGET}" ]]; then
  ENDPOINT=$(gcloud run services describe "${SERVICE}" --region "${REGION}" --project="${PROJECT}" --format 'value(status.url)')
fi

printf "\n\nsending to target: %s\n" "$ENDPOINT"

printf "\n\noutput:\n"

curl -i -X POST -H content-type:application/xml \
  ${ENDPOINT}/xml \
  --data-binary @"${randomfile}"

printf "\n\n"
