# Security Audit Findings

**Date:** 2026-01-29
**Target:** Production Moltbot (ClawdBot) deployment
**Deployment:** LAN-secured infrastructure, Tailscale mesh, no public exposure
**Auditor:** PureTensor infrastructure team

---

## Executive Summary

Audit of a production ClawdBot deployment revealed **no critical active exploits**, but identified several hardening opportunities. The bot has not yet migrated to Moltbot, meaning some Moltbot-specific security features (improved credential storage, sandboxed MCP execution) are not yet available. Credential file permissions are the most actionable finding.

## Environment

| Component | Status | Notes |
|-----------|--------|-------|
| Bot platform | ClawdBot (pre-Moltbot migration) | Config at `~/.clawdbot/` on deployment host |
| Node.js | v24.13.0 | Exceeds 22.12.0+ requirement |
| mcp-remote | Not installed | Not currently using MCP servers — CVE-2025-6514 not applicable yet |
| Gateway binding | Needs verification | Check `clawdbot.json` for `gateway.bind` |
| DM policy | Needs verification | Check for `dmPolicy` setting |
| Network | Tailscale mesh only | No public ports exposed |

## Findings

### CRITICAL — Credential File Permissions

Multiple credential files have overly permissive permissions (group/world readable). While mitigated by single-user system and LAN isolation, these would be the first targets of any malware achieving local access.

#### Google Drive OAuth Tokens (AFFECTED)
```
~/.config/puretensor/gdrive_tokens/token_cto.json     0644 → should be 0600
~/.config/puretensor/gdrive_tokens/token_personal.json 0644 → should be 0600
~/.config/puretensor/client_secret.json                0644 → should be 0600
```

#### HuggingFace API Tokens (AFFECTED)
```
~/.cache/huggingface/token          0664 → should be 0600
~/.cache/huggingface/stored_tokens  0664 → should be 0600
```

#### Application Environment Files (AFFECTED)
```
~/projects/whatsapp-translator/.env  0664 → should be 0600
/opt/bretalon_report_bot.env         0644 → should be 0600
```

#### Downloaded OAuth Secrets (AFFECTED)
```
~/Downloads/client_secret_568320298248-*.json  0644 → should be 0600 or removed
```

### GOOD — Properly Secured Credentials

These files already have correct permissions:

| Location | Permissions | Status |
|----------|-------------|--------|
| `~/.ssh/id_ed25519*` (private keys) | 0600 | OK |
| `~/.config/gcloud/credentials.db` | 0600 | OK |
| `~/.config/gcloud/access_tokens.db` | 0600 | OK |
| `~/.config/gogcli/keyring/*` | 0600 | OK |
| `~/.config/gh/hosts.yml` | 0600 | OK |
| `~/.config/Bitwarden CLI/data.json` | 0600 | OK |
| `~/.claude/.credentials.json` | 0600 | OK |
| `~/github-deploy-key.json` | 0600 | OK |

### MEDIUM — ClawdBot Configuration Not Yet Audited

The `~/.clawdbot/` directory on the deployment host (mon1) contains:
- `clawdbot.json` — Main configuration (gateway, DM policy, bindings)
- `agents/` — Agent definitions
- `credentials/` — Bot credentials (Telegram, Discord, etc.)
- `memory/` — Conversation memory/context
- `telegram/` — Telegram-specific config
- `subagents/` — Sub-agent definitions

**Action required:** SSH to mon1 and audit each file for:
- Gateway bind address (must be loopback)
- DM policy (must be "pairing")
- Credential storage method (plaintext vs encrypted)
- Installed skills/agents (remove untrusted)

### LOW — No MCP Remote Installed

`mcp-remote` is not installed globally or locally. This means:
- CVE-2025-6514 (RCE via MCP servers) is **not currently exploitable**
- If MCP integration is added later, ensure version 0.1.16+

### INFO — Network Posture

| Check | Result |
|-------|--------|
| Public ports | None (Tailscale only) |
| Tailscale active | Yes, ~20+ nodes |
| SSH access | Key-based only |
| Ollama (11434) | Bound to localhost |
| Web services (9000, 8100) | Internal only |

## Recommendations

### Immediate (P0)
1. Fix credential file permissions — see `scripts/harden.sh`
2. Audit `~/.clawdbot/` on mon1 — verify gateway.bind and dmPolicy
3. Remove downloaded OAuth client secrets from `~/Downloads/`

### Short-term (P1)
4. Migrate to Moltbot when stable — improved security model
5. Implement credential encryption or migrate to secret manager
6. Rotate all credentials after hardening

### Medium-term (P2)
7. Add file integrity monitoring on credential files
8. Add API call logging for audit trail
9. Set up anomaly alerting in Grafana

## Methodology

- Automated file permission scan across home directory and /opt
- Manual review of service configurations
- Network port scan via `ss -tlnp`
- Tailscale status verification
- SSH probe to deployment host (mon1)
- No destructive testing performed
