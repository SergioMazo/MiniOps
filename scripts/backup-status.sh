#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ -r "$SCRIPT_DIR/lib/miniops-common.sh" ]]; then
  # shellcheck source=lib/miniops-common.sh
  source "$SCRIPT_DIR/lib/miniops-common.sh"
elif [[ -r /usr/local/lib/miniops/miniops-common.sh ]]; then
  # shellcheck source=/dev/null
  source /usr/local/lib/miniops/miniops-common.sh
fi

usage() {
  cat <<'EOF'
Usage: miniops-status [--no-color] [--help]

Display sanitized, read-only operational status. Missing optional components
are reported without causing the dashboard to fail.
EOF
}

color_mode=${MINIOPS_COLOR:-auto}
while (($#)); do
  case "$1" in
    --no-color) color_mode=never ;;
    --help)
      usage
      exit 0
      ;;
    *) miniops_usage_error "Unknown option: $1" ;;
  esac
  shift
done

miniops_detect_platform >/dev/null
general_config=${MINIOPS_GENERAL_CONFIG:-/etc/miniops/miniops.env}
if [[ -f "$general_config" && ! -L "$general_config" ]]; then
  miniops_load_env "$general_config"
fi

if [[ "$color_mode" == always || ("$color_mode" == auto && -t 1) ]]; then
  green=$'\033[32m'
  yellow=$'\033[33m'
  red=$'\033[31m'
  bold=$'\033[1m'
  reset=$'\033[0m'
else
  green=''
  yellow=''
  red=''
  bold=''
  reset=''
fi

warnings=()
line() {
  printf '%-21s %s\n' "$1:" "$2"
}

service_state() {
  local unit=$1
  if ! command -v systemctl >/dev/null 2>&1; then
    printf 'not installed'
  elif systemctl is-active --quiet "$unit" 2>/dev/null; then
    printf '%sactive%s' "$green" "$reset"
  elif systemctl cat "$unit" >/dev/null 2>&1; then
    printf '%sinactive%s' "$red" "$reset"
  else
    printf 'not installed'
  fi
}

format_marker() {
  local marker=$1
  if [[ -r "$marker" ]]; then
    sed -n '1p' "$marker"
  else
    printf 'unknown'
  fi
}

printf '%sMiniOps status — %s%s\n' "$bold" "$(hostname 2>/dev/null || printf unknown)" "$reset"
line Time "$(date '+%Y-%m-%d %H:%M:%S %Z')"
if uptime -p >/dev/null 2>&1; then
  line Uptime "$(uptime -p | sed 's/^up //')"
else
  line Uptime "$(uptime 2>/dev/null || printf unknown)"
fi

load=unknown
[[ -r /proc/loadavg ]] && load=$(awk '{print $1, $2, $3}' /proc/loadavg)
cpu=unknown
if [[ -r /proc/stat ]]; then
  read -r _ u1 n1 s1 i1 w1 q1 r1 t1 _ </proc/stat
  total1=$((u1 + n1 + s1 + i1 + w1 + q1 + r1 + t1))
  idle1=$((i1 + w1))
  sleep 0.1
  read -r _ u2 n2 s2 i2 w2 q2 r2 t2 _ </proc/stat
  total2=$((u2 + n2 + s2 + i2 + w2 + q2 + r2 + t2))
  idle2=$((i2 + w2))
  delta_total=$((total2 - total1))
  delta_idle=$((idle2 - idle1))
  (( delta_total > 0 )) && cpu="$((100 * (delta_total - delta_idle) / delta_total))%"
fi
line "Load / CPU" "$load / $cpu"

memory=unknown
if command -v free >/dev/null 2>&1; then
  memory=$(free -h | awk '/^Mem:/ {print $3 " / " $2}')
fi
line Memory "$memory"

read -r disk_size disk_used disk_free disk_pct < <(
  df -hP / | awk 'NR == 2 {print $2, $3, $4, $5}'
)
line "Disk /" "$disk_used / $disk_size; $disk_free free ($disk_pct)"
disk_number=${disk_pct%%%}
(( disk_number >= 85 )) && warnings+=("root filesystem usage is ${disk_pct}")

tailscale_state='not installed'
tailscale_ip='-'
if command -v tailscale >/dev/null 2>&1; then
  tailscale_json=$(tailscale status --json 2>/dev/null || true)
  if [[ -n "$tailscale_json" ]] && command -v jq >/dev/null 2>&1; then
    tailscale_state=$(jq -r '.BackendState // "unknown"' <<<"$tailscale_json" 2>/dev/null || printf unknown)
  else
    tailscale_state=unknown
  fi
  tailscale_ip=$(tailscale ip -4 2>/dev/null || printf -- '-')
  [[ "$tailscale_state" == Running ]] || warnings+=("Tailscale is $tailscale_state")
fi
line Tailscale "$tailscale_state ($tailscale_ip)"

ssh_state=$(service_state ssh.service)
[[ "$ssh_state" != 'not installed' ]] || ssh_state=$(service_state sshd.service)
line SSH "$ssh_state"
line UFW "$(service_state ufw.service)"
line Fail2ban "$(service_state fail2ban.service)"

timer_summary=()
for timer in \
  miniops-backup.timer \
  miniops-backup-freshness.timer \
  miniops-backup-check.timer \
  miniops-retention.timer \
  miniops-restore-test.timer; do
  if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet "$timer" 2>/dev/null; then
    timer_summary+=("${timer#miniops-}:active")
  elif command -v systemctl >/dev/null 2>&1 && systemctl cat "$timer" >/dev/null 2>&1; then
    timer_summary+=("${timer#miniops-}:inactive")
    warnings+=("$timer is inactive")
  fi
done
if ((${#timer_summary[@]})); then
  line Timers "$(IFS=', '; printf '%s' "${timer_summary[*]}")"
else
  line Timers "not installed"
fi

next_backup=unknown
if command -v systemctl >/dev/null 2>&1; then
  next_backup=$(systemctl show miniops-backup.timer -p NextElapseUSecRealtime --value 2>/dev/null || true)
  next_backup=${next_backup:-unknown}
fi

status_file=$MINIOPS_STATE_DIR/status/backup.env
LAST_BACKUP=unknown SNAPSHOT_COUNT=unknown REPOSITORY_SIZE=unknown
if [[ -r "$status_file" && ! -L "$status_file" ]]; then
  # This root-written file contains sanitized values only.
  # shellcheck disable=SC1090
  source "$status_file"
fi
line "Backup timer next" "$next_backup"
line "Last backup" "$LAST_BACKUP"
line Snapshots "$SNAPSHOT_COUNT"
line "Repository size" "$REPOSITORY_SIZE"
line "Last check" "$(format_marker "$MINIOPS_STATE_DIR/status/last-check")"
line "Last restore test" "$(format_marker "$MINIOPS_STATE_DIR/status/last-restore-test")"

smart=not-configured
if command -v smartctl >/dev/null 2>&1 && [[ -n ${MINIOPS_SMART_DEVICE:-} ]]; then
  smart=$(
    smartctl -H "$MINIOPS_SMART_DEVICE" 2>/dev/null |
      awk -F: '/overall-health|SMART Health Status/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}'
  )
  smart=${smart:-permission-required}
  [[ "$smart" == *PASSED* || "$smart" == OK ]] || warnings+=("SMART status is $smart")
fi
line SMART "$smart"

if ((${#warnings[@]})); then
  printf '%sWarnings:%s\n' "$yellow" "$reset"
  for warning in "${warnings[@]}"; do printf '  - %s\n' "$warning"; done
else
  printf '%sWarnings:%s none\n' "$green" "$reset"
fi
