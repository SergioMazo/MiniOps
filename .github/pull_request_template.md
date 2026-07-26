## Summary

Describe the problem and the smallest change that solves it.

## Validation

- [ ] `make test`
- [ ] `make lint`
- [ ] `make secret-scan`
- [ ] Tested first in a disposable or non-production environment

## Safety

- [ ] No credentials, private infrastructure data, or real logs
- [ ] Mutating behavior supports dry-run where practical
- [ ] Existing system files are backed up before replacement
- [ ] Rollback and remote-access risks are documented
