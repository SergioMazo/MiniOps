<div align="center">
  <img src="docs/assets/miniops-logo.svg" alt="MiniOps logo" width="420">
</div>

# MiniOps

Resilient infrastructure for small Linux servers and homelabs.

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Language: Bash](https://img.shields.io/badge/language-Bash-4EAA25.svg)](https://www.gnu.org/software/bash/)
[![Project status: experimental](https://img.shields.io/badge/status-experimental-orange.svg)](ROADMAP.md)

MiniOps is a security-conscious Bash toolkit for turning a small Linux server,
mini PC, reused computer, or homelab node into maintainable infrastructure. It
combines conservative host hardening, encrypted Restic backups, systemd timers,
restore testing, operational checks, and plain-language runbooks.

> [!WARNING]
> MiniOps is experimental. Test every change in a disposable or non-production
> environment first, keep an independent recovery path, and review generated
> configuration before applying it.

## Why MiniOps?

Small servers often start with a few manual commands and become critical
without acquiring repeatable operations. MiniOps provides auditable building
blocks while keeping secrets outside version control and requiring explicit
confirmation for sensitive changes.

## Features

- Preflight checks for supported Linux and systemd environments
- SSH key-only hardening with lockout protection and rollback
- Optional UFW, Fail2ban, auditd, AppArmor, and Tailscale integration
- Encrypted Restic backups to local or SFTP repositories
- Locking, freshness checks, retention, and integrity verification
- Isolated automated restore tests that never overwrite source data
- Hardened systemd services and persistent timers
- A safe, partially degradable terminal dashboard
- Reboot and power-recovery validation procedures
- Incident-oriented operational runbooks
- Tests, ShellCheck, Markdownlint, and secret scanning in CI

## Architecture

```text
┌──────────────────────┐
│ Protected Linux host │
│ files + databases    │
└──────────┬───────────┘
           │ systemd timer
           ▼
┌──────────────────────┐
│ MiniOps backup       │
│ lock + Restic        │
└──────────┬───────────┘
           │ private network or Tailscale
           ▼
┌──────────────────────┐
│ SFTP backup node     │
│ encrypted repository │
└──────────┬───────────┘
           │
           ├── integrity checks
           ├── retention
           └── isolated restore tests
```

## Quick start

```bash
git clone https://github.com/YOUR_ACCOUNT/MiniOps.git
cd MiniOps
make test
sudo ./scripts/install.sh --dry-run
```

Review the example configuration:

```bash
cp config/miniops.env.example /tmp/miniops.env
cp config/backup.env.example /tmp/backup.env
```

Run preflight checks:

```bash
./scripts/preflight-check.sh
```

Preview the core, backup, and status modules:

```bash
sudo ./scripts/install.sh \
  --modules core,backup,status \
  --dry-run
```

See [Quick start](docs/quick-start.md) before applying any change.

## Manual installation

The installer places configuration under `/etc/miniops`, executable tools
under `/usr/local/sbin`, state under `/var/lib/miniops`, and systemd units
under `/etc/systemd/system`.

```bash
sudo ./scripts/install.sh --help
sudo ./scripts/install.sh --modules core,backup,status
```

Sensitive modules such as SSH and UFW require explicit selection and
confirmation. The installer will not harden SSH unless it verifies at least one
public key for the configured administrative account.

Detailed instructions are in [Installation](docs/installation.md).

## Configuration example

```bash
MINIOPS_ADMIN_USER=adminuser
MINIOPS_TIMEZONE=Etc/UTC
MINIOPS_STATE_DIR=/var/lib/miniops
MINIOPS_LOG_DIR=/var/log/miniops

RESTIC_REPOSITORY=sftp:backupuser@100.x.x.x:/path/to/repository
RESTIC_PASSWORD_FILE=/etc/miniops/secrets/restic-password
MINIOPS_BACKUP_SOURCES_FILE=/etc/miniops/backup-sources
MINIOPS_BACKUP_EXCLUDES_FILE=/etc/miniops/backup-excludes
```

Never commit the real files. See [Configuration](docs/configuration.md) and
[Security model](docs/security-model.md).

## Terminal dashboard

After installation:

```bash
miniops-status
```

Example with fictitious data:

```text
MiniOps status — miniops-node
Time:               2030-01-15 09:30:00 UTC
Uptime:             12 days, 4 hours
Load / CPU:         0.18 0.11 0.08 / 7%
Memory:             1.2 GiB / 8.0 GiB
Disk /:             18 GiB / 120 GiB (15%)
Tailscale:          Running (100.x.x.x)
SSH / UFW:          active / active
Fail2ban:           active
Backup timer:       active; next 2030-01-16 02:00 UTC
Last backup:        2030-01-15 02:04 UTC
Snapshots:          14
Repository size:    8.4 GiB
Last check:         2030-01-12 04:09 UTC
Last restore test:  2030-01-01 06:34 UTC
SMART:              PASSED
Warnings:           none
```

The dashboard does not print secret values, password-file paths, SSH
credentials, or repository credentials. Components that are unavailable are
reported as `not installed`, `permission required`, or `unknown`.

## Security model

MiniOps follows these defaults:

- secrets are stored outside the repository with mode `0600`;
- SSH hardening uses a drop-in, preserves the old configuration, and validates
  with `sshd -t` before reload;
- network changes are opt-in and dry-run capable;
- backup processes use locks and avoid secrets in arguments and logs;
- restore tests use temporary directories and clean them on exit;
- systemd units use least privilege and filesystem protections where practical;
- examples are intentionally fictitious.

Read [Security model](docs/security-model.md) and
[Threat model](docs/threat-model.md) before deployment.

## Supported systems

Initial targets:

- Ubuntu LTS releases using systemd
- Current stable Debian releases using systemd

CI exercises generic Bash behavior on Ubuntu. Hardware-specific power
recovery, AppArmor policy compatibility, storage behavior, and complete
distribution integration require validation on the target host. Other Linux
distributions are currently untested.

Requirements:

- Bash 4.4 or newer
- systemd
- OpenSSH
- coreutils, util-linux, and curl
- Restic for backups
- optional: Tailscale, UFW, Fail2ban, auditd, AppArmor, smartmontools

## Warnings and limitations

- MiniOps does not configure firmware or power-recovery registers.
- UFW and SSH mistakes can cause remote lockout; retain console access.
- A successful backup is not proof of recoverability; keep restore tests.
- Restic repository passwords must be backed up separately.
- SFTP server hardening varies by distribution and must be reviewed.
- The project does not replace monitoring, UPS hardware, or off-site strategy.

See [Limitations](docs/limitations.md).

## Roadmap

Version `0.1.0` focuses on conservative Bash automation, encrypted backups,
terminal status, documentation, and CI safety checks. See [Roadmap](ROADMAP.md)
for planned improvements.

## Contributing and support

Bug reports, documentation improvements, tests, and narrowly scoped features
are welcome. Read [Contributing](CONTRIBUTING.md),
[Code of Conduct](CODE_OF_CONDUCT.md), and [Support](SUPPORT.md).

Security issues must follow [Security policy](SECURITY.md).

## License

MiniOps is available under the [MIT License](LICENSE).
