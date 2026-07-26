# Tailscale SFTP backup example

This pattern keeps SFTP on a private Tailscale address. Tailscale enrollment,
ACLs, grants, device approval, and key rotation remain operator responsibilities.

```text
protected host → Tailscale → backup-node SFTP → encrypted Restic repository
```

Use a fictitious address such as `100.x.x.x` in documentation. Configure the
real address only in root-owned local configuration.
