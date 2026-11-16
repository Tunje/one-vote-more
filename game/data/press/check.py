"""Checks the newspaper articles in articles/ against wanted.json. Run in this folder:  python check.py
Prints every problem it finds and how many of the wanted articles exist. Exit code 1 if any file is bad."""
import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
WORDS = {"LEAD": (110, 200), "SECOND": (50, 100), "BRIEF": (15, 45), "FOLLOWUP": (35, 80), "RETURN": (80, 155), "FEATURE": (140, 240)}
wanted = {r["file"]: r for r in json.load(io.open(os.path.join(HERE, "wanted.json"), encoding="utf-8"))["articles"]}
adir = os.path.join(HERE, "articles")
bad = 0
ok = 0


def problem(name, msg):
    global bad
    bad += 1
    print("%s: %s" % (name, msg))


for name in sorted(os.listdir(adir)) if os.path.isdir(adir) else []:
    if not name.endswith(".json"):
        continue
    if name not in wanted:
        problem(name, "not in wanted.json (wrong file name?)")
        continue
    w = wanted[name]
    try:
        d = json.load(io.open(os.path.join(adir, name), encoding="utf-8"))
    except Exception as e:  # malformed JSON
        problem(name, "not valid JSON: %s" % e)
        continue
    errs = []
    for k in ("event", "flavour", "stance", "kind"):
        if d.get(k) != w[k]:
            errs.append("%s is %r, wanted %r" % (k, d.get(k), w[k]))
    vs = d.get("variants")
    if not isinstance(vs, list) or len(vs) != w["variants"]:
        errs.append("needs exactly %d variants" % w["variants"])
        vs = vs if isinstance(vs, list) else []
    allowed = set(w["placeholders"])
    lo, hi = WORDS[w["kind"]]
    for i, v in enumerate(vs):
        if not isinstance(v, dict) or not all(isinstance(v.get(k), str) for k in ("headline", "sub", "body")):
            errs.append("variant %d: needs headline, sub and body as text" % (i + 1))
            continue
        text = v["headline"] + " " + v["sub"] + " " + v["body"]
        for ph in re.findall(r"\{([^{}]*)\}", text):
            if ph not in allowed:
                errs.append("variant %d: blank {%s} is not allowed here" % (i + 1, ph))
        if re.search(r"[{}]", re.sub(r"\{[^{}]*\}", "", text)):
            errs.append("variant %d: a stray curly brace" % (i + 1))
        if len(v["headline"]) > 60 or not v["headline"].strip():
            errs.append("variant %d: headline is empty or over 60 characters" % (i + 1))
        if len(v["sub"]) > 140:
            errs.append("variant %d: sub is over 140 characters" % (i + 1))
        n = len(v["body"].split())
        if n < lo or n > hi:
            errs.append("variant %d: body has %d words, wanted %d to %d" % (i + 1, n, lo, hi))
        if re.search(r"[<>*#`]|\n\s*[-•]\s", v["body"]):
            errs.append("variant %d: plain text only (no Markdown, HTML or lists)" % (i + 1))
        if w["kind"] in ("LEAD", "SECOND") and "{target}" not in text:
            errs.append("variant %d: use {target} at least once" % (i + 1))
    if len({v.get("headline") for v in vs if isinstance(v, dict)}) < len(vs):
        errs.append("two variants share a headline")
    if errs:
        for e in errs:
            problem(name, e)
    else:
        ok += 1
print("%d of %d wanted articles exist and pass; %d problems" % (ok, len(wanted), bad))
# pictures: named as in images_wanted.json, PNG, 800 x 500
import struct
iw = {r["file"] for r in json.load(io.open(os.path.join(HERE, "images_wanted.json"), encoding="utf-8"))["images"]}
idir = os.path.join(HERE, "images")
iok = 0
for name in sorted(os.listdir(idir)) if os.path.isdir(idir) else []:
    if name.startswith(".") or name.endswith(".import"):
        continue
    if name not in iw:
        problem(name, "not in images_wanted.json (wrong file name?)")
        continue
    with open(os.path.join(idir, name), "rb") as fh:
        head = fh.read(24)
    if head[:8] != b"PNG

":
        problem(name, "not a PNG file")
        continue
    wpx, hpx = struct.unpack(">II", head[16:24])
    if (wpx, hpx) != (800, 500):
        problem(name, "is %d x %d, wanted 800 x 500" % (wpx, hpx))
        continue
    iok += 1
print("%d of %d wanted pictures exist and pass" % (iok, len(iw)))
sys.exit(1 if bad else 0)
