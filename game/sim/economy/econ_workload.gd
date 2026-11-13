class_name EconWorkload
extends RefCounted
## Support economy 27-W: workload and stress (user ruling: "workers stress when few are doing it should be a thing; an
## employer can earn more by making them do more but the industry suffers and the work becomes high stress").
##   WORKLOAD ‰ per facility (1000 = normal): plants — the floor crew the work needs ÷ the staff present; clinics —
##     patients ÷ (staff × the recipe's normal patients per worker); schools — pupils ÷ (staff × normal pupils).
##   HOURS a week = 40 × workload / 1000 (30..80). STRESS ‰ builds toward 2 × (workload − 1000) over ~6 months and
##     recovers over ~12.
##   RUNNING LEAN: a reckless or distressed private firm staffs LEAN_PM below the norm — fewer posts, the same floor
##     work, a lower wage bill (the "lean saving"), more workload for those who remain.
##   EFFECTS: sick days (labour fill × (1 − SICK_PM × stress)); accidents × (1 + stress); a stressed clinic or school
##     delivers less (output × (1 − QUALITY_PM × stress)), which feeds health access and mortality.
##   LAW (Anni's work_law, while CONDUCT is on): OVERWORK while hours > WK.max_hours at a private firm; UNDERSTAFFING
##     whenever a clinic is short of the HEALTH ratio (unlawful only when ratios are binding).
##   NEWS: ECON_OVERLOAD_INCIDENT when a workplace's stress passes OVERLOAD_PM (once a year per facility) — the Cabinet
##     answers for public workplaces, the company for private ones.
## OPT-IN until its A/B (world.meta["on"] has "WORKLOAD").

const S := EconUtil.S
const WK := preload("res://sim/law/work_law.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const LEAN_PM := 150
const PLEDGE_M := 24
## Public services under a staffing ratio (Anni's WK.RATIOS); CARE and CHILDCARE join when those services exist.
const PUBLIC_RATIO_SERVICE := {"CLINIC": "HEALTH", "ELDERCARE": "CARE", "CHILDCARE": "CHILDCARE", "POLICE_STATION": "POLICE"}
const SICK_PM := 150
const QUALITY_PM := 300
const OVERLOAD_PM := 800
const STRESS_RISE := 6  # months to close the gap upward
const STRESS_FALL := 12  # months to recover
const SERVICE_TAG := {"CLINIC": "HEALTH", "SCHOOL": "EDUCATION", "SANITATION": "SANITATION", "TRANSIT": "TRANSPORT",
	"ELDERCARE": "CARE", "CHILDCARE": "CHILDCARE", "POLICE_STATION": "POLICE"}


static func active(world: WorldState) -> bool:
	return world.meta.has("on") and (world.meta["on"] as Array).has("WORKLOAD") and not EconUtil.off(world, "WORKLOAD")


## Production hooks (1.0 / unchanged when off or unstressed).
static func sick_mult(f: Dictionary) -> float:
	return 1.0 - float(SICK_PM) / 1000.0 * float(int(f.get("stress_pm", 0))) / 1000.0


static func accident_mult(f: Dictionary) -> float:
	return 1.0 + float(int(f.get("stress_pm", 0))) / 1000.0


static func quality_mult(f: Dictionary) -> float:
	return 1.0 - float(QUALITY_PM) / 1000.0 * float(int(f.get("stress_pm", 0))) / 1000.0


## Clients a service facility serves this month (patients / pupils), its district's people shared over its sites.
static func _clients(world: WorldState, f: Dictionary) -> int:
	if f["type"] in ["ELDERCARE", "CHILDCARE"]:
		return EconCare.site_clients(f)  # part E: the enrolled
	if f["type"] == "POLICE_STATION":
		return int(f.get("covered_pop", 0))  # P1b: the residents a station covers (WK.RATIOS POLICE 500 per officer)
	var d: String = f["district"]
	var n := 0
	for fid in world.table("facility"):
		var g: Dictionary = world.table("facility")[fid]
		if g["type"] == f["type"] and g["district"] == d and not g["mothball"]:
			n += 1
	var pop := 0
	var kids := 0
	for gid in world.table("hh"):
		var h: Dictionary = world.table("hh")[gid]
		if h["district"] == d:
			pop += EconHouseholds.persons(h)
			kids += int(h.get("children", 0))
	return (kids if f["type"] == "SCHOOL" else pop) / maxi(1, n) / S


static func workload_pm(world: WorldState, f: Dictionary) -> int:
	var staff := EconLabor.staff_total(f["staff"])
	if f["type"] == "POLICE_STATION":
		return EconPolice.workload_pm(f)
	if f["type"] in ["ELDERCARE", "CHILDCARE"]:
		var e := EconCare.site_clients(f)
		if e <= 0:
			return 0
		return clampi(int(1000.0 * float(e) / maxf(1.0, float(staff) / S * EconCare.normal_for(f["type"]))), 0, 2000)
	if f["type"] in ["CLINIC", "SCHOOL"]:
		var r: Dictionary = EconData.RECIPES[f["type"]]
		var crew := 0
		for t in r["labor"]:
			crew += int(r["labor"][t])
		var per_worker := float(r["out"][1]) * EconUtil.fscale(f) / float(maxi(1, crew))  # normal clients per worker
		return clampi(int(1000.0 * float(_clients(world, f)) / maxf(1.0, float(staff) / S * per_worker)), 0, 2000)
	var req := 0
	var rq := EconLabor.required_full(f)
	for t in rq:
		req += int(rq[t])
	req = req * (1000 - int(f.get("off_share_pm", 0))) / 1000  # the floor crew (the office has its own)
	if req <= 0:
		return 0
	return clampi(int(1000.0 * float(req) / float(maxi(staff, req / 4))), 0, 2000)


## COMPANY_AI, after FirmAI.run: workload, hours, stress, lean choices, law reports, overload news.
static func monthly(world: WorldState) -> void:
	if not active(world):
		return
	var conduct := EconConduct.active(world)
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["mothball"] or f["type"] in ["HOUSING", "ROAD"]:
			f["stress_pm"] = int(int(f.get("stress_pm", 0)) * (STRESS_FALL - 1) / STRESS_FALL)
			continue
		var o: Dictionary = world.table("org").get(f["org"], {})
		# lean: reckless or distressed private firms staff below the norm
		var lean := 0
		if not o.is_empty() and o["type"] in ["PRIVATE", "COOPERATIVE"] and not o["is_contractor"]:
			# a settled staffing dispute (union STAFFING demand) binds the firm to full crews for PLEDGE_M months
			if (int(o["ceo"].get("risk", 50)) >= 70 or o["status"] == "DISTRESSED") and world.month - int(o.get("staffing_pledge_m", -999)) >= PLEDGE_M:
				lean = LEAN_PM
		f["lean_pm"] = lean
		var wl := workload_pm(world, f)
		f["workload_pm"] = wl
		f["hours"] = clampi(40 * wl / 1000, 30, 80)
		f["service"] = SERVICE_TAG.get(f["type"], "")
		var target := clampi(2 * (wl - 1000), 0, 1000)
		var st := int(f.get("stress_pm", 0))
		st += (target - st) / (STRESS_RISE if target > st else STRESS_FALL)
		f["stress_pm"] = clampi(st, 0, 1000)
		var saving := 0
		if lean > 0:
			var r: Dictionary = EconData.RECIPES[f["type"]]
			for t in r["labor"]:
				saving += int(float(r["labor"][t]) * EconUtil.fscale(f) * float(lean) / 1000.0 * float(EconUtil.st(world)["wage"][t]))
		f["lean_saving"] = saving
		if conduct and not o.is_empty():
			_report_law(world, f, o, saving)
		if int(f["stress_pm"]) >= OVERLOAD_PM and world.month - int(f.get("overload_m", -99)) >= 12:
			f["overload_m"] = world.month
			var public: bool = o.get("type", "") in EconData.PUBLIC_TYPES
			var resp: Array = [["GOVERNMENT", "government", 1.0]] if public else [["COMPANY", f["org"], 1.0]]
			EconFacts.emit(world, "ECON_OVERLOAD_INCIDENT", f["district"], [["COMPANY", f["org"]]], resp,
				{"SAFETY": -10, "PUBLIC_SERVICES": -15 if public else -5}, 30 + int(f["stress_pm"]) / 50, "PUBLIC",
				{"sector": EconLabor.occupation_of(world, f["org"], f["type"]), "facility": fid, "district": f["district"],
				"owner_kind": "PUBLIC" if public else "PRIVATE", "owner": f["org"], "severity": int(f["stress_pm"]) / 10,
				"persons": EconLabor.staff_total(f["staff"]) / S, "workload": wl}, {"districts": [f["district"]]})


static func _report_law(world: WorldState, f: Dictionary, o: Dictionary, saving: int) -> void:
	var fid: String = f["id"]
	var t: Dictionary = EconUtil.st(world).get("workload_tracks", {})
	EconUtil.st(world)["workload_tracks"] = t
	var ow := fid + "|OVERWORK"
	if o["type"] in ["PRIVATE", "COOPERATIVE"] and int(f["hours"]) > WK.max_hours(world):
		t[ow] = LawOps.record_greed(world, f["org"], {"kind": "OVERWORK", "facility": fid, "district": f["district"], "saving": saving})
	elif t.has(ow):
		LawOps.greed_stop(world, str(t[ow]))
		t.erase(ow)
	# Anni (Wilma's ruling): binding ratios bind the government's own services too — the law side records the episode
	if o["type"] in EconData.PUBLIC_TYPES and PUBLIC_RATIO_SERVICE.has(f["type"]):
		WK.report_public_staffing(world, fid, f["district"], PUBLIC_RATIO_SERVICE[f["type"]], _clients(world, f),
			EconLabor.staff_total(f["staff"]) / S)
	var us := fid + "|UNDERSTAFFING"
	if f["type"] == "CLINIC" and o["type"] in ["PRIVATE", "COOPERATIVE"]:
		var chk := WK.staffing_check(world, "HEALTH", _clients(world, f), EconLabor.staff_total(f["staff"]) / S)
		if int(chk["short"]) > 0:
			t[us] = LawOps.record_greed(world, f["org"], {"kind": "UNDERSTAFFING", "facility": fid, "district": f["district"], "saving": saving})
			return
	if t.has(us):
		LawOps.greed_stop(world, str(t[us]))
		t.erase(us)


## {colony: {sector: stress ‰}, districts: {d: {sector: stress ‰}}} — staff-weighted, integers (Ella, Wilma).
static func view(world: WorldState) -> Dictionary:
	var num := {}
	var den := {}
	var dnum := {}
	var dden := {}
	for fid in world.peek("facility"):
		var f: Dictionary = world.peek("facility")[fid]
		if not f.has("stress_pm") or not world.peek("org").has(f["org"]):
			continue
		var sec := EconLabor.occupation_of(world, f["org"], f["type"])
		var w := EconLabor.staff_total(f["staff"]) / S
		if w <= 0:
			continue
		num[sec] = int(num.get(sec, 0)) + int(f["stress_pm"]) * w
		den[sec] = int(den.get(sec, 0)) + w
		var d: String = f["district"]
		if not dnum.has(d):
			dnum[d] = {}
			dden[d] = {}
		dnum[d][sec] = int(dnum[d].get(sec, 0)) + int(f["stress_pm"]) * w
		dden[d][sec] = int(dden[d].get(sec, 0)) + w
	var col := {}
	for sec in num:
		col[sec] = int(num[sec]) / maxi(1, int(den[sec]))
	var dis := {}
	for d in dnum:
		dis[d] = {}
		for sec in dnum[d]:
			dis[d][sec] = int(dnum[d][sec]) / maxi(1, int(dden[d][sec]))
	return {"colony": col, "districts": dis}
