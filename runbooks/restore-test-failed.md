# Runbook: Restore test failed

1. Preserve the journal and failure timestamp.
2. Determine whether restore, path validation, or cleanup failed.
3. Run an integrity check before another restore attempt.
4. Confirm the configured representative paths exist in the latest snapshot.
5. Restore into a new private staging directory.
6. Validate file type, non-empty content, ownership, and application-specific
   consistency.
7. Do not copy unvalidated files into production.

Treat a failed restore test as a backup incident even when backup creation is
still succeeding.
