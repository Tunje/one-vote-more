# A/B: R8 step 2a, freight (E172) and freight on roads (Bob, 2026-11-15)

**Baseline:** "base11", the shared tree at fa3f6df (the freight-on-invoice fix), DEFAULT_ON only.

**E172 (R8 + R8_FREIGHT):** the transport operator CTA adds freight capacity when its trucks are full:
- **add:** if trucks were ≥ 95% full in 6 of the last 12 months, or deferred freight exceeded 5% of trade, it adds a
  +25% depot extension (or a new depot);
- **shed:** below 60% use for 12 months, it mothballs a spare depot;
- **tariffs:** unchanged (E150/E150B);
- **hauliers:** private haulier entry (rules 7/8) isn't built yet.

**FREIGHT_ROADS (Terra):** freight is limited by the road network's room on each route.

Tool: tools/ab_full.gd. 69 games; the ledger closed in all.

## 10 seeds × 30 years

| Arm | Adults | Unemployment % | Food short ‰ | Real wage | Food price (avg Y5+) | Firms dead |
|---|---|---|---|---|---|---|
| base11 | 4698 | 17.4 | 18.6 | 3.07 | 213 | 69 |
| + R8_FREIGHT | **4858** | 17.1 | 17.4 | 3.19 | 207 | 67 |
| + FREIGHT_ROADS | 4330 | 18.7 | 54.4 | 2.53 | 258 | 76 |
| + R8_FREIGHT + FREIGHT_ROADS | 4449 | 18.1 | 48.6 | 2.59 | 238 | 76 |

Freight, monthly averages from year 5:

| Arm | Capacity | Used | Deferred | Full months (of 300) | Depots at Y30 | CTA extensions |
|---|---|---|---|---|---|---|
| base11 | 10,406 | 6,800 | 306 | 85 | 1.9 | 0 |
| + R8_FREIGHT | 9,657 | 7,158 | 151 | 64 | 1.1 (scale 1.7×) | 6.2 |
| + FREIGHT_ROADS | 7,732 | 5,194 | 116 | 52 | 1.1 | 0 |
| + both | 8,226 | 5,370 | 47 | 32 | 1.0 | 1.6 |

Notes on the freight table:
- base11 already has government depots in some seeds; gov_builder builds them after "port full" facts.
- With roads on, less freight moves at all: the roads hold it back before the trucks fill.

## Seeds 1–3 × 60 years

| Arm | Adults | Unemployment % | Food short ‰ | Real wage | Per seed (adults / food ‰) |
|---|---|---|---|---|---|
| base11 | 6113 | 21.2 | 71.3 | 2.79 | s1 5875 / 142, s2 6127 / 65, s3 6339 / 7 |
| + R8_FREIGHT | **8450** | 21.0 | **18.0** | 3.45 | s1 **10,065** / 5, s2 7349 / 43, s3 7937 / 6 |
| + R8_FREIGHT + FREIGHT_ROADS | 7191 | 21.4 | 85.7 | 2.17 | s1 7732 / 55, s2 8397 / 57, s3 5445 / 145 |

## Reading
- **R8_FREIGHT works, and most over a century:** +160 adults at 30 years, +38% adults and a quarter of the hunger at
  60 years. The freight jam was the dominant long-run limit. It's a v11 candidate on its own.
- **Roads are the next limit, as the user predicted:** with FREIGHT_ROADS the real road network refuses the trucks, and
  colonies lose 9–12% of adults and triple their food shortfall. The fix is roads that follow freight demand, read
  from the R8 signals: Transport.deliverable_pm, Transport.district_jam_pm, and st.r8.goods[g][d].hr. That's
  government road building (Wilma) on Terra's road options.
- **FREIGHT_ROADS stays off by default until roads respond.**
- **Open:** haulier entry (rules 7/8) needs freight revenue split by depot owner first.
