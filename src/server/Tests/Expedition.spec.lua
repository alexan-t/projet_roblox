--!strict
-- Hors du dossier Services : jamais exécuté par le bootstrap.
-- Aperçu des stages (StagePreview, vraies configs serveur) et logique d'affichage de la fenêtre
-- Expédition (Shared.Expedition.ExpeditionModel) : tools/test-expedition.ps1.

return function(StagePreview: any, Model: any, configs: any)
	local passed, failed = 0, 0
	local function test(name: string, run: () -> ())
		local ok, err = pcall(run)
		if ok then
			passed += 1
			print("PASS " .. name)
		else
			failed += 1
			print("FAIL " .. name .. ": " .. tostring(err))
		end
	end

	local sources = { Rewards = configs.Rewards, Progression = configs.Progression, Elite = configs.Elite }
	local function preview(stage: number, mode: string?): any
		return StagePreview.build(configs.Stages.Zones[1].Stages[stage], 1, stage, mode or "Normal", sources)
	end
	local function waves(p: any): string
		local out = {}
		for i, wave in p.Waves do
			local parts = {}
			for _, group in wave.Enemies do table.insert(parts, `{group.EnemyId}x{group.Count}`) end
			table.insert(out, `W{i}:` .. table.concat(parts, "+"))
		end
		return table.concat(out, " ")
	end

	------------------------------------------------------------------ StagePreview (serveur)

	test("waves: the real StageConfig compositions, wave by wave (1-1 to 1-5)", function()
		assert(waves(preview(1)) == "W1:Slimex2+Gobelinx2", waves(preview(1)))
		assert(waves(preview(2)) == "W1:Slimex3+Gobelinx2", waves(preview(2)))
		assert(waves(preview(3)) == "W1:Slimex2+Gobelinx2 W2:Slimex2+Gobelinx1", waves(preview(3)))
		assert(waves(preview(4)) == "W1:Slimex2+Gobelinx2 W2:Gobelinx3", waves(preview(4)))
		assert(waves(preview(5)) == "W1:Slimex2+Gobelinx1", waves(preview(5)))
		assert(preview(5).Boss == "Boss" and preview(4).Boss == nil, "1-5 boss = Roi Orc (Boss)")
	end)

	test("hero XP: HeroProgressionConfig, Normal 25/35/50/70/100, Elite 60/80/110/150/220", function()
		local normal, elite = {}, {}
		for stage = 1, 5 do
			table.insert(normal, preview(stage).HeroXP)
			table.insert(elite, preview(stage, "Elite").HeroXP)
		end
		assert(table.concat(normal, ",") == "25,35,50,70,100", table.concat(normal, ","))
		assert(table.concat(elite, ",") == "60,80,110,150,220", table.concat(elite, ","))
	end)

	test("rewards: 1-1 first clear 100 Or / 10 Gemmes / 1 Ticket, replay 20 Or; 1-2..1-5 and Elite: nothing invented", function()
		local p = preview(1)
		local fc = {}
		for _, r in p.FirstClearRewards do fc[r.Kind] = r.Amount end
		assert(fc.Gold == 100 and fc.Gems == 10 and fc.SummonTicket == 1 and #p.FirstClearRewards == 3)
		assert(#p.RepeatRewards == 1 and p.RepeatRewards[1].Kind == "Gold" and p.RepeatRewards[1].Amount == 20)
		for stage = 2, 5 do
			local q = preview(stage)
			assert(#q.FirstClearRewards == 0 and #q.RepeatRewards == 0, `1-{stage}: no stage reward configured`)
		end
		for stage = 1, 5 do
			local e = preview(stage, "Elite")
			assert(#e.FirstClearRewards == 0 and #e.RepeatRewards == 0, `1-{stage}E: no Elite reward configured`)
		end
	end)

	test("Elite: real EliteConfig multipliers; Normal has none", function()
		local e1, e5 = preview(1, "Elite"), preview(5, "Elite")
		assert(e1.Multipliers.MaxHealth == 1.5 and e1.Multipliers.AttackDamage == 1.25)
		assert(e5.Multipliers.MaxHealth == 2.25 and e5.Multipliers.AttackDamage == 1.5)
		assert(preview(1).Multipliers == nil)
	end)

	test("drops: absent without a real loot table (#72); copied and validated when provided", function()
		assert(preview(1).PotentialDrops == nil, "no fake drop")
		local stage = configs.Stages.Zones[1].Stages[1]
		local withDrops = StagePreview.build(stage, 1, 1, "Normal", { Rewards = configs.Rewards, Progression = configs.Progression,
			Drops = { { Kind = "Resource", Id = "resource_011", Chance = 0.3, Min = 1, Max = 2 }, { Kind = "Item", Id = "item_001", Chance = 0.005 },
				{ Kind = "Gold", Id = "x", Chance = 0.5 }, { Kind = "Resource", Id = "bad", Chance = 4 } } })
		local d = withDrops.PotentialDrops
		assert(d and #d == 2 and d[1].Id == "resource_011" and d[1].Chance == 0.3 and d[1].Max == 2 and d[2].Min == 1)
	end)

	test("copies: editing the preview never changes the configs", function()
		local p = preview(1)
		p.FirstClearRewards[1].Amount = 99999
		p.Waves[1].Enemies[1].Count = 99
		assert(configs.Rewards.Stages["1-1"].FirstClearReward[1].Amount == 100)
		assert(configs.Stages.Zones[1].Stages[1].Waves[1].Enemies[1].Count == 2)
	end)

	------------------------------------------------------------------ ExpeditionModel (client)

	local function stages(cleared: number, mode: string?): { any }
		local list = {}
		for stage = 1, 5 do
			local p = preview(stage, mode)
			p.Zone, p.Stage = 1, stage
			p.Cleared = stage <= cleared
			p.Status = if stage <= cleared + 1 then "Unlocked" else "Locked"
			table.insert(list, p)
		end
		return list
	end

	test("rail Normal: Terminé / Disponible / Verrouillé, boss 1-5 (Boss, Boss · Terminé)", function()
		local nodes = Model.nodes(stages(2), "Normal", false)
		local badges = {}
		for _, n in nodes do table.insert(badges, n.Badge) end
		assert(table.concat(badges, ",") == "Terminé,Terminé,Disponible,Verrouillé,Boss", table.concat(badges, ","))
		assert(nodes[5].Boss == true and nodes[5].State == "Locked")
		local all = Model.nodes(stages(5), "Normal", true)
		assert(all[5].Badge == "Boss · Terminé" and all[5].State == "Done")
		assert(Model.track(nodes) == 0.5 and Model.track(all) == 1)
		assert(Model.cleared(stages(3)) == 3)
	end)

	test("Elite locked: every card locked, no launch, real Normal progress for the unlock message", function()
		local elite = stages(0, "Elite")
		local nodes = Model.nodes(elite, "Elite", false)
		for _, n in nodes do assert(n.State == "Locked", n.Label) end
		assert(nodes[1].Label == "Stage 1-1E")
		local launch = Model.launch(elite[1], "Elite", false, 4)
		assert(launch.Enabled == false and launch.Sub == "Élite verrouillée")
		assert(Model.track(nodes) == 0)
	end)

	test("Elite unlocked: Élite badge on open cards, own EliteFirstClears progress, ÉLITE in the launch sub-text", function()
		local elite = stages(2, "Elite")
		local nodes = Model.nodes(elite, "Elite", true)
		assert(nodes[1].Badge == "Terminé" and nodes[3].Badge == "Élite" and nodes[3].BadgeKind == "Elite" and nodes[4].Badge == "Verrouillé")
		local launch = Model.launch(elite[3], "Elite", true, 2)
		assert(launch.Enabled and launch.Sub == "Stage 1-3 · ÉLITE", launch.Sub)
		assert(Model.title(elite[5], "Elite") == "Stage 1-5E · Boss")
	end)

	test("launch: locked stage explains why; no hero -> Pose un héros; ready -> Stage 1-X", function()
		local list = stages(1)
		assert(Model.launch(list[4], "Normal", false, 3).Sub == "Termine 1-3")
		assert(Model.launch(list[2], "Normal", false, 0).Enabled == false and Model.launch(list[2], "Normal", false, 0).Sub == "Pose un héros")
		local ok = Model.launch(list[2], "Normal", false, 1)
		assert(ok.Enabled and ok.Sub == "Stage 1-2")
		assert(Model.launch(nil, "Normal", false, 1).Enabled == false)
	end)

	test("team: 0 -> place a hero, 1..3 -> ready with free places, 4 -> complete", function()
		assert(Model.team(0, 4).Ready == false and Model.team(0, 4).Hint == "Place au moins un héros sur les dalles")
		assert(Model.team(2, 4).Hint == "Prêt · 2 places libres" and Model.team(3, 4).Hint == "Prêt · 1 place libre")
		assert(Model.team(4, 4).Full and Model.team(4, 4).Hint == "Équipe complète")
	end)

	test("rewards: first clear (once) then repeat; after the first clear it is shown as obtained", function()
		local before = Model.rewards(stages(0)[1], true)
		assert(#before.FirstClear == 3 and before.FirstClearDone == false and before.RepeatTitle == "Ensuite, à chaque victoire")
		assert(#before.Repeat == 1 and before.Repeat[1].Amount == 20 and before.HeroXP == 25)
		local after = Model.rewards(stages(1)[1], true)
		assert(after.FirstClearDone == true and after.RepeatTitle == "À chaque victoire")
		local empty = Model.rewards(stages(1)[2], false)
		assert(#empty.FirstClear == 0 and #empty.Repeat == 0 and empty.HeroXP == 35 and empty.RepeatTitle == "Rejouer")
	end)

	test("default stage: preferred, else first open not cleared, else last open", function()
		local list = stages(2)
		assert(Model.default(list, "Normal", false, nil).Stage == 3)
		assert(Model.default(list, "Normal", false, 1).Stage == 1)
		assert(Model.default(stages(5), "Normal", true, nil).Stage == 5)
	end)

	test("chance formatting: 30 %, 6 %, 0,5 %, Garanti", function()
		assert(Model.chance(0.3) == "30 %" and Model.chance(0.06) == "6 %")
		assert(Model.chance(0.005) == "0,5 %", Model.chance(0.005))
		assert(Model.chance(1) == "Garanti")
	end)

	test("device: phone 844x390, tablet 1180x820, pc 1600x900 / 1920x1080", function()
		assert(Model.device(844, 390) == "phone")
		assert(Model.device(1180, 820) == "tablet")
		assert(Model.device(1600, 900) == "pc" and Model.device(1920, 1080) == "pc")
	end)

	print(`Expedition: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{failed} Expedition test(s) failed`)
	end
end
