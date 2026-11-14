"""Tiny parser for Lua table literals (data only, never executes code).

Used by import_polestar.py to read Polestar's compiled guide files.
"""
import re

_tok = re.compile(r"""
    (?P<ws>\s+|--\[\[.*?\]\]|--[^\n]*)
  | (?P<str>"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*')
  | (?P<lstr>\[(?P<eq>=*)\[.*?\](?P=eq)\])
  | (?P<num>-?0x[0-9a-fA-F]+|-?\d+\.?\d*(?:[eE][-+]?\d+)?|-?\.\d+)
  | (?P<name>[A-Za-z_][A-Za-z0-9_]*)
  | (?P<op>[{}\[\]=,;().:])
""", re.S | re.X)

_esc = {"n": "\n", "t": "\t", "r": "\r", "\\": "\\", '"': '"', "'": "'", "a": "\a", "b": "\b", "f": "\f", "v": "\v", "\n": "\n"}


def _unquote(s):
    body = s[1:-1]
    out, i = [], 0
    while i < len(body):
        c = body[i]
        if c == "\\" and i + 1 < len(body):
            n = body[i + 1]
            if n.isdigit():
                m = re.match(r"\d{1,3}", body[i + 1:])
                out.append(chr(int(m.group(0))))
                i += 1 + len(m.group(0))
                continue
            out.append(_esc.get(n, n))
            i += 2
        else:
            out.append(c)
            i += 1
    return "".join(out)


class Parser:
    def __init__(self, text, env=None):
        self.text = text
        self.pos = 0
        self.env = env or {}

    def peek(self):
        save = self.pos
        t = self.next()
        self.pos = save
        return t

    def next(self):
        while True:
            m = _tok.match(self.text, self.pos)
            if not m:
                if self.pos >= len(self.text):
                    return ("eof", None)
                raise SyntaxError("bad token at %d: %r" % (self.pos, self.text[self.pos:self.pos + 40]))
            self.pos = m.end()
            k = m.lastgroup
            if k == "ws":
                continue
            if k == "eq":
                k = "lstr"
            v = m.group(0)
            if k == "str":
                return ("str", _unquote(v))
            if k == "lstr":
                eq = len(re.match(r"\[(=*)\[", v).group(1))
                return ("str", v[2 + eq:-(2 + eq)])
            if k == "num":
                return ("num", float(v) if any(c in v for c in ".eE") and not v.lower().startswith(("0x", "-0x")) else int(v, 0))
            return (k, v)

    def expect(self, v):
        t = self.next()
        if t[1] != v:
            raise SyntaxError("expected %r got %r at %d" % (v, t, self.pos))

    def value(self):
        k, v = self.next()
        if k in ("str", "num"):
            return v
        if k == "op" and v == "{":
            return self.table()
        if k == "name":
            if v == "true":
                return True
            if v == "false":
                return False
            if v == "nil":
                return None
            base = self.env.get(v)
            while self.peek() == ("op", "["):
                self.next()
                idx = self.value()
                self.expect("]")
                base = base[idx - 1] if isinstance(base, list) else (base or {}).get(idx)
            return base
        raise SyntaxError("unexpected %r at %d" % ((k, v), self.pos))

    def table(self):
        arr, d = [], {}
        while True:
            t = self.peek()
            if t == ("op", "}"):
                self.next()
                break
            if t == ("op", "["):
                self.next()
                key = self.value()
                self.expect("]")
                self.expect("=")
                d[key] = self.value()
            elif t[0] == "name" and t[1] not in ("true", "false", "nil"):
                save = self.pos
                self.next()
                if self.peek() == ("op", "="):
                    self.next()
                    d[t[1]] = self.value()
                else:
                    self.pos = save
                    arr.append(self.value())
            else:
                arr.append(self.value())
            sep = self.peek()
            if sep in (("op", ","), ("op", ";")):
                self.next()
        if d and arr:
            for i, v in enumerate(arr):
                d[i + 1] = v
            return d
        return d if d else arr


def parse_table_at(text, start, env=None):
    """Parse a table literal whose '{' is at or after `start`. Returns (value, end_pos)."""
    p = Parser(text, env)
    p.pos = text.index("{", start)
    p.next()
    v = p.table()
    return v, p.pos
