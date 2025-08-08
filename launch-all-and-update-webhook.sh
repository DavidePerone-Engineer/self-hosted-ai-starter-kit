#!/bin/bash

# ------------- CONFIGURATION -------------
PROJECT_DIR="/root/n8n/self-hosted-ai-starter-kit"
LOG_FILE="$PROJECT_DIR/cloudflared.log"
ENV_FILE="$PROJECT_DIR/.env"
DOCKER_COMPOSE="$(which docker)"
SLEEP_INTERVAL=20  # seconds between webhook checks

# ------------- FUNCTIONS -------------

kill_if_running() {
  local term="$1"
  pkill -f "$term" 2>/dev/null || true
}

extract_url() {
  grep -o 'https://[a-zA-Z0-9.-]*\.trycloudflare\.com' "$LOG_FILE" | tail -1
}

restart_docker_stack() {
  echo "[INFO] Restarting n8n stack with new WEBHOOK_URL..."
  cd "$PROJECT_DIR"
  $DOCKER_COMPOSE compose down
  $DOCKER_COMPOSE compose up -d
}

# ------------- SCRIPT STARTS HERE -------------

echo "[STEP 0] Cleaning up any previous processes..."
kill_if_running cloudflared
: > "$LOG_FILE"

echo "[STEP 1] Starting Docker Compose stack..."
cd "$PROJECT_DIR"
$DOCKER_COMPOSE compose up -d

echo "[STEP 2] Starting Cloudflare tunnel in background..."
nohup cloudflared tunnel --url http://localhost:5678 --logfile "$LOG_FILE" > "$PROJECT_DIR/cloudflared-run.log" 2>&1 &
sleep 3

echo "[STEP 3] Monitoring for Cloudflare tunnel URL changes and auto-updating n8n..."

CURRENT_URL=""
while true; do
  NEW_URL=$(extract_url)
  if [[ -n "$NEW_URL" && "$NEW_URL" != "$CURRENT_URL" ]]; then
    echo "[INFO] Detected new Cloudflare tunnel URL: $NEW_URL"
    if grep -q '^WEBHOOK_URL=' "$ENV_FILE"; then
      sed -i "s|^WEBHOOK_URL=.*|WEBHOOK_URL=$NEW_URL/|" "$ENV_FILE"
    else
      echo "WEBHOOK_URL=$NEW_URL/" >> "$ENV_FILE"
    fi
    restart_docker_stack
    echo "[SUCCESS] n8n restarted with new WEBHOOK_URL: $NEW_URL/"
    CURRENT_URL="$NEW_URL"
  fi
  sleep $SLEEP_INTERVAL
done
