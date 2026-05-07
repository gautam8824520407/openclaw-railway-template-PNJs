#!/bin/bash
# Ensures openclaw.json always uses gemini-2.0-flash (Google Gemini) on startup.
# Runs as root before gosu-dropping to the openclaw user, so /data is writable.
# Requires GEMINI_API_KEY environment variable to be set.

set -e

TARGET_MODEL="gemini-2.0-flash"
CONFIG_DIR="/data/.openclaw"
CONFIG_FILE="${CONFIG_DIR}/openclaw.json"

if [ -z "${GEMINI_API_KEY}" ]; then
  echo "[init-config] WARNING: GEMINI_API_KEY is not set. The Gemini model will not work without it."
fi

if [ -f "${CONFIG_FILE}" ]; then
  echo "[init-config] Patching model fields in ${CONFIG_FILE}"

  # Use node (always available in the image) to do a safe JSON in-place update.
  node - "${CONFIG_FILE}" "${TARGET_MODEL}" "${GEMINI_API_KEY:-}" <<'EOF'
const fs    = require("fs");
const file  = process.argv[2];
const model = process.argv[3];
const apiKey = process.argv[4];

let cfg;
try {
  cfg = JSON.parse(fs.readFileSync(file, "utf8"));
} catch (err) {
  console.error("[init-config] Failed to parse", file, "-", err.message);
  process.exit(1);
}

cfg.model = model;
if (cfg.agent && typeof cfg.agent === "object") {
  cfg.agent.model = model;
}
if (apiKey) {
  cfg.geminiApiKey = apiKey;
}

fs.writeFileSync(file, JSON.stringify(cfg, null, 2) + "\n", "utf8");
console.log("[init-config] model set to", model);
EOF

else
  echo "[init-config] ${CONFIG_FILE} not found — creating minimal config with correct model"
  mkdir -p "${CONFIG_DIR}"
  node -e "
const model  = process.argv[1];
const file   = process.argv[2];
const apiKey = process.argv[3];
const cfg = { model, agent: { model } };
if (apiKey) cfg.geminiApiKey = apiKey;
require('fs').writeFileSync(file, JSON.stringify(cfg, null, 2) + '\n', 'utf8');
console.log('[init-config] created', file, 'with model', model);
" "${TARGET_MODEL}" "${CONFIG_FILE}" "${GEMINI_API_KEY:-}"
fi
