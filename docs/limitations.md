# Limitations

- The project is experimental and not certified for regulated environments.
- Only Ubuntu CI is planned for the first release; Debian remains an initial
  target that requires more integration evidence.
- AppArmor profiles differ between distributions; no custom profile is shipped.
- UFW is not a replacement for upstream network policy.
- Backup source consistency depends on the application. Live databases may
  require hooks or native dump tools.
- Status markers are local evidence, not a remote monitoring system.
- No external alert transport is configured by default.
- Power recovery and SMART device discovery are hardware specific.
- SFTP server-side isolation is documented through examples, not automatically
  imposed on a remote host.
- The installer does not manage operating-system upgrades.
