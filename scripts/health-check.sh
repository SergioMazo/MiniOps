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
Usage: health-check.sh [--help]

Exit 0 for healthy, 1 for critical, and 2 for warnings.
EOF
}
if (($#)); then
  [[ "$1" == --help && $# == 1 ]] || miniops_usage_error "Unknown option"
  usage
  exit 0
fi

miniops_detect_platform >/dev/null
general_config=${MINIOPS_GENERAL_CONFIG:-/etc/miniops/miniops.env}
[[ -f "$general_config" ]] && miniops_load_env "$general_config"

status=0
record() {
  local component=$1 level=$2 detail=$3
  printf '%s component=%s status=%s detail=%s\n' "$(miniops_now)" "$component" "$level" "$detail"
  case "$level" in
    CRIT) status=1 ;;
    WARN) (( status == 0 )) && status=2 ;;
  esac
}

used=$(df -P / | awk 'NR == 2 {gsub(/%/, "", $5); print $5}')
if (( used >= 95 )); then
  record disk CRIT "root=${used}%"
elif (( used >= 85 )); then
  record disk WARN "root=${used}%"
else
  record disk OK "root=${used}%"
fi

if command -v systemctl >/dev/null 2>&1; then
  if systemctl is-active --quiet ssh.service || systemctl is-active --quiet sshd.service; then
    record ssh OK active
  else
    record ssh CRIT inactive
  fi
else
  record systemd WARN unavailable
fi

if command -v tailscale >/dev/null 2>&1; then
  if tailscale status --json 2>/dev/null | grep -q '"BackendState"[[:space:]]*:[[:space:]]*"Running"'; then
    record tailscale OK running
  else
    record tailscale WARN offline
  fi
else
  record tailscale SKIP not-installed
fi

marker=$MINIOPS_STATE_DIR/status/last-backup
if [[ -e "$marker" ]]; then
  age=$(($(date +%s) - $(stat -c '%Y' "$marker")))
  if (( age > ${MINIOPS_MAX_BACKUP_AGE_SECONDS:-108000} )); then
    record backup WARN "stale=${age}s"
  else
    record backup OK "age=${age}s"
  fi
else
  record backup WARN no-success-marker
fi

exit "$status"
