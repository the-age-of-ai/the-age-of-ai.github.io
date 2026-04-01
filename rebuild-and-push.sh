#!/usr/bin/env bash
# rebuild-and-push.sh — Build Hugo site and push to GitHub
# Runs after generate.sh via cron at 2:30 AM
# Cron: 30 2 * * * cd /home/charlie/.openclaw/workspace/blog && ./rebuild-and-push.sh >> ./generate.log 2>&1

set -e
LOG="./generate.log"

# Check product article queue
echo "[$(date)] Checking product article queue..." >> "$LOG"
bash /home/charlie/.openclaw/workspace/blog/publish-queued.sh >> "$LOG" 2>&1 || true

echo "[$(date)] Building Hugo site..." >> "$LOG"
hugo --minify >> "$LOG" 2>&1

echo "[$(date)] Pushing to GitHub..." >> "$LOG"
git add -A
git commit -m "content: nightly build $(date +%Y-%m-%d)" >> "$LOG" 2>&1 || echo "[$(date)] Nothing to commit" >> "$LOG"
git push origin master >> "$LOG" 2>&1

echo "[$(date)] Deploy complete." >> "$LOG"
