extends RefCounted
## MEDIA v1 constants (planning/spec-media-v1.md). Owner: Anni (law/justice).

const MAX_OUTLETS := 8
const A_NONE := 0.35                # appeal of "no paper" (word of mouth) in the diet (§4.2)
const TRUST_DRIFT := 0.05           # per month toward cred × (0.5 + 0.5 fit) (§4.4)
const BIAS_DECAY := 0.25            # news_bias decays 25%/month (§7.2)
const K_BLAME := 0.5
const K_BIAS := 0.6
const BLAME_SCALE := 400.0          # same unit as PoliticsProvider's fact term (impact × salience/1000 × share × 400)
const AGENDA_PER_IMPACT := 3.0      # raw salience points per unit of over-/under-covered impact
const AGENDA_CAP := 60
const FIT_SCALE := 60.0             # points; fit = exp(-dist / FIT_SCALE)
const STATE_RECENTRE := 0.05        # an INDEPENDENT state paper follows the colony mean 5%/month
const REPORT_KEEP_MONTHS := 24
const P_ERROR := 0.04               # × (1 − quality/100)
const SLANT_BLAME := 0.3            # max share of blame moved by a SLANTED frame
const SLANT_THRESHOLD := 0.3
const BURY := 60.0
const BURY_MAX_MAGNITUDE := 70      # stories this big can't be buried
const SLANT_SCORE := 25.0
const SENS_BONUS := 20.0
## Disposable income per month by band, in W_ref (stand-in until Bob's band incomes are read).
const BAND_DISPOSABLE := {"LOW": 0.6, "MID": 1.0, "HIGH": 2.0}

## Editorial weight by kind of news (moved from the Gazette panel): politics, scandal and disaster lead.
const WEIGHT := {"POL_": 30, "HOME_": 40, "LAW_LEADER": 30, "LAW_CHARTER": 35, "LAW_PETITION": 30, "LAW_EVICTION": 25,
	"ECON_FAMINE": 60, "ECON_SOVEREIGN": 50, "PLANET_": 25, "COMP_WORKPLACE": 15, "ECON_STRIKE": 20, "ECON_LAYOFFS": 15,
	"COMP_LIQUIDATED": 10, "ECON_SHIP": 20, "ECON_CONTRACT": -40, "ECON_TENDER": -40, "ECON_RENT": -10, "ECON_SHORTAGE": -15,
	"ECON_LEVER_EFFECTIVE": -60, "POL_PROJECT_ORDERED": -20, "POL_BILL_PASSED": -15, "MEDIA_": 20}
## Never news: bookkeeping and paid space.
const SKIP_SUFFIX := ["_DONATION"]
const SKIP_TYPES := ["ECON_LEVER_EFFECTIVE", "POL_ATTACK_AD", "POL_CAMPAIGN_GOES_NEGATIVE"]
const MIN_MAGNITUDE := 25
## Scandal, crime and disaster: what sensational papers love.
const SENSATIONAL := ["POL_SCANDAL", "LAW_", "ECON_FAMINE", "PLANET_", "COMP_WORKPLACE_ACCIDENT", "POL_DIRT", "POL_SMEAR",
	"POL_DEBATE_GAFFE", "ECON_FACILITY_CLOSED", "MEDIA_REPORT_EXPOSED"]
## Facts that are bad news for their responsible actors even without an impact vector.
const NEGATIVE := ["POL_SCANDAL", "LAW_LEADER_CONVICTED", "LAW_MANAGER_CONVICTED", "POL_DIRT", "POL_SMEAR", "POL_DEBATE_GAFFE",
	"POL_NO_CONFIDENCE", "POL_BILL_DEFEATED", "COMP_WORKPLACE_ACCIDENT", "ECON_FAMINE", "ECON_SOVEREIGN_DEFAULT",
	"ECON_FACILITY_CLOSED", "LAW_DEFAMATION_RULED", "MEDIA_REPORT_EXPOSED", "LAW_CRISIS_CAUSE_REVEALED"]
const STATE_PAPER := {"sens": 0.2, "ethics": 0.8, "quality": 60, "cred": 70000, "price_mw": 2, "invest": 0.5}
const PARTY_PAPER := {"sens": 0.4, "quality": 40, "cred": 55000, "price_mw": 2, "invest": 0.3}
const UNION_PAPER := {"sens": 0.4, "ethics": 0.6, "quality": 40, "cred": 55000, "price_mw": 1, "invest": 0.3}
const COMPANY_PAPER := {"sens": 0.6, "ethics": 0.5, "quality": 50, "cred": 55000, "price_mw": 3, "invest": 0.5}

# ---- M2: lies, exposure, corrections, investigations, censorship (spec §3.3–3.4, §5, §6, §8)
const MISLEAD_PRESSURE := 0.35        # |stance| × (1 − ethics) (or owner pressure) at or above this: MISLEADING
const MISLEAD_SHIFT := 0.6            # share of blame moved by a misleading frame (× |stance|, at least 0.5)
const P_FABRICATE := 0.03             # × pressure × (1 − ethics) × (1 + election proximity) × legal factor
const LEGAL_FACTOR := {"STRICT": 0.4, "ACTUAL_MALICE": 1.0, "NONE": 1.6}
const FAB_CONCERNS := ["JOBS", "COST_OF_LIVING", "HOUSING", "PUBLIC_SERVICES", "SAFETY", "GOVERNANCE"]
const P_COMPLAINT := 0.25             # the victim complains (magnitude ≥ 40)
const COMPLAINT_MIN_MAGNITUDE := 40
const P_DEBUNK := 0.1                 # × rival invest (W_ref); ×1.5 when the rival opposes the liar
const DEBUNK_MIN_INVEST := 0.5
const P_MEDIA_WHISTLE := 0.01         # 0.03 with LAW_WHISTLEBLOWER_PROTECTION
const P_MEDIA_WHISTLE_PROTECTED := 0.03
const LIE_WATCH_MONTHS := 24
const CRED_LIE := 15000
const CRED_LIE_REPEAT := 5000
const CRED_ERROR := 3000
const CRED_ERROR_CORRECTED := 1000
const CRED_RECOVERY := 300            # per month back toward the paper's founding credibility
const CRED_GOV_RUN_SLANT := 300       # per month a government-run paper slants
const CORRECTION_ACCEPT := 0.6        # share of the remaining false belief a correction reverses (× trust)
const INVEST_P_PER_WREF := 0.08       # p(find) per W_ref of investigation budget, capped
const INVEST_P_MAX := 0.4
const FOI_TRANSPARENCY := 1.0
const NO_FOI_TRANSPARENCY := 0.6
const SCOOP_BONUS := 40.0
const RULES_VERSION := 1

# ---- M2 calibration (10-year probe: partisan papers misled every month and lost all credibility)
const MISLEAD_P_SCALE := 0.5          # p(MISLEADING) per eligible story = (pressure − MISLEAD_PRESSURE) × this
const P_COMPLAINT_BY := {"FALSE": 0.25, "ERROR": 0.15, "MISLEADING": 0.08}
const CRED_SPIN := 5000
const CRED_SPIN_REPEAT := 1000
const REPEAT_CAP := 3

# ---- AI founding (spec §2.1, §15; v4 chronicles: no paper but the Gazette in 100 years)
const FOUND_FROM_MONTH := 12              # no private press in the first year
const POP_PER_PAPER := 500                # market room: active outlets < 1 + voters / this (and ≤ MAX_OUTLETS)
const PARTY_FOUND_CASH := 6.0             # W_ref in the party account (spec §2.1) …
const PARTY_FOUND_SUPPORT := 8000         # … and ≥ 8% in the polls (support, milli-%)
const PARTY_FOUND_ENDOW := 3.0            # W_ref moved into the paper's account
const P_FOUND_PARTY := 0.005              # per eligible party-month, × (1 + support / 20%)
const UNION_FOUND_DENSITY := 30000        # ≥ 30% density …
const UNION_FOUND_OCCS := 2               # … in at least this many occupations
const P_FOUND_UNION := 0.02
const UNION_LINE_PULL := {"LABOR": 40000, "REDISTRIBUTION": 30000}
const COMPANY_FOUND_STAFF := 50000        # milli-persons employed (50 people)
const COMPANY_FOUND_CASH := 150.0         # W_ref
const COMPANY_FOUND_ENDOW := 20.0
const P_FOUND_COMPANY := 0.002            # per eligible company-month …
const P_FOUND_BAD_PRESS := 0.015          # … + this per bad PUBLIC story about it in 12 months (max 3)
const BAD_PRESS_MONTHS := 12
