# Moltbot Security Hardening Guide

Security hardening guide for [Moltbot](https://moltbot.dev) (formerly ClawdBot) deployments. Based on a real-world audit of a production deployment with access to Telegram, Discord, email, X, and Google Drive.

## Why This Exists

Moltbot is a powerful AI agent platform that connects to multiple communication channels and cloud services. With great power comes great attack surface. This repository documents:

- **Audit findings** from hardening a production Moltbot deployment
- **Step-by-step hardening guide** for new and existing installations
- **Automated scripts** to check and fix common security issues
- **Residual risk assessment** for informed risk acceptance

## Quick Start

```bash
# Clone this repo
git clone https://github.com/puretensor/moltbot-hardening.git
cd moltbot-hardening

# Run the audit check against your deployment
chmod +x scripts/audit-check.sh
./scripts/audit-check.sh
```

## Known Vulnerabilities

| CVE | Severity | Description | Fix |
|-----|----------|-------------|-----|
| CVE-2025-6514 | Critical | RCE via MCP servers | Update mcp-remote to 0.1.16+ |
| — | High | Plaintext credential storage | Targeted by active malware campaigns |
| — | Medium | Auth bypass on reverse-proxied instances | Bind gateway to loopback only |

## Repository Structure

```
moltbot-hardening/
├── README.md                 # This file
├── AUDIT.md                  # Full audit findings
├── HARDENING.md              # Step-by-step hardening guide
├── RESIDUAL-RISKS.md         # Accepted risks and rationale
├── scripts/
│   ├── audit-check.sh        # Automated audit script
│   ├── credential-migrate.sh # Credential migration helper
│   └── harden.sh             # One-shot hardening script
├── configs/
│   ├── gateway-secure.yaml   # Hardened gateway config
│   ├── sandbox-policy.yaml   # Recommended sandbox settings
│   └── firewall-rules.txt    # iptables/ufw rules
└── CHANGELOG.md              # Updates log
```

## Hardening Phases

1. **Immediate** — Version checks, gateway binding, DM policy, skill audit
2. **Credential Hardening** — Migrate from plaintext, rotate all secrets
3. **Network Hardening** — Firewall rules, Tailscale-only access
4. **Monitoring** — Process monitoring, API call logging, anomaly alerts

See [HARDENING.md](HARDENING.md) for the full guide.

## Context

This work was performed on a LAN-secured deployment running on dedicated infrastructure (no cloud VMs, no shared hosting). The deployment uses Tailscale mesh networking with no direct public exposure. We accept some residual risk given the network posture, but external attack vectors — particularly via MCP servers and credential theft — required mitigation.

## Contributing

Found a vulnerability or hardening step we missed? PRs welcome. Please follow responsible disclosure for any new vulnerabilities — open an issue tagged `security` or email security@puretensor.ai.

## License

MIT — see [LICENSE](LICENSE).
