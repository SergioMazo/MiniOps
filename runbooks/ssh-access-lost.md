# Runbook: SSH access lost

Use local console, out-of-band access, or a previously tested recovery path.

1. Do not close a working session.
2. Run `sshd -t`.
3. Inspect SSH service state and listening sockets.
4. Review the MiniOps drop-in and its most recent backup.
5. Verify the administrative account, home ownership, `.ssh` mode `0700`, and
   `authorized_keys` mode `0600`.
6. Check UFW and Fail2ban independently.
7. Restore the backed-up drop-in if validation fails.
8. Reload SSH only after `sshd -t` succeeds.

Never enable password authentication as an unreviewed emergency shortcut.
