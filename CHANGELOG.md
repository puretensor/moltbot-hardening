# Changelog

## 2026-01-29b — mon1 Audit Complete

### Added
- Full audit of `~/.clawdbot/` on mon1 (SSH remote audit)
- Detailed channel security review (Telegram, Discord, WhatsApp)
- ClawdBot architecture map (directory tree, plugins, model config)
- Remediation checklist (completed + pending items)

### Fixed
- Hardened 6 directories on mon1 from 0775 to 0700 (cron, devices, identity, media, memory, credentials/whatsapp)
- Fixed `.env` permissions on mon1 (0664 → 0600)
- Fixed `update-check.json` permissions on mon1 (0664 → 0600)

### Found
- 4 plaintext secrets in `clawdbot.json` (bot tokens + API keys) — rotation pending
- Discord groupPolicy set to "open" — lockdown pending
- Gateway mode "local" — needs verification against docs

## 2026-01-29 — Initial Release

### Added
- Initial security audit findings from production ClawdBot deployment
- Step-by-step hardening guide (4 phases)
- Residual risk assessment with acceptance rationale
- Automated audit script (`scripts/audit-check.sh`)
- Credential permission hardening script (`scripts/harden.sh`)
- Credential migration helper script (`scripts/credential-migrate.sh`)
- Hardened gateway configuration template
- Sandbox policy template
- Firewall rules for Tailscale-only deployments

### Known Gaps
- ~~ClawdBot config on mon1 not yet fully audited (SSH access pending)~~ Done in 2026-01-29b
- Moltbot migration not yet performed
- Credential encryption not yet implemented (permissions hardened only)
- Monitoring dashboards not yet created
