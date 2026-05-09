#!/bin/bash
# Ensures openclaw.json always uses openrouter/meta-llama/llama-3.3-70b-instruct:free
# on every startup, with Telegram and OpenRouter configured from environment variables.
# Runs as root before gosu-dropping to the openclaw user, so /data is writable.
# Requires TELEGRAM_BOT_TOKEN and OPENROUTER_API_KEY environment variables to be set.

set -e

TARGET_MODEL= "google/gemma-3-4b-it:free"
CONFIG_DIR="/data/.openclaw"
CONFIG_FILE="${CONFIG_DIR}/openclaw.json"

if [ -z "${TELEGRAM_BOT_TOKEN}" ]; then
  echo "[init-config] WARNING: TELEGRAM_BOT_TOKEN is not set. The Telegram bot will not work without it."
fi

if [ -z "${OPENROUTER_API_KEY}" ]; then
  echo "[init-config] WARNING: OPENROUTER_API_KEY is not set. The OpenRouter model will not work without it."
fi

mkdir -p "${CONFIG_DIR}"

# Always write a complete, fresh config so every startup is fully automated.
# The volume persists other state (memory, workspace, etc.) but the config is
# regenerated on every boot to pick up the correct model, API key, and bot token.
node - "${CONFIG_FILE}" "${TARGET_MODEL}" "${OPENROUTER_API_KEY:-}" "${TELEGRAM_BOT_TOKEN:-}" <<'EOF'
const fs           = require("fs");
const file         = process.argv[2];
const model        = process.argv[3];
const openrouterKey = process.argv[4];
const telegramToken = process.argv[5];

// Start from existing config if present so we preserve any extra state
// (e.g. device tokens, workspace settings) that openclaw wrote itself.
let cfg = {};
if (fs.existsSync(file)) {
  try {
    cfg = JSON.parse(fs.readFileSync(file, "utf8"));
  } catch (err) {
    console.warn("[init-config] Could not parse existing config, starting fresh:", err.message);
    cfg = {};
  }
}

// Always override model fields.
cfg.model = model;
if (!cfg.agent || typeof cfg.agent !== "object") cfg.agent = {};
cfg.agent.model = model;

// Always inject OpenRouter API key.
if (openrouterKey) {
  cfg.openrouterApiKey = openrouterKey;
}

// Always configure the Telegram channel.
if (telegramToken) {
  if (!cfg.channels || typeof cfg.channels !== "object") cfg.channels = {};
  if (!cfg.channels.telegram || typeof cfg.channels.telegram !== "object") cfg.channels.telegram = {};
  if (!cfg.channels.telegram.accounts || typeof cfg.channels.telegram.accounts !== "object") cfg.channels.telegram.accounts = {};
  if (!cfg.channels.telegram.accounts.default || typeof cfg.channels.telegram.accounts.default !== "object") cfg.channels.telegram.accounts.default = {};
  cfg.channels.telegram.accounts.default.token = telegramToken;
  cfg.channels.telegram.accounts.default.dmPolicy = "open";
  cfg.channels.telegram.accounts.default.allowFrom = ["*"];
  console.log("[init-config] Telegram channel configured.");
}


fs.writeFileSync(file, JSON.stringify(cfg, null, 2) + "\n", "utf8");
console.log("[init-config] Config written to", file, "— model:", model);
EOF
