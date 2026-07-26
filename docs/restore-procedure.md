# Restore procedure

## Selective restore

List snapshots through the strict configuration loader and repository lock:

```bash
sudo bash -c '
  source /usr/local/lib/miniops/miniops-common.sh
  source /usr/local/lib/miniops/miniops-restic.sh
  miniops_prepare_restic 1
  restic snapshots
'
```

Restore into a new empty directory:

```bash
sudo install -d -o root -g root -m 0700 /var/lib/miniops/manual-restore
sudo bash -c '
  source /usr/local/lib/miniops/miniops-common.sh
  source /usr/local/lib/miniops/miniops-restic.sh
  miniops_prepare_restic 1
  restic restore latest \
    --target /var/lib/miniops/manual-restore \
    --include /path/to/required/item
'
```

Validate ownership, modes, hashes, and application-level consistency before
copying data into place.

## Automated representative test

Configure a few important, non-secret paths in
`/etc/miniops/restore-test-paths`, then run:

```bash
sudo miniops-restore-test
sudo journalctl -u miniops-restore-test.service -n 100 --no-pager
```

The test uses a private temporary directory, validates each configured path,
and removes the directory on exit.

## Full disaster recovery

1. preserve the failed system for forensics;
2. provision a clean compatible host;
3. secure network and administrative access;
4. install Restic independently;
5. restore configuration and data into staging;
6. validate application-specific consistency;
7. restore services in dependency order;
8. document gaps and rotate exposed credentials.
