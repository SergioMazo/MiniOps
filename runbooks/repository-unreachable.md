# Runbook: Repository unreachable

## Diagnose

1. Confirm the backup node and private network are reachable.
2. Verify the SFTP host fingerprint through an independent source.
3. Test SSH in batch mode with the dedicated configuration.
4. Confirm the repository path and account permissions without listing
   unrelated server data.
5. Inspect `miniops-backup-freshness.service` and journal output.

## Safety

- Do not disable strict host-key checking.
- Do not copy private keys into command lines or tickets.
- Do not initialize a new repository over an expected existing path.
- Do not remove Restic locks while another client may be active.
