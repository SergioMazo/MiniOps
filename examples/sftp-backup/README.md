# SFTP backup example

Use a dedicated SFTP account and repository directory on `backup-node`.
Restrict the account server-side and verify its SSH host fingerprint out of
band.

```text
RESTIC_REPOSITORY=sftp:backupuser@backup-node:/path/to/repository
MINIOPS_SFTP_COMMAND=ssh -F /etc/miniops/ssh/config
```

Never disable strict host-key checking to make initial setup easier.
