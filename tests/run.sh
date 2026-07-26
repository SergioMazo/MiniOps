#!/usr/bin/env bash
set -Eeuo pipefail

TEST_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
failures=0
tests=0

while IFS= read -r test_file; do
  tests=$((tests + 1))
  printf '\n==> %s\n' "$(basename "$test_file")"
  if ! "$test_file"; then
    failures=$((failures + 1))
  fi
done < <(find "$TEST_DIR" -maxdepth 1 -type f -name 'test-*.sh' | sort)

printf '\nTests: %d, failures: %d\n' "$tests" "$failures"
(( failures == 0 ))

