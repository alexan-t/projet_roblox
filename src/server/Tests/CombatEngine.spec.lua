--!strict
-- Hors du dossier Services : jamais exécuté par le bootstrap.
-- Teste le vrai CombatEngine (pur) avec la vraie CombatConfig et la vraie StageConfig.

return function(CombatEngine: any, combatConfig: any, stageConfig: any)
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

	-- Générateur déterministe au format Random:NextInteger.
	local function seeded(seed: number): any
		local s = seed
		return { NextInteger = function(_self: any, min: number, max: number): number
			s = (s * 1103515245 + 12345) % 2147483648
			return min + s % (max - min + 1)
		end }
	end
	local function first(): any
		return { NextInteger = function(_self: any, min: number, _max: number): number return min end }
	end

	-- Grille ennemie de test : case n à x = colonne * 10, z = -30 - ligne * 10.
	local function cells(): any
		local t = {}
		for n = 1, 9 do t[n] = { x = ((n - 1) % 3) * 10, z = -30 - ((n - 1) // 3) * 10 } end
		return t
	end
	local STAT = { MaxHealth = 100, AttackDamage = 10, AttackInterval = 1, AttackRange = 5, MoveSpeed = 10, EnergyPerAttack = 25, MaxEnergy = 100, UltimateDamage = 40 }
	local function stats(over: any?): any
		local t = table.clone(STAT)
		for k, v in over or {} do t[k] = v end
		return t
	end
	-- Moteur avec stats et positions maîtrisées (Random "first" : ennemis dans les cases 1, 2, 3...).
	local function engine(opts: any): any
		return CombatEngine.new({
			Stage = opts.Stage or { Waves = { { Enemies = { { EnemyId = "E", Count = opts.enemies or 1 } } } } },
			Heroes = opts.Heroes or { H = stats(opts.hero), H2 = stats(opts.hero2) },
			Enemies = opts.Enemies or { E = stats(opts.enemy), B = stats(opts.boss) },
			UltimateRadius = opts.radius or 8,
			Allies = opts.Allies or { { TypeId = "H", Slot = 1, Position = { x = 0, z = 0 } } },
			EnemyCells = opts.cells or cells(),
			Random = opts.random or first(),
			TickRate = 20,
			MaxFrameTime = 0.25,
		})
	end
	local function unitsOf(state: any, team: string): { any }
		local list = {}
		for _, u in state.units do if u.Team == team then table.insert(list, u) end end
		return list
	end
	local function eventsOf(events: { any }, kind: string): { any }
		local list = {}
		for _, e in events do if e.Type == kind then table.insert(list, e) end end
		return list
	end
	local function run(state: any, seconds: number)
		for _ = 1, math.floor(seconds * 20 + 0.5) do CombatEngine.step(state, 1 / 20) end
	end

	test("units created with config stats, full health, zero energy, unique ids", function()
		local s = engine({ hero = { MaxHealth = 123 }, enemies = 2 })
		local ally = unitsOf(s, "Ally")[1]
		assert(ally.Health == 123 and ally.MaxHealth == 123 and ally.Energy == 0 and ally.MaxEnergy == 100)
		assert(ally.Alive and ally.Slot == 1 and ally.TypeId == "H")
		local enemies = unitsOf(s, "Enemy")
		assert(#enemies == 2 and enemies[1].MaxEnergy == 0 and enemies[1].Health == 100)
		local ids = {}
		for _, u in s.units do assert(not ids[u.UnitId]); ids[u.UnitId] = true end
		local events = CombatEngine.drain(s)
		assert(events[1].Type == "CombatStarted" and #eventsOf(events, "UnitSpawned") == 3 and #eventsOf(events, "WaveStarted") == 1)
	end)

	test("targets the nearest living enemy, never an ally", function()
		local s = engine({ enemies = 3, Allies = {
			{ TypeId = "H", Slot = 1, Position = { x = 19, z = -10 } },
			{ TypeId = "H2", Slot = 2, Position = { x = 0, z = -10 } },
		} })
		CombatEngine.step(s, 1 / 20)
		local a1, a2 = unitsOf(s, "Ally")[1], unitsOf(s, "Ally")[2]
		local target1, target2 = s.byId[a1.TargetId], s.byId[a2.TargetId]
		assert(target1.Team == "Enemy" and target1.Cell == 3, "ally at x=19 targets cell 3 (x=20)")
		assert(target2.Team == "Enemy" and target2.Cell == 1, "ally at x=0 targets cell 1 (x=0)")
		for _, e in unitsOf(s, "Enemy") do assert(s.byId[e.TargetId].Team == "Ally", "enemies target allies") end
	end)

	test("equal distances resolved by smallest UnitId, whatever the table order", function()
		local s = engine({ enemies = 3, Allies = { { TypeId = "H", Slot = 1, Position = { x = 10, z = 0 } } } })
		-- Cases 1 et 3 à égale distance de x = 10 ; la case 2 est la plus proche : on la retire.
		local enemies = unitsOf(s, "Enemy")
		enemies[2].Health, enemies[2].Alive = 0, false
		CombatEngine.step(s, 1 / 20)
		local ally = unitsOf(s, "Ally")[1]
		assert(ally.TargetId == math.min(enemies[1].UnitId, enemies[3].UnitId))
		-- Même situation avec la liste des unités inversée : même choix.
		local s2 = engine({ enemies = 3, Allies = { { TypeId = "H", Slot = 1, Position = { x = 10, z = 0 } } } })
		local e2 = unitsOf(s2, "Enemy")
		e2[2].Health, e2[2].Alive = 0, false
		local reversed = {}
		for i = #s2.units, 1, -1 do table.insert(reversed, s2.units[i]) end
		s2.units = reversed
		CombatEngine.step(s2, 1 / 20)
		assert(unitsOf(s2, "Ally")[1].TargetId == ally.TargetId)
	end)

	test("moves toward an out-of-range target, stops at range, never attacks out of range", function()
		local s = engine({ hero = { MoveSpeed = 10, AttackRange = 5 }, enemy = { MoveSpeed = 0, AttackRange = 1 } })
		local ally = unitsOf(s, "Ally")[1]
		local enemy = unitsOf(s, "Enemy")[1] -- case 1 : (0, -30), 30 studs
		CombatEngine.drain(s)
		CombatEngine.step(s, 0.5)
		assert(math.abs(ally.Position.z - (-5)) < 1e-6, "moved 5 studs")
		local events = CombatEngine.drain(s)
		assert(#eventsOf(events, "MoveStarted") == 1 and #eventsOf(events, "Attack") == 0 and enemy.Health == 100)
		run(s, 3)
		local d = math.abs(ally.Position.z - enemy.Position.z)
		assert(math.abs(d - 5) < 1e-6, "stopped exactly at range, distance " .. d)
		assert(enemy.Health < 100, "attacks once in range")
		local stepEvents = CombatEngine.drain(s)
		assert(#eventsOf(stepEvents, "MoveStarted") == 0, "MoveStarted not repeated every frame")
	end)

	test("attack respects the cooldown; damage applied by the server", function()
		local s = engine({ hero = { AttackInterval = 1, AttackDamage = 10, AttackRange = 50 }, enemy = { AttackRange = 1, MoveSpeed = 0 } })
		local enemy = unitsOf(s, "Enemy")[1]
		CombatEngine.drain(s)
		CombatEngine.step(s, 1 / 20)
		assert(enemy.Health == 90, "first attack immediate")
		run(s, 0.9)
		assert(enemy.Health == 90, "no attack before the cooldown")
		run(s, 0.1)
		assert(enemy.Health == 80, "second attack after 1 s")
		local damage = eventsOf(CombatEngine.drain(s), "Damage")
		for _, e in damage do assert(e.Amount == 10) end
	end)

	test("health bounded at 0, death processed once, dead units stop acting", function()
		local s = engine({ hero = { AttackDamage = 250, AttackRange = 50 }, enemy = { AttackRange = 1, MoveSpeed = 5 }, enemies = 2 })
		local enemies = unitsOf(s, "Enemy")
		CombatEngine.drain(s)
		CombatEngine.step(s, 1 / 20)
		assert(enemies[1].Health == 0 and not enemies[1].Alive)
		assert(#eventsOf(CombatEngine.drain(s), "UnitDied") == 1)
		local deadPos = { x = enemies[1].Position.x, z = enemies[1].Position.z }
		run(s, 2)
		local events = CombatEngine.drain(s)
		local died = eventsOf(events, "UnitDied")
		assert(#died == 1 and died[1].UnitId == enemies[2].UnitId, "second death only; first not repeated")
		assert(enemies[1].Position.x == deadPos.x and enemies[1].Position.z == deadPos.z, "dead unit never moves")
		for _, e in eventsOf(events, "Attack") do assert(e.UnitId ~= enemies[1].UnitId, "dead unit never attacks") end
		for _, e in eventsOf(events, "Damage") do assert(e.Health >= 0) end
	end)

	test("retargets after the target dies", function()
		local s = engine({ hero = { AttackDamage = 200, AttackRange = 50, AttackInterval = 0.5 }, enemies = 2, enemy = { MoveSpeed = 0, AttackRange = 1 } })
		local ally = unitsOf(s, "Ally")[1]
		CombatEngine.step(s, 1 / 20)
		local firstTarget = ally.TargetId
		assert(not s.byId[firstTarget].Alive)
		CombatEngine.step(s, 1 / 20)
		assert(ally.TargetId ~= firstTarget and s.byId[ally.TargetId].Alive)
		local changes = eventsOf(CombatEngine.drain(s), "TargetChanged")
		assert(#changes >= 2)
	end)

	test("energy gained per attack, bounded at MaxEnergy", function()
		local s = engine({ hero = { EnergyPerAttack = 40, MaxEnergy = 100, AttackRange = 50, AttackDamage = 1, AttackInterval = 0.1 }, enemy = { MaxHealth = 10000, MoveSpeed = 0, AttackRange = 1 } })
		local ally = unitsOf(s, "Ally")[1]
		CombatEngine.drain(s)
		CombatEngine.step(s, 1 / 20)
		assert(ally.Energy == 40)
		run(s, 1)
		assert(ally.Energy == 100, "capped at 100, got " .. ally.Energy)
		local changes = eventsOf(CombatEngine.drain(s), "EnergyChanged")
		assert(changes[#changes].Energy == 100 and #changes == 3, "no EnergyChanged once full")
	end)

	test("ultimate: refused without energy, accepted when full, energy reset, burst damage", function()
		local s = engine({ hero = { EnergyPerAttack = 100, AttackRange = 50, AttackDamage = 1, UltimateDamage = 40 }, radius = 12, enemies = 3,
			enemy = { MoveSpeed = 0, AttackRange = 1, MaxHealth = 500 } })
		local ally = unitsOf(s, "Ally")[1]
		local ok, reason = CombatEngine.useUltimate(s, ally.UnitId)
		assert(ok == false and reason == "énergie insuffisante" and ally.Energy == 0)
		CombatEngine.step(s, 1 / 20) -- une attaque : énergie pleine
		assert(ally.Energy == 100)
		CombatEngine.drain(s)
		local before = {}
		for _, e in unitsOf(s, "Enemy") do before[e.UnitId] = e.Health end
		ok, reason = CombatEngine.useUltimate(s, ally.UnitId)
		assert(ok == true and ally.Energy == 0)
		local events = CombatEngine.drain(s)
		local used = eventsOf(events, "UltimateUsed")
		assert(#used == 1 and used[1].UnitId == ally.UnitId)
		-- Cible en case 1 (0, -30) ; case 2 à 10 studs (dans le rayon 12), case 3 à 20 (hors rayon).
		local hit = {}
		for _, id in used[1].Hits do hit[id] = true end
		local e = unitsOf(s, "Enemy")
		assert(hit[e[1].UnitId] and hit[e[2].UnitId] and not hit[e[3].UnitId])
		assert(e[1].Health == before[e[1].UnitId] - 40 and e[3].Health == before[e[3].UnitId])
		assert(select(1, CombatEngine.useUltimate(s, ally.UnitId)) == false, "no second cast without energy")
	end)

	test("ultimate refused for enemies, unknown or dead units", function()
		local s = engine({ enemies = 1 })
		local enemy = unitsOf(s, "Enemy")[1]
		local ally = unitsOf(s, "Ally")[1]
		assert(select(2, CombatEngine.useUltimate(s, enemy.UnitId)) == "unité invalide")
		assert(select(2, CombatEngine.useUltimate(s, 999)) == "unité invalide")
		assert(select(2, CombatEngine.useUltimate(s, "1")) == "unité invalide")
		ally.Energy = 100
		ally.Health, ally.Alive = 0, false
		assert(select(2, CombatEngine.useUltimate(s, ally.UnitId)) == "unité morte")
	end)

	test("x2 advances about twice the simulation for the same real time, same damage per hit", function()
		local function play(speed: number): any
			local s = engine({ hero = { AttackRange = 50, AttackInterval = 0.5, AttackDamage = 7 }, enemy = { MaxHealth = 100000, MoveSpeed = 0, AttackRange = 1 } })
			CombatEngine.drain(s)
			local steps = 0
			for _ = 1, 60 do steps += CombatEngine.advance(s, 1 / 60, speed) end -- 1 s réelle
			local attacks = eventsOf(CombatEngine.drain(s), "Damage")
			return { steps = steps, time = s.time, hits = attacks }
		end
		local x1, x2 = play(1), play(2)
		assert(math.abs(x1.time - 1) < 0.06 and math.abs(x2.time - 2) < 0.06, `times {x1.time} / {x2.time}`)
		assert(x2.steps == 2 * x1.steps, `steps {x1.steps} / {x2.steps}`)
		assert(#x2.hits == 2 * #x1.hits - 1 or #x2.hits == 2 * #x1.hits, `hits {#x1.hits} / {#x2.hits}`)
		for _, e in x2.hits do assert(e.Amount == 7, "damage per hit unchanged at x2") end
	end)

	test("lag spike capped, no burst of hidden simulation", function()
		local s = engine({ enemy = { MaxHealth = 100000, MoveSpeed = 0, AttackRange = 1 } })
		local steps = CombatEngine.advance(s, 10, 1)
		assert(steps == 5 and math.abs(s.time - 0.25) < 1e-6, "10 s frame counts as 0.25 s")
		assert(CombatEngine.advance(s, 10, 2) == 10, "x2 cap")
	end)

	test("several units act independently, results do not depend on table iteration", function()
		local function play(): string
			local s = CombatEngine.new({
				Stage = stageConfig.Zones[1].Stages[1], Heroes = combatConfig.Heroes, Enemies = combatConfig.Enemies,
				UltimateRadius = combatConfig.Ultimate.Radius,
				Allies = {
					{ TypeId = "Paladin", Slot = 2, Position = { x = 0, z = 0 } },
					{ TypeId = "Archer", Slot = 7, Position = { x = -9, z = 18 } },
					{ TypeId = "Barbare", Slot = 1, Position = { x = -9, z = 0 } },
				},
				EnemyCells = cells(), Random = seeded(42), TickRate = 20, MaxFrameTime = 0.25,
			})
			run(s, 20)
			local parts = {}
			for _, u in s.units do table.insert(parts, `{u.UnitId}:{u.TypeId}:{u.Health}:{math.floor(u.Position.x * 100)}:{math.floor(u.Position.z * 100)}`) end
			return table.concat(parts, "|")
		end
		assert(play() == play(), "identical runs")
	end)

	test("waves: all wave enemies first, then the mini-boss alone, then victory", function()
		local stage = { Waves = {
			{ Enemies = { { EnemyId = "E", Count = 2 } } },
			{ Enemies = { { EnemyId = "E", Count = 1 } } },
		}, MiniBoss = { EnemyId = "B" } }
		local s = engine({ Stage = stage, hero = { AttackDamage = 1000, AttackRange = 100, AttackInterval = 0.2 }, enemy = { MoveSpeed = 0, AttackRange = 1 }, boss = { MoveSpeed = 0, AttackRange = 1 } })
		local order = {}
		for _ = 1, 400 do
			CombatEngine.step(s, 1 / 20)
			for _, e in CombatEngine.drain(s) do
				if e.Type == "WaveStarted" then table.insert(order, "W" .. e.Wave)
				elseif e.Type == "MiniBossStarted" then table.insert(order, "MB")
				elseif e.Type == "UnitSpawned" and e.Team == "Enemy" then
					table.insert(order, e.TypeId)
					if e.TypeId == "B" then
						for _, u in unitsOf(s, "Enemy") do assert(u.TypeId == "B" or not u.Alive, "boss never alongside a wave") end
					end
				elseif e.Type == "CombatEnded" then table.insert(order, e.Result) end
			end
			if s.result then break end
		end
		assert(table.concat(order, ",") == "W1,E,E,W2,E,MB,B,Victory", table.concat(order, ","))
	end)

	test("defeat when every hero is dead, never after victory, result emitted once", function()
		local s = engine({ hero = { MaxHealth = 20, AttackDamage = 1 }, enemy = { AttackDamage = 50, AttackRange = 50 } })
		run(s, 5)
		assert(s.result == "Defeat")
		local ended = eventsOf(CombatEngine.drain(s), "CombatEnded")
		assert(#ended == 1 and ended[1].Result == "Defeat")
		run(s, 5)
		assert(#eventsOf(CombatEngine.drain(s), "CombatEnded") == 0 and CombatEngine.advance(s, 1, 1) == 0)
		assert(select(2, CombatEngine.useUltimate(s, 1)) == "combat terminé")
	end)

	test("real Stage 1-1 with the real config: 4 heroes win in a reasonable time, 1 Magicien loses", function()
		local function simulate(allies: { any }, seed: number): (string?, number, boolean)
			local s = CombatEngine.new({
				Stage = stageConfig.Zones[1].Stages[1], Heroes = combatConfig.Heroes, Enemies = combatConfig.Enemies,
				UltimateRadius = combatConfig.Ultimate.Radius, Allies = allies, EnemyCells = cells(), Random = seeded(seed),
				TickRate = 20, MaxFrameTime = 0.25,
			})
			local bossSeen = false
			for _ = 1, 20 * 300 do
				CombatEngine.step(s, 1 / 20)
				for _, e in CombatEngine.drain(s) do if e.Type == "MiniBossStarted" then bossSeen = true end end
				if s.result then break end
			end
			return s.result, s.time, bossSeen
		end
		local team = {
			{ TypeId = "Paladin", Slot = 2, Position = { x = 10, z = 0 } },
			{ TypeId = "Epeiste", Slot = 1, Position = { x = 0, z = 0 } },
			{ TypeId = "Archer", Slot = 7, Position = { x = 0, z = 18 } },
			{ TypeId = "Magicien", Slot = 9, Position = { x = 20, z = 18 } },
		}
		for seed = 1, 5 do
			local result, time, boss = simulate(team, seed)
			assert(result == "Victory" and boss, `seed {seed}: {result}`)
			assert(time > 10 and time < 150, `seed {seed}: {time} s`)
		end
		local result = simulate({ { TypeId = "Magicien", Slot = 5, Position = { x = 10, z = 9 } } }, 1)
		assert(result == "Defeat", "lone Magicien loses: " .. tostring(result))
	end)

	test("allies spawned in slot order whatever the formation order", function()
		local s = engine({ Allies = {
			{ TypeId = "H2", Slot = 9, Position = { x = 0, z = 18 } },
			{ TypeId = "H", Slot = 2, Position = { x = 10, z = 0 } },
		} })
		local allies = unitsOf(s, "Ally")
		assert(allies[1].Slot == 2 and allies[2].Slot == 9 and allies[1].UnitId < allies[2].UnitId)
	end)

	test("enemies of a wave occupy distinct cells", function()
		for seed = 1, 20 do
			local s = engine({ enemies = 9, random = seeded(seed) })
			local seen = {}
			for _, e in unitsOf(s, "Enemy") do
				assert(e.Cell and not seen[e.Cell], `seed {seed}: cell {e.Cell} reused`)
				seen[e.Cell] = true
				local cell = cells()[e.Cell]
				assert(e.Position.x == cell.x and e.Position.z == cell.z, "unit placed on its cell")
			end
		end
	end)

	test("Damage.Amount is the health really lost (overkill not counted)", function()
		local s = engine({ hero = { AttackDamage = 250, AttackRange = 50 }, enemy = { MaxHealth = 60, MoveSpeed = 0, AttackRange = 1 } })
		CombatEngine.drain(s)
		CombatEngine.step(s, 1 / 20)
		local damage = eventsOf(CombatEngine.drain(s), "Damage")
		assert(#damage == 1 and damage[1].Amount == 60 and damage[1].Health == 0)
	end)

	test("immobile unit out of range neither moves nor attacks", function()
		local s = engine({ hero = { MoveSpeed = 0, AttackRange = 5 }, enemy = { MoveSpeed = 0, AttackRange = 1 } })
		local ally = unitsOf(s, "Ally")[1]
		CombatEngine.drain(s)
		run(s, 2)
		local events, moved = CombatEngine.drain(s)
		assert(ally.Position.x == 0 and ally.Position.z == 0 and next(moved) == nil)
		assert(#eventsOf(events, "MoveStarted") == 0 and #eventsOf(events, "Attack") == 0)
	end)

	test("enemies never gain energy", function()
		local s = engine({ enemy = { AttackRange = 50, EnergyPerAttack = 50, MaxEnergy = 100 }, hero = { MaxHealth = 100000 } })
		local enemy = unitsOf(s, "Enemy")[1]
		run(s, 5)
		assert(enemy.Energy == 0 and enemy.MaxEnergy == 0)
		for _, e in eventsOf(CombatEngine.drain(s), "EnergyChanged") do assert(e.UnitId ~= enemy.UnitId) end
	end)

	test("ultimate never hits allies, even inside the radius", function()
		local s = engine({ hero = { EnergyPerAttack = 100, AttackRange = 50, AttackDamage = 1, UltimateDamage = 40 }, radius = 100,
			enemy = { MoveSpeed = 0, AttackRange = 1, MaxHealth = 500 }, Allies = {
				{ TypeId = "H", Slot = 1, Position = { x = 0, z = -26 } },
				{ TypeId = "H2", Slot = 2, Position = { x = 2, z = -26 } },
			} })
		CombatEngine.step(s, 1 / 20)
		local caster = unitsOf(s, "Ally")[1]
		local other = unitsOf(s, "Ally")[2]
		local before = other.Health
		assert(CombatEngine.useUltimate(s, caster.UnitId) == true)
		local used = eventsOf(CombatEngine.drain(s), "UltimateUsed")[1]
		for _, id in used.Hits do assert(s.byId[id].Team == "Enemy") end
		assert(other.Health == before)
	end)

	test("ultimate that kills the last enemy advances the stage at once", function()
		local stage = { Waves = { { Enemies = { { EnemyId = "E", Count = 1 } } } }, MiniBoss = { EnemyId = "B" } }
		local s = engine({ Stage = stage, hero = { EnergyPerAttack = 100, AttackRange = 50, AttackDamage = 1, UltimateDamage = 1000 },
			enemy = { MoveSpeed = 0, AttackRange = 1 }, boss = { MoveSpeed = 0, AttackRange = 1 } })
		local ally = unitsOf(s, "Ally")[1]
		CombatEngine.step(s, 1 / 20)
		CombatEngine.drain(s)
		assert(CombatEngine.useUltimate(s, ally.UnitId) == true)
		local events = CombatEngine.drain(s)
		assert(#eventsOf(events, "UnitDied") == 1 and #eventsOf(events, "MiniBossStarted") == 1, "mini-boss right after the kill")
		ally.Energy = 100
		assert(CombatEngine.useUltimate(s, ally.UnitId) == true)
		assert(s.result == "Victory" and #eventsOf(CombatEngine.drain(s), "CombatEnded") == 1)
	end)

	test("ultimate refused when no enemy is alive", function()
		local s = engine({})
		local ally = unitsOf(s, "Ally")[1]
		ally.Energy = 100
		for _, e in unitsOf(s, "Enemy") do e.Health, e.Alive = 0, false end
		local ok, reason = CombatEngine.useUltimate(s, ally.UnitId)
		assert(ok == false and reason == "aucune cible" and ally.Energy == 100, "energy kept when refused")
	end)

	test("stage without mini-boss: victory right after the last wave, mini-boss flag only on the boss", function()
		local s = engine({ hero = { AttackDamage = 1000, AttackRange = 100 }, enemy = { MoveSpeed = 0, AttackRange = 1 } })
		for _, e in eventsOf(CombatEngine.drain(s), "UnitSpawned") do assert(e.MiniBoss == false) end
		run(s, 1)
		local events = CombatEngine.drain(s)
		assert(s.result == "Victory" and #eventsOf(events, "MiniBossStarted") == 0)
		local withBoss = engine({ Stage = { Waves = { { Enemies = { { EnemyId = "E", Count = 1 } } } }, MiniBoss = { EnemyId = "B" } },
			hero = { AttackDamage = 1000, AttackRange = 100 }, enemy = { MoveSpeed = 0, AttackRange = 1 }, boss = { MoveSpeed = 0, AttackRange = 1, MaxHealth = 100000 } })
		run(withBoss, 1)
		local boss = eventsOf(CombatEngine.drain(withBoss), "UnitSpawned")
		assert(boss[#boss].TypeId == "B" and boss[#boss].MiniBoss == true)
	end)

	test("drain empties the queue; moved lists only units that moved", function()
		local s = engine({ hero = { MoveSpeed = 10, AttackRange = 5 }, enemy = { MoveSpeed = 0, AttackRange = 1 } })
		local ally = unitsOf(s, "Ally")[1]
		local enemy = unitsOf(s, "Enemy")[1]
		CombatEngine.drain(s)
		CombatEngine.step(s, 1 / 20)
		local _, moved = CombatEngine.drain(s)
		assert(moved[ally.UnitId] and not moved[enemy.UnitId])
		local events, moved2 = CombatEngine.drain(s)
		assert(#events == 0 and next(moved2) == nil)
	end)

	test("small frames accumulate into fixed steps; nothing runs after the end", function()
		local s = engine({ enemy = { MaxHealth = 100000, MoveSpeed = 0, AttackRange = 1 } })
		assert(CombatEngine.advance(s, 0.03, 1) == 0, "0.03 s < one step")
		assert(CombatEngine.advance(s, 0.03, 1) == 1, "0.06 s = one step")
		s.result = "Defeat"
		local time = s.time
		CombatEngine.step(s, 1)
		assert(s.time == time and CombatEngine.advance(s, 0.25, 2) == 0)
	end)

	print(`CombatEngine: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{failed} CombatEngine test(s) failed`)
	end
end
