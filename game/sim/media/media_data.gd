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
const STATE_PAPER := {"sens": 0.2, "ethics": 0.8, "quality": 60, "cred": 70000, "price_mw": 2}
const PARTY_PAPER := {"sens": 0.4, "quality": 40, "cred": 55000, "price_mw": 2}
const UNION_PAPER := {"sens": 0.4, "ethics": 0.6, "quality": 40, "cred": 55000, "price_mw": 1}
const COMPANY_PAPER := {"sens": 0.6, "ethics": 0.5, "quality": 50, "cred": 55000, "price_mw": 3}
