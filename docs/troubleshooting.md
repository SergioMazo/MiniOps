# Troubleshooting

## Preflight fails

```bash
./scripts/preflight-check.sh
cat /etc/os-release
systemctl is-system-running
```

Do not force unsupported distribution changes without a disposable test.

## Backup fails

```bash
sudo journalctl -u miniops-backup.service -n 200 --no-pager
sudo systemctl status miniops-backup.service --no-pager
```

Check configuration existence and permissions without printing contents.

## Repository lock

Confirm no MiniOps or Restic process is running before considering lock
recovery. Never delete a lock solely because it is old.

## Dashboard shows unknown

The dashboard intentionally degrades when it cannot read optional state.
Confirm that a backup completed and that sanitized files under
`/var/lib/miniops/status` exist and are mode `0644`.

## Timer did not run

```bash
systemctl list-timers --all | grep miniops
sudo journalctl -u miniops-backup.timer -u miniops-backup.service --since today
```

Persistent timers run missed jobs after boot, subject to dependencies and
random delay.
