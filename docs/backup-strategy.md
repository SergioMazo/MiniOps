# Backup strategy

## Recovery objectives

Define recovery point and recovery time objectives before selecting schedules.
The included timers are examples:

- daily backup;
- daily freshness check;
- weekly rotating data check;
- weekly retention;
- monthly restore test.

## Data flow

1. systemd starts `miniops-backup`;
2. a host-local lock prevents overlapping repository operations;
3. Restic reads configured source and exclusion lists;
4. data is encrypted before it reaches the repository;
5. a success marker and sanitized aggregate status are written locally;
6. freshness, integrity, retention, and restore workflows run independently.

## Initial and incremental backups

Restic automatically deduplicates subsequent backups. The first successful
snapshot can be large and should be monitored. An initial backup is not enough:
run a check and restore test before relying on it.

Initialize a new repository with `miniops-init-repository --apply`, then create
the first snapshot with `miniops-backup`. Both commands use the same
configuration validation and repository lock as scheduled jobs.

## Repository placement

Use storage with independent failure characteristics. A private SFTP endpoint
over a trusted network or Tailscale is a reasonable small-deployment option.
Consider an additional offline or off-site copy for important data.

## Retention

Start with the example policy, measure growth, then adjust. Always run
`miniops-retention` without `--apply` first.
