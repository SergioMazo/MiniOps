# ADR 0004: Separate secrets from code

## Status

Accepted.

## Decision

Store secrets in root-owned files outside version control. Version only
fictitious examples and validate restrictive permissions before use.

## Consequences

Installation is not fully unattended until operators provision secrets through
an appropriate channel. The dashboard uses sanitized state instead of direct
secret access.
