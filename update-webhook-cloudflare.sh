#!/bin/bash

PROJECT_DIR="/root/n8n/self-hosted-ai-starter-kit"
LOG_FILE="$PROJECT_DIR/cloudflared.log"
ENV_FILE="$PROJECT_DIR/.env"
SLEEP_INTERVAL=20
DOCKER_COMPOSE="$(which docker)"

extract_url() {
  grep -o 'https://[a-zA-Z0-9.-]*\.trycloudflare\.com' "$LOG_FILE" | tail -1
}

echo "Monitoring for Cloudflare tunnel URL changes..."

CURRENT_URL=""
while true; do
  NEW_URL=$(extract_url)
  if [[ -n "$NEW_URL" && "$NEW_URL" != "$CURRENT_URL" ]]; then
    echo "Detected new tunnel URL: $NEW_URL"
    sed -i "s|^WEBHOOK_URL=.*|WEBHOOK_URL=$NEW_URL/|" "$ENV_FILE"
    (cd "$PROJECT_DIR" && $DOCKER_COMPOSE compose down && $DOCKER_COMPOSE compose up -d)
    echo "Updated .env and restarted Docker Compose: $NEW_URL/"
    CURRENT_URL="$NEW_URL"
  fi
  sleep $SLEEP_INTERVAL
done
