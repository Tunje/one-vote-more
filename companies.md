
# Political Colony Simulator
# Companies, Institutions, Ownership, Media & Corporate Influence
## Complete Game Design and Development Specification

**Version:** 0.6  
**Status:** Detailed development plan  
**Simulation interval:** Monthly turns  
**Economic model:** Mixed economy with autonomous public and private organizations  
**Political model:** Multiparty parliamentary democracy with 151 seats  
**Related systems:** Economy, population, districts, government, elections, parliament, legislation, personnel, projects, contracts, education, media, public health, law enforcement

---

# 1. System Overview

Companies and institutions must be independent actors in the colony.

They must not exist merely as menus from which the player purchases buildings, goods, or services.

Every company should be an organization with ownership, management, employees, finances, assets, interests, and a history.

Companies may grow, decline, change ownership, replace leadership, merge, split, become politically influential, violate regulations, or go bankrupt.

Some are controlled by individual founders. Others are governed by boards of directors, shareholders, cooperatives, or public authorities.

Companies may operate in construction, mining, manufacturing, transportation, retail, agriculture, education, healthcare, entertainment, communications, alcohol production, news publishing, and other economic sectors.

Institutions such as schools and hospitals may be publicly owned or privately operated.

Media organizations may investigate events, publish accurate reports, make errors, show editorial bias, deliberately mislead readers, or become tools of their owners.

Companies and institutions must interact with the same economic and political simulation as every other actor.

Their decisions should create consequences that develop naturally over time.

The player must not have complete control over private organizations. As settlement commander, they initially possess extensive government authority, but private companies still make their own business decisions. After the transition to parliamentary government, intervention must follow legislation, budgets, and administrative procedures.

## 1.1 Main design objectives

1. Create companies with persistent identities and histories.
2. Give companies autonomous economic behavior.
3. Support different ownership and management structures.
4. Allow founders, owners, CEOs, and boards to have individual characteristics.
5. Make leadership changes meaningful.
6. Support inheritance, sales, mergers, and acquisitions.
7. Permit good companies to deteriorate under poor leadership.
8. Permit struggling companies to improve under competent management.
9. Make industries economically and politically different.
10. Allow public and private institutions to compete or coexist.
11. Simulate corporate influence without making every company politically active.
12. Allow conflicts between commercial interests and public welfare.
13. Make newspapers readable and economically independent.
14. Distinguish media accuracy, bias, credibility, and deliberate dishonesty.
15. Allow regulation, monopolies, licensing, and state ownership.
16. Connect alcohol production and distribution to health, consumption, crime, happiness, and political behavior.
17. Simulate corporate misconduct, investigation, and enforcement.
18. Preserve companies and their histories across political terms.
19. Allow company behavior to influence political agendas and elections.
20. Keep the system playable without overwhelming the player with administrative work.

---

# 2. Fundamental Company Architecture

A company is a legal and economic organization.

It is separate from its owners, managers, employees, facilities, and products.

This distinction is essential.

A company can survive the death or departure of its founder.

Its factories can continue operating when a CEO is replaced.

Its reputation can remain damaged after the responsible leadership has departed.

Its ownership can change without automatically destroying contracts, employment, or physical assets.

## 2.1 Core company properties

Every company should have:

- Unique company ID.
- Company name.
- Foundation date.
- Company type.
- Legal structure.
- Ownership structure.
- Management structure.
- Headquarters.
- Registered operating districts.
- Financial accounts.
- Assets and liabilities.
- Facilities.
- Employees.
- Products and services.
- Equipment.
- Contracts.
- Reputation.
- Reliability.
- Market share.
- Political interests.
- Political activity status.
- Legal compliance record.
- Historical events.
- Current objectives.
- Active risks.
- Current operating status.

## 2.2 Separation of organization and individuals

The game should distinguish five concepts.

**Company:** The organization that enters contracts, owns assets, hires workers, and operates businesses.

**Owner:** A person, institution, company, or shareholder group possessing an ownership interest.

**Board:** A governing body overseeing major strategic decisions, when the company uses that structure.

**CEO or manager:** The person responsible for day-to-day management and implementation of business strategy.

**Facility:** A mine, factory, school, newspaper office, warehouse, shop, or other physical operation owned or controlled by an organization.

Not every company needs all five in the same form.

---

# 3. Types of Companies and Organizations

The company system should support different organizational categories.

These categories affect objectives, governance, financial behavior, and applicable regulation.

## 3.1 Private owner-operated business

A business controlled by an individual owner.

Examples:

- Small construction company.
- Local farm.
- Restaurant.
- Workshop.
- Independent newspaper.
- Small brewery.

The owner normally makes both strategic and operational decisions.

These businesses may respond quickly to changing circumstances.

However, their performance can depend heavily on the owner's ability and judgment.

## 3.2 Privately owned company with appointed management

The owner controls the company but appoints a CEO or manager.

The owner determines major strategic priorities.

The CEO manages ordinary operations.

The owner may replace the CEO.

Disagreements between owner and CEO can affect company performance.

## 3.3 Board-governed corporation

A company with a board responsible for major decisions.

The board may:

- Appoint or dismiss the CEO.
- Approve major investments.
- Authorize mergers.
- Establish strategic priorities.
- Approve substantial borrowing.
- Review financial performance.
- Authorize restructuring.
- Recommend or approve major asset sales.
- Determine leadership succession.

The CEO executes the board's approved strategy.

Board members may disagree.

## 3.4 Publicly traded corporation

A corporation with ownership divided into shares.

Shareholders may include:

- Individual citizens.
- Company founders.
- Other companies.
- Investment organizations.
- Public institutions.
- Government.

Ownership changes through share transactions.

Large shareholders may influence board appointments and strategic decisions.

The first implementation does not require a complete financial stock exchange.

Share transactions can initially occur through simplified monthly investment and ownership events.

## 3.5 Cooperative

A business owned by its members.

Examples:

- Agricultural cooperative.
- Worker-owned construction company.
- Consumer retail cooperative.
- Community energy producer.

Cooperatives may have:

- Elected management.
- Member voting.
- Profit-sharing rules.
- Restrictions on ownership transfers.
- Member-oriented objectives.

A cooperative may prioritize member employment or service quality alongside profitability.

It is not automatically efficient, honest, or politically progressive.

## 3.6 Government-owned enterprise

An enterprise owned by the colony government.

Examples:

- Public power company.
- Water utility.
- Government mining operation.
- Public transportation provider.
- State alcohol retailer.

A public enterprise has its own management and operating accounts.

Government ownership does not mean unlimited financial resources or guaranteed competence.

Public enterprises may have commercial objectives, public-service obligations, or both.

## 3.7 Mixed-ownership enterprise

A company with public and private owners.

Ownership percentages determine financial claims and governance rights according to its legal structure.

A public-private company may experience disagreements between commercial objectives and government policy.

## 3.8 Nonprofit organization

An organization that operates for a defined institutional or public purpose rather than distributing profits to owners.

Examples:

- Educational foundation.
- Independent research institution.
- Charitable medical provider.
- Nonprofit newspaper.
- Community development organization.

Nonprofits may earn revenue and accumulate reserves.

Their surplus must be used according to their governing rules.

They can still be inefficient, politically active, or poorly managed.

## 3.9 Government institutions

Public institutions differ from ordinary commercial companies.

Examples:

- Public schools.
- Public hospitals.
- Regulatory authorities.
- Government research institutes.
- Public news organizations.

They operate under public mandates and government funding arrangements.

They may be represented using the same organizational framework, with different governance and financial rules.

---

# 4. Ownership and Control

Ownership and management must remain separate.

## 4.1 Ownership records

Each organization has an ownership table.

Example:

**Atlas Construction**

| Owner | Ownership |
|---|---:|
| Founder | 55% |
| Investment company | 25% |
| Employee investment group | 20% |
| Total | 100% |

Ownership interests determine financial claims and applicable governance rights.

The ownership percentages must total 100%, subject to any explicitly modeled special share classes.

## 4.2 Control

A controlling owner may appoint managers or influence board decisions.

However, the exact powers depend on the company's legal structure.

A 40% shareholder may exercise substantial practical influence without having majority ownership.

A cooperative may distribute voting power differently from ownership shares.

## 4.3 Ownership objectives

Owners may prioritize different outcomes.

Examples:

- Short-term profit.
- Long-term company growth.
- Maintaining family ownership.
- Stable employment.
- Market expansion.
- Political influence.
- Public-service quality.
- Environmental objectives.
- Maintaining a specific editorial direction.
- Preserving the founder's legacy.

These priorities influence corporate behavior.

## 4.4 Ownership changes

Ownership may change through:

- Sale.
- Inheritance.
- Share purchases.
- Mergers.
- Acquisitions.
- Government purchase.
- Privatization.
- Bankruptcy restructuring.
- Cooperative conversion, where lawful.

Ownership changes must preserve company and asset history.

---

# 5. Owners, CEOs, Managers, and Board Members

Important corporate decision-makers should be individual characters.

The game does not need a fully simulated character for every employee.

However, named leaders should have persistent identities and measurable influence.

## 5.1 Character attributes

Corporate leaders may have:

- Unique ID.
- Name.
- Age or career stage.
- Skills.
- Talents.
- Experience.
- Risk tolerance.
- Management style.
- Strategic priorities.
- Ethical standards.
- Political interests.
- Personal wealth.
- Ownership stakes.
- Relationship to other leaders.
- Historical achievements.
- Current employment.
- Reputation.

## 5.2 Core leadership skills

| Skill | Effect |
|---|---|
| Business Management | General operational effectiveness |
| Finance | Financial planning and debt management |
| Engineering | Technical and industrial decisions |
| Logistics | Supply-chain decisions |
| Negotiation | Contracts and commercial bargaining |
| Human Resources | Recruitment and workforce management |
| Strategy | Long-term investments |
| Communication | Marketing and public relations |
| Legal Knowledge | Regulatory and contractual decisions |
| Industry Expertise | Sector-specific performance |

## 5.3 Leadership talents

Possible talents include:

- Exceptional Organizer.
- Industrial Visionary.
- Financial Strategist.
- Skilled Negotiator.
- Conservative Investor.
- Risk Taker.
- Workforce Developer.
- Technical Specialist.
- Effective Communicator.
- Political Networker.
- Crisis Manager.
- Detail-Oriented.
- Opportunist.
- Poor Delegator.
- Impulsive.
- Nepotistic.
- Reckless Expansionist.

Talents can be positive, negative, or situational.

A Risk Taker may lead a company into profitable new markets or expose it to catastrophic losses.

A Conservative Investor may protect a company during difficult economic periods but miss growth opportunities.

## 5.4 Leadership and results

A CEO's competence should affect the company through actual decisions.

An incompetent CEO may:

- Miscalculate investments.
- Bid too cheaply.
- Overestimate production capacity.
- Hire unsuitable managers.
- Borrow excessively.
- Expand into unprofitable sectors.
- Neglect maintenance.
- Mishandle supply contracts.
- Fail to respond to market changes.

These decisions create financial and operational consequences.

The game should not simply apply an arbitrary permanent penalty because the CEO has a low skill score.

---

# 6. Corporate Governance

Different company structures determine who makes decisions.

## 6.1 Owner-operated businesses

The owner makes most major decisions.

Decision speed is relatively fast.

There is little internal oversight.

The owner's abilities can strongly influence performance.

## 6.2 CEO-managed companies

The CEO makes routine operational decisions.

The owner or board sets major objectives and approves decisions outside the CEO's authority.

## 6.3 Board-governed companies

Boards make major strategic decisions.

Board decisions may occur:

- At scheduled meetings.
- During financial crises.
- When major investments are proposed.
- During leadership disputes.
- During merger or acquisition negotiations.
- When the CEO's performance becomes unacceptable.

## 6.4 Board composition

A board may contain three to seven members in the initial implementation.

Board members have:

- Individual interests.
- Skills.
- Ownership relationships.
- Voting rights.
- Strategic priorities.
- Relationships with the CEO.

## 6.5 Board voting

Major decisions require board approval according to the company's governance rules.

An ordinary majority may be sufficient for routine strategic decisions.

Certain actions may require a supermajority or shareholder approval.

The exact thresholds are configurable by legal structure.

## 6.6 Board disagreements

Boards may disagree over:

- Expansion.
- Debt.
- Management appointments.
- Political activity.
- Dividends.
- Wages.
- Environmental investments.
- Mergers.
- Company sales.

Disagreement may delay decisions.

Severe disputes may trigger leadership changes or ownership conflicts.

## 6.7 CEO replacement

A board or authorized owner may replace a CEO because of:

- Poor financial performance.
- Contract failures.
- Strategic disagreements.
- Misconduct.
- Retirement.
- Illness or death.
- Ownership changes.
- Loss of confidence.
- Succession planning.

A replacement affects future company decisions but does not automatically remove existing obligations.

---

# 7. Corporate Succession, Inheritance, and Nepotism

This must be a meaningful system because leadership succession can change the quality of an established company.

## 7.1 Succession events

Possible events:

- Founder retires.
- Owner dies.
- CEO resigns.
- Board dismisses management.
- Company is inherited.
- Ownership is sold.
- Family succession occurs.
- Management buyout.
- Hostile takeover.
- Bankruptcy restructuring.

## 7.2 Inheritance

If an owner dies, ownership transfers according to the company's legal and inheritance arrangements.

The heir may inherit:

- Ownership.
- Voting control.
- The right to appoint management.
- Financial claims.
- Family obligations.

Inheriting ownership does not necessarily mean inheriting the CEO position.

However, a controlling family owner may choose to appoint a relative.

## 7.3 Example: incompetent successor

**Original company:** Frontier Construction.

Its founder is a highly experienced engineer with a reputation for reliable delivery.

Over fifteen years, the company has:

- Completed numerous public projects.
- Built a skilled workforce.
- Acquired expensive equipment.
- Developed reliable suppliers.
- Earned strong public trust.

The founder retires and transfers controlling ownership to their son.

The son has:

- Business Management: 24.
- Engineering: 12.
- Finance: 30.
- Strategy: 18.
- Risk tolerance: High.
- Talent: Impulsive.

He appoints himself CEO.

The company's existing assets and skilled workers remain.

Its reputation does not immediately disappear.

However, under the new management, it may begin to:

- Underbid projects.
- Accept more contracts than it can handle.
- Cut maintenance spending.
- Lose experienced managers.
- Borrow too aggressively.
- Miss deadlines.

Over time, actual performance may deteriorate.

The player could initially continue choosing the company because of its excellent reputation, only to discover that its recent work no longer matches its historical record.

This is a central example of why the company and its leadership must be separate.

## 7.4 Alternative succession outcomes

The heir may also:

- Retain the previous management team.
- Appoint a highly capable CEO.
- Sell the company.
- Allow a professional board to govern.
- Improve their own skills over time.
- Turn the company around.

Family succession should create uncertainty, not guarantee decline.

## 7.5 Reputation after leadership changes

The company retains its historical reputation.

However, recent performance should gradually influence public perception more strongly.

The game should distinguish:

- Long-term reputation.
- Recent performance.
- Current leadership confidence.

This allows a historically respected company to remain popular temporarily even while its actual reliability deteriorates.

---

# 8. Company Economic Behavior

Companies use the economic simulation already specified.

Each company has its own financial accounts, inventories, workforce, facilities, obligations, and operating capacity.

## 8.1 Monthly decision-making

Companies evaluate:

1. Available cash.
2. Existing contracts.
3. Current production.
4. Resource requirements.
5. Labor requirements.
6. Expected market demand.
7. Market prices.
8. Available logistics.
9. Outstanding debt.
10. Investment opportunities.
11. Government regulations.
12. Management objectives.

## 8.2 Production planning

A company decides how much to produce based on:

- Expected sales.
- Existing inventory.
- Operating costs.
- Available workers.
- Available materials.
- Capacity.
- Financial resources.

It should not automatically produce at full capacity if there is no profitable demand.

## 8.3 Employment

Companies may:

- Hire workers.
- Offer higher wages.
- Reduce vacancies.
- Dismiss workers.
- Provide training.
- Expand or close facilities.

These decisions affect household income and public opinion.

## 8.4 Investment

Companies may invest in:

- New factories.
- Equipment.
- Additional workers.
- Logistics.
- Research.
- New business sectors.
- Competitor acquisitions.

Investment must require actual funding and resources.

## 8.5 Financial failure

Companies may experience losses, financial distress, restructuring, or bankruptcy.

Physical assets remain in the simulation.

A failed company may have its facilities sold to another operator.

Workers may become unemployed.

Government contracts may be interrupted.

## 8.6 Business lifecycle

Every company has an operating status.

Possible states:

- Forming.
- Active.
- Expanding.
- Stable.
- Contracting.
- Financially distressed.
- Under administration.
- Insolvent.
- Being liquidated.
- Acquired.
- Dissolved.

Transitions between states must follow defined economic or legal conditions.

---

# 9. Business Formation and Entrepreneurship

New businesses should arise as opportunities develop.

They should not require the player to create every company manually.

## 9.1 Company formation

Potential founders evaluate:

- Demand for products or services.
- Market prices.
- Competition.
- Startup costs.
- Available capital.
- Available workers.
- Licenses.
- Government regulations.
- Suitable locations.
- Expected profitability.

## 9.2 Example: new brewery

The colony has a growing population and increasing demand for recreational beverages.

An entrepreneur identifies the opportunity.

They possess sufficient capital and relevant expertise.

They may apply for permission to establish a brewery.

If the legal system allows the activity, they can invest in facilities and begin production.

If production is restricted, they may choose another business, lobby for legal changes, or potentially attempt unlawful production.

## 9.3 Formation outcomes

A startup may:

- Succeed.
- Remain small.
- Grow rapidly.
- Be acquired.
- Change industries.
- Fail financially.

Business formation should respond to actual economic conditions.

## 9.4 Market entry barriers

Entry may be restricted by:

- High capital requirements.
- Limited resources.
- Scarce skilled workers.
- Existing monopolies.
- Licensing requirements.
- Transport capacity.
- Dominant competitors.
- Government policy.

These barriers create political conflicts over competition and regulation.

---

# 10. Competition, Monopolies, and Market Power

## 10.1 Market share

Companies have market shares by sector and relevant geographic market.

Examples:

- Construction.
- Mining.
- Food production.
- Utilities.
- Retail.
- Alcohol distribution.
- News media.
- Education.

Market share should be based on actual activity, not a permanently assigned attribute.

## 10.2 Market concentration

A sector may contain:

- Many small competitors.
- Several major competitors.
- A dominant company.
- A private monopoly.
- A government monopoly.
- A mixed public-private structure.

## 10.3 Monopoly effects

A dominant business may have greater ability to:

- Raise prices.
- Influence suppliers.
- Control market access.
- Negotiate favorable contracts.
- Influence political decisions.
- Prevent competition.

However, large businesses may also benefit from economies of scale.

The effect of concentration should depend on actual incentives, technology, regulation, and market conditions.

## 10.4 Competition law

The government may establish rules governing:

- Mergers.
- Monopolistic practices.
- Price manipulation.
- Market access.
- Exclusive contracts.
- Anticompetitive agreements.

Enforcement requires administrative capacity.

## 10.5 Public monopoly

The government may operate certain sectors exclusively.

A public monopoly can have objectives beyond profit, including:

- Universal access.
- Quality control.
- Public health.
- Stable prices.
- Revenue generation.

It may also suffer from poor management, inadequate capacity, or political interference.

---

# 11. Institutions

Institutions provide services that influence the population and economy.

They may be public, private, cooperative, or nonprofit.

## 11.1 Institution types

Initial categories:

- Schools.
- Hospitals.
- Research institutions.
- Training centers.
- Cultural institutions.
- Public utilities.
- News organizations.
- Social-service providers.

## 11.2 Institution structure

Every institution has:

- Owner.
- Operator.
- Management.
- Facilities.
- Employees.
- Funding.
- Operating expenses.
- Service capacity.
- Service quality.
- Public reputation.
- Regulatory status.
- Service area.

## 11.3 Institutional independence

An institution can be publicly funded without being directly operated by government.

A private company may operate a publicly funded school.

A nonprofit foundation may operate a hospital.

A public institution may employ independent professional management.

The simulation must separate:

- Ownership.
- Funding.
- Operation.
- Regulation.
- Service delivery.

---

# 12. Education System

Schools should become an important link between the economy and the political system.

## 12.1 School ownership

Possible structures:

- Public school.
- Privately owned school.
- Nonprofit school.
- Cooperative school.
- Publicly funded private school.

## 12.2 Starting schools

Early colony schools are likely to be publicly established because the settlement initially has limited infrastructure.

However, private education providers can emerge when economic conditions and legislation permit.

## 12.3 School attributes

Every school tracks:

- Capacity.
- Enrollment.
- Teachers.
- Teacher qualifications.
- Facilities.
- Funding.
- Fees.
- Educational quality.
- Accessibility.
- Management.
- Operating costs.
- Student outcomes.

## 12.4 Educational outcomes

Schools influence:

- Future workforce skill levels.
- Availability of specialists.
- Economic productivity.
- Employment opportunities.
- Household expenses.
- Social mobility.
- District development.

Education should produce gradual long-term effects.

A newly built school should not instantly create qualified engineers.

## 12.5 Private schools

An entrepreneur or organization may establish a private school.

Depending on the legal system, the school may:

- Charge tuition.
- Receive public funding.
- Operate through a nonprofit foundation.
- Operate commercially.
- Specialize in certain types of education.

Private schools should follow the same staffing, financial, and service-quality rules as public schools.

## 12.6 Education policy

Government decisions may include:

- Public school funding.
- Permission for private schools.
- Public funding of private providers.
- Tuition regulation.
- Teacher qualification requirements.
- Curriculum requirements.
- Inspection standards.
- School access rules.

## 12.7 Political consequences

Possible debates:

- Private versus public provision.
- Educational equality.
- School choice.
- Public expenditure.
- Education quality.
- Profit extraction.
- Geographic access.

Political attitudes should respond to actual outcomes.

A successful private school sector may become popular.

A poorly regulated sector may create inequalities or financial controversies.

Public schools may outperform or underperform private schools depending on circumstances.

---

# 13. Healthcare and Other Public Services

The same institutional system should support healthcare.

## 13.1 Healthcare providers

Possible providers:

- Public hospitals.
- Private hospitals.
- Nonprofit clinics.
- Publicly funded private clinics.
- Specialist medical companies.

## 13.2 Healthcare inputs

Healthcare requires:

- Qualified workers.
- Medical supplies.
- Energy.
- Water.
- Facilities.
- Operating funds.
- Logistics.

## 13.3 Healthcare outcomes

Healthcare influences:

- Population health.
- Worker availability.
- Mortality.
- Public satisfaction.
- Household finances.
- Government spending.

## 13.4 Policy questions

Government may decide:

- Who can operate hospitals.
- Who pays for care.
- Whether private providers receive public contracts.
- What minimum standards apply.
- How services are geographically distributed.

These decisions create economic and political consequences.

---

# 14. Newspapers and Media Organizations

Newspapers must be readable in the game.

They are not simply numerical influence modifiers.

Each newspaper is operated by an organization with ownership, management, employees, editorial policies, finances, and a reputation.

## 14.1 Media company types

Possible structures:

- Independent privately owned newspaper.
- Newspaper owned by a large corporation.
- Family-owned newspaper.
- Cooperative newspaper.
- Nonprofit news organization.
- Public-service news organization.
- Party-affiliated publication.

## 14.2 Newspaper attributes

Every newspaper has:

- Name.
- Owner.
- Publisher.
- Editor.
- Editorial priorities.
- Journalistic resources.
- Investigative capability.
- Accuracy record.
- Correction practices.
- Editorial bias.
- Commercial incentives.
- Political affiliations.
- Readership.
- Distribution coverage.
- Revenue.
- Reputation.

## 14.3 Newspaper content

Each newspaper publishes a monthly edition.

An edition can contain:

- Major headlines.
- Economic news.
- Political developments.
- Company news.
- Construction and infrastructure updates.
- Investigations.
- Editorial opinions.
- Advertising.
- Election coverage.
- Public controversies.

The player can open and read the edition.

## 14.4 Article types

Articles should have defined types.

**News report:** Attempts to describe events.

**Investigation:** Examines a specific issue using available evidence.

**Editorial:** Expresses the publication's viewpoint.

**Opinion article:** Expresses an author's position.

**Company announcement:** Identified as an announcement or advertisement.

**Correction:** Addresses a previous error.

These categories should be visible to the player.

## 14.5 Underlying facts

The simulation should maintain a record of actual events.

For example:

A construction contractor missed a deadline because it lacked materials.

That event exists independently of whether newspapers report it.

Newspapers select, investigate, interpret, and describe events from the shared simulation.

## 14.6 Accuracy and truthfulness

Media behavior should distinguish:

- Accurate factual reporting.
- Incomplete reporting.
- Misleading framing.
- Accidental factual errors.
- Unsupported claims.
- Deliberate misinformation.
- Editorial opinion.

An opinionated newspaper is not automatically dishonest.

A newspaper may present accurate facts while strongly favoring certain policies.

## 14.7 Editorial bias

Editorial bias affects:

- Which events receive coverage.
- Which subjects are investigated.
- Headline emphasis.
- Editorial recommendations.
- The perspectives included in articles.

Bias must not automatically convert true events into false information.

## 14.8 Dishonest reporting

A media organization may knowingly publish false or misleading claims.

The likelihood depends on:

- Ownership pressure.
- Editorial leadership.
- Ethical standards.
- Financial incentives.
- Political objectives.
- Competition.
- Legal risks.
- Fear of losing readership.
- Likelihood of exposure.

Deliberate dishonesty should have potential consequences.

## 14.9 Corrections and reputation

When false reporting is exposed:

- The newspaper may publish a correction.
- Other publications may report the error.
- Credibility may decline.
- Readers may lose trust.
- Advertisers may withdraw.
- Legal consequences may follow where applicable.

A newspaper that promptly corrects errors should not necessarily suffer the same long-term reputation damage as one that knowingly fabricates stories.

## 14.10 Investigative journalism

Newspapers may investigate:

- Corruption.
- Unsafe working conditions.
- Government waste.
- Contractor failures.
- Environmental damage.
- Monopoly abuses.
- Mismanagement.
- Political misconduct.

Investigations require staff time and resources.

They may succeed, fail, uncover only partial evidence, or produce incorrect conclusions.

## 14.11 Media readership

Readership depends on:

- Distribution access.
- Subscription price.
- Public interest.
- Credibility.
- Editorial preferences.
- Quality.
- Competition.

Readers do not automatically believe everything they encounter.

Household groups may differ in their trust in particular publications.

## 14.12 Newspaper finances

Media companies may earn revenue from:

- Subscriptions.
- Advertising.
- Individual sales.
- Donations.
- Institutional funding.
- Public funding where permitted.

They incur expenses from:

- Journalists.
- Editors.
- Investigations.
- Distribution.
- Facilities.
- Printing or communications infrastructure.

A newspaper can become insolvent or be acquired.

---

# 15. Newspaper Reading Interface

## 15.1 Monthly newspaper editions

Each paper publishes an edition containing several articles.

The newspaper screen includes:

- Publication name.
- Date.
- Owner.
- Editor.
- Headlines.
- Article categories.
- Readership information.
- Historical editions.

## 15.2 Article presentation

A readable article contains:

- Headline.
- Publication date.
- Reporter or author.
- Article category.
- Body text.
- Relevant organizations and people.
- Sources or evidence where appropriate.

## 15.3 Article generation

Articles should be generated from structured simulation events.

For example:

**Underlying event:**

Frontier Construction completes only 35% of its scheduled work because of poor management and material shortages.

One newspaper might publish:

"Hospital Project Delayed as Contractor Misses Targets"

Another might publish:

"Government Procurement Decisions Under Scrutiny"

A company-friendly publication might emphasize material shortages rather than management failures.

These can be different interpretations of the same event without necessarily being factually false.

## 15.4 Deliberate false reporting

A dishonest newspaper might falsely claim that the government cancelled the project.

The underlying simulation must retain the real status.

The false claim becomes a separate information event that can be challenged, investigated, or corrected.

## 15.5 Player information

The player should not automatically know whether every article is true.

They can compare:

- Different newspapers.
- Official government reports.
- Company records available to them.
- Public financial records.
- Investigative findings.

Access to information should depend on the player's position and legal authority.

The government may have access to information unavailable to an opposition party.

## 15.6 Historical archive

Newspaper editions remain readable in an archive.

This creates a record of the colony's political and economic history.

---

# 16. Corporate Political Influence

Companies may attempt to influence government decisions, but they are not required to do so.

## 16.1 Political activity status

A company can be:

- Politically inactive.
- Occasionally politically engaged.
- Actively lobbying.
- Supporting particular policy causes.
- Closely aligned with a political party.
- Involved in unlawful influence activity.

Political involvement may change over time.

## 16.2 Reasons for influence

Companies may seek:

- Lower taxes.
- Industry subsidies.
- Favorable regulations.
- Access to government contracts.
- Infrastructure investment.
- Import-policy changes.
- Protection from competition.
- Labor-law changes.
- Environmental-law changes.
- Licensing advantages.
- Public procurement reform.

## 16.3 Influence methods

Possible methods include:

- Public statements.
- Lobbying.
- Industry associations.
- Political donations where legal.
- Advertising.
- Sponsoring research.
- Supporting public campaigns.
- Negotiating with government.
- Funding lawful advocacy groups.
- Using corporate-owned media.
- Illegal bribery or covert influence attempts.

Each method requires appropriate resources and has potential consequences.

## 16.4 Influence budgets

Companies allocate a portion of their resources to political activity.

Lobbying must compete with:

- Investment.
- Wages.
- Maintenance.
- Debt repayment.
- Dividends.
- Other operating expenses.

## 16.5 Influence effectiveness

Influence should not simply purchase political decisions.

Effectiveness depends on:

- Public support.
- Economic importance.
- Company reputation.
- Party policy alignment.
- Relationships.
- Legal restrictions.
- Government transparency.
- Available evidence.
- Political incentives.

## 16.6 Lobbying outcomes

A company may:

- Gain a meeting.
- Persuade a party to consider a policy.
- Help place an issue on the agenda.
- Influence a proposed amendment.
- Fail to influence the government.
- Damage its reputation through aggressive lobbying.

## 16.7 Corruption

Unlawful influence activities should be separate from legitimate lobbying.

Possible misconduct:

- Bribery.
- Procurement fraud.
- Undisclosed conflicts of interest.
- Illegal donations.
- Falsified financial information.
- Coordinated market manipulation.
- Unlawful political pressure.

Corruption creates risks of investigation, prosecution, financial penalties, and political scandal.

---

# 17. Alcohol Industry and Government Monopoly

Alcohol should be a distinct regulated economic sector because it affects production, consumption, health, public opinion, and political choices.

## 17.1 Alcohol products

For the initial version, alcohol can be represented as one commodity category.

A later version may distinguish:

- Beer.
- Wine-like products.
- Distilled alcohol.
- Other locally produced beverages.

The colony's fictional environment allows different raw materials and production traditions.

## 17.2 Alcohol production

Alcohol production requires:

- Suitable agricultural or industrial inputs.
- Water.
- Energy.
- Labor.
- Equipment.
- Production facilities.
- Storage.
- Distribution.

Alcohol is manufactured by businesses or public enterprises.

## 17.3 Regulatory models

The government may adopt different approaches.

### Model A — Government production and retail monopoly

The state controls legal production and retail distribution.

Private producers are excluded unless permitted through specific contracts.

### Model B — Government retail monopoly

Private companies may produce alcohol, but sales to consumers occur through government-authorized retail institutions.

### Model C — Licensed private market

Private producers and retailers may operate under licenses.

The government establishes taxation, safety standards, age restrictions, and distribution rules.

### Model D — Lightly regulated market

Most commercial alcohol activity is permitted with limited intervention.

### Model E — Prohibition

Commercial production and distribution are prohibited or heavily restricted, subject to defined exceptions.

Each model changes the economic incentives and opportunities available to companies.

## 17.4 State alcohol enterprise

Under a monopoly, the government may own a public enterprise responsible for distribution or production.

That enterprise has:

- Managers.
- Employees.
- Facilities.
- Financial accounts.
- Supply contracts.
- Operating costs.
- Stock.
- Service objectives.

It can be well managed or poorly managed.

## 17.5 Private brewing

When legislation permits private production, entrepreneurs may establish breweries.

They assess:

- Consumer demand.
- Startup investment.
- Input costs.
- Competition.
- Licensing.
- Distribution opportunities.
- Expected profitability.

If production is prohibited, potential entrepreneurs may lobby for legal changes.

A subset may attempt unlawful production if the expected rewards outweigh perceived risks.

## 17.6 Illegal production

Illegal production should arise through economic incentives and enforcement conditions.

Potential causes:

- High prices.
- Strong demand.
- Restricted legal supply.
- Weak enforcement.
- High taxation.
- Profitable illegal distribution.

Illegal operations may produce unsafe goods and avoid taxation.

They should carry risks of detection, penalties, seizure, and closure.

## 17.7 Alcohol consumption

Alcohol consumption is simulated by aggregated household groups.

Different groups may have different preferences and consumption patterns.

The simulation should distinguish:

- Abstainers.
- Occasional consumers.
- Moderate consumers.
- Heavy consumers.

These categories represent modeled consumption behavior, not moral judgments about individual citizens.

## 17.8 Consumption influences

Demand can depend on:

- Prices.
- Income.
- Availability.
- Social preferences.
- Cultural trends within the colony.
- Regulations.
- Advertising.
- Previous consumption patterns.

## 17.9 Happiness and recreation

For some population groups, access to recreational alcohol may increase short-term leisure satisfaction.

The effect should depend on preferences and actual consumption.

It must not be assumed that all citizens become happier when alcohol availability increases.

## 17.10 Health consequences

High levels of harmful consumption may increase:

- Healthcare demand.
- Workplace accidents.
- Absenteeism.
- Long-term health problems.
- Household financial strain.
- Public expenditure.

These effects should emerge gradually and be calibrated to plausible relationships.

## 17.11 Alcohol and election turnout

The game may include a mechanism where widespread harmful alcohol consumption reduces election participation.

However, turnout effects should depend on the actual extent of harmful consumption and associated social conditions.

Total alcohol sales alone should not directly produce a large fixed turnout penalty.

Potential pathways include:

- Health problems.
- Social disengagement.
- Reduced mobility.
- Economic hardship.
- Community instability.

For example, a district with persistent harmful consumption and associated social problems may experience lower civic participation over time.

The political simulation converts these conditions into turnout probabilities.

## 17.12 Alcohol and politics

Possible political disagreements:

- Public monopoly versus private competition.
- Taxation.
- Alcohol licensing.
- Advertising restrictions.
- Public health.
- Consumer freedom.
- Illegal production.
- State revenue.
- Corporate influence.

Parties may develop different positions.

An alcohol company may lobby for lower taxation.

A healthcare institution may advocate stronger controls.

A public enterprise may defend its monopoly.

Voters may weigh consumer freedom, public health, economic opportunities, and service quality differently.

---

# 18. Corporate Misconduct and Regulatory Enforcement

Companies should be capable of operating improperly, whether through incompetence, negligence, deliberate misconduct, or weak oversight.

## 18.1 Misconduct categories

Possible behavior:

- Contract fraud.
- Unsafe working conditions.
- Environmental violations.
- False advertising.
- Tax evasion.
- Price manipulation.
- Corruption.
- Illegal production.
- Accounting fraud.
- Unauthorized construction.
- Deliberate breach of regulation.

## 18.2 Causes

Misconduct probabilities depend on:

- Leadership incentives.
- Financial pressure.
- Ethical standards.
- Company culture.
- Compliance systems.
- Expected penalties.
- Enforcement likelihood.
- Opportunities for misconduct.

Poor financial performance does not automatically mean a company acts illegally.

## 18.3 Detection

Misconduct may be identified through:

- Government inspections.
- Whistleblowers.
- Employee complaints.
- Newspaper investigations.
- Competitor reports.
- Financial audits.
- Public complaints.
- Accidents.
- Regulatory monitoring.

Detection is separate from the underlying violation.

A violation can occur without being immediately discovered.

## 18.4 Enforcement

Possible responses:

- Warning.
- Compliance order.
- Fine.
- License suspension.
- License revocation.
- Contract termination.
- Asset seizure where legally justified.
- Criminal investigation.
- Prosecution.
- Dissolution in severe cases.

Legal procedures and available powers depend on the colony's laws.

## 18.5 Regulatory capacity

Government agencies require:

- Funding.
- Workers.
- Qualified leadership.
- Administrative capacity.

Weak oversight may allow violations to persist.

Excessively complicated or poorly designed rules may increase compliance costs without achieving their intended outcomes.

## 18.6 Political consequences

Corporate misconduct can create:

- Public anger.
- Calls for stronger regulation.
- Opposition criticism.
- Government investigations.
- Parliamentary inquiries.
- Coalition disagreements.
- Changes in voter priorities.

---

# 19. Company Reputation

Reputation must be multidimensional.

A single score cannot adequately describe every company.

## 19.1 Reputation categories

Each company may track:

- Product or service quality.
- Contract reliability.
- Financial reliability.
- Employee treatment.
- Environmental responsibility.
- Legal compliance.
- Public trust.
- Management credibility.

## 19.2 Reputation by audience

Different groups may perceive the same company differently.

For example:

A mining company may be popular with employees because it pays high wages, while nearby residents oppose its environmental impact.

Investors may admire its profits.

Government procurement officials may distrust its project scheduling.

The company therefore has separate performance records and audience perceptions.

## 19.3 Reputation development

Reputation changes according to:

- Actual performance.
- Media coverage.
- Public investigations.
- Company communication.
- Management changes.
- Historical experience.
- Significant incidents.

## 19.4 Reputation memory

Reputation changes over time.

Older events gradually lose influence, while severe incidents can remain relevant for years.

Recent performance should matter more when evaluating current reliability.

## 19.5 Leadership reputation

The company's reputation and its CEO's reputation should remain separate.

A respected business may employ an unpopular CEO.

A previously unsuccessful CEO may acquire a well-regarded company.

The interaction between these reputations creates uncertainty for investors, customers, and government contractors.

---

# 20. Company Relationships and Economic Networks

Companies should interact with each other.

## 20.1 Relationship types

- Supplier/customer.
- Contractor/subcontractor.
- Competitor.
- Owner/subsidiary.
- Business partner.
- Creditor/debtor.
- Joint venture.
- Industry association member.

## 20.2 Supply contracts

Companies may establish recurring supply arrangements.

These define:

- Commodity.
- Quantity.
- Price or pricing formula.
- Delivery schedule.
- Duration.
- Payment terms.
- Penalties.
- Termination rules.

## 20.3 Subcontracting

Construction firms may subcontract specialist work.

For example, a large construction company may hire:

- Electrical contractors.
- Logistics providers.
- Engineering firms.
- Material suppliers.

The main contractor remains responsible according to its agreement with the client.

## 20.4 Cascading failures

If a large company becomes insolvent, it can affect:

- Suppliers.
- Subcontractors.
- Workers.
- Government projects.
- Creditors.
- Related industries.

A bankruptcy may create a broader economic shock.

## 20.5 Corporate groups

A parent company may own several subsidiaries.

Subsidiaries can remain distinct legal entities.

Ownership links must not automatically merge their inventories, cash, or contractual responsibilities.

---

# 21. Corporate Sales, Mergers, and Acquisitions

## 21.1 Company sales

An owner may decide to sell a business.

Potential buyers evaluate:

- Assets.
- Profitability.
- Debt.
- Reputation.
- Market share.
- Contracts.
- Facilities.
- Future prospects.

## 21.2 Purchase financing

Acquisitions require actual funding.

Buyers may use:

- Cash.
- Borrowing.
- Share exchange.
- Other legally supported consideration.

## 21.3 Leadership after sale

A new owner may:

- Retain management.
- Replace the CEO.
- Change the board.
- Restructure operations.
- Sell facilities.
- Change investment priorities.
- Change the company's political activity.

## 21.4 Contract continuity

Contracts ordinarily remain attached to the legal entity that signed them unless their terms or applicable law provide otherwise.

A change of ownership should not automatically cancel all contracts.

## 21.5 Merger regulation

Large mergers may require regulatory approval.

The government may evaluate:

- Market concentration.
- Competition.
- Employment.
- Public-service effects.
- National or colony-wide strategic interests.

## 21.6 Privatization and nationalization

Government policy may permit:

- Sale of public enterprises.
- Purchase of private enterprises.
- Public-private partnerships.
- Acquisition of strategic assets.
- Legally authorized nationalization.

These actions require funding, legal authority, and administrative work.

They may produce political conflict.

---

# 22. Corporate AI

Every autonomous company requires decision-making behavior.

The initial implementation should use a utility-based decision model with explicit organizational constraints.

## 22.1 Company objectives

A company evaluates potential actions according to its priorities.

A commercial firm may favor profitability and growth.

A cooperative may value employment stability.

A public enterprise may prioritize service obligations.

A nonprofit may prioritize its mission.

## 22.2 Management modifiers

The company's management influences:

- Decision quality.
- Planning accuracy.
- Risk tolerance.
- Investment choices.
- Operational priorities.

## 22.3 Decision hierarchy

Decisions occur at appropriate organizational levels.

**Operational management:**

- Production.
- Routine purchasing.
- Hiring.
- Pricing.
- Delivery coordination.

**CEO or owner:**

- Expansion.
- Business strategy.
- Major contracts.
- Significant borrowing.
- Market entry.

**Board or controlling owner:**

- CEO replacement.
- Major acquisitions.
- Fundamental restructuring.
- Large investment decisions.
- Company sale.

## 22.4 Decision evaluation

A provisional action utility model:

\[
U(a)=
w_pP(a)+
w_gG(a)+
w_sS(a)+
w_rR(a)+
w_oO(a)
\]

Where:

- \(P(a)\) = expected profitability.
- \(G(a)\) = expected growth benefit.
- \(S(a)\) = organizational stability.
- \(R(a)\) = risk-adjusted outcome.
- \(O(a)\) = owner or institutional objective alignment.

The weights vary by company structure and leadership.

Actions must first pass legal, financial, and operational feasibility checks.

## 22.5 Imperfect information

Corporate AI should not know the exact future.

Managers make decisions using:

- Recent market history.
- Price forecasts.
- Available financial information.
- Known contracts.
- Their own estimates.
- Management competence.

Poor management may generate less accurate forecasts.

## 22.6 AI autonomy

Companies continue making decisions when:

- The player is occupied elsewhere.
- The player enters opposition.
- A new government takes office.
- The player retires and enters observer mode.

---

# 23. Monthly Company Simulation

The company system integrates with the colony's existing monthly economic turn.

## Phase 1 — Apply ownership and leadership changes

Process completed:

- Appointments.
- Resignations.
- Ownership transfers.
- Board changes.
- Acquisitions.
- Corporate restructuring.

## Phase 2 — Company planning

Management evaluates:

- Finances.
- Demand.
- Production.
- Workforce.
- Contracts.
- Regulations.
- Investments.
- Risks.

## Phase 3 — Strategic governance

Companies requiring board or owner approval submit major decisions to the appropriate authority.

Approved decisions enter the company plan.

Rejected or deferred decisions remain unresolved.

## Phase 4 — Production and commercial operations

Companies participate in the shared economy.

They:

- Purchase inputs.
- Allocate labor.
- Produce goods.
- Provide services.
- Deliver shipments.
- Perform contracts.

## Phase 5 — Financial settlement

Update:

- Revenue.
- Wages.
- Operating costs.
- Taxes.
- Debt payments.
- Cash.
- Profit or loss.
- Investment spending.

## Phase 6 — Institutional services

Schools, hospitals, and other organizations deliver services according to:

- Staffing.
- Capacity.
- Funding.
- Inputs.
- Management.

## Phase 7 — Media publication

News organizations select available stories, conduct reporting, and publish monthly editions.

Articles are recorded as information events.

## Phase 8 — Corporate influence and regulation

Process:

- Lobbying.
- Public campaigns.
- Regulatory inspections.
- Compliance.
- Investigations.
- Enforcement actions.

## Phase 9 — Market and public responses

Update:

- Company reputation.
- Customer demand.
- Household trust.
- Media readership.
- Business relationships.
- Political pressure.

## Phase 10 — Strategic events

Evaluate:

- Leadership succession.
- Bankruptcy.
- New business formation.
- Major investment opportunities.
- Company sales.
- Acquisition proposals.
- Corporate scandals.

## Phase 11 — Historical records

Store important:

- Ownership changes.
- Leadership changes.
- Contracts.
- Financial failures.
- Mergers.
- Institutional changes.
- Media controversies.
- Regulatory actions.

---

# 24. User Interface

## 24.1 Company directory

The game should have a company directory.

Companies can be filtered by:

- Industry.
- Ownership type.
- District.
- Size.
- Reputation.
- Financial condition.
- Public or private status.

## 24.2 Company profile

Each company profile displays:

**Overview**
- Name.
- Industry.
- Ownership.
- Management.
- Headquarters.
- Founded date.

**Financial**
- Revenue.
- Costs.
- Profit.
- Cash.
- Debt.
- Assets.

**Operations**
- Facilities.
- Production.
- Workforce.
- Contracts.
- Market share.

**Leadership**
- Owner.
- CEO.
- Board.
- Succession history.

**Reputation**
- Reliability.
- Quality.
- Public trust.
- Compliance history.

**Politics**
- Known political interests.
- Public lobbying.
- Party relationships.
- Political activity.

**History**
- Major events.
- Leadership changes.
- Acquisitions.
- Contracts.
- Failures.

Private information should only be visible when the player has a legitimate way to access it.

## 24.3 Ownership interface

Display ownership shares and control relationships.

For board-governed companies, display board members and their relevant positions.

## 24.4 Company history

A chronological timeline should show major changes.

Example:

- Year 2: Company founded.
- Year 4: First government contract.
- Year 7: Expansion into industrial construction.
- Year 12: Founder retires.
- Year 12: New CEO appointed.
- Year 13: First major contract failure.
- Year 14: Board dismisses CEO.
- Year 15: Company acquired.

## 24.5 Industry overview

The industry screen displays:

- Active companies.
- Market shares.
- Production.
- Prices.
- Employment.
- Imports.
- Regulations.
- Market concentration.

## 24.6 Newspapers

The media menu provides:

- Available publications.
- Latest editions.
- Article reader.
- Previous editions.
- Ownership information.
- Public credibility information.
- Subscription and readership figures.

## 24.7 Regulatory interface

Relevant government departments can inspect:

- Licensed companies.
- Violations.
- Investigations.
- Pending enforcement.
- Monopoly status.
- Compliance records.

## 24.8 Notification system

The player receives important company developments through monthly reporting and newspapers.

Examples:

- Major contractor changes CEO.
- Private school opens.
- Newspaper publishes investigation.
- Large company files for bankruptcy.
- Brewery applies for a license.
- Monopoly operator raises prices.
- Company proposes merger.
- Regulator discovers serious violations.

Not every routine corporate action requires a player notification.

---

# 25. Technical Data Architecture

The system should use stable entities and reusable rules.

## 25.1 Company

```text
Company
    id
    name
    founding_month
    industry_ids[]
    legal_structure
    ownership_structure
    governance_model
    operating_status

    headquarters_district_id

    owner_ids[]
    ownership_stakes[]
    board_member_ids[]
    ceo_id

    cash_account_id
    asset_ids[]
    liability_ids[]
    facility_ids[]
    employee_groups[]
    inventory_ids[]

    contract_ids[]
    supplier_relationships[]
    subsidiary_ids[]

    strategic_priorities[]
    political_interests[]
    political_activity_status

    reputation_profile
    compliance_record

    history[]
```

## 25.2 CorporatePerson

```text
CorporatePerson
    id
    name
    career_stage

    skills{}
    talents[]
    experience{}

    ethics
    risk_tolerance
    strategic_preferences[]

    wealth
    ownership_stakes[]

    management_position_ids[]
    board_position_ids[]

    relationships[]
    career_history[]
```

## 25.3 OwnershipStake

```text
OwnershipStake
    company_id
    owner_entity_id

    ownership_percentage
    voting_percentage
    share_class

    acquisition_month
    transfer_restrictions[]
```

## 25.4 Board

```text
Board
    id
    company_id

    member_ids[]
    chair_id

    voting_rules
    decision_authority[]
    meeting_schedule

    pending_decisions[]
    decision_history[]
```

## 25.5 CorporateDecision

```text
CorporateDecision
    id
    company_id

    proposed_by_id
    decision_type

    options[]
    expected_outcomes[]
    required_authority

    decision_status
    votes[]
    selected_option

    effective_month
    history[]
```

## 25.6 Institution

```text
Institution
    id
    organization_id

    institution_type
    ownership_model
    operator_id

    facility_ids[]
    staffing_requirements
    service_capacity
    service_quality

    funding_sources[]
    fees

    regulatory_status
    service_district_ids[]

    operational_history[]
```

## 25.7 Newspaper

```text
Newspaper
    id
    company_id

    publication_name
    editor_id

    editorial_priorities[]
    journalistic_capacity
    editorial_independence
    accuracy_record
    correction_record

    readership_groups[]
    circulation
    subscription_price
    advertising_revenue

    edition_ids[]
```

## 25.8 NewsArticle

```text
NewsArticle
    id
    newspaper_id
    publication_month

    headline
    article_type
    author_id
    body

    referenced_event_ids[]
    factual_claims[]
    editorial_framing

    source_quality
    accuracy_status
    correction_status

    readership
    credibility_effects[]
```

## 25.9 CorporateInfluenceAction

```text
CorporateInfluenceAction
    id
    company_id

    action_type
    target_entity_id
    target_policy_id

    resources_spent
    legality_status

    expected_effect
    actual_result

    detection_status
    reputation_effects[]
```

## 25.10 RegulatoryCase

```text
RegulatoryCase
    id
    target_company_id
    regulator_id

    alleged_violation
    underlying_event_ids[]
    evidence[]

    investigation_status
    legal_status

    findings[]
    penalties[]
    appeal_status

    history[]
```

## 25.11 CorporateEvent

```text
CorporateEvent
    id
    month

    company_ids[]
    person_ids[]

    event_type
    factual_outcome

    economic_effects[]
    legal_effects[]
    reputation_effects[]

    public_visibility
    related_article_ids[]
```

---

# 26. Data Integrity and Simulation Rules

The implementation must enforce the following.

1. Every company has a unique persistent ID.
2. Company identity remains stable across leadership and ownership changes unless the legal entity is dissolved or merged.
3. Ownership and management are stored separately.
4. Ownership percentages and voting rights follow the applicable governance structure.
5. Company assets cannot simultaneously be owned by unrelated entities without a defined joint-ownership arrangement.
6. Financial transactions must balance.
7. Production requires actual inputs.
8. Company investment requires funding.
9. Managers cannot exercise authority they do not possess.
10. Board-governed decisions follow board rules.
11. Ownership changes do not automatically terminate existing contracts.
12. Company bankruptcy does not delete physical assets.
13. Institutional service provision depends on actual operating capacity.
14. Public funding does not automatically imply public ownership.
15. Newspapers report on persistent simulation events.
16. Newspaper claims are separate from underlying facts.
17. Editorial bias and factual dishonesty are separate attributes.
18. Investigations require resources and evidence.
19. Corporate political activity follows applicable law and resource constraints.
20. Regulatory violations can exist before detection.
21. Penalties require the appropriate legal process.
22. Alcohol production and sales must respect applicable regulations or be classified as unlawful activity.
23. Household alcohol consumption must be recorded separately from production and sales.
24. Political effects depend on actual economic and social conditions rather than arbitrary direct voting modifiers.
25. Government transitions do not reset companies.
26. AI-controlled governments and companies operate through the same underlying rules as player-managed entities.
27. Company histories remain available after acquisition, restructuring, and leadership succession.
28. Save files preserve ownership, management, board decisions, investigations, media archives, and pending corporate actions.

---

# 27. Development Roadmap

## Phase C1 — Company Foundation

**Objective:** Establish companies as persistent independent organizations.

Development tasks:

- Implement Company entity.
- Add company IDs.
- Add founding dates.
- Add industry categories.
- Add operating status.
- Link companies to facilities.
- Link companies to inventories.
- Link companies to employment.
- Connect company accounts to the economy.
- Implement company creation and dissolution.
- Implement save/load.

**Completion criteria:** Companies can exist, own assets, hire workers, and operate across monthly turns without direct player management.

## Phase C2 — Company Types and Ownership

**Objective:** Support different business structures.

Development tasks:

- Implement private owner-operated businesses.
- Implement CEO-managed businesses.
- Implement board-governed corporations.
- Implement public enterprises.
- Implement cooperatives.
- Implement nonprofit organizations.
- Add mixed ownership.
- Implement ownership records.
- Separate financial ownership from governance control.
- Add institutional ownership.

**Completion criteria:** Different company structures use the same economic engine but follow distinct governance rules.

## Phase C3 — Corporate Leaders

**Objective:** Give companies meaningful individual leadership.

Development tasks:

- Implement CorporatePerson.
- Add leadership skills.
- Add talents.
- Add management styles.
- Add risk tolerance.
- Add strategic priorities.
- Add personal experience.
- Implement management appointments.
- Connect management competence to company decisions.
- Add leadership history.

**Completion criteria:** Different managers make meaningfully different business decisions under similar economic conditions.

## Phase C4 — Boards and Corporate Decisions

**Objective:** Implement internal corporate governance.

Development tasks:

- Implement boards.
- Add board members.
- Add decision authority.
- Add major corporate proposals.
- Add board voting.
- Implement CEO appointments and dismissals.
- Add strategic disagreements.
- Add company restructuring decisions.
- Add board decision history.

**Completion criteria:** Board-governed companies can approve or reject major decisions and replace management.

## Phase C5 — Corporate AI

**Objective:** Make companies economically autonomous.

Development tasks:

- Add production planning.
- Add hiring decisions.
- Add wage adjustments.
- Add pricing decisions.
- Add supplier selection.
- Add investment decisions.
- Add contract bidding.
- Add financial distress behavior.
- Add expansion and contraction.
- Add management decision modifiers.
- Add market forecasting.

**Completion criteria:** Companies can operate and adapt over many years without the player directing ordinary commercial decisions.

## Phase C6 — Company Formation and Competition

**Objective:** Make the economy develop independently.

Development tasks:

- Add entrepreneur generation.
- Add startup opportunity evaluation.
- Add startup financing.
- Add market entry.
- Add competition.
- Add market-share calculations.
- Add monopoly detection.
- Add market concentration.
- Add company closures.
- Add industry development.

**Completion criteria:** New firms emerge in response to economic opportunities, and competition changes prices and market shares.

## Phase C7 — Succession and Ownership Changes

**Objective:** Support corporate history and leadership turnover.

Development tasks:

- Implement owner retirement.
- Implement inheritance.
- Implement CEO resignation.
- Implement CEO replacement.
- Add succession planning.
- Add family succession.
- Implement company sale.
- Implement mergers.
- Implement acquisitions.
- Preserve contracts and assets.
- Update ownership records.
- Add succession event history.

**Completion criteria:** A respected company can survive its founder, change management, improve, decline, or be sold without losing its historical identity.

## Phase C8 — Institutions

**Objective:** Represent public and private service providers.

Development tasks:

- Implement Institution.
- Add schools.
- Add hospitals.
- Add service capacity.
- Add staffing.
- Add operating costs.
- Add private providers.
- Add nonprofit providers.
- Add government institutions.
- Add service quality.
- Add public funding arrangements.
- Connect services to population outcomes.

**Completion criteria:** Public and private institutions provide measurable services using actual economic resources.

## Phase C9 — Education

**Objective:** Connect education to long-term economic development.

Development tasks:

- Add school enrollment.
- Add teacher requirements.
- Add school quality.
- Add public school funding.
- Add private school formation.
- Add tuition and financial models.
- Add inspection and licensing.
- Add educational outcomes.
- Connect education to workforce skill development.
- Connect education conditions to political pressure.

**Completion criteria:** Educational investment affects workforce capability and social conditions over multiple years.

## Phase C10 — Media and Newspapers

**Objective:** Create readable autonomous news organizations.

Development tasks:

- Implement Newspaper.
- Implement NewsArticle.
- Add monthly editions.
- Add article categories.
- Add editorial priorities.
- Add reporting resources.
- Add factual claim records.
- Add accuracy and credibility.
- Add corrections.
- Add investigative journalism.
- Add readership.
- Add newspaper finances.
- Add ownership influence.
- Build newspaper-reading interface.
- Add newspaper archives.

**Completion criteria:** Multiple newspapers can publish different accounts of the same simulated event, and their credibility changes according to actual reporting behavior.

## Phase C11 — Political Influence

**Objective:** Give companies political interests and influence options.

Development tasks:

- Add corporate political priorities.
- Add politically inactive companies.
- Add lobbying actions.
- Add influence budgets.
- Add industry associations.
- Add public advocacy.
- Add lawful political contributions.
- Add corporate political advertising.
- Connect influence to party agendas.
- Add reputation consequences.
- Add legal restrictions.

**Completion criteria:** Companies can attempt to influence policy, but political results remain dependent on actual institutions, public support, and government decisions.

## Phase C12 — Alcohol Sector

**Objective:** Implement a politically consequential regulated industry.

Development tasks:

- Add alcohol commodity.
- Add production recipes.
- Add breweries.
- Add alcohol retail.
- Add government monopoly structures.
- Add licensing.
- Add taxation.
- Add private-market alternatives.
- Add legal and illegal production.
- Add household consumption patterns.
- Add leisure satisfaction.
- Add harmful-consumption consequences.
- Connect harmful consumption to public health.
- Connect social consequences to political participation.
- Add political lobbying over alcohol policy.

**Completion criteria:** Different regulatory models produce distinct economic, public-health, commercial, and political outcomes.

## Phase C13 — Misconduct and Enforcement

**Objective:** Support unlawful and negligent company behavior.

Development tasks:

- Add compliance rules.
- Add violations.
- Add detection probabilities.
- Add inspections.
- Add investigations.
- Add evidence records.
- Add whistleblower events.
- Add media investigations.
- Add enforcement procedures.
- Add penalties.
- Add licensing sanctions.
- Add appeals where applicable.
- Add public and political responses.

**Completion criteria:** Companies can violate rules, violations may be discovered, and enforcement follows legal and administrative procedures.

## Phase C14 — Corporate Relationships and Failures

**Objective:** Simulate connected businesses.

Development tasks:

- Add supplier relationships.
- Add recurring contracts.
- Add subcontracting.
- Add ownership groups.
- Add business debt relationships.
- Add insolvency.
- Add asset sales.
- Add company restructuring.
- Add cascading business failures.
- Add acquisition of distressed companies.

**Completion criteria:** Failure of a major company creates traceable effects on employees, suppliers, government projects, and other businesses.

## Phase C15 — Government Integration

**Objective:** Connect corporations to political decision-making.

Development tasks:

- Add government licensing powers.
- Add procurement regulation.
- Add monopoly policy.
- Add public enterprise management.
- Add privatization.
- Add government acquisitions.
- Add regulatory staffing requirements.
- Add political authorization requirements.
- Add parliamentary oversight.
- Add government response to corporate misconduct.
- Connect company conditions to voter concerns.

**Completion criteria:** Government policy can change the business environment, but companies remain economically and legally distinct organizations.

## Phase C16 — UI and Historical Integration

**Objective:** Make company activity understandable.

Development tasks:

- Build company directory.
- Build company profiles.
- Add owner and board screens.
- Add corporate history.
- Build industry statistics.
- Add competition overview.
- Add newspaper interface.
- Add regulatory case interface.
- Add ownership-change notifications.
- Add historical comparison tools.

**Completion criteria:** The player can understand why a company is successful, failing, politically active, or under investigation.

## Phase C17 — Balancing and Long-Term Testing

**Objective:** Ensure sustainable autonomous behavior.

Development tasks:

- Balance company formation.
- Balance failure rates.
- Balance market concentration.
- Balance executive competence.
- Balance board decision-making.
- Test succession outcomes.
- Balance political lobbying.
- Balance public and private service provision.
- Test newspaper credibility.
- Test media influence.
- Test alcohol-policy consequences.
- Test corruption and enforcement.
- Test acquisitions and mergers.
- Optimize monthly decision calculations.
- Run multidecade AI simulations.

**Completion criteria:** The system supports a varied company ecosystem over decades without repetitive, contradictory, or economically impossible outcomes.

---

# 28. Testing Scenarios

## Test 1 — Independent company operations

Create several private companies.

Advance twelve months without interacting with them.

Expected result: Companies continue hiring, producing, selling, and managing finances.

## Test 2 — Board disagreement

Create a corporation whose board disagrees over expansion.

Expected result: The decision follows established voting rules and produces the appropriate outcome.

## Test 3 — CEO replacement

Replace a poorly performing CEO.

Expected result: Existing facilities, workers, contracts, and company reputation remain, while future management behavior can change.

## Test 4 — Incompetent heir

Transfer a successful construction company to an inexperienced successor.

Expected result: The successor's decisions can damage performance, but the company's assets and historical reputation remain.

## Test 5 — Professional management

Have the inexperienced heir appoint a capable CEO.

Expected result: Professional management can mitigate the owner's lack of operational expertise, subject to the authority granted.

## Test 6 — Private school formation

Create demand for additional education.

Allow private education providers.

Expected result: An eligible entrepreneur may establish a school if conditions make the investment viable.

## Test 7 — Public-private school competition

Operate public and private schools in one district.

Expected result: Enrollment, funding, quality, capacity, and accessibility determine service outcomes.

## Test 8 — Accurate newspaper

Create a documented construction failure.

Expected result: A newspaper can accurately report the event.

## Test 9 — Biased but truthful newspaper

Give two papers different editorial priorities.

Expected result: They can emphasize different aspects of the same event while remaining factually accurate.

## Test 10 — Dishonest newspaper

Have a publication knowingly publish a false claim.

Expected result: The claim is recorded separately from the underlying facts and may later be investigated or corrected.

## Test 11 — Media acquisition

Allow an industrial company to acquire a newspaper.

Expected result: Ownership changes, but editorial influence depends on governance arrangements and leadership choices.

## Test 12 — Corporate lobbying

Have a company lobby for lower industry taxes.

Expected result: The company spends resources attempting influence, while political support remains dependent on parties and legislation.

## Test 13 — Alcohol monopoly

Create a government retail monopoly.

Expected result: Legal retail sales occur through the authorized public operator, subject to the monopoly rules.

## Test 14 — Private brewing

Legalize licensed private brewing.

Expected result: Entrepreneurs may establish breweries and compete within the permitted market.

## Test 15 — Alcohol prohibition

Restrict legal alcohol sales while maintaining demand.

Expected result: Legal supply declines, and illegal supply may emerge if economic incentives and enforcement conditions permit.

## Test 16 — Harmful consumption

Create a sustained increase in harmful alcohol consumption.

Expected result: Relevant healthcare, household, employment, and civic-participation effects develop through explicit causal mechanisms rather than arbitrary instant penalties.

## Test 17 — Regulatory violation

Create a company that violates safety regulations.

Expected result: The violation exists independently of whether it is detected.

## Test 18 — Investigation

Provide a regulator with adequate resources and evidence.

Expected result: The regulator may identify the violation and initiate appropriate enforcement.

## Test 19 — Company sale

Sell a company to another owner.

Expected result: Ownership and applicable control rights change while contracts, assets, and company history remain accounted for.

## Test 20 — Merger

Merge two companies.

Expected result: Ownership, assets, obligations, and competition effects follow the applicable merger rules.

## Test 21 — Bankruptcy

Make a major construction contractor insolvent.

Expected result: Contracts may be interrupted, workers are affected, and physical assets remain available for liquidation or transfer.

## Test 22 — Government transition

Replace the governing coalition.

Expected result: Private companies continue operating, while government regulation and public-enterprise priorities may change.

## Test 23 — Opposition

Move the player into opposition.

Expected result: Companies, newspapers, and institutions continue operating independently under AI government.

## Test 24 — Save and load

Save during an ownership transfer, ongoing investigation, newspaper controversy, and corporate merger negotiation.

Expected result: All records and pending decisions are restored correctly.

## Test 25 — Long-term simulation

Run the colony for 30 simulated years.

Expected result:

- Businesses form and disappear.
- Leadership changes occur.
- Corporate histories persist.
- Companies experience varied levels of success.
- Market concentration changes.
- Public and private institutions continue operating.
- Newspapers produce historical records.
- Regulatory systems remain functional.
- Economic resources and financial accounts remain consistent.
- Corporate AI avoids impossible actions.

---

# 29. Minimum Complete Playable Company System

The first fully playable version must include:

1. Independent companies with persistent identities.
2. Different company ownership structures.
3. Individual company owners and managers.
4. CEO-managed companies.
5. Board-governed companies.
6. Public enterprises.
7. Nonprofit and cooperative organizations.
8. Company finances and assets.
9. Autonomous production and hiring.
10. Market competition.
11. Contractor bidding.
12. Corporate reputation.
13. Leadership replacement.
14. Ownership transfers and company sales.
15. Basic company inheritance.
16. Company formation.
17. Bankruptcy.
18. Public and private institutions.
19. Public and private schools.
20. News organizations.
21. Readable monthly newspaper editions.
22. Accurate, biased, mistaken, and dishonest reporting.
23. Corporate political activity and lobbying.
24. Companies choosing not to participate in politics.
25. Public monopoly and licensed private-market structures.
26. Alcohol production and consumption.
27. Alcohol-related social and health consequences.
28. Corporate misconduct and regulatory enforcement.
29. Company profiles and historical records.
30. Integration with elections and government.
31. Continued autonomous operation during opposition.
32. Save and load support.

More elaborate stock markets, individual shareholder trading, extensive personality relationships, and highly detailed criminal justice procedures can be added after the core system is functional.

---

# 30. Outstanding Design Decisions

The following decisions must be finalized before implementing the corresponding systems.

| Area | Open decision | Proposed initial approach |
|---|---|---|
| Corporate leaders | Number of individually simulated people | Owners, CEOs, and significant board members |
| Board size | Number of directors | 3–7 |
| Board voting | Voting thresholds | Ordinary majority, configurable exceptions |
| Leadership changes | Frequency | Event-driven and performance-driven |
| Inheritance | Succession rules | Simplified legal succession |
| Shareholding | Stock-market detail | Simplified ownership transactions |
| Corporate investments | Risk evaluation | Utility-based AI |
| Company formation | Startup frequency | Based on market opportunities |
| Market concentration | Regulatory thresholds | Configurable by sector |
| Public enterprises | Government control | Strategic authority with delegated management |
| Private schools | Funding model | Determined by legislation |
| School outcomes | Education progression | Multiyear cohort-based effects |
| Newspapers | Articles per monthly edition | 3–7 initially |
| Media truthfulness | Accuracy and dishonesty model | Claims grounded in recorded events |
| Media ownership | Editorial independence | Organization-specific governance setting |
| Corporate lobbying | Allowed activities | Determined by current law |
| Corruption | Detection and enforcement | Evidence-based events with uncertainty |
| Alcohol | Starting legal framework | Scenario-dependent |
| Alcohol consumption | Household distribution | Aggregated preference and consumption groups |
| Alcohol and turnout | Magnitude of effect | Indirect, bounded, evidence-calibrated |
| Regulatory agencies | Staffing requirements | Linked to government administration |
| Corporate acquisitions | Approval procedure | Ownership and competition checks |
| AI complexity | Decision algorithm | Utility-based with imperfect information |
| Historical records | Retention | Permanent major events, compressed routine records |

These items remain explicit balancing and implementation decisions. They are not to be silently assumed during coding.

---

# 31. Complete Gameplay Acceptance Scenario

The following scenario tests the system as a whole.

## Years 1–4: Early settlement

The player lands on the planet and begins establishing the colony.

The original expedition includes several companies.

One construction firm is privately owned by an experienced engineer.

Another is controlled by a group of investors.

A third is a worker cooperative.

The government owns the initial power and water infrastructure.

Public schools are established to serve the expanding population.

The player awards construction contracts based on price, reliability, logistical access, and available resources.

Private companies begin expanding as new market opportunities appear.

Some companies become politically active.

Others remain focused entirely on commercial operations.

## Years 5–8: Corporate expansion

After the first election, a coalition government forms.

The colony's economy grows.

Private entrepreneurs establish new businesses.

A private school company opens its first institution.

The government must decide what regulatory and funding arrangements apply.

Meanwhile, one construction company becomes a dominant supplier.

Its owner begins lobbying against new competition rules.

A newspaper investigates whether the company's government contracts were awarded fairly.

The newspaper's report may be accurate, incomplete, or mistaken depending on its information and editorial behavior.

The government must respond through the appropriate institutions.

## Years 9–12: Leadership succession

The colony's most respected construction contractor changes ownership.

Its founder retires and transfers the company to a family member.

The new owner appoints himself CEO despite limited management experience.

Initially, the company continues operating successfully because it retains experienced workers, equipment, contracts, and suppliers.

Over subsequent months, management begins accepting overly ambitious projects.

Financial reserves decline.

Maintenance is neglected.

Construction delays become more frequent.

Company reputation begins to deteriorate.

The player must reconsider whether to award the company further public contracts.

The owner's board or other shareholders may attempt to replace the CEO if the governance structure permits.

Alternatively, the company may be sold to new investors.

## Years 13–16: Alcohol policy conflict

The colony's population has grown significantly.

Demand for recreational alcohol increases.

The government operates a public alcohol retail monopoly.

Several entrepreneurs want to establish private breweries and retail businesses.

The existing monopoly operator argues that the current system provides stable control and public revenue.

Business organizations argue for competition.

Public-health institutions raise concerns about harmful consumption.

Political parties develop different proposals.

The player may support:

- Maintaining the monopoly.
- Allowing private production under government retail.
- Introducing licensed private retail.
- Increasing taxation.
- Strengthening public-health interventions.
- Restricting alcohol advertising.

The resulting legislation affects company formation, production, government revenue, prices, household consumption, and public health.

Over subsequent years, consumption patterns may influence social conditions and, indirectly, electoral participation.

## Years 17–20: Media ownership and political influence

A large industrial corporation purchases a financially struggling newspaper.

The new owner appoints a different editor.

The publication begins giving more attention to industrial development and less attention to environmental complaints.

If its reporting remains accurate, the newspaper may simply have a different editorial perspective.

If its management begins deliberately suppressing facts or publishing false claims, it risks reputational and legal consequences.

Competing newspapers may investigate its coverage and ownership.

The player must decide how to respond politically while respecting whatever press-freedom and media-regulation framework the colony has established.

## Years 21–24: Political defeat

The player loses an election.

An opposing coalition forms a government.

The new government changes corporate tax policy, privatizes a public enterprise, and adjusts education regulation.

Private companies respond to the new conditions.

Newspapers cover the changes.

Company boards evaluate new investments.

Some existing businesses prosper.

Others struggle.

The player continues as opposition leader, using parliamentary oversight, political negotiations, and public information to challenge or support government policies.

The corporate economy continues functioning independently.

## Years 25–28: Return to power

The player's party wins enough support to participate in a new government.

The player inherits an economy transformed by the previous administration.

Some former contractors have disappeared.

Other companies have grown.

New institutions exist.

Major companies have changed ownership.

Experienced founders have retired.

Media organizations have developed different reputations.

The player must govern the economy that now exists rather than the economy they originally created.

---

# 32. Final System Acceptance Criteria

The companies and institutions system is complete when:

- Companies operate independently of direct player control.
- Different ownership structures meaningfully affect decision-making.
- Owners, boards, and CEOs have distinct authority.
- Corporate leaders have individual skills, talents, and priorities.
- Management competence affects actual business decisions.
- Companies can change leadership without losing their assets or histories.
- Inheritance and family succession can change corporate performance.
- Company sales and mergers preserve legal and economic continuity.
- Entrepreneurs can create businesses in response to market opportunities.
- Companies can grow, contract, fail, or be acquired.
- Public and private enterprises function within the same economy.
- Public and private institutions can coexist.
- Schools affect workforce development and social conditions.
- Media organizations publish readable news based on simulated events.
- Newspapers can be accurate, biased, mistaken, or deliberately dishonest.
- Media ownership and leadership can influence editorial behavior.
- Media credibility responds to reporting accuracy and correction practices.
- Companies can lobby, remain politically inactive, or pursue unlawful influence.
- Political influence does not automatically guarantee favorable government decisions.
- Monopoly structures affect competition and economic behavior.
- Alcohol policy can support public monopolies, private markets, licensing, or prohibition.
- Alcohol production and consumption affect the economy, public health, and relevant social conditions.
- Harmful consumption can indirectly affect civic participation under defined simulation rules.
- Regulatory violations can occur and be investigated.
- Companies remain subject to financial, logistical, labor, and resource constraints.
- Corporate events generate political and economic consequences.
- AI governments and private companies use consistent underlying rules.
- Company histories persist across elections and changes of government.
- The player can observe corporate developments while in opposition.
- The system continues operating after player retirement.
- Long-running campaigns remain economically and technically consistent.

**Final design principle:** Companies are independent participants in the colony's history, not passive tools of the player. Their owners, managers, employees, products, institutions, political interests, successes, and failures should change society over time. The player can regulate, contract with, support, investigate, compete with, or sometimes own these organizations, but cannot simply dictate the behavior of every business in the colony.
