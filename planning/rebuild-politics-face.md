# What politics reads from and does to the economy

**Ella, 2026-11-17.** Written on Wilma's order for the rebuild ([rebuild-company.md](rebuild-company.md) version 13,
sections 9.11, 10, 12.10 and 13). It lists, by name, everything that politics, campaigns, the press, the office and the
screens read from the economy or do to it: every lever, every indicator, every fact type, every act of the government,
and every piece of economy state read directly. For each it says:

- whether the thing still exists in the rebuild;
- which build step of section 13 brings it (1 to 11);
- what politics sees until then.

Step 11 is checked against this list. Every earlier step reads it to know which names it must publish.

How the list was made: every quoted name in the old economy (`game_full_copy/sim/economy`, `sim/companies`) was matched
against every file of the game now (`game/sim`, `game/ui`, `game/data`, the economy removed), plus the old lever,
indicator and action tables in `econ_pic.gd`. Names that are read by a prefix only (the opposition's research reads
every `ECON_` and `COMP_` fact; the gazette and the why-panel read recent facts by size) count as read.

**My decisions** (Ella's, where the plan gives no answer and one is plain) are marked **(E)**. Wilma or the user strikes
any that is wrong.

---

## 1. The ground rules for all of it

0. **Salaries** (the user, 9.2, commit 207cec3): a worker's salary is set when hired and climbs once a year by the yearly raise, whose minimum the government sets. The three price rules move only the HIRING salary. The levers below follow that.
1. **The old names stay.** "The rebuild publishes the same names where the thing still exists" (9.11). A thing that
   comes back comes back under its old id, with its effect built new. A new thing gets a new id in the same style.
2. **The stand-in stays whole until step 11.** **(E)** Today politics plays with the stand-in world's 7 levers
   (`STUB_INCOME_TAX`, `STUB_CORP_TAX`, `STUB_WELFARE`, `STUB_PUBLIC_INVESTMENT`, `STUB_ENV_STANDARD`,
   `STUB_LABOR_PROTECTION`, `STUB_DISTRICT_AUTONOMY`) and its 9 indicators, which together cover every concern.
   - From its step, a real lever is in the lever table, so the legislature can vote it and the economy can be steered
     and tested (in games without politics, the caretaker of 12.11, 103, sets it).
   - From its step, a real indicator is published, for the screens, the press and the tests.
   - The voters' concerns read the stand-in's indicators until step 11, when the stand-in is removed in one go and the
     real indicators take over.
   - Why: a concern is an average over its indicators. Half real and half stand-in, it would average figures from two
     different worlds, and every step would move the elections for no reason the step contains.
3. **No direct reads of the economy's state.** EconFace says "Nothing outside this file may call the economy any other
   way". Today 20 places read the old economy's state table by key (`CoreUtil.st` / `peek_st`, section 6). **(E)** Each
   becomes a named EconFace function at the step that brings it, and the direct read is removed then.
4. **Politics keeps its own memory in its own table.** **(E)** `gov_builder.gd` keeps the open grant programmes and the
   chosen districts (`grant_prog`, `grant_cover`) inside the economy's state. They are politics' own and move to
   politics' state before step 3, when grants open.
5. **Blame (12.10, 73).** Every fact below that marks an ending, a mass layoff, a shutdown, a famine or a shortage
   carries `responsible` (who is to blame, with shares) and a place (area, and the district it is in). The table says
   who, where it is plain. "Owner" means the company's owner register (section 3 of the plan), and "the government" for
   a state company.
6. **Nothing is published by the stand-in.** A doorway answer never makes a fact. An act refused because "there is no
   economy yet" makes no `ECON_ACTION_FAILED`, so the staff briefing is not flooded every month.

---

## 2. Levers

Old table: `econ_pic.gd` `levers()`, 50 levers and 1 choice. "Where the thing still exists" follows 12.10, 63 and 12.11.

### 2a. Kept

| Lever | What it is in the rebuild | Step | Read by name in |
|---|---|---|---|
| `ECON_INCOME_TAX_RATE` | income tax (62) | 8 | budget panel |
| `ECON_PROFIT_TAX_RATE` | profit tax (62) | 8 | budget panel |
| `ECON_SALES_TAX` | sales tax (62) | 8 | budget panel |
| `ECON_TAX_ALLOWANCE` | tax allowance (88) | 8 | budget panel |
| `ECON_IMPORT_TARIFF` | tariff on what comes in by ship (63) | 8 | budget panel |
| `ECON_MIN_WAGE` | the minimum wage (63): the least a company may HIRE at. **(E)** In per cent of the area's starting salary (9.2). Like a legal price ceiling (64), it stops the hiring-salary lowering rule at that floor. That is the government's doing, and allowed. A salary already paid never falls (9.2, 207cec3) | 8 | union politics, law data, budget panel |
| `ECON_UNION_RIGHTS` | union rights (63). Its effect is built with the union law (Anni) | 9 | union politics |
| `ECON_PUBLIC_PAY_INDEX` | public pay (63). **(E)** The state's employers (state companies and 12.10, 70) hire at this per cent of the starting-salary line, and the rules move that hiring salary from there. Above 100 it can also add to their staff's yearly raise, on top of `ECON_BONUS_MIN` | 8 | union politics |
| `ECON_UNEMPLOYMENT_BENEFIT_RATE` | the benefit, a share of the area's starting salary (12.5, 41) | 2 (in the lever table, so votable, from 2: 1.2) | union politics, budget panel |
| `ECON_PENSION_RATE` | pensions, the same way (41) | 2 | budget panel |
| `ECON_BENEFIT_FLOOR`, `ECON_BENEFIT_DURATION` | the floor and the time limit on the benefit (88) | 8 | legislature, budget panel |
| `ECON_FOOD_ASSISTANCE` | food assistance (88) | 8 | legislature (8 reads), budget panel |
| `ECON_UTILITY_TARIFF_ENERGY`, `ECON_UTILITY_TARIFF_WATER` | the approved tariff of a state utility (46, 49). The utility proposes; `ECON_APPROVE_TARIFF` sets the lever | 4 | budget panel |
| `ECON_PUBLIC_RENT` | the housing office's rent (a state landlord: proposed and approved like a tariff, 46). The landing shelters' rent comes from the salary formula (step-2 brief), not from this lever | 7 | budget panel |
| `ECON_RENT_INCREASE_CAP` | rent control (63, 64) | 8 | |
| `ECON_HEALTH_FEE`, `ECON_SCHOOL_FEE` | the fee at the door (100). Starts at 0 | 4 | |
| `ECON_SCHOOL_TAX`, `ECON_HEALTH_TAX`, `ECON_ADMIN_TAX`, `ECON_ELDER_CARE_TAX`, `ECON_CHILDCARE_TAX` | the tax brackets: the price of each public service (9.5, 46). The service's rules propose; the government decides. Their old switch `requires: R8_INSTITUTIONS` goes | 4 | |
| `ECON_STRATEGIC_SUBSIDY_RATE` | subsidies and co-financing (94) | 8 | |
| `ECON_PE_DIVIDEND_RATE` | state companies' dividend (97) | 8 | |
| `ECON_PROCUREMENT_PRICE_WEIGHT` | how the state picks a builder (98) | 8 | |
| `ECON_EMISSION_REDUCTION` | cleaner production (101) | 9 | |
| `ECON_PUBLIC_OWNERSHIP_POLICY` | who expands, market to state (96) | 8 | |
| `ECON_BUDGET_ADMIN`, `_HEALTH`, `_EDUCATION`, `_TRAINING`, `_INFRASTRUCTURE`, `_HOUSING`, `_PUBLIC_WORKS`, `_PUBLIC_EMPLOYMENT`, `_ELDER_CARE`, `_CHILDCARE`, `_PUBLIC_TRANSPORT`, `_SUBSIDIES`, `_RESERVE_PURCHASES` | the budget lines, each with what it has left (62) | 8 | gov builder, legislature, road law, desk, press, companies panel |
| `ECON_TRAINING_SUBSIDY` | the state's share of on-the-job training (85) | 8 | legislature |
| `ECON_FAMILY_FARM_GRANT`, `ECON_FAMILY_BAKERY_GRANT`, `ECON_TRUCK_DRIVER_GRANT`, `ECON_TRUCK_WORKSHOP_GRANT` | the four grants, open from month one (9.12). **(E)** Each starts open at a percentage set with the other numbers (no longer 0), and the old switches (`E160`, `E162`, `TRUCKERS`, `TRUCKSHOP`) go | 3 | gov builder |

### 2b. New levers the plan creates

| Lever **(E: the names)** | What | Step |
|---|---|---|
| `ECON_BONUS_MIN` | the yearly raise (the user, 9.2, 207cec3: "they have a sallery set on hire then it climbs based on yearly upps set by goverment"). Every employed person's salary climbs by at least this much once a year; a company may give more. Starts at 2%. Voters feel it every year, so it carries concern hints like the minimum wage. The id stays for continuity with the plan; it is a raise, not an optional bonus | 3 (in the lever table, so votable, from 3: 1.2) |
| `ECON_PRICE_CEILING` | a legal ceiling on the price of a named item (64); one value per item, 0 = none | 8 |
| `LAW_RETIREMENT_AGE` | already the law's (law_data.gd:668); the plan keeps it (41). Nothing to build; households read it from step 3 | 3 |

### 2c. Gone

| Lever | Why |
|---|---|
| `ECON_FREIGHT_TARIFF` | carriers price by the three rules (12.4, 30); there is no state freight tariff. **(E)** |
| `ECON_PE_EXPANSION` | folded into `ECON_PUBLIC_OWNERSHIP_POLICY` (96), which says who expands. **(E)** |
| `ECON_PUBLIC_BUILDER_AT_COST` | the public works department builds at cost when told; that is its rule, not a lever (99). Anni checks it against the competition law. **(E)** |
| `ECON_ENERGY_PRIORITY` (choice) | the order when power or water runs short is fixed: water before power; homes, farms and clinics first (104). **(E)** |

**Until its step**, a lever is not in the lever table. The legislature, the parties and the budget panel see only the
stand-in levers. Code that reads an ECON lever by `world.levers.get(id, default)` gets the default; union politics and
the legislature already read it so.

---

## 3. Indicators

Old table: `econ_pic.gd` `indicators()`, 39 indicators. All of them feed voters through their concerns, whether read by
name or not. By name: `ECON_UNEMPLOYMENT_RATE` (home world, legislature, main screen, map), `ECON_TREASURY_RUNWAY`
(gov builder, legislature: the fiscal guard), `ECON_UNION_DENSITY` (party life).

Published from the step in the table. They enter the voters' concerns at step 11 (1.2). **Until then** the voters read
the stand-in's 9 indicators, and code that reads one of these by name finds no definition and takes its own fallback.

| Indicator | What it measures in the rebuild | Step |
|---|---|---|
| `ECON_UNEMPLOYMENT_RATE` | the jobless share of the labour force, per district | 3 |
| `ECON_JOB_RISK` | the chance of losing one's job: layoffs and endings in the cell's occupation | 3 (layoffs, 19a), in full at 5 |
| `ECON_REAL_INCOME_INDEX` | income against the area price index (74) | 4 |
| `ECON_ESSENTIALS_SHARE` | essentials as a share of income | 4 |
| `ECON_ESSENTIAL_SHORTFALL` | need for essentials not met, for any reason (23) | 3 (food), all essentials at 4 |
| `ECON_CPI_INFLATION` | the colony's price index over twelve months (74) | 4 |
| `ECON_LOCAL_PRICE_INDEX` | the area price index (74): the companies' prices weighted by what they sold | 4 |
| `ECON_RENT_BURDEN` | rent as a share of income | 3 (the shelters' rent), in full at 7 |
| `ECON_OVERCROWDING` | households per home (the 130% limit) | 3 |
| `ECON_HOUSING_CONDITION` | the average condition of homes | 7 |
| `ECON_INFORMAL_HOUSING`, `ECON_HOMELESSNESS` | shacks and the homeless | 3 |
| `ECON_ELDER_CARE_ACCESS`, `ECON_CHILDCARE_ACCESS` | the share served (43) | 4 |
| `ECON_FOOD_UNAFFORDABLE` | food need unmet for lack of money (23, 23a) | 3 |
| `ECON_RAW_FOOD_SHARE` | food bought raw instead of bakery goods (the households' preference) | 4 |
| `ECON_UTILITY_RELIABILITY` | power and water served against need (104) | 4 |
| `ECON_INFRA_CONDITION` | the condition of roads and of public plants | 4 (roads carry freight), plants at 6 |
| `ECON_LOGISTICS_DELAY` | goods waiting in the freight queue | 4 |
| `ECON_HEALTH_ACCESS`, `ECON_EDUCATION_ACCESS` | the share served within reach (43) | 4 |
| `ECON_POLLUTION_INDEX` | pollution by area | 9 |
| `ECON_INCOME_RATIO`, `ECON_GINI`, `ECON_DEPRIVATION` | income spread; who cannot afford essentials | 3 |
| `ECON_TAX_BURDEN` | taxes as a share of income | 8 |
| `ECON_FINANCIAL_SECURITY` | months of savings | 3 |
| `ECON_REAL_WAGE_GROWTH` | salaries against the price index | 4 |
| `ECON_GROWTH` | the value of what the colony made, over twelve months | 4 |
| `ECON_PROJECT_DELIVERY` | building contracts finished on time | 3 (plainest), in full at 6 |
| `ECON_COMPANY_FAILURES` | endings in the last twelve months | 5 |
| `ECON_IMPORT_DEPENDENCY` | the share of what was used that came by ship | 4 |
| `ECON_TRADE_BALANCE` | exports less imports | 10 (imports count from 3) |
| `ECON_PUBLIC_DEBT_RATIO` | the state's debt to the bank (50) | 5 |
| `ECON_BUDGET_BALANCE`, `ECON_OPERATING_BALANCE` | the purse's balance | 2, in full at 8 |
| `ECON_TREASURY_RUNWAY` | months the treasury lasts. It keeps its fiscal stress and fiscal guard | 2 |
| `ECON_MARKET_CONCENTRATION` | how few companies sell each item | 4 |
| `ECON_UNION_DENSITY` | **(E)** still keyed by occupation: the share of each occupation's staff who are union members. Unions are no longer by occupation, but party life reads the density per occupation for endorsements, and the occupation is a column of the type table | 9 |

New ones the plan publishes:

| Indicator **(E: the names)** | What | Step |
|---|---|---|
| `ECON_SICKNESS` | the share of the labour force too ill to work where clinic places are short (86). health_signal.gd computes the same share for its pandemic fact; it reads it from here instead | 4 |
| `ECON_W_REF` (a world value, not an indicator) | the reference wage, per area and for the colony (108). Read by the law's fines, the press's costs, the legislature, the staff bench. Until step 3 every reader takes its own fallback (1,200 credits) | 3 |

---

## 4. Fact types

The old economy emitted about 110 fact types. The table lists every one, read by name or not, since the press and
opposition research read all of them by prefix and size. **Until its step a fact is never published**: the news, the
gazette, the opposition's research and the hot issues simply find none.

Read by name in: news text (`ui/news_text.gd`), the gazette, the press library, media data, justice, law, the hot
issues, emergency politics, rivalry, gov builder, home world, siting, the staff briefing, the unions panel, the trade
panel.

### 4a. Companies

| Fact | Step | Blame | Note |
|---|---|---|---|
| `COMP_COMPANY_PLANNED` | 3 | the founder | a plan made (8.1) |
| `COMP_COMPANY_FOUNDED` | 3 | the founder | the plant opens |
| `COMP_PLAN_ABANDONED` | 3 | the founder | a plan given up (60b); not a failure |
| `COMP_WORKPLACE_ACCIDENT` | 3 | the company (69) | justice and law read it |
| `ECON_LAYOFFS_MASS` | 3 | the owner; the government's share when its lever or bracket was the cause | a company that cannot pay its staff (19a) |
| `COMP_INVESTMENT` | 6 | | rule 5: a size up or a new plant |
| `COMP_DISTRESSED`, `COMP_RESTRUCTURED`, `COMP_STAKE_SOLD` | 5 | owner | trying to avoid the end (82) |
| `COMP_CREDIT_LINE_TERMED`, `COMP_BANK_RESCUE` | 5 | the bank, the owner | credit lines (83), more time (82) |
| `COMP_CEO_REPLACED` | 5 | | management (77) |
| `COMP_INSOLVENCY` | 5 | owner | an ending that leaves debt: the owner goes to court (8.3) |
| `COMP_LIQUIDATED` | 5 | owner; the government for a state company (54) | **(E)** one fact for all three endings, with `data.way` = `SALES`, `PLANTS` or `BUYOUT` |
| `COMP_COURT_LIQUIDATION` | 5 | owner | wound up after repeated convictions (68) |
| `COMP_WORKER_BUYOUT` | 6 | | the workers buy a plant as a co-op (81) |
| `COMP_FACILITY_MOTHBALLED` | gone | | **(E)** a double of `ECON_FACILITY_MOTHBALLED`; only that one is published |
| `ECON_FACILITY_MOTHBALLED`, `ECON_FACILITY_REOPENED`, `ECON_FACILITY_SCRAPPED` | 6 | owner | rule 6 and mothballing (79) |
| `ECON_FACILITY_CLOSED_UNSAFE` | 6 | owner | 80 |
| `ECON_FACILITY_SOLD` | 6 | | a plant sold (81, 95) |
| `ECON_OVERLOAD_INCIDENT` | 9 | the company | stress past its limit at a workplace; the hot issues read it |
| `ECON_QUALITY_SCANDAL` | gone for now | | quality of goods is left out (12.12). It was a source of scandals for campaigns; it comes back with quality |
| `ECON_STORAGE_SHORTAGE` | gone for now | | storage is left out (12.12) |

New:

| Fact **(E: the names)** | Step | Blame | Note |
|---|---|---|---|
| `COMP_BOUGHT_OUT` | 6 | | a buy-out in a shared square (section 5, 67) |
| `COMP_OWNER_IN_COURT` | 5 | the owner | debt left after an ending (8.3); the court's case is the law's |

### 4b. Food, homes, people

| Fact | Step | Blame | Note |
|---|---|---|---|
| `ECON_FAMINE` | 3 | the government | emergency politics, the law, the press read it. Counted from need (23) |
| `ECON_FOOD_SCARCE`, `ECON_SHORTAGE` | 3 (food), all items 4 | the government; the companies that sell the good | |
| `ECON_FOOD_UNAFFORDABLE` | 3 | the government | |
| `ECON_RAW_FOOD` | 4 | | |
| `ECON_FOOD_AID` | gone | | the home world's rations arriving by themselves are not worked in (12.11). Food the government releases is `ECON_RESERVE_RELEASED` |
| `ECON_HOMELESSNESS`, `ECON_SHANTYTOWN`, `ECON_SLUM`, `ECON_SHACK_FIRE` | 3 | the government | the hot issues read `ECON_SLUM` |
| `ECON_MIGRANTS_ARRIVED`, `ECON_EMIGRATION` | 3 | | by ship (42); the hot issues read both |
| `ECON_HOUSING_RENOVATED`, `ECON_HOUSING_RUNDOWN`, `ECON_RENT_INCREASE` | 7 | the landlord | |
| `ECON_PANDEMIC` (health_signal.gd's own fact, emitted through the doorway) | 4 | the government | must reach the fact store already (my review of 90cd880, point 4) |

### 4c. Building and the state's projects

| Fact | Step | Note |
|---|---|---|
| `ECON_PROJECT_COMPLETED`, `ECON_PROJECT_CANCELLED` | 3 | siting reads `COMPLETED` |
| `ECON_CONTRACT_AWARDED` | 3 | a plan signs with a builder |
| `ECON_CONTRACT_PAYMENT_MISSED` | 3 | the builder stops after three unpaid months (56); justice reads it |
| `ECON_CONTRACT_DELAYED`, `ECON_CONTRACT_SEVERELY_DELAYED`, `ECON_CONTRACT_FAILED` | 6 | justice reads `SEVERELY_DELAYED` |
| `ECON_UNFINISHED_LEFT`, `ECON_UNFINISHED_TAKEN` | 5 | a half-built building left and taken over (56, 60b) |
| `ECON_TENDER_OPENED`, `ECON_TENDER_FAILED`, `ECON_PUBLIC_QUOTE_REFUSED` | 8 | the state commissioning (98); rivalry reads `QUOTE_REFUSED` |

### 4d. The purse, the bank, grants

| Fact | Step | Blame | Note |
|---|---|---|---|
| `ECON_GRANT_ENDED`, `ECON_GRANT_PROGRAMME_ENDED` | 3 | the government; gov builder reads `PROGRAMME_ENDED` |
| `ECON_GRANT_FIRM_FAILED` | 5 | the government and the owner; rivalry reads it |
| `ECON_RESERVE_RELEASED` | 3 | the government | the landing stock is the reserve (62) |
| `ECON_IMPORT_ARRIVED`, `ECON_SHIP_ARRIVED` | 3 | | home world reads `SHIP_ARRIVED` |
| `ECON_BUDGET_REQUEST` | 4 | | a service proposes its bracket or a plant (46, 47) |
| `ECON_INSTITUTION_CLOSED`, `ECON_INSTITUTION_REOPENED` | 4 | the government (47) |
| `ECON_TARIFF_CHANGE` | 4 | the government (46, 49) |
| `ECON_UTILITY_OUTAGE` | 4 | the utility's owner (104) |
| `ECON_COMMUTE_DISRUPTION` | 4 | the transit company (40) |
| `ECON_GOV_BORROWED`, `ECON_CREDIT_CRUNCH` | 5 | |
| `ECON_BANK_FAILURE`, `ECON_BANK_CREDIT_FREEZE`, `ECON_BANK_BAILOUT`, `ECON_BANK_RECAPITALISED`, `ECON_BANK_SHARES_SOLD` | 5 | the bank's owner; the government for a bail-out (93) |
| `ECON_REMITTANCE` | 5 | the bank's home-world owner (91) |
| `ECON_PLAN_BAILOUT`, `ECON_PE_FUNDING_REQUEST` | 5 | a plan or a state company asking for help (54, 82) |
| `ECON_SUBSIDY_GRANTED`, `ECON_INCENTIVE_OFFERED`, `ECON_INCENTIVE_CLAIMED` | 8 | the government (94) |
| `ECON_PUBLIC_JOBS_HIRED`, `ECON_PUBLIC_JOBS_CUT` | 8 | public work for the jobless (87) |
| `ECON_PURSE_SHORT` | 2 | the government | the month's bill (state wages, benefit, pensions) not paid in full; shared in proportion (Wilma's purse). Data: due and paid per line. **(E)** Its impact stays {} until step 8: before taxes exist every purse runs short by construction, and voters must not punish a government for a part not yet built. From step 8 it weighs on GOVERNANCE and COST_OF_LIVING |
| `ECON_SOVEREIGN_DEFAULT`, `ECON_DEBT_RESTRUCTURED` | 8 | the government (92); the legislature reads the default |
| `ECON_ACTION_FAILED` | from the step that connects each act | the staff read it (1.6) |
| `ECON_POLLUTION_THRESHOLD` | 9 | the polluters |
| `ECON_EXPORTS_SOLD`, `ECON_PORT_FULL`, `ECON_HOME_PRICE_SWING` | 10 | home world and gov builder read `PORT_FULL` |

### 4e. Freight

| Fact | Step |
|---|---|
| `ECON_TRUCKS_OFF_ROAD`, `ECON_TRUCK_BUILT`, `ECON_TRUCK_REPAIRS`, `ECON_TRUCK_SCRAPPED`, `ECON_TRUCK_DRIVER_FIRST` | 4 |
| `BUS_BREAKDOWN`, `BUS_CRASH` (the colony view reads them) | 4 |

### 4f. Unions

Under the user's ruling (9.9) and 12.10, 71: a union starts at one company, members across companies, a fee, protests
and shutdowns paid at 2/3, no federation.

**Underpayment** (the user, 9.2 and 9.9: "It's too create political drama, underpayed workers go to the union, they can
quit if they think they can get better prices if not they may unionise"; and "I think you should avrage ask salleries
in the company and underpayed is based on that line, that way both old and new can become underpayed"):
- A worker is underpaid when paid less than the average salary in their company. The average is taken among the same
  kind of post (Wilma's detail, marked in 9.2), from `Company.payroll`. Old staff and new hires alike can be underpaid.
- An underpaid worker first negotiates with the manager (the user, 9.2: "Lets as one more thing to the sallery, the
  manager, negotiation can bring it closer to avrage"). A negotiation can bring the salary closer to the average.
- If the negotiation fails, a worker who can get better pay within reach quits for it (job changing, Maja). One who
  cannot may join or start a union. So a union's recruits over pay are those whose negotiation failed and who cannot get
  better pay elsewhere. Underpayment is the second way a union starts or grows, beside bad working conditions.
- For politics: a negotiation that succeeds is quiet (a Logbook row only). One that fails is what may become a union.
  **(E)** No fact per failed negotiation; the drama is the union's facts below.
- For politics: `UNION_FOUNDED` and `UNION_DEMAND` carry `data.cause` = `CONDITIONS` or `PAY` **(E)**, and a demand over
  pay names the gap. A pay dispute is the drama the ruling asks for, so its facts are PUBLIC. The share of underpaid
  workers is published with the unions (`ECON_UNDERPAID`, **(E)** the name, per district, step 9). It enters the
  voters' JOBS and FAIRNESS concerns at step 11, like every other indicator.

| Fact | Step | Note |
|---|---|---|
| `UNION_FOUNDED` | 9 | at the company with bad conditions |
| `UNION_DEMAND` | 9 | better conditions or pay at that company (71); the desk and the unions panel read it |
| `UNION_TALKS_FAILED`, `UNION_SETTLED` | 9 | |
| `UNION_STRIKE_CALLED` | 9 | **(E)** keeps its name; it now means a shutdown is ordered |
| `ECON_STRIKE` | 9 | **(E)** a shutdown under way. Blame: the company, and the government's share if it leaned on the union |
| `UNION_STRIKE_COLLAPSED` | 9 | the fund can no longer pay 2/3 |
| `ECON_LOCKOUT`, `ECON_ARBITRATION` | 9 | 89 |
| `UNION_DISSOLVED` | 9 | no members left |
| `UNION_MERGED`, `UNION_SPLIT` | gone | no federation and no unions by occupation (12.12). The unions panel and gazette find none |
| `UNION_LEADER_ELECTED` | gone **(E)** | the plan gives a union no leader. union_politics.gd reads a leader's militancy with a default of 50 (line 249), so it reads the default. If the user wants leaders, they come back with this fact |
| `UNION_PROTEST` (new, **(E)** the name) | 9 | "unions protest bad conditions" (9.9) |
| `POL_LEAN_ON` (new, **(E)** the name; politics' own) | 9 | the government leans on a company or a union (9.5) |

### 4g. Donations

| Fact | Step | Note |
|---|---|---|
| `POL_DONATION` (politics' own, party_life.gd:929) | 9 | the `donation_offer` table comes back: companies offer from their profit (72) |
| `POL_PARTY_COMPANY_PROFIT` (new, **(E)** the name) | 5 | a party-owned company's profit paid to the party, on the record (72). A scandal source, so it is PUBLIC |

---

## 5. Acts of the government

Old: `econ_pic.gd` `actions()`, 21 acts through `EconActions.enqueue`, plus the institutions' calls. **Until its step**
an act answers `{"ok": false, "error": "There is no economy yet."}`. The AI government gives up quietly; the player
sees the reason.

| Act | Rebuild | Step | Called from |
|---|---|---|---|
| `ECON_COMMISSION_PROJECT` | the state orders a building, road or repair (9.5) | 8 | gov builder, road law, colony map, projects panel |
| `ECON_AWARD_CONTRACT`, `ECON_RETENDER_PROJECT`, `ECON_CANCEL_PROJECT`, `ECON_TERMINATE_FOR_BREACH` | acts on a building contract (9.7, 56, 98) | 8 | gov builder, projects panel, decision desk |
| `ECON_SET_BUDGET` | the budget lines (62) | 8 | |
| `ECON_SUBSIDIZE`, `ECON_OFFER_INCENTIVE` | subsidies and co-financing (94); grants are levers now (2a) | 8 | companies panel, gov builder |
| `ECON_RESCUE_LOAN` | help asked for (82); the government may say no | 8 | |
| `ECON_BUY_FACILITY`, `ECON_SELL_FACILITY` | 95 | 8 | |
| `ECON_UPGRADE_FACILITY` | upgrading a state plant (78) | 8 | gov builder |
| `ECON_ORDER_IMPORTS` | the government orders with a ship in port (9.6, 102) | 3 | |
| `ECON_RELEASE_RESERVE` | selling from the reserve, the landing stock (62, 102) | 3 | gov builder |
| `ECON_APPROVE_TARIFF` | approving a state utility's tariff or a service's bracket (46, 49) | 4 | gov builder |
| `ECON_ANSWER_UNION_DEMAND` | the state as employer answering a demand (71) | 9 | office feed, unions panel, desk |
| `ECON_BORROW`, `ECON_REPAY_DEBT` | the state borrows from the bank (50) | 5 | |
| `ECON_BANK_BAILOUT` | 93 | 5 | |
| `ECON_PUBLISH_FISCAL_REPORT`, `ECON_REQUEST_ECON_BRIEFING` | 109 | 8 | |
| institutions: close, reopen, build needs, close candidates, budget requests (`EconFace.inst_*`) | a state service proposes a plant or a closure, the government decides (47) | 4 | gov builder |
| `ECON_LEAN_ON` (new, **(E)** the name) | lean on a company or a union (9.5, 9.9) | 9 | |

**Read with an act:** `actions_headroom` (what a line has left) and `construction_estimate` (the build bill at today's
prices) are connected **in the same step, 8**. My review of 90cd880, point 6: connected apart, every order either
fails on money or passes and is refused later. `actions_check`, `actions_validate`, `actions_pending`,
`actions_last_results`, `actions_lines_for`, `ACTIONS_LINE_OF`, `QUERY_LINE_LABELS`, `actions_set_manual_award`,
`construction_award`, `construction_ranked_bids` and `builders_refuse` connect with their acts.

**A consequence to report, not to fix:** until step 8 the state commissions nothing. No public road, school, clinic or
public works is built in steps 3 to 7; the colony is built by private plans and grants alone. Each step's report says
so under its fifth line ("there because the next step is not built yet").

---

## 6. Economy state read directly today, and the doorway function each becomes (E)

| Read today | By | Becomes | Step |
|---|---|---|---|
| `food_shortfall` | crime.gd:112, legislature.gd:313 | `EconFace.food_shortfall()`: food need unmet (23) | 3 |
| `famine_now` | emergency_politics.gd:132 | `EconFace.famine_now()` | 3 |
| `market_stats.FOOD` | legislature.gd:358 | `EconFace.market_overview()` (already in the doorway) | 3 |
| `food_unaff` | legislature.gd:388 | `EconFace.food_unaffordable()` | 3 |
| `food_assist_pm` | legislature.gd:382 | `EconFace.food_assistance_paid()` | 8 |
| `lever_need` | legislature.gd:397 | `EconFace.lever_need()`: which levers the economy says are needed (the grants first) | 3 |
| `family_need_d` | gov_builder.gd:536–542 | `EconFace.grant_need(kind)`: where each grant type has unmet need, by district | 3 |
| `grant_prog`, `grant_cover` | gov_builder.gd:538–540, 1051–1058 | politics' own state (1.4), not the economy's | before 3 |
| `health_access`, `edu_access` | gov_builder.gd:154, health_signal.gd:26 | `EconFace.service_access(kind)` by district | 4 |
| `staple_m` | gov_builder.gd | with the bakery preference | 4 |
| `sovereign_default` | legislature.gd:114 | `EconFace.sovereign_default()` | 8 |
| `ship_idx` | home_world.gd:474 | `EconFace.trade_ship_in_port()` | 3 |
| `union.density` | media_ops.gd:1579 | the `ECON_UNION_DENSITY` indicator | 9 |
| `emissions` | planet_climate.gd:239, planet_ecology.gd:162 | `EconFace.emissions()` (Terra's) | 9 |
| `commute_rows` | freight_roads.gd:331 | `EconFace.query_commuting()` (already in the doorway) | 4 |
| `world.peek("donation_offer")` | party_life.gd:862 | `EconFace.donation_offers()` | 9 |
| `world.peek("org")`, `"facility"`, `"project"`, `"hh"` | media_ops.gd (8), gov_builder.gd (31), legislature.gd (9), home_world.gd (3), office (6), bench.gd (2), staff_ops.gd (1), hot_issues.gd (1) | the company record, its plants, the building contracts, the household pools, read through the doorway | 3, all by 11 |

The test `world.table("econ").has("s")` (legislature, home world, office feed: "is there an economy?") becomes
`EconFace.running()` **(E)**, true from step 3.

**Step 3 must define `EconFace.running()` on something real** (companies trading, or households paid wages this
month), not on the old table's presence: nothing in the rebuild writes table "econ", so until then the press never pays
wages or gets its subsidy (Anni's review of step 2).

**Capital is not income** (step 2, `econ_publish.gd` CAPITAL_MEMOS): the landing treasury is in the treasury and the
runway, not in the balance's income. Step 5 must add the memo of every loan the bank makes to the purse (12.8, 50), or
the balance counts debt as revenue, and decide whether repayments show apart from spending (Anni's review). Open for
Wilma: whether selling the landing stock (12.2, 9) is income or the sale of an asset (capital); Anni leans to capital.
Decided (Wilma): capital. Step 3 gives the stock sales the memo `LANDING_STOCK_SALE` and adds it to CAPITAL_MEMOS. The
sales are first paid into Colony Stores' own `co:` account, which is outside the purse. So the memo must be on the
payment that brings that money INTO a `gov:` account (the Stores' payment to the treasury), not only on the sale.
Otherwise the money enters the purse under another memo (a dividend, a transfer) and counts as income after all.

**The purse is every `gov:` account** (step 2, `econ_publish.gd`): the treasury, the law's fines account and any other
the government keeps apart. Its income, spending and balance count them together.

---

## 7. Doorway answers politics reads, by step

What each answers until its step is what EconFace answers today (plain answers, checked in my review of 90cd880).
Three must change shape before the step that wakes them:

- `trade_export_pressure` → `{"left_total": 0}` (home_world.gd:433 indexes it);
- `households_pay_media_wages` connected in step 3 with the households. Otherwise every newspaper closes once the
  household pools exist (media_ops.gd:1750 and 1836);
- `facts_emit` → the fact store (core), now.

| Doorway function | Step |
|---|---|
| `households_persons`, `households_disposable`, `labor_employed`, `labor_staff_total`, `pop_*`, `cohorts_slums`, `query_demography`, `query_labour`, `training_summary`, `firm_colony_unemployment`, `households_pay_media_wages` | 3 |
| `trade_next_ship`, `trade_last_ship`, `trade_fleet`, `trade_hold_of`, `trade_set_hold`, `trade_add_ship`, `trade_ship_interval` | 3 |
| `query_essentials`, `query_shortages`, `query_market_overview`, `query_companies`, `query_company_profile`, `query_explain_facility`, `query_explain_fact`, `query_recent_econ_facts` | 3 (food), all items 4 |
| `query_projects`, `query_explain_project` | 3 |
| `construction_estimate` | 8, with headroom (section 5) |
| `rulesutil_capacity_on` | 3: answers true. The rules run for every type ("no rule is skipped for a type") **(E)** |
| `staple_active`, `staple_raw_pct` | 4 |
| `inst_*`, `publicco_pending`, `query_police`, `query_prisons`, `police_org` | 4 |
| `query_commuting` | 4 |
| `annual_months`, `annual_sum12` | 3: they call Bob's `Company.months_on_books(world, cid)` and `Company.revenue_12(world, cid)`, never his books dictionary. They then take (world, company id), not a record, so justice_ops `annual_rev` passes the id. The law's fines read a firm's revenue through them from the first sale |
| `insolvency_court_liquidation` | 5 |
| `query_upgrade_options`, `query_commission_options`, `query_tenders` | 8 |
| `actions_headroom`, `query_budget_view`, `finance_gov_pay`, `finance_spend_line` | 8 |
| `essentials_offers` | 8 (securing the essentials, 102) |
| `essentials_human_governs` | **(E)** not the economy's: whether the player governs is politics' own. It moves to politics (office_feed.gd:17) |
| `query_workload`, `workload_active` | 9 |
| `unions_active`, `unions_get_union`, `unions_spare_fund`, `unions_strike_weeks`, `disputes_dispute_of`, `disputes_pending_demands` | 9 |
| `unions_federation` | stays `{}`: there is no federation (12.12). Its 7 callers (bench, media, union politics) read "none" for good |
| `unions_of_occ`, `UNIONS_MODERATE` | 9. **(E)** A union's occupation is the occupation column of the type of the company it started at, so `of_occ` answers the union started in that occupation |
| `UNIONS_DONATION_MIN` | 9. **(E)** "may spend on politics only what it holds beyond one month of shutdown pay" (71) is the test; `spare_fund` answers that amount and the minimum stays a size below which a gift is not worth making |
| `trade_balance`, `trade_export_pressure`, `trade_port_stock`, `trade_port_capacity`, `trade_prices`, `trade_home_tariff` | 10 (the port's size and prices, 105 and 106, at 10) |

---

## 8. What the step 11 check is

For every row above: the name is published, or the act connected, by its step; its effect is the rebuild's; and
nothing reads the economy except through EconFace. At step 11 the stand-in's levers and indicators are removed, and
the voters read the real ones. The check fails on any name in this file that is neither published nor marked gone.
