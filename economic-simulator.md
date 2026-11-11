# Political Colony Simulator
## Economic Simulation — Detailed Technical Specification
**Version:** 0.2  
**Status:** Proposed implementation rules  
**Simulation frequency:** Monthly  
**Economic architecture:** Mixed, decentralized, stock-flow simulation

---

# 1. Economic Objectives

The economic simulation must support five gameplay objectives.

**1. Economic decisions create meaningful dependencies.**

Building a factory requires materials, workers, equipment, infrastructure, and funding. A shortage in one area can prevent progress elsewhere.

**2. Companies operate independently.**

Private businesses make production, employment, pricing, bidding, and investment decisions. Government-owned businesses also have operating constraints.

**3. Money and materials are conserved.**

A purchase transfers money from one actor to another. A delivery transfers goods between inventories. Production transforms inputs into outputs according to defined recipes.

**4. Economic changes produce political consequences.**

Unemployment, prosperity, housing costs, shortages, industrial growth, and public-service quality influence the population's interests and political preferences.

**5. The simulation remains manageable.**

The player does not manually operate every factory or warehouse. Economic actors respond automatically to circumstances, while the player manages strategic decisions and exceptions.

The intended result is an economy that is complex in its interactions but relatively simple in its individual rules.

---

# 2. Economic Entities

The simulation should use distinct entities for economic actors and physical assets.

| Entity | Represents |
|---|---|
| Government | Public finances, policies, assets, procurement |
| Company | A public or private economic organization |
| Facility | A building or operation with productive capacity |
| District | A geographic area with infrastructure and residents |
| Household group | An aggregated population with shared economic characteristics |
| Resource | A defined commodity or physical input |
| Inventory | Resources owned and stored at a specific location |
| Transport network | Connections used for distributing resources |
| Contract | An agreement between economic actors |
| Project | Construction, development, or administrative undertaking |
| Shipment | Resources moving between locations |
| Transaction | A transfer of money |
| Employment allocation | Workers assigned to companies and facilities |

A company and a facility must be separate entities.

For example, one private company may own a mine, a processing plant, and a warehouse. If that company becomes insolvent, its facilities do not simply disappear. They may close, be sold, enter administration, or acquire new operators.

Likewise, a government-owned facility can be operated by a contracted private company without transferring ownership.

---

# 3. Economic Ownership

## 3.1 Ownership categories

Every facility has a legal owner and an operating entity.

Ownership categories:

- Government-owned.
- Privately owned.
- Jointly owned, for later development.

Initially, government-owned and privately owned facilities are sufficient.

## 3.2 Public enterprises

A government-owned enterprise has its own operating account and budget.

It may:

- Sell goods or services.
- Purchase materials.
- Hire employees.
- Accumulate operating surpluses.
- Require government subsidies.
- Invest in productive capacity when authorized.

The government does not directly receive every credit that a public enterprise earns.

Instead, the enterprise may pay taxes, transfer dividends, retain profits, or receive subsidies according to applicable rules.

This distinction prevents public revenue from being counted twice.

## 3.3 Private enterprises

Private firms operate with their own:

- Financial reserves.
- Operating revenue.
- Employment costs.
- Material purchases.
- Debts.
- Investments.
- Profits or losses.

Private companies may compete for public contracts and supply other companies.

## 3.4 Starting colony economy

The founding expedition should arrive with:

- Government funding.
- Initial resource stockpiles.
- Basic infrastructure.
- Government-owned facilities.
- Several private companies.
- A founding population.
- Limited imported equipment.
- Existing ownership arrangements.

The founding economy must be viable for a reasonable period before requiring major expansion.

A starting scenario should not become unwinnable merely because the player fails to identify a hidden dependency during the tutorial.

---

# 4. Resource System

## 4.1 Resource definitions

The first economic model uses eight principal physical resources.

| ID | Resource | Unit | Primary use |
|---|---|---|---|
| FOOD | Food | Supply units | Household consumption |
| WATER | Water | Supply units | Households, farms, industry |
| ENERGY | Energy | Energy units | Facility and utility operation |
| MINERAL | Raw minerals | Material units | Industrial processing |
| MATERIAL | Construction materials | Material units | Buildings and infrastructure |
| COMPONENT | Industrial components | Component units | Machinery and advanced construction |
| CONSUMER | Consumer goods | Goods units | Household consumption |
| MEDICAL | Medical supplies | Supply units | Healthcare |

Credits are recorded separately as currency.

Labor, land, production capacity, and transport capacity are constraints rather than inventory commodities.

## 4.2 Storage

Resources require inventories.

An inventory records:

- Resource type.
- Quantity.
- Owner.
- Storage location.
- Maximum storage capacity.
- Quantity reserved for orders.
- Quantity available for sale or consumption.

The same material cannot be simultaneously allocated to several projects.

**Available stock = physical stock − reserved stock.**

Storage limits are enforced before deliveries are accepted.

Perishable goods may receive storage-loss mechanics in a later version.

## 4.3 Resource ownership

Resources belong to specific economic actors.

Examples:

- Food stored by an agricultural company.
- Construction materials owned by a building contractor.
- Emergency supplies owned by the government.
- Consumer goods owned by a retail company.

Ownership changes when a transaction or legally defined transfer occurs.

Materials should not be treated as a single shared colony inventory unless a specific institution actually controls that inventory.

## 4.4 Resource accounting

For a physical inventory:

**Closing quantity = opening quantity + production + deliveries received − production inputs − deliveries dispatched − consumption − losses.**

Transfers between inventories must be recorded at both ends.

Resources can be created through production or imports, transformed through production recipes, consumed, or destroyed through defined loss mechanisms.

A resource must never appear simply because a project requires it.

---

# 5. Production System

## 5.1 Production recipes

Each productive facility has one or more production recipes.

A recipe specifies:

- Required inputs.
- Output quantity.
- Labor requirement.
- Energy requirement.
- Production duration.
- Production capacity.
- Operating conditions.

Recipes should be defined in game data, not hardcoded individually.

## 5.2 Example recipes

The following are provisional monthly recipes at full operation.

| Facility | Monthly inputs | Monthly output |
|---|---|---|
| Mineral mine | 20 workers, 10 energy | 30 minerals |
| Processing plant | 30 minerals, 10 energy, 20 workers | 20 materials |
| Component factory | 20 materials, 20 energy, 15 skilled workers | 10 components |
| Farm | 15 workers, 20 water, 5 energy | 50 food |
| Consumer factory | 10 materials, 10 energy, 15 workers | 30 consumer goods |
| Medical manufacturer | 5 components, 10 energy, 10 skilled workers | 20 medical supplies |

These are illustrative production relationships, not yet balanced economic values.

Some facilities, particularly power and water facilities, also produce inputs required by other industries.

## 5.3 Production capacity

Each facility has a maximum monthly output.

Actual production depends on the least available essential input.

For facility \(f\):

\[
Q_f=C_f \times U_f \times E_f
\]

Where:

- \(Q_f\) = actual output.
- \(C_f\) = maximum output capacity.
- \(U_f\) = input availability factor.
- \(E_f\) = operational efficiency.

The input factor is:

\[
U_f=\min(1,r_1,r_2,\ldots,r_n)
\]

Each \(r_i\) is the available quantity of an essential input divided by its full-capacity requirement.

Example:

A factory requires 30 minerals to operate at full capacity but receives only 18.

Its mineral availability factor is:

\[
18/30=0.60
\]

If all other inputs are sufficient and operational efficiency is 100%, the factory produces 60% of its normal output.

## 5.4 Operational efficiency

Efficiency can depend on:

- Facility condition.
- Equipment quality.
- Worker skill.
- Company management.
- Technology.
- Regulatory constraints.
- Maintenance.

The initial implementation should limit these to a small number of multipliers.

Suggested initial formula:

\[
E_f=E_{\text{condition}}\times E_{\text{skill}}
\]

Company management effectiveness can initially influence operating costs and project reliability, avoiding too many overlapping multipliers.

## 5.5 Production timing

Production should operate on monthly batches.

Inputs available at the start of a production phase may be consumed during that month.

Newly manufactured physical goods become available to downstream facilities in the following month's production allocation.

This creates realistic inventory buffers and prevents unlimited processing through entire supply chains within a single month.

## 5.6 Fractional production

The simulation must define whether partial units are supported.

Recommendation:

Use fixed-point quantities internally, such as thousandths of a resource unit, while displaying rounded quantities to the player.

This avoids unnecessarily discarding production and consumption fractions.

---

# 6. Energy and Water

Energy and water should be treated as essential utility systems, but they do not need identical storage mechanics.

## 6.1 Energy production

Power stations have:

- Generating capacity.
- Required fuel or environmental conditions.
- Workers.
- Operating costs.
- Equipment condition.
- Network connection.

Energy is allocated through the connected power network.

## 6.2 Energy allocation

When demand exceeds available supply, an explicit priority mechanism applies.

An initial priority order might be:

1. Essential life-support and emergency systems.
2. Essential household consumption.
3. Critical public services.
4. Contractually protected industrial supply.
5. Remaining commercial and industrial demand.

The exact priority order may later change through legislation, contracts, and emergency powers.

A shortage must not be concealed by assigning every facility the energy it requested.

## 6.3 Water

Water is produced or collected at extraction and treatment facilities.

Water can be stored and distributed, subject to local network capacity.

Water availability influences residential capacity, agricultural production, and industrial output.

## 6.4 Utility network implementation

Version 1 should track whether facilities are connected to the relevant utility network and how much aggregate capacity that network can supply.

A later implementation can add local line capacities and transmission losses.

---

# 7. Employment and Labor

## 7.1 Workforce categories

The founding economic model uses three labor categories.

| Skill category | Examples |
|---|---|
| General | Construction labor, agriculture, transport |
| Skilled | Industrial processing, maintenance, mining |
| Specialist | Engineering, medicine, technical administration |

An individual facility may require several categories.

## 7.2 Household workforce

Each household group contains:

- Total population.
- Working-age population.
- Available workers by skill.
- Employed workers by skill.
- Unemployed workers by skill.
- Wage income.
- District of residence.

The population and labor totals must remain internally consistent.

## 7.3 Company labor demand

Companies create job vacancies based on:

- Planned production.
- Available funding.
- Expected sales.
- Current workforce.
- Facility capacity.
- Project commitments.

A business cannot hire workers indefinitely without meeting financial requirements.

## 7.4 Labor allocation

The monthly labor market matches job vacancies with available workers.

A simplified matching score can incorporate:

- Wage offered.
- Worker qualifications.
- Transport accessibility.
- Existing employment relationships.
- Working conditions.

The hiring algorithm should aim to fill vacancies without assigning the same worker to multiple full-time positions.

## 7.5 Skill shortages

If insufficient qualified workers are available, a facility operates below capacity.

Companies may respond by:

- Offering higher wages.
- Training workers.
- Recruiting migrants.
- Reducing production.
- Delaying expansion.

Training takes time and resources.

Migration also depends on housing availability and living conditions.

## 7.6 Wages

Wages are established by company decisions, labor-market conditions, and applicable law.

A simplified wage-adjustment model can use local labor shortages.

For example:

- High unemployment weakens upward wage pressure.
- Persistent vacancies increase wage pressure.
- Higher productivity supports higher sustainable wages.
- Minimum-wage or collective-agreement rules may establish limits.

The initial implementation should adjust wage offers gradually rather than recalculating every wage from scratch each month.

## 7.7 Employment accounting

Every employed worker must be counted exactly once in the labor market for the relevant work allocation.

Wages paid by companies or public institutions must be received by the corresponding household groups, subject to income taxes.

---

# 8. Household Economy

## 8.1 Aggregation model

Households are represented by groups with similar economic circumstances.

The recommended starting grouping is:

**District × income category × labor skill category.**

To control complexity, groups with very small populations can be merged.

Each group contains a population count and aggregate financial balances.

This preserves regional and socioeconomic differences without individually simulating thousands of households.

## 8.2 Household income

Household groups may receive:

- Wages.
- Business income distributions.
- Public transfers.
- Pensions or benefits.
- Other defined income.

Income taxes and other deductions reduce disposable income.

\[
\text{Disposable income}
=
\text{Gross income}
-\text{Taxes}
+\text{Transfers}
\]

## 8.3 Household expenditure

Households spend income on:

- Food.
- Water.
- Energy.
- Housing.
- Consumer goods.
- Medical services or supplies where applicable.
- Other public or private services.

Essential consumption should have minimum requirements.

Discretionary consumption depends on remaining purchasing power.

## 8.4 Household savings

Unspent income can accumulate as savings.

Households experiencing high costs may draw down savings.

Persistent income shortages can result in financial insecurity.

Initially, household borrowing can be omitted to simplify the economy.

## 8.5 Consumption behavior

A proposed consumption process:

1. Determine essential needs.
2. Calculate disposable income and available savings.
3. Evaluate local prices and available supply.
4. Attempt essential purchases.
5. Allocate remaining spending to discretionary goods.
6. Record unmet needs.
7. Update savings and financial security.

Purchasing goods requires both supply and purchasing power.

If insufficient food exists, high household income cannot create additional food automatically.

If food is available but unaffordable, households may still experience shortages.

## 8.6 Housing

Housing is a separate economic capacity system.

Residential facilities provide a number of housing units.

Each district tracks:

- Total housing capacity.
- Occupied units.
- Available units.
- Housing quality.
- Housing costs.
- Utility access.

Housing prices or rents respond to local availability, desirability, operating costs, and demand.

A household's housing expense is recorded as a payment to a landlord, housing enterprise, or public housing operator.

## 8.7 Household well-being

Economic well-being should derive from actual conditions.

Initial indicators:

- Employment.
- Real disposable income.
- Food security.
- Housing affordability.
- Utility reliability.
- Access to services.
- Financial reserves.

The game should preserve the underlying indicators rather than relying entirely on a single satisfaction number.

---

# 9. Dynamic Prices

## 9.1 Price objectives

The price system must:

- Respond to shortages and surpluses.
- Reflect changing production costs.
- Incorporate competition.
- Account for logistics.
- Remain reasonably stable across monthly turns.
- Support actual transactions.

## 9.2 Reference prices

Each commodity has a reference price.

This is a market indicator used for planning and estimates, not a guarantee that goods can be purchased.

For commodity \(r\), define:

- \(P_r\): current reference price.
- \(S_r\): available market supply, including saleable inventory and scheduled arrivals.
- \(D_r\): effective demand.
- \(P_{\min}\), \(P_{\max}\): provisional price bounds.

Effective demand means demand supported by actual purchasing power, budgets, or credible purchase commitments.

Unfunded requests may be tracked separately as unmet needs.

## 9.3 Price adjustment

A possible monthly formula:

\[
P_{r,t+1}=
\operatorname{clamp}
\left[
P_{r,t}
\left(
1+\alpha\frac{D_r-S_r}{\max(D_r,S_r,\epsilon)}
\right),
P_{\min},P_{\max}
\right]
\]

Where:

- \(\alpha\) controls price responsiveness.
- \(\epsilon\) prevents division by zero.
- Clamp prevents unrealistic price changes.

For early testing, \(\alpha=0.15\) is a reasonable provisional value.

The price floor and ceiling should be broad safeguards, not a way to suppress shortages permanently.

## 9.4 Seller prices

Companies can offer goods above or below the market reference price.

Their asking prices depend on:

- Production costs.
- Desired profit margin.
- Inventory levels.
- Competition.
- Cash requirements.
- Existing contracts.

A seller with excess stock may discount its goods.

A company facing strong demand may increase prices.

## 9.5 Market clearing

Actual trade requires matching buyers and sellers.

For each commodity:

1. Collect sale offers and purchase orders.
2. Identify compatible buyers and suppliers.
3. Calculate delivered prices.
4. Respect buyer budgets.
5. Respect seller inventories.
6. Respect logistics capacity.
7. Execute feasible trades.
8. Record unfilled demand and unsold supply.

The first implementation can use a deterministic priority or price-based matching algorithm rather than a complex continuous auction.

## 9.6 Market competition

Companies should compete on delivered price, not merely factory-gate price.

A nearby supplier charging 110 credits may be cheaper overall than a distant supplier charging 95 credits with 25 credits of delivery costs.

Existing supply contracts and company reputation can also influence purchasing decisions.

## 9.7 Inflation

The simulation can calculate a consumer price index using a weighted basket of household expenditures.

This is preferable to inventing a separate inflation variable.

A rising cost of living then reflects actual changes in food, energy, housing, and consumer prices.

---

# 10. Logistics

## 10.1 Transport network

The map contains transport links connecting districts and facilities.

Each link has:

- Origin and destination.
- Travel distance or cost.
- Monthly cargo capacity.
- Condition.
- Operating cost.

## 10.2 Transport capacity

A shipment consumes available capacity along its route.

Two shipments using the same limited road cannot both claim the full road capacity.

The routing system must reserve transport capacity for scheduled deliveries.

## 10.3 Freight costs

A basic freight calculation:

\[
C_{\text{freight}}
=
Q\times
\sum_{e\in\text{route}} c_e
\]

Where:

- \(Q\) = quantity shipped.
- \(c_e\) = cost per unit for each transport link.

Route costs may reflect distance, terrain, and infrastructure condition.

## 10.4 Shipment duration

Short local shipments may arrive within a single month.

Long-distance or constrained routes may require multiple months.

Every shipment has:

- Origin.
- Destination.
- Owner.
- Commodity.
- Quantity.
- Departure month.
- Expected arrival month.
- Transport reservation.
- Delivery status.

## 10.5 Logistics companies

Private or government-owned transport companies can provide delivery services.

Their costs depend on labor, energy, equipment, and transport infrastructure.

The first implementation can abstract the transport fleet into monthly capacity rather than simulating individual vehicles.

## 10.6 Infrastructure value

Roads and logistics infrastructure create economic benefits by:

- Reducing freight costs.
- Increasing route capacity.
- Improving access to employment.
- Connecting new facilities.
- Enabling otherwise impractical development.

Their value emerges from economic activity rather than fixed arbitrary bonuses.

---

# 11. Limited Interplanetary Imports

## 11.1 Import model

The colony can purchase limited supplies from its origin civilization.

Imports require:

- Credits.
- Available external supply.
- Cargo capacity.
- Import authorization where applicable.
- Delivery time.

## 11.2 Import costs

Imported goods have:

- External purchase price.
- Freight charge.
- Handling costs.
- Applicable tariffs or taxes.

A provisional formula:

\[
P_{\text{import}}
=
P_{\text{origin}}
+
C_{\text{freight}}
+
C_{\text{handling}}
+
C_{\text{tariff}}
\]

For early balancing, imported goods may cost approximately two to four times the ordinary local reference price, depending on the commodity.

This is a proposed balancing range, not an established rule.

## 11.3 Delivery delays

Imports should not arrive immediately.

An illustrative import shipment might require three months.

Delivery times can vary with available capacity and special events.

## 11.4 Import quotas

The colony has a maximum external cargo capacity per delivery period.

Imports compete for this capacity.

The player may have to prioritize medical supplies over industrial equipment, for example.

## 11.5 Private imports

Private companies should also be capable of importing goods, subject to the same transport constraints and applicable regulation.

The government should not automatically control all imported materials.

## 11.6 Imports and market prices

Imports can relieve local shortages, but their cost creates an economic incentive to develop domestic production.

Import orders must be tracked when determining anticipated future supply.

Goods that have been ordered but have not yet arrived cannot be consumed or used in construction.

## 11.7 Export policy

Exports are not essential for the first implementation.

A later version can allow companies to sell surplus goods externally, subject to cargo capacity and market access.

If exports are introduced, foreign sales and imported spending must both be represented in financial accounting.

---

# 12. Company Finances

## 12.1 Company balance sheet

Each company tracks:

**Assets**
- Cash.
- Inventories.
- Facilities.
- Equipment.
- Receivables.

**Liabilities**
- Loans.
- Payables.
- Contract obligations.
- Other financial commitments.

**Equity**
- Net assets attributable to ownership.

## 12.2 Operating profit

A company's monthly operating result is:

\[
\text{Operating profit}
=
\text{Revenue}
-
\text{Materials consumed}
-
\text{Wages}
-
\text{Energy and utilities}
-
\text{Logistics}
-
\text{Maintenance}
-
\text{Other operating expenses}
\]

Taxes, financing costs, and capital expenditure are handled according to the accounting model.

Inventory purchases should not automatically count as both an immediate expense and a later production expense.

## 12.3 Cash flow

Profit and cash are different.

A company may report a profit while waiting for customers to pay invoices.

Conversely, a company may have cash reserves while operating at a loss.

This matters for contractor reliability and insolvency.

## 12.4 Company investment

Companies may choose to:

- Increase production capacity.
- Build facilities.
- Upgrade equipment.
- Improve logistics.
- Recruit workers.
- Enter new markets.

Investment decisions depend on expected demand, available capital, projected profitability, and risk.

A company should not expand simply because its reputation is high.

## 12.5 Insolvency

A company becomes financially distressed if it cannot meet its obligations.

Possible consequences:

- Delayed wages.
- Reduced production.
- Sale of assets.
- Contract default.
- Restructuring.
- Bankruptcy.

Bankruptcy should not destroy physical assets.

Facilities may change ownership or remain temporarily inactive.

## 12.6 Reputation

Reputation is related to actual company behavior.

It can be influenced by:

- Contract delivery.
- Quality.
- Financial reliability.
- Workplace safety.
- Environmental compliance.
- Public controversies.

Reputation influences future contracts and some customer decisions, but is not identical to operational competence.

---

# 13. Government Finances

## 13.1 Treasury

The government has a treasury containing available credits.

Government cash changes through actual receipts and payments.

## 13.2 Revenue

Initial revenue sources:

- Personal income taxes.
- Company profit taxes.
- Returns from public enterprises.
- Defined fees or charges.

Property, consumption, and resource taxes can be developed later.

## 13.3 Expenditure

Government spending includes:

- Public wages.
- Public-service operating costs.
- Construction payments.
- Goods and services procurement.
- Subsidies.
- Social transfers.
- Infrastructure maintenance.
- Debt servicing.

## 13.4 Tax timing

Personal income taxes can be withheld when wages are paid.

Company profit taxes can initially be assessed periodically based on taxable earnings.

Tax losses and deductions require an explicit simplified rule rather than taxing every company's positive month while ignoring its previous losses.

## 13.5 Budget authorization

The government maintains three distinct quantities:

- Cash on hand.
- Approved budget allocations.
- Outstanding expenditure commitments.

A project can have an approved budget without its entire cost being paid immediately.

## 13.6 Example

A construction project is approved for 2 million credits.

The government reserves spending authority for the project.

The contractor receives payments when contractual milestones are completed.

Unused funds remain in the treasury.

The government must retain sufficient liquidity to meet future obligations.

This is particularly important when several long projects are underway simultaneously.

## 13.7 Debt

Government borrowing should be supported, but initially simplified.

Debt has:

- Principal.
- Interest rate.
- Repayment obligations.
- Maturity or repayment schedule.

Borrowing creates new government cash and a corresponding liability.

Interest payments transfer money to creditors.

The game should define who provides the loan rather than creating unexplained financial income.

## 13.8 Political authorization

After parliamentary government begins, taxes, spending authorization, and major economic interventions are governed by legislation and budget rules.

The economic engine processes these policies, but does not determine whether they were lawfully approved.

That responsibility belongs to the political and legislative systems.

---

# 14. Construction and Procurement

## 14.1 Project requirements

A construction project requires:

- Approved site.
- Legal authorization.
- Funding.
- Construction materials.
- Components where necessary.
- Workforce.
- Equipment and contractor capacity.
- Logistics access.

## 14.2 Bidding

Companies submit bids based on projected costs.

A provisional bid formula:

\[
\text{Bid}
=
\text{Expected material cost}
+
\text{Labor cost}
+
\text{Logistics cost}
+
\text{Equipment cost}
+
\text{Risk allowance}
+
\text{Profit margin}
\]

Different companies estimate costs differently.

Companies may also misjudge project difficulty, creating unexpected overruns.

## 14.3 Contract structure

A construction contract records:

- Contractor.
- Client.
- Project.
- Price.
- Estimated duration.
- Payment schedule.
- Material responsibilities.
- Performance requirements.
- Penalties.
- Termination conditions.

The contract must specify whether the contractor purchases materials or the government supplies them.

Otherwise, project costs may be counted twice.

## 14.4 Construction progress

Progress depends on available productive capacity and actual resources.

An initial model:

\[
\text{Monthly progress}
=
\text{Base progress rate}
\times
\text{Input availability}
\times
\text{Contractor efficiency}
\]

Progress is limited by project stage and outstanding work.

Required construction inputs are consumed according to actual progress.

## 14.5 Contractor workload

A contractor may handle multiple projects, subject to its construction workforce, equipment, and management capacity.

Taking more contracts than it can support increases delay risk.

## 14.6 Project failure

Projects may fail through:

- Contractor bankruptcy.
- Severe cost overruns.
- Unavailable materials.
- Major technical problems.
- Withdrawal of authorization.
- Termination or cancellation.

Failure does not imply that all previous work disappears.

Partially constructed assets and unused materials remain accounted for.

---

# 15. Government Personnel and Economic Projects

The economic engine must connect directly to the 20-person government management system.

## 15.1 Personnel do not replace ordinary workers

The ten political personnel and ten permanent civil servants represent managerial and administrative capacity.

They are distinct from the thousands of ordinary public and private employees represented in the labor economy.

## 15.2 Long-term assignments

An official may be assigned to supervise a project for several months or years.

Examples:

- Oversee mining development.
- Coordinate housing construction.
- Supervise a transportation expansion program.
- Manage industrial subsidies.
- Administer a public healthcare expansion.

## 15.3 Delegated authority

Each long-term assignment has:

- Responsible official.
- Objective.
- Assigned budget.
- Authorized actions.
- Reporting frequency.
- Escalation conditions.
- Workload requirement.
- Expected completion or review date.

An assigned official can make routine decisions within the approved mandate.

## 15.4 Management effectiveness

Officials influence:

- Contract monitoring.
- Administrative delays.
- Procurement quality.
- Compliance.
- Coordination.
- Problem detection.

They do not directly create materials, eliminate construction labor requirements, or guarantee successful projects.

## 15.5 Standing responsibilities

Officials may be assigned to ongoing economic responsibilities, such as overseeing public infrastructure or procurement.

These assignments continue month after month.

Routine work is automatically handled.

The player intervenes when significant decisions exceed the official's authority.

---

# 16. Monthly Economic Processing

The simulation should use a fixed monthly sequence.

## Phase 1 — Apply decisions

Apply:

- New laws.
- Authorized budgets.
- Approved contracts.
- New staff assignments.
- Company production decisions.
- Construction orders.
- Import orders.

## Phase 2 — Establish opening capacity

Determine:

- Operational facilities.
- Available workers.
- Utility capacity.
- Available inventory.
- Transport network capacity.
- Financial resources.

New construction completed in the previous month becomes available.

## Phase 3 — Market planning

Companies and households generate purchase intentions.

Companies determine desired production and required inputs.

Households determine consumption demand based on needs and available funds.

Government institutions submit purchases consistent with their budgets.

## Phase 4 — Labor and utility allocation

Match workers to vacancies.

Allocate electricity and water through the relevant networks.

Apply shortages and determine feasible operating capacity.

## Phase 5 — Trade and shipping

Match buyers and sellers.

Check:

- Prices.
- Inventory.
- Purchasing power.
- Freight availability.
- Delivery times.

Create transactions and shipments.

Reserve goods and funds as required by the chosen payment terms.

## Phase 6 — Production and project execution

Facilities consume available inputs.

New goods are produced.

Construction projects advance.

Finished output enters the relevant inventory.

Output cannot be reused by downstream production in the same monthly production batch.

## Phase 7 — Financial settlement

Process:

- Wages.
- Supplier payments.
- Contract milestones.
- Taxes.
- Government transfers.
- Operating expenses.
- Debt payments.

Every payment must specify its source and destination.

## Phase 8 — Households and public conditions

Calculate:

- Actual consumption.
- Household savings.
- Unmet essential needs.
- Housing affordability.
- Unemployment.
- Real income.
- Public-service accessibility.

## Phase 9 — Business and investment decisions

Companies review:

- Profitability.
- Cash reserves.
- Demand.
- Capacity.
- Workforce availability.
- Debt.
- Investment opportunities.

They may plan expansion, contraction, new bidding, or other future actions.

## Phase 10 — Political and historical updates

Economic conditions feed into the political system.

Update:

- District economic indicators.
- Political issue pressure.
- Public assessments of government competence.
- Economic aspects of party support.
- Historical records.

The detailed party and voting calculations belong to the political simulation specification.

---

# 17. Worked Economic Example

Consider a simplified settlement with:

- 1,000 residents.
- 500 available workers.
- One mine.
- One processing plant.
- One government construction project.
- Several household groups.

The mine produces 30 minerals per month at full capacity.

The processing plant requires 30 minerals to produce 20 construction materials.

The government wants to build additional housing requiring 100 construction-material units.

Assume the contractor can use 20 material units per month.

## Month 1

The mine operates and produces 30 minerals.

The processing plant has no opening mineral inventory.

Therefore, it cannot produce construction materials this month.

The government construction project has insufficient materials and does not begin physical construction.

The mine pays wages and incurs operating costs.

## Month 2

The processing plant receives or purchases the 30 minerals produced in Month 1, subject to delivery capacity.

It produces 20 construction materials.

The mine produces another 30 minerals.

The construction contractor still cannot consume the newly processed materials in the same monthly production batch.

## Month 3

The contractor obtains the previous month's construction materials, subject to delivery.

It advances housing construction by 20 material units.

The processing plant produces another 20 construction materials, assuming inputs remain available.

The government makes the scheduled construction payment.

The contractor pays workers and suppliers.

## Month 4 onward

The production chain continues.

Further housing progress depends on materials, available labor, contractor capacity, logistics, and payment.

After five fully supplied construction months, the project's 100 material units have been incorporated.

Other project requirements must also be satisfied before completion.

## Political consequences

The construction project creates temporary employment.

The mine and processing plant create ongoing jobs and industrial revenue.

New housing may improve affordability and permit migration.

However, industrial activity may increase pollution and infrastructure demand.

The government's success or failure in delivering the project influences public perceptions.

The political effects emerge from the underlying economic results.

---

# 18. Economic-to-Political Interface

The economic system should not directly calculate parliamentary seats or party election results.

Instead, it should produce indicators that the political simulation consumes.

## 18.1 District indicators

Each district reports:

- Employment rate.
- Unemployment rate.
- Average wage income.
- Real disposable income.
- Income inequality.
- Housing affordability.
- Essential-goods availability.
- Utility reliability.
- Economic growth or decline.
- Pollution.
- Public-service quality.

## 18.2 Colony-wide indicators

The colony reports:

- Total production.
- Employment.
- Government revenue.
- Government expenditure.
- Public debt.
- Consumer prices.
- Business investment.
- Company failures.
- Infrastructure condition.
- Import dependency.
- Aggregate economic activity.

## 18.3 Historical changes

The political system should receive both current conditions and trends.

For example:

- Unemployment is 8%.
- Unemployment increased from 4% over the last year.
- The increase is concentrated in mining districts.
- Government industrial subsidies failed to prevent layoffs.

The trend and geographic distribution provide more political information than a single colony-wide statistic.

---

# 19. Conservation and Accounting Rules

These are mandatory technical safeguards.

## Rule 1 — No duplicate inventory

The same quantity of physical goods cannot be simultaneously owned by multiple actors or reserved for multiple uses.

## Rule 2 — No duplicate employment

The same worker capacity cannot be fully allocated to multiple employers during one month.

## Rule 3 — No free construction

Construction must consume the resources and labor associated with its actual progress.

## Rule 4 — Financial transfers balance

Ordinary payments subtract credits from the payer and add them to the recipient.

Currency creation, destruction, external payments, and borrowing must be explicit economic operations.

## Rule 5 — No unlimited import availability

External supply and freight capacity are constrained.

## Rule 6 — Production does not precede inputs

Facilities cannot produce output without the required resources and capacity.

## Rule 7 — Failed companies retain physical assets

Bankruptcy changes the control, ownership, or operational status of assets rather than deleting them.

## Rule 8 — Governments obey economic constraints

Government ownership and legislative authority do not allow the government to ignore resource scarcity, labor shortages, or capacity limits.

## Rule 9 — Avoid double-counting

Inventory purchases, capital investments, taxes, subsidies, and public-enterprise transfers require consistent accounting treatment.

## Rule 10 — Every shortage is explainable

The player should be able to inspect a facility or project and identify the cause of a shortage, such as materials, labor, finances, utility supply, or logistics.

---

# 20. Recommended Implementation Order

The economic engine should be implemented in the following sequence.

## Stage E1 — Resource accounting

Implement:

- Resource definitions.
- Inventories.
- Resource transfers.
- Storage limits.
- Reservations.
- Resource conservation tests.

**Acceptance test:** Materials cannot disappear, duplicate, or be consumed twice.

## Stage E2 — Production

Implement:

- Facilities.
- Recipes.
- Production capacity.
- Input constraints.
- Operational efficiency.
- Monthly output.

**Acceptance test:** Resource shortages reduce production predictably.

## Stage E3 — Ownership and money

Implement:

- Government accounts.
- Company accounts.
- Transaction ledger.
- Public and private ownership.
- Operating costs.
- Payment transfers.

**Acceptance test:** Every financial transaction has balanced entries and identifiable participants.

## Stage E4 — Labor and households

Implement:

- Aggregated household groups.
- Labor categories.
- Job vacancies.
- Hiring.
- Wages.
- Income taxes.
- Consumption.
- Savings.

**Acceptance test:** Workers earn wages, households purchase goods, and the labor market respects population limits.

## Stage E5 — Markets and prices

Implement:

- Market reference prices.
- Seller offers.
- Purchase orders.
- Buyer affordability.
- Matching.
- Unmet demand.
- Price updates.

**Acceptance test:** Shortages and surpluses influence prices, while actual purchases remain constrained by supply and budgets.

## Stage E6 — Logistics

Implement:

- Transport connections.
- Route costs.
- Monthly capacity.
- Shipments.
- Delivery schedules.
- Logistics bottlenecks.

**Acceptance test:** Insufficient freight capacity delays deliveries and can restrict downstream production.

## Stage E7 — Construction and contractors

Implement:

- Construction recipes.
- Company bidding.
- Project schedules.
- Labor and material requirements.
- Payment milestones.
- Delays.
- Contract failure.

**Acceptance test:** Multiple contractors can compete for a project with different costs, capabilities, and outcomes.

## Stage E8 — Government economy

Implement:

- Taxation.
- Public-service operating costs.
- Public enterprises.
- Budgets.
- Spending commitments.
- Subsidies.
- Debt.

**Acceptance test:** Government economic policy changes public finances and produces measurable economic effects.

## Stage E9 — Imports

Implement:

- External supplier.
- Import pricing.
- Freight capacity.
- Delivery delay.
- Import orders.
- Government and private imports.

**Acceptance test:** Imports can relieve shortages but cannot bypass delivery and financing constraints.

## Stage E10 — AI economic behavior

Implement:

- Company production planning.
- Pricing strategies.
- Hiring decisions.
- Investment decisions.
- Basic public-enterprise management.
- Financial distress responses.

**Acceptance test:** The colony's economy can operate for multiple years without requiring player control of individual firms.

## Stage E11 — Political integration

Implement:

- District economic indicators.
- Colony-wide statistics.
- Economic history.
- Political issue triggers.
- Government performance indicators.

**Acceptance test:** Different development strategies produce distinct and explainable economic conditions for the political simulation.

---

# 21. Automated Economic Testing

The simulation should run automated tests under several economic scenarios.

### Scenario A — Balanced settlement

Resources, jobs, and household needs are reasonably balanced.

Expected behavior: stable production, limited unemployment, functioning markets, and manageable public finances.

### Scenario B — Energy shortage

Energy supply falls below demand.

Expected behavior: affected facilities reduce production, critical service allocation follows the current policy, and energy prices face upward pressure.

### Scenario C — Construction boom

The government begins several major projects simultaneously.

Expected behavior: material demand rises, contractors compete for workers and supplies, and shortages or cost increases may occur.

### Scenario D — Company bankruptcy

A large contractor becomes insolvent.

Expected behavior: unfinished contracts are interrupted, workers and assets remain accounted for, and project owners can seek replacement contractors.

### Scenario E — Labor shortage

Several new factories open without sufficient skilled workers.

Expected behavior: vacancies persist, wage pressure rises, some production capacity remains unused, and companies adjust recruitment strategies.

### Scenario F — Import interruption

Interplanetary freight capacity is temporarily reduced.

Expected behavior: scheduled supplies are delayed, local inventories decline where relevant, and import-dependent industries face difficulties.

### Scenario G — Government austerity

Public investment and operational spending are reduced.

Expected behavior: government spending declines, contractors may lose demand, service capacity can deteriorate if underfunded, and public finances respond according to actual revenues and obligations.

### Scenario H — Long-term simulation

The economy runs automatically for 20 simulated years across different random seeds and starting conditions.

Expected behavior: transactions remain consistent, no resource duplication occurs, company assets persist correctly, and systemic failures can be traced to explicit causes.

Economic collapse should remain possible under sufficiently unfavorable conditions. The test objective is to eliminate erroneous or unexplained collapse, not to guarantee prosperity.

---

# 22. Technical Parameters to Balance

The following values should be stored in configuration rather than embedded in simulation logic.

| Parameter | Initial approach |
|---|---|
| Price adjustment speed | 0.15 per month |
| Production period | One month |
| Labor categories | Three |
| Household segmentation | District, income, skill |
| Resource categories | Eight |
| Import duration | Three months as a test baseline |
| Import price premium | Commodity-dependent |
| Company investment thresholds | Based on liquidity and expected returns |
| Worker recruitment speed | Limited monthly matching |
| Freight capacity | Based on network links |
| Production efficiency | Based on condition and skills |
| Company bankruptcy criteria | Persistent inability to meet obligations |

These are tuning parameters, not promises of optimal balance.

---

# 23. Economic Engine Completion Definition

The economic engine is ready for full political integration when the following sequence works without manual intervention:

1. Households supply labor.
2. Companies recruit and pay workers.
3. Production facilities purchase and consume inputs.
4. Facilities produce goods.
5. Companies distribute goods through constrained logistics.
6. Households purchase available goods using actual income.
7. Prices respond to changing market conditions.
8. Companies earn profits or experience losses.
9. Companies invest, expand, or contract.
10. Government collects taxes and pays obligations.
11. Government contracts create construction activity.
12. Construction creates new productive or residential capacity.
13. Imports provide limited external supplies.
14. Shortages have identifiable economic causes.
15. Economic conditions change district well-being.
16. Economic history is recorded for future political decisions.

The entire sequence must function across repeated monthly turns.

**Final architectural principle:** Economic actors should operate under the same resource, financial, and production constraints regardless of whether the government is controlled by the player or an AI political party.
