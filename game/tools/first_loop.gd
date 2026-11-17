extends SceneTree
## The first loop, month by month (rebuild step 3): people, jobs, plans, farms, food and money, and at the end what the
## log holds. For looking, not for judging: every number is read from the game's own records.
## usage: godot --headless --path game --script res://tools/first_loop.gd -- [months=36] [seed=1] [every=3]

const Company := preload("res://sim/economy/company.gd")
const Households := preload("res://sim/population/households.gd")
const Landing := preload("res://sim/economy/landing.gd")
const S := CoreUtil.S


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var months := int(args[0]) if args.size() > 0 else 36
	var seed_v := int(args[1]) if args.size() > 1 else 1
	var every := int(args[2]) if args.size() > 2 else 3
	var sim := GameSim.make(seed_v)
	var w := sim.world
	var made := Landing.land(w, AreaStore.found_landing(w))
	var stores := String(made["stores"])
	print("month | people employed jobless | plans made/signed/done/given-up | farms open (staff) | Stores food | food held by farms | pools' money | treasury | builders' crew")
	for m in months + 1:
		if m % every == 0 or m == months:
			var emp := 0
			var job := 0
			var money := 0
			for pid in Households.pools(w):
				var c := Households.counts(w, pid)
				emp += int(c["employed"]) / S
				job += Households.persons(w, pid, "UNEMPLOYED")
				money += w.ledger.balance(Households.account(pid)) / S
			var plans := {}
			for pid in w.peek("plan"):
				var st := String(w.peek("plan")[pid]["status"])
				plans[st] = int(plans.get(st, 0)) + 1
			var farms := 0
			var farm_staff := 0
			var farm_food := 0
			var crew := 0
			for cid in Company.ids(w):
				var r := Company.record(w, cid)
				if String(r["status"]) != "OPEN":
					continue
				if String(r["type"]) == "FARM":
					farms += 1
					farm_staff += Company.staff_count(w, cid) / S
					farm_food += int(Company.stock_of(w, cid, "FOOD")["qty"]) / S
				elif String(r["type"]) == "BUILDER":
					crew += Company.staff_count(w, cid) / S
			print("%5d | %5d %5d %5d | %s | %3d (%d) | %6d | %6d | %8d | %8d | %d" % [w.month, PopStore.total(w), emp, job,
				str(plans), farms, farm_staff, int(Company.stock_of(w, stores, "FOOD")["qty"]) / S, farm_food, money,
				w.ledger.balance(CoreUtil.TREASURY) / S, crew])
		if m < months:
			sim.step()
	print("\nWHAT THE LOG HOLDS (kind what: rows), the 60 most frequent:")
	var counts := Logbook.counts(w)
	var keys := counts.keys()
	keys.sort_custom(func(a, b): return int(counts[a]) > int(counts[b]) or (int(counts[a]) == int(counts[b]) and String(a) < String(b)))
	for i in mini(60, keys.size()):
		print("  %6d  %s" % [int(counts[keys[i]]), keys[i]])
	quit()
