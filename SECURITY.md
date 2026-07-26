# Security Policy

## Supported versions

Security fixes are provided for the latest tagged release and the `main`
branch while the project remains experimental.

## Reporting a vulnerability

Do not open a public issue for a vulnerability that could expose credentials,
cause remote lockout, weaken host access, or permit command execution.

Use GitHub's private vulnerability reporting feature for this repository.
Include the affected version, a minimal reproduction, impact, and any safe
mitigation. Do not include live credentials or private infrastructure data.

Maintainers will acknowledge a complete report when practical, investigate it,
and coordinate a fix and disclosure. No response-time guarantee is made.

## Scope

Security-sensitive areas include:

- command and configuration injection;
- unsafe privilege boundaries;
- secret disclosure;
- SSH and firewall lockout;
- Restic repository handling;
- restore path traversal or overwrite;
- systemd sandbox escapes.
