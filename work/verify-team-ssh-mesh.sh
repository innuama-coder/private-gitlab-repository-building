#!/bin/sh
set -u

source_name=$1
shift
failures=0

for target in "$@"; do
  if [ "$target" = "$source_name" ]; then
    continue
  fi

  output=$(ssh -o ConnectTimeout=15 "$target" id -un 2>&1)
  status=$?
  identity=$(printf '%s\n' "$output" | tail -n 1)
  if [ "$status" -eq 0 ] && [ "$identity" = "kunora" ]; then
    printf '%s\t%s\tPASS\tkunora\n' "$source_name" "$target"
  else
    printf '%s\t%s\tFAIL\tstatus=%s output=%s\n' \
      "$source_name" "$target" "$status" "$output"
    failures=$((failures + 1))
  fi
done

exit "$failures"
