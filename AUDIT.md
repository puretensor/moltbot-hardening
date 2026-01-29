# Security Audit Findings

**Date:** 2026-01-29
**Target:** Production ClawdBot deployment on mon1 (192.168.4.168)
**Deployment:** LAN-secured infrastructure, Tailscale mesh, no public exposure
**Auditor:** PureTensor infrastructure team
**Status:** Phase 1 complete — permissions hardened, config audited

---

## Executive Summary

Audit of a production ClawdBot deployment on mon1 revealed **no critical active exploits**, but identified several hardening requirements. The bot has not yet migrated to Moltbot. Key findings:

- **4 plaintext secrets** embedded in `clawdbot.json` (bot tokens + API keys) — require rotation
- **Discord groupPolicy set to "open"** — allows any server to interact with the bot
- **File permissions were too permissive** on several subdirectories — **now fixed**
- **DM pairing policy correctly set** on Telegram and WhatsApp
- **No ClawdHub skills installed** — clean attack surface
- **No MCP servers configured** — CVE-2025-6514 not applicable

## Environment

| Component | Status | Notes |
|-----------|--------|-------|
| Bot platform | ClawdBot v2026.1.24-3 | Config at `~/.clawdbot/` on mon1 |
| Host | mon1 (192.168.4.168) | Dedicated LAN host |
| Node.js | v24.13.0 (tensor-core) | Exceeds 22.12.0+ requirement |
| mcp-remote | Not installed | CVE-2025-6514 not applicable |
| Gateway | port 18789, mode `"local"` | Verify "local" = loopback in docs |
| Network | Tailscale mesh only | No public ports exposed |
| Backups | 4-location automated | mon2 hourly, Ceph, Gitea, Iceland DR |

## Channels Configured

| Channel | Status | DM Policy | Group Policy | Notes |
|---------|--------|-----------|--------------|-------|
| Telegram | Enabled | `pairing` | `allowlist` | OK |
| WhatsApp | Disabled | `pairing` | `allowlist` | OK (currently off) |
| Discord | Enabled | — | **`open`** | **NEEDS LOCKDOWN** |

## Findings

### CRITICAL — Plaintext Secrets in Config

`clawdbot.json` contains 4 secrets in plaintext. These are the primary hardening target.

| Secret | Config Path | Impact |
|--------|------------|--------|
| Telegram bot token | `channels.telegram.botToken` | Full bot impersonation |
| Discord bot token | `channels.discord.token` | Full bot impersonation |
| Web search API key | `tools.web.search.apiKey` | API abuse / billing |
| Google Search API key | `plugins.entries.clawdbot-google-search.config.apiKey` | API abuse / billing |

Additionally, `~/.clawdbot/.env` contains a Google API key in plaintext.

**Action required:** Rotate all 5 secrets after hardening is complete. See [HARDENING.md](HARDENING.md) Phase 2.4.

### CRITICAL — Discord Group Policy Open

Discord `groupPolicy` is set to `"open"`, meaning any Discord server the bot is added to can interact with it. This should be changed to `"allowlist"` with specific server IDs.

```json
"discord": {
  "groupPolicy": "open"  // <-- change to "allowlist"
}
```

### HIGH — Credential File Permissions (tensor-core)

Multiple credential files on tensor-core had overly permissive permissions (group/world readable).

#### Google Drive OAuth Tokens
```
~/.config/puretensor/gdrive_tokens/token_cto.json     0644 → should be 0600
~/.config/puretensor/gdrive_tokens/token_personal.json 0644 → should be 0600
~/.config/puretensor/client_secret.json                0644 → should be 0600
```

#### HuggingFace API Tokens
```
~/.cache/huggingface/token          0664 → should be 0600
~/.cache/huggingface/stored_tokens  0664 → should be 0600
```

#### Application Environment Files
```
~/projects/whatsapp-translator/.env  0664 → should be 0600
/opt/bretalon_report_bot.env         0644 → should be 0600
```

#### Downloaded OAuth Secrets
```
~/Downloads/client_secret_568320298248-*.json  0644 → should be 0600 or removed
```

### MEDIUM — ClawdBot Directory Permissions (mon1) — FIXED

The following directories under `~/.clawdbot/` had `0775` permissions, allowing group read/execute. **All have been hardened to `0700`:**

| Directory | Before | After | Contents |
|-----------|--------|-------|----------|
| `cron/` | 0775 | **0700** | Scheduled job definitions |
| `devices/` | 0775 | **0700** | Device auth tokens |
| `identity/` | 0775 | **0700** | Ed25519 private key + device ID |
| `media/` | 0775 | **0700** | Media processing data |
| `memory/` | 0775 | **0700** | Conversation memory (SQLite) |
| `credentials/whatsapp/` | 0775 | **0700** | WhatsApp session data |

Files also fixed:

| File | Before | After |
|------|--------|-------|
| `.env` | 0664 | **0600** |
| `update-check.json` | 0664 | **0600** |

### GOOD — Already Correctly Configured

| Item | Value | Status |
|------|-------|--------|
| `~/.clawdbot/` dir | 0700 | OK |
| `clawdbot.json` | 0600 | OK |
| `clawdbot.json.bak*` | 0600 | OK |
| `credentials/` dir | 0700 | OK |
| `credentials/*.json` | 0600 | OK |
| `agents/` dir | 0700 | OK |
| `subagents/` dir | 0700 | OK |
| `telegram/` dir | 0700 | OK |
| `identity/*.json` | 0600 | OK |
| Telegram dmPolicy | `"pairing"` | OK |
| WhatsApp dmPolicy | `"pairing"` | OK |
| WhatsApp groupPolicy | `"allowlist"` | OK |
| Telegram groupPolicy | `"allowlist"` | OK |
| Operator device | Loopback (127.0.0.1), CLI mode | OK |
| Skills/ClawdHub | No skills directory exists | OK — clean surface |
| MCP servers | None configured | OK — CVE-2025-6514 N/A |

### GOOD — Properly Secured Credentials (tensor-core)

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

### INFO — ClawdBot Architecture on mon1

```
~/.clawdbot/
├── clawdbot.json          # Main config (secrets, channels, plugins)
├── clawdbot.json.bak*     # 4 rolling config backups
├── .env                   # Google API key
├── agents/main/           # Agent definition + session history
├── credentials/           # Channel auth (Telegram pairing, WhatsApp session)
├── cron/                  # Scheduled jobs (jobs.json + run history)
├── devices/               # Device registration + operator tokens
├── identity/              # Ed25519 keypair + device ID
├── media/                 # Audio transcription pipeline
├── memory/                # Conversation memory (main.sqlite, 70KB)
├── subagents/             # Sub-agent run tracking
└── telegram/              # Telegram update offset tracking
```

**Plugins loaded:**
- `telegram` — Channel integration
- `discord` — Channel integration
- `whatsapp` — Channel integration (disabled)
- `google-gemini-cli-auth` — Gemini model authentication
- `clawdbot-google-search` — Web search via Google Custom Search API

**Model configuration:**
- Primary: `google/gemini-3-flash`
- Fallback: `google/gemini-3-pro`
- Memory search via Gemini, context pruning via cache-TTL

### INFO — Network Posture

| Check | Result |
|-------|--------|
| Public ports | None (Tailscale only) |
| Tailscale active | Yes, ~20+ nodes |
| SSH access | Key-based only |
| Ollama (11434) | Bound to localhost |
| Web services (9000, 8100) | Internal only |
| Gateway (18789) | Mode "local" — verify loopback |

## Remediation Summary

### Completed (2026-01-29)

- [x] Fixed `~/.clawdbot/` subdirectory permissions on mon1 (6 dirs: 0775 → 0700)
- [x] Fixed `.env` permissions on mon1 (0664 → 0600)
- [x] Fixed `update-check.json` permissions on mon1 (0664 → 0600)
- [x] Fixed WhatsApp credential subdirectory permissions (0775 → 0700)
- [x] Verified DM policy = "pairing" on Telegram and WhatsApp
- [x] Verified no ClawdHub skills installed
- [x] Verified no MCP servers configured
- [x] Verified operator device bound to loopback

### Pending

- [ ] Change Discord `groupPolicy` from `"open"` to `"allowlist"`
- [ ] Fix credential file permissions on tensor-core (GDrive, HuggingFace, .env files)
- [ ] Remove downloaded OAuth client secrets from `~/Downloads/` on tensor-core
- [ ] Verify gateway mode `"local"` = loopback in ClawdBot documentation
- [ ] Rotate Telegram bot token
- [ ] Rotate Discord bot token
- [ ] Rotate web search API key
- [ ] Rotate Google Search API key
- [ ] Rotate Google API key in `.env`
- [ ] Implement credential encryption (Phase 2.3)
- [ ] Add monitoring dashboards (Phase 4)

## Methodology

- Automated file permission scan across home directory and /opt (tensor-core)
- SSH to mon1, full audit of `~/.clawdbot/` directory tree
- Manual review of `clawdbot.json` configuration
- Review of all credential, identity, and device files
- Network port scan via `ss -tlnp`
- Tailscale status verification
- No destructive testing performed
