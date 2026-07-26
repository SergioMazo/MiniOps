#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/miniops-common.sh
source "$SCRIPT_DIR/lib/miniops-common.sh"

usage() {
  cat <<'EOF'
Usage: preflight-check.sh [OPTIONS]

Validate whether a host is ready for MiniOps.

Options:
  --allow-unsupported  Report an unsupported Linux distribution without failing
  --json               Emit a small JSON document
  --help               Show this help
EOF
}

json=0
while (($#)); do
  case "$1" in
    --allow-unsupported)
      MINIOPS_ALLOW_UNSUPPORTED=1
      ;;
    --json)
      json=1
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      miniops_usage_error "Unknown option: $1"
      ;;
  esac
  shift
done

miniops_require_command awk bash cp date grep install sed stat uname
platform=$(miniops_detect_platform)
miniops_require_systemd

missing_optional=()
for command_name in curl restic tailscale ufw fail2ban-client auditctl aa-status smartctl; do
  command -v "$command_name" >/dev/null 2>&1 || missing_optional+=("$command_name")
done

if (( json )); then
  optional=$(IFS=,; printf '%s' "${missing_optional[*]:-}")
  printf '{"status":"ok","platform":"%s","systemd":true,"missing_optional":"%s"}\n' \
    "$platform" "$optional"
else
  printf 'MiniOps preflight: OK\n'
  printf 'Platform: %s\n' "$platform"
  printf 'systemd: available\n'
  if ((${#missing_optional[@]})); then
    printf 'Optional commands not installed: %s\n' "$(IFS=', '; printf '%s' "${missing_optional[*]}")"
  else
    printf 'Optional commands: all detected\n'
  fi
fi

