# Secret Rotation Procedure

Step-by-step instructions for rotating all exposed secrets. These secrets were found in plaintext in `~/.clawdbot/clawdbot.json` and `~/.clawdbot/.env` on mon1.

**Important:** For each secret, update the config file with the new value BEFORE revoking the old one, to minimize downtime.

---

## Overview

| # | Secret | Source | Config Location |
|---|--------|--------|-----------------|
| 1 | Telegram bot token | @BotFather | `channels.telegram.botToken` |
| 2 | Discord bot token | Discord Developer Portal | `channels.discord.token` |
| 3 | Brave Search API key | Brave Search Dashboard | `tools.web.search.apiKey` |
| 4 | Google Custom Search API key | GCP Console | `plugins.entries.clawdbot-google-search.config.apiKey` |
| 5 | Google API key (.env) | GCP Console | `~/.clawdbot/.env` |

All secrets are in: `mon1:~/.clawdbot/clawdbot.json` (except #5 which is in `~/.clawdbot/.env`)

---

## Pre-rotation Checklist

- [ ] Backup current config: `ssh mon1 'cp ~/.clawdbot/clawdbot.json ~/.clawdbot/clawdbot.json.bak.pre-rotation'`
- [ ] Confirm you can edit the config: `ssh mon1 'ls -la ~/.clawdbot/clawdbot.json'`
- [ ] Note the current bot name/identity to verify after rotation

---

## 1. Telegram Bot Token

**Current location in config:**
```json
"channels": {
  "telegram": {
    "botToken": "<CURRENT_TOKEN>"
  }
}
```

**Rotation steps:**

1. Open Telegram, message **@BotFather**
2. Send `/mybots`
3. Select the bot (**Clawdzoidberg**)
4. Tap **API Token**
5. Tap **Revoke current token** — this immediately invalidates the old token
6. Copy the new token
7. Update the config on mon1:
   ```bash
   ssh mon1
   # Edit the config
   nano ~/.clawdbot/clawdbot.json
   # Replace the botToken value with the new token
   # Save and exit
   ```
8. Restart ClawdBot:
   ```bash
   # Find and restart the clawdbot process
   # Method depends on how it's managed (systemd, pm2, manual)
   pgrep -af clawdbot
   # Then restart accordingly
   ```
9. Verify: Send a message to the bot on Telegram, confirm it responds

**Note:** Revoking the token immediately disconnects the bot. Plan for brief downtime.

---

## 2. Discord Bot Token

**Current location in config:**
```json
"channels": {
  "discord": {
    "token": "<CURRENT_TOKEN>"
  }
}
```

**Rotation steps:**

1. Go to https://discord.com/developers/applications
2. Select the application for the bot
3. Navigate to **Bot** section in the left sidebar
4. Click **Reset Token**
5. Confirm the reset — old token is immediately invalidated
6. Copy the new token
7. Update the config on mon1:
   ```bash
   ssh mon1
   nano ~/.clawdbot/clawdbot.json
   # Replace the discord token value with the new token
   ```
8. Restart ClawdBot
9. Verify: Check bot appears online in Discord, test a command

**Note:** Resetting invalidates the old token immediately. The bot will disconnect from all Discord servers until restarted with the new token.

---

## 3. Brave Search API Key

**Current location in config:**
```json
"tools": {
  "web": {
    "search": {
      "apiKey": "<CURRENT_KEY>"
    }
  }
}
```

**Rotation steps:**

1. Go to https://api.search.brave.com/app/keys
2. Log in with the account that owns the current key
3. Either:
   - **Option A:** Create a new API key, update config, then delete the old key
   - **Option B:** Delete the old key and create a new one (brief search outage)
4. Copy the new API key
5. Update the config on mon1:
   ```bash
   ssh mon1
   nano ~/.clawdbot/clawdbot.json
   # Replace the web search apiKey value
   ```
6. Restart ClawdBot
7. Verify: Ask the bot to search for something, confirm results return

**Preferred:** Option A (zero downtime for search functionality)

---

## 4. Google Custom Search API Key

**Current location in config:**
```json
"plugins": {
  "entries": {
    "clawdbot-google-search": {
      "config": {
        "apiKey": "<CURRENT_KEY>"
      }
    }
  }
}
```

**Rotation steps:**

1. Go to https://console.cloud.google.com/apis/credentials
2. Select the project that owns this key
3. **Option A (preferred):** Create a new API key first
   - Click **+ CREATE CREDENTIALS** → **API key**
   - Restrict the new key to Custom Search API only
   - Update the config with the new key
   - Then delete the old key
4. **Option B:** Click on the existing key → **REGENERATE KEY** (invalidates old immediately)
5. Update the config on mon1:
   ```bash
   ssh mon1
   nano ~/.clawdbot/clawdbot.json
   # Replace the clawdbot-google-search apiKey value
   ```
6. Restart ClawdBot
7. Verify: Test Google search functionality

**Also:** The `searchEngineId` is still set to `"PLACEHOLDER_NEEDS_SETUP"`. When rotating, also set up a proper Custom Search Engine ID at https://programmablesearchengine.google.com/

---

## 5. Google API Key (.env)

**Current location:** `~/.clawdbot/.env`
```
GOOGLE_API_KEY=<CURRENT_KEY>
```

**Rotation steps:**

1. Go to https://console.cloud.google.com/apis/credentials
2. Identify which project this key belongs to (may be same project as #4)
3. Create a new API key (restrict to required APIs only)
4. Update the .env file on mon1:
   ```bash
   ssh mon1
   nano ~/.clawdbot/.env
   # Replace GOOGLE_API_KEY value
   ```
5. Restart ClawdBot
6. Delete the old key in GCP Console
7. Verify: Test Gemini model access (this key likely authenticates the Gemini plugin)

**Note:** This key is likely used by the `google-gemini-cli-auth` plugin. Verify Gemini model calls work after rotation.

---

## Post-rotation Checklist

After rotating ALL secrets:

- [ ] All 5 secrets updated in config files
- [ ] ClawdBot restarted and running
- [ ] Telegram bot responds to messages
- [ ] Discord bot online and responding
- [ ] Web search returns results
- [ ] Google search returns results
- [ ] Gemini model calls succeed
- [ ] Old tokens deleted/revoked in their respective portals
- [ ] Backup config updated: `ssh mon1 'cp ~/.clawdbot/clawdbot.json ~/.clawdbot/clawdbot.json.bak.post-rotation'`

---

## Quick Reference: Editing Config on mon1

```bash
# SSH to mon1
ssh mon1

# Backup before editing
cp ~/.clawdbot/clawdbot.json ~/.clawdbot/clawdbot.json.bak.pre-rotation

# Edit config (use jq for precision, or nano for manual)
nano ~/.clawdbot/clawdbot.json

# Or use jq to update a specific field:
cat ~/.clawdbot/clawdbot.json | jq '.channels.telegram.botToken = "NEW_TOKEN_HERE"' > /tmp/cb.json
mv /tmp/cb.json ~/.clawdbot/clawdbot.json
chmod 600 ~/.clawdbot/clawdbot.json

# Restart ClawdBot (check how it's managed first)
pgrep -af clawdbot
# systemctl restart clawdbot  (if systemd)
# pm2 restart clawdbot        (if pm2)
```

---

## Rotation Schedule

After initial rotation, establish a regular cadence:

| Secret | Recommended Cadence | Notes |
|--------|-------------------|-------|
| Telegram bot token | Every 90 days | Low risk if loopback + pairing |
| Discord bot token | Every 90 days | Now on allowlist |
| API keys | Every 180 days | Lower risk, billing impact only |

Set a calendar reminder or cron-based notification.
