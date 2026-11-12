# Spec: The expedition — game setup with real costs (v1)

User decision 2026-11-13 (A47): "Game start, how it's handled: getting to pick the planet, what resources you bring,
how many colonists — this is where that choice should be; how many investors you get, that becomes the starting
companies." + "Yes, and real costs" (not a points budget). Includes the bank question (A47 decides the colony's first
bank through the funding mix).

Today: one planet per seed, 2,000 colonists, a fixed founding endowment, fixed starting companies and districts,
one abstract bank. A46 already makes the founding years an emergent, guided intro; A47 is the step before it.

Owners: **Wilma** X1, X5, X6 (setup flow, investor politics, presets), **Terra** X2 (several candidate planets),
**Bob** X3, X4 (money, cargo, investors as companies, the bank), **Anni** X5 law side (charter terms from the deal).
Order: after E120/S3 and with A46 (both are about the start). Integer state; deterministic from the setup choices
plus seed; the choices are saved in the world (meta.expedition).

## X1. The flow (Wilma)

New Game → **The Expedition** (several screens, one summary): Planet · Colonists · Cargo · Funding · Commander ·
Review & sign the charter → landing (A46 intro). Every screen shows the running **balance sheet**: money raised,
money spent, ship space used, and what the colony will owe after landing. Nothing is free: every colonist,
crate and promise is paid for by someone who wants something back.

## X2. The planet (Terra)

- 3–5 candidate worlds generated from the seed (each a full Planet + Terrain): climate, fertile land, ore and
  rare-mineral deposits, native-crop land, alien phenomena and sights, hazards, and **distance** (ship interval
  18–30 months becomes a range per world: closer worlds get ships more often and cost less to reach).
- Preview on the globe and a summary card; a survey report with honest uncertainty (some facts only "estimated").
- **Cost**: reaching a farther or harsher world costs more per tonne and per colonist.

## X3. People and cargo — real costs (Bob)

- **Colonists**: a count (about 800–4,000) and a mix (general, skilled, specialists, families with children),
  each with a passage cost (more for specialists; families cost more and bring the future workforce).
  Optionally a recruitment source (volunteers, contract labour with debts to their sponsor, a political or
  religious group) that seeds philosophies and loyalties.
- **Cargo** on a ship with limited mass and volume: fabrication kits (tier), seed stock and livestock, food
  reserve (months), medicine, tools, shelter modules (how long until homes are needed), rovers, spare parts,
  construction materials. Each item has a price and a mass; better kits and more reserve buy safety.
- **Money**: the expedition must raise enough to pay for passage and cargo; what is left over becomes the founding
  endowment (treasury) and the investors' companies' capital.

## X4. Funding: who pays, and what they want back (Bob economy, Anni charter, Wilma politics)

The money comes from a mix of backers, each with real terms:
- **Private investors** (several to choose from, each a named house with a sector and a mandate: a mining house,
  a farming syndicate, a builder, a trading house, a pharmaceutical firm…): each one invested becomes a **company
  in the colony at landing** with its capital, its plants to build, and expectations — dividends sent home, sector
  privileges, lobbying, maybe a seat on a council. More investors: more capital and companies, more money leaving
  as dividends, more corporate politics.
- **The home-world government**: funds generously but writes a stricter charter (higher quota share, lower charter
  price, governor powers, export levy), feeding the colonial burden and the independence story.
- **The colonists' own pooled savings**: little money, but co-ops and a credit union, local control, and a more
  independent-minded colony.
- **The bank**: the funding mix decides the first bank — a home-world bank branch (profits remitted home, credit
  can be squeezed on home-world orders) or the colony's own (state or co-op); it lends to companies and the state,
  takes deposits later (the banking system is a follow-up spec).
- **Debts**: some funding is loans that must be repaid from colony earnings (exports) on a schedule — a real
  burden that shapes the first decades.

## X5. Signing the charter (Wilma, Anni)

The review screen shows the deal: charter terms (quota, price, levy, autonomy), the companies that will exist, the
debts and dividends owed, the bank's owner, and the expected first-decade pressures. Signing sets the law levers
(charter), creates the companies, the bank, the debts and the endowment; the commander persona follows.

## X6. Presets and AI (Wilma)

- Presets for quick starts and comparable chronicles: **Balanced**, **Corporate venture** (many investors),
  **State charter** (home-world funded), **Pioneer co-op** (colonists' own savings), **Hard world** (rich but harsh).
- Autoplay and chronicles use a preset (default Balanced, which reproduces today's start as closely as possible).
- Old saves: no expedition (meta flag), they keep today's start.

## Acceptance

- Different setups produce visibly different colonies (companies, charter, debts, bank, early pressures) from the
  same seed; presets reproduce runs deterministically.
- The balance sheet always closes: money raised = spent + endowment + company capital; debts and dividends appear
  in the ledger as real flows.
- A starved setup (too few supplies, too many colonists) can fail early — and the intro's advisers warn about it
  before signing.
