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
	-- Stage avec mini-boss (l'ancien 1-1) : l'expansion et le résumé du mini-boss restent couverts.
	local hard = { Waves = { { Enemies = { { EnemyId = "Slime", Count = 2 }, { EnemyId = "Gobelin", Count = 4 } } } }, MiniBoss = { EnemyId = "Boss" } }

	test("real Stage 1-1 (entry stage) expands to 2 Slime and 2 Gobelin, no mini-boss", function()
		local enemies = ArenaRules.expandEnemies(stage)
		assert(#enemies == 4)
		local counts: { [string]: number } = {}
		for _, e in enemies do
			counts[e.EnemyId] = (counts[e.EnemyId] or 0) + 1
			assert(e.MiniBoss == false)
		end
		assert(counts.Slime == 2 and counts.Gobelin == 2 and counts.Boss == nil)
	end)

	test("a stage with a mini-boss expands to its waves, then the Boss mini-boss", function()
		local enemies = ArenaRules.expandEnemies(hard)
		assert(#enemies == 7)
		local counts: { [string]: number } = {}
		for _, e in enemies do counts[e.EnemyId] = (counts[e.EnemyId] or 0) + 1 end
		assert(counts.Slime == 2 and counts.Gobelin == 4 and counts.Boss == 1)
		assert(enemies[7].EnemyId == "Boss" and enemies[7].MiniBoss == true and enemies[1].MiniBoss == false)
	end)

	test("summary tells which enemies and how many, never positions", function()
		local real = ArenaRules.summarize(stage)
		assert(#real == 2 and real[1].EnemyId == "Slime" and real[1].Count == 2 and real[2].EnemyId == "Gobelin" and real[2].Count == 2)
		local summary = ArenaRules.summarize(hard)
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

	-- Deux arènes de plots voisins : A autour de (0, 0), B autour de (163, 0) (écart mesuré en Studio).
	local function grid(ox: number): any
		local poses = {}
		for slot = 1, 9 do poses[slot] = { x = ox + ((slot - 1) % 3) * 10, z = ((slot - 1) // 3) * 10 } end
		return poses
	end
	local posesA, posesB = grid(0), grid(163)
	local zoneA = ArenaRules.zone(posesA, 10)
	local zoneB = ArenaRules.zone(posesB, 10)

	test("zone: circle around the 9 tiles plus margin", function()
		assert(zoneA and zoneA.center.x == 10 and zoneA.center.z == 10)
		assert(math.abs(zoneA.radius - (math.sqrt(200) + 10)) < 1e-6)
		assert(ArenaRules.zone({}, 10) == nil, "no tiles, no zone")
	end)

	test("A acts on its own arena only from inside its zone and within reach of the tile", function()
		assert(ArenaRules.canInteract({ x = 11, z = 9 }, zoneA, posesA[5], 14) == true, "standing on its tile 5")
		assert(ArenaRules.canInteract({ x = 11, z = 9 }, zoneA, nil, 14) == true, "Ready from inside the zone")
		local ok, reason = ArenaRules.canInteract({ x = 11, z = 9 }, zoneA, posesA[6], 14)
		assert(ok == true and reason == nil, "neighbour tile 6 (9 studs) within reach")
		ok, reason = ArenaRules.canInteract({ x = -5, z = 20 }, zoneA, posesA[3], 14)
		assert(ok == false and reason == "Approche-toi de la dalle", "inside the zone but too far from that tile")
	end)

	test("A standing in B's arena (or anywhere outside its own zone) can do nothing on its arena", function()
		local inB = { x = 173, z = 10 }
		assert(ArenaRules.canInteract(inB, zoneB, posesB[5], 14) == true, "B's own position is fine for B")
		for _, pose in { posesA[1], posesA[5], posesA[9], nil } :: { any } do
			local ok, reason = ArenaRules.canInteract(inB, zoneA, pose, 14)
			assert(ok == false and reason == "Approche-toi de ton arène")
		end
		local ok, reason = ArenaRules.canInteract({ x = 60, z = 10 }, zoneA, nil, 14)
		assert(ok == false and reason == "Approche-toi de ton arène", "between plots: no Ready")
		assert(select(2, ArenaRules.canInteract(nil, zoneA, posesA[1], 14)) == "Approche-toi de ton arène", "no character")
		assert(select(2, ArenaRules.canInteract({ x = 10, z = 10 }, nil, posesA[1], 14)) == "Approche-toi de ton arène", "no arena")
	end)

	-- Liste façon ZoneService:ListStages : le stage n est débloqué si n-1 est terminé (First Clear).
	local function listAfter(cleared: number, total: number?): { any }
		local list = {}
		for stage = 1, total or 5 do
			table.insert(list, { Zone = 1, Stage = stage, Status = if stage <= cleared + 1 then "Unlocked" else "Locked", Cleared = stage <= cleared })
		end
		return list
	end

	test("stage selection: default = first unlocked not cleared (new player 1-1, after 1-1 -> 1-2), all cleared -> last", function()
		local z, s = ArenaRules.defaultStage(listAfter(0))
		assert(z == 1 and s == 1, "new player: 1-1")
		z, s = ArenaRules.defaultStage(listAfter(1))
		assert(z == 1 and s == 2, "rejoin after 1-1: 1-2")
		z, s = ArenaRules.defaultStage(listAfter(5))
		assert(z == 1 and s == 5, "everything cleared: last stage, no 1-6")
		assert(ArenaRules.defaultStage({}) == nil, "no stage")
	end)

	test("stage selection advances after a win: 1-1 -> 1-2 -> 1-3 -> 1-4 -> 1-5, no 1-6", function()
		for stage = 1, 4 do
			local z, s = ArenaRules.nextStage(listAfter(stage), 1, stage)
			assert(z == 1 and s == stage + 1, `1-{stage} -> 1-{stage + 1}`)
		end
		local z, s = ArenaRules.nextStage(listAfter(5), 1, 5)
		assert(z == 1 and s == 5, "1-5 stays 1-5")
		z, s = ArenaRules.nextStage(listAfter(3), 1, 1)
		assert(z == 1 and s == 2, "replaying 1-1 later: next is 1-2 (already unlocked)")
		z, s = ArenaRules.nextStage(listAfter(0), 1, 1)
		assert(z == 1 and s == 1, "next still locked (no First Clear recorded): stay")
	end)

	-- Progression façon ArenaService (#120) : Zone 1 (avec butin) puis Zone 2 (sans butin, tant que #115 n'est
	-- pas livrée) en Normal ; Élite de la Zone 1 débloquée par 1-5, chaque stage Élite par le précédent.
	-- normalCleared : stages Normal gagnés dans l'ordre (0..10) ; eliteCleared : stages Élite gagnés (0..5).
	local function progress(normalCleared: number, eliteCleared: number, zone2Loot: boolean?): ({ any }, { any })
		local normal = {}
		for index = 1, 10 do
			local zone, stage = if index <= 5 then 1 else 2, (index - 1) % 5 + 1
			table.insert(normal, { Zone = zone, Stage = stage, Status = if index <= normalCleared + 1 then "Unlocked" else "Locked",
				Cleared = index <= normalCleared, Loot = zone == 1 or zone2Loot == true })
		end
		local elite = {}
		for stage = 1, 5 do
			local open = normalCleared >= 5 and stage <= eliteCleared + 1
			table.insert(elite, { Zone = 1, Stage = stage, Status = if open then "Unlocked" else "Locked", Cleared = stage <= eliteCleared, Loot = true })
		end
		return normal, elite
	end
	local function same(objective: any, kind: string, mode: string, zone: number, stage: number): boolean
		return objective ~= nil and objective.Kind == kind and objective.Mode == mode and objective.Zone == zone and objective.Stage == stage
	end

	test("#120 objective: new player 1-1, Normal in progress, Élite after 1-5 (never 2-1 without loot), farm 1-5E at the end", function()
		assert(same(ArenaRules.objective(progress(0, 0)), "Normal", "Normal", 1, 1), "new player: 1-1")
		assert(same(ArenaRules.objective(progress(3, 0)), "Normal", "Normal", 1, 4), "after 1-3: 1-4")
		assert(same(ArenaRules.objective(progress(5, 0)), "EliteNew", "Elite", 1, 1), "after 1-5: discover the Élite on 1-1E, not 2-1")
		assert(same(ArenaRules.objective(progress(5, 2)), "Elite", "Elite", 1, 3), "Élite in progress: next Élite stage")
		assert(same(ArenaRules.objective(progress(6, 2)), "Elite", "Elite", 1, 3), "2-1 won anyway: Zone 2 still not proposed")
		assert(same(ArenaRules.objective(progress(5, 5)), "Farm", "Elite", 1, 5), "everything won: farm 1-5E, the best source")
		assert(same(ArenaRules.objective(progress(5, 0, true)), "Normal", "Normal", 2, 1), "Zone 2 with loot (#115): proposed again")
	end)

	test("#120 objective: no loot anywhere -> nil (the caller keeps defaultStage); never a locked stage", function()
		local normal, elite = progress(5, 0)
		for _, entry in normal do entry.Loot = false end
		for _, entry in elite do entry.Loot = false end
		assert(ArenaRules.objective(normal, elite) == nil)
		local n2, e2 = progress(5, 0)
		for _, entry in e2 do entry.Status = "Locked" end
		assert(same(ArenaRules.objective(n2, e2), "Farm", "Normal", 1, 5), "Élite not unlocked: nothing locked is proposed")
	end)

	test("#120 after a victory: next objective (1-5 -> 1-1E, Élite -> next Élite), replays jump to the objective, farm stays", function()
		-- progression APRÈS la victoire (First Clear déjà enregistré), puis le stage qui vient d'être gagné
		local function after(normalCleared: number, eliteCleared: number, mode: string, zone: number, stage: number): (string, number, number)
			local normal, elite = progress(normalCleared, eliteCleared)
			return ArenaRules.afterVictory(normal, elite, mode, zone, stage)
		end
		local mode, z, s = after(5, 0, "Normal", 1, 5)
		assert(mode == "Elite" and z == 1 and s == 1, "Roi Orc beaten: 1-1E, not 2-1")
		mode, z, s = after(5, 1, "Elite", 1, 1)
		assert(mode == "Elite" and z == 1 and s == 2, "1-1E -> 1-2E")
		mode, z, s = after(5, 3, "Normal", 1, 2)
		assert(mode == "Elite" and z == 1 and s == 4, "Normal replay won while 1-4E waits: back to the objective")
		mode, z, s = after(5, 5, "Elite", 1, 5)
		assert(mode == "Elite" and z == 1 and s == 5, "1-5E beaten: stays on 1-5E (farm)")
		mode, z, s = after(5, 5, "Elite", 1, 2)
		assert(mode == "Elite" and z == 1 and s == 2, "everything won: the farmed stage stays selected")
		mode, z, s = after(2, 0, "Normal", 1, 2)
		assert(mode == "Normal" and z == 1 and s == 3, "Normal: 1-2 -> 1-3 as before")
	end)

	test("#120 after a victory without any loot table: the old nextStage behaviour in the same mode", function()
		local normal, elite = progress(2, 0)
		for _, entry in normal do entry.Loot = false end
		for _, entry in elite do entry.Loot = false end
		local mode, z, s = ArenaRules.afterVictory(normal, elite, "Normal", 1, 2)
		assert(mode == "Normal" and z == 1 and s == 3)
	end)

	test("stage selection uses the real StageConfig: 6 zones of exactly 5 stages", function()
		assert(#stageConfig.Zones == 6)
		for zone = 1, 6 do
			assert(#stageConfig.Zones[zone].Stages == 5, `zone {zone}`)
		end
	end)

	print(`ArenaRules: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{failed} ArenaRules test(s) failed`)
	end
end
