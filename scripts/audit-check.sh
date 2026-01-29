#!/usr/bin/env bash
# Moltbot/ClawdBot Security Audit Script
# Checks deployment against hardening requirements
# Usage: ./audit-check.sh [--fix]

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FIX_MODE=false
[[ "${1:-}" == "--fix" ]] && FIX_MODE=true

PASS=0
FAIL=0
WARN=0

pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((PASS++)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; ((FAIL++)); }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; ((WARN++)); }
info() { echo -e "      $1"; }

echo "======================================"
echo "Moltbot/ClawdBot Security Audit"
echo "Date: $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "Host: $(hostname)"
echo "User: $(whoami)"
echo "======================================"
echo ""

# --- Phase 1: Version Checks ---
echo "--- Phase 1: Software Versions ---"

# Node.js version
if command -v node &>/dev/null; then
    NODE_VER=$(node --version | sed 's/v//')
    NODE_MAJOR=$(echo "$NODE_VER" | cut -d. -f1)
    NODE_MINOR=$(echo "$NODE_VER" | cut -d. -f2)
    if [[ "$NODE_MAJOR" -gt 22 ]] || { [[ "$NODE_MAJOR" -eq 22 ]] && [[ "$NODE_MINOR" -ge 12 ]]; }; then
        pass "Node.js version: v${NODE_VER} (>= 22.12.0)"
    else
        fail "Node.js version: v${NODE_VER} (requires >= 22.12.0)"
    fi
else
    fail "Node.js not installed"
fi

# mcp-remote version
if npm list -g mcp-remote &>/dev/null 2>&1; then
    MCP_VER=$(npm list -g mcp-remote 2>/dev/null | grep mcp-remote | sed 's/.*@//')
    MCP_MINOR=$(echo "$MCP_VER" | cut -d. -f2)
    MCP_PATCH=$(echo "$MCP_VER" | cut -d. -f3)
    if [[ "$MCP_MINOR" -gt 1 ]] || { [[ "$MCP_MINOR" -eq 1 ]] && [[ "$MCP_PATCH" -ge 16 ]]; }; then
        pass "mcp-remote version: ${MCP_VER} (>= 0.1.16)"
    else
        fail "mcp-remote version: ${MCP_VER} (requires >= 0.1.16 for CVE-2025-6514)"
    fi
else
    warn "mcp-remote not installed (CVE-2025-6514 not applicable, but check if needed)"
fi

# Moltbot/ClawdBot
if command -v moltbot &>/dev/null; then
    pass "Moltbot binary found: $(moltbot --version 2>/dev/null || echo 'version unknown')"
elif [[ -d "$HOME/.clawdbot" ]]; then
    warn "ClawdBot config found but no Moltbot binary — migration pending"
else
    warn "Neither Moltbot nor ClawdBot detected on this host"
fi

echo ""

# --- Phase 2: Configuration Checks ---
echo "--- Phase 2: Configuration ---"

CONFIG_DIR="$HOME/.clawdbot"
MOLTBOT_DIR="$HOME/.moltbot"
CONFIG_FILE=""

if [[ -f "$MOLTBOT_DIR/moltbot.json" ]]; then
    CONFIG_FILE="$MOLTBOT_DIR/moltbot.json"
elif [[ -f "$CONFIG_DIR/clawdbot.json" ]]; then
    CONFIG_FILE="$CONFIG_DIR/clawdbot.json"
fi

if [[ -n "$CONFIG_FILE" ]]; then
    # Gateway binding
    if command -v jq &>/dev/null; then
        GATEWAY_BIND=$(jq -r '.gateway.bind // "not set"' "$CONFIG_FILE" 2>/dev/null)
        if [[ "$GATEWAY_BIND" == "loopback" || "$GATEWAY_BIND" == "127.0.0.1" ]]; then
            pass "Gateway bind: ${GATEWAY_BIND}"
        elif [[ "$GATEWAY_BIND" == "not set" ]]; then
            warn "Gateway bind not explicitly set — verify default behavior"
        else
            fail "Gateway bind: ${GATEWAY_BIND} (should be 'loopback' or '127.0.0.1')"
        fi

        # DM Policy
        DM_POLICY=$(jq -r '.dmPolicy // "not set"' "$CONFIG_FILE" 2>/dev/null)
        if [[ "$DM_POLICY" == "pairing" ]]; then
            pass "DM policy: pairing"
        else
            fail "DM policy: ${DM_POLICY} (should be 'pairing')"
        fi
    else
        warn "jq not installed — cannot parse config automatically"
    fi
else
    warn "No config file found — bot may not be deployed on this host"
fi

echo ""

# --- Phase 3: Credential Permissions ---
echo "--- Phase 3: Credential File Permissions ---"

check_perms() {
    local file="$1"
    local expected="$2"
    local desc="$3"

    if [[ -f "$file" ]]; then
        actual=$(stat -c %a "$file" 2>/dev/null || stat -f %Lp "$file" 2>/dev/null)
        if [[ "$actual" == "$expected" ]]; then
            pass "${desc}: ${actual}"
        else
            fail "${desc}: ${actual} (should be ${expected})"
            if $FIX_MODE; then
                chmod "$expected" "$file"
                info "Fixed: chmod ${expected} ${file}"
            fi
        fi
    fi
}

check_dir_perms() {
    local dir="$1"
    local expected="$2"
    local desc="$3"

    if [[ -d "$dir" ]]; then
        actual=$(stat -c %a "$dir" 2>/dev/null || stat -f %Lp "$dir" 2>/dev/null)
        if [[ "$actual" == "$expected" ]]; then
            pass "${desc}: ${actual}"
        else
            fail "${desc}: ${actual} (should be ${expected})"
            if $FIX_MODE; then
                chmod "$expected" "$dir"
                info "Fixed: chmod ${expected} ${dir}"
            fi
        fi
    fi
}

# ClawdBot/Moltbot credentials
check_dir_perms "$HOME/.clawdbot/credentials" "700" "ClawdBot credentials dir"
check_dir_perms "$HOME/.moltbot/credentials" "700" "Moltbot credentials dir"

# Find and check all files in credential directories
for dir in "$HOME/.clawdbot/credentials" "$HOME/.moltbot/credentials"; do
    if [[ -d "$dir" ]]; then
        while IFS= read -r -d '' f; do
            check_perms "$f" "600" "$(basename "$f")"
        done < <(find "$dir" -type f -print0 2>/dev/null)
    fi
done

# Config files
check_perms "$HOME/.clawdbot/clawdbot.json" "600" "ClawdBot config"
check_perms "$HOME/.moltbot/moltbot.json" "600" "Moltbot config"

# Google Drive tokens
for f in "$HOME/.config/puretensor/gdrive_tokens"/*.json; do
    [[ -f "$f" ]] && check_perms "$f" "600" "GDrive token: $(basename "$f")"
done
check_perms "$HOME/.config/puretensor/client_secret.json" "600" "GDrive client secret"

# HuggingFace
check_perms "$HOME/.cache/huggingface/token" "600" "HuggingFace token"
check_perms "$HOME/.cache/huggingface/stored_tokens" "600" "HuggingFace stored_tokens"

# SSH keys (spot check)
for f in "$HOME/.ssh"/id_*; do
    [[ "$f" == *.pub ]] && continue
    [[ -f "$f" ]] && check_perms "$f" "600" "SSH key: $(basename "$f")"
done

# Application env files
check_perms "$HOME/projects/whatsapp-translator/.env" "600" "WhatsApp translator .env"
check_perms "/opt/bretalon_report_bot.env" "600" "Bretalon bot .env"

echo ""

# --- Phase 4: Network ---
echo "--- Phase 4: Network ---"

# Check for Tailscale
if command -v tailscale &>/dev/null; then
    if tailscale status &>/dev/null; then
        pass "Tailscale active"
    else
        fail "Tailscale installed but not active"
    fi
else
    warn "Tailscale not installed"
fi

# Check for public-facing ports (non-loopback, non-tailscale)
PUBLIC_PORTS=$(ss -tlnp 2>/dev/null | grep -v "127.0.0.1\|::1\|\[::1\]" | tail -n +2 | wc -l)
if [[ "$PUBLIC_PORTS" -eq 0 ]]; then
    pass "No public-facing ports detected"
else
    warn "${PUBLIC_PORTS} port(s) listening on non-loopback interfaces"
    ss -tlnp 2>/dev/null | grep -v "127.0.0.1\|::1\|\[::1\]" | tail -n +2 | while read -r line; do
        info "$line"
    done
fi

echo ""

# --- Summary ---
echo "======================================"
echo "Audit Summary"
echo "======================================"
echo -e "${GREEN}PASS: ${PASS}${NC}"
echo -e "${RED}FAIL: ${FAIL}${NC}"
echo -e "${YELLOW}WARN: ${WARN}${NC}"
echo ""

if [[ "$FAIL" -gt 0 ]]; then
    echo "Run with --fix to auto-remediate permission issues."
    exit 1
elif [[ "$WARN" -gt 0 ]]; then
    echo "Audit passed with warnings. Review items above."
    exit 0
else
    echo "All checks passed."
    exit 0
fi
