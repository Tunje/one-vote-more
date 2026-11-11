class_name PolDefs
extends RefCounted
## Political constants (planning/pic-core.md §1–2, planning/spec-politics-v1.md).

const AXES: Array[String] = ["ECON_ROLE", "REDISTRIBUTION", "LABOR", "ENVIRONMENT", "AUTONOMY", "FISCAL", "INSTITUTIONS", "SOVEREIGNTY"]
const CONCERNS: Array[String] = ["JOBS", "COST_OF_LIVING", "HOUSING", "PUBLIC_SERVICES", "SAFETY",
	"ENVIRONMENT_QUALITY", "INFRASTRUCTURE", "FAIRNESS", "GOVERNANCE", "COLONIAL_BURDEN"]
const OCCUPATIONS: Array[String] = ["INDUSTRY", "MINING", "AGRICULTURE", "SERVICES", "PROFESSIONAL", "PUBLIC_SECTOR", "BUSINESS_OWNER", "UNEMPLOYED", "RETIRED"]
const BANDS: Array[String] = ["LOW", "MID", "HIGH"]

# ---- calendar (DECISIONS A7) ----
const PARTY_FORMATION_MONTH := 24       # start of Year 3: movements become parties
const FOUNDING_ELECTION_MONTH := 44     # September, Year 4
const TERM_MONTHS := 48
const SEPTEMBER := 9
const MAX_FORMATION_ROUNDS := 4
const BILL_INTERVAL_MONTHS := 3

# ---- parliament (A5) ----
const SEATS := 151
const MAJORITY := 76
const THRESHOLD_PERMILLE := 40          # 4%
const FIRST_DIVISOR := 1.2

# ---- base ideology per occupation (axis order as AXES) ----
const OCC_IDEOLOGY := {
	"INDUSTRY":       [  0,  10,  40, -20,   0,  -5, -10,   0],
	"MINING":         [  0,  10,  45, -45,  15,  -5, -20,   5],
	"AGRICULTURE":    [-10,   0,   0, -10,  35, -15, -10,   5],
	"PROFESSIONAL":   [-15, -10, -10,  20,   0,  -5,  25,  -5],
	"SERVICES":       [-15,   0,   5,  15,   5, -10,  15,   0],
	"PUBLIC_SECTOR":  [ 18,  15,  18,  25, -10,  20,  20, -10],
	"BUSINESS_OWNER": [-60, -50, -50, -15,  20, -40,   0,  -5],
	"UNEMPLOYED":     [ 25,  40,  30,   0,   0,  25,   0,   5],
	"RETIRED":        [-10,   5, -10,   0,  -5, -30, -20, -15],
}
## Value cohorts: every (district, occupation, band) group is split into people who differ in values,
## not class. Template offsets (points); each colony adds its own random variation (pol.culture stream),
## so the same economy can produce different political cultures.
const COHORTS := {
	"TRAD": {"share": 300, "offset": {"SOVEREIGNTY": -20, "INSTITUTIONS": -25, "ENVIRONMENT": -15, "AUTONOMY": 15, "FISCAL": -10, "REDISTRIBUTION": -10, "ECON_ROLE": -5}},
	"PRAG": {"share": 400, "offset": {"SOVEREIGNTY": -10}},
	"PROG": {"share": 300, "offset": {"SOVEREIGNTY": 5, "INSTITUTIONS": 25, "ENVIRONMENT": 25, "REDISTRIBUTION": 10, "AUTONOMY": -5, "ECON_ROLE": 5}},
}
const COHORT_RANDOM_SD := 15.0     # per-colony random offset per cohort and axis (points)
const COLONY_CULTURE_SD := 10.0    # per-colony shift of everyone (points)
const COHORT_SHARE_JITTER := 80    # per-mille

## Income band shift on (ECON_ROLE, REDISTRIBUTION, FISCAL).
const BAND_SHIFT := {"LOW": [15, 25, 10], "MID": [0, 0, 0], "HIGH": [-20, -30, -15]}

## Base salience per occupation (per-mille, concern order as CONCERNS); renormalized at runtime.
const OCC_SALIENCE := {
	"INDUSTRY":       [180, 130, 110, 90, 140, 60, 110, 90, 90, 60],
	"MINING":         [170, 110, 100, 80, 200, 40, 120, 90, 90, 110],
	"AGRICULTURE":    [130, 140, 80, 100, 70, 100, 170, 80, 130, 110],
	"PROFESSIONAL":   [110, 110, 120, 130, 40, 120, 110, 100, 160, 60],
	"SERVICES":       [130, 170, 140, 110, 60, 90, 80, 110, 110, 50],
	"PUBLIC_SECTOR":  [100, 110, 110, 200, 60, 110, 80, 110, 120, 50],
	"BUSINESS_OWNER": [120, 110, 70, 60, 50, 60, 170, 70, 290, 90],
	"UNEMPLOYED":     [300, 170, 140, 120, 30, 40, 40, 120, 40, 40],
	"RETIRED":        [40, 200, 120, 240, 40, 100, 60, 90, 110, 40],
}

## Which ideology axes a concern makes salient (for weighting ideological distance).
const CONCERN_AXES := {
	"JOBS": ["ECON_ROLE", "LABOR"], "COST_OF_LIVING": ["REDISTRIBUTION"], "HOUSING": ["ECON_ROLE"],
	"PUBLIC_SERVICES": ["FISCAL", "REDISTRIBUTION"], "SAFETY": ["LABOR"], "ENVIRONMENT_QUALITY": ["ENVIRONMENT"],
	"INFRASTRUCTURE": ["FISCAL", "AUTONOMY"], "FAIRNESS": ["REDISTRIBUTION", "INSTITUTIONS"], "GOVERNANCE": ["INSTITUTIONS"], "COLONIAL_BURDEN": ["SOVEREIGNTY"],
}

## How sustained dissatisfaction with a concern pulls voters' ideology (axis -> points per month at 0 satisfaction).
const CONCERN_PULL := {
	"JOBS": {"ECON_ROLE": 0.6, "LABOR": 0.4}, "COST_OF_LIVING": {"REDISTRIBUTION": 0.6},
	"HOUSING": {"ECON_ROLE": 0.4}, "PUBLIC_SERVICES": {"FISCAL": 0.4, "REDISTRIBUTION": 0.3},
	"SAFETY": {"LABOR": 0.6}, "ENVIRONMENT_QUALITY": {"ENVIRONMENT": 0.8},
	"INFRASTRUCTURE": {"FISCAL": 0.4}, "FAIRNESS": {"REDISTRIBUTION": 0.5},
	"GOVERNANCE": {"INSTITUTIONS": 0.4, "AUTONOMY": 0.3},
	"COLONIAL_BURDEN": {"SOVEREIGNTY": 0.8},  # always toward independence (M12)
}

# ---- vote model coefficients (tuning knobs) ----
const BETA_DISTANCE := 0.045     # utility per point of weighted ideological distance
const BETA_PERFORMANCE := 1.4    # government parties: (approval-50)/50 scaled by gov share
const BETA_OWNERSHIP := 1.2      # issue ownership x unmet salience
const BETA_LOYALTY := 0.4        # log of previous vote share in cell
const ELECTION_SHOCK_SD := 0.15  # per-party utility shock on election day
const POLL_MOE_DEFAULT := 3.0    # percentage points (staff quality overrides; spec-staff S6)
const BASE_TURNOUT := 0.78   # recalibrated: 100-year chronicles reached ~92% overall (2nd analysis)
const COST_OF_RULING_PER_YEAR := 0.06   # utility per year in government (~3 pts per term)
const COST_OF_RULING_CAP := 0.5
const BETA_LEADER := 0.35            # leader popularity (0..100, 50 neutral) -> utility (M9)
const SOCIAL_INFLUENCE := 0.005       # monthly pull of a cell toward its district mean (M9)
const ZEITGEIST_SD := 1.5             # points per year per cohort and axis (M9)
const SOV_GENERATIONAL_DRIFT := 0.4  # points/year toward independence: new generations are colony-born (M12)
const AGENDA_HALF_LIFE_FACTOR := 0.79 # monthly decay of news-driven salience (halves in ~3 months)

const PARTY_COLORS: Array[String] = ["#2f6db5", "#c0392b", "#27ae60", "#e1a100", "#8e44ad", "#16a085", "#d35400", "#7f8c8d"]


static func axis_index(axis: String) -> int:
	return AXES.find(axis)


static func cell_key(district: String, occ: String, band: String) -> String:
	return "%s|%s|%s" % [district, occ, band]


static func zero_axes() -> Dictionary:
	var d := {}
	for a in AXES:
		d[a] = 0
	return d
