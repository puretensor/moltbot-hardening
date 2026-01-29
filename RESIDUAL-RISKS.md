# Residual Risk Assessment

Risks we are consciously accepting after hardening, with rationale.

**Date:** 2026-01-29
**Reviewed by:** PureTensor infrastructure team

---

## Risk Matrix

| # | Risk | Severity | Likelihood | Mitigation | Acceptance Rationale |
|---|------|----------|------------|------------|---------------------|
| R1 | Local privilege escalation exposes credentials | High | Low | File permissions hardened to 0600; single-user system | No other users; physical access required beyond Tailscale |
| R2 | Tailscale compromise exposes internal services | Critical | Very Low | Tailscale ACLs; firewall rules; loopback binding | Tailscale's security model is well-audited; we use MFA |
| R3 | Supply chain attack via npm packages | High | Low | Pin versions; audit dependencies | Node.js ecosystem risk is industry-wide; we don't run untrusted code |
| R4 | ClawdBot zero-day before Moltbot migration | Medium | Low | Gateway loopback; DM pairing; no public exposure | LAN isolation limits blast radius |
| R5 | Credential theft via compromised development machine | High | Medium | Credentials encrypted at rest; rotated regularly | Development machines have full disk encryption; Tailscale MFA |
| R6 | Memory/context leakage via bot conversations | Medium | Medium | Conversation memory is local-only | No cloud sync; memory files secured with permissions |
| R7 | MCP server RCE (CVE-2025-6514) | Critical | N/A | mcp-remote not installed | Risk activates only if MCP integration is added |
| R8 | Ollama model poisoning via local API | Medium | Very Low | Ollama bound to localhost | Requires local access; models are integrity-checked |

---

## Detailed Risk Narratives

### R1: Local Privilege Escalation

**Scenario:** Malware or compromised process on the host reads credential files.

**Current state:** Single-user system (`puretensorai`). All services run as this user. No other human users. File permissions hardened to 0600.

**Residual risk:** A process running as `puretensorai` can read any file owned by that user regardless of permissions. This is inherent to the Unix permission model.

**Acceptance:** We accept this because:
- No untrusted software runs on this host
- All packages are from official repositories or verified sources
- The host is not directly internet-accessible
- Full disk encryption prevents offline attacks

### R2: Tailscale Compromise

**Scenario:** Attacker compromises Tailscale control plane or a peer node, gaining network access to internal services.

**Current state:** All services bind to loopback or Tailscale interface only. Firewall drops non-Tailscale inbound traffic.

**Acceptance:** Tailscale uses WireGuard with per-node keys. Compromise of the control plane alone doesn't decrypt traffic. We use MFA on Tailscale admin. The alternative (VPN server) has its own attack surface.

### R3: Supply Chain (npm)

**Scenario:** Compromised npm package executes malicious code during install or runtime.

**Current state:** Minimal global packages installed. No automatic updates.

**Acceptance:** This is an industry-wide risk. We mitigate by keeping packages minimal, not running `npm install` from untrusted sources, and monitoring for advisories.

### R5: Development Machine Compromise

**Scenario:** A development machine with SSH keys or Tailscale access is compromised, providing lateral movement to bot host.

**Current state:** Development machines use full disk encryption, screen locks, and Tailscale MFA.

**Acceptance:** This is the most likely attack vector. We mitigate with:
- SSH key passphrases
- Tailscale device approval
- Regular credential rotation
- Monitoring for anomalous access patterns

### R7: CVE-2025-6514 (MCP RCE)

**Scenario:** Malicious MCP server achieves remote code execution on the bot host.

**Current state:** `mcp-remote` is not installed. No MCP servers are configured.

**Acceptance:** Risk is currently zero. If MCP integration is added:
- Install mcp-remote 0.1.16+ only
- Audit all MCP server sources
- Run MCP servers in sandboxed containers
- Re-assess this risk

---

## Review Schedule

This assessment should be reviewed:
- After any infrastructure change
- After adding new integrations (MCP, new APIs, new channels)
- After migrating from ClawdBot to Moltbot
- Quarterly at minimum

---

## Sign-off

| Role | Name | Date |
|------|------|------|
| Infrastructure | PureTensor ops | 2026-01-29 |
