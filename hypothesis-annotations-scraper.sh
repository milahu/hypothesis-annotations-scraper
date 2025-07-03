#!/usr/bin/env bash

# download all annotations for a user from https://hypothes.is/

set -e
#set -x

# https://github.com/hypothesis/h

# https://h.readthedocs.io/en/latest/api-reference/v1/#tag/annotations/paths/~1search/get

# https://jonudell.info/h/facet/

# https://github.com/hypothesis/product-backlog/issues/566

debug=false
# debug=true

user="$1"

if [ -z "$user" ]; then
  echo "usage: $0 some_username"
  exit 1
fi

# https://r-world-devs.github.io/hypothesis/reference/search_annotations.html
base_url="https://hypothes.is/api/search?sort=updated&limit=200&user=$user"

num_done=0
num_total=
last_date=
search_after=

date_format="%Y%m%dT%H%M%SZ"

date=$(date --utc +"$date_format")

result_json_list=()

# https://h.readthedocs.io/en/latest/api/authorization/
api_token=""
api_token_file="$HOME/.config/hypothesis-annotations/api-token.txt"
if [ -e "$api_token_file" ]; then
  echo "using api token from $api_token_file"
  api_token="$(< "$api_token_file")"
else
  echo "not using api token from $api_token_file"
  echo "  note: without an api token, we can scrape only public data = only annotations, but no highlights"
  echo "  you can get an api token at https://hypothes.is/account/developer"
fi

while true; do

  step_time=$(date +%s.%N)

  url="$base_url"

  # https://github.com/hypothesis/h/issues/5191#issuecomment-419400695
  # https://web.hypothes.is/blog/new-search-api-parameter-search_after/
  # search_after is based on sort and order.
  # sort defaults to the updated field, or the last time the annotation was updated,
  # and order defaults to descending (so the most recently updated annotations will be found and returned first).
  # search_after will return annotations that occur after the annotation whose sort field has the search_after’s value.
  if [ -n "$search_after" ]; then
    url+="&search_after=$search_after"
  fi

  result_json=$(curl -s -H "Authorization: Bearer $api_token" "$url")

  if $debug; then
    echo "$url" >debug.$step_time.url.txt
    echo "$result_json" | jq >debug.$step_time.result_json.json
  fi

  result_json_list+=("$result_json")

  if [ -z "$num_total" ]; then
    num_total=$(jq -r '.total' <<<"$result_json")
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

  [[ "$search_after" == "null" ]] && break

done

# pass multiple strings via process substitution
# https://stackoverflow.com/questions/51040310/process-substitution-for-each-array-entry-without-eval
echo "writing $out"
jq_script='map(.rows) | add as $rows | { total: $rows | length, rows: $rows }'
eval \
  jq -s -c '"$jq_script"' \
  $(printf '<(echo -n "${result_json_list[%s]}") ' "${!result_json_list[@]}") \
  >"$out"
