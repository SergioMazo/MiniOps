# Runbook: Tailscale offline

1. Preserve an existing SSH session or use console access.
2. Check service and peer state:

   ```bash
   systemctl status tailscaled.service --no-pager
   tailscale status
   sudo journalctl -u tailscaled.service -n 200 --no-pager
   ```

3. Confirm DNS, default route, clock synchronization, and outbound HTTPS.
4. Do not reset enrollment or delete node identity as a first response.
5. Verify firewall rules did not block the Tailscale interface or transport.
6. Use a tested LAN fallback when available.
