#!/usr/bin/env bash
set -Eeuo pipefail

TEST_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd -- "$TEST_DIR/.." && pwd)
# shellcheck source=lib/testlib.sh
source "$TEST_DIR/lib/testlib.sh"

checked=0
while IFS= read -r markdown_file; do
  while IFS= read -r reference; do
    target=${reference#*](}
    target=${target%)}
    case "$target" in
      https://* | http://* | mailto:* | \#*) continue ;;
    esac
    target=${target%%#*}
    [[ -n "$target" ]] || continue
    if [[ "$target" == /* ]]; then
      resolved=$target
    else
      resolved=$(dirname "$markdown_file")/$target
    fi
    [[ -e "$resolved" ]] || fail "broken local link in ${markdown_file#"$PROJECT_ROOT"/}: $target"
    checked=$((checked + 1))
  done < <(grep -oE ']\([^)]+\)' "$markdown_file" || true)
done < <(find "$PROJECT_ROOT" -path "$PROJECT_ROOT/.git" -prune -o -type f -name '*.md' -print)

(( checked > 0 )) || fail "no local documentation links were discovered"
pass "$checked local documentation links resolve"
