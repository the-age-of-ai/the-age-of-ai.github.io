#!/usr/bin/env bash
# generate.sh — Nightly content generation via Ollama
# Niche: AI Tools for Small Business / Solopreneurs
# Strategy: 1 quality article/night. SEO-structured. HCU-safe.
# Rebuilt 2026-03-31 with SEO principles: keyword placement, H2 hierarchy,
#   short paragraphs, FAQ section, meta description, search-intent matching.
# Usage: ./generate.sh [keyword] [count]
# Cron: 0 2 * * * cd /home/charlie/.openclaw/workspace/blog && ./generate.sh >> ./generate.log 2>&1

set -e

MODEL="llama3.2:3b"
CONTENT_DIR="./content/posts"
LOG="./generate.log"
KEYWORDS_FILE="./keywords.txt"
USED_KEYWORDS_FILE="./used-keywords.txt"
COUNT="${2:-1}"

mkdir -p "$CONTENT_DIR"
touch "$USED_KEYWORDS_FILE"

echo "[$(date)] === Starting generation run ===" >> "$LOG"

# Check Ollama is running
if ! curl -sf http://localhost:11434/api/tags > /dev/null; then
  echo "[$(date)] ERROR: Ollama not running. Skipping." >> "$LOG"
  exit 1
fi

# Get next unused keyword
if [ -n "$1" ]; then
  KEYWORD="$1"
else
  KEYWORD=$(grep -vFf "$USED_KEYWORDS_FILE" "$KEYWORDS_FILE" 2>/dev/null | head -1)
fi

if [ -z "$KEYWORD" ]; then
  echo "[$(date)] No unused keywords left. Add more to keywords.txt" >> "$LOG"
  exit 0
fi

echo "[$(date)] Keyword: $KEYWORD" >> "$LOG"

ollama_query() {
  local prompt="$1"
  curl -sf http://localhost:11434/api/generate \
    -d "{\"model\": \"$MODEL\", \"prompt\": $(echo "$prompt" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))"), \"stream\": false}" \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['response'].strip())"
}

# ── Step 1: Generate SEO title ────────────────────────────────────────────
# Principle: keyword in title, under 60 chars ideal, specific + year
echo "[$(date)] Generating title..." >> "$LOG"
TITLE=$(ollama_query "Write ONE SEO-optimized blog post title for this exact keyword: '$KEYWORD'.

Rules:
- Include the keyword naturally in the title
- Keep it under 65 characters if possible
- Be specific and practical — small business owners are the audience
- Use 2026 as the year
- Format like: 'Best [X] for Small Business in 2026' or '[Keyword]: Top Picks for [Year]'
- Return ONLY the title, no quotes, no punctuation at end, nothing else")

if [ -z "$TITLE" ]; then
  echo "[$(date)] ERROR: Empty title. Skipping." >> "$LOG"
  exit 1
fi
echo "[$(date)] Title: $TITLE" >> "$LOG"

# ── Step 2: Generate meta description ────────────────────────────────────
# Principle: under 155 chars, drives CTR, include keyword naturally
echo "[$(date)] Generating meta description..." >> "$LOG"
META=$(ollama_query "Write a meta description for a blog post titled: '$TITLE'

Rules:
- Under 155 characters (strict)
- Include the keyword '$KEYWORD' naturally
- Focus on the benefit to the reader, not a summary
- End with a subtle action signal (e.g., 'Find the right fit.')
- Return ONLY the meta description, no quotes, nothing else")

if [ -z "$META" ]; then
  META="Honest comparison of ${KEYWORD} options for small business owners in 2026. Real pricing, real features, clear verdict."
fi
# Truncate to 155 chars
META=$(echo "$META" | cut -c1-155)
echo "[$(date)] Meta: $META" >> "$LOG"

# ── Step 3: Generate article body ────────────────────────────────────────
# SEO principles applied:
#   - Keyword in H1 (title) and first paragraph
#   - H2/H3 hierarchy with clear subtopics
#   - Short paragraphs (2-3 sentences)
#   - 1000+ words target
#   - FAQ section for long-tail keyword capture
#   - Match search intent (informational/transactional)
#   - Internal linking placeholder
# HCU principles:
#   - Who it's for / who it's NOT for
#   - Real pricing, real tools
#   - Honest verdict
echo "[$(date)] Generating article body..." >> "$LOG"
BODY=$(ollama_query "Write a detailed blog post titled: '$TITLE'

The target keyword is: '$KEYWORD'
The audience is: small business owners and solopreneurs (non-technical)
Search intent: informational — they want to understand their options and pick the right one

STRUCTURE (follow exactly, use these H2 headings):

## [Keyword rephrased as a question, e.g. 'What Is the Best AI CRM for Small Business?']
(Opening paragraph — 2-3 sentences. Include '$KEYWORD' naturally in the first sentence. Hook with a specific pain point. No generic openers like 'In today's world...')

## What Is [Topic]?
(2-3 short paragraphs, 2-3 sentences each. Plain English. Define it for a non-technical reader. Mention one specific example.)

## Who Should Use This?
(Bullet list: 4-5 specific use cases. Name business types and pain points. Be concrete.)

## Who Should NOT Use This?
(Bullet list: 2-3 honest cases. Be direct. This builds trust.)

## Top Options Compared in 2026
(Markdown table: Tool | Starting Price | Best For | Key AI Feature — 4 real tools)

## Our Top Pick for Most Small Businesses
(2-3 paragraphs. Name the winner. Explain why with specific features and real pricing. Mention $AFFILIATE as a complementary or runner-up tool where relevant.)

## Pricing Breakdown
(Bullet list or small table. Each plan: name, price, what you get. Be specific. Use real 2026 pricing.)

## Frequently Asked Questions
(3-4 Q&A pairs targeting long-tail variations of '$KEYWORD'. Keep answers 2-3 sentences each.)

## Verdict
(2-3 sentences. Honest bottom line. End with one clear action: 'Try [tool] free for 14 days at [URL]' or similar.)

WRITING RULES:
- Paragraphs: 2-3 sentences maximum. Short. Scannable.
- Use 2026 for all year references
- Specificity over generality: '3 hours per week' beats 'saves time'
- No filler phrases: no 'In today's fast-paced world', no 'It's worth noting that'
- Write for humans first — natural keyword usage, not stuffed
- Target 1000-1200 words total
- Clean Markdown formatting throughout")

if [ -z "$BODY" ]; then
  echo "[$(date)] ERROR: Empty body. Skipping." >> "$LOG"
  exit 1
fi

# ── Step 4: Generate tags ─────────────────────────────────────────────────
# Principle: semantic SEO — related keywords for topic clustering
echo "[$(date)] Generating tags..." >> "$LOG"
TAGS_RAW=$(ollama_query "List 5 short SEO tags for a blog post about '$KEYWORD' targeting small business owners.
Return ONLY a comma-separated list of lowercase tags, no quotes, no explanation.
Example format: ai tools, small business, automation, crm software, productivity")

# Parse tags into Hugo array format
TAGS=$(echo "$TAGS_RAW" | python3 -c "
import sys
raw = sys.stdin.read().strip()
tags = [t.strip().strip('\"').strip(\"'\") for t in raw.split(',')]
tags = [t for t in tags if t][:6]
print(', '.join([f'\"{t}\"' for t in tags]))
" 2>/dev/null || echo '"small business", "AI tools", "review"')

# ── Step 5: Write Hugo post ───────────────────────────────────────────────
SLUG=$(echo "$KEYWORD" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g' | tr ' ' '-' | cut -c1-60)
DATE=$(date +%Y-%m-%d)
FILENAME="${CONTENT_DIR}/${DATE}-${SLUG}.md"

# Affiliate links
LINKTREE_URL="https://linktr.ee/theageofai"
SYSTEME_URL="https://systeme.io/?sa=sa0267131685129e77387d3fa97cf89da7b07af0d7"
FRASE_URL=""
SEMRUSH_URL=""
HUBSPOT_URL=""
GETRESPONSE_URL=""

# Pick primary affiliate based on keyword
AFFILIATE=""
AFFILIATE_URL=""
case "$KEYWORD" in
  *CRM*|*crm*) AFFILIATE="HubSpot" ; AFFILIATE_URL="$HUBSPOT_URL" ;;
  *SEO*|*seo*|*semrush*) AFFILIATE="SEMrush" ; AFFILIATE_URL="$SEMRUSH_URL" ;;
  *email*|*Email*) AFFILIATE="GetResponse" ; AFFILIATE_URL="$GETRESPONSE_URL" ;;
  *accounting*|*bookkeeping*|*invoice*|*payroll*) AFFILIATE="Systeme.io" ; AFFILIATE_URL="$SYSTEME_URL" ;;
  *project*|*manage*) AFFILIATE="Notion" ; AFFILIATE_URL="$SYSTEME_URL" ;;
  *writing*|*content*|*copy*) AFFILIATE="Writesonic" ; AFFILIATE_URL="$FRASE_URL" ;;
  *landing*|*site*|*builder*) AFFILIATE="10Web" ; AFFILIATE_URL="$SYSTEME_URL" ;;
  *) AFFILIATE="Systeme.io" ; AFFILIATE_URL="$LINKTREE_URL" ;;
esac

# Strip surrounding quotes from title
TITLE="${TITLE#\"}" ; TITLE="${TITLE%\"}"
TITLE="${TITLE#\'}" ; TITLE="${TITLE%\'}"
META="${META#\"}" ; META="${META%\"}"

cat > "$FILENAME" << FRONTMATTER
---
title: "$TITLE"
date: $DATE
draft: false
description: "$META"
categories: ["AI Tools", "Small Business"]
tags: [$TAGS]
affiliate: "$AFFILIATE"
affiliateUrl: "$AFFILIATE_URL"
---

$BODY

---
*This post contains affiliate links. We may earn a commission if you purchase through our links, at no extra cost to you.*
FRONTMATTER

echo "[$(date)] Saved: $FILENAME" >> "$LOG"

# Mark keyword as used
echo "$KEYWORD" >> "$USED_KEYWORDS_FILE"
echo "[$(date)] === Run complete ===" >> "$LOG"
