#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ -r "$SCRIPT_DIR/lib/miniops-common.sh" ]]; then
  # shellcheck source=lib/miniops-common.sh
  source "$SCRIPT_DIR/lib/miniops-common.sh"
else
  # shellcheck source=/dev/null
  source /usr/local/lib/miniops/miniops-common.sh
fi

usage() {
  cat <<'EOF'
Usage: restore-test.sh [--dry-run] [--help]

Restore configured representative paths into a private temporary directory,
validate their existence, and remove the directory.
EOF
}

while (($#)); do
  case "$1" in
    --dry-run) MINIOPS_DRY_RUN=1 ;;
    --help)
      usage
      exit 0
      ;;
    *) miniops_usage_error "Unknown option: $1" ;;
  esac
  shift
done

if [[ -r "$SCRIPT_DIR/lib/miniops-restic.sh" ]]; then
  # shellcheck source=lib/miniops-restic.sh
  source "$SCRIPT_DIR/lib/miniops-restic.sh"
else
  # shellcheck source=/dev/null
  source /usr/local/lib/miniops/miniops-restic.sh
fi
miniops_require_root
: "${MINIOPS_RESTORE_TEST_PATHS_FILE:?MINIOPS_RESTORE_TEST_PATHS_FILE is required}"
[[ -s "$MINIOPS_RESTORE_TEST_PATHS_FILE" && ! -L "$MINIOPS_RESTORE_TEST_PATHS_FILE" ]] ||
  miniops_die "Restore-test path list is unavailable." 78

paths=()
while IFS= read -r path; do
  [[ -n "$path" && "$path" != \#* ]] || continue
  [[ "$path" == /* && "$path" != / && "$path" != *..* ]] ||
    miniops_die "Unsafe restore-test path." 78
  paths+=("$path")
done <"$MINIOPS_RESTORE_TEST_PATHS_FILE"
((${#paths[@]})) || miniops_die "No restore-test paths are configured." 78

miniops_prepare_restic 1
restore_base=$MINIOPS_STATE_DIR/restore-tests
miniops_run install -d -o root -g root -m 0700 "$restore_base"
if (( MINIOPS_DRY_RUN )); then
  args=(restore latest --tag "$MINIOPS_BACKUP_TAG" --target "$restore_base/restore-test.DRYRUN")
  for path in "${paths[@]}"; do args+=(--include "$path"); done
  miniops_quote_command restic "${args[@]}"
  exit 0
fi

target=$(mktemp -d "$restore_base/restore-test.XXXXXX")
chmod 0700 "$target"
cleanup() {
  [[ "$target" == "$restore_base"/restore-test.* ]] ||
    miniops_die "Unsafe restore cleanup target." 73
  find "$target" -mindepth 1 -depth -delete
  rmdir "$target"
}
trap cleanup EXIT

args=(restore latest --tag "$MINIOPS_BACKUP_TAG" --target "$target")
for path in "${paths[@]}"; do args+=(--include "$path"); done
restic "${args[@]}"

for path in "${paths[@]}"; do
  restored="$target$path"
  [[ -e "$restored" ]] || miniops_die "Representative restore path is missing." 1
  if [[ -f "$restored" ]]; then
    [[ -s "$restored" ]] || miniops_die "Representative restored file is empty." 1
  fi
done
miniops_write_marker "$MINIOPS_STATE_DIR/status/last-restore-test"
miniops_log INFO "Isolated restore test completed successfully."
