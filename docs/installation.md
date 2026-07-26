# Installation

## Requirements

- Linux with systemd
- Bash 4.4 or newer
- OpenSSH and standard GNU userland
- root access for installation
- console or independent recovery access before SSH or firewall changes

Optional components are checked by `preflight-check.sh`.

## Installer behavior

The installer:

1. detects the distribution and systemd;
2. validates dependencies and privileges;
3. prints selected modules;
4. creates standard directories with restrictive permissions;
5. preserves existing configuration files;
6. backs up replaced programs and systemd units;
7. installs a manifest for bounded uninstall;
8. reloads systemd;
9. enables timers only with explicit confirmation.

## Modules

```text
core ssh ufw fail2ban auditd apparmor restic backup status
```

Install only core and status:

```bash
sudo ./scripts/install.sh --modules core,status
```

Preview a broader deployment:

```bash
sudo ./scripts/install.sh \
  --modules core,ssh,ufw,fail2ban,auditd,restic,backup,status \
  --apply \
  --dry-run
```

Do not combine `--yes` with SSH or UFW changes until dry-run output has been
reviewed and console access has been tested.

## Uninstall

```bash
sudo miniops-uninstall --dry-run
sudo miniops-uninstall
```

Uninstall preserves configuration, secrets, state, repositories, and backup
data. It removes only bounded paths recorded in the install manifest.
