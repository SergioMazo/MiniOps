# Configuration

MiniOps examples use simple `NAME=value` environment syntax. The loader treats
values as literal data instead of evaluating shell code, accepts only MiniOps
and Restic variables, and rejects untrusted owners or group/world-writable
files. Real configuration belongs under `/etc/miniops` and must not be
committed.

## General settings

`miniops.env` controls the administrative user, standard directories, optional
private network, color behavior, and SMART device.

## Backup settings

`backup.env` defines:

- `RESTIC_REPOSITORY`;
- `RESTIC_PASSWORD_FILE`;
- source, exclusion, and restore-test lists;
- backup tag and host label;
- cache and lock paths;
- maximum acceptable backup age;
- optional restricted SFTP command.

The password file contains only the password and must be mode `0600` or `0400`.

## Retention

`retention.env` provides daily, weekly, monthly, and yearly counts. Values are
examples. Size, change rate, compliance requirements, and recovery objectives
must determine the real policy.

`miniops-retention` is non-destructive unless called with `--apply`.

## Validation

```bash
./tests/test-config.sh
sudo miniops-backup --dry-run
sudo miniops-check-backup --dry-run
sudo miniops-retention
```
