#!/usr/bin/env bash
# Credential Migration Helper for Moltbot/ClawdBot
# Encrypts plaintext credentials using age encryption
# Usage: ./credential-migrate.sh [encrypt|decrypt|status]

set -euo pipefail

AGE_KEY_DIR="$HOME/.config/puretensor"
AGE_KEY_FILE="$AGE_KEY_DIR/age-key.txt"
BACKUP_DIR="$HOME/.config/puretensor/credential-backups"

usage() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  setup    - Generate age encryption key"
    echo "  status   - Show current credential encryption status"
    echo "  encrypt  - Encrypt plaintext credential files"
    echo "  decrypt  - Decrypt credentials (for recovery)"
    echo "  rotate   - Print credential rotation checklist"
    echo ""
    exit 1
}

check_age() {
    if ! command -v age &>/dev/null; then
        echo "ERROR: 'age' encryption tool not found."
        echo "Install: sudo apt install age"
        exit 1
    fi
}

cmd_setup() {
    check_age
    mkdir -p "$AGE_KEY_DIR"

    if [[ -f "$AGE_KEY_FILE" ]]; then
        echo "Age key already exists at $AGE_KEY_FILE"
        echo "Public key: $(grep 'public key' "$AGE_KEY_FILE" | awk '{print $NF}')"
        return
    fi

    age-keygen -o "$AGE_KEY_FILE" 2>&1
    chmod 600 "$AGE_KEY_FILE"
    echo ""
    echo "Key generated at: $AGE_KEY_FILE"
    echo "IMPORTANT: Back up this key securely. Without it, encrypted credentials cannot be recovered."
}

cmd_status() {
    echo "Credential Encryption Status"
    echo "============================="
    echo ""

    local dirs=(
        "$HOME/.clawdbot/credentials:ClawdBot credentials"
        "$HOME/.moltbot/credentials:Moltbot credentials"
        "$HOME/.config/puretensor/gdrive_tokens:Google Drive tokens"
    )

    for entry in "${dirs[@]}"; do
        dir="${entry%%:*}"
        desc="${entry##*:}"

        if [[ -d "$dir" ]]; then
            total=$(find "$dir" -type f | wc -l)
            encrypted=$(find "$dir" -name "*.age" -type f | wc -l)
            plaintext=$((total - encrypted))
            echo "$desc ($dir):"
            echo "  Total files: $total"
            echo "  Encrypted:   $encrypted"
            echo "  Plaintext:   $plaintext"
            echo ""
        fi
    done

    if [[ -f "$AGE_KEY_FILE" ]]; then
        echo "Encryption key: $AGE_KEY_FILE (exists)"
    else
        echo "Encryption key: NOT SET UP (run: $0 setup)"
    fi
}

cmd_encrypt() {
    check_age

    if [[ ! -f "$AGE_KEY_FILE" ]]; then
        echo "ERROR: No encryption key found. Run '$0 setup' first."
        exit 1
    fi

    PUBLIC_KEY=$(grep 'public key' "$AGE_KEY_FILE" | awk '{print $NF}')
    mkdir -p "$BACKUP_DIR"
    chmod 700 "$BACKUP_DIR"

    echo "Encrypting credential files..."
    echo "Public key: $PUBLIC_KEY"
    echo ""

    local encrypted=0

    encrypt_file() {
        local file="$1"
        local desc="$2"

        if [[ -f "$file" && ! -f "${file}.age" ]]; then
            # Backup original
            local backup="$BACKUP_DIR/$(basename "$file").$(date +%s)"
            cp "$file" "$backup"
            chmod 600 "$backup"

            # Encrypt
            age -r "$PUBLIC_KEY" -o "${file}.age" "$file"
            chmod 600 "${file}.age"

            echo "[ENCRYPTED] $desc -> ${file}.age"
            echo "  Backup at: $backup"
            echo "  Original preserved (delete manually after verifying)"
            ((encrypted++))
        fi
    }

    # ClawdBot credentials
    if [[ -d "$HOME/.clawdbot/credentials" ]]; then
        while IFS= read -r -d '' f; do
            [[ "$f" == *.age ]] && continue
            encrypt_file "$f" "ClawdBot: $(basename "$f")"
        done < <(find "$HOME/.clawdbot/credentials" -type f -print0 2>/dev/null)
    fi

    # Google Drive tokens
    for f in "$HOME/.config/puretensor/gdrive_tokens"/*.json; do
        [[ -f "$f" && "$f" != *.age ]] && encrypt_file "$f" "GDrive: $(basename "$f")"
    done

    echo ""
    echo "$encrypted file(s) encrypted."
    echo ""
    echo "NEXT STEPS:"
    echo "1. Verify encrypted files can be decrypted: $0 decrypt --test"
    echo "2. Remove plaintext originals once verified"
    echo "3. Update application configs to use decrypt-on-read"
}

cmd_decrypt() {
    check_age

    if [[ ! -f "$AGE_KEY_FILE" ]]; then
        echo "ERROR: No decryption key found at $AGE_KEY_FILE"
        exit 1
    fi

    echo "Decryptable files:"
    find "$HOME/.clawdbot" "$HOME/.moltbot" "$HOME/.config/puretensor" \
        -name "*.age" -type f 2>/dev/null | while read -r f; do
        echo "  $f"
        if [[ "${1:-}" == "--test" ]]; then
            if age -d -i "$AGE_KEY_FILE" "$f" >/dev/null 2>&1; then
                echo "    -> Decryption: OK"
            else
                echo "    -> Decryption: FAILED"
            fi
        fi
    done
}

cmd_rotate() {
    echo "Credential Rotation Checklist"
    echo "=============================="
    echo ""
    echo "After hardening and encrypting credentials, rotate all secrets:"
    echo ""
    echo "[ ] Telegram bot token"
    echo "    -> @BotFather -> /mybots -> select bot -> API Token -> Revoke"
    echo "    -> Generate new token and update config"
    echo ""
    echo "[ ] Discord bot token"
    echo "    -> https://discord.com/developers/applications"
    echo "    -> Select app -> Bot -> Reset Token"
    echo ""
    echo "[ ] Google OAuth tokens"
    echo "    -> https://myaccount.google.com/permissions"
    echo "    -> Revoke access for ClawdBot/Moltbot"
    echo "    -> Re-authorize with new tokens"
    echo ""
    echo "[ ] X (Twitter) API credentials"
    echo "    -> https://developer.twitter.com/en/portal/dashboard"
    echo "    -> Regenerate API Key & Secret"
    echo "    -> Regenerate Access Token & Secret"
    echo ""
    echo "[ ] HuggingFace token"
    echo "    -> https://huggingface.co/settings/tokens"
    echo "    -> Delete old token, create new one"
    echo ""
    echo "[ ] Any other API keys found during audit"
    echo ""
    echo "IMPORTANT: Update all configs with new credentials BEFORE revoking old ones."
}

case "${1:-}" in
    setup)    cmd_setup ;;
    status)   cmd_status ;;
    encrypt)  cmd_encrypt ;;
    decrypt)  cmd_decrypt "${2:-}" ;;
    rotate)   cmd_rotate ;;
    *)        usage ;;
esac
