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
			EconConsumer.ensure(world)  # D2: prices for the consumer goods in older worlds
			EconMarket.trade(world)
		TickPhase.PRODUCTION:
			EconProduction.produce(world)
		TickPhase.SETTLEMENT:
			EconFinance.settle(world)
			EconUnions.donation_offers(world)
		TickPhase.COMPANY_AI:
			LawBridge.revalidate(world)
			EconTrade.monthly(world)  # D1 (A42): home prices, export consignments — before the firms post sale offers
			FirmAI.run(world)
			EconConsumer.decorate_offers(world)  # D2: quality and reputation on consumer-goods offers
			EconConsumer.quality_monthly(world)  # D2: workshop quality, brand reputation, scandals
			EconTraining.monthly(world)  # E114: on-the-job training into skilled vacancies
			EconPublicJobs.monthly(world)  # E117b: public employment scheme (budget line set by parliament)
			EconUnions.industrial_action(world)
			EconPop.realign(world)  # M10: workplaces that changed owner this month relabel their staff's occupation
			EconPop.sync(world)
		TickPhase.SOCIAL:
			EconHouseholds.social(world)
			EconIndicators.publish(world)
			EconUnions.publish_density(world)
			EconTrade.publish(world)  # D1: trade balance indicator
			EconConsumer.update_confidence(world)  # D2: consumer confidence (durables boom and slump)
			Unions.monthly(world)  # U1 (A41): unions as organisations: members, dues, mood, leaders, mergers, breakaways
