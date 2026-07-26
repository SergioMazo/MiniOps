# Architecture

MiniOps separates policy, execution, secrets, state, and scheduling.

```text
Operator configuration       Secret files
/etc/miniops/*.env           /etc/miniops/secrets/*
          │                            │
          └────────────┬───────────────┘
                       ▼
               MiniOps Bash tools
                       │
             lock + Restic + SSH
                       │
                       ▼
            encrypted repository
                       │
        ┌──────────────┼──────────────┐
        ▼              ▼              ▼
   integrity       retention      restore test
```

## Trust boundaries

- Configuration is root-owned and may identify repository locations.
- Secret files are separate, mode `0600` or `0400`, and never versioned.
- The Restic repository is treated as untrusted storage; encryption and
  authentication happen on the protected host.
- Sanitized status markers contain timestamps, counts, and sizes only.
- The terminal dashboard reads sanitized markers and system state without
  reading repository credentials.

## Runtime paths

| Purpose | Default |
| --- | --- |
| Configuration | `/etc/miniops` |
| Secrets | `/etc/miniops/secrets` |
| Executables | `/usr/local/sbin` |
| Shared library | `/usr/local/lib/miniops` |
| State | `/var/lib/miniops` |
| Cache | `/var/cache/miniops` |
| Locks | `/run/lock` |
| Units | `/etc/systemd/system` |

## Failure behavior

Each workflow fails non-zero, writes to journald, and triggers
`miniops-failure@.service`. MiniOps does not silently convert failed backups or
checks into success. External alert delivery is intentionally left as a
deployment-specific integration.
