--!strict
-- Hors du dossier Services : jamais exécuté par le bootstrap.
-- Teste le vrai module ArenaRules (règles pures du prototype de préparation) avec la vraie StageConfig.

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

	-- Générateur déterministe au format de Random (NextInteger), pour des tirages reproductibles.
	local function seeded(seed: number): any
		local state = seed
		return { NextInteger = function(_self: any, min: number, max: number): number
			state = (state * 1103515245 + 12345) % 2147483648
			return min + state % (max - min + 1)
		end }
	end

	local stage = stageConfig.Zones[1].Stages[1]
	local classes = {}
	for _, class in arenaConfig.HeroClasses do classes[class.Id] = true end

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

	test("random layout: every enemy on its own cell of the 3x3", function()
		local enemies = ArenaRules.expandEnemies(stage)
		for seed = 1, 50 do
			local layout = ArenaRules.randomLayout(enemies, 9, seeded(seed))
			assert(layout)
			local n, bosses = 0, 0
			for cell, enemy in layout do
				assert(cell >= 1 and cell <= 9 and cell % 1 == 0)
				n += 1
				if enemy.MiniBoss then bosses += 1 end
			end
			assert(n == 7 and bosses == 1, "7 distinct cells")
		end
	end)

	test("random layout changes between fights of the same stage", function()
		local enemies = ArenaRules.expandEnemies(stage)
		local seen = {}
		local distinct = 0
		for seed = 1, 20 do
			local layout = ArenaRules.randomLayout(enemies, 9, seeded(seed * 7919))
			local key = {}
			for cell = 1, 9 do key[cell] = if layout[cell] then layout[cell].EnemyId else "-" end
			local text = table.concat(key, ",")
			if not seen[text] then
				seen[text] = true
				distinct += 1
			end
		end
		assert(distinct >= 15, "layouts vary: " .. distinct .. "/20")
	end)

	test("more enemies than cells is refused", function()
		local many = { Waves = { { Enemies = { { EnemyId = "Slime", Count = 10 } } } } }
		local layout, reason = ArenaRules.randomLayout(ArenaRules.expandEnemies(many), 9, seeded(1))
		assert(layout == nil and reason ~= nil)
	end)

	test("assign: up to 4 heroes, one unit per class", function()
		local f = {}
		assert(ArenaRules.assign(f, 1, "Archer", classes, 4))
		assert(ArenaRules.assign(f, 2, "Epeiste", classes, 4))
		assert(ArenaRules.assign(f, 5, "Barbare", classes, 4))
		assert(ArenaRules.assign(f, 9, "Paladin", classes, 4))
		local ok, reason = ArenaRules.assign(f, 3, "Magicien", classes, 4)
		assert(ok == false and reason == "4 héros maximum" and f[3] == nil, "5th hero refused on a free cell")
		assert(ArenaRules.assign(f, 7, "Archer", classes, 4), "same class moves instead of duplicating")
		assert(f[1] == nil and f[7] == "Archer" and ArenaRules.count(f) == 4)
		assert(ArenaRules.assign(f, 7, "Archer", classes, 4) and f[7] == "Archer", "re-assigning in place is a no-op")
	end)

	test("assign on an occupied cell replaces its hero, even with a full field", function()
		local f = { [1] = "Archer", [2] = "Epeiste", [5] = "Barbare", [9] = "Paladin" }
		assert(ArenaRules.assign(f, 5, "Magicien", classes, 4), "replace allowed at 4/4")
		assert(f[5] == "Magicien" and ArenaRules.count(f) == 4)
		for _, placed in f do assert(placed ~= "Barbare", "replaced hero goes back to the collection") end
		assert(ArenaRules.assign(f, 2, "Paladin", classes, 4), "moving a placed class onto an occupied cell")
		assert(f[2] == "Paladin" and f[9] == nil and ArenaRules.count(f) == 3)
	end)

	test("clear empties a cell; invalid cells and unknown classes refused", function()
		local f = { [4] = "Tireur" }
		assert(ArenaRules.clear(f, 4) and f[4] == nil)
		assert(ArenaRules.clear(f, 4), "clearing an empty cell is harmless")
		for _, bad in { 0, 10, 1.5, "1", {} } :: { any } do
			local ok, reason = ArenaRules.assign(f, bad, "Archer", classes, 4)
			assert(ok == false and reason == "case invalide")
			ok, reason = ArenaRules.clear(f, bad)
			assert(ok == false and reason == "case invalide")
		end
		local ok, reason = ArenaRules.assign(f, 1, "Dragon", classes, 4)
		assert(ok == false and reason == "classe inconnue" and next(f) == nil)
	end)

	test("prototype collection: exactly the six requested classes, max 4 heroes", function()
		local ids = {}
		for _, class in arenaConfig.HeroClasses do table.insert(ids, class.Id) end
		table.sort(ids)
		assert(table.concat(ids, ",") == "Archer,Barbare,Epeiste,Magicien,Paladin,Tireur")
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
