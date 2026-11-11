# Political Colony Simulator
# Staff, Skills, Talents & Assignment System
## Complete Game Design and Development Specification

**Version:** 0.5  
**Status:** Consolidated development plan  
**Simulation interval:** Monthly turns  
**Personnel model:** 10 political positions + 10 permanent civil servants  
**Related systems:** Government, political parties, parliament, economy, contractors, projects, legislation, elections, opposition

---

# 1. System Overview

The personnel system represents the government's ability to organize, supervise, and carry out work.

Personnel are limited resources that the player uses to execute political, administrative, and development objectives.

Each official has individual skills, talents, experience, and a work-speed rating.

Tasks can require one or several people. Certain tasks require specific skills, combinations of skills, or particular talents.

The player assigns available officials to the positions required by a task.

Once assigned, those officials continue performing their work automatically over successive monthly turns. The player receives a report from every official at the beginning of each month.

At any time during the planning phase, the player can inspect assigned personnel, unassign individuals, and allocate them to other work.

Projects, completed progress, financial commitments, and historical records are preserved when assignments change.

The system must make delegation a central mechanic rather than requiring constant intervention.

## 1.1 Primary objectives

The system must accomplish the following:

1. Limit how many initiatives the government can actively manage.
2. Make individual staff qualifications strategically important.
3. Allow tasks to require teams with different competencies.
4. Make talents meaningfully different from ordinary skills.
5. Support projects lasting months or years.
6. Allow indefinite standing responsibilities.
7. Minimize repetitive administrative decisions.
8. Give the player complete visibility over staff availability.
9. Allow reassignment without destroying completed work.
10. Preserve administrative continuity between governments.
11. Support political disagreements within coalition governments.
12. Provide detailed but manageable monthly progress reporting.
13. Allow personnel to develop through experience.
14. Connect staff activity to real economic, legislative, and government outcomes.

---

# 2. Confirmed Design Rules

The following rules are treated as established design requirements.

| Feature | Rule |
|---|---|
| Political staff | 10 positions allocated among governing coalition parties |
| Civil servants | 10 nonpartisan permanent government officials |
| Staff availability | Unassigned personnel are displayed as available resources |
| Monthly reporting | Every official provides an update at the beginning of the month |
| Task requirements | Different tasks require different numbers of personnel |
| Skill requirements | Tasks can require specific competencies |
| Talent requirements | Some tasks may require or benefit from particular talents |
| Team formation | Multiple officials can be assigned to one task |
| Long-term work | Assignments persist for months or years |
| Delegation | Assigned personnel perform routine work automatically |
| Unassignment | Individual officials can be unassigned during planning |
| Reassignment | Released officials are immediately available for other assignments |
| Project preservation | Unassigning staff does not erase completed work |
| Government transition | Political appointments change while permanent officials provide continuity |
| Opposition | Losing office does not end the campaign |
| Retirement | The player can voluntarily end their political career |

All numerical formulas, skill thresholds, and balancing values introduced below are proposed implementation rules unless specifically identified as fixed requirements.

---

# 3. Personnel Categories

## 3.1 Political personnel

The government contains ten political positions.

These positions are distributed among parties participating in the governing coalition, proportionally to their parliamentary representation within that coalition.

Political personnel represent ministers, political administrators, policy advisers, and other senior political leadership.

Their responsibilities include:

- Developing government policy.
- Drafting legislation.
- Negotiating with parliamentary parties.
- Preparing government budgets.
- Coordinating coalition commitments.
- Managing politically sensitive initiatives.
- Supervising government priorities.
- Communicating government decisions.
- Negotiating with companies and interest groups.
- Directing implementation of approved reforms.

Political personnel generally have higher work speed than permanent civil servants, but their individual skills vary.

### 3.1.1 Coalition distribution

For a coalition containing multiple parties:

\[
\text{Party share}=
\frac{\text{Party coalition seats}}
{\text{Total coalition seats}}
\]

The ten political positions are distributed according to these shares using a deterministic proportional allocation algorithm.

Example:

| Coalition party | Parliamentary seats | Political positions |
|---|---:|---:|
| Player's party | 49 | 5 |
| Commerce Party | 28 | 3 |
| Green Future | 19 | 2 |
| Total | 96 | 10 |

The precise personnel attached to the positions are determined through the government's appointment process.

### 3.1.2 Coalition-party loyalty

Each political official has a party affiliation.

An official belonging to a coalition partner may have different priorities from the player.

Coalition agreements establish the policies the parties have committed to implementing.

An official may object to work that:

- Contradicts their party's fundamental commitments.
- Violates the coalition agreement.
- Requires authority they do not possess.
- Conflicts with previously negotiated responsibilities.

Such objections are handled through the political system.

Political disagreements do not automatically erase assignments or project progress.

## 3.2 Permanent civil servants

The government also contains ten permanent senior administrative personnel.

These officials:

- Have no party affiliation.
- Remain employed across government transitions.
- Retain their accumulated experience.
- Possess individual specializations.
- Generally have higher professional skills.
- Generally work more slowly than political personnel.
- Carry out lawful government instructions.
- Preserve institutional knowledge.

Civil servants may specialize in:

- Finance.
- Engineering.
- Logistics.
- Procurement.
- Law.
- Public administration.
- Infrastructure.
- Healthcare.
- Environmental management.
- Economic development.

Permanent officials serve the government as an institution.

They are not the personal employees of the party currently governing.

## 3.3 Political and administrative differences

| Characteristic | Political personnel | Civil servants |
|---|---|---|
| Total positions | 10 | 10 |
| Party affiliation | Yes | No |
| Changes after elections | Generally | Usually retained |
| Typical work speed | Higher | Lower |
| Typical professional expertise | Variable | Higher |
| Policy leadership | Primary function | Advisory and implementation function |
| Technical administration | Possible | Primary function |
| Institutional continuity | Lower | Higher |
| Coalition commitments | Relevant | Not personally partisan |

Individual officials may differ significantly from these general tendencies.

---

# 4. Individual Staff Attributes

Every official must be represented by a persistent character record.

## 4.1 Core attributes

Each official has:

- Unique ID.
- Name.
- Personnel category.
- Party affiliation, where applicable.
- Current government position.
- Skill ratings.
- Talents.
- Work speed.
- Reliability.
- Experience.
- Current assignment.
- Employment or availability status.
- Professional history.
- Previous achievements and failures.

## 4.2 Skills

Skills represent professional abilities developed through training and experience.

The initial system uses ten skill categories.

| Skill | Relevant responsibilities |
|---|---|
| Administration | Managing projects, institutions, and departments |
| Economics | Taxation, budgets, subsidies, economic development |
| Engineering | Infrastructure, construction, industrial development |
| Logistics | Transportation, supplies, procurement coordination |
| Law | Legislation, regulation, contracts |
| Negotiation | Coalition agreements, disputes, commercial agreements |
| Politics | Parliamentary strategy, political coordination |
| Communication | Public information, campaigns, announcements |
| Environmental Management | Environmental policy, regulation, restoration |
| Public Services | Healthcare, housing, education, service administration |

Skills range from 0 to 100.

### 4.2.1 Skill levels

| Rating | Description |
|---|---|
| 0–19 | Minimal knowledge |
| 20–39 | Basic |
| 40–59 | Competent |
| 60–79 | Experienced |
| 80–94 | Expert |
| 95–100 | Exceptional |

The rating provides a general indication of competence.

Task-specific suitability is calculated using the relevant skills and requirements.

## 4.3 Work speed

Work speed determines how quickly an official performs administrative work.

A fast official can advance tasks more rapidly, but speed does not automatically improve the quality of the result.

Work speed uses a numerical rating from 0 to 100.

The actual contribution is converted into a task-specific multiplier.

## 4.4 Reliability

Reliability represents consistency.

It may influence:

- Administrative mistakes.
- Missed deadlines.
- Accuracy of reports.
- Routine task execution.
- The likelihood that emerging problems are detected.

Reliability should not produce random failures so frequently that experienced staff become frustrating to use.

## 4.5 Experience

Experience records professional development.

Staff gain experience through:

- Completing tasks.
- Participating in major projects.
- Handling complex responsibilities.
- Training.
- Responding to difficult events.

Experience contributes to skill development.

---

# 5. Talents

## 5.1 Purpose

Talents distinguish officials who have similar skill ratings.

A skill represents a learned competency.

A talent represents a distinctive ability or working characteristic.

An official may have excellent negotiation skills without possessing the Skilled Mediator talent.

Likewise, an official with moderate negotiation skills may possess a talent that makes them especially effective in a particular type of negotiation.

## 5.2 Talent structure

A talent contains:

- ID.
- Name.
- Description.
- Applicable task types.
- Activation requirements.
- Effect.
- Stacking rules.

Most officials begin with zero to two talents.

## 5.3 Initial talent library

| Talent | Gameplay effect |
|---|---|
| Fast Learner | Increases relevant experience gain |
| Detail-Oriented | Improves detection of mistakes |
| Skilled Mediator | Improves negotiation outcomes |
| Crisis Manager | Improves emergency management |
| Industrial Expert | Improves industrial development assignments |
| Strong Organizer | Improves multi-person team coordination |
| Cautious Planner | Reduces planning risks, possibly at a speed cost |
| Persuasive Speaker | Improves public communication |
| Procurement Specialist | Improves contractor evaluations |
| Financial Analyst | Improves economic forecasts |
| Legal Specialist | Improves complex legal drafting |
| Field Supervisor | Improves construction oversight |
| Adaptable | Reduces penalties outside specialization |
| Institutional Memory | Improves institutional and administrative work |
| Problem Solver | Improves resolution of unexpected problems |
| Resourceful | Reduces certain administrative resource costs |

## 5.4 Talent requirements

Tasks may use talents in three ways.

**Required talent:** The task or position explicitly requires the talent.

**Alternative qualification:** A talent can substitute for part of a conventional skill requirement.

**Optional advantage:** The talent improves the official's performance but is not necessary.

Required talents should be relatively uncommon to avoid creating frequent situations where important tasks are impossible.

## 5.5 Talent stacking

Talents may apply to:

- An individual's performance.
- A specific task stage.
- The entire assigned team.

Team-wide bonuses should have explicit stacking limits.

Identical talents should not produce unlimited cumulative bonuses.

---

# 6. Task and Project Structure

Tasks and projects must be separate entities.

This is necessary because one project may contain several tasks, each requiring different personnel.

## 6.1 Projects

A project is a long-term objective.

Examples:

- Construct a hospital.
- Develop a mining district.
- Establish an industrial area.
- Expand transportation infrastructure.
- Implement a healthcare reform.
- Introduce a new taxation system.

A project has:

- Project ID.
- Objective.
- Current status.
- Overall progress.
- Budget.
- Resources.
- Contractors.
- Associated tasks.
- Legal authorization.
- Historical record.

## 6.2 Tasks

A task represents a defined piece of work within a project or a standalone responsibility.

For example, a hospital project might contain:

1. Prepare the technical design.
2. Obtain financial authorization.
3. Evaluate contractor bids.
4. Negotiate a construction contract.
5. Supervise construction.
6. Complete final inspection.

Each task may require different skills and numbers of personnel.

## 6.3 Task types

The system supports four primary categories.

### Short tasks

Finite administrative work.

Examples:

- Review a contractor bid.
- Prepare an economic report.
- Conduct a legal review.
- Negotiate a minor agreement.

Expected duration: usually one to three months, depending on complexity.

### Long-term tasks

Assignments that continue across many months.

Examples:

- Supervise hospital construction.
- Manage industrial development.
- Coordinate a housing expansion.
- Implement an economic reform.

Expected duration: several months or years.

### Standing responsibilities

Indefinite assignments.

Examples:

- Oversee infrastructure maintenance.
- Manage routine procurement.
- Monitor public finances.
- Supervise healthcare administration.
- Coordinate logistics policy.

These tasks continue until ended or reassigned.

### Political tasks

Assignments related to government and parliamentary activity.

Examples:

- Draft legislation.
- Negotiate coalition agreements.
- Prepare budget proposals.
- Coordinate parliamentary support.
- Develop electoral agendas.

These may be short or long-term.

---

# 7. Task Staffing Requirements

Every task specifies exactly what personnel it needs.

## 7.1 Required positions

A task can require one or more distinct roles.

Example:

**Northern Mining District Development**

| Position | Primary requirement | Minimum skill |
|---|---|---:|
| Technical lead | Engineering | 70 |
| Logistics coordinator | Logistics | 65 |
| Administrative supervisor | Administration | 60 |

The task requires three qualified officials.

Three randomly selected officials are not sufficient unless they satisfy the requirements.

## 7.2 Optional positions

Tasks may offer additional positions.

For example:

- Procurement adviser.
- Financial reviewer.
- Legal adviser.
- Deputy coordinator.

Optional officials may improve progress, reduce risks, or increase quality.

The task can continue without them.

## 7.3 Multiple skills per position

Some positions require several competencies.

Example:

**Tax reform lead**

- Economics: minimum 75.
- Law: minimum 50.
- Administration: minimum 40.

The task definition identifies which requirements are mandatory and which contribute to effectiveness.

## 7.4 Alternative qualifications

Positions can accept different qualification paths.

Example:

**Senior procurement coordinator**

Qualification A:
- Economics ≥ 75.

Qualification B:
- Administration ≥ 60.
- Procurement Specialist talent.

A candidate meeting either path is eligible.

## 7.5 Qualification validation

When a person is selected for a position, the system checks:

1. Is the official available?
2. Is the official permitted to hold the position?
3. Are mandatory skills sufficient?
4. Are required talents present?
5. Does the official meet an alternative qualification path?
6. Is the position currently vacant?

The interface displays the result before confirmation.

---

# 8. Team Formation

## 8.1 General rules

Each official may occupy one active assignment position at a time in the initial implementation.

Tasks can have several positions.

Several officials can work together on the same task.

An official cannot simultaneously occupy positions in unrelated assignments.

## 8.2 Team readiness

A task is adequately staffed when every mandatory position is occupied by an eligible official.

The system distinguishes:

- Fully staffed.
- Partially staffed.
- Unstaffed.
- Staffed but lacking resources.
- Staffed but awaiting authorization.

A fully staffed task may still be blocked by funding, materials, or political approval.

## 8.3 Team roles

Each role should contribute to a particular part of a task.

For example:

**Major infrastructure project**

- Engineer: Technical quality.
- Logistics specialist: Material coordination.
- Administrator: Budget oversight.
- Political official: Political coordination.

Team performance depends on the combination of these contributions.

## 8.4 Team compatibility

The initial implementation should use skill and talent compatibility rather than complicated interpersonal relationship simulations.

A Strong Organizer talent may provide a coordination benefit.

A poorly qualified official may contribute less effectively to their assigned position.

Additional personal relationships may be introduced later.

---

# 9. Work and Progress Calculations

## 9.1 Work units

Finite tasks contain a defined amount of administrative work.

Example:

A legislative draft requires 100 work units.

Staff contribute work units during each monthly processing phase.

## 9.2 Individual contribution

Proposed formula:

\[
W_i = B_i \times V_i \times K_i \times T_i
\]

Where:

- \(W_i\) = individual monthly work contribution.
- \(B_i\) = base work rate for the position.
- \(V_i\) = speed multiplier.
- \(K_i\) = skill suitability multiplier.
- \(T_i\) = applicable talent multiplier.

## 9.3 Skill suitability

A role can use weighted skills.

For example, a budget reform position might use:

- Economics: 60%.
- Law: 25%.
- Administration: 15%.

The weighted skill value is:

\[
K_{\text{raw}}=
0.60E+0.25L+0.15A
\]

Where E, L, and A represent the official's skill ratings.

This raw value is converted to a suitable bounded work multiplier.

Minimum qualifications are checked separately.

## 9.4 Team progress

Team contribution should depend on the task structure.

For work that can be performed in parallel, individual contributions can be combined.

For work requiring sequential stages, later stages cannot advance until earlier stages are complete.

For work requiring coordination, the task may apply a team-efficiency multiplier.

The engine should therefore support three execution patterns:

- Parallel.
- Sequential.
- Coordinated.

## 9.5 Quality

Progress and quality are separate values.

A task may finish quickly but have reduced quality.

Quality affects relevant outcomes, including:

- Legal accuracy.
- Technical reliability.
- Financial forecasting.
- Administrative mistakes.
- Contractor supervision.
- Implementation performance.

## 9.6 Resources and dependencies

Work may require:

- Funding.
- Information.
- Materials.
- Contractor input.
- Legal authorization.
- Completion of preceding tasks.

Staff cannot overcome an absolute resource shortage merely through high skill ratings.

## 9.7 Completion

When a finite task finishes:

1. Completion conditions are verified.
2. The result is calculated.
3. Task history is updated.
4. The task is marked completed.
5. Its assignments end.
6. Staff return to the available pool.
7. The next dependent task becomes eligible, if applicable.
8. Completion appears in the next monthly briefing.

---

# 10. Personnel Management Interface

The personnel menu is the primary interface for staff administration.

## 10.1 Main personnel screen

The main screen contains:

- Available personnel.
- Assigned personnel.
- All personnel.
- Assignment history.

A summary displays:

- Total government personnel.
- Available personnel.
- Assigned personnel.
- Vacant government positions.
- Tasks needing qualified staff.
- Assignments requiring intervention.

## 10.2 Available-personnel list

Every available official appears as a selectable resource.

Each entry shows:

- Name.
- Personnel category.
- Party affiliation, if applicable.
- Primary specialization.
- Relevant skills.
- Talents.
- Work speed.
- Assign button.

Selecting Assign opens tasks with vacant positions.

## 10.3 Assigned-personnel list

Every assigned official appears with:

- Name.
- Current task.
- Current position within that task.
- Task progress.
- Assignment start date.
- Current status.
- View Report button.
- Unassign button.

The player must not have to navigate through individual projects merely to free personnel.

## 10.4 Personnel details

Selecting an official displays their complete profile.

The profile includes:

- Skills.
- Talents.
- Experience.
- Professional history.
- Current assignment.
- Previous projects.
- Performance record.
- Monthly reports.

## 10.5 Assignment through a task

When opening a task, the player sees every required position.

Each position displays:

- Role.
- Required skills.
- Required talents.
- Optional qualifications.
- Assigned official, if any.
- Vacant or filled status.

Selecting a vacant position opens eligible available personnel.

## 10.6 Assignment through the personnel menu

When selecting an available official, the game displays vacant positions for which that official is eligible.

This allows both workflows:

**Task → Select official.**

**Official → Select task.**

Both modify the same assignment records.

## 10.7 Candidate comparison

The assignment interface should display:

- Qualification status.
- Relevant skill ratings.
- Talent matches.
- Estimated contribution.
- Potential team benefits.

Mandatory requirements should be clearly distinguished from optional advantages.

---

# 11. Assignment Rules

## 11.1 Assignment creation

When the player confirms an assignment:

1. Validate staff availability.
2. Validate position eligibility.
3. Reserve the position.
4. Create the assignment record.
5. Link the assignment to the official and task.
6. Remove the official from the available pool.
7. Update the task's staffing status.

The assignment begins contributing work during the next monthly execution phase.

## 11.2 Assignment persistence

Assignments persist automatically between months.

The player does not need to renew them.

## 11.3 Multiple-person teams

Each official has an individual assignment to a position within the shared task.

Removing one official does not automatically remove the others.

## 11.4 One assignment per official

The initial model allows one active assignment per official.

This keeps the limited personnel resource clear and manageable.

If this proves excessively restrictive during balancing, a later system may permit minor duties within broader administrative portfolios.

Such expansion is not required for the first implementation.

---

# 12. Unassignment and Reassignment

## 12.1 Universal unassignment

The player can unassign any official during monthly planning.

The assigned-personnel list provides this action directly.

## 12.2 Unassignment effects

When an official is unassigned:

1. The assignment is closed.
2. The task position becomes vacant.
3. The official becomes available immediately.
4. The task retains completed progress.
5. Other assigned officials remain in place.
6. The task's readiness is recalculated.
7. The action is added to task history.

## 12.3 Mandatory position becomes vacant

If a mandatory position is vacant, work dependent on that position pauses.

Other independent activities may continue if their requirements are still satisfied.

## 12.4 Optional position becomes vacant

The task continues but loses the associated benefit.

## 12.5 Standing responsibility becomes vacant

The responsibility is recorded as unmanaged.

Routine activity may continue through existing institutions, but managerial supervision is absent.

## 12.6 Construction project implications

Removing a construction supervisor does not automatically stop the construction company.

The contractor may continue fulfilling its existing contract.

However, government oversight and certain administrative decisions may be delayed.

## 12.7 Reassignment

The player may immediately assign the freed official elsewhere.

No arbitrary reassignment penalty is imposed.

Consequences arise from the actual staffing changes.

## 12.8 Replacement

A replacement action should permit the player to select a new qualified official for a currently occupied position.

The system releases the existing official and assigns the replacement as a single validated planning operation.

The previous assignment remains in history.

## 12.9 Cancelling a task

Cancelling a task differs from unassigning personnel.

Cancellation may have legal, financial, political, or contractual consequences.

It must not be triggered accidentally by removing staff.

---

# 13. Long-Term Delegation

## 13.1 Delegation model

Assigned personnel carry out their tasks automatically during monthly simulation processing.

The player defines the objective and authorizes relevant activities.

The officials handle routine operations within those limits.

## 13.2 Delegated authority

Each assignment or task contains an authority profile defining what decisions can be made automatically.

Potential permissions include:

- Routine scheduling.
- Requesting information.
- Coordinating departments.
- Monitoring contractors.
- Performing technical reviews.
- Managing approved expenditures.
- Preparing documents.
- Reporting problems.

## 13.3 Limits of authority

Officials cannot exceed their permitted authority.

They cannot independently:

- Enact laws.
- Override parliament.
- Approve unauthorized major expenditure.
- Violate procurement rules.
- Ignore binding contracts.
- Change fundamental government policy.
- Enter major coalition agreements without authorization.

## 13.4 Delegated decisions

Routine authorized decisions should occur automatically.

They should be recorded in monthly reports and relevant project histories.

## 13.5 Escalation

A decision is escalated when it exceeds delegated authority.

Examples:

- Contractor demands additional funding.
- Technical specifications must change.
- Resources are unavailable.
- Coalition disagreement blocks action.
- A project requires new legislation.
- A major administrative failure occurs.

The report presents the issue and available responses.

## 13.6 Blocked work

When an escalation is unresolved, the affected work becomes blocked.

Other independent work may continue.

Blocked work should not automatically free its assigned staff. The player can choose whether to keep the team assigned or move personnel elsewhere.

## 13.7 Standing responsibilities

Standing assignments perform authorized routine management every month.

They do not have a predetermined completion point.

The official remains assigned until removed, replaced, or otherwise made unavailable.

---

# 14. Monthly Staff Briefing

## 14.1 Reporting requirement

Every government official provides a report at the beginning of each monthly turn.

This includes assigned and available staff.

The briefing represents work and events from the previous month's simulation.

## 14.2 Report contents

Every report stores:

- Reporting month.
- Official.
- Task or availability status.
- Individual role.
- Progress achieved.
- Work completed.
- Problems encountered.
- Actions taken automatically.
- Decisions requiring approval.
- Planned next steps.

## 14.3 Report categories

**Routine**

The assignment progresses without intervention.

**Attention**

An issue has occurred but work can continue.

**Decision Required**

An authorization or player decision is necessary.

**Completed**

A finite assignment has finished.

**Available**

The official has no active assignment.

## 14.4 Briefing presentation

The monthly briefing displays:

1. Critical decisions.
2. Completed tasks.
3. Important delays or risks.
4. Routine assigned-personnel updates.
5. Available-personnel updates.

Every report remains accessible, but routine reports can be collapsed.

The player should never be required to dismiss twenty individual routine notifications.

## 14.5 Team reports

Each team member reports on their specific responsibilities.

The shared task also has a consolidated report showing:

- Overall progress.
- Staff readiness.
- Resource readiness.
- Important problems.
- Current stage.
- Expected next steps.

## 14.6 Report accuracy

Reports must be generated from actual simulation state.

A report stating that construction is 60% complete must correspond to the project's recorded progress.

A reported contractor delay must exist in the contract or project records.

## 14.7 Reporting history

The game preserves monthly reports.

Older routine reports may be compressed for storage efficiency, but important events, decisions, personnel changes, and completed work must remain in the permanent history.

---

# 15. Monthly Turn Processing

The staff system follows a deterministic monthly sequence.

## Step 1 — Open monthly briefing

Display the reports produced by the previous month's execution.

Show current availability and urgent decisions.

## Step 2 — Player planning

The player can:

- Inspect reports.
- Assign available personnel.
- Unassign personnel.
- Replace team members.
- Start new tasks.
- Cancel tasks.
- Change priorities.
- Approve escalated decisions.
- Review government projects.

## Step 3 — Validate assignments

Before executing the month, verify:

- Personnel availability.
- Position qualifications.
- Mandatory team composition.
- Legal authority.
- Required task dependencies.
- Funding and resource availability.

## Step 4 — Calculate work

For eligible tasks:

- Calculate individual contributions.
- Apply team coordination.
- Apply relevant talents.
- Check resource availability.
- Advance work.
- Update quality and risk.

## Step 5 — Coordinate external systems

Relevant tasks interact with:

- Construction companies.
- Material supplies.
- Government budgets.
- Legislative procedures.
- Coalition negotiations.
- Public institutions.

## Step 6 — Resolve events

Process:

- Task completion.
- Errors.
- Delays.
- Administrative problems.
- Required decisions.
- Changes in project status.

## Step 7 — Award experience

Officials gain experience in skills relevant to the work performed.

## Step 8 — Release completed assignments

Finite assignments that have finished are closed.

Staff return to the available pool.

Standing responsibilities remain active.

## Step 9 — Generate monthly reports

Create reports for every official.

Generate consolidated reports for active tasks.

These appear when the following month begins.

---

# 16. Skill Development

## 16.1 Experience gain

Officials gain skill-specific experience while performing relevant work.

An engineer supervising construction improves relevant engineering and administrative skills.

A negotiator participating in coalition discussions improves negotiation-related competencies.

## 16.2 Experience calculation

Proposed formula:

\[
XP =
B \times D \times R \times L
\]

Where:

- \(B\) = base experience.
- \(D\) = task difficulty modifier.
- \(R\) = relevance of the skill.
- \(L\) = learning modifier.

The Fast Learner talent may affect \(L\).

## 16.3 Progression

Skill growth slows at higher ratings.

Experts should require substantially more experience to improve than beginners.

## 16.4 Training

Training is a special assignment.

Training:

- Occupies the official.
- Takes time.
- May cost money.
- Improves specified skills.
- Reduces the government's immediate available personnel capacity.

## 16.5 Professional history

Completed tasks contribute to an official's career record.

The record contains:

- Project participation.
- Position held.
- Duration.
- Performance.
- Significant achievements.
- Relevant failures.
- Skill development.

This history should remain after government transitions.

---

# 17. Political Integration

## 17.1 Political assignment authority

Certain government actions require political authorization.

An official with strong legal skills cannot enact legislation without parliamentary approval.

A skilled engineer cannot independently approve an unauthorized public project.

The staff system determines the capacity to prepare and implement decisions, not whether those decisions are legally permitted.

## 17.2 Coalition personnel

Coalition parties control their allocated political appointments according to the government agreement.

An official's party membership may influence their participation in politically sensitive tasks.

## 17.3 Disagreements

A political official may identify conflict between an assigned task and their party's commitments.

Possible outcomes include:

- Requesting clarification.
- Requesting renegotiation.
- Escalating the conflict.
- Refusing an instruction outside the agreed mandate.
- Triggering coalition discussions.

The political system determines the wider consequences.

## 17.4 Legislative drafting

Legislation may require a team containing:

- Legal expertise.
- Relevant policy expertise.
- Political coordination.
- Negotiation expertise.

More complex legislation may require larger teams or more work.

## 17.5 Coalition negotiations

Negotiation tasks may require several officials.

Relevant skills include:

- Politics.
- Negotiation.
- Economics.
- Law.
- Communication.

Team composition influences preparation, effectiveness, and negotiation outcomes.

## 17.6 Parliamentary approval

Successful completion of a drafting task produces a proposal.

It does not guarantee parliamentary passage.

The proposal enters the legislative system for negotiation and voting.

## 17.7 Government implementation

An approved law may create administrative tasks.

Officials must then be assigned to implement the legislation, monitor compliance, or supervise associated projects.

---

# 18. Economic and Contractor Integration

## 18.1 Economic constraints

Staff assignments do not bypass physical or financial constraints.

An infrastructure team still requires materials, contractors, funding, and logistical access to perform the relevant project work.

## 18.2 Procurement

Procurement tasks may require officials with:

- Administration.
- Economics.
- Engineering.
- Law.
- Logistics.

Skills affect bid evaluation, contract preparation, and oversight.

## 18.3 Contractor supervision

A supervising official may:

- Monitor progress.
- Examine reports.
- Identify delays.
- Verify milestones.
- Request corrective action.
- Report contract violations.

The contractor continues operating through the economic simulation.

## 18.4 Company failure

If a contractor becomes insolvent, its project may be interrupted.

The assigned official reports the failure and may recommend:

- Replacement procurement.
- Contract termination.
- Emergency financing, where lawful.
- Project suspension.
- Revised scheduling.

## 18.5 Budget control

Staff can manage approved budgets within their authority.

They cannot create additional government money.

## 18.6 Economic reports

Officials assigned to economic oversight may produce analysis of:

- Employment.
- Company activity.
- Government revenue.
- Industrial development.
- Supply shortages.
- Public spending.
- Investment performance.

These reports should draw from the actual economic simulation.

---

# 19. Government Transitions

## 19.1 Election results

After an election, government formation determines the political positions available to each coalition party.

## 19.2 Political appointments

When political positions change:

- Departing political officials lose government authority.
- Their assignments are reviewed.
- Vacant positions are created where required.
- Incoming political staff may be appointed.
- Existing task progress is preserved.

## 19.3 Permanent administration

The ten permanent civil servants continue in the administration.

Their:

- Skills.
- Talents.
- Experience.
- Career histories.
- Institutional knowledge.

remain intact.

## 19.4 Inherited projects

The incoming government inherits ongoing public projects, financial commitments, and administrative responsibilities.

It can decide whether to continue, modify, or cancel them through the relevant legal and political mechanisms.

## 19.5 Unstaffed inherited work

If a departing political official occupied a mandatory position, that position becomes vacant.

The new government may assign a replacement.

Work dependent on the position remains paused until staffing requirements are satisfied.

## 19.6 Coalition allocation and vacancies

The government has ten political positions, but a position may temporarily be vacant during appointments or coalition changes.

A vacant position does not automatically provide an available official.

The position must be filled through the appointment system.

---

# 20. Opposition Gameplay

## 20.1 Loss of government

When the player loses power, they no longer control the government's political appointments or permanent civil servants.

Government work continues under the incoming administration.

## 20.2 Opposition personnel

The player's party receives a separate opposition personnel capacity.

This pool supports:

- Policy research.
- Legislative drafting.
- Parliamentary negotiations.
- Government oversight.
- Election preparation.
- Public communication.
- Party organization.

The exact size of the opposition pool remains a political-system balancing decision.

## 20.3 Shared personnel engine

Opposition staff use the same:

- Skills.
- Talents.
- Assignment rules.
- Task requirements.
- Progress calculations.
- Monthly reporting.
- Experience development.

There should not be an unrelated simplified staff system for opposition gameplay.

## 20.4 AI government

An AI-controlled government must use the same staffing rules as the player.

It must:

- Fill mandatory positions.
- Assign qualified officials.
- Manage long-term work.
- Respond to missing qualifications.
- Reassign staff.
- Handle monthly administrative developments.

AI governments may use automated assignment decisions, but they must remain subject to personnel limitations.

## 20.5 Returning to power

If the player returns to government:

- They gain access to the new government's allocated political positions.
- Permanent civil servants remain available to the government.
- Existing project assignments and institutional history remain intact.
- New political assignments can be made.

The player should not automatically regain officials who are no longer eligible for appointment.

---

# 21. Retirement and Personnel Legacy

When the player retires, the game should preserve staff and administrative history.

The retirement summary may include:

- Major government programs completed.
- Number of officials appointed.
- Administrative reforms.
- Significant project successes.
- Major failures.
- Long-serving civil servants.
- Institutional improvements.
- The condition of ongoing projects.

Optional observation mode allows the colony to continue operating under AI leadership.

Personnel and administrative institutions continue functioning after retirement.

---

# 22. Technical Data Structures

The following structures describe the minimum data required for implementation.

## 22.1 StaffMember

```text
StaffMember
    id
    name
    category
    party_id
    position_id

    skills {
        administration
        economics
        engineering
        logistics
        law
        negotiation
        politics
        communication
        environmental_management
        public_services
    }

    talents[]

    work_speed
    reliability
    experience_by_skill

    employment_status
    availability_status
    active_assignment_id

    career_history[]
```

## 22.2 TalentDefinition

```text
TalentDefinition
    id
    name
    description

    applicable_task_categories[]
    activation_conditions[]
    effects[]

    stacking_rule
```

## 22.3 TaskDefinition

```text
TaskDefinition
    id
    name
    description
    category

    required_positions[]
    optional_positions[]

    execution_mode
    base_work_required

    resource_requirements[]
    authorization_requirements[]
    prerequisite_task_ids[]

    completion_effects[]
    failure_conditions[]
```

## 22.4 TaskPosition

```text
TaskPosition
    id
    task_id
    role_name

    mandatory

    minimum_skills[]
    preferred_skills[]
    required_talents[]
    preferred_talents[]
    alternative_qualification_paths[]

    assigned_staff_id
    contribution_weights[]
```

## 22.5 TaskInstance

```text
TaskInstance
    id
    definition_id
    project_id

    owner_id
    target_entity_id

    status
    progress
    quality

    start_month
    expected_completion_month

    authorized_budget
    resource_status

    positions[]
    decision_requests[]
    history[]
```

## 22.6 Assignment

```text
Assignment
    id
    staff_id
    task_id
    position_id

    start_month
    end_month

    status
    delegated_authority
    reporting_configuration
```

## 22.7 StaffReport

```text
StaffReport
    id
    staff_id
    assignment_id
    task_id

    month
    report_category

    progress_change
    total_progress

    completed_actions[]
    problems[]
    decisions_required[]
    next_steps[]
```

## 22.8 Project

```text
Project
    id
    name
    category

    status
    total_progress

    authorized_budget
    actual_expenditure
    outstanding_commitments

    assigned_contractors[]
    task_ids[]
    prerequisites[]

    start_month
    history[]
```

## 22.9 GovernmentStaffPool

```text
GovernmentStaffPool
    government_id

    political_position_ids[]
    civil_servant_ids[]

    party_position_allocations{}

    filled_positions[]
    vacant_positions[]

    available_staff_ids[]
    assigned_staff_ids[]
```

---

# 23. Data Integrity Requirements

The implementation must enforce the following invariants.

1. Every active official has at most one active assignment.
2. Every active assignment references a valid official.
3. Every active assignment references a valid task.
4. Every assignment references an existing task position.
5. A position has at most one assigned official.
6. Mandatory qualifications are validated.
7. Available staff cannot simultaneously be assigned.
8. Unassigning staff preserves task progress.
9. Completing a task releases its assigned personnel.
10. Standing responsibilities persist until explicitly ended.
11. Government transitions preserve institutional records.
12. Political positions cannot be occupied by ineligible personnel.
13. Every completed monthly turn generates a status report for every active government official.
14. Staff may not authorize operations beyond delegated authority.
15. Project progress and personnel progress must remain consistent with the relevant task records.
16. Save and load must preserve assignments, staffing vacancies, and task history.

Assignment, replacement, and unassignment operations should be atomic. Either the complete operation succeeds or the previous valid state is retained.

---

# 24. Development Roadmap

## Phase S1 — Personnel Foundation

**Objective:** Create individual government staff.

Tasks:

- Implement StaffMember.
- Implement political and permanent categories.
- Add the ten skills.
- Add work speed and reliability.
- Implement experience tracking.
- Implement talents.
- Add employment and availability states.
- Generate initial government personnel.
- Implement serialization and loading.

**Completion criteria:** Twenty government staff can be generated, saved, loaded, and inspected without losing their attributes.

## Phase S2 — Task and Position Definitions

**Objective:** Define work and staffing requirements.

Tasks:

- Implement TaskDefinition.
- Implement TaskInstance.
- Implement TaskPosition.
- Add mandatory positions.
- Add optional positions.
- Add skill requirements.
- Add talent requirements.
- Add alternative qualification paths.
- Add prerequisite tasks.
- Add task categories.
- Add execution modes.

**Completion criteria:** A task can require several differently qualified officials and accurately determine whether its staffing requirements are satisfied.

## Phase S3 — Assignment Engine

**Objective:** Allocate personnel to tasks.

Tasks:

- Implement Assignment.
- Add availability checks.
- Add qualification validation.
- Implement assignment creation.
- Implement unassignment.
- Implement replacement.
- Implement automatic release.
- Prevent duplicate assignments.
- Preserve task progress after staffing changes.

**Completion criteria:** Staff can be assigned, unassigned, and replaced without corrupting existing tasks.

## Phase S4 — Personnel Interface

**Objective:** Make staffing manageable through the user interface.

Tasks:

- Build available-personnel list.
- Build assigned-personnel list.
- Build complete roster.
- Add personnel profiles.
- Add assignment history.
- Add task staffing slots.
- Add qualification comparison.
- Add talent display.
- Add task-to-person assignment workflow.
- Add person-to-task assignment workflow.
- Add direct Unassign controls.

**Completion criteria:** The player can manage all twenty officials through the interface without manually editing task data.

## Phase S5 — Work Progression

**Objective:** Make assigned personnel perform work.

Tasks:

- Implement work units.
- Implement individual contribution calculations.
- Implement team contributions.
- Implement skill modifiers.
- Implement work-speed modifiers.
- Add task quality.
- Add parallel task execution.
- Add sequential task execution.
- Add coordinated task execution.
- Implement completion.
- Implement automatic staff release.

**Completion criteria:** Different qualified teams complete tasks at different rates and produce appropriately different outcomes.

## Phase S6 — Talents and Staff Development

**Objective:** Make personnel distinctive and capable of growth.

Tasks:

- Implement talent activation.
- Implement talent bonuses.
- Add stacking limits.
- Add skill experience.
- Add skill progression.
- Add diminishing experience returns.
- Implement training assignments.
- Store career history.

**Completion criteria:** Talent selection and professional experience produce measurable, explainable differences in performance.

## Phase S7 — Delegation and Long-Term Work

**Objective:** Reduce micromanagement.

Tasks:

- Implement persistent assignments.
- Add standing responsibilities.
- Add delegated authority profiles.
- Implement automatic routine work.
- Add blocked and paused states.
- Add decision escalation.
- Connect tasks to multiyear projects.
- Preserve work when staff are removed.
- Support unmanaged responsibilities.

**Completion criteria:** The player can assign a team to a long project and advance several months without having to repeat orders.

## Phase S8 — Monthly Reporting

**Objective:** Provide transparent administrative oversight.

Tasks:

- Implement StaffReport.
- Generate individual monthly updates.
- Add report categories.
- Add report priority.
- Generate consolidated task reports.
- Implement the monthly briefing.
- Add links from reports to assignments.
- Add report history.
- Implement historical report compression.

**Completion criteria:** Every official reports monthly, major problems are visible, and routine progress does not require repetitive interaction.

## Phase S9 — Economy and Contractor Integration

**Objective:** Connect administrative work to real economic outcomes.

Tasks:

- Connect tasks to construction projects.
- Connect officials to contractor oversight.
- Add procurement tasks.
- Add budget supervision.
- Add resource-dependent task progress.
- Add contract failure reporting.
- Add project milestone verification.
- Add government economic programs.
- Ensure contractor activity continues independently when permitted.

**Completion criteria:** Personnel can supervise economic projects without replacing the companies, workers, materials, and financial systems that actually execute them.

## Phase S10 — Political and Legislative Integration

**Objective:** Make staff necessary for government policy.

Tasks:

- Add legislative drafting assignments.
- Add coalition negotiation assignments.
- Add budget preparation assignments.
- Connect political staff to party affiliations.
- Implement political authority requirements.
- Add coalition disagreement escalation.
- Add implementation tasks generated by approved laws.
- Add parliamentary oversight assignments.

**Completion criteria:** Government policy requires appropriate staff and authorization, and administrative capacity limits the government's ability to implement simultaneous initiatives.

## Phase S11 — Elections, Opposition, and Government Transitions

**Objective:** Support personnel continuity through political change.

Tasks:

- Implement coalition staff allocation.
- Add government appointments.
- Add political position vacancies.
- Implement government transitions.
- Preserve permanent civil servants.
- Preserve ongoing projects.
- Transfer government assignments.
- Implement opposition personnel.
- Implement AI government staffing.
- Restore government access following electoral victory.

**Completion criteria:** The player can lose power, continue in opposition, and later return to government without administrative records or ongoing projects being lost.

## Phase S12 — Balancing and Optimization

**Objective:** Make the system strategically meaningful and sustainable.

Tasks:

- Balance skill thresholds.
- Balance talent strength.
- Balance staff work speed.
- Balance task duration.
- Balance team requirements.
- Adjust experience progression.
- Test the availability of qualified staff.
- Reduce repetitive decision requests.
- Evaluate standing responsibility costs.
- Test AI staffing decisions.
- Optimize reports and historical storage.
- Test extended campaigns.

**Completion criteria:** The staff system remains functional, understandable, and strategically interesting across multidecade campaigns.

---

# 25. Test Plan

## Test A — Single-person assignment

Create a task requiring one qualified official.

Assign an available official.

Expected result: The official becomes assigned and cannot be selected for another active task.

## Test B — Multiple-person requirement

Create a task requiring three officials.

Assign only two.

Expected result: The task identifies the missing mandatory position and cannot begin the dependent work.

## Test C — Different skill requirements

Create a project requiring engineering, logistics, and administration.

Attempt to fill every position with officials qualified only in administration.

Expected result: Ineligible placements are rejected.

## Test D — Alternative talent qualification

Create a task position allowing either advanced economics or administration combined with a procurement talent.

Expected result: Both qualification paths are accepted.

## Test E — Optional specialist

Start a fully staffed task.

Assign an optional specialist.

Expected result: The applicable performance benefit is added.

Remove the specialist.

Expected result: The task continues without that benefit.

## Test F — Persistent assignment

Assign officials to a 24-month administrative responsibility.

Advance twelve turns.

Expected result: Their assignments remain active without repeated instructions.

## Test G — Individual unassignment

Remove one official from a four-person team.

Expected result: Only that official is released.

Other staff remain assigned.

## Test H — Task progress preservation

Advance a task to 60% completion.

Unassign its lead official.

Expected result: The task retains 60% progress.

## Test I — Replacement

Replace a mandatory team member with another qualified official.

Expected result: The task resumes without resetting progress.

## Test J — Standing responsibility

Assign an official to routine infrastructure oversight.

Advance 48 months.

Expected result: The assignment remains active until changed.

## Test K — Monthly reporting

Advance a month with twenty active government personnel.

Expected result: Twenty individual reports are generated.

Unassigned personnel produce availability reports.

## Test L — Delegated authority

Assign an official authority to manage routine expenditure within an approved budget.

Expected result: Permitted actions happen automatically.

An action exceeding authority generates a decision request.

## Test M — Contractor failure

Assign a staff team to supervise a construction contract.

Make the contractor insolvent.

Expected result: The task reports the problem and the construction project's actual state is preserved.

## Test N — Government transition

Replace the governing coalition.

Expected result: Political appointments change, permanent officials retain continuity, and projects preserve progress and history.

## Test O — Opposition

Move the player into opposition.

Expected result: Government staff are no longer under player control, and an opposition staff pool becomes available.

## Test P — Save and load

Save a game containing active teams, vacancies, standing responsibilities, blocked tasks, and pending decisions.

Reload.

Expected result: All personnel relationships and statuses remain identical.

## Test Q — Long-term simulation

Run an automated 20-year campaign.

Expected result:

- No duplicate personnel assignments.
- No orphaned task positions.
- No disappearing projects.
- No unintended progress resets.
- No unauthorized staff actions.
- No missing mandatory reports.
- Government transitions preserve institutional history.

---

# 26. Minimum Playable System

The first complete playable version of this subsystem requires:

1. Twenty government staff positions.
2. Political and civil servant categories.
3. Individual skill ratings.
4. Individual talents.
5. Available and assigned personnel views.
6. One or more mandatory positions per task.
7. Position-specific skill requirements.
8. Tasks requiring several people.
9. Optional specialist positions.
10. Assignment from either the task or personnel menu.
11. Direct unassignment.
12. Immediate reassignment during planning.
13. Persistent assignments across monthly turns.
14. Task progress based on staff contributions.
15. Separate task progress and project progress.
16. Long-term delegated work.
17. Standing responsibilities.
18. Monthly individual reporting.
19. Consolidated team reporting.
20. Escalation of decisions outside delegated authority.
21. Automatic release after finite task completion.
22. Preservation of progress when personnel change.
23. Save and load support.

Government transitions, opposition staffing, advanced skill development, and more extensive talents may be added after this core system is operational.

---

# 27. Complete Gameplay Acceptance Scenario

A complete system test should simulate the following sequence.

## Month 1

The player begins with twenty government officials.

Fourteen are assigned and six are available.

The monthly briefing contains:

- A highway project progressing normally.
- A mining project lacking logistical coordination.
- A completed legal drafting task.
- A hospital construction project experiencing material shortages.
- Routine reports from all other officials.

The player reviews the reports.

Two officials have completed their work and are available.

The player opens the mining project.

It requires three positions:

- Engineering lead.
- Logistics coordinator.
- Administrative supervisor.

Two positions are filled.

The logistics position is vacant.

The available-personnel list shows that none of the currently free officials meets the mandatory logistics requirement.

The player opens the assigned-personnel list.

An experienced logistics specialist is supervising a lower-priority transport improvement project.

The player unassigns that specialist.

The lower-priority task retains its progress, but the work requiring logistical supervision is paused.

The specialist immediately enters the available pool.

The player assigns that specialist to the mining project.

All three required positions are now filled.

The player also assigns the two officials released from legal drafting to a new taxation proposal.

The player ends the month.

## Month 2

The simulation processes all assignments.

The mining team advances its administrative work.

Its engineering lead handles technical requirements.

Its logistics coordinator organizes supply deliveries.

Its administrator manages the approved budget and reports.

The lower-priority transport improvement remains partially paused.

The taxation team begins drafting legislation.

The highway and hospital contractors continue working according to their material availability, contracts, and supervision.

At the beginning of the month, all officials provide updated reports.

One report indicates that the mining project has advanced successfully.

Another reports that the transport improvement is still missing a coordinator.

The player may now choose to restore staffing to that task, leave it paused, or reorganize other responsibilities.

## Month 3 onward

Tasks continue automatically.

The player focuses on:

- New government priorities.
- Important administrative problems.
- Staff shortages.
- Political negotiations.
- Legislative decisions.
- Project failures or delays.
- Reallocating personnel when circumstances change.

The player does not repeatedly instruct unchanged teams to continue working.

## Election transition

At the end of the political term, another coalition takes power.

Political positions are reallocated.

Permanent civil servants remain employed.

The highway, mine, and hospital retain their recorded physical progress.

Existing contracts and government obligations remain in the simulation.

The new government assigns officials to ongoing responsibilities.

If the player enters opposition, they continue with an opposition-oriented personnel pool.

The complete administrative history remains available as appropriate to the player's political position.

---

# 28. Outstanding Design Decisions

These decisions remain open and must be resolved before implementing the relevant mechanics.

| Decision | Proposed default | Required by phase |
|---|---|---|
| Exact skill-to-speed multipliers | Bounded weighted formula | S5 |
| Work-unit values | Task-specific, configurable | S5 |
| Maximum staff per task | Defined by task positions | S2 |
| Optional staff effectiveness | Diminishing returns | S5 |
| Talent stacking | Limited, explicit rules | S6 |
| Experience gain rate | Based on difficulty and relevance | S6 |
| Training duration | Depends on skill level | S6 |
| Temporary staff unavailability | Rare initially | S6–S7 |
| Delegated spending limits | Task authorization based | S7 |
| Reporting frequency | Monthly for every official | S8 |
| Coalition appointment procedure | Negotiated political appointments | S11 |
| Political staff vacancy rules | Vacancies permitted | S11 |
| Opposition personnel count | To be balanced with political gameplay | S11 |
| AI assignment priorities | Role suitability, urgency, policy priority | S11 |
| Retirement and observation | Preserve institutional histories | Later integration |

These are explicit open decisions, not missing mechanics to be invented during coding.

---

# 29. Final Acceptance Criteria

The staff system is complete when all of the following are true:

- The player can inspect the entire personnel pool at any time during planning.
- Every person has individual skills, talents, and work speed.
- Tasks can require specific combinations of qualified officials.
- The player can form teams from available personnel.
- Assignments persist automatically between months.
- Long-term work can continue for years.
- Standing responsibilities operate without a fixed end date.
- Officials independently perform authorized routine work.
- The player receives individual monthly reports from every official.
- Team tasks produce consolidated progress reports.
- Important problems generate meaningful intervention requests.
- Personnel can be unassigned directly from a centralized list.
- Released personnel can immediately accept new work.
- Reassignment never destroys completed project progress.
- Mandatory staffing shortages have predictable consequences.
- Task completion correctly releases personnel.
- Experience and talents influence performance.
- Political staff and civil servants behave according to their different institutional roles.
- Coalition agreements and political authority affect eligible assignments.
- Government changes preserve project and institutional history.
- The same mechanics work for AI governments.
- Opposition gameplay uses the same personnel architecture.
- Save and load preserve the entire system.
- Extended simulation does not produce contradictory or invalid staff states.

**Final design principle:** The personnel system must make the player's decisions about *who performs which work, with what qualifications, and for how long* strategically important, while ensuring that ordinary execution happens automatically. The challenge should come from limited competent personnel, competing objectives, and political and economic constraints—not repetitive administrative clicking.
