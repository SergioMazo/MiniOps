#!/usr/bin/env bash
set -Eeuo pipefail

TEST_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd -- "$TEST_DIR/.." && pwd)
# shellcheck source=lib/testlib.sh
source "$TEST_DIR/lib/testlib.sh"

assert_success "preflight help succeeds" "$PROJECT_ROOT/scripts/preflight-check.sh" --help

fixture=$(mktemp)
trap 'rm -f -- "$fixture"' EXIT
cat >"$fixture" <<'EOF'
ID=ubuntu
VERSION_ID=24.04
EOF
output=$(
  MINIOPS_TEST_PLATFORM=linux \
    MINIOPS_SKIP_SYSTEMD_CHECK=1 \
    MINIOPS_OS_RELEASE_FILE="$fixture" \
    "$PROJECT_ROOT/scripts/preflight-check.sh" --json
)
assert_contains "$output" '"status":"ok"' "supported fixture passes"
assert_contains "$output" '"platform":"ubuntu 24.04"' "platform is reported"

cat >"$fixture" <<'EOF'
ID=examplelinux
VERSION_ID=1
EOF
assert_failure "unsupported fixture fails closed" env \
  MINIOPS_TEST_PLATFORM=linux \
  MINIOPS_SKIP_SYSTEMD_CHECK=1 \
  MINIOPS_OS_RELEASE_FILE="$fixture" \
  "$PROJECT_ROOT/scripts/preflight-check.sh" --json

