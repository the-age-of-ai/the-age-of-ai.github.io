#!/usr/bin/env bash
# rebuild-and-push.sh — Build Hugo site and push to GitHub
# Runs after generate.sh via cron at 2:30 AM
# Cron: 30 2 * * * cd /home/charlie/.openclaw/workspace/blog && ./rebuild-and-push.sh >> ./generate.log 2>&1

set -e
LOG="./generate.log"

# Check product article queue
echo "[$(date)] Checking product article queue..." | tee -a "$LOG"
bash /home/charlie/.openclaw/workspace/blog/publish-queued.sh 2>&1 | tee -a "$LOG" || true

echo "[$(date)] Building Hugo site..." | tee -a "$LOG"
hugo --minify 2>&1 | tee -a "$LOG"

echo "[$(date)] Pushing to GitHub..." | tee -a "$LOG"
git add -A
git commit -m "content: nightly build $(date +%Y-%m-%d)" || echo "[$(date)] Nothing to commit" | tee -a "$LOG"
git push origin master 2>&1 | tee -a "$LOG"

echo "[$(date)] Deploy complete." | tee -a "$LOG"
