# MEDIA M3: voter hookup patch (for Wilma's review)

**From:** Anni · **Target:** `game/sim/politics/politics_provider.gd`, `_update_opinion` (Wilma's file; not applied) · **Spec:** spec-media-v1 §7

Media fills these fields on every voter group (leaf or cell, pop > 0) at the end of JUSTICE, in the same month and before POLITICS:

| Field | Shape | Meaning |
|---|---|---|
| `news_blame` | int | Delta to the approval *target*, in the same units as the fact term (impact × salience/1000 × share × 400). It is already scaled by K_BLAME 0.5. Distortion only: about 0 with one neutral paper. |
| `news_bias` | {concern: int} | Milli sat points. Perceived sat = actual + bias. Belief state: decays 25% a month and mixes on transfer. |
| `news_agenda` | {concern: int} | Raw salience points, ±60, added like the existing agenda term. |
| `diet`, `trust` | {out: ‰}, {out: milli} | `MediaQuery.weight(cell, out)` = diet × trust, 0..1. |

All four reads use `.get(..., default)`, so the patch is a no-op for groups that media hasn't reached yet, and a no-op for old saves.

## 1. Perceived satisfaction (line ~202)

```gdscript
		var nb: Dictionary = cell.get("news_bias", {})
		for c in PolDefs.CONCERNS:
			var actual := int(round(num[c] / den[c])) if den.get(c, 0.0) > 0.0 else 50000
			cell["sat"][c] = clampi(actual + int(nb.get(c, 0)), 0, 100000)   # media: perceived = actual + bias (facts unchanged)
```

## 2. Salience (line ~210)

```gdscript
		var na: Dictionary = cell.get("news_agenda", {})
		...
			raw[c] = maxf(1.0, float(occ_sal[i]) * (1.0 + 2.0 * unmet) + float(agenda.get(c, 0)) + float(na.get(c, 0)))
```

(`maxf(1, …)` because a paper that buries a concern can push the term negative.)

## 3. Ideology pull from sustained reading (PD 17.6; after the clamp at line ~226, or just before it)

```gdscript
		var diet: Dictionary = cell.get("diet", {})
		for oid in diet:
			var o: Dictionary = world.peek("outlet").get(oid, {})
			if o.is_empty():
				continue
			var wgt := MediaQuery.weight(cell, oid) * MEDIA_PULL          # MEDIA_PULL := 0.002 per month
			for ax in PolDefs.AXES:
				cell["ideology"][ax] += int(round((float(o["line"].get(ax, 0)) - float(cell["ideology"][ax])) * wgt))
```

- Strength: at most about 0.12% of the gap a month for a loyal reader (diet 600‰ × trust 0.7 ≈ 0.4 weight). That's about a fifth of your district social influence, so one headline does nothing and years of one paper do something.
- The independent Gazette's line tracks the colony mean, so it pulls toward the centre only very weakly.

## 4. Approval (line ~248)

```gdscript
		var target := 50000.0 + 0.8 * (perf - pe) + 0.25 * (perf - 50000.0) + 2.5 * trend + honeymoon
		target += float(cell.get("news_blame", 0))   # media framing: distortion vs a neutral full account
```

## 5. Gate (spec §11 M3)

- **With one neutral paper,** run 3 seeds × 40 years. Approval and vote shares must stay within ±2 pp of the baseline.
- **Plural press check:** use `tools/probe_media.gd`, which founds a labour and a business paper in year 3. Their readers' approval and ideology should split measurably.
- **Tuning knobs:** `K_BLAME` / `K_BIAS` in `sim/media/media_data.gd`, which I own, and `MEDIA_PULL`, which you own.
