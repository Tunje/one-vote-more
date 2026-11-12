"""A53 L2: overnight strategy optimiser (CMA-ES in NumPy) for one party's genome.

Usage (from anywhere):
    python tools/ml/optimise.py [--hours 6] [--workers 24] [--pop 11] [--seeds 2] [--years 40]
Each generation plays pop genomes x seeds games in parallel (headless Godot, tools/ml/run_game.gd), plus the
default genome (all 500) on the same seeds as the yardstick. Everything goes to tools/ml/out/<date>/:
  evals.jsonl (every game), gens.jsonl (per generation), best.json, report.md.
Genes are searched in [0, 1] (x1000 = milli); 0.5 = today's behaviour.
"""
import argparse
import datetime
import json
import os
import subprocess
import time
from concurrent.futures import ThreadPoolExecutor

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "..", ".."))
GODOT = os.environ.get("GODOT", os.path.expanduser(
    r"~\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"))
GENES = ["G_DRIFT", "G_ISSUE", "G_NEGATIVE", "G_SPEND", "G_COALITION", "G_PORK", "G_PACE", "G_DISCIPLINE",
         "G_RESEARCH", "G_UNION"]
D = len(GENES)


def play(genome, seed, years, tmpdir, tag):
    gpath = "-"
    if genome is not None:
        gpath = os.path.join(tmpdir, f"g_{tag}.json")
        with open(gpath, "w") as f:
            json.dump({g: int(round(1000 * v)) for g, v in zip(GENES, genome)}, f)
    cmd = [GODOT, "--headless", "--path", GAME, "--script", "res://tools/ml/run_game.gd", "--",
           gpath, str(seed), str(years), "auto"]
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=years * 60,
                             encoding="utf-8", errors="replace").stdout
    except subprocess.TimeoutExpired:
        return {"error": "timeout", "seed": seed, "score": None}
    for line in out.splitlines():
        if line.startswith("SCORE "):
            return json.loads(line[6:])
    return {"error": "no score", "seed": seed, "score": None, "tail": out[-500:]}


class CMAES:
    """Plain (mu/mu_w, lambda)-CMA-ES, maximising."""

    def __init__(self, mean, sigma, lam):
        n = len(mean)
        self.n, self.m, self.sigma, self.lam = n, np.array(mean, float), sigma, lam
        self.mu = lam // 2
        w = np.log(self.mu + 0.5) - np.log(np.arange(1, self.mu + 1))
        self.w = w / w.sum()
        self.mueff = 1.0 / np.sum(self.w ** 2)
        self.cc = (4 + self.mueff / n) / (n + 4 + 2 * self.mueff / n)
        self.cs = (self.mueff + 2) / (n + self.mueff + 5)
        self.c1 = 2 / ((n + 1.3) ** 2 + self.mueff)
        self.cmu = min(1 - self.c1, 2 * (self.mueff - 2 + 1 / self.mueff) / ((n + 2) ** 2 + self.mueff))
        self.damps = 1 + 2 * max(0.0, np.sqrt((self.mueff - 1) / (n + 1)) - 1) + self.cs
        self.pc, self.ps, self.C = np.zeros(n), np.zeros(n), np.eye(n)
        self.chiN = np.sqrt(n) * (1 - 1 / (4 * n) + 1 / (21 * n * n))
        self.gen = 0
        self.B, self.Dg = np.eye(n), np.ones(n)

    def ask(self, rng):
        vals, vecs = np.linalg.eigh(self.C)
        self.B, self.Dg = vecs, np.sqrt(np.maximum(vals, 1e-12))
        z = rng.standard_normal((self.lam, self.n))
        y = z @ np.diag(self.Dg) @ self.B.T
        return np.clip(self.m + self.sigma * y, 0.0, 1.0)

    def tell(self, xs, fitness):
        idx = np.argsort(-np.asarray(fitness))[: self.mu]
        y = (xs[idx] - self.m) / self.sigma
        yw = self.w @ y
        self.m = np.clip(self.m + self.sigma * yw, 0.0, 1.0)
        invsqrt = self.B @ np.diag(1 / self.Dg) @ self.B.T
        self.ps = (1 - self.cs) * self.ps + np.sqrt(self.cs * (2 - self.cs) * self.mueff) * (invsqrt @ yw)
        self.gen += 1
        hs = float(np.linalg.norm(self.ps) / np.sqrt(1 - (1 - self.cs) ** (2 * self.gen))
                   < (1.4 + 2 / (self.n + 1)) * self.chiN)
        self.pc = (1 - self.cc) * self.pc + hs * np.sqrt(self.cc * (2 - self.cc) * self.mueff) * yw
        rank_mu = (y.T * self.w) @ y
        self.C = ((1 - self.c1 - self.cmu) * self.C
                  + self.c1 * (np.outer(self.pc, self.pc) + (1 - hs) * self.cc * (2 - self.cc) * self.C)
                  + self.cmu * rank_mu)
        self.sigma *= np.exp((self.cs / self.damps) * (np.linalg.norm(self.ps) / self.chiN - 1))
        self.sigma = float(np.clip(self.sigma, 0.02, 0.5))


def milli(x):
    return {g: int(round(1000 * v)) for g, v in zip(GENES, x)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--hours", type=float, default=6.0)
    ap.add_argument("--workers", type=int, default=24)
    ap.add_argument("--pop", type=int, default=11)   # 11 x 2 seeds + 2 baselines = 24 games = one wave on 24 workers
    ap.add_argument("--seeds", type=int, default=2)
    ap.add_argument("--years", type=int, default=40)
    ap.add_argument("--sigma", type=float, default=0.2)
    ap.add_argument("--max-gens", type=int, default=1000)
    ap.add_argument("--out", default=None)
    a = ap.parse_args()
    out = a.out or os.path.join(HERE, "out", datetime.date.today().isoformat())
    tmp = os.path.join(out, "tmp")
    os.makedirs(tmp, exist_ok=True)
    rng = np.random.default_rng(53)
    es = CMAES([0.5] * D, a.sigma, a.pop)
    deadline = time.time() + a.hours * 3600
    best = (-1e9, None, None)
    evals_f = open(os.path.join(out, "evals.jsonl"), "a", encoding="utf-8")
    gens_f = open(os.path.join(out, "gens.jsonl"), "a", encoding="utf-8")
    all_x, all_adv = [], []
    gen_secs = None
    while es.gen < a.max_gens:
        if gen_secs and time.time() + gen_secs > deadline:
            break
        t0 = time.time()
        seeds = [int(s) for s in rng.integers(1, 10000, a.seeds)]   # common random numbers within a generation
        xs = es.ask(rng)
        jobs = [(None, s, f"{es.gen}_base_{s}") for s in seeds]
        jobs += [(xs[i], s, f"{es.gen}_{i}_{s}") for i in range(a.pop) for s in seeds]
        with ThreadPoolExecutor(a.workers) as ex:
            res = list(ex.map(lambda j: play(j[0], j[1], a.years, tmp, j[2]), jobs))
        base = {s: r.get("score") for (g, s, _), r in zip(jobs, res) if g is None}
        fit, cnt = np.zeros(a.pop), np.zeros(a.pop)
        for (g, s, tag), r in zip(jobs, res):
            evals_f.write(json.dumps({"gen": es.gen, "tag": tag,
                                      "x": None if g is None else [round(float(v), 4) for v in g], **r}) + "\n")
            if g is None or r.get("score") is None or base.get(s) is None:
                continue
            i = int(tag.split("_")[1])
            fit[i] += r["score"] - base[s]
            cnt[i] += 1
        evals_f.flush()
        adv = np.where(cnt > 0, fit / np.maximum(cnt, 1), -1e3)   # advantage over the default genome, same seeds
        for i in range(a.pop):
            if cnt[i] > 0:
                all_x.append(xs[i])
                all_adv.append(adv[i])
        es.tell(xs, adv)
        bi = int(np.argmax(adv))
        if adv[bi] > best[0]:
            best = (float(adv[bi]), xs[bi].tolist(), es.gen - 1)
        gen_secs = time.time() - t0
        ok = cnt > 0
        rec = {"gen": es.gen - 1, "secs": round(gen_secs), "seeds": seeds, "base": base,
               "adv_best": float(adv[bi]), "adv_mean": float(adv[ok].mean()) if ok.any() else None,
               "failed": int(sum(1 for r in res if r.get("score") is None)), "sigma": es.sigma, "mean": milli(es.m)}
        gens_f.write(json.dumps(rec) + "\n")
        gens_f.flush()
        print(f"gen {rec['gen']}: {rec['secs']}s best {rec['adv_best']:+.2f} mean {rec['adv_mean']} "
              f"failed {rec['failed']} sigma {es.sigma:.3f}", flush=True)
        with open(os.path.join(out, "best.json"), "w", encoding="utf-8") as f:
            json.dump({"advantage": best[0], "gen": best[2], "genome": milli(best[1]), "mean_genome": rec["mean"]},
                      f, indent=1)
    report(out, es, best, np.array(all_x), np.array(all_adv))


def report(out, es, best, X, y):
    L = ["# A53 overnight optimiser report", "",
         f"Generations: {es.gen}. Each genome is scored as its advantage over the default genome (all 500) "
         "on the same seeds.", ""]
    if len(y) < D + 2:
        L.append("Too few evaluations for an importance estimate.")
    else:
        A = np.column_stack([np.ones(len(y)), X - 0.5])
        coef, *_ = np.linalg.lstsq(A, y, rcond=None)
        L += ["## Per-gene importance (linear fit: score change moving a gene from 500 to 1000)", "",
              "| gene | effect | final mean (milli) |", "|---|---|---|"]
        for i in np.argsort(-np.abs(coef[1:])):
            L.append(f"| {GENES[i]} | {coef[1 + i] * 0.5:+.2f} | {int(round(1000 * es.m[i]))} |")
        L.append("")
    L += ["## Best genome seen", "",
          f"Advantage over the default: {best[0]:+.2f} (generation {best[2]}; one generation's seeds only, "
          "so optimistic)", ""]
    if best[1]:
        for g, v in zip(GENES, best[1]):
            flag = "  <- at an extreme: exploit candidate for the A52 bias report" if v < 0.05 or v > 0.95 else ""
            L.append(f"- {g}: {int(round(1000 * v))}{flag}")
    L += ["", "## Final search mean (the more robust answer)", ""]
    for g, v in zip(GENES, es.m):
        L.append(f"- {g}: {int(round(1000 * v))}")
    with open(os.path.join(out, "report.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(L) + "\n")
    print("\n".join(L))


if __name__ == "__main__":
    main()
