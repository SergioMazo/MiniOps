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
Usage: harden-ssh.sh [OPTIONS]

Install a reversible OpenSSH key-only hardening drop-in.

Options:
  --admin-user USER  Account that must already have a public key
  --apply            Install, validate, and reload the SSH service
  --dry-run          Print actions without modifying the host
  --yes              Accept confirmation
  --help             Show this help
EOF
}

admin_user=
apply=0
while (($#)); do
  case "$1" in
    --admin-user)
      (($# >= 2)) || miniops_usage_error "--admin-user requires a value"
      admin_user=$2
      shift
      ;;
    --apply) apply=1 ;;
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
miniops_require_command getent sshd systemctl

general_config=${MINIOPS_GENERAL_CONFIG:-/etc/miniops/miniops.env}
if [[ -f "$general_config" ]]; then
  miniops_load_env "$general_config"
fi
admin_user=${admin_user:-${MINIOPS_ADMIN_USER:-}}
[[ -n "$admin_user" ]] || miniops_die "Configure MINIOPS_ADMIN_USER first." 78

passwd_record=$(getent passwd "$admin_user") ||
  miniops_die "Administrative user does not exist: $admin_user" 67
admin_home=$(awk -F: '{print $6}' <<<"$passwd_record")
admin_uid=$(awk -F: '{print $3}' <<<"$passwd_record")
authorized_keys="$admin_home/.ssh/authorized_keys"
[[ -f "$authorized_keys" && ! -L "$authorized_keys" ]] ||
  miniops_die "No safe authorized_keys file for $admin_user." 78
[[ "$(miniops_file_owner_id "$admin_home/.ssh")" == "$admin_uid" &&
  "$(miniops_file_owner_id "$authorized_keys")" == "$admin_uid" ]] ||
  miniops_die "SSH key files must be owned by $admin_user." 78
[[ "$(miniops_file_mode "$admin_home/.ssh")" == 700 &&
  "$(miniops_file_mode "$authorized_keys")" == 600 ]] ||
  miniops_die "Require mode 0700 on .ssh and 0600 on authorized_keys." 78
grep -Eq '^[[:space:]]*(ssh-(ed25519|rsa)|ecdsa-sha2-nistp(256|384|521))[[:space:]]+[A-Za-z0-9+/=]+' \
  "$authorized_keys" ||
  miniops_die "No public key found for $admin_user; refusing SSH hardening." 78

target=/etc/ssh/sshd_config.d/90-miniops-hardening.conf
temporary=$(mktemp)
trap 'rm -f -- "$temporary"' EXIT
cat >"$temporary" <<'EOF'
# Managed by MiniOps. Review before applying.
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
AuthenticationMethods publickey
PermitEmptyPasswords no
X11Forwarding no
AllowTcpForwarding no
EOF
chmod 0600 "$temporary"

printf 'Proposed SSH hardening for administrative user %s:\n' "$admin_user"
sed -n '1,120p' "$temporary"
(( apply )) || {
  miniops_log INFO "Preview only. Re-run with --apply after testing console access."
  exit 0
}

miniops_confirm "Install key-only SSH hardening and reload sshd?" ||
  miniops_die "Operator declined SSH hardening." 75

sshd -t
backup=
if [[ -e "$target" ]]; then
  [[ -f "$target" && ! -L "$target" ]] ||
    miniops_die "Unsafe SSH drop-in target." 73
  backup="${target}.miniops-backup-$(date -u +%Y%m%dT%H%M%SZ)"
  miniops_run cp -a -- "$target" "$backup"
fi

rollback() {
  local rc=$?
  trap - ERR
  if (( ! MINIOPS_DRY_RUN )); then
    if [[ -n "$backup" ]]; then
      cp -a -- "$backup" "$target"
    else
      rm -f -- "$target"
    fi
    sshd -t || true
  fi
  miniops_log ERROR "SSH hardening failed and was rolled back."
  exit "$rc"
}
trap rollback ERR

miniops_run install -o root -g root -m 0644 "$temporary" "$target"
if (( ! MINIOPS_DRY_RUN )); then
  sshd -t
  if systemctl cat ssh.service >/dev/null 2>&1; then
    systemctl reload ssh.service
  else
    systemctl reload sshd.service
  fi
fi
trap - ERR
miniops_log INFO "SSH key-only hardening validated and applied."
