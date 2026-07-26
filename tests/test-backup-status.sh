#!/usr/bin/env bash
set -Eeuo pipefail

TEST_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd -- "$TEST_DIR/.." && pwd)
# shellcheck source=lib/testlib.sh
source "$TEST_DIR/lib/testlib.sh"

state=$(mktemp -d)
trap 'find "$state" -mindepth 1 -delete; rmdir "$state"' EXIT
mkdir -p "$state/status"
printf '%s\n' 'ID=ubuntu' 'VERSION_ID=24.04' >"$state/os-release"
cat >"$state/status/backup.env" <<'EOF'
LAST_BACKUP=2030-01-15T02:04:00Z
SNAPSHOT_COUNT=14
REPOSITORY_SIZE=8.4_GiB
EOF
printf '2030-01-12T04:09:00Z\n' >"$state/status/last-check"
printf '2030-01-01T06:34:00Z\n' >"$state/status/last-restore-test"

output=$(
  MINIOPS_TEST_PLATFORM=linux \
    MINIOPS_OS_RELEASE_FILE="$state/os-release" \
    MINIOPS_GENERAL_CONFIG=/nonexistent \
    MINIOPS_STATE_DIR="$state" \
    "$PROJECT_ROOT/scripts/backup-status.sh" --no-color
)
assert_contains "$output" 'MiniOps status' "dashboard renders"
assert_contains "$output" '2030-01-15T02:04:00Z' "last backup is shown"
assert_contains "$output" 'Snapshots:' "snapshot field is shown"
assert_contains "$output" 'Last restore test:' "restore field is shown"

if grep -Eiq '(RESTIC_|password|token|private[ _-]?key|/etc/miniops/secrets)' <<<"$output"; then
  fail "dashboard output contains sensitive material"
else
  pass "dashboard output is sanitized"
fi

assert_success "dashboard help succeeds" "$PROJECT_ROOT/scripts/backup-status.sh" --help
assert_failure "dashboard rejects unknown options" "$PROJECT_ROOT/scripts/backup-status.sh" --unknown
