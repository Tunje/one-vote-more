# Political Colony Simulator — Population, Society, Demographics & Political Behavior

Complete Game Design and Development Specification

- Version: 0.8
- Status: Detailed development plan
- Simulation interval: Monthly turns
- Population architecture: Hierarchical population blocks
- Individual citizen simulation: Not required
- Political system: Multiparty parliamentary democracy, 151 seats
- Related systems: Colony map, housing, economy, companies, employment, institutions, media, elections, political parties, law, justice, healthcare, education, government, events

> Implementation plan and accepted deviations: `planning/spec-population-v1.md`.

## 1. System Overview

The population system will use a hierarchical block structure.

Instead of simulating every individual citizen, the game divides the population into increasingly specific groups. These groups are based on where people live, their economic position, their work, their philosophical outlook, and the external pressures affecting their circumstances.

The structure follows five levels:

1. Housing Block — Where people live.
2. Income Block — Their economic circumstances.
3. Work Block — Their employment or occupational position.
4. Philosophy Block — Their beliefs, priorities, and general outlook.
5. Effect Block — The external pressures currently influencing them.

Each level subdivides the population of the level above it.

The result is a detailed social simulation that can model how different populations respond to economic development, political decisions, social conditions, company behavior, and public institutions without creating thousands of independently simulated characters.

### 1.1 Core population hierarchy

```
COLONY POPULATION
│
├── HOUSING BLOCK A
│   │
│   ├── LOW INCOME
│   │   ├── MINING WORKERS
│   │   │   ├── Labor-oriented
│   │   │   │   ├── Pollution exposure
│   │   │   │   ├── Unsafe working conditions
│   │   │   │   └── No significant external pressure
│   │   │   │
│   │   │   ├── Market-oriented
│   │   │   └── Environment-oriented
│   │   │
│   │   ├── CONSTRUCTION WORKERS
│   │   ├── SERVICE WORKERS
│   │   └── UNEMPLOYED
│   │
│   ├── MIDDLE INCOME
│   │   ├── INDUSTRIAL WORKERS
│   │   ├── PROFESSIONAL WORKERS
│   │   └── OTHER OCCUPATIONS
│   │
│   └── HIGH INCOME
│       ├── BUSINESS OWNERS
│       ├── PROFESSIONAL WORKERS
│       └── OTHER OCCUPATIONS
│
├── HOUSING BLOCK B
│   └── Same subdivision structure
│
└── HOUSING BLOCK C
    └── Same subdivision structure
```

This is the conceptual hierarchy, not a requirement to create every possible branch. Branches are only created when people actually belong to them. An empty occupation or philosophy category does not need a population record.

### 1.2 Core design principle

Population blocks represent real groups of residents, not independent copies of those residents.

Every resident belongs to exactly one active leaf group in the hierarchy at a given moment.

A housing block with 600 residents must still contain exactly 600 residents after division into income, work, philosophy, and effect blocks.

External pressures may overlap, but they must not cause the population to be counted multiple times.

## 2. Population Accounting

Population conservation is a mandatory system rule. For every parent block:

P_parent = Σ P_children

Where P_parent is the parent block's population and P_children represents all direct child groups.

### 2.1 Example

Housing Block A contains 600 residents. Its income distribution is:

| Income group | Population |
|---|---|
| Low income | 240 |
| Middle income | 240 |
| High income | 120 |
| Total | 600 |

Within the low-income group, 100 residents belong to the mining-work category. Those 100 residents are divided into philosophy groups:

| Philosophy | Population |
|---|---|
| Labor-oriented | 45 |
| Market-oriented | 35 |
| Environment-oriented | 20 |
| Total | 100 |

The 45 labor-oriented residents might then be divided by current external pressures:

| Effect category | Population |
|---|---|
| Pollution exposure only | 20 |
| Pollution and unsafe work | 15 |
| No major exposure | 10 |
| Total | 45 |

These are 45 distinct residents represented in aggregate. The 15 residents exposed to both pollution and unsafe working conditions are not counted twice.

### 2.2 Population values

Population counts should use nonnegative integers. Intermediate economic calculations may use decimal values, but population transfers must be converted into integer counts without creating or deleting residents.

Recommended rounding method:

1. Calculate the expected population movement.
2. Allocate integer residents using a largest-remainder method.
3. Preserve exact source and destination totals.
4. Record the resulting transfers.

### 2.3 Resident conservation

The colony's population changes only through defined demographic operations: births, deaths, immigration, emigration, and other explicitly modeled arrival or departure events.

Moving from one income, employment, philosophy, effect, or housing category does not change the total colony population.

## 3. Level One — Housing Blocks

Housing blocks form the geographic foundation of the population system.

### 3.1 Housing blocks originate from the map

Each developed residential area becomes a housing block. The colony map determines: where people can live; how many residents can be accommodated; which infrastructure serves them; their proximity to workplaces; their access to schools and healthcare; environmental conditions; transport connections; local political and economic circumstances.

A district may contain several housing blocks. Housing blocks are smaller geographic units than administrative districts.

### 3.2 Housing block creation

A housing block is created when a residential area becomes available for occupation. The map system identifies the area and assigns a persistent HousingBlock ID. Initially, a contiguous residential zoning area can form one block. The map editor should also permit the player to create separate residential areas within the same district.

### 3.3 Housing block properties

Each housing block tracks: unique ID; district ID; map tiles or geographic boundary; total housing units; occupied housing units; available housing units; resident population; average occupancy; housing quality; average housing costs; water availability; energy availability; transport accessibility; public-service accessibility; pollution exposure; local infrastructure condition; general safety conditions; current development projects; housing ownership distribution; historical development records.

### 3.4 Housing capacity

Housing capacity depends on the buildings within the block. Each residential building has: number of housing units; intended occupancy; quality; maintenance condition; utility requirements; ownership; operating costs. The housing block aggregates these quantities.

Example: a block with 100 housing units designed for an average of three residents can normally accommodate approximately 300 residents. Actual occupancy may be lower or higher.

### 3.5 Overcrowding

When population exceeds normal housing capacity, overcrowding may occur. Consequences can include: reduced housing satisfaction; higher maintenance pressure; increased demand for public services; poorer health conditions; greater migration pressure; political demands for new housing.

Overcrowding must not automatically destroy or remove residents.

### 3.6 Unhoused residents

If people cannot obtain ordinary housing, they must remain accounted for. Possible destinations include: temporary accommodation; emergency shelters; informal residential areas; government-organized housing; emigration.

Temporary accommodation should be represented by identifiable residential or shelter blocks, with appropriate service limitations.

### 3.7 Geographic movement

Residents may move between housing blocks. Movement depends on: available housing; housing cost; household income; employment opportunities; transport; public services; environmental conditions; personal and social preferences; applicable housing regulations.

Movement transfers people between blocks without creating additional residents.

### 3.8 Housing expansion

Constructing new housing increases accommodation capacity. It does not automatically create a population. New residents must arrive through migration or relocate from existing blocks.

### 3.9 Housing block changes

If residential areas expand, merge, split, or are demolished, the system must preserve population accounting and geographic history. Recommended rules:

- Expanding an existing residential area increases its capacity.
- Splitting an area creates new block IDs and transfers residents proportionally or according to actual building occupancy.
- Merging blocks combines their populations and records predecessor IDs.
- Demolition reduces capacity and requires a lawful relocation or displacement process.
- Historical block IDs remain available for statistics and past elections.

## 4. Level Two — Income Blocks

Each housing block is divided into income groups. These groups represent economic circumstances rather than arbitrary political identities.

### 4.1 Proposed initial income categories

Use five income categories: very low income; low income; middle income; high income; very high income. Five categories provide more socioeconomic detail than a simple poor/middle/rich model without requiring individual household simulation.

### 4.2 Income classification

Income categories should be based on the colony's economic conditions. Recommendation: classify residents using estimated equivalized disposable household income, rather than wages alone. This accounts for: employment income; government transfers; household composition; taxes; dependents; other income sources.

A person without employment may belong to a middle-income household. A skilled worker with relatively high wages may still experience low disposable income because of household circumstances.

### 4.3 Income data

Each income block tracks: population; average gross income; average disposable income; average housing expense; essential consumption costs; savings; financial insecurity; debt, if household borrowing is introduced; employment income share; transfer income share; purchasing power; cost-of-living pressure.

### 4.4 Income thresholds

Income thresholds should adjust to the colony economy. A hybrid classification is recommended: relative thresholds measure income distribution; absolute living-standard indicators measure whether households can afford essentials. This distinguishes low relative income from actual deprivation.

### 4.5 Income movement

Residents can move between income groups when their economic circumstances change. Causes include: wage increases; job loss; promotion; new business income; tax changes; government benefits; rising living costs; household changes; retirement.

### 4.6 Preventing classification instability

Residents should not move between income categories every month because their estimated income changes slightly. Use a configurable stabilization mechanism. For example: income classification uses a moving average over several months; small movements near a threshold do not immediately trigger reclassification; large income changes can cause immediate movement. The exact averaging period must be calibrated.

### 4.7 Economic inequality

The system can calculate inequality from the income distribution across housing blocks. This permits both colony-wide inequality and geographic inequality. Two colonies with similar average incomes may have very different living standards and political pressures.

## 5. Level Three — Work Blocks

Each income group is divided according to employment and occupational position. Work blocks connect the population directly to companies, institutions, and the labor market.

### 5.1 Work classification

Every resident belongs to a work-status and occupation category. The initial system should support:

| Work category | Description |
|---|---|
| Mining | Resource extraction workers |
| Construction | Construction and infrastructure workers |
| Manufacturing | Industrial and factory workers |
| Agriculture | Farming and food production |
| Logistics | Transport, distribution, storage |
| Services | Retail, hospitality, commercial services |
| Professional | Engineering, legal, technical, specialist work |
| Public sector | Government and public-institution employees |
| Business ownership/management | Owners and senior commercial management |
| Unemployed | Available workers without employment |
| Education/training | Residents primarily studying or training |
| Retired | Residents no longer normally participating in employment |
| Other nonworking | Children and other residents not in the labor force |

Additional categories may be introduced when the economy develops.

### 5.2 Employment and occupation

Employment status and occupational specialization must remain distinct in the underlying data. For example: a mining worker who loses their job becomes unemployed but retains mining-related skills and employment history. This allows the labor system to identify suitable new employment.

### 5.3 Work block properties

Every work block tracks: population; employment status; occupation category; average wage; workforce skills; work experience; average working hours; workplace safety conditions; job security; commute burden; employment satisfaction; union participation where applicable; primary employment sectors; exposure to relevant workplace regulations.

### 5.4 Employer relationships

Work blocks must connect to actual company and institution employment. The economic system tracks jobs by employer and workplace. The population system tracks residents by home location. This allows people to live in one housing block while working elsewhere.

### 5.5 Commuting

Every employment allocation has: residential origin; workplace destination; occupation category; number of workers; transport requirement. The same worker capacity cannot be used twice. Poor transport connections may reduce access to employment or increase commuting costs.

### 5.6 Employment changes

Work-block populations change when: companies hire workers; companies dismiss workers; new facilities open; facilities close; workers retire; students enter employment; workers retrain; residents migrate; job opportunities change.

### 5.7 Work and income interaction

The hierarchy is: Housing → Income → Work. However, employment changes may cause income reclassification. The simulation should first calculate the new employment and income circumstances, then reallocate residents to the appropriate income and work branches. This prevents the hierarchy from forcing economically impossible outcomes.

### 5.8 Work-related political interests

Work affects the issues residents encounter. Examples: miners may be directly affected by extraction regulations; construction workers may be affected by public investment; retail employees may be affected by consumer demand; public-sector workers may be affected by government budgets; unemployed residents may prioritize employment opportunities.

These are potential interests, not predetermined voting instructions.

## 6. Level Four — Philosophy Blocks

Each work block is divided into philosophical outlook groups. This is where the population's political character becomes more detailed. The purpose is to represent different ways people interpret events and prioritize policies.

### 6.1 Philosophy is not party membership

A philosophy block must not be identical to a political party. Political parties can emerge, disappear, merge, or change their agendas. Residents' underlying philosophical preferences should usually evolve more gradually.

Two residents with similar philosophies may vote for different parties because of: different economic circumstances; trust in party leadership; specific election promises; government performance; coalition decisions; media exposure; local issues.

### 6.2 Philosophy dimensions

Each philosophy block should have a vector of preferences rather than only one fixed label. Recommended dimensions:

| Dimension | Main conflict or priority |
|---|---|
| Economic intervention | Public intervention versus market autonomy |
| Equality | Redistribution and economic equality priorities |
| Labor policy | Worker protections versus employer flexibility |
| Environmental policy | Environmental protection versus development priorities |
| Personal liberty | Individual freedom versus regulatory control |
| Government structure | Centralized authority versus local autonomy |
| Institutional trust | Confidence in established institutions |
| Social stability | Preference for continuity versus rapid change |

Values can be stored on a normalized numerical scale.

### 6.3 Philosophy archetypes

For efficient grouping, the game can define broad philosophy archetypes. Possible initial categories: labor-oriented; market-oriented; environment-oriented; equality-oriented; liberty-oriented; stability-oriented; development-oriented; institution-oriented.

These labels summarize outlooks, but the underlying preference vector determines responses. A person can support economic development and environmental protection simultaneously. The grouping algorithm should account for combinations rather than treating these categories as mutually exclusive beliefs.

### 6.4 Philosophy block properties

Every philosophy block tracks: population; philosophy archetype; average preference vector; strength of ideological commitment; institutional trust; political engagement; issue priorities; openness to persuasion; historical changes in outlook; party preference distribution.

### 6.5 Philosophy formation

The starting settlement population should have a distribution of outlooks. During the founding period, philosophical positions are influenced by actual colonial development. Examples: successful private enterprise may strengthen confidence in market-oriented solutions; unfair employment conditions may increase interest in labor protections; environmental damage may increase ecological priorities; effective public services may strengthen confidence in public institutions; poor government administration may reduce institutional trust.

These effects should depend on exposure, interpretation, and previous beliefs.

### 6.6 Philosophy changes

Philosophical preferences should normally change gradually. One unfavorable event should not completely transform an entire group's worldview. Possible mechanisms: slow movement in philosophy scores; changes in issue salience; splitting a philosophy block when part of the group develops distinct preferences; merging similar groups when their outlooks converge.

### 6.7 Political disagreement within occupations

The system must allow substantial political differences within the same work category. For example, mining workers may include: people prioritizing wages and labor protections; people prioritizing low taxation and market growth; people prioritizing environmental regulation; people prioritizing stable government administration.

This is a principal reason for placing philosophy below work in the hierarchy.

## 7. Level Five — Effect Blocks

Effect blocks represent external pressures acting on particular population groups. This final layer is where economic events, company decisions, government policies, environmental conditions, media, and social developments influence people.

### 7.1 Purpose

Effects allow the game to distinguish people who otherwise share the same location, income, occupation, and philosophy but are experiencing different circumstances. For example, two groups of similarly paid mining workers may have very different political experiences if one group is exposed to dangerous conditions and the other is not.

### 7.2 Effect categories

| Category | Examples |
|---|---|
| Economic | Inflation, wage increases, job insecurity, tax changes |
| Environmental | Pollution, water shortages, environmental restoration |
| Employment | Unsafe conditions, layoffs, labor disputes |
| Housing | Rising rents, overcrowding, improved accommodation |
| Public services | Hospital shortages, school improvements |
| Government | Popular reforms, broken promises, administrative failures |
| Corporate | Company bankruptcy, workplace scandals, major investments |
| Media | News exposure, misinformation, investigations |
| Legal | Rights violations, court judgments, enforcement actions |
| Social | Crime, public safety, recreation, community stability |
| Health | Disease outbreaks, harmful consumption, improved treatment |
| Infrastructure | Transport access, energy failures, construction disruption |

### 7.3 Effect block structure

An effect block contains: population; parent philosophy block; active exposure identifiers; effect intensity; effect duration; relevant economic consequences; relevant social consequences; awareness of events; perceived responsibility; political response modifiers; historical exposure.

### 7.4 Overlapping effects

This requires particular care. A person may simultaneously experience: pollution; high rent; wage growth; positive government-service improvements; exposure to misleading news. The game must not create five independent population copies. Instead, an effect block represents a unique combination of active exposures. For example:

```
PHILOSOPHY BLOCK: 100 residents
│
├── 30 residents
│   └── Pollution only
│
├── 25 residents
│   └── Pollution + high housing costs
│
├── 20 residents
│   └── High housing costs only
│
└── 25 residents
    └── No major active exposure

TOTAL: 100 residents
```

New effects may split existing groups. Expired effects may allow groups to merge again.

### 7.5 Shared effects

If an event affects everyone in a parent block equally, the game should attach the exposure to that parent rather than unnecessarily creating identical child groups. Only differences that matter to simulation outcomes should create new effect-block subdivisions. This keeps the hierarchy efficient.

### 7.6 Effect intensity

Effects should have measurable severity. Example: pollution exposure might be represented on a normalized scale from zero to one. A severe exposure can have greater consequences than a minor exposure.

### 7.7 Duration

Effects may be: immediate; temporary; persistent; recurring; long-term. Examples: a newspaper headline may have a relatively short information effect; a major pollution problem may persist for years; a permanently improved transport connection may continue influencing employment access until the infrastructure changes.

### 7.8 Effect decay

Temporary effects should decline when their causes disappear. A provisional rule:

I(t+1) = I(t) · (1 − d)

Where I(t) is current intensity and d is the monthly decay rate. Different effects have different decay rates. Persistent effects should be recalculated from continuing conditions instead of fading automatically.

### 7.9 Effect interactions

Effects may reinforce or offset one another. For example: wage growth may improve living standards; rising housing costs may reduce the benefit of those wages; better healthcare may partially offset health pressures; reliable public transport may improve employment access.

The simulation should calculate these effects through their relevant underlying indicators. It should not simply add every happiness modifier into one unrestricted number.

### 7.10 Effect attribution

Each effect should record its cause. Examples: pollution caused by Company A's mine; housing-cost increase associated with local shortages; tax reduction enacted by Government B; hospital delay associated with Contractor C; false report published by Newspaper D.

Attribution is important for political accountability. The population may perceive responsibility differently from the actual cause. Both should be tracked.

## 8. Population Block Data Model

The system should store each level as a separate entity linked through IDs.

### 8.1 HousingBlock

```
HousingBlock
    id
    district_id
    tile_ids[]

    population
    housing_capacity
    housing_units
    occupied_units

    housing_quality
    housing_cost
    utility_access
    infrastructure_access

    environmental_conditions
    public_service_access

    income_block_ids[]
    history[]
```

### 8.2 IncomeBlock

```
IncomeBlock
    id
    housing_block_id

    income_category
    population

    average_gross_income
    average_disposable_income
    average_housing_cost
    average_essential_expenses

    savings
    financial_security

    work_block_ids[]
```

### 8.3 WorkBlock

```
WorkBlock
    id
    income_block_id

    occupation_category
    employment_status
    population

    average_wage
    skill_distribution
    experience_distribution

    employment_allocations[]
    workplace_district_ids[]

    workplace_conditions
    job_security
    commute_cost

    philosophy_block_ids[]
```

### 8.4 PhilosophyBlock

```
PhilosophyBlock
    id
    work_block_id

    philosophy_archetype
    population

    philosophy_vector{}
    ideological_commitment
    institutional_trust

    political_engagement
    issue_priorities{}
    party_preference_distribution{}

    effect_block_ids[]
```

### 8.5 EffectBlock

```
EffectBlock
    id
    philosophy_block_id

    population

    exposure_signature[]
    active_effect_ids[]

    current_conditions{}
    perceived_conditions{}

    government_trust
    political_grievances{}
    election_participation_factors{}

    history[]
```

### 8.6 EffectDefinition

```
EffectDefinition
    id
    category
    source_entity_id
    source_event_id

    target_rules[]
    exposure_conditions[]

    intensity
    duration
    decay_rule

    economic_effects[]
    health_effects[]
    social_effects[]
    political_effects[]

    start_month
    end_month
```

### 8.7 PopulationTransfer

```
PopulationTransfer
    id
    month

    source_block_id
    destination_block_id

    population_count
    transfer_reason

    economic_context
    demographic_context
```

The transfer ledger is important for debugging and historical analysis.

## 9. Demographics Without Individual Simulation

The population also needs demographic information. However, demographics should not require another full set of hierarchical divisions.

### 9.1 Demographic distributions

Each relevant block can maintain distributions of: age; household size; education level; voting eligibility; labor-market participation; health status. These are aggregate distributions attached to existing groups.

### 9.2 Age structure

Recommended age categories: children; working-age adults; older adults. A more detailed age distribution can be used internally for births, retirement, mortality, education, and voter eligibility.

### 9.3 Births

Births depend on demographic conditions and the population's age structure. Births increase the colony population and enter the appropriate residential and household groups.

### 9.4 Deaths

Mortality depends on: age; healthcare access; general health; environmental conditions; significant events. Deaths reduce the appropriate population groups.

### 9.5 Education progression

Residents progress through education over time. Education affects: skills; employment opportunities; occupational mobility; future earnings. The education system must not instantly convert an entire population group into specialists when a new school opens.

### 9.6 Voting eligibility

Voting eligibility is separate from total population. Eligibility depends on the colony's electoral law. The system must distinguish: total residents; eligible voters; registered voters, if registration is modeled; actual voters.

The electoral system should never use total population as a direct substitute for eligible voters.

### 9.7 Demographic consistency

Because demographic attributes are aggregated, the simulation must preserve relevant joint distributions. For example, employment status and working age cannot be sampled independently in a way that creates more employed adults than the number of eligible workers. Where necessary, store joint counts within groups instead of only independent percentages.

## 10. Migration

Migration connects housing, employment, and population growth.

### 10.1 Immigration

Potential immigrants evaluate: employment availability; wages; housing; public safety; healthcare; available services; migration rules; transport availability. Migration may be limited by the colony's external transport capacity.

### 10.2 Internal migration

Residents may move between housing blocks. A worker might relocate closer to a new industrial area. A household might leave a polluted district. A higher-income household might move into newly constructed housing.

### 10.3 Emigration

Residents may leave the colony when conditions become unattractive or opportunities elsewhere are better. Emigration is constrained by available departure transport and applicable rules.

### 10.4 Migration algorithm

Each month:

1. Identify potential movers.
2. Identify available destination housing.
3. Estimate the attractiveness of destinations.
4. Check affordability and transport constraints.
5. Allocate successful moves.
6. Transfer residents between blocks.
7. Update housing occupancy.
8. Preserve employment and philosophy attributes unless an actual transition occurs.

### 10.5 Migration and politics

Migration changes the distribution of voters across districts. A rapidly expanding industrial district may develop a different political character from a declining settlement area. This geographic evolution should be an outcome of actual migration and development.

## 11. Employment Integration

The population model must use the same labor totals as the economic simulation.

### 11.1 Labor-market consistency

Companies generate job demand. Population groups supply workers. Employment allocations connect workers to firms. A worker cannot be fully employed in multiple jobs simultaneously unless the labor model explicitly permits part-time allocation.

### 11.2 Employment matching

The economic system evaluates: required skills; available workers; wages; transport access; working conditions; employer demand. Successful matches update work blocks.

### 11.3 Job loss

When a company closes: its employment allocations end; affected residents enter the appropriate unemployment categories; income is recalculated; household purchasing power changes; economic effects are recorded; political and social responses develop.

### 11.4 Industry growth

When new facilities open, the labor market creates opportunities. Residents may: change employers; change sectors; retrain; relocate; enter employment from unemployment. Work-block movement follows the actual employment changes.

### 11.5 Public employment

Public institutions participate in the same labor accounting. Teachers, healthcare workers, regulators, and other ordinary public employees are represented through population work blocks. The twenty senior government personnel are separately modeled named characters and must be reconciled with public workforce totals without double-counting.

## 12. Household Income and Consumption

The economy and population systems must use the same financial information.

### 12.1 Income sources

Population income can include: wages; business income; government transfers; pensions; investment distributions; other defined sources.

### 12.2 Disposable income

D = Y − T + B

Where D = disposable income, Y = gross income, T = taxes and deductions, B = benefits and transfers.

### 12.3 Consumption

Household groups consume goods and services through the economic market. Relevant categories include: food; water; energy; housing; consumer goods; healthcare services; education services; recreation.

### 12.4 Financial constraints

Residents cannot purchase unlimited goods. Purchases depend on: disposable income; savings; prices; availability; transport and local access.

### 12.5 Shortages

The simulation must distinguish: goods unavailable because of insufficient supply; goods available but unaffordable; goods available elsewhere but inaccessible; goods deliberately not purchased because of preferences. These circumstances produce different social and political consequences.

### 12.6 Household spending approximation

Because people are represented by blocks rather than individual households, expenditure should be calculated using per-capita or equivalized household requirements. The system must preserve total income and expenditure across income and work groups.

## 13. Public Services and Institutions

Institutions influence populations through geographic access and service capacity.

### 13.1 Education

Schools affect: educational attainment; future occupational qualifications; long-term earnings; family expenses; access to opportunity.

### 13.2 Healthcare

Healthcare affects: population health; mortality; worker availability; recovery from illness; household expenses; public satisfaction.

### 13.3 Public and private provision

The population system should not assume that public services are automatically better or worse than private services. Service outcomes depend on: capacity; funding; staffing; quality; accessibility; fees; regulation.

### 13.4 Service allocation

If a block contains 500 residents but nearby healthcare facilities can only serve part of their demand, the system records unmet service needs. Different income groups may experience different access depending on prices, funding, transport, and current legislation.

### 13.5 Political consequences

Public-service problems create political pressures. However, dissatisfaction should reflect actual circumstances and perceived government responsibility rather than simply applying an automatic penalty to the current government.

## 14. Environmental and Infrastructure Effects

The geographic housing layer allows environmental conditions to affect nearby residents.

### 14.1 Pollution

Pollution originates from facilities, transport, industrial activity, and other sources. The map determines exposure. Housing blocks receive pollution levels based on their locations.

### 14.2 Differing exposure

Not every resident in a housing block must experience identical exposure. For example: residents close to an industrial facility may experience higher pollution; workers at the facility may experience additional occupational exposure; other residents may have lower exposure. The final effect-block layer represents those differences.

### 14.3 Infrastructure quality

Infrastructure affects: commuting; energy availability; water supply; access to services; housing desirability; employment opportunities.

### 14.4 Geographic inequality

Different housing blocks may have unequal access to: employment; healthcare; schools; transportation; clean water; reliable energy. These differences contribute to district-level political development.

## 15. Alcohol, Recreation, and Social Conditions

Alcohol consumption must integrate with the population hierarchy.

### 15.1 Consumption preferences

Different philosophy and income groups may have different recreational preferences. Alcohol consumption is not determined by ideology alone. It may also depend on: availability; price; income; cultural preferences; household circumstances; previous consumption patterns.

### 15.2 Consumption categories

Suggested categories: nonconsumers; occasional consumers; moderate consumers; harmful or heavy consumers. These can be represented using aggregate distributions within relevant population blocks.

### 15.3 Leisure satisfaction

For groups that value alcohol consumption, legal access may contribute to recreational satisfaction. The benefit depends on actual preferences.

### 15.4 Harmful consumption

Sustained harmful consumption may influence: health; employment reliability; household finances; healthcare demand; social stability; civic participation. These effects should operate through modeled conditions rather than through a universal direct happiness or turnout adjustment.

### 15.5 Alcohol and voting

The game may model reduced political participation associated with severe alcohol-related social problems. However, large alcohol sales do not automatically imply low voter turnout. The simulation should consider: harmful consumption prevalence; health consequences; social disengagement; economic hardship; access to polling; political motivation. The final turnout effects should be bounded and calibrated during balancing.

### 15.6 Alcohol regulation

Changes to alcohol law influence: legal supply; prices; illegal market incentives; government revenue; consumption patterns; company formation; public health. The population system receives those outcomes through economic and effect-block updates.

## 16. Law, Rights, and Justice Integration

The population system must connect with the legal framework already specified.

### 16.1 Rights and legal protections

Residents may be affected by: employment rights; housing rights; property protections; voting rights; freedom of expression; freedom of association; access to justice; public-service obligations.

### 16.2 Legal disputes

Legal incidents can create effects on relevant population groups. Examples: workers affected by an unsafe workplace; residents affected by unlawful eviction; families affected by public-service failures; communities affected by environmental violations.

### 16.3 Judicial outcomes

Court judgments may change: financial compensation; regulatory compliance; employment conditions; government authority; public trust.

### 16.4 Public trust in justice

Trust in legal institutions depends on: access to justice; case delays; enforcement consistency; judicial independence; significant legal controversies; media coverage; personal experience.

### 16.5 Political consequences

Residents may prioritize legal reforms when they experience poor enforcement or institutional failures. Their political response depends on the nature of the problem and their philosophical preferences.

## 17. Media and Information Exposure

Newspapers and other media organizations influence the population through information exposure.

### 17.1 Readership

Each newspaper has a readership distributed across population groups. Readership depends on: geographic access; price; credibility; editorial interests; income; education; personal preferences.

### 17.2 Media exposure

When an article is published, the system calculates which groups encounter it. An article should not automatically affect every resident.

### 17.3 Facts and perceptions

The population system must distinguish: actual conditions; information received; perceived conditions; confidence in the information; perceived responsibility.

A company may genuinely be responsible for a construction failure. A newspaper may report the event accurately, misleadingly, or falsely. The population's reaction depends partly on which information reaches them and how credible they find it.

### 17.4 Misinformation

False information may temporarily influence beliefs. Later corrections or investigations can change those beliefs. A correction should not guarantee that everyone immediately accepts the truth.

### 17.5 Competing newspapers

A population block may read several newspapers with conflicting editorial positions. The media system should aggregate information exposure without duplicating residents.

### 17.6 Media influence on philosophy

Repeated information exposure may gradually change issue priorities or institutional trust. Deep philosophical changes should generally require sustained influences rather than one headline.

## 18. Public Satisfaction and Well-Being

The game should not treat satisfaction as one independent number. Instead, satisfaction is derived from several measurable conditions.

### 18.1 Well-being dimensions

Recommended dimensions: economic security; employment conditions; housing conditions; essential consumption; healthcare access; education access; public safety; environmental quality; infrastructure reliability; personal freedom; institutional trust; recreational satisfaction.

### 18.2 Objective conditions

Objective conditions are calculated from the economy, map, institutions, and legal systems. Examples: actual unemployment; actual food consumption; actual pollution; actual housing costs; actual healthcare availability.

### 18.3 Perceived conditions

Perceived conditions depend on: personal experience; philosophy; media; government communication; social expectations; historical comparisons.

### 18.4 Satisfaction calculation

A proposed multidimensional formula:

S_g = Σ_i w_{g,i} · x_{g,i}

Where S_g = satisfaction of population group g, x_{g,i} = normalized condition, w_{g,i} = importance of that condition to the group.

Weights vary between groups. A market-oriented business owner may place greater weight on business conditions. A resident with severe health problems may prioritize healthcare. A worker facing unsafe conditions may prioritize workplace protection.

The simulation should preserve the underlying indicators even when a composite satisfaction score is displayed.

### 18.5 Expectations

Satisfaction may depend on whether conditions are improving or deteriorating. A household whose income is increasing may be more satisfied than another household with the same income whose circumstances have recently worsened. Historical comparisons should therefore influence satisfaction.

## 19. Political Attitudes

The population system supplies political attitudes to the party and election systems. It should not calculate the entire election independently.

### 19.1 Political inputs

Each philosophy/effect group contributes: eligible voters; issue preferences; issue salience; government trust; party trust; policy preferences; political engagement; turnout tendency; recent economic experiences; media exposure; local political concerns.

### 19.2 Issue salience

Issue salience measures how important an issue currently is. For example: a resident may generally support environmental protections, but housing affordability may be their immediate priority. A major pollution incident may increase environmental salience. A company closure may increase employment salience.

### 19.3 Party alignment

Party alignment depends on the distance between party policies and the group's preferences. However, policy agreement is only one component. A party may be ideologically attractive but distrusted because of previous failures.

### 19.4 Political trust

The system should distinguish: trust in the current government; trust in individual parties; trust in parliament; trust in public institutions; trust in legal institutions. These are not interchangeable.

### 19.5 Government performance

A population group may reward or punish the government based on: delivered promises; economic conditions; public services; major projects; administrative competence; scandals; crisis response. Perceived responsibility affects the response.

## 20. Elections and Voting Behavior

The population system must provide detailed voting inputs without simulating individual ballots.

### 20.1 Electoral population

For every population leaf or compatible aggregate:

1. Determine eligible voters.
2. Determine turnout probability.
3. Determine party preference probabilities.
4. Allocate expected votes.

### 20.2 Turnout

Turnout can depend on: political engagement; satisfaction or dissatisfaction; perceived importance of the election; trust in institutions; campaign mobilization; voting accessibility; health and social conditions; relevant external pressures.

Dissatisfaction should not always reduce turnout. It may also mobilize opposition voters.

### 20.3 Party support

A proposed voting utility model:

U_{g,p} = A_{g,p} + T_{g,p} + P_{g,p} + C_{g,p}

Where A = ideological and policy alignment, T = party trust, P = perceived performance, C = campaign and contextual effects.

These scores are converted into party-choice probabilities using a normalized choice function. The exact weights and normalization require balancing.

### 20.4 Aggregated voting

A group of 100 eligible voters might have: 65 expected participants; 25% preference for Party A; 30% for Party B; 20% for Party C; 15% for Party D; 10% for Party E. The simulation allocates votes across parties rather than assigning the entire group to one party.

### 20.5 Electoral geography

Voting calculations should retain the housing block and district of residence. This permits: local election analysis; district voting patterns; geographic political shifts; constituency-level rules if implemented.

### 20.6 Parliamentary seats

The election system converts the final vote distribution into 151 parliamentary seats according to the established electoral rules. The population engine produces votes, not seat allocations.

### 20.7 Political development

During Year 3 of the founding period, public demands contribute to party formation and election agendas. At least five parties must participate in the formal political system. Population interests and experiences help determine which parties emerge and which policies gain support.

## 21. Monthly Population Simulation

The population update must use a deterministic sequence.

1. **Receive economic results** — employment changes; wages; taxes; benefits; consumer prices; purchases; resource shortages; company closures; new business formation.
2. **Receive geographic and service results** — housing capacity; infrastructure changes; pollution; utility reliability; school capacity; healthcare capacity; transport access.
3. **Receive legal and political events** — new laws; court judgments; regulatory actions; government decisions; public controversies; election developments.
4. **Update demographics** — births; deaths; age progression; education progression; retirement; eligibility changes.
5. **Update employment and income** — apply actual job changes; recalculate income and purchasing power; reclassify income and work blocks where necessary.
6. **Process migration** — allocate movements between housing blocks, respecting housing capacity, affordability, transport, available opportunities, migration rules.
7. **Update effect blocks** — determine which groups are exposed to new pressures; update persistent exposures; expire or reduce temporary effects; split or merge effect groups as necessary.
8. **Update well-being** — economic security; service satisfaction; environmental conditions; social conditions; perceived outcomes.
9. **Update philosophy and political attitudes** — slow philosophical changes; issue salience changes; government trust; party trust; media exposure; political grievances.
10. **Update political outputs** — eligible voter counts; turnout tendencies; party preference distributions; political pressure indicators.
11. **Reconcile population counts** — verify that no residents are duplicated; no residents disappear without a demographic event; all parent-child population totals match; employment allocations remain consistent; housing occupancy totals are correct.
12. **Save history** — population totals; demographic changes; employment trends; income distributions; housing movements; political shifts; major exposure events.

## 22. Population Performance and Optimization

The hierarchy must remain efficient during large simulations.

### 22.1 Sparse block generation

Do not create every possible combination of housing, income, work, philosophy, effects. Only create combinations that contain residents.

### 22.2 Example population size

Suppose the colony contains: 100 housing blocks; 5 income categories; 8 active work categories per income group; 6 active philosophy categories per work group; an average of 3 effect groups per philosophy group. The upper illustrative count would be:

100 × 5 × 8 × 6 × 3 = 72,000

This is a manageable starting target for a monthly-turn simulation if updates are efficient and the majority of operations use aggregate calculations. The actual number of populated groups should normally be substantially lower.

### 22.3 Effect-block explosion

Because effects can overlap, combinations could otherwise grow exponentially. The system must prevent this. Recommended techniques: group similar exposure levels; quantize effect intensity into configurable bands; merge compatible effect groups; remove expired exposures; store common effects at parent levels; use compact exposure signatures; avoid creating new groups for negligible differences.

### 22.4 Minimum cohort size

Very small groups may be merged with the nearest compatible group when this does not materially alter behavior. However, small groups with significant legal, political, or economic importance should not automatically disappear through aggregation.

### 22.5 Merge rules

Two effect blocks can merge when they share: housing location; income category; work classification; compatible philosophy; compatible demographic distributions; equivalent relevant exposure conditions. Population counts are combined. Financial, demographic, and political statistics are recomputed using population-weighted aggregation.

### 22.6 Cached aggregates

The game should cache useful totals for: housing blocks; districts; income groups; work categories; philosophy categories; colony-wide statistics. These totals should be derived from underlying records and validated periodically.

### 22.7 Update scheduling

Not every variable needs recalculation every month. Recommended approach:

| Variables | Schedule |
|---|---|
| Employment, income, prices, consumption | Monthly |
| Political salience and active effects | Monthly |
| Education advancement | Monthly accumulation, periodic milestones |
| Deep philosophy changes | Gradual, with periodic regrouping |
| Demographic progression | Monthly accumulation |
| Historical statistics | Monthly snapshots with older aggregation |

### 22.8 Reproducibility

All random allocations should use seeded randomness. Given identical starting conditions and player decisions, the population simulation should reproduce the same results.

## 23. Player Interface

The interface should allow the player to examine the population hierarchy visually.

### 23.1 Map selection

Selecting a housing area opens its Housing Block panel. The panel shows: population; housing capacity; occupancy; average income; employment; public services; satisfaction; political attitudes; major active effects.

### 23.2 Hierarchical inspection

The player can drill down:

```
Housing Block A
    ↓
Low Income
    ↓
Mining Workers
    ↓
Labor-oriented
    ↓
Pollution + Unsafe Work
```

The final screen shows the detailed characteristics of that population group.

### 23.3 Block statistics

Every population level displays: population count; share of parent population; economic circumstances; employment data; well-being; political preferences; active external pressures.

### 23.4 Population comparison

The interface should allow comparisons between: housing blocks; income categories; occupations; philosophical groups; exposed and unexposed groups.

### 23.5 Map overlays

Suggested map overlays: population density; average income; unemployment; housing affordability; pollution; healthcare access; education access; government satisfaction; party support; election turnout; significant external pressures.

### 23.6 Historical trends

Players should be able to view changes over time. Examples: income growth over ten years; unemployment by district; migration between housing blocks; political shifts among industrial workers; pollution exposure before and after regulation.

### 23.7 Information accuracy

The game should distinguish actual administrative statistics from uncertain political estimates. For example: housing capacity may be precisely known; registered employment may be closely measured; informal economic activity may be estimated; political preferences should be measured through polling with uncertainty.

The player should not automatically possess perfect information about every population group's political intentions.

## 24. Interaction With Other Game Systems

| System | Information sent to population | Information received from population |
|---|---|---|
| Map | Location, terrain, housing, infrastructure | Population density, housing demand |
| Economy | Wages, prices, goods, employment | Labor supply, consumption |
| Companies | Jobs, working conditions, corporate events | Workers, customers, public attitudes |
| Institutions | Service availability and quality | Demand, enrollment, patients |
| Media | News and information exposure | Readership, credibility responses |
| Law | Rights, legal outcomes, enforcement | Complaints, affected groups, trust |
| Government | Taxes, benefits, public projects | Satisfaction, service demand |
| Political parties | Policies, campaigns, promises | Issue priorities, support |
| Elections | Electoral rules, campaign events | Eligible voters, turnout, party votes |
| Staff | Completed administrative work | Populations affected by projects |
| Events | Disasters, shortages, crises | Vulnerability, social response |

Every cross-system interaction should use defined data interfaces. For example: a company closure produces an employment event; the economic system removes affected jobs; the population system reallocates workers and updates income; the effect system creates unemployment and economic-security pressures; the media system may report the closure; the political system updates public priorities and party support.

The same event must not be independently recreated by each subsystem.

## 25. Development Roadmap

### Phase P1 — Population Block Foundation
Objective: Implement the five-level hierarchy.
Tasks: create HousingBlock; create IncomeBlock; create WorkBlock; create PhilosophyBlock; create EffectBlock; implement parent-child relationships; add stable IDs; add population totals; add sparse block creation; add merging and splitting; implement population conservation validation; add save/load.
Completion criteria: A housing block can be subdivided through all five levels without duplicating or losing residents.

### Phase P2 — Geographic Housing Integration
Objective: Connect population to the map.
Tasks: generate housing blocks from residential areas; link blocks to districts; implement housing capacity; implement occupancy; add housing quality; add housing expenses; add service accessibility; implement residential expansion; implement geographic splitting and merging; preserve block history.
Completion criteria: Residents are attached to actual residential areas, and map development changes housing capacity and living conditions.

### Phase P3 — Income Structure
Objective: Divide residents by economic circumstances.
Tasks: implement five income categories; connect wages and transfers; calculate disposable income; add housing expenses; add purchasing power; add savings; add income classification; add threshold stabilization; implement income reclassification; add inequality calculations.
Completion criteria: Economic changes move residents between income categories without changing total population.

### Phase P4 — Work Structure
Objective: Connect employment to population groups.
Tasks: add work categories; add employment status; add occupational skills; link employer allocations; link workplace locations; implement commuting; add unemployment; add retirement; add retraining transitions; prevent double employment.
Completion criteria: Company hiring and layoffs correctly affect work blocks and household income.

### Phase P5 — Philosophy Structure
Objective: Represent distinct social and political outlooks.
Tasks: implement philosophy vectors; define starting archetypes; add philosophical commitment; add issue priorities; add institutional trust; add philosophy allocation; add gradual belief changes; implement philosophy group splitting; implement philosophy group merging.
Completion criteria: Residents with similar economic and occupational conditions can have significantly different political beliefs.

### Phase P6 — Effect System
Objective: Represent external pressures.
Tasks: implement EffectDefinition; add exposure rules; add effect intensity; add duration; add decay; add overlapping effects; add exposure signatures; implement effect splitting; implement effect merging; add event attribution; prevent effect-block population duplication.
Completion criteria: Multiple external events can affect the same residents without creating invalid population totals.

### Phase P7 — Demographics and Migration
Objective: Make the colony population evolve.
Tasks: add age distributions; add births; add deaths; add education progression; add retirement; add voting eligibility; add immigration; add emigration; add internal relocation; add housing-capacity checks; add population transfer history.
Completion criteria: Population changes occur through explicit demographic and migration processes.

### Phase P8 — Household Consumption and Well-Being
Objective: Connect economic conditions to living standards.
Tasks: implement household spending; add essential consumption; add service consumption; add housing affordability; add financial insecurity; add well-being dimensions; add objective conditions; add perceived conditions; add satisfaction calculation; add historical expectations.
Completion criteria: Different economic conditions produce different, explainable living standards.

### Phase P9 — Institutions and Social Conditions
Objective: Connect schools, healthcare, infrastructure, and legal institutions.
Tasks: add school access; add healthcare access; add education outcomes; add public-service quality; add legal-system trust; add environmental exposure; add workplace conditions; add recreation; add alcohol consumption effects; add social pressure indicators.
Completion criteria: Institutional and environmental changes produce measurable population outcomes.

### Phase P10 — Media and Public Perception
Objective: Model information exposure.
Tasks: connect newspaper readership; add media distribution; add article exposure; add source credibility; add factual versus perceived conditions; add misleading reporting; add corrections; add government communication effects; add perception history.
Completion criteria: Different population groups can perceive the same events differently based on available information and prior beliefs.

### Phase P11 — Political Integration
Objective: Connect population to parties and elections.
Tasks: add issue salience; add party-policy alignment; add government trust; add party trust; add political engagement; add voting eligibility; add turnout modeling; add party preference probabilities; add aggregate vote generation; connect votes to district geography; provide results to the 151-seat election system.
Completion criteria: Economic and political events can alter party support without predetermining voting behavior by occupation or income.

### Phase P12 — Population Interface
Objective: Make the hierarchy understandable.
Tasks: build housing block panel; add income drill-down; add work drill-down; add philosophy drill-down; add effect inspection; add population charts; add geographic overlays; add block comparisons; add historical trends; add data uncertainty indicators.
Completion criteria: The player can inspect all five levels and understand why groups differ.

### Phase P13 — Performance and Optimization
Objective: Support large populations and long games.
Tasks: implement sparse groups; add cohort merging; add intensity quantization; add shared parent effects; add cached totals; add efficient migration allocation; add batched monthly updates; add seeded randomness; optimize save files; run large-colony benchmarks.
Completion criteria: The simulation can process large populations without requiring individual citizen records or excessive per-turn computation.

### Phase P14 — Balancing and Integration
Objective: Produce realistic and strategically interesting population behavior.
Tasks: balance population growth; balance immigration; balance economic mobility; balance philosophical change; balance political responsiveness; balance media influence; balance external-effect persistence; test geographic inequality; test labor-market behavior; test voter turnout; test long-term societal evolution; run multidecade simulations.
Completion criteria: The population model remains internally consistent and produces varied, explainable societies over many political terms.

## 26. Testing Scenarios

1. **Population conservation** — Create a housing block containing 1,000 residents. Divide it into multiple income, work, philosophy, and effect categories. Expected: every aggregation level totals exactly 1,000 residents.
2. **Housing development** — Construct additional housing. Expected: housing capacity increases without automatically creating residents.
3. **Residential migration** — Move 100 residents from one housing block to another. Expected: source population decreases by 100 and destination population increases by 100.
4. **Company closure** — Close a factory employing 200 residents. Expected: employment allocations end, work categories update, and household income changes.
5. **Income mobility** — Increase wages for a group of workers. Expected: some residents may move into higher income blocks if the classification requirements are met.
6. **Different philosophies** — Create two groups with identical income and occupation but different philosophies. Expected: they respond differently to policies where their preferences differ.
7. **Pollution** — Create pollution near one housing area. Expected: relevant effect blocks record exposure while distant blocks remain unaffected.
8. **Overlapping pressures** — Apply pollution and unsafe working conditions to the same residents. Expected: both effects are recorded without doubling the population.
9. **Effect expiration** — Remove a temporary pressure. Expected: its intensity declines or expires according to its rule, and compatible groups can merge.
10. **Public school improvement** — Increase education quality. Expected: relevant educational outcomes improve gradually, subject to available capacity and demographic timing.
11. **Hospital shortage** — Reduce healthcare capacity. Expected: unmet healthcare demand increases among affected groups.
12. **Housing affordability** — Increase rents in one district. Expected: financial pressure increases among affected households, potentially creating relocation demand.
13. **Media misinformation** — Publish an inaccurate report. Expected: exposed groups may update their perceived conditions without changing the underlying facts.
14. **Media correction** — Publish credible evidence disproving a previous report. Expected: some groups revise their beliefs according to exposure and source trust.
15. **Alcohol consumption** — Increase harmful consumption among a subset of residents. Expected: relevant health and social consequences change according to the consumption model.
16. **Election turnout** — Create a major political controversy. Expected: turnout may increase among mobilized groups and decrease among disengaged groups according to the defined model.
17. **Mixed-party voting** — Create one philosophy group containing 500 eligible voters. Expected: its votes can be distributed among several parties rather than going entirely to one party.
18. **Rights violation** — Create a documented unlawful government action affecting a group. Expected: legal, social, and political effects arise from the same underlying event.
19. **Government transition** — Replace the governing coalition. Expected: population groups retain their economic history, philosophies, and previous experiences.
20. **Long-term evolution** — Run a colony for thirty years. Expected: population changes through demographic processes; residents move between housing blocks; income distributions change; employment patterns evolve; philosophy groups develop; external effects appear and disappear; geographic political differences emerge; population totals remain consistent; no individual citizen simulation is required.

## 27. Minimum Complete Playable Population System

The first complete population subsystem must include: housing blocks generated from the map; income subdivisions within housing blocks; work subdivisions within income blocks; philosophy subdivisions within work blocks; effect subdivisions within philosophy blocks; exact population conservation; housing capacity and occupancy; five income groups; employment and unemployment; links to companies and workplaces; multiple philosophy types; philosophy preference vectors; external effects; overlapping effect combinations; effect duration and decay; internal migration; immigration and emigration; basic demographics; household income; household consumption; living-standard indicators; access to institutions; government and party trust; media exposure; electoral eligibility; turnout tendencies; party preference distributions; aggregate votes; population drill-down interface; geographic map overlays; historical records; save and load; performance optimization for sparse groups.

## 28. Outstanding Design Decisions

The following parameters must be finalized before their relevant implementation phases.

| Area | Decision | Proposed initial approach |
|---|---|---|
| Housing block boundaries | Automatic or manually separated | Contiguous residential areas with optional manual division |
| Income categories | Number of groups | Five |
| Income thresholds | Relative or absolute | Hybrid classification |
| Income stability | Reclassification timing | Moving average with hysteresis |
| Work categories | Number of categories | Approximately 13 including nonworking groups |
| Philosophy groups | Starting number | Up to eight archetypes, sparsely instantiated |
| Philosophy representation | Labels or numerical values | Labels plus multidimensional vectors |
| Philosophy change speed | Responsiveness | Slow changes; faster issue-salience shifts |
| Effect intensity | Numerical scale | Normalized 0–1 |
| Effect combinations | Storage format | Sparse exposure signatures |
| Effect persistence | Decay method | Per-effect duration and decay |
| Demographic precision | Age groups | Aggregated age distribution |
| Housing demand | Allocation method | Affordability and accessibility |
| Internal migration | Monthly movement | Capacity-constrained group transfers |
| Household spending | Economic calculation | Equivalized aggregate budgets |
| Political behavior | Party-selection model | Probabilistic party utilities |
| Turnout | Participation model | Group probabilities with bounded effects |
| Election uncertainty | Vote allocation | Seeded probabilistic aggregation |
| Media influence | Persuasion strength | Exposure and credibility dependent |
| Cohort merging | Minimum group size | Configurable with preservation of significant groups |
| Population scale | Performance target | Initial benchmark of 100,000 residents, then larger colonies |
| Historical data | Retention | Monthly summaries and significant event histories |

These decisions are part of this specification and must not be silently replaced by unrelated assumptions during implementation.

## 29. Complete Gameplay Acceptance Scenario

**Year 1 — Founding.** The player lands on the planet and establishes three residential areas. These become Housing Blocks A, B, and C. The settlement has 1,500 residents. Initially, most residents have relatively similar economic circumstances. Several private companies begin operating. The population is divided into income, work, and philosophy groups. Because the colony is young, there are relatively few significant external pressures.

**Year 2 — Industrial development.** The player builds a mine near Housing Block A. The mine creates jobs. Some unemployed residents begin working there. Their employment classifications change. Wage income increases. Some residents move into higher income groups. However, the mine also creates pollution. Housing Block A develops additional effect groups representing varying pollution exposure.

**Year 3 — Political disagreements.** Workers begin demanding improved safety conditions. Some support stronger regulation. Others worry that excessive regulation could threaten employment. Residents near the mine increasingly prioritize environmental protection. These developments affect philosophy and issue-salience distributions. Formal political movements begin organizing. At least five parties emerge in preparation for the first parliamentary election.

**Year 4 — First election.** Political parties present their agendas. The player campaigns on continued development and better infrastructure. Other parties emphasize labor protections, environmental regulation, public services, or lower business taxes. Each population group evaluates the parties according to its interests, philosophy, recent experiences, and trust. Eligible voters participate according to their turnout probabilities. The results are aggregated into the election system. Parliament receives 151 seats.

**Year 6 — Major company closure.** A factory closes in District B. Its workers lose employment. Affected work blocks transition to unemployment. Household income declines. Some residents move to lower income categories. Consumer spending falls. New effect groups represent the economic pressure of unemployment. Political parties offer competing solutions. The population does not automatically switch to one predetermined party.

**Year 9 — Public-service expansion.** The government builds new public schools and expands healthcare. These institutions improve service capacity. Different housing blocks benefit according to geographic access. Educational improvements gradually affect future workforce skills. Public satisfaction changes according to actual service quality.

**Year 12 — Media controversy.** A newspaper publishes allegations about a major contractor. Some residents read the article. Others do not. Different groups interpret the story differently. A competing newspaper investigates and publishes additional evidence. The population's beliefs may change. The actual underlying company event remains separate from the information people receive.

**Year 16 — Alcohol reform.** The government changes the alcohol market from a retail monopoly to licensed private sales. Private businesses begin entering the market. Prices and availability change. Some groups experience improved recreational satisfaction. Other groups experience greater harmful consumption. Healthcare demand and household finances respond accordingly. Political effects develop through these actual circumstances.

**Year 20 — Political defeat.** The player loses the election. A new coalition assumes government. The population continues evolving. Businesses hire and dismiss workers. Housing blocks gain and lose residents. Income groups change. Philosophical priorities shift. Media organizations continue publishing. The player remains active in opposition.

**Year 24 — Return to government.** The player returns to office. The colony's population has changed considerably. Housing Block A is now a prosperous industrial and commercial area. Housing Block B has struggled with unemployment. Housing Block C has developed into a higher-income residential district. Each block contains different income, occupational, philosophical, and external-effect distributions. The player must govern the society that developed during their absence.

## 30. Final System Acceptance Criteria

The population system is complete when:

- Residential areas automatically generate geographically identifiable housing blocks.
- Every housing block can be subdivided by income, occupation, philosophy, and external effects.
- Every resident belongs to exactly one active population leaf group.
- Population totals remain consistent through every subdivision and transfer.
- Income changes can reclassify residents.
- Employment changes affect work categories.
- Occupational experience persists through unemployment and job changes.
- Similar workers can hold different political philosophies.
- Philosophy is separate from party membership.
- Philosophical preferences can evolve gradually.
- External pressures can affect only relevant groups.
- Multiple pressures can affect the same residents without duplication.
- Effects have defined causes, intensity, duration, and decay.
- Housing capacity constrains residential settlement.
- Migration transfers residents between actual housing blocks.
- Births, deaths, and demographic changes are accounted for.
- Household income and consumption use real economic data.
- Public and private institutions affect relevant populations.
- Pollution and infrastructure conditions depend on map geography.
- Media exposure affects perceptions without changing underlying facts.
- Public satisfaction reflects multiple conditions rather than one arbitrary value.
- Government trust and party trust are separately represented.
- Voting eligibility is distinct from total population.
- Political party support is calculated probabilistically.
- Election participation is influenced by relevant conditions.
- Different population groups contribute votes to multiple parties.
- Geographic voting distributions are preserved.
- The population system remains active during opposition and AI government.
- Historical societal changes can be inspected over decades.
- The simulation runs efficiently without individual citizen agents.
- Save and load preserve all population records and relationships.

**Final design principle:** The colony's society must emerge from the interaction between geography, income, employment, philosophy, and external pressure. The population block hierarchy should make those interactions detailed and politically meaningful without requiring individual citizens to be simulated. Every block represents real residents whose circumstances can change, whose interests may conflict, and whose collective decisions shape the colony's political future.
