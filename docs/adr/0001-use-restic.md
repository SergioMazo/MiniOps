# ADR 0001: Use Restic for encrypted backups

## Status

Accepted.

## Decision

Use Restic because it provides client-side encryption, deduplication, snapshots,
integrity checks, retention primitives, and SFTP support in one maintained tool.

## Consequences

Operators must preserve the repository password independently and test restores.
Repository availability and application consistency remain separate concerns.
