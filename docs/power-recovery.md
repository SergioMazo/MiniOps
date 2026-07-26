# Power recovery

Power-loss recovery is hardware and firmware specific. MiniOps does not change
firmware, chipset registers, boot policy, or energy settings automatically.

## Safe procedure

1. Identify the exact vendor, model, firmware, and operating system.
2. Consult vendor documentation for "restore on AC power loss" or equivalent.
3. Record current firmware and operating-system energy settings.
4. Change only the documented setting.
5. Verify normal reboot behavior first.
6. Confirm filesystems, backup jobs, and repositories are idle.
7. Synchronize disks.
8. Perform a controlled AC-removal test with physical access available.
9. Restore power without pressing the power button.
10. Verify a new boot ID, SSH, private networking, timers, repository access,
    filesystem health, and the status dashboard.

## Evidence

Capture:

- boot IDs before and after;
- boot timestamps;
- service and timer states;
- filesystem and SMART results;
- repository integrity after the test.

An operating-system reboot does not prove recovery after complete AC loss.
