#!/usr/bin/env bash
# publish-queued.sh — Publish one queued product article sporadically
# Runs nightly but only publishes every 2-3 days (random)
# Picks a random article from product-articles/ queue

set -e

BLOG_DIR="/home/charlie/.openclaw/workspace/blog"
QUEUE_DIR="$BLOG_DIR/product-articles"
PUBLISHED_DIR="$BLOG_DIR/product-articles/published"
CONTENT_DIR="$BLOG_DIR/content/posts"
LOG="$BLOG_DIR/generate.log"
STATE_FILE="$BLOG_DIR/product-articles/queue-state.json"

mkdir -p "$PUBLISHED_DIR"

echo "[$(date)] === Checking product article queue ===" | tee -a "$LOG"

# Check if we should publish today (random 2-3 day cadence)
if [ -f "$STATE_FILE" ]; then
  LAST_PUBLISHED=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d.get('lastPublishedDate',''))" 2>/dev/null || echo "")
  TODAY=$(date +%Y-%m-%d)
  if [ -n "$LAST_PUBLISHED" ]; then
    DAYS_SINCE=$(python3 -c "from datetime import date; d1=date.fromisoformat('$LAST_PUBLISHED'); d2=date.fromisoformat('$TODAY'); print((d2-d1).days)" 2>/dev/null || echo "999")
    # Randomly skip: publish if days_since >= 2 AND random roll passes
    ROLL=$(python3 -c "import random; print(random.choice([1,1,0]))")  # 2/3 chance on day 2, always on day 3+
    if [ "$DAYS_SINCE" -lt 2 ]; then
      echo "[$(date)] Published recently ($DAYS_SINCE days ago). Skipping." | tee -a "$LOG"
      exit 0
    fi
    if [ "$DAYS_SINCE" -eq 2 ] && [ "$ROLL" -eq 0 ]; then
      echo "[$(date)] Day 2 — random skip. Next chance tomorrow." | tee -a "$LOG"
      exit 0
    fi
  fi
fi

# Pick a random unpublished article
ARTICLES=($(ls "$QUEUE_DIR"/*.md 2>/dev/null | grep -v "published/"))
if [ ${#ARTICLES[@]} -eq 0 ]; then
  echo "[$(date)] Product article queue empty. Nothing to publish." | tee -a "$LOG"
  exit 0
fi

# Random pick
IDX=$(python3 -c "import random; print(random.randint(0, $((${#ARTICLES[@]} - 1))))")
ARTICLE="${ARTICLES[$IDX]}"
BASENAME=$(basename "$ARTICLE")

echo "[$(date)] Publishing: $BASENAME" | tee -a "$LOG"

# Update date in frontmatter to today
TODAY=$(date +%Y-%m-%d)
sed -i "s/^date: .*/date: $TODAY/" "$ARTICLE"

# Copy to content/posts
DEST="$CONTENT_DIR/${TODAY}-${BASENAME#product-article-??-}"
cp "$ARTICLE" "$DEST"

# Move to published
mv "$ARTICLE" "$PUBLISHED_DIR/$BASENAME"

echo "[$(date)] Published: $DEST" | tee -a "$LOG"

# Update state
TOTAL_REMAINING=${#ARTICLES[@]}
TOTAL_REMAINING=$((TOTAL_REMAINING - 1))
python3 -c "
import json
state = {}
try:
    state = json.load(open('$STATE_FILE'))
except:
    pass
state['lastPublishedDate'] = '$TODAY'
state['lastPublishedFile'] = '$BASENAME'
state['remaining'] = $TOTAL_REMAINING
json.dump(state, open('$STATE_FILE', 'w'), indent=2)
print('State updated')
"

echo "[$(date)] Queue: $TOTAL_REMAINING articles remaining" | tee -a "$LOG"
echo "[$(date)] PUBLISHED_ARTICLE: $DEST" | tee -a "$LOG"
