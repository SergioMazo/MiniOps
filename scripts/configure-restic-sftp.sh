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
Usage: configure-restic-sftp.sh OPTIONS

Create a restricted SSH client configuration for a Restic SFTP repository.

Required:
  --host HOST
  --user USER
  --identity-file PATH
  --known-hosts-file PATH

Optional:
  --port PORT       Default: 22
  --apply           Install the configuration
  --dry-run
  --yes
  --help

The known-hosts file must be prepared and fingerprint-verified out of band.
EOF
}

host=''
user=''
identity_file=''
known_hosts_file=''
port=22
apply=0
while (($#)); do
  case "$1" in
    --host | --user | --identity-file | --known-hosts-file | --port)
      (($# >= 2)) || miniops_usage_error "$1 requires a value"
      case "$1" in
        --host) host=$2 ;;
        --user) user=$2 ;;
        --identity-file) identity_file=$2 ;;
        --known-hosts-file) known_hosts_file=$2 ;;
        --port) port=$2 ;;
      esac
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
[[ -n "$host" && -n "$user" && -n "$identity_file" && -n "$known_hosts_file" ]] ||
  miniops_usage_error "Host, user, identity file, and known-hosts file are required"
[[ "$host" =~ ^[A-Za-z0-9.-]+$ ]] || miniops_usage_error "Invalid host"
[[ "$user" =~ ^[A-Za-z_][A-Za-z0-9_-]*$ ]] || miniops_usage_error "Invalid user"
if [[ ! "$port" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
  miniops_usage_error "Invalid port"
fi
miniops_validate_secret_file "$identity_file"
[[ -s "$known_hosts_file" && ! -L "$known_hosts_file" ]] ||
  miniops_die "Verified known-hosts file is required." 78

temporary=$(mktemp)
trap 'rm -f -- "$temporary"' EXIT
cat >"$temporary" <<EOF
Host miniops-repository
    HostName $host
    User $user
    Port $port
    IdentityFile $identity_file
    IdentitiesOnly yes
    BatchMode yes
    PasswordAuthentication no
    KbdInteractiveAuthentication no
    StrictHostKeyChecking yes
    UserKnownHostsFile /etc/miniops/ssh/known_hosts
    ServerAliveInterval 60
    ServerAliveCountMax 10
EOF

(( apply )) || {
  sed "s|IdentityFile .*|IdentityFile [configured secret path]|" "$temporary"
  miniops_log INFO "Preview only. Re-run with --apply after fingerprint verification."
  exit 0
}
miniops_confirm "Install the verified Restic SFTP client configuration?" ||
  miniops_die "Operator declined SFTP configuration." 75
miniops_run install -d -o root -g root -m 0700 /etc/miniops/ssh
miniops_install_file "$identity_file" /etc/miniops/ssh/id_ed25519 0600 root root
miniops_install_file "$known_hosts_file" /etc/miniops/ssh/known_hosts 0600 root root
sed -i 's|IdentityFile .*|IdentityFile /etc/miniops/ssh/id_ed25519|' "$temporary"
miniops_install_file "$temporary" /etc/miniops/ssh/config 0600 root root
miniops_log INFO "SFTP client configuration installed without testing write access."
