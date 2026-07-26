#!/usr/bin/env bash
set -Eeuo pipefail

TEST_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd -- "$TEST_DIR/.." && pwd)
# shellcheck source=lib/testlib.sh
source "$TEST_DIR/lib/testlib.sh"

while IFS= read -r config_file; do
  assert_success "$(basename "$config_file") parses as Bash" bash -n "$config_file"
done < <(find "$PROJECT_ROOT/config" "$PROJECT_ROOT/examples" -type f -name '*.env.example' | sort)

output=$(bash -c "
  set -u
  source '$PROJECT_ROOT/config/backup.env.example'
  printf '%s|%s|%s' \"\$RESTIC_REPOSITORY\" \"\$RESTIC_PASSWORD_FILE\" \"\$MINIOPS_BACKUP_TAG\"
")
assert_contains "$output" '100.x.x.x' "repository example is fictitious"
assert_contains "$output" '/etc/miniops/secrets/restic-password' "secret file path follows policy"
assert_contains "$output" '|miniops' "backup tag is defined"

safe_env=$(mktemp)
unsafe_env=$(mktemp)
trap 'rm -f -- "$safe_env" "$unsafe_env"' EXIT
printf '%s\n' \
  "MINIOPS_TEST_VALUE='literal value'" \
  'RESTIC_REPOSITORY=/path/to/repository' >"$safe_env"
chmod 0600 "$safe_env"
output=$(
  bash -c "
    source '$PROJECT_ROOT/scripts/lib/miniops-common.sh'
    miniops_load_env '$safe_env'
    printf '%s|%s' \"\$MINIOPS_TEST_VALUE\" \"\$RESTIC_REPOSITORY\"
  "
)
assert_contains "$output" 'literal value|/path/to/repository' "safe environment parser preserves data"

printf '%s\n' 'BASH_ENV=/path/to/repository' >"$unsafe_env"
chmod 0600 "$unsafe_env"
assert_failure "environment parser rejects shell-control variables" bash -c "
  source '$PROJECT_ROOT/scripts/lib/miniops-common.sh'
  miniops_load_env '$unsafe_env'
"

while IFS= read -r unit; do
  assert_success "$(basename "$unit") is non-empty" test -s "$unit"
  if [[ "$unit" == *.service ]]; then
    assert_success "$(basename "$unit") has a service section" grep -q '^\[Service\]$' "$unit"
  else
    assert_success "$(basename "$unit") has a timer section" grep -q '^\[Timer\]$' "$unit"
  fi
done < <(find "$PROJECT_ROOT/systemd" -type f | sort)
