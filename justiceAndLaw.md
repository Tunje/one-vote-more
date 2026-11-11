# Political Colony Simulator
# Law, Rights, Justice & Constitutional Government
## Complete Game Design and Development Specification

**Version:** 0.7  
**Status:** Detailed development plan  
**Simulation interval:** Monthly turns  
**Government model:** Multiparty parliamentary democracy inspired by Sweden  
**Parliament:** 151 seats  
**Absolute majority:** 76 seats  
**Related systems:** Parliament, legislation, government, personnel, economy, companies, institutions, population, elections, media, projects, opposition, events

---

# 1. System Overview

The Law, Rights & Justice system determines what actions are legally permitted, which institutions possess authority, how disputes are resolved, and what happens when individuals, companies, or the government violate the law.

The colony begins under the authority of a settlement commander.

During its first four years, the commander possesses broad executive powers necessary to establish the settlement, develop institutions, and respond to emergencies.

However, this authority should not be unlimited or entirely arbitrary.

As the colony develops, formal laws, legal institutions, and constitutional protections become established.

Following the first parliamentary election, political authority is exercised through a democratic government subject to legislation, constitutional limitations, independent courts, and administrative oversight.

The legal system must continue functioning regardless of which political party controls government.

It must also support the possibility that laws are poorly designed, institutions are underfunded, officials are incompetent, companies violate regulations, political leaders abuse authority, and citizens challenge government decisions.

**The central design principle is that political power, legal authority, and practical enforcement capacity are three different things.**

A government may possess the parliamentary votes to pass legislation but lack the constitutional authority to enact it.

A law may be valid but difficult to enforce.

A company may violate a regulation without immediately being discovered.

A court may issue a legally binding judgment that the government finds politically inconvenient.

These distinctions create the gameplay.

---

# 2. Primary Design Objectives

The system must:

1. Establish a coherent legal framework for the colony.
2. Define the legal authority of the founding commander.
3. Support a transition from command administration to parliamentary government.
4. Establish constitutional rights and limitations on government power.
5. Allow legislation to create, amend, and repeal laws.
6. Prevent contradictory laws from being applied without defined conflict-resolution rules.
7. Support independent courts and judicial review.
8. Establish civil, criminal, administrative, commercial, and constitutional legal procedures.
9. Permit citizens and organizations to challenge government actions.
10. Permit companies to sue, be sued, and face regulatory enforcement.
11. Model law enforcement and investigative capacity.
12. Support corruption, misconduct, investigations, and prosecution.
13. Preserve due process and legal protections.
14. Allow different political parties to pursue different legal policies.
15. Distinguish legal outcomes from public perceptions of justice.
16. Make court and enforcement capacity depend on actual resources.
17. Allow laws to produce unintended economic and social consequences.
18. Support legally authorized emergency powers.
19. Preserve legal institutions and court records across elections.
20. Integrate with the same AI and simulation rules used by player and opposition governments.

---

# 3. Legal Development During the Founding Period

## 3.1 Initial expedition charter

The colony begins with an expedition charter issued by the organization or civilization responsible for establishing the settlement.

This charter provides the legal basis for the commander's initial authority.

The charter defines:

- The commander's executive responsibilities.
- The administration's ownership of expedition assets.
- Initial emergency powers.
- Basic protections for settlers.
- Authority to establish public institutions.
- Authority to enter construction and supply contracts.
- Rules governing private companies.
- Basic dispute-resolution procedures.
- The timetable or conditions for democratic transition.

This avoids treating the colony as completely lawless during the founding period.

## 3.2 Founding commander's powers

During Years 1–4, the commander can generally:

- Designate development districts.
- Authorize ordinary construction.
- Establish public facilities.
- Award contracts.
- Manage expedition resources.
- Establish administrative departments.
- Introduce provisional regulations.
- Create initial law enforcement and judicial institutions.
- Respond to emergencies.
- Organize the first parliamentary election.

The commander remains subject to the expedition charter and any foundational rights protected by it.

## 3.3 Provisional laws

During the founding period, the commander may introduce provisional rules governing:

- Land allocation.
- Construction safety.
- Employment.
- Business licensing.
- Resource extraction.
- Public health.
- Trade.
- Environmental protection.
- Public order.
- Government procurement.

These rules are recorded in a provisional legal register.

## 3.4 Democratic transition

At the first election, parliamentary government replaces the commander's extraordinary founding authority.

Provisional rules must have a defined legal status.

Recommended approach:

- Ordinary provisional regulations continue temporarily unless revoked or superseded.
- Founding emergency powers expire.
- The new parliament gains ordinary legislative authority.
- The new government inherits existing contracts and legal obligations.
- The constitutional framework becomes fully operational.
- Independent courts continue operating.

This prevents an unrealistic situation in which all founding regulations disappear overnight.

## 3.5 Founding constitutional decisions

During the founding period, the player may participate in establishing certain institutional arrangements.

These may include:

- Court organization.
- Local government powers.
- Administrative oversight.
- Public access to government information.
- Legislative procedures.
- Regulatory institutions.

Fundamental protections should already exist under the expedition charter so that the founding commander cannot simply abolish every right.

Major constitutional choices can later be amended through appropriately demanding parliamentary procedures.

---

# 4. Hierarchy of Laws

The game requires a clear legal hierarchy.

Proposed hierarchy:

| Level | Legal instrument | Authority |
|---|---|---|
| 1 | Foundational charter or constitution | Supreme legal authority |
| 2 | Constitutional legislation | Rules governing institutions and protected rights |
| 3 | Ordinary legislation | Laws passed by parliament |
| 4 | Government regulations | Rules made under statutory authorization |
| 5 | Administrative decisions | Decisions by authorities acting under law |
| 6 | Private agreements | Contracts between legally recognized parties |

A lower-level instrument cannot lawfully override a superior legal instrument.

## 4.1 Constitutional supremacy

The constitution determines:

- Government structure.
- Parliamentary authority.
- Executive powers.
- Judicial authority.
- Basic rights.
- Legislative procedures.
- Legal limits on public institutions.

## 4.2 Ordinary legislation

Parliament passes laws governing areas such as:

- Taxation.
- Employment.
- Education.
- Healthcare.
- Business regulation.
- Criminal offenses.
- Environmental protection.
- Alcohol production and distribution.
- Property.
- Public expenditure.
- Trade.

## 4.3 Government regulations

Government departments may issue regulations only where legislation grants authority.

For example, parliament may establish a mining safety law while authorizing a regulatory agency to determine detailed technical standards.

## 4.4 Administrative decisions

Government institutions may issue individual decisions.

Examples:

- Approving a business license.
- Rejecting a construction permit.
- Issuing a safety order.
- Approving a school.
- Assessing a tax obligation.
- Suspending an operating license.

These decisions must comply with applicable law.

## 4.5 Contracts

Contracts create obligations between parties but cannot authorize conduct prohibited by higher law.

## 4.6 Conflicting rules

Every legal rule should have:

- A defined scope.
- Effective date.
- Legal authority.
- Applicable entities.
- Conditions.
- Legal effect.
- Amendment history.
- Repeal status.

When rules conflict, the simulation should apply hierarchy, specificity, effective dates, and explicit supersession rules.

Unresolved constitutional conflicts may require judicial review.

---

# 5. Constitutional Rights

The constitution establishes protected rights that constrain government action.

The initial model should include the following.

| Right | Gameplay relevance |
|---|---|
| Equality before the law | Limits arbitrary discrimination by public institutions |
| Freedom of expression | Protects lawful political and public speech |
| Freedom of the press | Protects independent news reporting |
| Freedom of association | Allows parties, unions, and organizations to form |
| Political participation | Protects voting and democratic participation |
| Due process | Requires lawful procedures before penalties |
| Property rights | Protects ownership subject to lawful regulation |
| Privacy | Limits arbitrary surveillance and information collection |
| Freedom of assembly | Protects lawful demonstrations |
| Access to justice | Allows legal challenges and dispute resolution |
| Labor protections | Establishes foundational employment safeguards |
| Protection against arbitrary detention | Limits law enforcement power |

## 5.1 Rights are not all absolute

Some rights can be subject to lawful, proportionate limitations.

For example:

- Dangerous industrial activity may be regulated.
- Private property may be acquired for public infrastructure under defined legal procedures.
- Certain confidential information may be protected.
- Public gatherings may be subject to narrowly defined safety requirements.

Restrictions must have a legal basis.

## 5.2 Constitutional review

Courts may evaluate whether legislation or government action conflicts with constitutional protections.

A court may:

- Uphold the challenged action.
- Interpret a law narrowly.
- Refuse to apply an unconstitutional provision in a particular case.
- Invalidate a specific administrative decision.
- Require reconsideration.
- Award an available legal remedy.

The exact scope of judicial review must be established through the constitutional rules.

## 5.3 Constitutional amendments

Constitutional amendments require a more demanding procedure than ordinary legislation.

A proposed model inspired by Swedish constitutional procedure is approval by two successive parliaments with an election between them.

The game should specify any additional voting requirements or exceptions.

This allows constitutional reform while preventing a temporary parliamentary majority from instantly rewriting every foundational protection.

## 5.4 Political consequences

Rights disputes may create:

- Court cases.
- Parliamentary conflicts.
- Media investigations.
- Public protests.
- Party disagreements.
- Changes in political trust.

The simulation should distinguish public approval of a measure from its legal validity.

---

# 6. Court System

Courts must be institutions with capacity, personnel, budgets, independence, and persistent case records.

## 6.1 Proposed court structure

For the initial implementation, use three judicial branches or functions.

**General courts**

Handle criminal cases and ordinary civil disputes.

**Administrative courts**

Handle challenges to government and regulatory decisions.

**Higher appellate and constitutional review**

Handle appeals and important constitutional questions.

The physical court network may be expanded as the colony grows.

## 6.2 Court attributes

Every court tracks:

- Jurisdiction.
- Geographic coverage.
- Judges.
- Administrative employees.
- Budget.
- Operating capacity.
- Pending cases.
- Average processing time.
- Case backlog.
- Institutional independence.
- Professional competence.
- Public confidence.

## 6.3 Judicial independence

Judges should not be ordinary political staff assigned by the player each month.

Judicial appointments and removal must follow the relevant legal procedures.

The government may influence court capacity through lawful funding and institutional reforms.

It should not be able to directly command a judge to deliver a preferred ruling.

## 6.4 Court capacity

Court capacity depends on:

- Number of qualified judges.
- Administrative staffing.
- Facilities.
- Available funding.
- Case complexity.
- Existing backlog.

A severe case backlog increases the time required for disputes to be resolved.

## 6.5 Judicial skill

Individually modeled senior judges may have:

- Legal knowledge.
- Experience.
- Case-management ability.
- Reliability.
- Integrity.
- Specialization.

Ordinary judges can be represented through aggregated personnel pools.

## 6.6 Case assignment

Cases are assigned according to:

- Jurisdiction.
- Location.
- Case type.
- Judicial capacity.
- Procedural rules.

The player cannot personally choose the judge for a case merely because the outcome matters politically.

---

# 7. Legal Cases

A legal case is a persistent entity.

## 7.1 Case categories

The initial system should support:

- Civil disputes.
- Criminal prosecution.
- Administrative appeals.
- Commercial disputes.
- Employment disputes.
- Regulatory enforcement.
- Constitutional challenges.

## 7.2 Case stages

A standard case may pass through:

1. Incident or dispute.
2. Complaint, claim, or investigation.
3. Jurisdiction and admissibility review.
4. Evidence gathering.
5. Preparation.
6. Hearing or judicial review.
7. Judgment.
8. Appeal, where available.
9. Enforcement or compliance.
10. Closure.

Not every case requires every stage.

## 7.3 Case data

Every case records:

- Case ID.
- Case type.
- Parties involved.
- Relevant law.
- Underlying events.
- Evidence.
- Court.
- Filing date.
- Current stage.
- Legal representatives.
- Procedural deadlines.
- Judicial findings.
- Judgment.
- Remedies or penalties.
- Appeals.
- Final status.

## 7.4 Case duration

Case duration depends on:

- Complexity.
- Court capacity.
- Evidence availability.
- Procedural requirements.
- Party cooperation.
- Existing backlog.

Cases may take several months or years.

## 7.5 Evidence and factual uncertainty

The simulation must distinguish:

- What actually occurred.
- What investigators know.
- What evidence is available.
- What evidence is admissible.
- What the court concludes.

A company may have committed fraud without enough admissible evidence existing to prove the allegation.

Conversely, a publicly suspected person may be innocent.

The underlying event record remains separate from the legal findings.

---

# 8. Civil Justice

Civil cases involve disputes between individuals or organizations.

## 8.1 Civil disputes

Examples:

- Unpaid invoices.
- Property disputes.
- Breach of contract.
- Negligent construction.
- Employment compensation.
- Defamation.
- Commercial damages.
- Ownership disputes.

## 8.2 Legal claims

A claimant may seek:

- Payment.
- Compensation.
- Contract enforcement.
- Injunctive relief.
- Return of property.
- Declaration of legal rights.

## 8.3 Civil outcomes

A case may result in:

- Claim dismissed.
- Claim upheld.
- Partial judgment.
- Settlement.
- Compensation.
- Court order.
- Appeal.

## 8.4 Settlements

Parties may settle disputes before a final judgment.

Settlement decisions depend on:

- Expected legal costs.
- Evidence.
- Likelihood of success.
- Financial capacity.
- Commercial relationships.
- Management preferences.

## 8.5 Economic integration

Court judgments can create financial obligations.

Compensation must be transferred through the economy's financial ledger.

A company unable to pay may become financially distressed.

---

# 9. Contract Law

Contract law is essential because nearly all major construction and procurement activities rely on commercial agreements.

## 9.1 Contract validity

Contracts require:

- Legally recognized parties.
- Agreement.
- Defined obligations.
- Lawful subject matter.
- Appropriate authority.
- Any required approvals.

## 9.2 Contract terms

Contracts may specify:

- Price.
- Deliverables.
- Duration.
- Materials.
- Payment schedules.
- Quality standards.
- Responsibilities.
- Penalties.
- Termination conditions.
- Dispute-resolution process.

## 9.3 Breach of contract

A breach occurs when a party fails to meet a binding obligation without an applicable legal excuse.

Examples:

- Contractor misses a deadline.
- Buyer fails to pay.
- Supplier delivers defective materials.
- Company abandons construction.
- Government unlawfully terminates a contract.

## 9.4 Contract enforcement

Possible remedies:

- Compensation.
- Performance order, where appropriate.
- Contract termination.
- Financial penalty.
- Renegotiation.
- Settlement.

## 9.5 Ownership changes

A company sale does not automatically invalidate contracts held by the same legal entity.

A merger, liquidation, or asset transfer may create additional legal questions.

These must be resolved through defined contract and corporate rules.

---

# 10. Corporate Law

The legal system governs company formation, ownership, management, insolvency, and commercial conduct.

## 10.1 Corporate registration

Companies require an appropriate legal registration.

Registration establishes:

- Legal identity.
- Ownership structure.
- Governance model.
- Registered business activities.
- Applicable reporting obligations.

## 10.2 Directors and management

Corporate law establishes the authority and responsibilities of:

- Owners.
- Board members.
- CEOs.
- Appointed managers.

## 10.3 Corporate misconduct

Potential violations include:

- Accounting fraud.
- Tax evasion.
- Bribery.
- Procurement fraud.
- Illegal distributions.
- Misleading financial disclosures.
- Unlawful market manipulation.

## 10.4 Insolvency

Insolvency proceedings determine how a distressed company's obligations and assets are handled.

Possible outcomes:

- Restructuring.
- Debt renegotiation.
- Sale.
- Administration.
- Liquidation.

## 10.5 Ownership disputes

Courts may resolve disputes involving:

- Shareholder rights.
- Inheritance.
- Board appointments.
- Breach of fiduciary duties.
- Company sales.
- Misappropriation of assets.

## 10.6 Competition law

Legal restrictions may apply to:

- Collusion.
- Price fixing.
- Abuse of market dominance.
- Anticompetitive mergers.
- Exclusive agreements.

Competition authorities investigate suspected violations.

## 10.7 Public enterprises

Public companies remain subject to applicable commercial and regulatory law.

They may also have special public-service obligations and additional public accountability requirements.

---

# 11. Labor Law and Employment Rights

Labor law connects the economic system to legal rights and political conflict.

## 11.1 Labor-law categories

Potential legislation covers:

- Workplace safety.
- Working hours.
- Employment contracts.
- Dismissal procedures.
- Wages.
- Collective bargaining.
- Union organization.
- Discrimination.
- Employment benefits.
- Employer liability.

## 11.2 Union formation

Workers may establish labor organizations where legally permitted.

Unions can:

- Negotiate employment conditions.
- Represent members.
- Organize lawful industrial action.
- File complaints.
- Participate in workplace disputes.

## 11.3 Labor disputes

Possible events:

- Wage dispute.
- Unsafe workplace.
- Unlawful dismissal.
- Failure to pay wages.
- Collective bargaining conflict.
- Strike.
- Lockout.

## 11.4 Labor enforcement

Relevant authorities may inspect employers and investigate violations.

Civil or administrative remedies may include:

- Compensation.
- Compliance orders.
- Penalties.
- Reinstatement, where legally available.
- Suspension of unsafe operations.

## 11.5 Economic consequences

Labor regulation can influence:

- Employer costs.
- Worker security.
- Productivity.
- Recruitment.
- Injury rates.
- Company profitability.
- Public satisfaction.

These effects must be calculated from the actual rules and circumstances, not assumed to be universally beneficial or harmful.

---

# 12. Property, Land, and Resource Rights

The player controls land-use planning, but ownership and planning permission are separate.

## 12.1 Property ownership

Land and facilities may be:

- Publicly owned.
- Privately owned.
- Cooperatively owned.
- Jointly owned.

## 12.2 Land-use regulation

Government may establish zoning and construction requirements.

Zoning does not automatically transfer ownership.

A private company may own land that is unsuitable for its desired development under current planning law.

## 12.3 Construction permissions

Developers may require permits.

Permits depend on:

- Zoning.
- Environmental rules.
- Safety standards.
- Infrastructure capacity.
- Legal ownership or development rights.

## 12.4 Resource extraction

Mineral rights may be controlled by:

- Government.
- Landowners.
- Licensed extraction companies.
- Other legally recognized entities.

The initial legal regime should define who owns resources before and after extraction.

## 12.5 Compulsory acquisition

The government may acquire property for public purposes only through defined legal procedures.

Requirements may include:

- Public purpose.
- Legal authorization.
- Compensation.
- Review or appeal.

## 12.6 Land disputes

Possible cases:

- Ownership dispute.
- Construction permit appeal.
- Compensation dispute.
- Unauthorized development.
- Resource extraction conflict.
- Environmental damage claim.

---

# 13. Administrative Law

Administrative law determines how government institutions exercise delegated powers.

## 13.1 Administrative decisions

Government agencies may:

- Issue permits.
- Enforce regulations.
- Assess taxes.
- Approve institutions.
- Inspect companies.
- Award certain licenses.
- Make eligibility decisions.

## 13.2 Legality checks

Administrative decisions must satisfy:

- Legal authority.
- Applicable procedure.
- Required evidence.
- Relevant criteria.
- Proper decision-maker.
- Rights protections.

## 13.3 Appeals

Affected parties may challenge decisions.

Examples:

- Company appeals a denied mining permit.
- School appeals a licensing decision.
- Citizen challenges a tax assessment.
- Contractor appeals a procurement exclusion.

## 13.4 Administrative court outcomes

A court may:

- Uphold the decision.
- Reverse it.
- Require reconsideration.
- Order an available remedy.
- Declare the action unlawful.

## 13.5 Institutional independence

Certain administrative authorities should possess operational independence.

The government may set lawful policy and funding, but may not necessarily direct individual regulatory decisions.

---

# 14. Criminal Law

Criminal law defines prohibited conduct and applicable penalties.

## 14.1 Offense categories

The initial system may include:

- Theft.
- Fraud.
- Bribery.
- Assault.
- Serious workplace safety violations.
- Environmental crimes.
- Illegal production or distribution.
- Tax evasion.
- Obstruction of justice.
- Other legally defined offenses.

## 14.2 Criminal investigation

Investigations may begin from:

- Reported incidents.
- Regulatory referrals.
- Police detection.
- Whistleblowers.
- Audits.
- News investigations.
- Complaints.

## 14.3 Prosecution

An authorized prosecution institution evaluates whether evidence is sufficient to bring charges.

The government cannot simply declare a person guilty.

## 14.4 Burden of proof

Criminal conviction requires the relevant criminal standard of proof.

The simulation must distinguish that from the standards used in ordinary civil and administrative proceedings.

## 14.5 Possible outcomes

- No charge.
- Case dismissed.
- Acquittal.
- Conviction.
- Appeal.
- Sentence or penalty.
- Alternative legal resolution where permitted.

## 14.6 Sentencing

Potential sanctions include:

- Fines.
- Restitution.
- Community-based penalties.
- Restrictions or disqualification.
- Imprisonment for appropriate serious offenses.

Sentencing must follow legislation and judicial procedures.

## 14.7 Detention capacity

If imprisonment is modeled, detention institutions require funding, facilities, staff, and capacity.

Overcrowding and poor conditions may create legal, social, and political consequences.

---

# 15. Police and Law Enforcement

## 15.1 Police institutions

Law enforcement agencies should operate as public institutions.

Their functions include:

- Responding to incidents.
- Investigating suspected crimes.
- Protecting public safety.
- Supporting lawful court orders.
- Enforcing applicable laws.

## 15.2 Police resources

Police capacity depends on:

- Funding.
- Staffing.
- Training.
- Equipment.
- Geographic coverage.
- Investigative workload.

## 15.3 Police effectiveness

Performance may depend on:

- Professional competence.
- Resources.
- Community cooperation.
- Institutional procedures.
- Case complexity.

## 15.4 Police misconduct

Police institutions may also violate laws or rights.

Potential issues include:

- Unlawful detention.
- Excessive use of authority.
- Corruption.
- Improper searches.
- Failure to follow procedure.

Such conduct can result in investigation, discipline, and legal proceedings.

## 15.5 Political control

The government may establish budgets, laws, and organizational structures.

It should not have unrestricted power to order arrests of political opponents.

---

# 16. Regulatory Agencies

Regulatory agencies enforce specialized laws.

## 16.1 Initial agencies

Recommended initial regulatory categories:

- Business and competition authority.
- Workplace safety authority.
- Environmental regulator.
- Education inspectorate.
- Healthcare regulator.
- Tax authority.
- Alcohol licensing authority.
- Public procurement oversight authority.

These may initially share abstracted administrative capacity rather than each requiring a large individually simulated workforce.

## 16.2 Agency properties

Each agency tracks:

- Statutory authority.
- Jurisdiction.
- Funding.
- Workforce.
- Expertise.
- Inspection capacity.
- Case backlog.
- Pending investigations.
- Enforcement history.

## 16.3 Inspections

Inspections require resources.

Inspection selection may consider:

- Random compliance checks.
- Previous violations.
- Public complaints.
- Risk factors.
- Reported incidents.
- Prior investigations.

## 16.4 Enforcement

A regulator may:

- Issue warnings.
- Require corrective action.
- Assess authorized penalties.
- Suspend licenses.
- Refer criminal cases.
- Seek judicial orders.

## 16.5 Underfunded regulators

An underfunded agency may inspect fewer organizations.

Violations may remain undetected longer.

A well-funded regulator may detect more violations without the underlying rate of misconduct necessarily increasing.

This distinction is essential.

---

# 17. Media, Press Freedom, and Legal Disputes

Newspapers must operate under the colony's legal framework.

## 17.1 Press freedom

Publications may investigate and criticize:

- Government.
- Political parties.
- Companies.
- Public officials.
- Institutions.

Lawful criticism should not automatically create legal penalties.

## 17.2 Media ownership

Private companies may own newspapers according to applicable ownership and competition law.

Publicly funded news organizations may have additional editorial independence protections.

## 17.3 Defamation and false claims

The legal system may provide remedies for actionable false statements that harm a person's or organization's reputation.

The simulation must distinguish:

- Factual allegations.
- Opinions.
- Accurate reporting.
- Accidental errors.
- Deliberate fabrication.

## 17.4 Media investigations

A newspaper investigation may reveal evidence that later becomes relevant to regulatory or criminal proceedings.

Publication alone does not establish legal guilt.

## 17.5 Confidential information

The law may protect certain private, commercial, or government information.

Restrictions must be defined and balanced against relevant press and public-information protections.

## 17.6 Government transparency

Public access rules may allow citizens and newspapers to obtain government records.

Transparency affects:

- Detection of misconduct.
- Public trust.
- Investigative journalism.
- Government accountability.

---

# 18. Alcohol Regulation and Justice

Alcohol legislation creates a useful example of how the legal and economic systems interact.

## 18.1 Legal market models

The law may establish:

- Government monopoly.
- Government retail monopoly.
- Licensed private production.
- Licensed private retail.
- Restricted production.
- Prohibition.

## 18.2 Licensing

A brewery or retailer may require a license.

Licensing requirements can include:

- Facility standards.
- Safety rules.
- Ownership disclosure.
- Fees.
- Product standards.
- Sales restrictions.

## 18.3 Illegal production

Illegal production may occur when businesses or individuals operate without the required authorization.

The economic simulation determines whether there is demand and opportunity.

The legal system determines the applicable offense, investigation, and potential sanctions.

## 18.4 Regulatory response

Authorities may:

- Inspect facilities.
- Investigate complaints.
- Issue penalties.
- Suspend licenses.
- Seek court orders.
- Refer suspected criminal conduct for prosecution.

## 18.5 Public health and enforcement

Government alcohol policy may involve:

- Taxation.
- Public health programs.
- Retail restrictions.
- Education.
- Licensing.
- Criminal enforcement.

These approaches have different economic, administrative, and political costs.

---

# 19. Corruption and Abuse of Power

Corruption must apply to both public and private actors.

## 19.1 Corruption types

Potential misconduct includes:

- Bribery.
- Illegal political donations.
- Procurement manipulation.
- Conflicts of interest.
- Embezzlement.
- Improper licensing decisions.
- Undisclosed financial interests.
- Misuse of public resources.

## 19.2 Corruption opportunities

Opportunities may arise during:

- Government contracts.
- Regulatory licensing.
- Public acquisitions.
- Subsidy allocation.
- Company inspections.
- Political donations.
- Major infrastructure projects.

## 19.3 Corruption incentives

Factors may include:

- Personal financial pressure.
- Ethical standards.
- Expected gain.
- Detection risk.
- Institutional oversight.
- Organizational culture.

## 19.4 Detection

Corruption may be discovered through:

- Audits.
- Whistleblowers.
- Investigations.
- Media reporting.
- Court proceedings.
- Financial inconsistencies.

## 19.5 Consequences

Possible consequences:

- Criminal proceedings.
- Financial penalties.
- Removal from office.
- Contract invalidation where legally applicable.
- Company sanctions.
- Loss of reputation.
- Coalition disputes.
- Election consequences.

## 19.6 False allegations

Political actors and newspapers may make inaccurate allegations.

An allegation should not automatically be treated as proof.

Investigations and court outcomes must rely on evidence.

---

# 20. Emergency Powers

Emergency powers are necessary for a vulnerable planetary settlement.

They must have explicit legal boundaries.

## 20.1 Emergency categories

Examples:

- Major infrastructure failure.
- Life-support emergency.
- Severe epidemic.
- Natural disaster.
- Critical food shortage.
- Serious civil unrest.
- Major industrial accident.

## 20.2 Emergency declaration

An emergency declaration may grant temporary authority to:

- Reallocate approved resources.
- Accelerate certain procurement.
- Restrict access to dangerous areas.
- Coordinate emergency services.
- Issue temporary operational orders.

## 20.3 Limitations

Emergency powers must specify:

- Who can declare the emergency.
- Conditions required.
- Duration.
- Permitted actions.
- Parliamentary oversight.
- Judicial review.
- Renewal procedures.

## 20.4 Rights during emergencies

Emergency measures may restrict certain activities within defined legal limits.

Fundamental protections against arbitrary punishment, unlawful detention, and other abuses should remain subject to constitutional safeguards.

## 20.5 Abuse of emergency powers

If the government exceeds its authority, affected parties may challenge the actions.

Political and legal consequences may follow.

---

# 21. Legal Reform and Parliament

The legal system must integrate with the clause-based legislative drafting system.

## 21.1 Legislative proposals

A proposed law consists of clauses specifying changes to legal rules.

Each clause has:

- Subject.
- Legal effect.
- Scope.
- Effective date.
- Enforcement mechanism.
- Required funding.
- Applicable institutions.
- Compatibility requirements.

## 21.2 Legal drafting

Political and administrative staff prepare the proposal.

Relevant skills may include:

- Law.
- Administration.
- Economics.
- Negotiation.
- Sector-specific expertise.

## 21.3 Legal compatibility checks

Before voting, the legislative system should identify:

- Constitutional conflicts.
- Existing laws affected.
- Required amendments.
- Administrative responsibilities.
- Enforcement costs.
- Legal uncertainty.

These checks provide advice and warnings, not guaranteed certainty about every eventual judicial ruling.

## 21.4 Parliamentary approval

Parliament votes according to its established rules.

Ordinary laws generally use the applicable parliamentary majority procedure.

Constitutional amendments follow their special procedure.

## 21.5 Enactment

After lawful approval, legislation enters the legal register.

Its rules become effective on the specified date.

Relevant agencies receive new responsibilities.

## 21.6 Implementation

Passing a law does not create instant enforcement capacity.

The government may need to:

- Fund agencies.
- Recruit employees.
- Train inspectors.
- Issue regulations.
- Create licensing systems.
- Inform companies.
- Establish reporting procedures.

---

# 22. Courts and Government Conflict

Courts must be able to make decisions unfavorable to the government.

## 22.1 Example: mining permit

The government approves a mining project.

Residents challenge the permit.

The court finds that the environmental authority failed to follow the required procedure.

The permit may be suspended or returned for reconsideration.

The underlying mining project retains its existing physical and contractual state but cannot continue unauthorized work.

## 22.2 Example: government contract

A construction company claims that the government unlawfully terminated its contract.

The dispute proceeds through the appropriate process.

The court may award compensation if the company proves its claim.

## 22.3 Example: constitutional challenge

Parliament passes a law restricting independent newspaper reporting.

A publication challenges the law.

The reviewing court determines whether the restriction complies with constitutional protections.

## 22.4 Government compliance

The government must have procedures for responding to binding judgments.

A government that refuses to comply creates a constitutional or institutional crisis.

Consequences may include:

- Parliamentary conflict.
- Loss of public trust.
- Administrative paralysis.
- Further legal action.
- Coalition breakdown.

---

# 23. Public Trust in Justice

Public trust in the justice system must be separate from actual legal performance.

## 23.1 Justice-system indicators

Track:

- Case backlog.
- Average case duration.
- Enforcement consistency.
- Access to legal services.
- Institutional independence.
- Corruption findings.
- Successful appeals.
- Public confidence.

## 23.2 Public perception

Population groups may respond differently to legal developments.

For example:

- Workers may prioritize workplace enforcement.
- Business owners may prioritize predictable contract law.
- Newspapers may prioritize press freedom.
- Residents may prioritize public safety.
- Civil-rights groups may prioritize protection against government abuse.

## 23.3 Political influence

Parties can campaign on:

- Faster courts.
- Stronger anti-corruption enforcement.
- Criminal justice reform.
- Regulatory reform.
- Greater government transparency.
- More independent oversight.
- Expanded legal protections.

The effectiveness of these promises depends on actual implementation and results.

---

# 24. Institutional Staffing

The justice system requires workers and resources.

## 24.1 Ordinary workforce

Judges, court clerks, police officers, prosecutors, inspectors, and lawyers are part of the broader labor simulation.

Their employment consumes funding and skilled labor capacity.

## 24.2 Government's twenty senior personnel

The player's ten political officials and ten permanent civil servants represent senior management capacity.

They do not replace ordinary judges, police, or regulatory employees.

Senior personnel may be assigned to:

- Prepare legal reforms.
- Develop court funding proposals.
- Coordinate justice administration.
- Review regulatory structures.
- Establish new agencies.
- Oversee lawful government implementation.

## 24.3 Judicial independence

Assigning a senior civil servant to improve court administration does not give that official control over judicial rulings.

## 24.4 Standing responsibilities

The player may assign officials to ongoing responsibilities such as:

- Justice administration oversight.
- Anti-corruption coordination.
- Regulatory policy monitoring.
- Government legal compliance.
- Public procurement oversight.

These assignments operate through the previously specified staff delegation system.

---

# 25. Legal AI

The legal system requires autonomous decision-making.

## 25.1 Citizens and households

Aggregated household groups may generate legal disputes based on economic and social events.

Only legally significant cases need individual records.

## 25.2 Companies

Corporate AI may decide whether to:

- File claims.
- Defend lawsuits.
- Appeal regulations.
- Settle disputes.
- Challenge licenses.
- Comply with enforcement orders.
- Contest penalties.

Decisions depend on evidence, costs, management, and expected outcomes.

## 25.3 Regulators

Regulatory AI chooses inspections and investigations based on:

- Risk.
- Complaints.
- Available resources.
- Legal mandate.
- Existing workload.

## 25.4 Prosecutors

Prosecution decisions depend on:

- Evidence.
- Legal requirements.
- Case priority.
- Available capacity.

## 25.5 Courts

Court decisions should follow explicit rules, relevant evidence, and legally defined standards.

Judicial outcomes should not simply be random political preferences.

Where uncertainty is appropriate, it should represent evidentiary ambiguity, legal interpretation, or procedural variation.

## 25.6 Government AI

An AI government must:

- Draft lawful legislation.
- Fund legal institutions.
- Respond to judgments.
- Appoint officials through appropriate procedures.
- Manage regulatory policy.
- Respond to emergencies.
- Respect the same constitutional constraints as the player.

---

# 26. User Interface

## 26.1 Law register

The game must provide a searchable register of current laws.

Each law displays:

- Name.
- Category.
- Status.
- Date enacted.
- Effective date.
- Legal authority.
- Relevant clauses.
- Previous amendments.
- Responsible institutions.

## 26.2 Constitution screen

Displays:

- Government structure.
- Fundamental rights.
- Parliamentary authority.
- Executive limitations.
- Judicial powers.
- Amendment procedures.

## 26.3 Justice overview

Displays:

- Court capacity.
- Pending cases.
- Backlogs.
- Institutional funding.
- Public confidence.
- Major judgments.

## 26.4 Cases interface

Each case displays:

- Parties.
- Allegations or claims.
- Current stage.
- Available evidence.
- Relevant law.
- Court.
- Expected procedural steps.
- Outcome when resolved.

Visibility depends on public access rules and the player's position.

## 26.5 Regulatory overview

Displays:

- Agencies.
- Budgets.
- Inspections.
- Violations.
- Investigations.
- Licenses.
- Enforcement actions.

## 26.6 Legal warnings

When proposing an action, the interface should identify known legal requirements.

Example:

"Construction requires an environmental permit."

Another example:

"This proposal may conflict with constitutional press protections."

Warnings should distinguish definite legal prohibitions from uncertain legal risks.

## 26.7 Historical legal archive

Preserve major:

- Laws.
- Constitutional amendments.
- Court decisions.
- Government legal controversies.
- Regulatory reforms.
- Legal investigations.

---

# 27. Technical Data Architecture

## 27.1 LegalRule

```text
LegalRule
    id
    title
    legal_level
    category

    issuing_authority_id
    enacted_month
    effective_month
    expiry_month

    status
    scope

    conditions[]
    permissions[]
    prohibitions[]
    obligations[]
    exceptions[]

    enforcement_authority_ids[]
    penalty_rules[]

    supersedes_rule_ids[]
    amended_by_rule_ids[]

    history[]
```

## 27.2 Constitution

```text
Constitution
    id
    founding_charter_id

    rights[]
    institutional_powers[]
    legislative_procedures[]
    judicial_powers[]
    amendment_procedure

    current_version
    amendment_history[]
```

## 27.3 Court

```text
Court
    id
    name
    court_type

    jurisdiction[]
    service_district_ids[]

    judge_capacity
    administrative_capacity
    budget

    pending_case_ids[]
    case_backlog

    independence_rules[]
    performance_history[]
```

## 27.4 LegalCase

```text
LegalCase
    id
    case_type

    claimant_ids[]
    respondent_ids[]

    underlying_event_ids[]
    relevant_rule_ids[]
    evidence_ids[]

    assigned_court_id

    filing_month
    current_stage
    procedural_deadlines[]

    findings[]
    judgment_id
    appeal_ids[]

    status
    history[]
```

## 27.5 EvidenceRecord

```text
EvidenceRecord
    id
    source_event_id

    evidence_type
    discovered_month

    content_reference
    reliability
    admissibility_status

    known_by_entity_ids[]
    chain_of_custody_record[]

    related_case_ids[]
```

## 27.6 Judgment

```text
Judgment
    id
    case_id

    court_id
    judgment_month

    findings[]
    applied_laws[]

    outcome
    remedies[]
    penalties[]

    appeal_status
    compliance_status
```

## 27.7 RegulatoryAgency

```text
RegulatoryAgency
    id
    name

    statutory_authority[]
    jurisdiction[]

    budget
    staffing
    inspection_capacity

    active_case_ids[]
    license_records[]
    enforcement_history[]
```

## 27.8 LegalIncident

```text
LegalIncident
    id
    event_month

    involved_entity_ids[]
    location_id

    actual_event_type
    potential_violations[]

    detected
    discovered_by_ids[]

    investigation_ids[]
    case_ids[]

    historical_record[]
```

## 27.9 LegalAction

```text
LegalAction
    id
    acting_entity_id

    action_type
    target_entity_id

    authority_rule_id
    required_conditions[]

    validation_result
    effective_month

    economic_effects[]
    administrative_effects[]

    history[]
```

## 27.10 License

```text
License
    id
    holder_id
    issuing_agency_id

    licensed_activity
    permitted_locations[]

    issued_month
    expiry_month

    conditions[]
    compliance_status

    suspension_status
    revocation_status

    history[]
```

---

# 28. Legal Rules Engine

A shared rules engine must determine whether an action is authorized.

## 28.1 Action validation

When an actor attempts an action:

1. Identify the actor.
2. Identify the action.
3. Identify the affected entities.
4. Determine relevant laws.
5. Check jurisdiction.
6. Check required authority.
7. Check conditions.
8. Check prohibitions.
9. Check exceptions.
10. Return the legal status.

## 28.2 Action results

Possible results:

- Authorized.
- Authorized with conditions.
- Requires approval.
- Legally prohibited.
- Legally disputed.
- Insufficient information.

## 28.3 Illegal actions

The simulation may permit autonomous actors to attempt unlawful conduct.

Such actions must be recorded as violations rather than silently treated as lawful.

The player's government interface should identify known legal restrictions, though exceptional systems may permit deliberate unlawful orders with appropriate consequences.

## 28.4 Legal uncertainty

Some cases require interpretation.

The rules engine determines established rules and likely conflicts.

Courts resolve formally contested interpretations within their jurisdiction.

## 28.5 Integration

The same legal engine is used by:

- Player government.
- AI governments.
- Companies.
- Public institutions.
- Regulators.
- Courts.
- Political parties.

---

# 29. Monthly Legal Simulation

The legal system must integrate into the shared monthly turn.

## Phase 1 — Apply new laws

Activate laws and regulations reaching their effective dates.

Expire temporary provisions.

Update relevant permissions and obligations.

## Phase 2 — Validate planned actions

Check legal authority for proposed government, institutional, and corporate actions.

Flag required approvals and prohibited actions.

## Phase 3 — Execute lawful operations

Allow authorized actions to proceed through the relevant economic, government, and project systems.

Record attempted violations separately.

## Phase 4 — Generate legal incidents

Economic and social events may create:

- Contract disputes.
- Regulatory violations.
- Criminal incidents.
- Employment claims.
- Administrative appeals.

## Phase 5 — Investigations and inspections

Regulators and enforcement agencies process available work according to staffing and resources.

## Phase 6 — Court processing

Courts advance cases based on procedural stage and capacity.

## Phase 7 — Judgments and remedies

Resolve eligible cases.

Create enforceable obligations.

## Phase 8 — Enforcement and compliance

Apply lawful orders, fines, compensation, and other consequences through the appropriate systems.

## Phase 9 — Public and political effects

Update public trust, institutional reputation, political pressures, and media-relevant events.

## Phase 10 — Historical records

Preserve laws, significant cases, judgments, violations, appeals, and institutional changes.

---

# 30. Development Roadmap

## Phase L1 — Legal Foundation

**Objective:** Establish legal entities and rule hierarchy.

Development tasks:

- Implement LegalRule.
- Implement legal categories.
- Implement hierarchy.
- Implement effective dates.
- Implement repeal and amendment.
- Add jurisdiction.
- Add legal permissions and prohibitions.
- Build rule validation.
- Add save/load.

**Acceptance criteria:** The game can determine which rules apply to an action and identify straightforward conflicts.

## Phase L2 — Founding Charter and Constitution

**Objective:** Define government authority and protected rights.

Development tasks:

- Implement founding charter.
- Add commander powers.
- Add provisional regulations.
- Define founding transition.
- Implement constitution.
- Add rights.
- Add institutional powers.
- Add constitutional amendment rules.
- Add judicial review authority.

**Acceptance criteria:** The founding commander and elected government have different legal powers, and constitutional protections persist across both phases.

## Phase L3 — Administrative Law

**Objective:** Make government agencies legally accountable.

Development tasks:

- Implement administrative authority.
- Add permit decisions.
- Add licenses.
- Add appealable decisions.
- Add procedural requirements.
- Add administrative challenges.
- Connect government staff and institutions.

**Acceptance criteria:** Administrative decisions require legal authority and can be challenged through defined procedures.

## Phase L4 — Civil and Contract Law

**Objective:** Support enforceable private obligations.

Development tasks:

- Implement civil claims.
- Add contract disputes.
- Add breach events.
- Add compensation.
- Add settlements.
- Add commercial remedies.
- Connect cases to financial transfers.
- Preserve obligations during company ownership changes.

**Acceptance criteria:** Companies and government can enter enforceable contracts and resolve disputes without arbitrary deletion of obligations.

## Phase L5 — Courts and Case Processing

**Objective:** Establish independent judicial institutions.

Development tasks:

- Implement courts.
- Add jurisdictions.
- Add case registration.
- Add evidence.
- Add procedural stages.
- Add judicial capacity.
- Add hearings.
- Add judgments.
- Add appeals.
- Add case backlogs.

**Acceptance criteria:** Courts process cases independently under defined legal rules and capacity constraints.

## Phase L6 — Corporate and Competition Law

**Objective:** Connect legal institutions to company behavior.

Development tasks:

- Add company registration.
- Add corporate authority.
- Add ownership disputes.
- Add insolvency procedures.
- Add competition rules.
- Add merger review.
- Add commercial enforcement.
- Add corporate penalties.

**Acceptance criteria:** Corporate legal disputes, mergers, and insolvency follow consistent rules.

## Phase L7 — Labor and Property Law

**Objective:** Establish employment and property protections.

Development tasks:

- Add labor standards.
- Add employment disputes.
- Add union rights.
- Add workplace inspections.
- Add property ownership rules.
- Add land-use permissions.
- Add resource extraction rights.
- Add public acquisition procedures.
- Add compensation claims.

**Acceptance criteria:** Employment, land, and resource decisions generate enforceable rights and obligations.

## Phase L8 — Criminal Law and Enforcement

**Objective:** Support criminal violations and prosecution.

Development tasks:

- Add criminal offenses.
- Add incidents.
- Add police capacity.
- Add investigations.
- Add prosecutors.
- Add evidence standards.
- Add trials.
- Add sentencing.
- Add enforcement.
- Add detention capacity where applicable.

**Acceptance criteria:** Suspected wrongdoing can be investigated, prosecuted, and judged without automatically treating allegations as guilt.

## Phase L9 — Regulatory Agencies

**Objective:** Implement specialized enforcement.

Development tasks:

- Implement agencies.
- Add inspection capacity.
- Add regulatory cases.
- Add enforcement orders.
- Add penalties.
- Add license suspension.
- Add referrals.
- Add administrative appeals.
- Connect agency funding to the economy.

**Acceptance criteria:** Regulatory enforcement depends on legal powers, evidence, staff, and resources.

## Phase L10 — Rights and Constitutional Review

**Objective:** Enforce legal limits on government action.

Development tasks:

- Add rights conflict detection.
- Add constitutional cases.
- Add review procedures.
- Add remedies.
- Add government compliance.
- Add institutional crisis handling.
- Add constitutional amendments.

**Acceptance criteria:** Unconstitutional or unauthorized government actions can be challenged and legally constrained.

## Phase L11 — Corruption and Government Accountability

**Objective:** Support misconduct and oversight.

Development tasks:

- Add public corruption offenses.
- Add conflicts of interest.
- Add procurement investigations.
- Add financial audits.
- Add whistleblower events.
- Add prosecution.
- Add public accountability.
- Connect findings to political consequences.

**Acceptance criteria:** Corruption can occur, be discovered, investigated, and punished through defined processes.

## Phase L12 — Media, Alcohol, and Sector Regulation

**Objective:** Integrate specialized company systems.

Development tasks:

- Add press protections.
- Add media legal disputes.
- Add licensing rules.
- Add alcohol legislation.
- Add legal and illegal production.
- Add school regulation.
- Add healthcare regulation.
- Add environmental enforcement.
- Add sector-specific legal procedures.

**Acceptance criteria:** Companies and institutions operate under the laws applicable to their industries.

## Phase L13 — Emergency Powers

**Objective:** Support lawful crisis response.

Development tasks:

- Add emergency declaration rules.
- Add temporary powers.
- Add duration limits.
- Add parliamentary oversight.
- Add judicial review.
- Add abuse-of-power cases.
- Connect to crisis events.

**Acceptance criteria:** Emergency authority can be exercised within explicit legal limits and reviewed when challenged.

## Phase L14 — Political Integration

**Objective:** Connect legal systems to parliamentary government.

Development tasks:

- Connect legislative drafting.
- Add legal compatibility warnings.
- Add laws from parliamentary votes.
- Add legal implementation tasks.
- Add government legal advisers.
- Add court-relevant political events.
- Add constitutional reform.
- Add opposition legal challenges.

**Acceptance criteria:** Political decisions change the legal system through legitimate procedures, while legal institutions continue operating independently.

## Phase L15 — Legal AI

**Objective:** Make courts and enforcement autonomous.

Development tasks:

- Add regulatory decision AI.
- Add legal claims AI.
- Add settlement AI.
- Add prosecution decisions.
- Add court processing.
- Add government compliance AI.
- Add appeal decisions.
- Add legal-risk evaluation for companies.
- Ensure AI and player share legal constraints.

**Acceptance criteria:** Legal institutions can function across multiple government terms without requiring direct player control.

## Phase L16 — User Interface

**Objective:** Make the legal system understandable.

Development tasks:

- Build law register.
- Build constitution screen.
- Build court overview.
- Build legal case interface.
- Build regulatory overview.
- Add legal warnings.
- Add judgment history.
- Add appeal notifications.
- Add legal institution information.

**Acceptance criteria:** The player can identify applicable laws, current cases, institutional capacity, and legal constraints.

## Phase L17 — Balancing and Long-Term Testing

**Objective:** Produce a stable and credible legal simulation.

Development tasks:

- Balance case generation.
- Balance court capacity.
- Balance investigation frequency.
- Balance legal uncertainty.
- Balance enforcement effectiveness.
- Test constitutional conflicts.
- Test government transitions.
- Test corporate disputes.
- Test administrative appeals.
- Test emergency powers.
- Run multidecade simulations.
- Optimize case and evidence storage.

**Acceptance criteria:** The legal system remains functional, internally consistent, and understandable across long campaigns.

---

# 31. Testing Scenarios

## Test 1 — Founding authority

The commander creates a permitted provisional construction regulation.

Expected result: The regulation becomes effective under the expedition charter.

## Test 2 — Constitutional protection

The commander attempts an action prohibited by a foundational right.

Expected result: The legal engine identifies the conflict.

## Test 3 — Parliamentary transition

The first election establishes parliamentary government.

Expected result: Extraordinary founding powers expire, ordinary provisional rules follow their continuation rules, and constitutional institutions remain.

## Test 4 — Contract dispute

A government contractor fails to fulfill a contract.

Expected result: The parties can initiate the applicable legal procedures.

## Test 5 — Government breach

The government unlawfully refuses a contract payment.

Expected result: The contractor may pursue a legal claim.

## Test 6 — Ownership transfer

A company changes owners while holding contracts.

Expected result: Existing legal obligations remain attached to the appropriate entity.

## Test 7 — Employment dispute

A worker group reports unlawful wage withholding.

Expected result: The event can generate an investigation or legal claim.

## Test 8 — Environmental permit

A company attempts to open a mine without required authorization.

Expected result: The action is prohibited or recorded as an unlawful attempt.

## Test 9 — Administrative appeal

A school challenges a license rejection.

Expected result: The appeal proceeds through the relevant administrative process.

## Test 10 — Independent court

A court rules against a government ministry.

Expected result: The judgment is recorded without requiring political approval.

## Test 11 — Constitutional challenge

Parliament passes a law conflicting with a protected right.

Expected result: The law may be challenged and reviewed through the constitutional process.

## Test 12 — Criminal allegation

A newspaper accuses a CEO of bribery.

Expected result: The allegation alone does not establish guilt.

## Test 13 — Evidence discovery

Investigators discover relevant bribery evidence.

Expected result: The prosecution process evaluates the evidence.

## Test 14 — Acquittal

Evidence is insufficient for conviction.

Expected result: The accused is acquitted even if public suspicion remains.

## Test 15 — Corporate fine

A company receives a lawful financial penalty.

Expected result: Its finances and the recipient public account are updated consistently.

## Test 16 — Underfunded regulator

Reduce regulatory funding.

Expected result: Inspection capacity decreases, potentially allowing more violations to remain undetected.

## Test 17 — Court backlog

Increase incoming cases above court capacity.

Expected result: Case delays and backlog grow.

## Test 18 — Court expansion

Fund additional judicial capacity and recruit qualified personnel.

Expected result: Backlog may decrease over subsequent months.

## Test 19 — Alcohol regulation

Change from a public retail monopoly to licensed private sales.

Expected result: Licensing and lawful market access change according to the new legislation.

## Test 20 — Illegal brewery

A company produces alcohol without a required license.

Expected result: A legal violation exists even if regulators do not immediately discover it.

## Test 21 — Press freedom

A newspaper publishes lawful criticism of government.

Expected result: No legal penalty arises merely from criticism.

## Test 22 — False reporting

A newspaper knowingly publishes a damaging false factual allegation.

Expected result: The underlying claim and any legally actionable consequences are handled separately from its editorial viewpoint.

## Test 23 — Emergency authority

The government declares an emergency under valid conditions.

Expected result: Defined temporary powers become available.

## Test 24 — Emergency abuse

The government exceeds the emergency powers granted by law.

Expected result: The action can generate legal challenges and institutional consequences.

## Test 25 — Constitutional amendment

Parliament initiates a constitutional change.

Expected result: The amendment follows the special procedure rather than ordinary legislative approval.

## Test 26 — Government transition

An election replaces the government during ongoing cases.

Expected result: Courts, investigations, legal obligations, and pending cases persist.

## Test 27 — Opposition

The player loses office.

Expected result: The player can participate in lawful opposition oversight and legal challenges without controlling courts or prosecutors.

## Test 28 — Save and load

Save during an investigation, court hearing, administrative appeal, and constitutional challenge.

Expected result: All proceedings and records resume consistently.

## Test 29 — Long-term simulation

Run the colony for thirty simulated years.

Expected result:

- Legal institutions remain functional.
- Cases do not disappear without resolution.
- Court backlogs follow capacity constraints.
- Laws preserve valid amendment histories.
- Companies remain subject to legal obligations.
- Courts remain institutionally separate from governments.
- Political transitions preserve ongoing proceedings.
- Economic penalties and compensation balance financially.
- Legal rules do not produce contradictory permissions without explicit resolution.

---

# 32. Minimum Complete Playable Legal System

The first complete playable version requires:

1. Founding expedition charter.
2. Founding commander legal authority.
3. Parliamentary constitutional framework.
4. Legal hierarchy.
5. Fundamental rights.
6. Ordinary legislation.
7. Government regulations.
8. Administrative decisions.
9. Legal permissions and prohibitions.
10. Basic legal validation.
11. Civil disputes.
12. Contract disputes.
13. Administrative appeals.
14. Courts.
15. Case backlogs.
16. Evidence records.
17. Judgments.
18. Appeals.
19. Regulatory agencies.
20. Company licensing.
21. Corporate law.
22. Employment protections.
23. Property rights.
24. Criminal offenses.
25. Basic investigation and prosecution.
26. Corruption rules.
27. Constitutional review.
28. Emergency authority.
29. Legal consequences for companies.
30. Legal restrictions on government.
31. Continued operation during opposition.
32. Save and load support.

---

# 33. Outstanding Design Decisions

The following must be decided before implementing the relevant phases.

| Area | Decision | Proposed starting approach |
|---|---|---|
| Founding charter | Initial protected rights | Core constitutional protections from arrival |
| Founding regulations | Continuity after election | Temporary continuation until amended or repealed |
| Constitution | Amendment procedure | Two parliamentary approvals separated by election |
| Courts | Number of court levels | General, administrative, higher review |
| Judges | Individual simulation depth | Senior judges individually, others aggregated |
| Criminal justice | Sentencing complexity | Simplified penalties and detention |
| Evidence | Legal proof model | Structured evidence with reliability and admissibility |
| Appeals | Number of appeal opportunities | Limited, jurisdiction-dependent |
| Court capacity | Processing formula | Staff, funding, complexity, backlog |
| Corporate law | Ownership and governance | Shared with company specification |
| Labor law | Starting protections | Defined minimum founding standards |
| Property | Ownership rules | Public and private ownership supported |
| Mining | Mineral-rights regime | Established by founding charter |
| Police | Individual or aggregate | Aggregated workforce |
| Regulators | Agency specialization | Sector-specific mandates, shared initial infrastructure |
| Corruption | Detection mechanics | Evidence and enforcement capacity |
| Emergency powers | Maximum duration | Constitutionally limited with renewal procedure |
| Judicial appointments | Selection process | Independent legal process with political appointments constrained |
| Government compliance | Response to adverse judgments | Mandatory lawful compliance, with institutional crises if resisted |
| Public legal information | Access rules | Public laws and most final judgments |
| Legal aid | Access to representation | Publicly fundable institutional service |
| AI legal decisions | Algorithm | Rule-based procedures with structured uncertainty |

These decisions are retained within the specification and should be resolved before their corresponding implementation phases.

---

# 34. Complete Gameplay Acceptance Scenario

## Founding years

The player arrives as settlement commander.

The expedition charter provides broad authority to establish the colony.

The player introduces construction regulations, creates a basic legal register, and establishes a dispute-resolution institution.

Several private companies begin operating.

One construction company fails to deliver a contracted facility.

The commander cannot simply erase the company's obligations.

The dispute follows the available founding legal procedures.

## First parliamentary term

The first election establishes parliamentary government.

The founding commander's extraordinary authority expires.

Parliament considers legislation establishing stronger workplace safety protections.

The government assigns political and permanent staff to draft the law.

The proposal passes.

The workplace safety authority receives new responsibilities.

However, its existing staff cannot inspect every industrial facility immediately.

The government must fund additional capacity.

## Industrial dispute

A mining company continues operating with unsafe equipment.

Workers complain.

A regulator investigates.

The company attempts to challenge the regulator's order.

The administrative court reviews whether the agency acted lawfully.

The regulator's powers, inspection evidence, and the company's arguments all influence the outcome.

The government cannot dictate the ruling.

## Corporate corruption case

A major contractor is suspected of bribing a public procurement official.

A newspaper publishes allegations.

The underlying misconduct is recorded separately from the newspaper's reporting.

Investigators gather evidence.

The prosecution authority determines whether a criminal case can proceed.

The legal case may last several months.

The public reacts before the case is resolved, but legal guilt remains a separate question.

## Constitutional dispute

A coalition proposes legislation restricting certain newspaper investigations.

Opposition parties argue that the law violates constitutional press protections.

The government may have sufficient parliamentary support to pass the proposal.

However, its constitutional validity can still be challenged.

A court reviews the issue.

The final ruling may restrict how the legislation can be implemented.

## Government change

The player loses the next election.

The incoming government changes labor regulation, corporate taxation, and regulatory funding.

Courts and legal institutions continue operating.

Existing legal cases do not restart.

Companies adapt to the new legal environment.

The player continues in opposition and may challenge government policy through parliament and appropriate legal institutions.

## Return to power

Four years later, the player returns to government.

The legal system has evolved.

New laws have been introduced.

Some previous laws have been repealed.

Major court judgments have affected government authority.

Companies have adapted their business practices.

The player must govern within the legal framework that now exists.

They may attempt reforms, but must follow the same constitutional and parliamentary procedures.

---

# 35. Final System Acceptance Criteria

The Law, Rights & Justice system is complete when:

- The founding commander operates under defined legal authority.
- Democratic transition changes government powers without deleting legal obligations.
- A persistent constitution protects fundamental rights.
- The game distinguishes constitutional, statutory, regulatory, administrative, and contractual rules.
- Legislation can create, amend, and repeal enforceable laws.
- Courts operate independently of direct political control.
- Civil and criminal cases follow different legal procedures.
- Evidence and allegations remain separate from proven legal findings.
- Individuals and companies can challenge government decisions.
- Companies can enforce and be held accountable for contracts.
- Ownership and leadership changes preserve corporate legal continuity.
- Labor and property rights affect economic decisions.
- Regulatory agencies enforce legislation according to their available resources.
- Law enforcement operates under legal restrictions.
- Corruption can be investigated and prosecuted.
- Newspapers can report freely within the applicable legal framework.
- Alcohol, education, healthcare, mining, and other industries follow their applicable regulations.
- Legal changes alter economic and institutional behavior.
- Emergency powers have explicit limits.
- Governments can be challenged when they exceed their authority.
- Court judgments create enforceable consequences.
- Public trust responds to legal performance and events.
- Judicial and regulatory institutions survive changes of government.
- AI governments operate under the same rules as the player.
- Opposition gameplay includes lawful oversight and legal challenges.
- Long-term campaigns preserve laws, cases, rulings, and institutional history.
- Save and load maintain complete legal-system consistency.

**Final design principle:** The legal system must ensure that the colony is governed by institutions and enforceable rules rather than whichever political party happens to hold power. The player can change laws, establish institutions, regulate companies, and pursue legal reforms, but those actions must follow the powers and procedures established by the colony's evolving constitutional and legal framework.
