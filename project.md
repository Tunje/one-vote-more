# Political Colony Simulator
## Game Design & Development Master Plan
**Version:** 0.1 — Initial specification  
**Status:** Planning  
**Genre:** 2D colony management, economic simulation, political strategy  
**Time system:** Monthly turns  
**Political model:** Multiparty parliamentary democracy inspired by Sweden  
**Parliament:** 151 seats, with 76 constituting an absolute majority

---

# 1. Game Vision

## 1.1 Core premise

The player lands on an uninhabited or previously unsettled alien planet as the appointed commander of a new colony.

Initially, the player possesses broad executive authority and is responsible for establishing the settlement's economic and physical foundations.

They must decide where districts are developed, how infrastructure is constructed, which companies receive contracts, how public resources are allocated, and how the growing population's needs are addressed.

These decisions create social classes, economic interests, regional inequalities, and political disagreements.

As the colony develops, organized political movements emerge. The colony transitions from a commander-led settlement to a democratic parliamentary system.

The player becomes the leader of a political party whose ideological identity has developed through the decisions made during the founding years.

From this point onward, political power is determined through elections, coalition negotiations, legislation, public confidence, and the government's ability to deliver results.

The game continues through multiple electoral cycles.

The player may remain in government, enter opposition, return to power, or retire. The colony's development continues through every political transition.

## 1.2 Design pillars

**1. Decisions have persistent consequences.**

Early construction, economic, and administrative choices can have implications decades later.

**2. Politics emerges from the simulation.**

Political demands and party positions arise from economic conditions, population interests, government performance, and ideological differences.

**3. Government authority is not unlimited.**

Winning an election gives the player political influence, not unrestricted control over parliament, companies, public institutions, or society.

**4. Execution matters as much as policy.**

Passing legislation or funding a construction project does not guarantee that it will be successfully implemented.

**5. Delegation is necessary.**

A limited staff pool requires the player to prioritize projects, appoint responsible personnel, and automate long-running activities.

**6. Losing power is part of the game.**

Opposition politics and political recovery are legitimate gameplay paths.

**7. The colony exists independently of the player.**

Companies, citizens, civil servants, and other political parties continue making decisions as the simulation progresses.

---

# 2. Time, Turns, and Campaign Structure

## 2.1 Calendar

The simulation operates in monthly turns.

- 12 turns constitute one year.
- 48 turns constitute one four-year political term.
- Each month updates the economy, construction projects, population, politics, government administration, and ongoing events.

The player can issue multiple instructions before ending a month.

## 2.2 Founding period

**Years 1–2: Settlement establishment**

The player operates as settlement commander with broad executive authority.

Primary activities include:

- Establishing residential, commercial, industrial, mining, and public-service districts.
- Developing infrastructure and essential services.
- Procuring materials and commissioning construction.
- Managing the founding budget.
- Creating jobs and supporting population growth.
- Responding to emerging social problems.
- Establishing the colony's first institutions.

**Year 3: Political organization and election preparation**

Political movements become increasingly formalized.

The player must establish an electoral agenda for the next term. Competing parties develop their own programs.

At least five political parties must participate in the political system, including the player's party.

Polling, political debate, and election campaigning become available.

**Year 4: Campaign and first parliamentary election**

The player continues governing the colony while preparing for the election.

At the conclusion of the founding term, 151 parliamentary seats are allocated according to the election results.

The first government is formed through parliamentary negotiations.

The exact timing of the election within Year 4 can be finalized during calendar design, but the initial specification places it at the end of the fourth year.

## 2.3 Subsequent political terms

Each subsequent four-year term includes:

- Government formation or opposition organization.
- Policy and budget negotiations.
- Legislative activity.
- Implementation of approved projects.
- Monthly economic and social changes.
- Government performance evaluation.
- Electoral campaigning.
- A new election.

Early elections, failed government formation, votes of no confidence, and extraordinary political events are candidates for the advanced political simulation.

---

# 3. Planet and Colony Map

## 3.1 Map presentation

The game uses simple 2D graphics.

The initial implementation should use a tile-based map. The map represents land development, infrastructure, resource deposits, and population districts.

The simulation must be able to operate independently of graphical rendering.

## 3.2 Terrain properties

Each tile can contain data describing:

- Terrain type.
- Construction suitability.
- Natural resources.
- Environmental sensitivity.
- Existing infrastructure.
- Transport accessibility.
- Development status.
- Ownership or administrative control.
- Pollution and environmental impact.

## 3.3 Zoning system

The player designates areas for different purposes.

Initial zoning categories:

| Zone | Primary function |
|---|---|
| Residential | Population housing |
| Commercial | Retail and economic services |
| Industrial | Manufacturing and processing |
| Mining | Resource extraction |
| Agricultural | Food production |
| Logistics | Storage and distribution |
| Public services | Healthcare, education, administration |
| Energy | Power generation |
| Infrastructure | Roads and utility corridors |
| Protected | Environmental preservation |

Additional district types may be introduced after the basic simulation is operational.

## 3.4 Geographic consequences

District location affects development costs and operating efficiency.

Examples:

- Mining requires accessible mineral deposits.
- Industries benefit from transport connections and reliable power.
- Housing requires access to employment and services.
- Remote settlements require additional logistical support.
- Pollution may affect nearby residential districts.
- Infrastructure reduces transportation costs but requires investment and maintenance.

These consequences should feed into both the economy and public opinion.

## 3.5 District-level tracking

Every developed district should maintain:

- Population.
- Employment.
- Housing availability.
- Average income.
- Service accessibility.
- Infrastructure condition.
- Pollution.
- Local economic activity.
- Public satisfaction.
- Political preferences.
- Active and planned projects.

District boundaries and geographic representation can be refined during implementation.

---

# 4. Population and Social Simulation

## 4.1 Population model

The colony population is divided into demographic and economic groups rather than requiring a separate fully simulated person for every citizen.

The initial model should track:

- Population size.
- Working population.
- Employment and unemployment.
- Household income.
- Housing conditions.
- Access to essential services.
- Economic security.
- Public satisfaction.
- Migration.

Additional demographic complexity can be introduced later.

## 4.2 Population groups

Citizens may have different economic positions and interests.

Examples include:

- Industrial workers.
- Mining workers.
- Service workers.
- Public-sector employees.
- Business owners.
- Unemployed residents.
- Retired residents.

These groups are not fixed political voting blocs.

Political preferences should be influenced by material conditions, personal priorities, party platforms, trust, and government performance.

## 4.3 Social conditions

The game tracks political and economic pressures such as:

- Unemployment.
- Income inequality.
- Housing shortages.
- Workplace safety.
- Environmental damage.
- Access to public services.
- Inflation or rising living costs.
- Tax burdens.
- Public debt.
- Infrastructure reliability.

These conditions influence satisfaction, political mobilization, and election results.

## 4.4 Citizen satisfaction

Satisfaction should not be represented by a single independent happiness calculation.

Instead, overall satisfaction is derived from multiple underlying conditions.

A district may have strong employment but poor health outcomes, or low income inequality but inadequate services.

These differences allow multiple political interpretations of the colony's performance.

---

# 5. Economy and Resource System

## 5.1 Starting economy

The colony begins with a defined stock of materials, equipment, funding, and personnel delivered from its original expedition.

These resources permit initial development but are finite.

The player must establish a sustainable local economy before the founding supplies are exhausted.

## 5.2 Resource categories

Initial resource categories should remain manageable.

Suggested starting resources:

- Food.
- Energy.
- Construction materials.
- Industrial metals.
- Advanced components.
- Financial credits.

More detailed material chains can be added later.

## 5.3 Economic actors

The economic system includes:

- Government.
- Private companies.
- Workers and households.
- Public institutions.
- Resource producers.
- Logistics providers.

Each actor has relevant financial or material constraints.

## 5.4 Production and consumption

Economic activity follows identifiable production chains.

For example:

Mineral extraction → Material transport → Industrial processing → Construction materials → Building projects.

Projects require both funding and the necessary material supply.

A project should not progress successfully if the required resources or logistical connections are unavailable.

## 5.5 Public finances

The government maintains a budget.

Revenue may include:

- Taxes.
- Government-owned operations.
- Licensing and resource fees.
- Other lawful public income.

Expenditure may include:

- Construction contracts.
- Public salaries.
- Infrastructure maintenance.
- Welfare and public services.
- Subsidies.
- Government administration.
- Debt servicing.

The game should distinguish between recurring operating expenditure and capital investment.

## 5.6 Fiscal consequences

Government financial choices have long-term implications.

Budget deficits can create borrowing requirements.

Infrastructure investment may increase future economic capacity.

Tax increases may improve public revenue while changing private-sector incentives.

Reductions in spending may stabilize finances while reducing public services.

These relationships should remain understandable to the player.

---

# 6. Company and Contract System

## 6.1 Company formation

Companies emerge from the founding expedition's available expertise, equipment, and economic opportunities.

Initial companies should differ in capability, capacity, pricing, and operating practices.

As the colony expands, new companies can form, existing firms can grow, and unsuccessful firms can disappear.

## 6.2 Company attributes

Each company should possess:

| Attribute | Meaning |
|---|---|
| Capital | Available financial resources |
| Equipment | Operational capacity |
| Workforce | Available labor |
| Specialization | Projects the company handles efficiently |
| Reputation | Public and institutional perception |
| Reliability | Historical consistency of delivery |
| Price strategy | How competitively the company bids |
| Logistics capability | Ability to move materials and equipment |
| Work quality | Construction or service quality |
| Labor practices | Working conditions and employment policies |
| Environmental practices | Operational environmental impact |
| Contract history | Previous performance |

## 6.3 Procurement

Government projects requiring private execution enter a contracting process.

Companies submit bids based on:

- Expected material costs.
- Workforce requirements.
- Distance and logistics.
- Available capacity.
- Project complexity.
- Desired profit.
- Risk.

The player evaluates bids and selects a contractor.

Some companies may decline to bid because they lack capacity, materials, expertise, or commercial interest.

## 6.4 Contractor performance

Contracts may experience:

- Successful completion.
- Delays.
- Cost overruns.
- Material shortages.
- Quality deficiencies.
- Labor disputes.
- Insolvency.
- Project failure.

These outcomes should emerge from company attributes and simulation conditions, with controlled uncertainty.

Cheaper bids are not inherently worse. Higher prices are not guaranteed to deliver better outcomes.

## 6.5 Reputation

A company's reputation changes according to its actual behavior.

Reliable completion improves reputation.

Delays, unsafe work, defective construction, and contract failures may reduce reputation.

Reputation can influence future procurement, public trust, and the company's commercial opportunities.

## 6.6 Company autonomy

Companies should continue operating outside government projects.

Depending on economic conditions, they may:

- Expand.
- Recruit workers.
- Purchase equipment.
- Raise prices.
- Compete for contracts.
- Invest in new facilities.
- Shut down unprofitable activities.

Government decisions should affect the market without giving the player direct control over every company.

---

# 7. Projects and Long-Term Work

## 7.1 Project categories

Projects include:

- Construction.
- Infrastructure improvement.
- Resource development.
- Public-service expansion.
- Economic programs.
- Regulatory implementation.
- Administrative reform.
- Scientific and technical development.

## 7.2 Project life cycle

A project progresses through several states.

1. Proposed.
2. Awaiting authorization.
3. Authorized.
4. Awaiting resources or contractors.
5. In progress.
6. Delayed or interrupted, when applicable.
7. Completed or cancelled.

Not every project requires parliamentary approval in every phase of the game.

Routine administrative work should be distinguished from actions requiring legislation or a new budget authorization.

## 7.3 Project requirements

Every project maintains:

- Project objectives.
- Estimated cost.
- Expected duration.
- Required resources.
- Assigned personnel.
- Contractor, if required.
- Current progress.
- Risks.
- Political or legal authorization.
- Expected effects.
- Actual results.

## 7.4 Delegated project management

A project may be assigned to one or more government personnel for an extended period.

Those personnel manage the activity over successive monthly turns.

The player is not required to issue the same orders repeatedly.

Delegated personnel handle routine work within their authority.

They may:

- Monitor contractors.
- Resolve ordinary administrative problems.
- Coordinate deliveries.
- Report progress.
- Manage assigned budgets.
- Request additional resources.
- Escalate significant problems.

## 7.5 Delegation limitations

A delegated official cannot automatically:

- Exceed their authorized budget.
- Change legislation.
- Ignore procurement requirements.
- Override the responsible ministry.
- Authorize politically sensitive changes beyond their mandate.

When such issues arise, the player receives a decision requiring intervention.

This creates management by exception rather than management by constant supervision.

---

# 8. Political Development and Ideology

## 8.1 Emergent political identity

The player's party develops its political identity from the commander's historical decisions.

Policies influence ideological perceptions over time.

Relevant dimensions include:

- Public intervention in the economy.
- Labor and employment protection.
- Environmental protection.
- Economic redistribution.
- Centralization and local autonomy.
- Development priorities.
- Fiscal policy.

The player is not required to select a fixed ideological label at the start.

## 8.2 Political movements

Public interests and conflicts gradually produce organized movements.

Examples:

- Workers seeking safer conditions.
- Residents demanding better public services.
- Businesses opposing high taxation.
- Environmental groups demanding stronger protections.
- Communities seeking increased local autonomy.
- Groups opposing the government's overall direction.

Some movements develop into parties.

## 8.3 Party generation

The game maintains at least five political parties once formal multiparty politics begins.

Party creation considers:

- Unrepresented political demands.
- Economic conditions.
- Existing party positions.
- Population support.
- Prominent political issues.
- Potential ideological constituencies.

Parties should have coherent but adaptable political programs.

## 8.4 Party properties

Each party maintains:

- Name and identity.
- Leadership.
- Policy preferences.
- Core commitments.
- Negotiable positions.
- Public support.
- Parliamentary seats.
- Political reputation.
- Relationships with other parties.
- Trust in the player.
- Recent promises.
- History of government participation.
- Strategic priorities.

Party platforms can evolve in response to changing conditions.

---

# 9. Elections and Polling

## 9.1 Election schedule

Ordinary elections occur every four years.

The third year of each term begins a formal election period.

During this period, parties establish or update their election agendas.

## 9.2 Electoral agendas

A party's election agenda contains a limited number of major commitments.

Examples:

- Construct additional housing.
- Expand mining.
- Reduce government debt.
- Increase public-service spending.
- Strengthen employment protections.
- Reduce corporate taxation.
- Improve environmental conditions.

The player chooses the priorities they want their party to advocate.

## 9.3 Promise tracking

Promises are recorded and remain accessible after the election.

Each commitment can be classified as:

- Not started.
- In development.
- Partially fulfilled.
- Fulfilled.
- Abandoned.
- Blocked by political circumstances.

Public reactions depend on progress, circumstances, and credibility.

The simulation should distinguish between deliberate abandonment and an unsuccessful attempt to deliver.

## 9.4 Polling

Polling allows the player to estimate public support.

Polls have:

- A financial or political resource cost.
- Statistical uncertainty.
- A sample of public preferences.
- Geographic or demographic coverage.
- A publication date.

Polls provide information about likely outcomes but never guarantee election results.

## 9.5 Voting behavior

Voter decisions should reflect a combination of:

- Policy alignment.
- Current economic conditions.
- Personal circumstances.
- Party reputation.
- Leadership confidence.
- Past performance.
- Electoral promises.
- Campaign effectiveness.

The relative importance of each factor should be calibrated through testing.

## 9.6 Seat allocation

The parliament contains 151 seats.

Election results should be converted into seats through a defined proportional allocation method.

The initial implementation may use a simple proportional divisor method, later refined to reflect the intended electoral model.

Details such as electoral thresholds, district constituencies, and adjustment seats remain explicit design decisions.

The essential requirement is a consistent multiparty electoral system in which coalition formation matters.

---

# 10. Parliament and Government Formation

## 10.1 Parliamentary structure

Parliament has 151 seats.

An absolute majority is 76 seats.

Parties may participate in government, support government from outside, or form the opposition.

## 10.2 Government formation

After an election, a government formation phase begins.

The player may be invited or otherwise positioned to attempt government formation, depending on the election results and support available.

Other parties can negotiate among themselves.

## 10.3 Coalition negotiations

Negotiations can include:

- Shared policy commitments.
- Budget priorities.
- Ministerial responsibility.
- Legislative concessions.
- Limits on proposed reforms.
- Government stability arrangements.
- Promises for the coming term.

Parties evaluate offers against their priorities and political interests.

## 10.4 Government confidence

A coalition holding at least 76 seats can command an absolute majority when its members vote together.

Minority governments may also operate through parliamentary agreements, outside support, or abstentions.

This preserves the political character of a system inspired by Swedish parliamentarism.

## 10.5 Coalition cohesion

Government stability depends on:

- Policy compatibility.
- Fulfillment of agreements.
- Personal and institutional trust.
- Public opinion.
- Economic performance.
- Internal party pressure.
- Disputes over legislation.

Coalition members can object to proposals or threaten to withdraw support.

## 10.6 Government change

The advanced political model should support:

- Coalition reshuffles.
- Loss of parliamentary confidence.
- Resignation of governments.
- Attempts to form replacement governments.
- Early elections where permitted by the final rules.

---

# 11. Legislation and Policy Drafting

## 11.1 Legislative proposals

Government policies requiring parliamentary approval are developed through a drafting system.

A proposal consists of one or more clauses.

Each clause has a specific intended effect.

## 11.2 Legislative content

Possible clause categories:

- Public spending.
- Taxation.
- Regulatory requirements.
- Industrial subsidies.
- Environmental standards.
- Employment conditions.
- Administrative powers.
- Public-service obligations.
- Infrastructure authorizations.

## 11.3 Proposal complexity

Larger proposals can produce more substantial changes but may create additional points of political disagreement.

The difficulty of passing legislation depends on its actual contents, the interests of parliamentary parties, fiscal implications, and coalition commitments.

A small proposal is not automatically popular, and a large proposal is not automatically opposed.

## 11.4 Drafting process

The legislative process consists of:

1. Define the policy objective.
2. Assign drafting personnel.
3. Select provisions.
4. Estimate costs and expected consequences.
5. Negotiate parliamentary support.
6. Revise the proposal.
7. Submit for a vote.
8. Implement the approved measures.

## 11.5 Party voting

Each party evaluates legislation according to:

- Ideological alignment.
- Coalition commitments.
- Fiscal effects.
- Constituency interests.
- Political incentives.
- Confidence in implementation.
- Existing relationships.

Party support can change during negotiations.

## 11.6 Implementation

Successful parliamentary approval authorizes the government to act.

It does not automatically finish the associated work.

Implementation requires personnel, administrative capacity, funding, and sometimes commercial contractors.

---

# 12. Government Personnel System

## 12.1 Overall structure

The government has a pool of 20 principal personnel.

**Ten political personnel** are allocated among governing coalition parties.

**Ten permanent administrative personnel** work for the state rather than a political party.

This is a high-level management abstraction, not the entire public-sector workforce.

## 12.2 Political personnel

Political personnel represent the government's political leadership and its capacity to pursue policy priorities.

Their distribution is based on the relative parliamentary strength of the parties participating in government.

A coalition party's personnel may prioritize its own policies and obligations.

## 12.3 Permanent civil servants

Permanent personnel:

- Are not affiliated with individual political parties.
- Can remain employed across election cycles.
- Generally possess greater professional experience.
- Typically work at a slower pace than political appointees.
- Provide continuity and specialized administrative knowledge.

They may differ significantly in their individual skills.

## 12.4 Personnel attributes

Every person should have:

| Attribute | Purpose |
|---|---|
| Professional skill | Competence in assigned work |
| Work speed | Rate of task progression |
| Experience | Accumulated expertise |
| Specialization | Preferred subject area |
| Reliability | Likelihood of consistent performance |
| Current workload | Existing commitments |
| Authority | Decisions they may make independently |
| Political affiliation | Applicable to political staff |
| Assignment | Current responsibility |
| Availability | Whether they can accept additional work |

## 12.5 Assignment types

Personnel may be assigned to:

**Short tasks:** Preparing a report, conducting negotiations, reviewing bids, or completing a defined administrative action.

**Long tasks:** Managing a construction project, implementing a reform, developing a district, or supervising a program over several months or years.

**Standing responsibilities:** Overseeing infrastructure maintenance, procurement, economic development, healthcare administration, or another ongoing function.

Standing responsibilities continue until reassigned, terminated, or interrupted by political changes.

## 12.6 Workload and efficiency

Personnel can have limited work capacity rather than being restricted to one arbitrary task.

A highly demanding assignment might consume most of an official's available capacity.

Several minor duties could potentially be managed simultaneously.

The workload model should remain simple enough for the player to understand at a glance.

## 12.7 Supervision and escalation

Personnel perform delegated work independently.

The game alerts the player when:

- A project exceeds authorized cost.
- A major delay occurs.
- A contractor fails.
- A legal or parliamentary problem arises.
- A significant political dispute occurs.
- The official requires a decision outside their authority.

Routine administration progresses without repeated input.

## 12.8 Government transitions

After an election:

- Permanent civil servants remain in their roles unless affected by lawful administrative changes.
- Political staff positions are redistributed according to the new governing arrangement.
- Ongoing projects continue where legally and financially possible.
- New political leadership may alter priorities or replace assignments.
- Institutional experience persists across governments.

---

# 13. Opposition Gameplay

## 13.1 Losing government

Losing an election does not end the game.

The player continues as leader of their political party, provided they retain that role under the eventual party-leadership rules.

The colony continues operating under the new government.

## 13.2 Opposition activities

Opposition gameplay includes:

- Drafting alternative policies.
- Introducing parliamentary proposals.
- Negotiating with other opposition parties.
- Voting on government legislation.
- Conducting oversight.
- Criticizing government performance.
- Supporting selected government proposals.
- Developing new electoral strategies.
- Rebuilding public trust.
- Preparing for future elections.

## 13.3 Opposition personnel

The player no longer controls the government's ten political positions.

Their party instead receives a smaller party-oriented political capacity suitable for parliamentary and organizational work.

The exact opposition staffing limits will be established during balancing.

Permanent civil servants continue to serve the existing government and public institutions, rather than becoming the player's private staff.

## 13.4 Observing the colony

The player retains access to public information about:

- Economic performance.
- District development.
- Government expenditure.
- Major public projects.
- Public satisfaction.
- Parliamentary activity.
- Company developments.
- Election polling.

Information unavailable to an opposition party should not automatically be revealed.

The player may receive additional details through parliamentary oversight and political investigation.

## 13.5 Regaining power

The opposition player can improve their electoral prospects through policy development, constructive legislative activity, coalition relationships, and campaigning.

Future elections allow them to return to government.

The world should meaningfully reflect the policies of governments that ruled during their absence.

---

# 14. Retirement and Campaign Continuity

## 14.1 Retirement option

The player may choose to retire from active politics.

Retirement is voluntary and should be available at appropriate points in the campaign.

## 14.2 Retirement summary

A retirement screen should show:

- Total years in politics.
- Number of elections contested.
- Years in government.
- Years in opposition.
- Major laws passed.
- Major construction and development achievements.
- Changes in living standards.
- Economic performance.
- Political promises fulfilled.
- Major failures and controversies.
- Long-term condition of the colony.

## 14.3 Historical legacy

The game should compare the state of the colony when the player first arrived with its condition at retirement.

A player who developed a wealthy but unequal industrial society should receive a different historical summary from one who created a slower-growing but broadly prosperous and environmentally stable colony.

The summary should describe actual outcomes rather than applying a single ideological definition of success.

## 14.4 Optional observation mode

After retirement, the player may be offered the ability to advance the simulation as an observer.

Other parties continue governing.

Companies continue operating.

Districts develop and change.

This allows the player to observe how their political and economic legacy survives beyond their active career.

Observer mode should be a later development feature.

---

# 15. Events and Unexpected Developments

## 15.1 Event categories

The colony should experience events arising from simulation conditions.

Categories include:

- Economic shocks.
- Resource shortages.
- Workplace accidents.
- Environmental incidents.
- Infrastructure failures.
- Company bankruptcies.
- Scientific discoveries.
- Migration changes.
- Labor disputes.
- Political scandals.
- Government crises.

## 15.2 Event generation

Events should ideally emerge from existing conditions.

For example, a mine with inadequate safety practices and heavy operational pressure may face elevated accident risk.

The game should avoid relying entirely on unrelated random events.

## 15.3 Event responses

Events may require:

- Emergency funding.
- New legislation.
- Administrative intervention.
- Contract renegotiation.
- Coalition consultation.
- Public communication.
- Changes to development plans.

Events can also alter the political landscape.

---

# 16. User Interface

## 16.1 Main screen

The colony map is the central screen.

The player should be able to inspect districts, view projects, and access relevant management functions without excessive navigation.

## 16.2 Core panels

**Colony:** Map, zoning, district information, infrastructure.

**Economy:** Budget, resource production, employment, taxation, debt.

**Companies:** Contractor directory, bidding, reputation, active contracts.

**Projects:** Proposed, active, delayed, completed, and cancelled work.

**Government:** Coalition, ministries, government agenda, political stability.

**Parliament:** Seat distribution, legislation, voting, negotiations.

**Personnel:** Political staff, permanent officials, workloads, assignments.

**Politics:** Parties, polling, public opinion, election agendas.

**History:** Past elections, policy changes, economic records, significant events.

## 16.3 Monthly turn interface

Before advancing the month, the player should be able to review outstanding decisions.

A monthly report should summarize:

- Completed tasks.
- Project progress.
- Economic changes.
- Budget results.
- Political developments.
- Staff availability.
- Events requiring attention.

## 16.4 Notification priorities

Notifications should distinguish:

- Critical decisions requiring intervention.
- Important developments.
- Routine reports.

The player should not need to dismiss dozens of repetitive updates every month.

## 16.5 Visual style

Initial presentation:

- Flat 2D graphics.
- Tile-based maps.
- Simple icons.
- Party colors.
- Clear tables and charts.
- Minimal animation.
- Readable tooltips.
- Strong information hierarchy.

Graphics development should not become a prerequisite for simulation development.

---

# 17. Simulation Architecture

## 17.1 Separation of systems

The game should separate simulation logic from presentation.

Recommended logical modules:

1. Calendar and turn manager.
2. Map and district simulation.
3. Resource and economy simulation.
4. Population simulation.
5. Company and contract simulation.
6. Project management.
7. Political party simulation.
8. Elections and polling.
9. Parliament and legislation.
10. Government and personnel.
11. Events and history.
12. Save and load.
13. User interface.

## 17.2 Central game state

The simulation maintains a shared game state containing all relevant entities.

Major entity categories include:

- Colony.
- District.
- Population group.
- Company.
- Contract.
- Project.
- Political party.
- Election.
- Parliament.
- Government.
- Personnel.
- Legislation.
- Event.
- Historical record.

Entities should be identified through stable internal IDs.

## 17.3 Monthly update sequence

A deterministic monthly update sequence should be established.

Suggested order:

1. Validate player instructions.
2. Resolve political and administrative actions.
3. Advance assigned work and projects.
4. Process logistics and resource availability.
5. Update production and company activity.
6. Update employment, income, and public finances.
7. Update district and population conditions.
8. Update political attitudes and party support.
9. Generate and resolve simulation events.
10. Record history and generate the monthly report.

The order must be reviewed for dependencies and double-counting.

## 17.4 Reproducible simulation

The game should support seeded randomness.

Identical starting conditions and player decisions should produce identical results when the same random seed is used.

This is important for debugging and balancing.

## 17.5 Save system

Save files should preserve:

- Full colony state.
- Current date.
- Projects and assignments.
- Company finances and capacity.
- Parliamentary composition.
- Legislation and agreements.
- Party identities and relationships.
- Political history.
- Random seed state.

The save format should include version information for future compatibility.

---

# 18. Artificial Intelligence

## 18.1 Company decision-making

Companies decide whether to bid, invest, expand, hire, or withdraw based on their resources, profitability, and available opportunities.

## 18.2 Political party decision-making

Parties evaluate:

- Their ideological positions.
- Their electoral base.
- The economic environment.
- Parliamentary opportunities.
- Coalition relationships.
- Their political reputation.

These evaluations determine negotiations, voting, campaigning, and government formation.

## 18.3 Government AI

When the player is in opposition, an AI-controlled government must be able to:

- Establish priorities.
- Prepare budgets.
- Draft legislation.
- Negotiate support.
- Authorize projects.
- Assign personnel.
- Manage ongoing administrative commitments.
- Respond to major events.

The AI should operate through the same fundamental rules as the player.

## 18.4 AI design approach

An initial utility-based decision model is recommended.

AI actors evaluate available actions using weighted priorities, constraints, and expected outcomes.

Complex machine-learning systems are not required for the initial implementation.

---

# 19. Development Roadmap

## Phase 0 — Design Foundation

**Objective:** Convert the concept into an implementable specification.

Tasks:

- Finalize the primary gameplay loop.
- Select the development engine and language.
- Define entity types and data structures.
- Define the first resource and zoning categories.
- Specify the monthly update order.
- Establish the save-file architecture.
- Define the initial balancing parameters.
- Establish coding and testing conventions.

**Completion requirement:** A documented technical foundation exists, and the project can run an empty monthly simulation.

## Phase 1 — Colony Map and Settlement

**Objective:** Make the founding settlement playable.

Tasks:

- Implement a tile-based map.
- Add terrain properties.
- Add zoning controls.
- Add initial infrastructure.
- Add a starting population.
- Create an inspection interface.
- Implement basic resource storage.
- Add monthly progression.

**Completion requirement:** The player can establish districts and advance the colony through time.

## Phase 2 — Economy and Companies

**Objective:** Make construction dependent on economic activity.

Tasks:

- Implement resource production and consumption.
- Implement government finances.
- Implement company entities.
- Implement contractor bidding.
- Add logistical costs.
- Implement contract progress.
- Add delays and failure conditions.
- Implement company reputation.
- Add workforce and employment effects.

**Completion requirement:** The player can commission infrastructure through companies, and economic conditions affect the project outcome.

## Phase 3 — Projects and Delegation

**Objective:** Establish the game's management system.

Tasks:

- Build the project life cycle.
- Add personnel entities.
- Implement work capacity.
- Implement long-term assignments.
- Implement standing responsibilities.
- Add automatic monthly task progression.
- Add supervision and escalation.
- Create a personnel dashboard.

**Completion requirement:** The player can assign a person to a long-running project, advance several months, and receive meaningful progress reports without repeated instructions.

## Phase 4 — Population and Political Foundations

**Objective:** Make settlement decisions influence political attitudes.

Tasks:

- Implement district-level population conditions.
- Add income and employment effects.
- Implement public-service satisfaction.
- Add pollution and inequality.
- Implement ideological dimensions.
- Track the player's political record.
- Add political pressures and movements.
- Develop initial party generation.

**Completion requirement:** Different development strategies produce measurably different political conditions.

## Phase 5 — Elections and Parliament

**Objective:** Implement the first complete electoral transition.

Tasks:

- Generate at least five political parties.
- Implement party agendas.
- Implement public opinion and polling.
- Build election calculations.
- Allocate 151 parliamentary seats.
- Display election results.
- Add parliamentary voting.
- Implement majority calculations.
- Add a basic government formation system.

**Completion requirement:** The founding settlement can reach its first election and produce a functioning multiparty parliament.

## Phase 6 — Coalitions and Legislation

**Objective:** Make parliamentary government playable.

Tasks:

- Implement coalition negotiations.
- Add governing agreements.
- Assign political positions proportionally.
- Add legislative drafting.
- Add party support calculations.
- Implement parliamentary voting.
- Connect legislation to administrative projects.
- Add government stability mechanics.
- Implement election promises and policy tracking.

**Completion requirement:** The player can form a government, negotiate legislation, pass policies, and implement them through delegated personnel.

## Phase 7 — Opposition and AI Government

**Objective:** Support continued play after electoral defeat.

Tasks:

- Implement AI government formation.
- Implement AI budgets and priorities.
- Implement AI legislative proposals.
- Add opposition actions.
- Add parliamentary oversight.
- Introduce opposition staffing.
- Allow the player to campaign while outside government.
- Preserve colony development under AI control.
- Implement subsequent elections.

**Completion requirement:** The player can lose power, complete a term in opposition, and successfully compete in another election.

## Phase 8 — Persistence, Retirement, and History

**Objective:** Support long-running political campaigns.

Tasks:

- Implement full save and load.
- Add election history.
- Record policy and government changes.
- Track party evolution.
- Maintain long-term company histories.
- Add retirement.
- Generate a political career summary.
- Add optional observation mode.

**Completion requirement:** A campaign can span multiple governments and end through voluntary retirement.

## Phase 9 — Balancing and Refinement

**Objective:** Make the interconnected systems strategically interesting and reliable.

Tasks:

- Balance company prices and project durations.
- Balance economic growth and resource scarcity.
- Balance political responsiveness.
- Test coalition formation.
- Test ideological diversity.
- Balance personnel capacity.
- Improve AI decision-making.
- Reduce repetitive administration.
- Improve UI readability.
- Optimize long-running simulation performance.
- Fix emergent economic and political deadlocks.

**Completion requirement:** The game can sustain a multidecade simulated political history without systemic breakdowns or repetitive player workloads.

---

# 20. Testing Strategy

## 20.1 Unit tests

Test independent rules including:

- Resource calculations.
- Budget arithmetic.
- Contract cost calculations.
- Project progress.
- Personnel workloads.
- Seat allocation.
- Parliamentary vote counting.
- Coalition seat totals.
- Election promise tracking.

## 20.2 Integration tests

Test relationships between systems.

Examples:

- A new mine creates jobs and changes district conditions.
- A transport failure delays several construction contracts.
- New employment regulations influence company operating costs.
- A government spending increase affects debt and public services.
- A coalition withdrawal changes parliamentary support.

## 20.3 Long-term simulation tests

Allow AI-controlled games to advance automatically for many years.

Monitor:

- Population growth.
- Company survival.
- Economic stability.
- Government turnover.
- Party diversity.
- Parliamentary deadlocks.
- Project completion rates.
- Government debt.
- Save-file integrity.

## 20.4 Gameplay testing

Check whether the player understands:

- Why companies fail.
- Why budgets change.
- Why parties support or oppose legislation.
- Why voters change their preferences.
- Why government projects are delayed.
- Why staff members need additional authority.
- Why an election was won or lost.

The simulation should provide explanations rather than hiding all causal relationships.

---

# 21. Development Priority and Scope Control

## 21.1 Minimum playable political game

The first complete playable version should contain:

- One colony map.
- Basic zoning.
- A simplified economy.
- Several private companies.
- Contractor bidding.
- Projects taking multiple months.
- Twenty government personnel.
- Delegated long-term assignments.
- District-level population conditions.
- At least five parties.
- A 151-seat parliament.
- Four-year elections.
- Coalition formation.
- Clause-based legislation.
- Opposition gameplay.
- Multiple electoral cycles.
- Retirement and campaign summaries.
- Saving and loading.

This is the minimum complete expression of the intended game, not the minimum technical prototype.

## 21.2 Features to defer

The following are valuable but not essential to the first complete version:

- Highly detailed individual citizens.
- Complex orbital and interplanetary trade.
- Sophisticated transportation pathfinding.
- Large research trees.
- Detailed international diplomacy.
- Individual parliamentary representatives.
- Extensive political character relationships.
- Complex media organizations.
- Multiplayer.
- Elaborate animated graphics.
- Procedurally generated narrative dialogue.
- Full economic supply chains involving dozens of material categories.

These systems should only be added when the underlying economic and political game is already functional.

---

# 22. Open Design Decisions

The following require decisions before their respective implementation phases.

| Issue | Decision required |
|---|---|
| Map | Fixed or procedurally generated |
| Terrain | Tile size and environmental detail |
| Districts | Manually drawn boundaries or predefined regions |
| Resources | Exact starting resource chain |
| Economy | Taxation, prices, wages, and ownership model |
| Companies | Rules for market entry and bankruptcy |
| Personnel | Assignment capacity and delegation authority |
| Parties | Conditions for formation, merger, or dissolution |
| Electoral law | Proportional method and any threshold |
| Coalition negotiations | Exact concessions and bargaining mechanism |
| Legislative process | Voting discipline, negotiation, and amendment rules |
| Government crises | Confidence rules and early-election procedures |
| Opposition | Available staffing and parliamentary actions |
| Retirement | Player-chosen conclusion and observer-mode behavior |
| Difficulty | How challenge scales without arbitrary penalties |
| Game ending | Whether the colony can fail independently of retirement |

These are deliberately left as design decisions rather than silently treating one possible implementation as settled.

---

# 23. Project Completion Criteria

The game should be considered functionally complete when it supports the following full sequence:

1. A new colony is founded.
2. The player builds residential and industrial districts.
3. Companies compete for public construction contracts.
4. Projects consume time, labor, materials, and public funds.
5. District economies and social conditions change.
6. Political movements and parties develop from those conditions.
7. The player establishes an electoral agenda.
8. A multiparty election allocates 151 seats.
9. Coalition negotiations determine who governs.
10. Government responsibilities and personnel are allocated.
11. Legislation is drafted, negotiated, and voted upon.
12. Successful legislation produces work requiring implementation.
13. Staff manage projects over multiple months or years.
14. Government performance changes public opinion.
15. Another election takes place.
16. The player can remain in power or continue in opposition.
17. AI governments continue managing the colony.
18. The player can return to office in a later election.
19. The colony retains its institutional and economic history.
20. The player may retire and review their long-term political legacy.

**Final design objective:** A self-sustaining political colony simulation in which settlement decisions produce economic conditions, economic conditions produce political conflicts, political institutions shape government action, and government action continuously changes the colony.
