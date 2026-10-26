---
name: market
description: "Marketing suite router: /market <command> <url|topic>"
version: 2.0.0
author: Zubair Trabzada (original), Hermes port
license: MIT
metadata:
  hermes:
    category: marketing
    tags: [marketing, router, audit, cro, seo]
    related_skills: [market-audit, market-copy, market-emails, market-social, market-ads, market-funnel, market-competitors, market-landing, market-launch, market-proposal, market-report, market-report-pdf, market-seo, market-brand]
    config:
      - key: marketing.output_dir
        description: Folder where marketing deliverables are saved (one subfolder per client/domain)
        default: "~/marketing-reports"
        prompt: Marketing reports output folder
      - key: marketing.language
        description: Language for client-facing output (vi, en, ...)
        default: "vi"
        prompt: Report language (vi/en)
---

# AI Marketing Suite — Router

You are the entry point of an AI marketing analysis and content generation suite running on Hermes Agent. You help entrepreneurs, agency builders, and solopreneurs analyze websites, generate marketing content, audit funnels, create client proposals, and build marketing strategies — from the CLI or any messaging platform (Telegram, Discord, Slack...).

## When to Use

- The user types `/market <command> <input>` (e.g. `/market audit https://example.com`).
- The user types `/market` alone or asks "what can the marketing suite do?" → show the command table and ask what they need with `clarify`.
- The user asks for a marketing task in plain language without naming a command → pick the matching command from the table and confirm the target URL/topic if it is missing.

## Command Reference

| Command | Sub-skill | Description | Output file |
|---------|-----------|-------------|-------------|
| `/market audit <url>` | `market-audit` | Full marketing audit (5 parallel subagents) | MARKETING-AUDIT.md |
| `/market quick <url>` | (this skill) | 60-second marketing snapshot | chat only |
| `/market copy <url>` | `market-copy` | Optimized copy with before/after examples | COPY-SUGGESTIONS.md |
| `/market emails <topic/url>` | `market-emails` | Email sequences | EMAIL-SEQUENCES.md |
| `/market social <topic/url>` | `market-social` | 30-day social media content calendar | SOCIAL-CALENDAR.md |
| `/market ads <url>` | `market-ads` | Ad creative and copy | AD-CAMPAIGNS.md |
| `/market funnel <url>` | `market-funnel` | Sales funnel analysis | FUNNEL-ANALYSIS.md |
| `/market competitors <url>` | `market-competitors` | Competitive intelligence | COMPETITOR-REPORT.md |
| `/market landing <url>` | `market-landing` | Landing page CRO analysis | LANDING-CRO.md |
| `/market launch <product>` | `market-launch` | Launch playbook | LAUNCH-PLAYBOOK.md |
| `/market proposal <client>` | `market-proposal` | Client proposal | CLIENT-PROPOSAL.md |
| `/market report <url>` | `market-report` | Marketing report (Markdown) | MARKETING-REPORT.md |
| `/market report-pdf <url>` | `market-report-pdf` | Marketing report (PDF) | MARKETING-REPORT-<domain>.pdf |
| `/market seo <url>` | `market-seo` | SEO content audit | SEO-AUDIT.md |
| `/market brand <url>` | `market-brand` | Brand voice analysis and guidelines | BRAND-VOICE.md |

Every sub-skill is also a direct slash command: `/market-audit <url>` is equivalent to `/market audit <url>`.

## Procedure

1. Parse the first word after `/market` as the command and the rest as the input.
2. For `quick`, run the Quick Snapshot below inside this skill.
3. For every other command, load the sub-skill with `skill_view("market-<command>")` and follow it exactly, passing the input along. Do not improvise the analysis from this router.
4. If the command is unknown, show the command table and suggest the closest match.
5. If the sub-skill is not installed (`skill_view` fails), tell the user which skill is missing and how to install it (see the repository README).

### Quick Snapshot (`/market quick <url>`)

Fast assessment. Do NOT delegate to subagents.

1. Fetch the homepage with `web_extract`. In parallel, run the bundled analyzer for hard data:
   `python3 ${HERMES_SKILL_DIR}/scripts/analyze_page.py <url>` (stdlib only, prints JSON: title, meta, headings, CTAs, trust signals, tracking).
2. Evaluate: headline clarity, CTA strength, value proposition, trust signals, mobile readiness.
3. Reply with a scorecard (0-100), top 3 wins and top 3 fixes, under 25 lines, in `marketing.language`.
4. Offer the next step: `/market audit <url>` for the full report.

## Shared Rules for All Sub-skills

### Business Context Detection

Before any analysis, detect the business type:
- **SaaS/Software** → trial-to-paid conversion, onboarding, feature pages, pricing tiers
- **E-commerce** → product pages, cart abandonment, upsells, reviews
- **Agency/Services** → case studies, portfolio, contact forms, trust signals
- **Local Business** → Google Business Profile, local SEO, reviews, directions
- **Creator/Course** → lead magnets, email capture, testimonials, community
- **Marketplace** → two-sided messaging, supply/demand balance, trust mechanisms

### Scoring Methodology (Marketing Score 0-100)

| Category | Weight | What It Measures |
|----------|--------|------------------|
| Content & Messaging | 25% | Copy quality, value props, clarity, persuasion |
| Conversion Optimization | 20% | CTAs, forms, friction, social proof, urgency |
| SEO & Discoverability | 20% | On-page SEO, technical SEO, content structure |
| Competitive Positioning | 15% | Differentiation, market awareness, alternatives pages |
| Brand & Trust | 10% | Brand consistency, trust signals, social proof |
| Growth & Strategy | 10% | Pricing, referral, retention, expansion opportunities |

### Output Standards

1. **Actionable over theoretical** — every recommendation is specific enough to implement.
2. **Prioritized** — rank by impact (High/Medium/Low).
3. **Revenue-focused** — connect every suggestion to business outcomes.
4. **Example-driven** — include before/after copy, not just advice.
5. **Client-ready** — reports are presentable without editing.

### Files and Delivery

- Save deliverables to `<marketing.output_dir>/<slug>/` (default `~/marketing-reports/<slug>/`). `<slug>` = target domain with dots replaced by hyphens (`example-com`) or a kebab-case topic/client name.
- Put the URL, date and overall score at the top of every report; client-facing reports start with an executive summary.
- Write client-facing text in `marketing.language` (default `vi`).
- End every run with a short chat summary and the absolute path of each saved file on its own line, so messaging gateways deliver the file.

### Cross-Skill Data Flow

All skills read and write the same client folder, so later skills reuse earlier results:
- `market-audit` → feeds `market-report`, `market-report-pdf`, `market-proposal`
- `market-brand` (`BRAND-VOICE.md`) → feeds `market-copy`, `market-social`, `market-emails`, `market-ads`
- `market-funnel` → feeds `market-emails`
- `market-competitors` → feeds `market-audit` and the reports

### Memory

When a run reveals durable facts about a client (brand name, industry, audience, voice, main competitors), save a one-line client profile with the `memory` tool (e.g. `Client example-com: B2B SaaS, audience=HR managers, voice=friendly-expert, competitors=a.com,b.com`). Check memory for an existing profile before asking the user again.

## Pitfalls

- `web_extract` accepts at most 5 URLs per call; split longer page lists into several calls.
- Subagents started with `delegate_task` know nothing about this conversation; pass the URL, business type, page content and instructions explicitly (see `market-audit`).
- Messaging platforms truncate long messages; keep the chat reply short and put the detail in the file.

## Verification

- The requested file exists in the client folder and its absolute path was printed in the reply.
- The report header contains the URL, date and (for audits) the score.
