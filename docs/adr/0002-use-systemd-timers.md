# ADR 0002: Use systemd timers

## Status

Accepted.

## Decision

Use systemd services and timers for scheduling, persistence across reboot,
resource controls, failure status, and journald integration.

## Consequences

MiniOps requires systemd and does not initially support cron-only systems.
