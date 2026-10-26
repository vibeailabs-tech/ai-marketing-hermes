# AGENTS.md

Hermes Agent skill suite for marketing (port of zubair-trabzada/ai-marketing-claude).

## Layout
- `skills/marketing/<skill>/SKILL.md` — one directory per skill; directory name = `name` in frontmatter.
- Supporting files live inside the skill that uses them (`scripts/`, `templates/`, `references/`) and must be referenced from that skill's SKILL.md, otherwise `hermes skills install` from GitHub will not copy them.
- Reference bundled files as `${HERMES_SKILL_DIR}/scripts/<file>` (Hermes substitutes the absolute skill path).
- `analyze_page.py` / `competitor_scanner.py` are duplicated across skills on purpose; edit the copy in `market-seo` / `market-competitors`, then copy it to the others.

## Conventions
- Frontmatter: quoted `description` ≤ 60 chars, `metadata.hermes.category: marketing`, shared config keys `marketing.output_dir` and `marketing.language`.
- Use Hermes tool names: `web_extract` (≤ 5 URLs/call), `web_search`, `terminal`, `read_file`, `write_file`, `delegate_task`, `clarify`, `memory`, `image_generate`. Never Claude Code names (WebFetch, WebSearch, Task).
- Helper scripts: Python 3.8+ stdlib only (PDF generator needs `reportlab`).

## Verification
```bash
python3 tools/validate.py                      # frontmatter, references, script copies, bundles (needs PyYAML)
HOME=/tmp/h ./install.sh && HERMES_HOME=/tmp/h/.hermes hermes skills list < /dev/null   # Hermes sees 16 marketing skills
python3 skills/marketing/market-report-pdf/scripts/generate_pdf_report.py   # demo PDF
```
