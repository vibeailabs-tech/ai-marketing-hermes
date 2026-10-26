---
name: market-watch
description: "Weekly watch of client and competitor sites, reports changes"
version: 2.0.0
author: Hermes port of AI Marketing Suite
license: MIT
metadata:
  hermes:
    category: marketing
    tags: [marketing, blueprint, monitoring, competitors]
    related_skills: [market-competitors, market-audit]
    requires_toolsets: [terminal]
    config:
      - key: marketing.output_dir
        description: Folder where marketing deliverables are saved (one subfolder per client/domain)
        default: "~/marketing-reports"
        prompt: Marketing reports output folder
      - key: marketing.language
        description: Language for client-facing output (vi, en, ...)
        default: "vi"
        prompt: Report language (vi/en)
      - key: marketing.watchlist
        description: Text file listing the sites to watch (one URL per line)
        default: "~/marketing-reports/watchlist.txt"
        prompt: Path to the marketing watchlist file
    blueprint:
      schedule: "0 8 * * 1"
      deliver: origin
      prompt: "Run the market-watch skill: snapshot every site in the watchlist and report what changed since last week."
---

# Marketing Watch (weekly change monitor)

Snapshots every site in a watchlist (your clients and their competitors) and reports what changed since the previous run: headlines, CTAs, meta tags, pricing mentions, tracking tools, schema, social links and the automated marketing score.

## When to Use

- Scheduled run (blueprint, Mondays 08:00 by default). Installing this skill only adds a suggestion; accept it with `/suggestions`.
- The user asks "what changed on my competitors' sites?", "monitor these sites", or types `/market-watch`.
- The user wants to add or remove a site: edit the watchlist file (see Procedure step 1).

## Procedure

**Paths:** `${HERMES_SKILL_DIR}` is this skill's folder. If it still appears literally (older Hermes), use the `[Skill directory: ...]` path from the activation message, or find this skill's `SKILL.md` with `search_files` and use its folder.

1. **Watchlist.** Read the path from `marketing.watchlist` (default `~/marketing-reports/watchlist.txt`).
   - If it does not exist, copy `${HERMES_SKILL_DIR}/templates/watchlist.txt` there, then ask the user with `clarify` which sites to watch and write them into the file (one `Label | URL` per line). During a scheduled run with no watchlist, reply with setup instructions instead.
   - To add or remove sites on request, edit that file with `read_file` / `patch`.
2. **Snapshot and diff.** Run:
   `python3 ${HERMES_SKILL_DIR}/scripts/watch.py <watchlist> <marketing.output_dir>/_watch`
   The script (Python stdlib only, imports its sibling helpers `scripts/analyze_page.py` and `scripts/competitor_scanner.py`) saves `<output_dir>/_watch/<slug>/<date>.json` per site and prints a JSON report with `changes` per site compared with the most recent earlier snapshot.
3. **Interpret.** For each site with changes, explain in one or two lines what the change likely means for marketing (new offer, repositioned headline, new pricing, new tracking pixel = new ad campaigns, etc.). Skip the noise (minor word-count drift is already filtered).
4. **Optional deep check.** If a competitor changed its headline, pricing or main CTA, fetch that page with `web_extract` and quote the new copy.
5. **Save.** Write `WATCH-<date>.md` to `<marketing.output_dir>/_watch/` with a table per site (field, before, after, meaning) and a "Suggested actions" section for the client.
6. **Reply** in `marketing.language`, under 15 lines: sites with notable changes first, "no change" sites grouped on one line, then the absolute path of the report on its own line.

## Pitfalls

- The first run for a site has nothing to compare against (`first_run: true`). Report it as "baseline saved", not as "no change".
- Snapshots are compared with the latest earlier date, so running twice on the same day overwrites today's snapshot instead of creating a diff.
- Sites that block bots or render entirely with JavaScript return little or no text; report `status: error` or very low word counts as "could not read reliably" and suggest checking with the browser tools.

## Verification

- `<output_dir>/_watch/<slug>/<today>.json` exists for every reachable site.
- `WATCH-<date>.md` exists and its path is printed in the reply.
