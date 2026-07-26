#!/usr/bin/env bash
set -Eeuo pipefail

TESTS_RUN=0

pass() {
  TESTS_RUN=$((TESTS_RUN + 1))
  printf 'ok %d - %s\n' "$TESTS_RUN" "$1"
}

fail() {
  TESTS_RUN=$((TESTS_RUN + 1))
  printf 'not ok %d - %s\n' "$TESTS_RUN" "$1" >&2
  exit 1
}

assert_contains() {
  local haystack=$1 needle=$2 description=$3
  if [[ "$haystack" == *"$needle"* ]]; then
    pass "$description"
  else
    fail "$description"
  fi
}

assert_success() {
  local description=$1
  shift
  if "$@" >/dev/null 2>&1; then
    pass "$description"
  else
    fail "$description"
  fi
}

assert_failure() {
  local description=$1
  shift
  if "$@" >/dev/null 2>&1; then
    fail "$description"
  else
    pass "$description"
  fi
}
