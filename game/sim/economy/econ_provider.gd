class_name EconProvider
extends PicProvider
## Economy + companies subsystem (planning/spec-economy-v1.md, pic-economy.md). Stateless: all state in WorldState.
## Runs in TRADE → PRODUCTION → SETTLEMENT → COMPANY_AI → SOCIAL (pic-core §7, spec §5).


func owner_id() -> String:
	return "econ"


func indicator_defs() -> Array:
	return EconPic.indicators()


func lever_defs() -> Array:
	return EconPic.levers()


func action_defs() -> Array:
	return EconPic.actions()


func phases() -> Array:
	return [TickPhase.TRADE, TickPhase.PRODUCTION, TickPhase.SETTLEMENT, TickPhase.COMPANY_AI, TickPhase.SOCIAL]


func init_world(world: WorldState) -> void:
	EconSetup.init_world(world)


func run_phase(phase: int, world: WorldState) -> void:
	match phase:
		TickPhase.TRADE:
			var t0 := Time.get_ticks_usec()
			EconConsumer.ensure(world)  # D2: prices for the consumer goods in older worlds
			EconMarket.trade(world)
			EconUtil.prof(world, "phase TRADE", t0)
		TickPhase.PRODUCTION:
			var t1 := Time.get_ticks_usec()
			EconProduction.produce(world)
			EconUtil.prof(world, "phase PRODUCTION", t1)
		TickPhase.SETTLEMENT:
			var t2 := Time.get_ticks_usec()
			EconFinance.settle(world)
			EconUnions.donation_offers(world)
			EconUtil.prof(world, "phase SETTLEMENT", t2)
		TickPhase.COMPANY_AI:
			var t := Time.get_ticks_usec()
			LawBridge.revalidate(world)
			t = EconUtil.prof(world, "LawBridge.revalidate", t)
			EconTrade.monthly(world)  # D1 (A42): home prices, export consignments — before the firms post sale offers
			t = EconUtil.prof(world, "EconTrade.monthly", t)
			EconCommute.monthly(world)  # §8b (opt-in): commuting fares to CTA, buses staffed from them
			t = EconUtil.prof(world, "EconCommute.monthly", t)
			EconComfort.monthly(world)  # §8b (opt-in): cafés, takeaway, hairdressers staffed from comfort spending
			t = EconUtil.prof(world, "EconComfort.monthly", t)
			EconRetail.monthly(world)  # support economy D (opt-in): shop staff from the retail margin
			t = EconUtil.prof(world, "EconRetail.monthly", t)
			EconSanitation.monthly(world)  # support economy E (opt-in): the Sanitation Department, sized to the population
			t = EconUtil.prof(world, "EconSanitation.monthly", t)
			EconOffice.monthly(world)  # support economy A (opt-in): size each organisation's office before vacancies are posted
			t = EconUtil.prof(world, "EconOffice.monthly", t)
			FirmAI.run(world)
			t = EconUtil.prof(world, "FirmAI.run", t)
			EconConduct.monthly(world)  # E132 (opt-in): firms' corner-cutting, reported to the law
			t = EconUtil.prof(world, "EconConduct.monthly", t)
			EconVictims.monthly(world)  # (opt-in with CONDUCT): the victim fund paid out to the victims' households
			EconWorkload.monthly(world)  # 27-W (opt-in): workload, hours, stress, lean staffing, overload news
			t = EconUtil.prof(world, "EconWorkload.monthly", t)
			EconConsumer.decorate_offers(world)  # D2: quality and reputation on consumer-goods offers
			t = EconUtil.prof(world, "EconConsumer.decorate_offers", t)
			EconConsumer.quality_monthly(world)  # D2: workshop quality, brand reputation, scandals
			t = EconUtil.prof(world, "EconConsumer.quality_monthly", t)
			EconTraining.monthly(world)  # E114: on-the-job training into skilled vacancies
			t = EconUtil.prof(world, "EconTraining.monthly", t)
			EconPublicJobs.monthly(world)  # E117b: public employment scheme (budget line set by parliament)
			t = EconUtil.prof(world, "EconPublicJobs.monthly", t)
			EconHousing.monthly(world)  # S3 (A46): housing ages on an S-curve; owners renovate or let it slide
			t = EconUtil.prof(world, "EconHousing.monthly", t)
			EconUnions.industrial_action(world)
			t = EconUtil.prof(world, "EconUnions.industrial_action", t)
			EconPop.realign(world)  # M10: workplaces that changed owner this month relabel their staff's occupation
			t = EconUtil.prof(world, "EconPop.realign", t)
			EconPop.sync(world)
			t = EconUtil.prof(world, "EconPop.sync", t)
		TickPhase.SOCIAL:
			EconHouseholds.social(world)
			EconIndicators.publish(world)
			EconUnions.publish_density(world)
			EconTrade.publish(world)  # D1: trade balance indicator
			EconConsumer.update_confidence(world)  # D2: consumer confidence (durables boom and slump)
			Unions.monthly(world)  # U1 (A41): unions as organisations: members, dues, mood, leaders, mergers, breakaways
