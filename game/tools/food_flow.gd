extends SceneTree
## Food, month by month: made by the farms, sold on the market, left unsold with the farms at the month's end, held in
## the households' stores (and how many months of eating that is), eaten from the stores, spoiled, and meals not eaten.
## usage: godot --headless --path game --script res://tools/food_flow.gd -- [months=60] [seed=1]

const Company := preload("res://sim/economy/company.gd")
const Market := preload("res://sim/economy/market.gd")
const S := CoreUtil.S


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var months := int(args[0]) if args.size() > 0 else 60
	var seed_v := int(args[1]) if args.size() > 1 else 1
	var sim := GameSim.make(seed_v)
	var w := sim.world
	print("month | people | need | made | sold | unsold at farms | in Colony Stores | in household stores | months of eating held | eaten from stores | spoiled at home | not eaten (hunger) | price")
	for m in months:
		var ran := w.month
		sim.step()
		var made := 0
		for r in Logbook.rows(w, {"kind": "MAKE", "what": "made FOOD", "from": ran, "to": ran}):
			made += int(r["change"]["FOOD"][1])
		var farm := 0
		var shop := 0
		for cid in Company.ids(w):
			var q := int(Company.stock_of(w, cid, "FOOD")["qty"])
			if Company.type_of(w, cid) == "FARM":
				farm += q
			else:
				shop += q
		var need := 0
		var held := 0
		var from_store := 0
		for r in Logbook.rows(w, {"kind": "STORE", "from": ran, "to": ran}):
			need += int(r["why"]["need"])
			held += int(r["change"]["stock"][1])
			from_store += int(r["change"]["eaten"][1])
		var hunger := 0
		var spoiled := 0
		for r in Logbook.rows(w, {"kind": "EAT", "from": ran, "to": ran}):
			hunger += int(r["change"]["hunger"][1])
			spoiled += int(r["change"]["spoiled"][1])
		var mk: Dictionary = Market.summary(w, "FOOD")
		print("%5d | %5d | %5d | %5d | %5d | %5d | %5d | %5d | %4.1f | %5d | %4d | %5d | %d" % [ran, PopStore.total(w), need / S, made / S,
			int(mk.get("filled", 0)) / S, farm / S, shop / S, held / S, float(held) / float(maxi(1, need)), from_store / S, spoiled / S, hunger / S,
			int(mk.get("avg_price", 0)) / S])
	quit()
