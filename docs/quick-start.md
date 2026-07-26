# Quick start

Use a disposable Ubuntu or Debian host with console access.

## 1. Inspect and test

```bash
git clone https://github.com/YOUR_ACCOUNT/MiniOps.git
cd MiniOps
make test
./scripts/preflight-check.sh
```

## 2. Preview installation

```bash
sudo ./scripts/install.sh \
  --modules core,restic,backup,status \
  --dry-run
```

## 3. Install files without enabling timers

```bash
sudo ./scripts/install.sh \
  --modules core,restic,backup,status
```

## 4. Configure secrets

Create the Restic password without printing it:

```bash
sudo install -d -o root -g root -m 0700 /etc/miniops/secrets
sudoedit /etc/miniops/secrets/restic-password
sudo chmod 0600 /etc/miniops/secrets/restic-password
```

Edit `/etc/miniops/backup.env`, source and exclusion lists, then preview and
initialize a new repository:

```bash
sudo miniops-init-repository --dry-run
sudo miniops-init-repository --apply
```

The command exits successfully without modifying an already initialized
repository. Verify the configured endpoint and password file before `--apply`.

## 5. Run a dry backup and a real backup

```bash
sudo miniops-backup --dry-run
sudo miniops-backup
sudo miniops-backup-freshness
```

## 6. Test restore before scheduling

```bash
sudo miniops-restore-test
miniops-status
```

Only after successful manual tests:

```bash
sudo systemctl enable --now \
  miniops-backup.timer \
  miniops-backup-freshness.timer \
  miniops-backup-check.timer \
  miniops-retention.timer \
  miniops-restore-test.timer
```
