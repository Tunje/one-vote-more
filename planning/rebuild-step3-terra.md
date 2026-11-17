# Rebuild step 3: Terra's piece. A plan's land, and farm yield from the planet

Terra, 2026-11-17. Built against planning/rebuild-step3-joins.md (HEAD ac6947e). Reviewers: Maja, and Anni for land.

## What it does

**A plan's site** (in the tree since step 2, unchanged): `Site.choose_country`, `choose_town`, `hold`, `open`,
`release`. The joins call them in COMPANY_AI (make a plan), PRODUCTION (the opening) and when a plan is given up.

**The land under a plan** (new, COMPANY_AI):
- `Site.land_keys(site)` gives land law's keys: ["x,y"] in the country, ["c:fx,fy", ...] for a town site's cells.
- `Site.land_terms(world, plan_id)` (pure) returns land law's terms at the plan's own price: 10% of the plan's bill ×
  the value of its place / 1000, in milli-credits. `{}` if the plan holds no site.
- `Site.buy_land(world, plan_id, payer_acct)` → {ok, mode, price, why}.
  - It takes no money itself. It calls `LandLaw.sell`, the one deed (joins): the price goes from the payer to the
    treasury (memo LAND_SALE) and the title is written (a country tile's plot of the plan's sixths; a town site's
    cells).
  - If the payer can't pay, or the terms refuse, nothing moves.
  - SITE row "land bought" / "land not bought" with the price, the value and why.
- `Site.zone_use` now calls `LandLaw.use_of` (Anni: the zones are the law's, so the mapping lives in one place).

**Farm yield** (new, PRODUCTION): `Site.yield_pm(world, plant_id, month)` gives the ‰ of the type row's output a
plant makes this month. Bob's making multiplies by it.
- A FARM: the season at its hex (`PlanetSeasons.farm_pct`: the growing year, averaging 100 over a year, less the
  drought) × the harm to its land (`PlanetEcology.yield_pct`) / 100.
- Anything else, or a farm with no place: 1000.
- Food grows month by month with the season; there is no harvest lump (joins).
- It reads the current month's weather, which NATURE has made before PRODUCTION.
- A month below 700 ‰ writes a PLANET "low yield" row with the season, the land, the drought and the hex.

## Tests

`tests/transport/test_site_land_yield.gd`, 5 tests:
- a farm's yield is season × land each month, the season averaging 100% over a year, the year at most its row;
- other types, and a farm with no place, make their row;
- harmed land yields less, with a log row;
- a plan buys its land: its own price moves from the plan to the treasury to the milli-credit, the title holds its
  plot of one sixth, and land law's plots agree with the map's square;
- a plan short of money buys nothing and nothing moves; a plan with no site buys nothing.

Full suite in my copy (with Anni's land_law, law_data and her updated land tests, which are hers): all pass.

## Decided by me

- Month-by-month food (agreed in the joins).
- A low-yield row only below 700 ‰, so ordinary seasons don't flood the log; the ordinary yield goes in Bob's making
  row.
- The land price comes from the plan's own bill at the size of its hold (sixths → size).

## Maja's review (2026-11-17) and my answers

Nothing wrong; nothing the plan or the joins say differently.
1. yield_pm wrote its low-yield row on every call, so any second reader (a forecast, a screen) would repeat it.
   **Fixed:** yield_pm is pure. `Site.note_low_yields` writes one row per farm per month, in NATURE (from
   Site.step_month, after the month's weather). Tested: reading writes nothing; the month's note writes one row.
2. A held plan's site answered with a yield. **Fixed:** a plan's site is 1000 (it grows nothing). Tested.
3. The SELL_LAND rule having to be installed before month one: Maja names it in her hand-over too.
- Her question back (a founder in area A may get a farm nearest area B, hiring in B): allowed, and to be said when
  areas multiply. Noted.

## Anni's review of the land side (2026-11-17) and my answers

Approved. One note: under a LEASE or KEEP policy, what a plan pays at signing is the first month's rent, not the price,
so the check "land + total" must not use the price. **Added:** `land_terms` and `buy_land` carry "due", which is the
price under a sale and the first rent under a lease. Otto is told to check `due`. Tested under both policies. Anni's law
provider now installs the land rules in init_world, so a new game can sell land from month one.

## For whoever puts it together

Land law refuses every sale ("land policy does not allow this") until `LandLaw.ensure_rules` has installed the
SELL_LAND rule. Anni's law provider must install it in a new game and on load; otherwise every plan in the first month
is refused. My tests install it themselves.
