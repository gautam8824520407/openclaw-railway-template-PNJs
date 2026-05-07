#!/bin/bash
# Ensures openclaw.json always uses the correct OpenRouter model on startup.
# Runs as root before gosu-dropping to the openclaw user, so /data is writable.

set -e

TARGET_MODEL="openrouter/meta-llama/llama-3.3-70b-instruct:free"
CONFIG_DIR="/data/.openclaw"
CONFIG_FILE="${CONFIG_DIR}/openclaw.json"

if [ -f "${CONFIG_FILE}" ]; then
  echo "[init-config] Patching model fields in ${CONFIG_FILE}"

  # Use node (always available in the image) to do a safe JSON in-place update.
  node - "${CONFIG_FILE}" "${TARGET_MODEL}" <<'EOF'
const fs   = require("fs");
const file  = process.argv[2];
const model = process.argv[3];

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

fs.writeFileSync(file, JSON.stringify(cfg, null, 2) + "\n", "utf8");
console.log("[init-config] model set to", model);
EOF

else
  echo "[init-config] ${CONFIG_FILE} not found — creating minimal config with correct model"
  mkdir -p "${CONFIG_DIR}"
  node -e "
const model = process.argv[1];
const cfg = { model, agent: { model } };
require('fs').writeFileSync(process.argv[2], JSON.stringify(cfg, null, 2) + '\n', 'utf8');
console.log('[init-config] created', process.argv[2], 'with model', model);
" "${TARGET_MODEL}" "${CONFIG_FILE}"
fi
