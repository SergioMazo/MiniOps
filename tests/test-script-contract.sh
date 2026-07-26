#!/usr/bin/env bash
set -Eeuo pipefail

TEST_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd -- "$TEST_DIR/.." && pwd)
# shellcheck source=lib/testlib.sh
source "$TEST_DIR/lib/testlib.sh"

while IFS= read -r script; do
  first=$(sed -n '1p' "$script")
  second=$(sed -n '2p' "$script")
  [[ "$first" == '#!/usr/bin/env bash' ]] ||
    fail "$(basename "$script") has the required shebang"
  [[ "$second" == 'set -Eeuo pipefail' ]] ||
    fail "$(basename "$script") enables strict mode"
  bash -n "$script" || fail "$(basename "$script") parses"
done < <(find "$PROJECT_ROOT/scripts" "$PROJECT_ROOT/tests" -type f -name '*.sh' | sort)
pass "all Bash files satisfy the script contract"

while IFS= read -r script; do
  [[ -x "$script" ]] || fail "$(basename "$script") is executable"
done < <(find "$PROJECT_ROOT/scripts" "$PROJECT_ROOT/tests" -type f -name '*.sh' | sort)
pass "all Bash files are executable"

while IFS= read -r script; do
  assert_success "$(basename "$script") help works without host configuration" "$script" --help
done < <(find "$PROJECT_ROOT/scripts" -maxdepth 1 -type f -name '*.sh' | sort)

assert_success "installer deploys the Restic runtime library" \
  grep -Fq '/usr/local/lib/miniops/miniops-restic.sh' "$PROJECT_ROOT/scripts/install.sh"
assert_success "installer deploys repository initialization" \
  grep -Fq 'init-repository' "$PROJECT_ROOT/scripts/install.sh"
