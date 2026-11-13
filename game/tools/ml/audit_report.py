"""A52 bias audit: aggregate tools/audit_outcomes.gd runs (normal + mirror per seed) into numbers for the report.

python tools/ml/audit_report.py <out_dir_with_sN_mode.json> <levers.json>
Prints markdown tables to stdout. Sides on an axis: a party is "+" if its position > +SIDE, "-" if < -SIDE.
Mirror test: in a fair engine, the "+" side's success in normal worlds equals the "-" side's success in mirrored
worlds (and vice versa). Uncertainty: bootstrap over seeds (paired normal/mirror).
"""
import glob
import json
import os
import sys

import numpy as np

AXES = ["ECON_ROLE", "REDISTRIBUTION", "LABOR", "ENVIRONMENT", "AUTONOMY", "FISCAL", "INSTITUTIONS", "SOVEREIGNTY"]
SIDE = 15000          # milli: positions beyond ±15 count as a side
RNG = np.random.default_rng(52)


def load(d):
    runs = {}
    for f in glob.glob(os.path.join(d, "s*_*.json")):
        r = json.load(open(f, encoding="utf-8"))
        runs[(r["seed"], r["mode"])] = r
    return runs


def side_stats(run, ax):
    """Per side (+/-): share of party-years as First Minister, mean support (%), seat share, donations per support pt."""
    out = {}
    py = run["party_years"]
    years = max((p["year"] for p in py), default=0)
    for s in (1, -1):
        mine = [p for p in py if s * p["pos"].get(ax, 0) > SIDE]
        pm_years = len([p for p in mine if p["pm"]])
        all_pm = max(1, len([p for p in py if p["pm"]]))
        sup = sum(p["support"] for p in mine) / 1000.0 / max(1, years)
        seats = sum(p["seats"] for p in mine) / max(1, years)
        don = sum(p["donations"] for p in mine)
        don_per = don / max(1.0, sum(p["support"] for p in mine) / 1000.0)
        press = np.mean([p["press"] for p in mine]) if mine else 0.0
        out[s] = {"pm": pm_years / all_pm, "support": sup, "seats": seats, "don_per": don_per, "press": press}
    return out


def boot(vals, n=2000):
    vals = np.asarray(vals, float)
    if len(vals) == 0:
        return float("nan"), float("nan"), float("nan")
    idx = RNG.integers(0, len(vals), (n, len(vals)))
    means = vals[idx].mean(axis=1)
    return float(vals.mean()), float(np.percentile(means, 5)), float(np.percentile(means, 95))


def mirror_table(runs):
    seeds = sorted({s for s, m in runs if (s, "mirror") in runs and (s, "normal") in runs})
    L = ["## Mirror test (12 seeds x 60 years, normal vs mirrored political space)", "",
         "Asymmetry = the + side's share of First Minister years in normal worlds minus the - side's share in "
         "mirrored worlds (where the same voters sit on the other side). 0 = fair. 90% interval from a bootstrap "
         "over seeds. Same for vote share (points).", "",
         "| axis (+ side) | FM-years asym. | 90% CI | vote asym. (pts) | 90% CI | seeds with both sides |",
         "|---|---|---|---|---|---|"]
    for ax in AXES:
        d_pm, d_sup = [], []
        for s in seeds:
            n = side_stats(runs[(s, "normal")], ax)
            m = side_stats(runs[(s, "mirror")], ax)
            d_pm.append(n[1]["pm"] - m[-1]["pm"])
            d_sup.append(n[1]["support"] - m[-1]["support"])
        a, lo, hi = boot(d_pm)
        b, blo, bhi = boot(d_sup)
        L.append(f"| {ax} | {a:+.2f} | {lo:+.2f} .. {hi:+.2f} | {b:+.1f} | {blo:+.1f} .. {bhi:+.1f} | {len(seeds)} |")
    return L, seeds


def delivery_table(runs):
    """Per Cabinet: change per year in unemployment, real income, debt, approval vs the FM party's ECON_ROLE and
    REDISTRIBUTION side, pooled over normal and mirror runs (economy outcome by ideology of who governs)."""
    L = ["", "## Who delivers? Economy during each Cabinet, by the First Minister's party side", "",
         "Change per year in office (end minus start, divided by years), Cabinets of at least 12 months, pooled over "
         "normal and mirrored runs. Mean with 90% bootstrap interval.", "",
         "| FM side | Cabinets | unemployment pts/yr | real income idx/yr | debt % GDP/yr | approval pts/yr |",
         "|---|---|---|---|---|---|"]
    for ax in ("ECON_ROLE", "REDISTRIBUTION", "FISCAL", "ENVIRONMENT"):
        for s, lab in ((1, "+"), (-1, "-")):
            rows = []
            for r in runs.values():
                for c in r["cabinets"]:
                    if c["months"] < 12 or s * c["pos"].get(ax, 0) <= SIDE:
                        continue
                    yrs = c["months"] / 12.0
                    i0, i1 = c["ind0"], c["ind1"]
                    rows.append([(i1.get(k, 0) - i0.get(k, 0)) / yrs for k in
                                 ("ECON_UNEMPLOYMENT_RATE", "ECON_REAL_INCOME_INDEX", "ECON_PUBLIC_DEBT_RATIO", "POL_GOV_APPROVAL")])
            if not rows:
                continue
            a = np.array(rows)
            cells = []
            for j in range(4):
                m, lo, hi = boot(a[:, j])
                cells.append(f"{m:+.2f} ({lo:+.2f}..{hi:+.2f})")
            L.append(f"| {ax} {lab} | {len(rows)} | " + " | ".join(cells) + " |")
    return L


def money_press_table(runs):
    L = ["", "## Money and press by side (normal runs)", "",
         "Donations per point of vote share (credits), and the circulation-weighted press closeness (higher = the "
         "press line is nearer the party). Mean over seeds.", "",
         "| axis | + side donations/pt | - side donations/pt | + side press | - side press |", "|---|---|---|---|---|"]
    for ax in AXES:
        dp, dm, pp, pm = [], [], [], []
        for (s, mode), r in runs.items():
            if mode != "normal":
                continue
            st = side_stats(r, ax)
            dp.append(st[1]["don_per"]); dm.append(st[-1]["don_per"])
            pp.append(st[1]["press"]); pm.append(st[-1]["press"])
        L.append(f"| {ax} | {np.mean(dp):,.0f} | {np.mean(dm):,.0f} | {np.mean(pp):+.2f} | {np.mean(pm):+.2f} |")
    return L


def hint_table(runs, levers):
    """Evidence (1000 = the law did what its hints promise) by the ideological lean of the change."""
    L = ["", "## Hint audit: did laws do what their hints promise, by ideological lean?", "",
         "Evidence = the colony's record a year after a change, relative to the hint (1.00 = as promised). A change's "
         "lean on an axis = sign(lever ideology weight x direction). If one side's laws systematically under- or "
         "over-deliver, the hints are biased.", "",
         "| axis | changes leaning + | mean evidence | changes leaning - | mean evidence |", "|---|---|---|---|---|"]
    ev = [e for r in runs.values() for e in r["evidence"]]
    for ax in AXES:
        plus, minus = [], []
        for e in ev:
            w = levers.get(e.get("lever", ""), {}).get("ideology", {}).get(ax, 0.0)
            if w == 0:
                continue
            (plus if w * e.get("dir", 0) > 0 else minus).append(e.get("evidence", 0) / 1000.0)
        if plus or minus:
            L.append(f"| {ax} | {len(plus)} | {np.mean(plus) if plus else float('nan'):.2f} | {len(minus)} | "
                     f"{np.mean(minus) if minus else float('nan'):.2f} |")
    by_lever = {}
    for e in ev:
        by_lever.setdefault(e.get("lever", "?"), []).append(e.get("evidence", 0) / 1000.0)
    L += ["", "Laws judged most often (mean evidence):", ""]
    for lid, v in sorted(by_lever.items(), key=lambda kv: -len(kv[1]))[:15]:
        L.append(f"- {lid}: {len(v)} judgements, mean {np.mean(v):.2f}, share at 0: {np.mean(np.array(v) == 0):.0%}")
    return L


def main():
    runs = load(sys.argv[1])
    levers = json.load(open(sys.argv[2], encoding="utf-8"))
    L, seeds = mirror_table(runs)
    L += delivery_table(runs)
    L += money_press_table(runs)
    L += hint_table(runs, levers)
    print(f"<!-- runs: {len(runs)}, paired seeds: {seeds} -->")
    print("\n".join(L))


if __name__ == "__main__":
    main()
