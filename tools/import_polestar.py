#!/usr/bin/env python3
"""Build Waypost route packs from Polestar's compiled guides (GPL-3.0).

Polestar (https://github.com/fitzforge/polestar) ships its guides as compiled
Lua tables with quest givers, coordinates and names already resolved. This
script reads those files as *data* (it never executes them), trims every goal
to the fields Waypost uses, resolves the {npc:123}-style placeholders into
plain text, and writes:

  Waypost/Data/MapFrames.lua        Era map bounds (map coords -> world yards)
  Waypost/Data/Trainers.lua         Class trainers, for "train" goals
  Waypost/Data/Talents.lua          Leveling talent plans per class
  Waypost/Data/GuideIndex.lua       Guide metadata for the picker (no steps)
  Waypost_Routes_Alliance/Routes.lua  Load-on-demand Alliance leveling
  Waypost_Routes_Horde/Routes.lua     Load-on-demand Horde leveling
  Waypost_Routes_Extras/Routes.lua    Class, reputation, profession, ... guides

Route packs register each guide's steps as a function, so a guide's tables
are only built while it is the active guide (see Core/Guides.lua).

Usage:
  python3 -I tools/import_polestar.py /path/to/polestar
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from luadata import parse_table_at  # noqa: E402

ROOT = os.path.dirname(HERE)

# ---------------------------------------------------------------- reading

def read_guides(path):
    text = open(path, encoding="utf-8").read()
    out = []
    for m in re.finditer(r"-- Source: (\S+)\ndo\n", text):
        start = m.end()
        nxt = text.find("\n-- Source: ", start)
        blk = text[start: nxt if nxt > 0 else len(text)]
        env = {}
        for cm in re.finditer(r"local (\w+) = \{", blk):
            v, _ = parse_table_at(blk, cm.start(), env)
            env[cm.group(1)] = v
        rg = blk.find("RegisterGuide(")
        if rg < 0:
            continue
        g, _ = parse_table_at(blk, rg, env)
        g["_source"] = m.group(1)
        out.append(g)
    return out


def read_map_frames(path):
    text = open(path, encoding="utf-8").read()
    t, _ = parse_table_at(text, text.index("RegisterMapFrames("))
    return t["era"]

# ---------------------------------------------------------------- text

PH = re.compile(r"\{(npc|area|item|zone|quest|object|spell|skill|faction):(\d+)\}")


def make_resolver(g):
    names = g.get("names") or {}
    written = g.get("written") or {}

    def resolve(s):
        if not s or not isinstance(s, str):
            return s
        if s in written:
            return written[s]

        def rep(m):
            key = "%s:%s" % (m.group(1), m.group(2))
            return names.get(key) or {"npc": "the NPC", "item": "the item", "object": "the object"}.get(m.group(1), m.group(1))
        return PH.sub(rep, s)
    return resolve


def r2(v):
    if isinstance(v, float):
        v = round(v, 2)
        if v == int(v):
            return int(v)
    return v

# ---------------------------------------------------------------- goals

KEEP_TYPES = {
    "accept", "turnin", "complete", "kill", "collect", "interact", "talk", "use",
    "goto", "enter", "explore", "level", "train", "fly", "getfp", "sethome",
    "buy", "vendor", "note", "learn", "skill", "rep", "money", "die", "task", "craft",
}

trainers = {}


def only_of(o):
    if not o:
        return None
    out = {}
    for k in ("classes", "races", "factions"):
        if o.get(k):
            out[k] = list(o[k])
    return out or None


def convert_goal(go, resolve):
    t = go["t"]
    if t not in KEEP_TYPES:
        return None
    out = {"t": t}
    if go.get("quest"):
        out["quest"] = go["quest"]
        if go.get("title"):
            out["title"] = go["title"]
    if go.get("npcName"):
        out["npc"] = go["npcName"]
    if go.get("objName") and not out.get("npc"):
        out["npc"] = go["objName"]
    if go.get("map") and go.get("x") is not None:
        out["map"], out["x"], out["y"] = go["map"], r2(go["x"]), r2(go["y"])
        if go.get("f") == "e":
            out["era"] = True
    for src, dst in (("count", "count"), ("item", "item"), ("itemName", "itemName"), ("target", "target"),
                     ("oi", "oi"), ("level", "level"), ("location", "location"), ("spell", "spell"),
                     ("spellName", "spellName"), ("money", "money"), ("factionName", "factionName"),
                     ("faction", "faction"), ("standing", "standing"), ("profName", "skillName"),
                     ("profRank", "skillRank"), ("qlvl", "qlvl"), ("lvl", "mobLevel")):
        if go.get(src) is not None and go.get(src) != "":
            out[dst] = r2(go[src])
    if t == "skill" and go.get("skill") and "skillName" not in out:
        out["skillName"] = go.get("skill")
    if go.get("optional"):
        out["optional"] = True
    if go.get("group"):
        out["group"] = True
    if go.get("escort"):
        out["escort"] = True
    if go.get("class"):
        out["class"] = True
    o = only_of(go.get("only"))
    if o:
        out["only"] = o
    if go.get("note"):
        out["note"] = resolve(go["note"])
    if go.get("text"):
        out["text"] = resolve(go["text"])
    if go.get("objs") and t == "complete":
        out["objs"] = [resolve(o.get("text")) for o in go["objs"] if o.get("text")]
    if go.get("startItemName"):
        out["startItem"] = go.get("startItem")
        out["startItemName"] = go["startItemName"]
    # Where an item comes from: the creatures that drop it, or the object to loot.
    if t == "collect":
        names = [n.get("npcName") for n in (go.get("fromNpcs") or []) if n.get("npcName")]
        if names:
            out["src"] = ", ".join(names[:3]) + (" and others" if len(names) > 3 else "")
            out["srcKind"] = "npc"
        elif go.get("from"):
            out["src"] = go["from"]
            out["srcKind"] = go.get("fromKind") or "npc"
    sp = go.get("spotsPacked")
    if sp and t in ("kill", "collect", "interact", "use"):
        pts = []
        for chunk in sp.split(";")[:5]:
            parts = chunk.split(",")
            try:
                pts.append("%s,%s" % (parts[0], parts[1]))
            except IndexError:
                pass
        if len(pts) > 1:
            out["spots"] = ";".join(pts)
    for c in go.get("candidates") or []:
        if c and c.get("npc") and c.get("x") is not None and c.get("classes"):
            trainers[c["npc"]] = {
                "name": c.get("npcName"), "map": c["map"], "x": r2(c["x"]), "y": r2(c["y"]),
                "era": c.get("f") == "e", "classes": c.get("classes") or [], "faction": c.get("faction") or "AH",
            }
    return out


def convert_when(ws):
    out = []
    for w in ws or []:
        w = {k: v for k, v in w.items() if k in ("k", "neg", "q", "n", "item", "op", "name", "area", "spell", "skillLine", "label", "minLevel", "closedBy", "map")}
        out.append(w)
    return out or None


def convert_guide(g):
    resolve = make_resolver(g)
    steps = []
    for s in g.get("steps") or []:
        goals = [c for c in (convert_goal(go, resolve) for go in s.get("goals") or []) if c]
        if not goals and not s.get("note"):
            continue
        st = {"title": resolve(s.get("title")) or "Step"}
        if s.get("note"):
            st["note"] = resolve(s["note"])
        o = only_of(s.get("only"))
        if o:
            st["only"] = o
        w = convert_when(s.get("when"))
        if w:
            st["when"] = w
        if s.get("label"):
            st["label"] = s["label"]
        if s.get("section"):
            st["section"] = resolve(s["section"])
        st["goals"] = goals
        steps.append(st)
    out = {
        "id": g["id"].replace("forever/", ""),
        "title": resolve(g.get("title")),
        "category": g.get("category") or "Leveling",
        "minLevel": g.get("minLevel"),
        "maxLevel": g.get("maxLevel"),
        "zone": g.get("zoneName"),
        "source": "Polestar",
    }
    for k in ("faction", "why"):
        if g.get(k):
            out[k] = resolve(g[k])
    if g.get("races"):
        out["races"] = list(g["races"])
    if g.get("classes"):
        out["classes"] = list(g["classes"])
    if g.get("folder"):
        out["folder"] = g["folder"]
    if g.get("next"):
        out["next"] = g["next"].replace("forever/", "")
    out["steps"] = steps
    return out

# ---------------------------------------------------------------- lua output

IDENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
LUA_KEYWORDS = {"and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in",
                "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while"}


def lua_str(s):
    s = s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "")
    return '"' + s + '"'


def lua(v, indent=0, inline=False):
    if v is None:
        return "nil"
    if v is True:
        return "true"
    if v is False:
        return "false"
    if isinstance(v, (int, float)):
        return repr(r2(v))
    if isinstance(v, str):
        return lua_str(v)
    if isinstance(v, list):
        if inline:
            return "{" + ", ".join(lua(x, indent, True) for x in v) + "}"
        if all(not isinstance(x, (dict, list)) for x in v):
            return "{" + ", ".join(lua(x) for x in v) + "}"
        pad = "\t" * (indent + 1)
        return "{\n" + "".join(pad + lua(x, indent + 1) + ",\n" for x in v) + "\t" * indent + "}"
    if isinstance(v, dict):
        parts = []
        for k, x in v.items():
            if isinstance(k, str) and IDENT.match(k) and k not in LUA_KEYWORDS:
                key = k
            else:
                key = "[" + lua(k) + "]"
            parts.append((key, x))
        if inline:
            return "{ " + ", ".join("%s = %s" % (k, lua(x, indent, True)) for k, x in parts) + " }"
        flat = all(not isinstance(x, (dict, list)) or (isinstance(x, list) and all(not isinstance(y, (dict, list)) for y in x)) or (isinstance(x, dict) and len(x) <= 3 and all(not isinstance(y, dict) for y in x.values())) for _, x in parts)
        if flat and (inline or len(parts) <= 24):
            return "{ " + ", ".join("%s = %s" % (k, lua(x, indent, True)) for k, x in parts) + " }"
        pad = "\t" * (indent + 1)
        return "{\n" + "".join("%s%s = %s,\n" % (pad, k, lua(x, indent + 1)) for k, x in parts) + "\t" * indent + "}"
    raise TypeError(type(v))


def guide_lua(g):
    steps = g.pop("steps")
    lines = ["Waypost.RegisterSteps(%s, function() return {" % lua(g["id"])]
    for s in steps:
        goals = s.pop("goals")
        head = lua(s, 1, True)
        lines.append("\t" + head[:-2] + ", goals = {")
        for go in goals:
            lines.append("\t\t" + lua(go, 2, True) + ",")
        lines.append("\t} },")
    lines.append("} end)")
    g["steps"] = steps
    return "\n".join(lines)


HEADER = ("-- Generated by tools/import_polestar.py from Polestar's guides "
          "(https://github.com/fitzforge/polestar, GPL-3.0). Do not edit by hand.\n")


def write(path, body):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(HEADER + body + "\n")
    print("wrote", os.path.relpath(path, ROOT), "%.0f KB" % (os.path.getsize(path) / 1024))

# ---------------------------------------------------------------- talents

def read_talents(pdir):
    out = {}
    tdir = os.path.join(pdir, "talents", "forever")
    if not os.path.isdir(tdir):
        return out
    for fn in sorted(os.listdir(tdir)):
        if not fn.endswith(".json"):
            continue
        d = json.load(open(os.path.join(tdir, fn), encoding="utf-8"))
        builds = []
        for b in d.get("builds", []):
            picks = {}
            for p in b.get("picks", []):
                pk = {"tree": p["tree"], "talent": p["talent"], "rank": p.get("rank", 1)}
                if p.get("note"):
                    pk["note"] = p["note"]
                picks.setdefault(p["level"], []).append(pk)
            builds.append({"key": b.get("key"), "spec": b.get("spec"), "split": b.get("split"),
                           "picks": [{"level": lv, "picks": picks[lv]} for lv in sorted(picks)]})
        out[d["class"]] = {"summary": d.get("summary"), "source": d.get("source"), "url": d.get("sourceUrl"), "builds": builds}
    return out


def talents_lua(t):
    lines = ["Waypost.RegisterTalents({"]
    for cls, d in t.items():
        lines.append("\t%s = { summary = %s, source = %s, url = %s, builds = {" % (cls, lua(d["summary"] or ""), lua(d["source"] or ""), lua(d["url"] or "")))
        for b in d["builds"]:
            lines.append("\t\t{ key = %s, spec = %s, split = %s, levels = {" % (lua(b["key"]), lua(b["spec"]), lua(b["split"] or "")))
            for lv in b["picks"]:
                lines.append("\t\t\t[%d] = %s," % (lv["level"], lua(lv["picks"], 3, True)))
            lines.append("\t\t} },")
        lines.append("\t} },")
    lines.append("})")
    return "\n".join(lines)

# ---------------------------------------------------------------- main

def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    pdir = sys.argv[1]
    adir = os.path.join(pdir, "addon")
    raw = []
    for pack in ("Polestar_Guides_Alliance", "Polestar_Guides_Horde", "Polestar_Guides"):
        raw += read_guides(os.path.join(adir, pack, "Guides.lua"))
    guides = [convert_guide(g) for g in raw if g.get("category") != "Legacy"]
    packs = {"Alliance": [], "Horde": [], "Extras": []}
    for g in guides:
        if g["category"] == "Leveling" and g.get("faction") in ("Alliance", "Horde"):
            g["pack"] = "Waypost_Routes_" + g["faction"]
            packs[g["faction"]].append(g)
        else:
            g["pack"] = "Waypost_Routes_Extras"
            packs["Extras"].append(g)

    index = []
    for g in guides:
        meta = {k: g[k] for k in ("id", "title", "category", "minLevel", "maxLevel", "zone", "pack") if g.get(k) is not None}
        for k in ("faction", "races", "classes", "next", "folder", "why"):
            if g.get(k):
                meta[k] = g[k]
        meta["steps"] = len(g["steps"])
        index.append(meta)
    write(os.path.join(ROOT, "Waypost", "Data", "GuideIndex.lua"),
          "Waypost.RegisterIndex({\n" + "".join("\t" + lua(m, 1, True) + ",\n" for m in index) + "})")

    for name, lst in packs.items():
        body = "\n\n".join(guide_lua(g) for g in lst)
        write(os.path.join(ROOT, "Waypost_Routes_" + name, "Routes.lua"), body)

    frames = read_map_frames(os.path.join(adir, "Polestar_Guides", "MapFrames.lua"))
    body = "Waypost.RegisterMapFrames({\n" + "".join(
        "\t[%d] = { %s, %s, %s, %s, %s },\n" % (k, v["c"], r2(v["left"]), r2(v["right"]), r2(v["top"]), r2(v["bottom"]))
        for k, v in sorted(frames.items())) + "})"
    write(os.path.join(ROOT, "Waypost", "Data", "MapFrames.lua"), "-- [uiMapID] = { continent, left, right, top, bottom } (Era world yards)\n" + body)

    body = "Waypost.RegisterTrainers({\n" + "".join(
        "\t[%d] = %s,\n" % (k, lua(v, 1, True)) for k, v in sorted(trainers.items())) + "})"
    write(os.path.join(ROOT, "Waypost", "Data", "Trainers.lua"), body)

    t = read_talents(pdir)
    if t:
        write(os.path.join(ROOT, "Waypost", "Data", "Talents.lua"), talents_lua(t))

    print("guides:", {k: len(v) for k, v in packs.items()})


if __name__ == "__main__":
    main()
