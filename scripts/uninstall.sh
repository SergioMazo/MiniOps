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
Usage: uninstall.sh [--dry-run] [--yes] [--help]

Remove files recorded in the MiniOps install manifest.
Configuration, secrets, state, repositories, and backups are preserved.
EOF
}

while (($#)); do
  case "$1" in
    --dry-run) MINIOPS_DRY_RUN=1 ;;
    --yes) MINIOPS_ASSUME_YES=1 ;;
    --help)
      usage
      exit 0
      ;;
    *) miniops_usage_error "Unknown option: $1" ;;
  esac
  shift
done

miniops_require_root
miniops_detect_platform >/dev/null
miniops_require_systemd
manifest=/var/lib/miniops/install-manifest
[[ -f "$manifest" && ! -L "$manifest" ]] ||
  miniops_die "Install manifest not found; refusing broad removal." 66

miniops_confirm "Remove installed MiniOps programs and units?" ||
  miniops_die "Operator declined uninstall." 75

for timer in \
  miniops-backup.timer \
  miniops-backup-freshness.timer \
  miniops-backup-check.timer \
  miniops-retention.timer \
  miniops-restore-test.timer; do
  if systemctl is-enabled "$timer" >/dev/null 2>&1; then
    miniops_run systemctl disable --now "$timer"
  fi
done

while IFS= read -r path; do
  [[ -n "$path" ]] || continue
  case "$path" in
    /usr/local/sbin/miniops-* | /usr/local/lib/miniops/* | /etc/systemd/system/miniops-*)
      if [[ -e "$path" && ! -L "$path" ]]; then
        miniops_backup_file "$path"
        miniops_run rm -f -- "$path"
      fi
      ;;
    /etc/miniops/*)
      miniops_log INFO "Preserving configuration: $path"
      ;;
    *)
      miniops_die "Unsafe manifest entry: $path" 73
      ;;
  esac
done <"$manifest"

miniops_run systemctl daemon-reload
miniops_log INFO "Programs removed; configuration, state, and backup data were preserved."
