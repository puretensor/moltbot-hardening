#!/usr/bin/env bash
# Moltbot/ClawdBot One-Shot Hardening Script
# Fixes common permission and configuration issues
# Usage: ./harden.sh [--dry-run]

set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

CHANGED=0

fix_perms() {
    local target="$1"
    local perms="$2"
    local desc="$3"
    local type="${4:-file}"  # file or dir

    if [[ "$type" == "dir" && -d "$target" ]] || [[ "$type" == "file" && -f "$target" ]]; then
        current=$(stat -c %a "$target" 2>/dev/null || stat -f %Lp "$target" 2>/dev/null)
        if [[ "$current" != "$perms" ]]; then
            if $DRY_RUN; then
                echo "[DRY RUN] Would chmod $perms $target ($desc: $current -> $perms)"
            else
                chmod "$perms" "$target"
                echo "[FIXED] $desc: $current -> $perms ($target)"
            fi
            ((CHANGED++))
        fi
    fi
}

echo "Moltbot/ClawdBot Hardening Script"
echo "================================="
$DRY_RUN && echo "MODE: Dry run (no changes)"
echo ""

# --- Credential Directories ---
echo "--- Credential Directories ---"
fix_perms "$HOME/.clawdbot/credentials" "700" "ClawdBot credentials dir" "dir"
fix_perms "$HOME/.moltbot/credentials" "700" "Moltbot credentials dir" "dir"
fix_perms "$HOME/.clawdbot" "700" "ClawdBot config dir" "dir"
fix_perms "$HOME/.moltbot" "700" "Moltbot config dir" "dir"

# --- Config Files ---
echo "--- Configuration Files ---"
fix_perms "$HOME/.clawdbot/clawdbot.json" "600" "ClawdBot config"
fix_perms "$HOME/.moltbot/moltbot.json" "600" "Moltbot config"

# --- Credential Files (ClawdBot) ---
if [[ -d "$HOME/.clawdbot/credentials" ]]; then
    echo "--- ClawdBot Credential Files ---"
    while IFS= read -r -d '' f; do
        fix_perms "$f" "600" "ClawdBot cred: $(basename "$f")"
    done < <(find "$HOME/.clawdbot/credentials" -type f -print0 2>/dev/null)
fi

# --- Credential Files (Moltbot) ---
if [[ -d "$HOME/.moltbot/credentials" ]]; then
    echo "--- Moltbot Credential Files ---"
    while IFS= read -r -d '' f; do
        fix_perms "$f" "600" "Moltbot cred: $(basename "$f")"
    done < <(find "$HOME/.moltbot/credentials" -type f -print0 2>/dev/null)
fi

# --- Google Drive ---
echo "--- Google Drive Tokens ---"
for f in "$HOME/.config/puretensor/gdrive_tokens"/*.json; do
    [[ -f "$f" ]] && fix_perms "$f" "600" "GDrive: $(basename "$f")"
done
fix_perms "$HOME/.config/puretensor/client_secret.json" "600" "GDrive client secret"

# --- HuggingFace ---
echo "--- HuggingFace ---"
fix_perms "$HOME/.cache/huggingface/token" "600" "HuggingFace token"
fix_perms "$HOME/.cache/huggingface/stored_tokens" "600" "HuggingFace stored_tokens"

# --- Application Env Files ---
echo "--- Application Environment Files ---"
fix_perms "$HOME/projects/whatsapp-translator/.env" "600" "WhatsApp translator .env"
# Note: /opt files may need sudo
if [[ -f "/opt/bretalon_report_bot.env" ]]; then
    current=$(stat -c %a /opt/bretalon_report_bot.env 2>/dev/null)
    if [[ "$current" != "600" ]]; then
        if $DRY_RUN; then
            echo "[DRY RUN] Would sudo chmod 600 /opt/bretalon_report_bot.env ($current -> 600)"
        else
            echo "[NOTE] /opt/bretalon_report_bot.env needs sudo to fix ($current -> 600)"
            echo "       Run: sudo chmod 600 /opt/bretalon_report_bot.env"
        fi
        ((CHANGED++))
    fi
fi

# --- Clean up Downloads ---
echo "--- Downloaded Secrets ---"
for f in "$HOME/Downloads"/client_secret_*.json; do
    if [[ -f "$f" ]]; then
        if $DRY_RUN; then
            echo "[DRY RUN] Would remove downloaded OAuth secret: $f"
        else
            echo "[WARN] Downloaded OAuth secret found: $f"
            echo "       Consider removing: rm '$f'"
        fi
        ((CHANGED++))
    fi
done

echo ""
echo "================================="
if [[ "$CHANGED" -eq 0 ]]; then
    echo "No changes needed. System is already hardened."
else
    if $DRY_RUN; then
        echo "$CHANGED issue(s) found. Run without --dry-run to apply fixes."
    else
        echo "$CHANGED issue(s) addressed."
    fi
fi
