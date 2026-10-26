---
name: market-audit
description: "Full 6-dimension website marketing audit (parallel agents)"
version: 2.0.0
author: Zubair Trabzada (original), Hermes port
license: MIT
metadata:
  hermes:
    category: marketing
    tags: [marketing, audit, cro, seo, scoring]
    related_skills: [market-report, market-report-pdf, market-proposal]
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

# Marketing Audit Orchestrator

## Hermes Runtime (read first)

- **Invocation:** `/market-audit <input>` or through the router `/market audit <input>`. Everything after the command is the user's input.
- **Fetching:** use `web_extract` to read pages (max 5 URLs per call, batch longer lists) and `web_search` for discovery. If the web toolset is unavailable, fall back to `terminal` with `curl -sL <url>`.
- **Files:** save deliverables in `<marketing.output_dir>/<slug>/` (default `~/marketing-reports/<slug>/`), where `<slug>` is the target domain with dots replaced by hyphens (`example-com`) or a short kebab-case topic name. Create the folder first. Wherever this skill says "save to `X.md`", use that folder; look there for outputs of other `market-*` skills too.
- **Language:** write client-facing output in `marketing.language` (default `vi` = Vietnamese). Keep standard marketing terms (CTA, CRO, SEO, ROAS...) and file names in English.
- **Missing info:** if a required input (URL, product, audience, offer, budget) is missing, ask once with `clarify`, batching all questions in one call, instead of guessing.
- **Reply:** finish with a short chat summary (at most ~15 lines; messaging apps truncate long replies) and put the absolute path of every saved file on its own line so the gateway delivers it as an attachment.

You are the full marketing audit engine for `/market audit <url>`. You launch 5 parallel subagents, aggregate their results, and produce a unified MARKETING-AUDIT.md report that is client-ready and revenue-focused.

## When This Skill Is Invoked

The user runs `/market audit <url>`. This is the flagship command of the entire suite. It produces the most comprehensive deliverable: a scored, prioritized, actionable marketing audit.

---

## Phase 1: Discovery (Pre-Analysis)

Before launching subagents, perform these discovery steps:

### 1.1 Fetch the Target URL

1. Use `web_extract` on the homepage first, then on up to 5 key interior pages found in its navigation (pricing, about, product/features, blog, contact). `web_extract` takes at most 5 URLs per call, so this is two calls.
2. Run the bundled analyzer for hard technical data (stdlib only, prints JSON):
   `python3 ${HERMES_SKILL_DIR}/scripts/analyze_page.py <url>`
3. Keep a condensed digest of each page (headlines, CTAs, offers, pricing, proof, nav links). Subagents receive this digest, not the full raw HTML, to stay within their context.

### 1.2 Detect Business Type

Classify the business into one of these categories. This classification shapes every subagent's analysis focus:

| Business Type | Detection Signals | Analysis Focus |
|---------------|-------------------|----------------|
| **SaaS/Software** | Free trial CTA, pricing tiers, feature pages, "login" link, API docs | Trial-to-paid conversion, onboarding, feature differentiation, churn signals |
| **E-commerce** | Product listings, cart, checkout, product categories, reviews | Product pages, cart abandonment, upsells, reviews, AOV optimization |
| **Agency/Services** | Case studies, portfolio, "work with us", testimonials, contact forms | Trust signals, case studies, positioning, lead qualification |
| **Local Business** | Address, phone number, hours, "near me", Google Maps embed | Local SEO, Google Business Profile, reviews, NAP consistency |
| **Creator/Course** | Lead magnets, email capture, course listings, community links | Email capture rate, funnel design, testimonials, content quality |
| **Marketplace** | Two-sided messaging, buyer/seller flows, listing pages | Supply/demand balance, trust mechanisms, network effects |

### 1.3 Identify Key Pages

Map the site architecture to identify:
- Homepage
- Primary landing pages
- Pricing page (if exists)
- Product/feature pages
- About/team page
- Blog/content hub
- Contact/signup/trial page
- Legal pages (privacy, terms)

Store this page map for all subagents to reference.

---

## Phase 2: Analysis (Parallel Subagent Execution)

Launch all 5 subagents in ONE `delegate_task` call with a `tasks` batch. Subagents start with a blank context and cannot see this conversation or this skill, so each task must carry everything it needs.

**Build each task like this:**

1. Read the matching brief from this skill's `references/` folder (`read_file` on `${HERMES_SKILL_DIR}/references/<brief>.md`, or `skill_view("market-audit", "references/<brief>.md")`).
2. Create one task per brief:

| Task | Brief file | Scores to return |
|------|------------|------------------|
| Content & Messaging | `references/market-content.md` | content |
| Conversion Optimization | `references/market-conversion.md` | conversion |
| Competitive Positioning | `references/market-competitive.md` | competitive |
| SEO & Technical | `references/market-technical.md` | seo |
| Brand, Trust & Growth | `references/market-strategy.md` | brand, growth |

```
delegate_task(tasks=[
  {
    "goal": "Act as the <dimension> analyst in a marketing audit of <url> and return your section in the brief's Output Format.",
    "context": "<full text of the brief>\n\nTARGET: <url>\nBUSINESS TYPE: <type>\nPAGE MAP: <list of URLs>\nPAGE DIGEST: <condensed content from Phase 1>\nANALYZER JSON: <analyze_page.py output, technical task only>\nLANGUAGE: write findings in <marketing.language>.\nTOOLS: use web_extract (max 5 URLs/call) and web_search if you need more pages.",
    "output_schema": {
      "type": "object",
      "properties": {
        "scores": {"type": "object", "description": "Dimension scores on a 0-10 scale, e.g. {\"content\": 7}"},
        "markdown": {"type": "string", "description": "The full section in the brief's Output Format"}
      },
      "required": ["scores", "markdown"]
    }
  },
  ... one entry per row of the table above ...
])
```

3. Wait until all 5 results are back before Phase 3; results may arrive as separate messages. If a result has `schema_valid: false`, extract the scores from its raw `summary` text instead of re-running it.

The five dimension descriptions below are what each brief covers; use them to sanity-check the returned sections.

### Subagent 1: market-content

**Focus:** Content quality, messaging clarity, copy effectiveness

Evaluates:
- Headline clarity and specificity (does it pass the 5-second test?)
- Value proposition strength (is the unique value immediately obvious?)
- Body copy persuasion (does it speak to pain points and desired outcomes?)
- Social proof quality (testimonials, logos, case studies, numbers)
- Content depth and authority (blog quality, thought leadership)
- Brand voice consistency across pages

**Scores:** Content & Messaging (0-100)

### Subagent 2: market-conversion

**Focus:** CRO, funnels, landing pages, signup flows

Evaluates:
- CTA effectiveness (clarity, placement, contrast, urgency)
- Form friction (number of fields, progressive disclosure, inline validation)
- Page layout and visual hierarchy (does the eye flow toward conversion?)
- Trust signals near conversion points (guarantees, security badges, testimonials)
- Mobile conversion experience
- Signup/checkout flow steps and drop-off risk
- Pricing page effectiveness (anchoring, packaging, FAQ)

**Scores:** Conversion Optimization (0-100)

### Subagent 3: market-competitive

**Focus:** Competitive positioning, market landscape

Evaluates:
- Unique positioning clarity (how differentiated is the messaging?)
- Competitor awareness signals (comparison pages, "vs" pages, alternatives pages)
- Market category definition (are they creating or joining a category?)
- Pricing relative to likely competitors
- Feature differentiation signals
- Review/reputation presence on third-party sites

**Scores:** Competitive Positioning (0-100)

### Subagent 4: market-technical

**Focus:** Technical SEO, site architecture, page speed

Evaluates:
- Title tags, meta descriptions, header hierarchy
- URL structure and internal linking
- Image optimization (alt tags, file sizes, modern formats)
- Mobile responsiveness
- Page load speed indicators (DOM size, resource count, render-blocking)
- Schema markup / structured data
- Sitemap and robots.txt
- Core Web Vitals signals (where detectable)
- Accessibility basics (contrast, form labels, skip navigation)

**Scores:** SEO & Discoverability (0-100)

### Subagent 5: market-strategy

**Focus:** Overall strategy, pricing, growth opportunities

Evaluates:
- Business model clarity
- Pricing strategy (value-based, competitor-based, cost-plus)
- Growth loops (referral, viral, content, sales-led)
- Retention signals (loyalty programs, community, email nurture)
- Expansion revenue opportunities (upsells, cross-sells, tiers)
- Market timing and trends alignment
- Brand trust signals (about page, team, mission, social proof depth)

**Scores:** Brand & Trust (0-100), Growth & Strategy (0-100)

---

## Phase 3: Synthesis (Aggregation and Scoring)

### 3.1 Scoring Methodology

The subagent briefs score on a 0-10 scale; multiply by 10 to get each 0-100 category score. Then compute the composite Marketing Score using weighted averages:

```
Marketing Score = (
    Content_Score      * 0.25 +
    Conversion_Score   * 0.20 +
    SEO_Score          * 0.20 +
    Competitive_Score  * 0.15 +
    Brand_Score        * 0.10 +
    Growth_Score       * 0.10
)
```

**Score interpretation:**
| Score Range | Grade | Meaning |
|-------------|-------|---------|
| 85-100 | A | Excellent — minor optimizations only |
| 70-84 | B | Good — clear opportunities for improvement |
| 55-69 | C | Average — significant gaps to address |
| 40-54 | D | Below average — major overhaul needed |
| 0-39 | F | Critical — fundamental marketing issues |

### 3.2 Aggregate Recommendations

Collect all recommendations from subagents and classify them:

**Quick Wins** (implement in < 1 week, low effort, high impact):
- Copy changes to headlines and CTAs
- Adding missing meta descriptions
- Adding trust signals near CTAs
- Fixing broken links or images
- Adding urgency or social proof

**Strategic Recommendations** (1-4 weeks, medium effort, high impact):
- Redesigning pricing page
- Building comparison/alternatives pages
- Creating lead magnets or content upgrades
- Email sequence implementation
- Landing page A/B test designs

**Long-Term Initiatives** (1-3 months, high effort, transformative impact):
- Content marketing strategy overhaul
- SEO content gap campaign
- Funnel redesign
- Brand repositioning
- New growth channel development

### 3.3 Revenue Impact Estimates

For each recommendation, estimate the revenue impact:

```
Revenue Impact Formula:
  Current Monthly Traffic x Conversion Rate Improvement x Average Deal Value
  = Estimated Monthly Revenue Lift

Example:
  10,000 visitors x 0.5% conversion lift x $99 ARPU = $4,950/month
```

Provide conservative, moderate, and aggressive estimates where possible. Use these qualifiers:

| Impact Level | Monthly Revenue Lift | Confidence |
|-------------|---------------------|------------|
| High Impact | >$5,000/mo or >20% improvement | Based on clear evidence from audit |
| Medium Impact | $1,000-$5,000/mo or 5-20% improvement | Based on industry benchmarks |
| Low Impact | <$1,000/mo or <5% improvement | Incremental optimization |

### 3.4 Competitor Comparison Table

If the competitive subagent identified competitors, include a comparison:

```markdown
| Factor | [Target] | Competitor A | Competitor B | Competitor C |
|--------|----------|-------------|-------------|-------------|
| Headline Clarity | 6/10 | 8/10 | 5/10 | 7/10 |
| Value Prop Strength | 5/10 | 7/10 | 6/10 | 8/10 |
| Trust Signals | 7/10 | 9/10 | 4/10 | 6/10 |
| CTA Effectiveness | 4/10 | 8/10 | 6/10 | 7/10 |
| Pricing Clarity | 6/10 | 7/10 | 8/10 | 5/10 |
| Content Depth | 5/10 | 9/10 | 3/10 | 6/10 |
```

---

## Output Format: MARKETING-AUDIT.md

Write the final report to `MARKETING-AUDIT.md` in the client output folder with this structure:

```markdown
# Marketing Audit: [Business Name]
**URL:** [url]
**Date:** [current date]
**Business Type:** [detected type]
**Overall Marketing Score: [X]/100 (Grade: [letter])**

---

## Executive Summary

[3-5 paragraph summary for a non-technical stakeholder. Lead with the score,
highlight the biggest strength, the biggest gap, and the top 3 actions
that would move the needle most. Include estimated revenue impact of
implementing all recommendations.]

---

## Score Breakdown

| Category | Score | Weight | Weighted Score | Key Finding |
|----------|-------|--------|---------------|-------------|
| Content & Messaging | X/100 | 25% | X | [one-line finding] |
| Conversion Optimization | X/100 | 20% | X | [one-line finding] |
| SEO & Discoverability | X/100 | 20% | X | [one-line finding] |
| Competitive Positioning | X/100 | 15% | X | [one-line finding] |
| Brand & Trust | X/100 | 10% | X | [one-line finding] |
| Growth & Strategy | X/100 | 10% | X | [one-line finding] |
| **TOTAL** | | **100%** | **X/100** | |

---

## Quick Wins (This Week)

[Numbered list of 5-10 quick wins with specific implementation steps.
Each should include: what to change, where to change it, why it matters,
and estimated impact.]

## Strategic Recommendations (This Month)

[Numbered list of 3-7 strategic recommendations with rationale,
implementation steps, and expected outcomes.]

## Long-Term Initiatives (This Quarter)

[Numbered list of 2-5 long-term initiatives with business case,
resource requirements, and projected ROI.]

---

## Detailed Analysis by Category

### Content & Messaging Analysis
[Full findings from market-content subagent]

### Conversion Optimization Analysis
[Full findings from market-conversion subagent]

### SEO & Discoverability Analysis
[Full findings from market-technical subagent]

### Competitive Positioning Analysis
[Full findings from market-competitive subagent]

### Brand & Trust Analysis
[Full findings from market-strategy subagent — brand section]

### Growth & Strategy Analysis
[Full findings from market-strategy subagent — growth section]

---

## Competitor Comparison

[Comparison table from Section 3.4]

---

## Revenue Impact Summary

| Recommendation | Est. Monthly Impact | Confidence | Timeline |
|---------------|-------------------|------------|----------|
| [recommendation 1] | $X,XXX | High/Med/Low | X weeks |
| [recommendation 2] | $X,XXX | High/Med/Low | X weeks |
| ... | | | |
| **Total Potential** | **$XX,XXX/mo** | | |

---

## Next Steps

1. [Most critical action item]
2. [Second priority]
3. [Third priority]

*Generated by AI Marketing Suite — `/market audit`*
```

---

## Chat Summary

In addition to the file, reply in chat with a condensed summary:

```
=== MARKETING AUDIT COMPLETE ===

Business: [name] ([type])
URL: [url]
Marketing Score: [X]/100 (Grade: [letter])

Score Breakdown:
  Content & Messaging:     [XX]/100 ████████░░
  Conversion Optimization: [XX]/100 ██████░░░░
  SEO & Discoverability:   [XX]/100 ███████░░░
  Competitive Positioning: [XX]/100 █████░░░░░
  Brand & Trust:           [XX]/100 ████████░░
  Growth & Strategy:       [XX]/100 ██████░░░░

Top 3 Quick Wins:
  1. [win]
  2. [win]
  3. [win]

Top 3 Strategic Moves:
  1. [move]
  2. [move]
  3. [move]

Estimated Revenue Impact: $X,XXX-$XX,XXX/month

/absolute/path/to/marketing-reports/<slug>/MARKETING-AUDIT.md
```

Keep the chat version short: score, the six category scores, top 3 quick wins, then the absolute file path on its own line. The full detail lives in the file.

---

## Error Handling

- If the URL is unreachable, report the error and suggest checking the URL
- If a subagent fails, continue with remaining subagents and note the gap in the report
- If `delegate_task` is unavailable (delegation toolset disabled), run the five briefs sequentially yourself, in the same order, and keep each section short
- If the web toolset is unavailable, gather page data with `python3 ${HERMES_SKILL_DIR}/scripts/analyze_page.py <url>` and `python3 ${HERMES_SKILL_DIR}/scripts/competitor_scanner.py <url1> <url2> ...` and pass that JSON to the subagents
- If the site is behind authentication, note what was accessible and recommend manual review for gated content
- If the site has very little content (single page), adapt the analysis accordingly and note limited scope

## Cross-Skill Integration

- If `COMPETITOR-REPORT.md` exists in the client output folder, incorporate its findings
- If `BRAND-VOICE.md` exists, use it to contextualize content analysis
- Reference other available analyses in the executive summary
- Suggest follow-up commands: `/market copy`, `/market funnel`, `/market competitors` for deeper dives
- Offer `/market report-pdf <url>` to turn this audit into a client-ready PDF, and `/market proposal <client>` to turn it into a sales proposal

## Pitfalls

- Subagents know nothing except their `goal` and `context`. A task that says "analyze the site" without the brief, URL and page digest produces generic output.
- Do not paste full raw HTML into subagent context; send the condensed digest and let subagents fetch extra pages themselves.
- Scores from briefs are 0-10. Forgetting to multiply by 10 makes the composite score wrong by an order of magnitude.

## Verification

- `MARKETING-AUDIT.md` exists in `<marketing.output_dir>/<slug>/` and contains all six category sections.
- The composite score equals the weighted sum shown in the Score Breakdown table.
- The chat reply ends with the absolute path of the report.
