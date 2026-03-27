#!/usr/bin/env python3
import os
import json
import time
import subprocess
import urllib.request
import urllib.error

# Load API key directly from secrets file
def load_env(path):
    env = {}
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line.startswith("export "):
                line = line[7:]
            if "=" in line and not line.startswith("#"):
                k, v = line.split("=", 1)
                env[k.strip()] = v.strip().strip('"').strip("'")
    return env

secrets = load_env("/home/charlie/.openclaw/secrets.env")
API_KEY = secrets.get("XAI_API_KEY", "")
print(f"API key loaded: {API_KEY[:8]}...")

API_URL = "https://api.x.ai/v1/chat/completions"
OUTPUT_DIR = "/home/charlie/.openclaw/workspace/blog/product-articles"

PRODUCTS = [
    {"num": "01", "slug": "chatgpt-prompts-small-business", "name": "50 ChatGPT Prompts for Small Business", "url": "https://theageofai.gumroad.com/l/xlziu"},
    {"num": "02", "slug": "email-templates-ai-business", "name": "30 Email Templates AI Business", "url": "https://theageofai.gumroad.com/l/eusvf"},
    {"num": "03", "slug": "ai-tools-cheat-sheet-2026", "name": "AI Tools Cheat Sheet 2026", "url": "https://theageofai.gumroad.com/l/rnlsvh"},
    {"num": "04", "slug": "20-ai-agent-workflows", "name": "20 AI Agent Workflows", "url": "https://theageofai.gumroad.com/l/roomup"},
    {"num": "05", "slug": "ai-automation-blueprint", "name": "AI Automation Blueprint", "url": "https://theageofai.gumroad.com/l/ebhmc"},
    {"num": "06", "slug": "openclaw-quickstart-guide", "name": "OpenClaw Quickstart Guide", "url": "https://theageofai.gumroad.com/l/gxadca"},
    {"num": "07", "slug": "freelancer-rate-proposal-toolkit", "name": "Freelancer Rate & Proposal Toolkit", "url": "https://theageofai.gumroad.com"},
    {"num": "08", "slug": "90-day-social-content-calendar", "name": "90-Day Social Content Calendar", "url": "https://theageofai.gumroad.com"},
    {"num": "09", "slug": "chatgpt-customer-service-templates", "name": "ChatGPT Customer Service Templates", "url": "https://theageofai.gumroad.com"},
    {"num": "10", "slug": "solopreneur-legal-starter-pack", "name": "Solopreneur Legal Starter Pack", "url": "https://theageofai.gumroad.com"},
    {"num": "11", "slug": "ai-prompts-etsy-sellers", "name": "50 AI Prompts for Etsy Sellers", "url": "https://theageofai.gumroad.com"},
    {"num": "12", "slug": "cold-outreach-playbook", "name": "Cold Outreach Playbook", "url": "https://theageofai.gumroad.com"},
    {"num": "13", "slug": "ai-prompts-coaches-consultants", "name": "AI Prompts for Coaches & Consultants", "url": "https://theageofai.gumroad.com"},
    {"num": "14", "slug": "youtube-content-creator-toolkit", "name": "YouTube Content Creator Toolkit", "url": "https://theageofai.gumroad.com"},
    {"num": "15", "slug": "ai-tools-real-estate-agents", "name": "AI Tools for Real Estate Agents", "url": "https://theageofai.gumroad.com"},
    {"num": "16", "slug": "notion-templates-freelancers", "name": "Notion Templates for Freelancers", "url": "https://theageofai.gumroad.com"},
    {"num": "17", "slug": "content-repurposing-playbook", "name": "Content Repurposing Playbook", "url": "https://theageofai.gumroad.com"},
    {"num": "18", "slug": "instagram-growth-templates", "name": "Instagram Growth Templates", "url": "https://theageofai.gumroad.com"},
    {"num": "19", "slug": "seo-checklist-bloggers", "name": "SEO Checklist for Bloggers", "url": "https://theageofai.gumroad.com"},
    {"num": "20", "slug": "ai-writing-toolkit-course-creators", "name": "AI Writing Toolkit for Course Creators", "url": "https://theageofai.gumroad.com"},
    {"num": "21", "slug": "client-onboarding-kit", "name": "Client Onboarding Kit", "url": "https://theageofai.gumroad.com"},
    {"num": "22", "slug": "solopreneur-productivity-system", "name": "Solopreneur Productivity System", "url": "https://theageofai.gumroad.com"},
    {"num": "23", "slug": "email-newsletter-templates", "name": "Email Newsletter Templates", "url": "https://theageofai.gumroad.com"},
    {"num": "24", "slug": "side-hustle-launch-checklist", "name": "Side Hustle Launch Checklist", "url": "https://theageofai.gumroad.com"},
    {"num": "25", "slug": "linkedin-content-calendar", "name": "LinkedIn Content Calendar", "url": "https://theageofai.gumroad.com"},
    {"num": "26", "slug": "podcast-launch-kit", "name": "Podcast Launch Kit", "url": "https://theageofai.gumroad.com"},
    {"num": "27", "slug": "freelancer-pricing-strategy-guide", "name": "Freelancer Pricing Strategy Guide", "url": "https://theageofai.gumroad.com"},
    {"num": "28", "slug": "digital-product-launch-checklist", "name": "Digital Product Launch Checklist", "url": "https://theageofai.gumroad.com"},
    {"num": "29", "slug": "pinterest-marketing-templates", "name": "Pinterest Marketing Templates", "url": "https://theageofai.gumroad.com"},
    {"num": "30", "slug": "ai-prompts-coaches-therapists", "name": "AI Prompts for Coaches & Therapists", "url": "https://theageofai.gumroad.com"},
]

SYSTEM_PROMPT = """You are Alan McCarthy, founder of The Age of AI blog. You write direct, practical content for solopreneurs, freelancers, and small business owners who want to use AI tools to work smarter. Your style is:
- Direct and no-fluff — get to the point fast
- Genuinely useful — teach something real in every article
- No corporate speak, no filler phrases like "In today's fast-paced world"
- Lead with the reader's problem, not the product
- Natural CTAs that don't feel pushy
- Conversational but authoritative — like advice from a smart friend who's done this stuff

You write for people who are busy and skeptical. Earn their attention."""

def generate_article_curl(product):
    prompt = f"""Write a Hugo blog post for The Age of AI blog that promotes the product: "{product['name']}" (available at {product['url']}).

The article should:
1. Have an SEO-optimized title targeting a real search query someone would type (not generic)
2. Be 600-800 words
3. Lead with the reader's problem — not the product
4. Teach something genuinely useful within the article itself (not just tease the product)
5. End with a natural, non-pushy CTA linking to the product
6. Tags should be relevant to the specific content (3-5 tags)

Return ONLY valid Hugo frontmatter + markdown, no commentary. Use this exact format:

---
title: "[SEO title targeting real search query]"
date: 2026-03-26
draft: false
description: "[Meta description, max 150 chars]"
categories: ["AI Tools", "Digital Products"]
tags: ["solopreneur", "AI tools", "productivity"]
product_url: "{product['url']}"
---

[Article body - 600-800 words, markdown formatted]

---
*Ready to put this into practice? Get the {product['name']} at {product['url']}*"""

    payload = {
        "model": "grok-3",
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": prompt}
        ],
        "temperature": 0.7,
        "max_tokens": 1500
    }

    payload_str = json.dumps(payload)

    result = subprocess.run(
        ["curl", "-s", "-X", "POST", API_URL,
         "-H", f"Authorization: Bearer {API_KEY}",
         "-H", "Content-Type: application/json",
         "-d", payload_str,
         "--max-time", "90"],
        capture_output=True, text=True, timeout=100
    )

    if result.returncode != 0:
        return None, f"curl error: {result.stderr}"

    try:
        data = json.loads(result.stdout)
        if "error" in data:
            return None, f"API error: {data['error']}"
        return data["choices"][0]["message"]["content"], None
    except Exception as e:
        return None, f"Parse error: {e} | stdout: {result.stdout[:200]}"

created = []
failed = []

for product in PRODUCTS:
    filename = f"product-article-{product['num']}-{product['slug']}.md"
    filepath = os.path.join(OUTPUT_DIR, filename)

    # Skip if already exists
    if os.path.exists(filepath):
        print(f"[SKIP] {filename} already exists")
        created.append(filename)
        continue

    print(f"[GEN] {product['num']}/30 — {product['name']}...", flush=True)

    content, err = generate_article_curl(product)

    if content is None:
        print(f"  [RETRY] Failed: {err}. Retrying in 5s...", flush=True)
        time.sleep(5)
        content, err = generate_article_curl(product)

    if content is None:
        print(f"  [FAIL] {filename}: {err}", flush=True)
        failed.append({"file": filename, "error": err})
        continue

    with open(filepath, "w") as f:
        f.write(content)

    print(f"  [OK] Saved {filename} ({len(content)} chars)", flush=True)
    created.append(filename)
    time.sleep(1)  # Be nice to the API

print("\n=== SUMMARY ===")
print(f"Created: {len(created)}")
print(f"Failed: {len(failed)}")
if failed:
    print("Failed files:")
    for f in failed:
        print(f"  - {f['file']}: {f['error']}")
