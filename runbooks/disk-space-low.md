# Runbook: Disk space low

1. Record filesystem and inode usage:

   ```bash
   df -hT
   df -i
   ```

2. Identify large top-level consumers without crossing unrelated mounts:

   ```bash
   sudo du -x -h -d 1 /var | sort -h
   ```

3. Check journal retention, package caches, temporary files, and repository
   growth.
4. Do not delete backup snapshots outside Restic.
5. Evaluate retention with `miniops-retention` before using `--apply`.
6. Add capacity if retention changes would violate recovery objectives.
