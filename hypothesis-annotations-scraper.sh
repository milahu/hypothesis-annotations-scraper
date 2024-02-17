#!/usr/bin/env bash

# download all annotations for a user from https://hypothes.is/

set -e
#set -x

# https://h.readthedocs.io/en/latest/api-reference/v1/#tag/annotations/paths/~1search/get

# https://jonudell.info/h/facet/

# https://github.com/hypothesis/product-backlog/issues/566

user="$1"

if [ -z "$user" ]; then
  echo "usage: $0 some_username"
  exit 1
fi

base_url="https://hypothes.is/api/search?sort=updated&limit=200&user=$user"

num_done=0
num_total=
last_date=
search_after=

date_format="%Y%m%dT%H%M%SZ"

date=$(date --utc +"$date_format")

result_json_list=()

while true; do

  url="$base_url"
  if [ -n "$search_after" ]; then
    url+="&search_after=$search_after"
  fi

  result_json=$(curl -s "$url")

  result_json_list+=("$result_json")

  if [ -z "$num_total" ]; then
    num_total=$(jq -r '.total' <<<"$result_json")
    # fix: off by one error
    num_total=$((num_total - 1))
    #echo "num_total: $num_total"
  fi

  if [ -z "$last_date" ]; then
    last_date=$(jq -r '.rows[0].updated' <<<"$result_json")
    #echo "last_date: $last_date"
    date=$(date --utc +"$date_format" -d "$last_date")
    out="$user.$date.json"
    if [ -e "$out" ]; then
      echo "keeping $out"
      exit
    fi
  fi

  num_rows=$(jq -r '.rows | length' <<<"$result_json")
  #echo "num_rows: $num_rows"

  num_done=$((num_done + num_rows))
  echo "done $num_done of $num_total"

  ((num_done >= num_total)) && break

  search_after=$(jq -r '.rows[-1].updated' <<<"$result_json")

done

# pass multiple strings via process substitution
# https://stackoverflow.com/questions/51040310/process-substitution-for-each-array-entry-without-eval
echo "writing $out"
jq_script='map(.rows) | add as $rows | { total: $rows | length, rows: $rows }'
eval \
  jq -s -c '"$jq_script"' \
  $(printf '<(echo -n "${result_json_list[%s]}") ' "${!result_json_list[@]}") \
  >"$out"
