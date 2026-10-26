#!/usr/bin/env python3
"""Add a path to skills.external_dirs in a Hermes config.yaml without rewriting the rest of the file.

Usage: python3 add_external_dir.py <config.yaml> <path>
Exit codes: 0 = added or already present, 2 = layout not understood (print manual instructions).
Comments and formatting elsewhere are preserved; a backup is written to <config>.bak-aims.
"""

import re
import shutil
import sys


def indent_of(line):
    return len(line) - len(line.lstrip(" "))


def is_content(line):
    s = line.strip()
    return bool(s) and not s.startswith("#")


def add(lines, path):
    item_text = path
    top = [i for i, l in enumerate(lines) if re.match(r"^skills:\s*(#.*)?$", l.rstrip("\n"))]
    if not top:
        if any(re.match(r"^skills:", l) for l in lines):
            return None  # inline value such as "skills: {}"
        tail = "" if not lines or lines[-1].endswith("\n") else "\n"
        return lines + [tail + "\nskills:\n", "  external_dirs:\n", f"    - {item_text}\n"]

    start = top[0]
    end = start + 1
    while end < len(lines) and (not is_content(lines[end]) or indent_of(lines[end]) > 0):
        end += 1
    block = range(start + 1, end)
    children = [i for i in block if is_content(lines[i])]
    child_indent = indent_of(lines[children[0]]) if children else 2

    ext = [i for i in children if indent_of(lines[i]) == child_indent
           and re.match(r"^\s*external_dirs:", lines[i])]
    if not ext:
        insert = [f"{' ' * child_indent}external_dirs:\n", f"{' ' * (child_indent + 2)}- {item_text}\n"]
        return lines[:start + 1] + insert + lines[start + 1:]

    e = ext[0]
    value = lines[e].split(":", 1)[1].split("#", 1)[0].strip()
    if value in ("[]", "~", "null"):
        lines = lines[:]
        lines[e] = f"{' ' * child_indent}external_dirs:\n"
        return lines[:e + 1] + [f"{' ' * (child_indent + 2)}- {item_text}\n"] + lines[e + 1:]
    if value:
        return None  # inline list like [a, b]

    last, item_indent = e, child_indent + 2
    for i in range(e + 1, end):
        if not is_content(lines[i]):
            continue
        if indent_of(lines[i]) <= child_indent:
            break
        if lines[i].lstrip().startswith("- "):
            item_indent = indent_of(lines[i])
        last = i
    return lines[:last + 1] + [f"{' ' * item_indent}- {item_text}\n"] + lines[last + 1:]


def main():
    config, path = sys.argv[1], sys.argv[2]
    try:
        with open(config, encoding="utf-8") as f:
            lines = f.readlines()
    except FileNotFoundError:
        lines = []
    if any(re.match(rf"^\s*-\s*['\"]?{re.escape(path)}['\"]?\s*(#.*)?$", l) for l in lines):
        print("already present")
        return 0
    new = add(lines, path)
    if new is None:
        return 2
    if lines:
        shutil.copyfile(config, config + ".bak-aims")
    with open(config, "w", encoding="utf-8") as f:
        f.writelines(new)
    try:
        import yaml
        data = yaml.safe_load("".join(new)) or {}
        if path not in ((data.get("skills") or {}).get("external_dirs") or []):
            raise ValueError("path not found after edit")
    except ImportError:
        pass
    except Exception as e:  # restore on any doubt
        if lines:
            shutil.copyfile(config + ".bak-aims", config)
        print(f"edit verification failed: {e}", file=sys.stderr)
        return 2
    print("added")
    return 0


if __name__ == "__main__":
    sys.exit(main())
