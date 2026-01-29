# Changelog

## 2026-01-29c — Hardening Complete, Rotation Prepared

### Added
- `ROTATION.md` — Step-by-step secret rotation procedure for all 5 exposed secrets
- Rotation schedule recommendations (90-day for tokens, 180-day for API keys)
- Post-rotation verification checklist
- Quick reference for jq-based config editing on mon1

### Fixed
- Changed Discord `groupPolicy` from `"open"` to `"allowlist"` on mon1
- Fixed 8 credential file permissions on tensor-core (0664 → 0600)
- Fixed gdrive_tokens directory on tensor-core (0775 → 0700)
- Fixed `/opt/bretalon_report_bot.env` on tensor-core (0644 → 0600)
- Confirmed no client_secret files on mon1 Downloads (clean)

### Status
- All automated hardening complete
- 5 secrets require manual rotation by operator (see ROTATION.md)

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
