#!/usr/bin/env bash

for result_json_file in debug.*.result_json.json; do
  echo -----------
  url_file=${result_json_file%.result_json.json}.url.txt
  cat $url_file
  jq -r '
    .rows[] |
    "\(.updated) \(.document.title[0][0:50]) :: \(
      (if .text != "" then .text[0:50] else .target[0].selector[2].exact[0:50] end) |
      gsub("\n"; "\\n")? // ""
    )"
  ' $result_json_file
done
