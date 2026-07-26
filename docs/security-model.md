# Security model

## Principles

- Fail closed when configuration or secrets are missing.
- Never print secret values or embed them in versioned files.
- Keep secrets outside visible process arguments.
- Make network and SSH changes opt-in and reversible.
- Preserve existing system files before replacement.
- Use locks for repository operations.
- Restore only into a dedicated temporary directory.
- Expose sanitized status instead of repository credentials.

## SSH

The hardening helper refuses to proceed unless the configured administrative
account already has a recognizable public key. It writes a drop-in, validates
the current and proposed configuration with `sshd -t`, and rolls back on
failure.

Keep a second session and console access open while testing.

## Restic and SFTP

Restic receives its repository and password-file location through its
environment. The password value is never placed in the environment. SFTP uses
strict host-key checking and a dedicated identity. Host fingerprints must be
verified through an independent channel.

## systemd

Services use filesystem protection, restricted address families, no-new-
privileges, private temporary directories, and bounded capabilities. Backup
sources remain read-only. State, cache, and lock directories are the only local
write locations.

## Status data

Status files contain only timestamps, snapshot counts, and aggregate sizes.
They do not contain repository addresses, credentials, source paths, or file
names from backups.
