# Public safety: crime, police, criminal courts, prisons (A60, 2026-11-13)

User: "At this point do we need prisons?" → "what about police, they are linked to this" → "Queue both, police first".
Reverses J17 ("public safety/crime is post-v1 with police"). Spec: justiceAndLaw.md §14.7 (imprisonment), §15 (police).
Queue position: after Bob's support-economy pieces (offices A/B, §8b services, §8c buses, §9 warehouses).
Everything opt-in (meta["on"]) with its own A/B; integer state; RNG streams; --check-only every edited file.

## Phase P1 — crime + police (first)

### P1a Crime (Bob: economic drivers; Anni: offence types and records)
- Per district, monthly offence counts by kind: THEFT, VIOLENCE, FRAUD (later: DRUGS, VANDALISM).
- Drivers: unemployment, hunger (food shortfall), workplace stress, inequality, informal housing/homelessness,
  stock worth stealing (warehouses §9), youth share; dampers: police presence, clearance rate (deterrence),
  trust in police, public services.
- Calibrate to roughly Swedish levels at full employment; must rise visibly in a slump.
- New indicator POL/LAW_CRIME_RATE (district) feeding SAFETY (and FAIRNESS for fraud); victims/press facts.

### P1b Police (Anni owns; Terra draws; Bob pays)
- POLICE_STATION facility per district or covering neighbours; staff: officers (Sp/G tiers) + civilian support
  (dispatch, clerks, cleaning, vehicle upkeep) — same support-staff rules as everyone else (A56).
- Size reference: ~200 officers per 100k (Sweden) → ~20 for 10k colonists + ~8 civilian.
- Budget lever LAW_BUDGET_POLICE (Bob's budget table) and a powers law LAW_POLICE_POWERS
  (search/detention/surveillance; INSTITUTIONS axis: liberty vs order).
- Effects per district: response time, clearance rate (share of offences solved), detection of company and political
  crime as a second channel beside the inspectorate.
- Workload/stress (A57): understaffed police → slower response, more errors, burnout, misconduct.
- Police misconduct (§15.4): unlawful detention, excessive force, corruption, improper searches → records via the
  existing violation/reveal chain; press and inquiries.
- Political control (§15.5): government sets budget, law and structure; arresting opponents needs an unlawful path
  (unlawful action reveal, courts, press) and feeds authoritarian drift.

### P1c Politics (Wilma)
- SAFETY concern now driven by crime too; a "crime" hot issue for Ella's campaigns.
- Party positions: tough on crime (police, powers, sentences) vs prevention (jobs, services, rehabilitation).
- Scandals: district left unpatrolled after cuts, crime wave, brutality, corrupt officer.

## Phase P2 — criminal courts + prisons (second)
- Criminal cases through the existing courts: arrests → charges → verdicts → sentences (fine, community service,
  prison). Convicted CEOs and politicians can actually go to prison (removes them from posts).
- PRISON facility (Anni; Terra draws): capacity, guards and support staff, budget lever LAW_BUDGET_PRISONS,
  sentencing law (lenient ↔ harsh). Scale: Sweden ~70/100k → ~7 inmates at 10k; US ~500/100k → ~50.
- Overcrowding → stress, riots, escapes, scandals blamed on budget cuts; rehabilitation lowers reoffending.
- Repeat offenders (Anni's ×2 fine rule extends to sentences).

## Owners
Anni: offence model, police institution, criminal procedure, prisons. Bob: economic crime drivers, police/prison
wages and budget lines, theft from stock. Terra: stations and prisons on the map. Ella: crime as a campaign issue.
Wilma: concerns, party positions, legislature, integration, A/Bs and chronicles.
