#!/usr/bin/env python3
"""Validate the Hermes skill tree: frontmatter, referenced files, shared script copies, bundles."""

import hashlib
import json
import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
SKILLS = ROOT / "skills" / "marketing"
MAX_DESC = 60
MAX_BODY = 24000
FORBIDDEN = [r"\bWebFetch\b", r"\bWebSearch\b", r"Claude Code", r"~/\.claude"]
REF_RE = re.compile(r"(?:\$\{HERMES_SKILL_DIR\}/)?((?:scripts|templates|references|assets|examples)/[\w.\-/]+\.\w+)")

errors, warnings = [], []
names = set()

for skill_md in sorted(SKILLS.glob("*/SKILL.md")):
    d = skill_md.parent
    text = skill_md.read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        errors.append(f"{d.name}: missing frontmatter")
        continue
    _, fm_text, body = text.split("---\n", 2)
    try:
        fm = yaml.safe_load(fm_text)
    except yaml.YAMLError as e:
        errors.append(f"{d.name}: invalid YAML frontmatter: {e}")
        continue
    name, desc = fm.get("name"), fm.get("description", "")
    names.add(name)
    if name != d.name:
        errors.append(f"{d.name}: name '{name}' does not match directory")
    if not desc:
        errors.append(f"{d.name}: empty description")
    elif len(desc) > MAX_DESC:
        warnings.append(f"{d.name}: description is {len(desc)} chars (> {MAX_DESC})")
    hermes = (fm.get("metadata") or {}).get("hermes") or {}
    if hermes.get("category") != "marketing":
        errors.append(f"{d.name}: metadata.hermes.category should be 'marketing'")
    if len(body) > MAX_BODY:
        warnings.append(f"{d.name}: body is {len(body)} chars (> {MAX_BODY}, Hermes lint warns)")
    for pat in FORBIDDEN:
        for m in re.finditer(pat, body):
            errors.append(f"{d.name}: forbidden Claude-specific reference '{m.group(0)}'")
    for ref in sorted(set(REF_RE.findall(body))):
        if not (d / ref).is_file():
            errors.append(f"{d.name}: references missing file {ref}")
    for f in d.rglob("*"):
        if f.is_file() and f.name != "SKILL.md" and f.relative_to(d).as_posix() not in body:
            warnings.append(f"{d.name}: {f.relative_to(d)} is not referenced in SKILL.md (tap installs skip it)")
    for rel in hermes.get("related_skills") or []:
        if not (SKILLS / rel / "SKILL.md").is_file():
            errors.append(f"{d.name}: related skill '{rel}' does not exist")

# Shared scripts must stay identical across skills
copies = {}
for script in SKILLS.glob("*/scripts/*.py"):
    copies.setdefault(script.name, {})[script.parent.parent.name] = hashlib.md5(script.read_bytes()).hexdigest()
for script, by_skill in copies.items():
    if len(set(by_skill.values())) > 1:
        errors.append(f"scripts/{script} differs between skills: {sorted(by_skill)} (copy the canonical version)")

for bundle in sorted((ROOT / "bundles").glob("*.yaml")):
    data = yaml.safe_load(bundle.read_text(encoding="utf-8"))
    for s in data.get("skills", []):
        if s not in names:
            errors.append(f"bundle {bundle.name}: unknown skill '{s}'")

grouped = {s for g in json.loads((ROOT / "skills.sh.json").read_text())["groupings"] for s in g["skills"]}
for missing in sorted(names - grouped):
    warnings.append(f"skills.sh.json: '{missing}' not in any grouping")
for unknown in sorted(grouped - names):
    errors.append(f"skills.sh.json: unknown skill '{unknown}'")

for w in warnings:
    print("WARN ", w)
for e in errors:
    print("ERROR", e)
print(f"\n{len(names)} skills, {len(errors)} errors, {len(warnings)} warnings")
sys.exit(1 if errors else 0)
