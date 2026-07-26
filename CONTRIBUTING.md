# Contributing

Thank you for helping improve MiniOps.

## Before opening a change

1. Search existing issues.
2. Keep the scope narrow and explain the operational risk.
3. Do not include real infrastructure data, credentials, logs, or keys.
4. Add or update tests and documentation.
5. Test in a disposable environment.

## Development

```bash
git clone https://github.com/YOUR_ACCOUNT/MiniOps.git
cd MiniOps
make test
make lint
make secret-scan
```

Scripts must:

- use Bash with strict mode;
- support `--help`;
- support `--dry-run` for mutating workflows where practical;
- be idempotent;
- back up system files before modification;
- fail closed and avoid printing secrets;
- pass ShellCheck.

## Pull requests

Describe:

- the problem and intended behavior;
- systems tested;
- commands used for validation;
- security and rollback considerations;
- documentation changes.

Maintainers may request a smaller change or additional evidence before merge.
