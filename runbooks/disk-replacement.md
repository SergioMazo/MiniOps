# Runbook: Disk replacement

1. Confirm independent backups and a recent restore test.
2. Record partitioning, filesystem, mount options, boot mode, and encryption.
3. Shut down gracefully and label the removed device.
4. Install and test the replacement disk.
5. Recreate storage from documented configuration, not from memory.
6. Restore into staging and validate hashes and application consistency.
7. Re-enable timers only after mounts and repository access are correct.
8. Run SMART tests and a new representative restore test.
9. Retain the old disk securely until acceptance criteria are met.
