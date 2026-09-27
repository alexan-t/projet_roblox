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

	test("placement: up to 4 heroes, one of each class, click again removes", function()
		local f = {}
		assert(ArenaRules.toggle(f, 1, "Archer", classes, 4))
		assert(ArenaRules.toggle(f, 2, "Epeiste", classes, 4))
		assert(ArenaRules.toggle(f, 5, "Barbare", classes, 4))
		assert(ArenaRules.toggle(f, 9, "Paladin", classes, 4))
		local ok, reason = ArenaRules.toggle(f, 3, "Magicien", classes, 4)
		assert(ok == false and reason == "4 héros maximum" and f[3] == nil)
		assert(ArenaRules.toggle(f, 9, "Magicien", classes, 4) and f[9] == nil, "click on occupied cell removes")
		assert(ArenaRules.toggle(f, 3, "Magicien", classes, 4) and f[3] == "Magicien")
		assert(ArenaRules.toggle(f, 7, "Archer", classes, 4), "same class moves instead of duplicating")
		assert(f[1] == nil and f[7] == "Archer" and ArenaRules.count(f) == 4)
	end)

	test("placement refuses unknown classes and invalid cells", function()
		local f = {}
		for _, bad in { 0, 10, 1.5, "1", {} } :: { any } do
			local ok, reason = ArenaRules.toggle(f, bad, "Archer", classes, 4)
			assert(ok == false and reason == "case invalide")
		end
		local ok, reason = ArenaRules.toggle(f, 1, "Dragon", classes, 4)
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
