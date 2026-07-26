# Runbook: Power-failure recovery

1. Confirm the host returned without manual intervention.
2. Record the new boot ID and boot time.
3. Check filesystem and kernel errors.
4. Verify SSH, private networking, firewall, and time synchronization.
5. Confirm all MiniOps timers are active.
6. Confirm no stale Restic lock remains.
7. Open the repository and list snapshots.
8. Run a full integrity check when an abrupt outage may have interrupted a
   repository write.
9. Run `miniops-status`.
10. Document any component that required manual action.

See [Power recovery](../docs/power-recovery.md) before performing a live test.
