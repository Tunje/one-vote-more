# Spec: The office: one workflow for the player's turn (v1)

User decision 2026-11-13 (A44): "the political turn needs a once-over… so many systems, so many things to do in
office, it needs a uniform workflow. Reports on your desk to look through, then emails on your PC that you need to
respond to — proposals and updates from your 20-man team. Your ordered newspaper on top of the desk that you read
first, if you have one." + "Swap between the two views in settings" + "the hiring process of your staff — click a
door, a candidate in front of you, ask questions; you don't know their stats when hiring."

Today every system has its own window (Legislate, Personnel, Staff briefing, Projects, Budget, Unions, Trade,
Campaign…) and the player must remember to visit each one. The office makes every system speak through **one
channel** and gives the turn a rhythm: read the paper, read the reports, answer the inbox, take calls, end the month.

Owners: **Wilma** O1–O4, O6 (channel, desk, inbox UI, calendar, settings), **Anni** O5 (staff as authors, hiring
interviews, delegation by staff skill), **Ella / Bob / Terra** feed their systems through the channel. The existing
windows stay as the "files and tools" behind items — nothing is lost.

## O1. The channel (Wilma; every owner sends through it)

One table `office_item` (integer state, saved): `{id, kind: PAPER|REPORT|EMAIL|CALL|MEETING|CALENDAR, from: staff
person id or org/union/party/home_world, role, subject, summary, recommendation, options: [{id, label, action}],
deadline, default_option, priority 0..100, source: {system, ref}, status: NEW|READ|ANSWERED|DELEGATED|EXPIRED,
answer, month}`.
- REPORT: read-only information (engineers' traffic report, oversight report, polls, budget outlook, economy and
  union status, trade). Marked read; can link to the detailed window.
- EMAIL: needs an answer. Options map to the same actions the windows use (EconActions/PolActions/staff actions):
  union demands, engineers' fixes, tenders, coalition partners' prices, petitions to the home world, emergency
  measures, drafts ready to table, budget requests, incentive offers, hiring shortlists.
- CALL (red phone): urgent, interrupts — strike called, famine, no-confidence motion, fatal crash, home-world ship
  or envoy, general strike. Must be answered (or explicitly deferred) before the month ends.
- MEETING request: union leaders, company bosses, coalition partners, a home-world envoy, party rebels; accept
  (resolves or softens the issue, costs time) or refuse (consequences).
- CALENDAR: upcoming dated events (election, next ship ±, deadlines, votes, congress, debates, budget day).
- Each system calls `Office.post(world, item)` when something needs the player, and reads the answer from the
  item (or receives it through its normal action). Items for an AI-held office are answered by the AI as today.

## O2. The month's rhythm (Wilma)

- The turn opens on the **paper** (if subscribed), then the desk.
- **End month** warns if CALLs or past-deadline EMAILs are open; unanswered items fall to their `default_option`
  (usually refuse or delay), with consequences, and are logged ("You didn't answer the Builders' Union").
- The governor's time is limited: meetings and some answers cost "office hours" (a small monthly budget), so the
  player prioritises; delegation (O5) frees hours.

## O3. The desk view (Wilma)

- **Newspaper on top**: the paper(s) you subscribe to (choose in the desk; subscriptions cost a little). Its slant is
  what you read — the press secretary's digest (O5) gives a cross-paper view, with their own slant.
- **In-tray**: REPORTs, newest first, unread marked.
- **PC**: the inbox (EMAILs) sorted by the chief of staff (O5) by priority and deadline.
- **Red phone**: lit when a CALL waits.
- **Wall calendar**: next 12 months.
- **Door**: visitors (meetings) and **hiring interviews** (O5).
- **Window**: the colony map / globe outside.
- Out of office (opposition): the same desk as **party leader** — party reports, polls, campaign, union contacts,
  inbox from party staff. Founding era: the **commander's** desk.

## O4. Two views, swappable in settings (user)

- **Office** view: a single drawn scene with the paper, in-tray, PC, phone, calendar, door and window as
  clickable objects.
- **Tabs** view: the same content as plain tabs (Paper · Reports · Inbox · Calls · Calendar · Visitors), styled
  like an office, faster to use.
- Setting `ui.office_view = OFFICE | TABS`, saved in user settings (not in the world state); both read the same
  `office_item` table.

## O5. Staff: authors, filters, delegation and hiring (Anni)

- **Every item has an author** from the player's team (~20 people: chief of staff, finance, legal, press secretary,
  engineers, economic adviser, union liaison, home-world liaison…). Their skill and leanings colour what you get:
  - the **chief of staff** sorts the inbox; a weak one mis-prioritises or buries an important email under routine;
  - the **press secretary** writes the press digest with their own slant;
  - an adviser's recommendation follows their skill and ideology (a market-minded finance adviser recommends the
    market option); summaries from weak staff can be wrong or incomplete.
- **Delegation**: the player can hand a category to a staffer ("routine tenders to finance"); the staffer then
  answers those emails by their own skill and leanings. Explicit and revocable — not hidden autopilot.
- **Hiring by interview (user)**: clicking the **door** with an open vacancy brings in candidates one by one. Their
  stats are **hidden**. The player asks questions from a set (experience, a technical scenario, a political
  position, a "why did you leave" question, a stress question, references); each answer gives a noisy signal of a
  hidden trait (skill, integrity, ideology, loyalty, temper), better questions cost more interview time. Candidates
  with low integrity can bluff; references can be checked (costs a month); a weak HR adviser's notes are less
  reliable. The player hires on impressions; true stats show only through work. AI offices keep picking by the
  existing merit rule.

## O6. Migration of today's windows (Wilma)

- Staff briefing → REPORTs + EMAILs; Personnel → the door (hiring) and a staff list; Legislate → drafts arrive as
  EMAILs ("draft ready to table") with a link to the drafting tool; Projects/Budget/Trade/Unions/Campaign stay as
  tools, their pending decisions arrive as EMAILs.
- Toolbar shrinks to: Office · Map · Tools (the old windows) · Help.

## Acceptance

- Every player-facing decision in the current game reaches the player as an office item (audit list in O6).
- A full governing year can be played from the office without opening a tool window.
- Unanswered items expire to their defaults with visible consequences; nothing is decided silently.
- Both views show the same items; switching the setting changes nothing in the world.
- Hiring by interview: two candidates with different hidden stats are distinguishable on average by questions, but
  not reliably on one interview (tested statistically).
