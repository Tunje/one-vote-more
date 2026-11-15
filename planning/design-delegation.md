# Who decides: the First Minister, the ministers and the desk (Wilma, 2026-11-15)

Status: design from the user's ruling; nothing coded. Replaces my first sketch (a fixed rule that only large or
irregular things reach the desk), which the user rejected.

User: "No, I think it's wrong. You need to see the decisions. What should happen is: at term start you get every
decision type and can elect what level the minister takes it on, and if no minister has it you can hand it over. The
limits are: make calls (they take the decision and you get a note in your monthly summary), give me suggestions (you get
a pre-selected decision), or leave it to me. You can change this later, but leaving someone without any is negative for
them; the more they have, the more they feel you trust them. Imagine if you let the ministers of one of your allied
parties make no decisions at all." And: "I think you're underestimating how much will be on the desk year 50+", "and
this is where municipalities come in."

## 1. Decision types
Every decision a government takes is a registered **decision type**: a name, the portfolio it belongs to (the cabinet
already has portfolios: Finance, Economy, Labour, Infrastructure/Engineer, Home world, Services, Environment, ...), how
often it comes up, and its legal ceiling (section 4). Systems post a *case* of a type to the office instead of deciding
by themselves; today most of this week's decisions (grant programmes and their districts, wildlife policy, bailouts,
tariff approvals, budget requests, public builders, road works, price rises on public projects) are decided by code
with no minister in sight.

**Portfolios (user, 2026-11-15):** "Minister of agriculture, homeworld liaison, minister of education (once we add
more)". Today's portfolios: Finance, Economy, Labour, Infrastructure, Home-World Affairs, Public Services, Environment,
Justice, Leader of the Assembly. Home world exists. **Agriculture is new**: farms, family-farm programmes and their
districts, food stocks, wildlife trouble on farms (today split between Economy and Environment). **Education is new,
later**: it splits out of Public Services once there is more to decide in education than a budget.

## 2. Three levels, chosen per decision type
- **Make the call:** the minister decides. The First Minister gets a line in the monthly summary: what was decided
  and why.
- **Give me a suggestion:** the case comes to the desk with the minister's choice pre-selected; the First Minister
  confirms or picks another option.
- **Leave it to me:** the case comes to the desk with the options and the minister's advice, nothing pre-selected.
A type whose portfolio has no minister (vacant, or a new kind of decision) stays with the First Minister until it is
handed to a minister of the First Minister's choosing; a minister deciding outside their portfolio does it worse.

## 3. When it is set
- **At the start of a term** (a new government): one screen with every decision type, grouped by minister, with the
  level for each. Presets to fill it quickly (trusting / balanced / hands-on), then adjust.
- **Any time later**, per type. Taking decisions away from a minister mid-term is noticed (section 5).

## 4. What the law fixes (Anni's notes, planning/design-law-*.md)
Some cases are Cabinet matters by law whatever the level: a large concession, ending one without cause, a merger to
dominance or in a utility market, selling a utility or a strategic plant, a public sale far below book, state aid above
the threshold, cancelling a flagship project. Those always come to the desk at least as a suggestion; a minister who
takes one alone commits an unlawful government act, found through the usual channels. Parliament keeps the laws.

## 5. Trust
- A minister's **standing** rises with what they are trusted with: the share of their portfolio's decision types they
  may call, weighted by how often those come up; "suggest" counts for part, "leave it to me" for nothing.
- **A minister with nothing to decide resents it.** For a minister from a coalition partner, that resentment is the
  partner's: it feeds the coalition's cohesion (GovCrisis) and the partner's price at the next formation. A partner
  whose ministers decide nothing is a partner on the way out.
- **Overruling** a suggestion, and **taking a type away** mid-term, cost standing; handing more over raises it.
- The other side of trust is risk: a minister decides by their own lean (today 60% party line, 40% their own) and
  their skill, so a weak or partisan minister makes calls the First Minister would not have, and owns up to them only
  in the summary. An unlawful call is the government's scandal.

## 6. The monthly summary
One page: decisions ministers took this month (grouped by minister: what, the option, one line of why), cases
waiting on the desk, and what came of last month's decisions where that is known. This replaces a stream of separate
items for anything delegated.

## 7. Computer-run governments
The same system. A computer-run First Minister sets levels from character and politics (a controlling one keeps more,
a weak one in a broad coalition hands more out), and coalition partners can demand a free hand in their portfolios as
part of the coalition agreement. Their ministers then decide as described, with the same risks.

## 8. How much reaches the desk
My rough count (10 to 20 decisions a month once this week's features are in) was a guess, and the user expects far
more by year 50. Before tuning anything: count it. Step 1 of the build is the registry plus a counter of cases by type
and month in the chronicle, on the 100-year games, so the real load by decade is known.

## 9. Municipalities (user: "this is where municipalities come in") — not designed here
A colony of 26,000 people in six towns should not have its First Minister deciding which junction gets a roundabout.
Local decisions (local roads, clinics and schools, where a family farm programme lands, local zoning, a town's
wildlife troubles) would belong to town or district councils with their own elected politics and budgets, and never
reach the Cabinet. That is a new layer of government, with its own elections and money, and ties to the user's
settlement notes (planning/plan-settlement-later.md). It needs the user's decision before any design.

## Build order (after the user's review)
1. The decision-type registry and the case counter; the chronicle reports cases by type and decade.
2. Levels per type, the term-start screen and the monthly summary; existing office items (union demands, staff
   requests) become cases of registered types.
3. Route this week's government decisions through it, one system at a time (grant programmes, wildlife policy,
   bailouts, tariff approvals, budget requests, road works, public builders and concessions).
4. Trust and standing, the coalition effect, computer-run First Ministers setting levels.
