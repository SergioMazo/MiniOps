# Runbook: Backup failed

## Trigger

`miniops-backup.service` is failed or no fresh success marker exists.

## Actions

1. Do not run retention or remove repository locks.
2. Inspect sanitized unit status and recent journal:

   ```bash
   sudo systemctl status miniops-backup.service --no-pager
   sudo journalctl -u miniops-backup.service -n 200 --no-pager
   ```

3. Check source mounts, free space, DNS, and private-network connectivity.
4. Validate configuration and secret-file permissions without printing values.
5. Confirm no Restic process is running.
6. Retry once manually and capture the exit code.
7. After recovery, run freshness and a representative restore test.

Escalate repeated failures or any repository integrity error.
