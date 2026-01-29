# Moltbot Hardening Guide

Step-by-step guide to hardening a Moltbot (or ClawdBot) deployment. Organized by priority phase.

---

## Prerequisites

- SSH access to the host running Moltbot/ClawdBot
- `node --version` returns 22.12.0 or higher
- Root/sudo access for firewall rules (Phase 3)

---

## Phase 1 — Immediate Checks

### 1.1 Verify Software Versions

```bash
# Node.js — must be 22.12.0+
node --version

# Moltbot version (if migrated)
moltbot --version

# mcp-remote — must be 0.1.16+ if installed (patches CVE-2025-6514)
npm list -g mcp-remote
```

### 1.2 Run Security Audit

```bash
# If using Moltbot
moltbot security audit --deep --fix

# If still on ClawdBot, manually check config
cat ~/.clawdbot/clawdbot.json | jq '.gateway, .dmPolicy, .security'
```

### 1.3 Gateway Binding

The gateway UI must only bind to loopback. External binding allows authentication bypass when behind a reverse proxy.

**Check:**
```bash
# In clawdbot.json or moltbot.json
grep -i "bind" ~/.clawdbot/clawdbot.json
```

**Fix:** Set `gateway.bind` to `"loopback"` or `"127.0.0.1"`:
```json
{
  "gateway": {
    "bind": "loopback"
  }
}
```

### 1.4 DM Policy

Require pairing approval for new contacts to prevent unsolicited command injection.

**Fix:** Set `dmPolicy` to `"pairing"`:
```json
{
  "dmPolicy": "pairing"
}
```

### 1.5 Skill Audit

List and review all installed skills. Remove anything from ClawdHub that hasn't been audited.

```bash
# List installed skills
moltbot skills list

# Or for ClawdBot
ls ~/.clawdbot/skills/
cat ~/.clawdbot/clawdbot.json | jq '.skills'

# Remove untrusted skills
moltbot skills remove <skill-name>
```

---

## Phase 2 — Credential Hardening

### 2.1 Fix File Permissions

Run the hardening script or manually fix:

```bash
# Automated
./scripts/harden.sh

# Manual — Google Drive tokens
chmod 600 ~/.config/puretensor/gdrive_tokens/*.json
chmod 600 ~/.config/puretensor/client_secret.json

# Manual — HuggingFace tokens
chmod 600 ~/.cache/huggingface/token
chmod 600 ~/.cache/huggingface/stored_tokens

# Manual — Application env files
chmod 600 ~/projects/whatsapp-translator/.env
sudo chmod 600 /opt/bretalon_report_bot.env

# Manual — ClawdBot credentials directory
chmod 700 ~/.clawdbot/credentials/
chmod 600 ~/.clawdbot/credentials/*
chmod 600 ~/.clawdbot/clawdbot.json
```

### 2.2 Audit Plaintext Credentials

Document everything stored in plaintext:

```bash
# Check ClawdBot credential directory
ls -la ~/.clawdbot/credentials/

# Look for plaintext tokens/keys in configs
grep -r "token\|api_key\|secret\|password" ~/.clawdbot/ --include="*.json" -l
```

### 2.3 Choose Credential Storage

| Option | Pros | Cons | Recommended For |
|--------|------|------|-----------------|
| **A: HashiCorp Vault** | Full-featured, self-hosted, audit log | Complex setup, resource overhead | Multi-node deployments |
| **B: Google Cloud Secret Manager** | Managed, already in GCP pipeline | Cloud dependency, per-access cost | GCP-heavy workflows |
| **C: Encrypted local storage** | Simple, no dependencies | Manual key management | Single-node, LAN-secured |

For LAN-secured single-node deployments, **Option C** is pragmatic. Use `age` or `sops` for encryption:

```bash
# Install age
sudo apt install age

# Generate key
age-keygen -o ~/.config/puretensor/age-key.txt
chmod 600 ~/.config/puretensor/age-key.txt

# Encrypt credentials
age -r <public-key> -o credentials.age credentials.json

# Decrypt at runtime
age -d -i ~/.config/puretensor/age-key.txt credentials.age
```

### 2.4 Rotate Credentials

After migration, rotate ALL credentials:

- [ ] Telegram bot token (via @BotFather)
- [ ] Discord bot token (via Discord Developer Portal)
- [ ] Google OAuth tokens (revoke and re-authorize)
- [ ] X API credentials (via X Developer Portal)
- [ ] Any other API keys found in audit

---

## Phase 3 — Network Hardening

### 3.1 Verify No Public Exposure

```bash
# Check listening ports
ss -tlnp

# Verify Tailscale is the only external interface
ip addr show | grep -E "inet " | grep -v "127.0.0.1\|tailscale"
```

### 3.2 Firewall Rules

Apply restrictive iptables rules — see `configs/firewall-rules.txt`:

```bash
# Allow established connections
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow loopback
sudo iptables -A INPUT -i lo -j ACCEPT

# Allow Tailscale interface
sudo iptables -A INPUT -i tailscale0 -j ACCEPT

# Allow SSH (as fallback)
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Drop everything else
sudo iptables -A INPUT -j DROP
```

### 3.3 Tailscale ACLs

If using Tailscale, restrict which nodes can reach the bot host:

```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["tag:admin"],
      "dst": ["tag:bot-host:*"]
    }
  ]
}
```

---

## Phase 4 — Monitoring

### 4.1 Process Monitoring

Add to Prometheus/Grafana stack:

```yaml
# prometheus.yml - add scrape target
- job_name: 'moltbot'
  static_configs:
    - targets: ['mon1:9100']
  metrics_path: /metrics
```

Create a Grafana dashboard tracking:
- Bot process uptime
- Memory/CPU usage
- API call rate
- Error rate

### 4.2 Audit Logging

Enable API call logging:

```bash
# In moltbot config, enable audit log
{
  "logging": {
    "audit": true,
    "auditPath": "/var/log/moltbot/audit.log",
    "level": "info"
  }
}
```

### 4.3 Anomaly Alerts

Set up alerts for:
- Bot process crash/restart
- Unusual API call volume (>2x baseline)
- Failed authentication attempts
- New DM contacts (if dmPolicy is "notify" instead of "pairing")

---

## Verification Checklist

After completing all phases, verify:

- [ ] `node --version` >= 22.12.0
- [ ] `mcp-remote` >= 0.1.16 (if installed)
- [ ] Gateway bound to loopback only
- [ ] DM policy set to "pairing"
- [ ] No untrusted skills installed
- [ ] All credential files are 0600
- [ ] Credential directory is 0700
- [ ] No plaintext secrets in world-readable locations
- [ ] All credentials rotated post-hardening
- [ ] Firewall drops non-Tailscale traffic
- [ ] Monitoring dashboards active
- [ ] Audit logging enabled
- [ ] Alert rules configured
