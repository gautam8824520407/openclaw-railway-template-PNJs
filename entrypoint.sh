#!/bin/bash
set -e

chown -R openclaw:openclaw /data
chmod 700 /data

if [ ! -d /data/.linuxbrew ]; then
  cp -a /home/linuxbrew/.linuxbrew /data/.linuxbrew
fi

rm -rf /home/linuxbrew/.linuxbrew
ln -sfn /data/.linuxbrew /home/linuxbrew/.linuxbrew

# Force config reset on every startup so the model, API key, and Telegram bot
# token are always injected from environment variables. The volume persists
# other state (credentials, memory, etc.) but the config file is regenerated
# fresh each time by init-config.sh.
rm -f /data/.openclaw/openclaw.json

bash /app/init-config.sh

exec gosu openclaw node src/server.js
