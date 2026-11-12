extends TestCase
## E118: a closed plant nobody can repair is force-sold once; if it is still unrepaired when it falls due again (or would
## fetch nothing) it is scrapped — no yearly resale loop at halving prices down to 0 credits.


func _closed_private_plant(w: WorldState) -> Dictionary:
	for fid in EconUtil.sorted_keys(w.table("facility")):
		var f: Dictionary = w.table("facility")[fid]
		var o: Dictionary = w.table("org")[f["org"]]
		if o["type"] == "PRIVATE" and o["status"] == "ACTIVE" and not o["is_contractor"] and f["type"] in ["MINE", "CONSUMERF", "FARM"]:
			f["mothball"] = true
			f["closed_unsafe"] = true
			f["overhaul_frac"] = 0
			f["closed_m"] = EconData.FORCED_SALE_MONTHS
			return f
	return {}


func _due(f: Dictionary) -> void:
	f["mothball"] = true
	f["closed_unsafe"] = true
	f["overhaul_frac"] = 0
	f["closed_m"] = EconData.FORCED_SALE_MONTHS


func test_second_forced_sale_scraps() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(2)
	var w := sim.world
	var f := _closed_private_plant(w)
	check(not f.is_empty(), "a private plant to close")
	f["book"] = 50 * EconConstruction.estimate(f["type"])  # worth selling the first time
	EconInsolvency.forced_sale_round(w)
	var sold := int(f.get("forced_sales", 0)) == 1
	var scrapped := bool(f.get("scrapped", false))
	check(sold or scrapped, "first time due: sold (or scrapped if no one could take it)")
	if sold:
		var o: Dictionary = w.table("org").get(f["org"], {})
		if not o.is_empty() and not (o["type"] in EconData.PUBLIC_TYPES):
			_due(f)  # still unrepaired by the buyer
			EconInsolvency.forced_sale_round(w)
			check(bool(f.get("scrapped", false)), "second time due: scrapped, not resold")
	check(not w.facts.query("ECON_FACILITY_SCRAPPED").is_empty() or not bool(f.get("scrapped", false)), "scrapping makes news")
	check_eq(w.ledger.total(), 0, "ledger closed")


func test_worthless_plant_is_not_sold_for_nothing() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(2)
	var w := sim.world
	var f := _closed_private_plant(w)
	f["book"] = 0
	var owner: String = f["org"]
	EconInsolvency.forced_sale_round(w)
	check(bool(f.get("scrapped", false)), "book below the overhaul cost: scrapped")
	check_eq(String(f["org"]), owner, "no change of owner at 0 credits")
	for _i in 3:
		sim.run(1)
	check(f["mothball"], "a scrapped plant is not restarted automatically")
	check_eq(EconLabor.required(f).get("G", 0), 0, "no repair crew for a scrapped plant")
