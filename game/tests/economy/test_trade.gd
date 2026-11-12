extends TestCase
## D1 (A42): exports and a small import trade on the home-world ships. Firms consign stock to the port when the home
## price net of freight, levy and tax beats the local price; the ship pays them from EXTERNAL; merchants bring imports.


func _force_port(w: WorldState) -> String:
	# put components worth exporting into the port for the first org that holds some (or the utility)
	var cpw := EconFinance.org_by_key(w, "CPW")
	EconUtil.inv_add(w, cpw, "COMPONENT", EconTrade.PORT, 50 * EconUtil.S, 500 * EconUtil.S)
	EconUtil.qflow(w, "COMPONENT", "made", 50 * EconUtil.S)
	return cpw


func test_ship_pays_exporters_and_brings_imports() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(3)
	var w := sim.world
	var cpw := _force_port(w)
	var cash0 := w.ledger.balance(EconUtil.acct(cpw))
	EconUtil.st(w)["prices"]["CONSUMER"] = 1000 * EconUtil.S  # a consumer-goods shortage: imports would sell
	var res := EconTrade.on_ship(w)
	check(int(res["cargo"].get("COMPONENT", 0)) >= 49, "the ship loads the consigned components: %s" % [res["cargo"]])
	check(w.ledger.balance(EconUtil.acct(cpw)) > cash0, "the exporter is paid")
	check_eq(EconUtil.inv_get(w, cpw, "COMPONENT", EconTrade.PORT), 0, "the port is emptied")
	check(not res["imports"].is_empty(), "merchants bring goods back")
	check(not w.facts.query("ECON_EXPORTS_SOLD").is_empty(), "exports make news")
	check(not EconTrade.import_offer(w, "CONSUMER").is_empty(), "imports are offered in the market")
	check_eq(w.ledger.total(), 0, "ledger closed (EXTERNAL included)")


func test_export_tax_goes_to_the_treasury() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(3)
	var w := sim.world
	w.levers["LAW_EXPORT_TAX"] = 20
	var px := EconTrade.prices(w)
	check(int(px["COMPONENT"]["tax"]) > 0, "export tax per unit")
	check_eq(int(px["COMPONENT"]["net"]), int(px["COMPONENT"]["home"]) - int(px["COMPONENT"]["freight"]) - int(px["COMPONENT"]["levy"]) - int(px["COMPONENT"]["tax"]), "net = home − freight − levy − tax")
	_force_port(w)
	var t0 := w.ledger.balance(EconUtil.TREASURY)
	var res := EconTrade.on_ship(w)
	check(w.ledger.balance(EconUtil.TREASURY) > t0, "the treasury collects the export tax")
	check(int(EconTrade.last_ship(w).get("tax", 0)) > 0, "tax recorded on the ship")


func test_exports_happen_by_themselves_and_perishables_stay() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(48)
	var w := sim.world
	check(not w.facts.query("ECON_SHIP_ARRIVED").is_empty(), "a ship came")
	var exported := 0
	for f in w.facts.query("ECON_SHIP_ARRIVED"):
		exported += int(f["data"].get("export_value", 0))
	check(exported > 0, "the colony exported something (%d credits)" % exported)
	check(EconReport.goods_errors(w).is_empty(), "goods conserved through ports, ships and imports: %s" % [EconReport.goods_errors(w)])
	for g in ["FOOD", "ENERGY", "WATER"]:
		check(not g in EconTrade.EXPORT_GOODS, "%s does not keep and is not exported" % g)
	check_eq(w.ledger.total(), 0, "ledger closed")


func test_switch_off() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.world.meta["off"] = ["D1"]
	sim.run(36)
	check(EconTrade.port_stock(sim.world).is_empty(), "D1 off: nothing consigned")
