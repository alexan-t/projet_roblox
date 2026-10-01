--!strict
-- Hors du dossier Services : jamais exécuté par le bootstrap.
-- Teste le vrai module ArenaRules (règles pures de la préparation) avec la vraie StageConfig.
-- La formation associe une case à un identifiant d'exemplaire de héros (H1, H2...).

return function(ArenaRules: any, stageConfig: any, arenaConfig: any)
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

	local stage = stageConfig.Zones[1].Stages[1]

	test("Stage 1-1 expands to 2 Slime, 4 Gobelin, then the Boss mini-boss", function()
		local enemies = ArenaRules.expandEnemies(stage)
		assert(#enemies == 7)
		local counts: { [string]: number } = {}
		for _, e in enemies do counts[e.EnemyId] = (counts[e.EnemyId] or 0) + 1 end
		assert(counts.Slime == 2 and counts.Gobelin == 4 and counts.Boss == 1)
		assert(enemies[7].EnemyId == "Boss" and enemies[7].MiniBoss == true and enemies[1].MiniBoss == false)
	end)

	test("summary tells which enemies and how many, never positions", function()
		local summary = ArenaRules.summarize(stage)
		assert(#summary == 3)
		assert(summary[1].EnemyId == "Slime" and summary[1].Count == 2 and not summary[1].MiniBoss)
		assert(summary[2].EnemyId == "Gobelin" and summary[2].Count == 4)
		assert(summary[3].EnemyId == "Boss" and summary[3].Count == 1 and summary[3].MiniBoss)
		for _, entry in summary do
			for key in entry do assert(key == "EnemyId" or key == "Count" or key == "MiniBoss", "no position field: " .. key) end
		end
	end)

	test("assign: up to 4 heroes, one cell per hero instance", function()
		local f = {}
		assert(ArenaRules.assign(f, 1, "H1", 4))
		assert(ArenaRules.assign(f, 2, "H2", 4))
		assert(ArenaRules.assign(f, 5, "H3", 4))
		assert(ArenaRules.assign(f, 9, "H4", 4))
		local ok, reason = ArenaRules.assign(f, 3, "H5", 4)
		assert(ok == false and reason == "4 héros maximum" and f[3] == nil, "5th hero refused on a free cell")
		assert(ArenaRules.assign(f, 7, "H1", 4), "same instance moves instead of duplicating")
		assert(f[1] == nil and f[7] == "H1" and ArenaRules.count(f) == 4 and ArenaRules.slotOf(f, "H1") == 7)
		assert(ArenaRules.assign(f, 7, "H1", 4) and f[7] == "H1", "re-assigning in place is a no-op")
	end)

	test("two instances of the same class are two different heroes", function()
		local f = {}
		assert(ArenaRules.assign(f, 1, "ArcherA", 4) and ArenaRules.assign(f, 2, "ArcherB", 4))
		assert(f[1] == "ArcherA" and f[2] == "ArcherB")
	end)

	test("assign on an occupied cell replaces its hero, even with a full field", function()
		local f = { [1] = "H1", [2] = "H2", [5] = "H3", [9] = "H4" }
		assert(ArenaRules.assign(f, 5, "H5", 4), "replace allowed at 4/4")
		assert(f[5] == "H5" and ArenaRules.count(f) == 4 and ArenaRules.slotOf(f, "H3") == nil)
		assert(ArenaRules.assign(f, 2, "H4", 4), "moving a placed hero onto an occupied cell")
		assert(f[2] == "H4" and f[9] == nil and ArenaRules.count(f) == 3)
	end)

	test("clear empties a cell; invalid cells and empty ids refused", function()
		local f = { [4] = "H6" }
		assert(ArenaRules.clear(f, 4) and f[4] == nil)
		assert(ArenaRules.clear(f, 4), "clearing an empty cell is harmless")
		for _, bad in { 0, 10, 1.5, "1", {} } :: { any } do
			local ok, reason = ArenaRules.assign(f, bad, "H1", 4)
			assert(ok == false and reason == "case invalide")
			ok, reason = ArenaRules.clear(f, bad)
			assert(ok == false and reason == "case invalide")
		end
		for _, bad in { "", 12, {} } :: { any } do
			local ok, reason = ArenaRules.assign(f, 1, bad, 4)
			assert(ok == false and reason == "héros inconnu")
		end
		assert(next(f) == nil)
	end)

	test("arena config: max 4 heroes and a mannequin for every Stage 1-1 enemy", function()
		assert(arenaConfig.MaxHeroes == 4)
		for _, e in ArenaRules.expandEnemies(stage) do
			assert(arenaConfig.EnemyTemplates[e.EnemyId], "mannequin for " .. e.EnemyId)
		end
	end)

	print(`ArenaRules: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{failed} ArenaRules test(s) failed`)
	end
end
