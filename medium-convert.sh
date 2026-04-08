#!/bin/bash
# medium-convert.sh — Convert blog posts to Medium-ready markdown
# Strips Hugo front matter, tables, shortcodes; adds canonical footer
# Output: blog/medium/YYYY-MM-DD-slug.md

POSTS_DIR="/home/charlie/.openclaw/workspace/blog/content/posts"
MEDIUM_DIR="/home/charlie/.openclaw/workspace/blog/medium"
BLOG_BASE="https://the-age-of-ai.github.io/posts"

mkdir -p "$MEDIUM_DIR"

converted=0
skipped=0
errors=0

for post in "$POSTS_DIR"/*.md; do
    filename=$(basename "$post")
    slug="${filename%.md}"
    output="$MEDIUM_DIR/$filename"

    # Skip if already converted (unless --force passed)
    if [ -f "$output" ] && [ "$1" != "--force" ]; then
        ((skipped++))
        continue
    fi

    canonical_url="$BLOG_BASE/$slug/"

    result=$(python3 << PYEOF
import sys, re

post_path = "$post"
canonical_url = "$canonical_url"

with open(post_path, 'r') as f:
    content = f.read()

# Extract title from front matter
title_match = re.search(r'^title:\s*["\']?(.+?)["\']?\s*$', content, re.MULTILINE)
title = title_match.group(1).strip('"\'') if title_match else ""

if not title:
    print("ERROR:no_title")
    sys.exit(1)

# Strip Hugo front matter (--- ... ---)
content = re.sub(r'^---\n.*?---\n', '', content, flags=re.DOTALL)

# Strip leading H1 (Medium adds its own from the title)
content = re.sub(r'^\s*#\s+.+\n', '', content.lstrip(), count=1)

# Remove Hugo shortcodes
content = re.sub(r'\{\{[^}]+\}\}', '', content)

# Remove markdown tables
content = re.sub(r'(\|[^\n]+\|\n)+', '', content)
content = re.sub(r'^\|[-| :]+\|\s*$', '', content, flags=re.MULTILINE)

# Remove bare affiliate/product URLs on their own line
content = re.sub(r'^\s*https?://\S+\s*$', '', content, flags=re.MULTILINE)

# Clean up excessive blank lines
content = re.sub(r'\n{3,}', '\n\n', content)

# Build output
output = "# " + title + "\n\n"
output += content.strip()
output += "\n\n---\n\n*Originally published at [" + canonical_url + "](" + canonical_url + ")*\n"

print(output)
PYEOF
    )

    if echo "$result" | grep -q "^ERROR:"; then
        echo "SKIP (no title): $filename"
        ((skipped++))
    elif [ -z "$result" ]; then
        echo "ERROR: $filename"
        ((errors++))
    else
        echo "$result" > "$output"
        echo "CONVERTED: $filename"
        ((converted++))
    fi
done

echo ""
echo "Done. Converted: $converted | Skipped: $skipped | Errors: $errors"
echo "Output: $MEDIUM_DIR"
