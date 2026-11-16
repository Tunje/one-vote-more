# Exports: producers count the home world as a customer (Bob, 2026-11-16)

Status: design. Code next, in a scratch copy, with unit tests. The A/B comes after the bank work.

## The user's order

The user's diagnosis: "the people who send those things back only ever do things based on how much they can use on the colony, not on what also they get from off-world exports."

What is ordered, via Wilma:
- Producers count the home-world price, net of freight, levy and tax, and the next ship, as orders they can reach. This applies in all eight rules and in expected sales.
- Port space (depots) grows on the signal of goods producers want to ship and can't.
- No caps built on past sales, and no extra floors or caps beyond what exists physically.
- Ships are the home world's, not the colony's. Wilma drives SHIP_HOLD and SHIP_INTERVAL from home_world.gd.

## What the code does today (HEAD)

- **EconTrade._consign:** each month a producer moves its own output to the port store when the net home price is at least EXPORT_MARGIN (1.1) × the local price. It keeps back a month of its local sales (sales_ema). The port store is PORT_BASE 1000 + 1000 per DEPOT, at most 40% per good.
- **Consignments count in o["sold"]**, which only the old sales_ema planning reads.
- **The eight rules never see the home world.** The R8 signals (st["r8"]["goods"], plants.reach), the output target (EconRulesMat.target), capacity rule 5, entry (EconForecast.first_year) and EconAnnual.expected_rev all look at colony orders only.

  So a mine whose ore the home world would buy runs at local demand, never expands for export, and no firm is founded to export.
- **The ship:** SHIP_CARGO 2000 units every 18–30 months, loaded pro rata from the port store. What doesn't fit stays on the dock.

## Design

### 1. The export order book (a new R8 signal, computed monthly in EconRules.monthly)

`st["r8"]["export"][good] = {net, hold_open, per_m, refused}`, all integers:
- **net:** EconTrade.prices()[good]["net"] (mcr per unit). This is already net of freight, the charter levy, the home tariff and the export tax, and a reserved good sells at its charter price.
- **hold_open:** the part of the next ship's hold still free for this good (mu). The hold is shared, so goods take it in order of net value per unit, most valuable first. That is the order the port store already uses.

      hold_open[g] = max(0, ship_hold − consigned_all − Σ hold_open of the goods worth more)

  It is limited by the ship only, not by the port: the port is the second signal (4).
- **per_m:** hold_open ÷ months until the next ship (at least 1). These are the orders a producer can reach each month.
- **refused:** mu that producers wanted to consign this month and could not, because the port store was full or the good's 40% share was full (counted in _consign, 4).

A producer counts export orders only if `net ≥ its plant's variable cost` (cost_var, the rules' own number). Exports that don't pay for their inputs are not orders. This is the test target() already applies to local prices; it adds no new floor.

### 2. In the eight rules

- **Rules 3 and 4 (output, EconRulesMat.target).** A plant's reach becomes local reachable unfilled orders plus its share of the export order book: per_m × its capacity ÷ the capacity of all open plants of its type.

  The plant's price test reads max(local price, net) for exportable goods. A plant whose local price has fallen below variable cost still runs for export if the home world pays.
- **Rules 5 and 6 (capacity up, keep).** These read the same reach, through r8_unf_bits and keeps(). The capacity price test (ADD_MARGIN × unit cost) uses max(local, net). A mine with a full ship's worth of open hold expands like one with unfilled colony orders.
- **Rules 7 and 8 (entry).** EconForecast.first_year adds the export order book to the demand a newcomer could reach, at net. So a firm can be founded to export, and "no_customers" is not reported while the ship has open hold for its good at a price above its variable cost.
- **Rules 1 and 2 (price).** No change: sellers' prices are v12 work. Export earnings arrive at net through the ship, as today.

The sectors that see it are those on the rules (R8_MATERIAL: MINERAL, MATERIAL, COMPONENT; R8_FOOD: FINE_FOOD from bakeries). The workshops (CONSUMER, CLOTHING, FURNISHINGS, MEDICAL) see it when they move onto the eight rules. Until then, their old planning keeps counting consignments through o["sold"].

### 3. In expected sales (EconAnnual.expected_rev)

A month of the plan is valued once. Units the plan sends to the ship are valued at net, the rest at the local price. It adds the firm's own port stock (consigned, not yet shipped) at net, spread over the months to the next ship: those are sales the ship will pay for.

Credit lines and input budgets that follow expected_rev then follow export orders too, with no limit built on past sales.

### 4. Port space on the signal of goods producers can't ship

- **In _consign:** when free port space or the good's 40% share runs out while a producer still holds output it would consign, add that quantity to `refused`. That is the 1.1 margin test it already applies, so no new test.
- **In the freight rules (EconRules._freight_rules, the CTA's depots):** a new reason to add a depot. Refused > 0 in PORT_M of the last 12 months (start PORT_M 6, like rule 5's window), and no depot project pending. Then the CTA expands its smallest depot or builds one, financed as the freight rules already do.

  A port that sits empty (no consignments in 12 months) doesn't count as a reason to keep a depot: the trucks' idle rule decides that.
- **The 40% share per good** is the port's own rule for mixing cargo. I keep it, since it isn't built on sales. Wilma or the user may want it gone; it is one constant.

### 5. What "a month of local sales stays home" becomes

_consign keeps back `sales_ema`, a month of past local sales. That is a limit built on past sales. In its place, the producer keeps back the local orders it can reach now (EconRules.reachable_unfilled for its good and district, its capacity share), plus what its own local customers bought this month. Local customers who pay more than the net home price already win (the existing test sends port stock back to the local market when local > 1.1 × net).

This is a change to existing behaviour, so it has its own switch for the A/B.

### 6. A hook for Wilma (pressure on the home world)

`EconTrade.export_pressure(world) -> {left_last_ship {good: units}, left_total, refused_12m {good: units}, hold_open {good: units}}`, all integers. It is cheap:
- on_ship already knows the loading factor f. What it left on the dock is `held − loaded` per good, saved in the ship record as "left".
- refused_12m is a 12-entry ring of the monthly refused totals.

home_world.gd's _dock_units reads port_stock after the ship, which mixes what was left with new consignments of the same month. The "left" field is the exact figure.

### 7. Switches

| Switch | Part |
|---|---|
| EXP | 1–3: export orders in the rules, the forecast and expected sales |
| EXP_PORT | 4: depots on refused cargo |
| EXP_KEEP | 5: keep back current local orders instead of a month of past sales |

The hook (6) is always written: it is a measurement only. Saved state is integers only, with save/load tests.

### 8. Tests (unit)

- With open hold and net > cost_var, a mine's reach includes its share of per_m, and target() rises.
- With net < cost_var, it doesn't.
- hold_open falls as consignments fill the ship, and is shared most-valuable-first.
- A full port store records refused. Refused in 6 of 12 months leads the CTA to plan a depot.
- expected_rev counts consigned port stock at net.
- first_year doesn't report no_customers while open hold exists at a paying net price.
- on_ship records "left" per good when the hold is full, and export_pressure returns it.
- Save/load round trip with the new fields.

### 9. A/B (after the bank work)

| Arm | Switches |
|---|---|
| base | v11 defaults |
| exp | EXP |
| exp+port | EXP, EXP_PORT |
| exp+port+keep | EXP, EXP_PORT, EXP_KEEP |
| all + SHIPPING | the three, plus SHIPPING (Wilma's home-world side) |

Run 10 seeds × 30 years, then seeds 1–3 × 60 years. Report:
- adults, unemployment, real wage;
- export value a year and the trade surplus;
- units left on the dock and refused at the port;
- mines and processing plants built for export;
- the bank's losses. Export orders raise expected sales, and so lines.
