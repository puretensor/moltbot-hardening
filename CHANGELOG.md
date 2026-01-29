# Changelog

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
- ClawdBot config on mon1 not yet fully audited (SSH access pending)
- Moltbot migration not yet performed
- Credential encryption not yet implemented (permissions hardened only)
- Monitoring dashboards not yet created
