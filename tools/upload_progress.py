#!/usr/bin/env python3
"""Waypost companion: send your leveling progress to a website.

The addon cannot reach the web. It writes progress into its SavedVariables
file (WaypostDB.export); this script reads that file and POSTs it as JSON.
The game only writes the file on logout or /reload, so run this afterwards
(or use --watch to upload whenever the file changes).

  python3 tools/upload_progress.py --wow "C:/Games/World of Warcraft" --dry-run
  python3 tools/upload_progress.py --file path/to/WaypostDB.lua --url https://example.org/api/progress --token XYZ
  python3 tools/upload_progress.py --wow ... --url ... --watch

The default URL is the Dragon Warriors site; the endpoint has to exist on the
site for the upload to succeed. --dry-run prints the JSON and sends nothing.
Standard library only.
"""
import argparse
import glob
import json
import os
import sys
import time
import urllib.error
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from luadata import parse_table_at  # noqa: E402

DEFAULT_URL = "https://dragonwarriors.app/api/waypost/progress"


def find_saved_variables(wow_dir):
    """Every WaypostDB.lua under the WoW folder (one per account and client flavour)."""
    pattern = os.path.join(wow_dir, "**", "WTF", "Account", "*", "SavedVariables", "WaypostDB.lua")
    return sorted(glob.glob(pattern, recursive=True), key=os.path.getmtime, reverse=True)


def read_export(path):
    text = open(path, encoding="utf-8", errors="replace").read()
    start = text.find("WaypostDB = ")
    if start < 0:
        raise ValueError("no WaypostDB table in %s" % path)
    db, _ = parse_table_at(text, start)
    export = db.get("export") if isinstance(db, dict) else None
    if not export or not export.get("characters"):
        raise ValueError("no export data yet: log out of the game once with Waypost enabled")
    return export


def to_json(export):
    def clean(v):
        if isinstance(v, dict):
            return {str(k): clean(x) for k, x in v.items()}
        if isinstance(v, list):
            return [clean(x) for x in v]
        return v
    return {
        "schema": export.get("schema", 1),
        "addon": export.get("addon"),
        "updated": export.get("updated"),
        "characters": list(clean(export["characters"]).values()),
    }


def upload(payload, url, token):
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, method="POST", headers={
        "Content-Type": "application/json", "User-Agent": "waypost-companion/1"})
    if token:
        req.add_header("Authorization", "Bearer " + token)
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.status


def run_once(path, args):
    payload = to_json(read_export(path))
    names = ", ".join("%s (%s)" % (c.get("name"), c.get("level")) for c in payload["characters"])
    if args.dry_run:
        print(json.dumps(payload, indent=2, sort_keys=True))
        print("dry run: nothing sent. Characters: " + names, file=sys.stderr)
        return True
    try:
        status = upload(payload, args.url, args.token)
    except urllib.error.HTTPError as e:
        print("upload refused: HTTP %s %s" % (e.code, e.reason), file=sys.stderr)
        return False
    except urllib.error.URLError as e:
        print("could not reach %s: %s" % (args.url, e.reason), file=sys.stderr)
        return False
    print("uploaded %s -> HTTP %s" % (names, status))
    return True


def main():
    ap = argparse.ArgumentParser(description="Upload Waypost leveling progress.")
    ap.add_argument("--wow", help="World of Warcraft install folder (searched for WaypostDB.lua)")
    ap.add_argument("--file", help="path to a WaypostDB.lua SavedVariables file")
    ap.add_argument("--url", default=os.environ.get("WAYPOST_UPLOAD_URL", DEFAULT_URL))
    ap.add_argument("--token", default=os.environ.get("WAYPOST_UPLOAD_TOKEN"), help="API token (or WAYPOST_UPLOAD_TOKEN)")
    ap.add_argument("--dry-run", action="store_true", help="print the JSON, send nothing")
    ap.add_argument("--watch", action="store_true", help="keep running; upload whenever the file changes")
    args = ap.parse_args()

    path = args.file
    if not path:
        if not args.wow:
            ap.error("give --file or --wow")
        found = find_saved_variables(args.wow)
        if not found:
            sys.exit("no WaypostDB.lua under %s (log out of the game once first)" % args.wow)
        path = found[0]
    print("reading " + path, file=sys.stderr)

    if not args.watch:
        try:
            ok = run_once(path, args)
        except ValueError as e:
            sys.exit(str(e))
        sys.exit(0 if ok else 1)

    last = None
    while True:
        try:
            mtime = os.path.getmtime(path)
            if mtime != last:
                last = mtime
                try:
                    run_once(path, args)
                except ValueError as e:
                    print(str(e), file=sys.stderr)
        except OSError:
            pass
        time.sleep(15)


if __name__ == "__main__":
    main()
