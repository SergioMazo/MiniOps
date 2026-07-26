# Local backup example

This example is suitable only for learning and does not protect against loss of
the host. Use a separate mounted filesystem in a disposable environment.

```bash
export RESTIC_REPOSITORY=/mnt/backup/restic
export RESTIC_PASSWORD_FILE=/etc/miniops/secrets/restic-password
sudo restic init
sudo miniops-backup --dry-run
```

Copy `backup.env.example` to a root-owned location and replace all fictitious
values before use.
