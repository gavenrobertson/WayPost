#!/usr/bin/env python3
"""CI check: every TOC lists files that exist, targets the pinned client build,
and each addon's plain and _Forever TOC are identical."""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INTERFACE = "16001"
ADDONS = ["Waypost", "Waypost_Routes_Alliance", "Waypost_Routes_Horde", "Waypost_Routes_Extras"]
errors = []

for addon in ADDONS:
    base = os.path.join(ROOT, addon)
    tocs = [os.path.join(base, addon + suffix + ".toc") for suffix in ("", "_Forever")]
    texts = []
    for toc in tocs:
        if not os.path.isfile(toc):
            errors.append("missing " + os.path.relpath(toc, ROOT))
            continue
        text = open(toc, encoding="utf-8").read()
        texts.append(text)
        lines = [l.strip() for l in text.splitlines()]
        if "## Interface: " + INTERFACE not in lines:
            errors.append("%s: Interface is not %s" % (os.path.relpath(toc, ROOT), INTERFACE))
        for l in lines:
            if l and not l.startswith("#"):
                path = os.path.join(base, l.replace("\\", os.sep))
                if not os.path.isfile(path):
                    errors.append("%s lists a missing file: %s" % (os.path.relpath(toc, ROOT), l))
    if len(texts) == 2 and texts[0] != texts[1]:
        errors.append("%s: the two TOC files differ" % addon)

# every Lua file in the main addon is listed (nothing silently unloaded)
listed = {l.strip().replace("\\", "/") for l in open(os.path.join(ROOT, "Waypost", "Waypost.toc"), encoding="utf-8") if l.strip() and not l.startswith("#")}
for dirpath, _, files in os.walk(os.path.join(ROOT, "Waypost")):
    for f in files:
        if f.endswith(".lua"):
            rel = os.path.relpath(os.path.join(dirpath, f), os.path.join(ROOT, "Waypost")).replace(os.sep, "/")
            if rel not in listed:
                errors.append("Waypost/%s is not in the TOC" % rel)

for e in errors:
    print("TOC: " + e)
print("toc check: %d problem(s)" % len(errors))
sys.exit(1 if errors else 0)
