#!/bin/bash
set -e

chown -R openclaw:openclaw /data
chmod 700 /data

if [ ! -d /data/.linuxbrew ]; then
  cp -a /home/linuxbrew/.linuxbrew /data/.linuxbrew
fi

rm -rf /home/linuxbrew/.linuxbrew
ln -sfn /data/.linuxbrew /home/linuxbrew/.linuxbrew

# Force config reset on every startup so the model is always gemini-2.0-flash.
# The volume persists other state (credentials, memory, etc.) but the config
# file is regenerated fresh each time to pick up the correct model and API key.
rm -f /data/.openclaw/openclaw.json

bash /app/init-config.sh

exec gosu openclaw node src/server.js
