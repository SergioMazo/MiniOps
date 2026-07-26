# ADR 0003: Treat Tailscale as optional private transport

## Status

Accepted.

## Decision

Support Tailscale as an optional private transport for administration and SFTP.
Do not make it mandatory or automatically enroll a host.

## Consequences

Authentication and tailnet policy remain operator responsibilities. Workflows
must also function on another trusted private network.
