# Threat model

## Assets

- administrative SSH access;
- source data and restored data;
- Restic password and SFTP identity;
- backup repository availability and integrity;
- host configuration and audit history.

## Considered threats

- accidental publication of credentials or infrastructure identifiers;
- remote SSH password attacks;
- firewall lockout;
- repository theft or untrusted storage;
- overlapping backup and retention jobs;
- malicious or accidental restore overwrite;
- stale backups that appear healthy;
- disk exhaustion;
- tampered SFTP host keys;
- overly broad systemd privileges.

## Controls

- key-only SSH helper with precondition and rollback;
- UFW and Fail2ban as explicit optional modules;
- Restic client-side encryption;
- strict SFTP host-key checking;
- locks and independent freshness checks;
- isolated restore tests;
- sanitized status files;
- secret scanning and minimal CI permissions.

## Out of scope

- kernel or firmware compromise;
- a fully compromised root account;
- physical theft without disk encryption;
- availability guarantees for remote storage or private networking;
- application-consistent database backup without application-specific hooks.
