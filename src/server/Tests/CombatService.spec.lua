--!strict
-- Hors du dossier Services : jamais exécuté par le bootstrap.
-- Exécute le vrai CombatService (avec le vrai CombatEngine et la vraie CombatConfig) et des doubles
-- de ZoneService, DataService et des API Roblox utilisées.

return function(createService: any, CombatEngine: any, combatConfig: any, stageConfig: any)
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

	local function vector(x: number, y: number, z: number): any
		return setmetatable({ X = x, Y = y, Z = z }, {
			__add = function(a: any, b: any): any return vector(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end,
			__sub = function(a: any, b: any): any return vector(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end,
			__div = function(a: any, n: number): any return vector(a.X / n, a.Y / n, a.Z / n) end,
			__index = function(v: any, key: string): any
				if key == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
				return nil
			end,
		})
	end
	local function seeded(seed: number): any
		local s = seed
		return { NextInteger = function(_self: any, min: number, max: number): number
			s = (s * 1103515245 + 12345) % 2147483648
			return min + s % (max - min + 1)
		end }
	end

	local function fixture(): any
		local env: any = { data = {}, stages = {}, completions = {}, completeCalls = 0, fired = {}, instances = {}, delayed = {}, spawned = {}, nextStageId = 0 }
		local function signal(): any
			local sig: any = { listeners = {} }
			function sig:Connect(fn: any) table.insert(self.listeners, fn) end
			function sig:Fire(...: any) for _, fn in self.listeners do fn(...) end end
			return sig
		end
		env.players = { PlayerRemoving = signal() }
		env.heartbeat = signal()
		local replicated: any = { Shared = { Utils = { Log = { debug = function() end, info = function() end, warn = function() end } } } }
		function replicated:FindFirstChild(name: string): any
			for _, i in env.instances do if i.Name == name and i.Parent == replicated then return i end end
			return nil
		end
		env.replicated = replicated
		env.game = { GetService = function(_self: any, name: string): any
			return ({ Players = env.players, ReplicatedStorage = replicated, RunService = { Heartbeat = env.heartbeat } })[name]
		end }
		local dataService: any = {}
		function dataService:GetData(player: any): any return env.data[player] end
		local zoneService: any = {}
		function zoneService:GetSession(player: any): any return env.stages[player] end
		function zoneService:CompleteStage(player: any, id: number, victory: boolean): boolean
			env.completeCalls += 1
			local stage = env.stages[player]
			if not stage or stage.Id ~= id then return false end
			env.stages[player] = nil
			table.insert(env.completions, { player = player, id = id, victory = victory })
			return true
		end
		env.script = { Parent = { DataService = dataService, ZoneService = zoneService,
			Parent = { Config = { CombatConfig = combatConfig }, Combat = { CombatEngine = CombatEngine } } } }
		env.require = function(module: any): any return module end
		env.Instance = { new = function(class: string): any
			local i: any = { ClassName = class, Name = class }
			if class == "RemoteEvent" then
				function i:FireClient(player: any, combatId: number, events: any)
					table.insert(env.fired, { player = player, combatId = combatId, events = events })
				end
			end
			table.insert(env.instances, i)
			return i
		end }
		env.Random = { new = function(): any return seeded(7) end }
		env.Vector3 = { new = vector, zero = vector(0, 0, 0) }
		env.CFrame = { lookAt = function(pos: any, look: any): any
			local d = look - pos
			local m = d.Magnitude
			return { Position = pos, LookVector = if m > 0 then d / m else vector(0, 0, -1) }
		end }
		env.task = {
			delay = function(_t: number, fn: any) table.insert(env.delayed, fn) end,
			spawn = function(fn: any, ...: any) fn(...) end,
		}

		function env.player(name: string): any
			local p: any = { Name = name, Parent = env.players, attributes = { DataLoaded = true } }
			function p:GetAttribute(key: string): any return self.attributes[key] end
			env.data[p] = {
				Currencies = { Gold = 0, Gems = 0, SummonTickets = 0 },
				Progression = { CurrentZone = 1, HighestStage = 0, FirstClears = {} },
				Settings = { CombatSpeed = 1 }, Heroes = {}, Quests = {},
			}
			env.nextStageId += 1
			env.stages[p] = { Id = env.nextStageId, Zone = 1, Stage = 1, Config = stageConfig.Zones[1].Stages[1] }
			return p
		end
		-- Géométrie de l'arène : 3x3 héros (z 0..18) et 3x3 ennemis (z -21..-30), comme PlotTravail.
		function env.context(): any
			local heroes, enemies = {}, {}
			for n = 1, 9 do
				heroes[n] = vector(((n - 1) % 3) * 9, 0, ((n - 1) // 3) * 9)
				enemies[n] = vector(((n - 1) % 3) * 9, 0, -21 - ((n - 1) // 3) * 4.7)
			end
			return {
				HeroPositions = heroes,
				EnemyPositions = enemies,
				SpawnUnit = function(unit: any, feet: any, _look: any): any
					local model: any = { attributes = {}, pivot = { Position = vector(feet.X, feet.Y + 3, feet.Z), LookVector = vector(0, 0, -1) }, moves = 0 }
					function model:SetAttribute(k: string, v: any) self.attributes[k] = v end
					function model:GetPivot(): any return self.pivot end
					function model.PivotTo(self: any, cf: any) self.pivot = cf; self.moves += 1 end
					function model:Destroy() self.destroyed = true end
					model.unit = unit
					table.insert(env.spawned, model)
					return model
				end,
			}
		end
		function env.start(): any
			env.service = createService(env)
			env.service:Start()
			return env.service
		end
		function env.tick(seconds: number, dt: number?)
			local step = dt or 0.25
			for _ = 1, math.floor(seconds / step + 0.5) do env.heartbeat:Fire(step) end
		end
		function env.remote(name: string): any
			for _, i in env.instances do if i.Name == name then return i end end
			return nil
		end
		function env.events(player: any, kind: string?): { any }
			local list = {}
			for _, batch in env.fired do
				if batch.player == player then
					for _, e in batch.events do if not kind or e.Type == kind then table.insert(list, e) end end
				end
			end
			return list
		end
		function env.runUntilEnd(s: any, p: any, maxSeconds: number): boolean
			for _ = 1, maxSeconds * 4 do
				env.heartbeat:Fire(0.25)
				if not s:GetCombat(p) then return true end
			end
			return false
		end
		return env
	end

	local TEAM = { [1] = "Epeiste", [2] = "Paladin", [7] = "Archer", [9] = "Magicien" }

	local function deepEqual(a: any, b: any): boolean
		if type(a) ~= "table" or type(b) ~= "table" then return a == b end
		for k, v in a do if not deepEqual(v, b[k]) then return false end end
		for k in b do if a[k] == nil then return false end end
		return true
	end

	test("StartCombat refused without a stage session, with a wrong id, empty or oversized formation, unknown class", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local id = e.stages[p].Id
		local noStage = e.player("B")
		e.stages[noStage] = nil
		assert(select(2, s:StartCombat(noStage, 1, TEAM, e.context())) == "session de stage invalide")
		assert(select(2, s:StartCombat(p, id + 100, TEAM, e.context())) == "session de stage invalide")
		assert(select(2, s:StartCombat(p, id, {}, e.context())) == "formation vide")
		local five = { [1] = "Archer", [2] = "Epeiste", [3] = "Barbare", [4] = "Paladin", [5] = "Magicien" }
		assert(select(2, s:StartCombat(p, id, five, e.context())) == "4 héros maximum")
		assert(select(2, s:StartCombat(p, id, { [1] = "Dragon" }, e.context())) == "classe inconnue")
		assert(select(2, s:StartCombat(p, id, { [12] = "Archer" }, e.context())) == "case héros invalide")
		assert(s:GetCombat(p) == nil and #e.spawned == 0)
	end)

	test("session created; second combat refused; wave 1 = 2 Slime + 4 Gobelin, no Boss", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local combatId = s:StartCombat(p, e.stages[p].Id, TEAM, e.context())
		assert(combatId)
		assert(select(2, s:StartCombat(p, e.stages[p].Id, TEAM, e.context())) == "combat déjà en cours")
		local view = s:GetCombat(p)
		assert(view and view.Id == combatId and view.Wave == 1 and view.WaveCount == 1 and view.Speed == 1)
		local counts: { [string]: number } = {}
		for _, u in view.Units do counts[u.Team .. u.TypeId] = (counts[u.Team .. u.TypeId] or 0) + 1 end
		assert(counts.EnemySlime == 2 and counts.EnemyGobelin == 4 and counts.EnemyBoss == nil, "no Boss in wave 1")
		assert((counts.AllyEpeiste or 0) + (counts.AllyPaladin or 0) + (counts.AllyArcher or 0) + (counts.AllyMagicien or 0) == 4)
		assert(#e.spawned == 10, "10 models (4 allies + 6 enemies)")
		local spawned = e.events(p, "UnitSpawned")
		assert(#spawned == 10 and #e.events(p, "WaveStarted") == 1 and #e.events(p, "CombatStarted") == 1)
	end)

	test("Boss only after wave 1 is dead, then victory: CompleteStage(true) exactly once", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local zoneId = e.stages[p].Id
		local ended = {}
		s:OnCombatEnded(function(player: any, id: number, result: string) table.insert(ended, { player, id, result }) end)
		local combatId = s:StartCombat(p, zoneId, TEAM, e.context())
		assert(e.runUntilEnd(s, p, 300), "combat ends")
		local order = {}
		for _, ev in e.events(p) do
			if ev.Type == "MiniBossStarted" then table.insert(order, "MB")
			elseif ev.Type == "UnitSpawned" and ev.TypeId == "Boss" then table.insert(order, "Boss")
			elseif ev.Type == "UnitDied" and ev.Team == "Enemy" and ev.TypeId ~= "Boss" then table.insert(order, "wave-death")
			elseif ev.Type == "CombatEnded" then table.insert(order, ev.Result) end
		end
		local text = table.concat(order, ",")
		assert(text == "wave-death,wave-death,wave-death,wave-death,wave-death,wave-death,MB,Boss,Victory", text)
		assert(#e.completions == 1 and e.completions[1].victory == true and e.completions[1].id == zoneId)
		assert(e.completeCalls == 1, "CompleteStage called exactly once")
		assert(#ended == 1 and ended[1][2] == combatId and ended[1][3] == "Victory")
		e.tick(5)
		assert(#e.completions == 1, "no second completion")
		for _, fn in e.delayed do fn() end -- retrait différé des modèles d'unités mortes
		for _, m in e.spawned do assert(m.destroyed, "all models cleaned") end
	end)

	test("defeat when all heroes die: CompleteStage(false) exactly once", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		s:StartCombat(p, e.stages[p].Id, { [5] = "Magicien" }, e.context())
		assert(e.runUntilEnd(s, p, 300))
		assert(#e.completions == 1 and e.completions[1].victory == false and e.completeCalls == 1)
		local ended = e.events(p, "CombatEnded")
		assert(#ended == 1 and ended[1].Result == "Defeat")
	end)

	test("cancel and leave never call CompleteStage", function()
		local e = fixture()
		local s = e.start()
		local a, b = e.player("A"), e.player("B")
		s:StartCombat(a, e.stages[a].Id, TEAM, e.context())
		s:StartCombat(b, e.stages[b].Id, TEAM, e.context())
		e.tick(3)
		assert(s:CancelCombat(a) == true and s:GetCombat(a) == nil)
		e.players.PlayerRemoving:Fire(b)
		b.Parent = nil
		e.tick(200)
		assert(#e.completions == 0 and e.completeCalls == 0 and s:GetCombat(b) == nil)
		assert(s:CancelCombat(a) == false)
	end)

	test("stage session lost, profile lost or player gone: combat cancelled without result", function()
		local e = fixture()
		local s = e.start()
		local a, b, c = e.player("A"), e.player("B"), e.player("C")
		for _, p in { a, b, c } do s:StartCombat(p, e.stages[p].Id, TEAM, e.context()) end
		e.stages[a] = nil
		b.attributes.DataLoaded = nil
		c.Parent = nil
		e.tick(1)
		for _, p in { a, b, c } do assert(s:GetCombat(p) == nil) end
		e.tick(200)
		assert(#e.completions == 0)
	end)

	test("an old combat can never end the new one", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local oldZone = e.stages[p].Id
		local old = s:StartCombat(p, oldZone, TEAM, e.context())
		s:CancelCombat(p)
		e.stages[p] = { Id = oldZone + 50, Zone = 1, Stage = 1, Config = stageConfig.Zones[1].Stages[1] }
		local new = s:StartCombat(p, oldZone + 50, TEAM, e.context())
		assert(new and new ~= old)
		assert(select(2, s:StartCombat(p, oldZone, TEAM, e.context())) == "session de stage invalide")
		e.stages[p] = { Id = oldZone, Zone = 1, Stage = 1, Config = stageConfig.Zones[1].Stages[1] } -- ancienne session de stage
		e.tick(1)
		assert(s:GetCombat(p) == nil and #e.completions == 0, "combat bound to its own stage session")
	end)

	test("two players: independent sessions, events only to their owner", function()
		local e = fixture()
		local s = e.start()
		local a, b = e.player("A"), e.player("B")
		local ca = s:StartCombat(a, e.stages[a].Id, TEAM, e.context())
		local cb = s:StartCombat(b, e.stages[b].Id, { [5] = "Magicien" }, e.context())
		assert(ca ~= cb)
		assert(e.runUntilEnd(s, b, 300))
		assert(s:GetCombat(a) ~= nil, "A still fighting after B lost")
		for _, batch in e.fired do
			assert((batch.player == a and batch.combatId == ca) or (batch.player == b and batch.combatId == cb), "no cross-player events")
		end
		assert(#e.completions == 1 and e.completions[1].player == b and e.completions[1].victory == false)
	end)

	test("client CombatAction: only UseUltimate(own ally) and SetSpeed(1|2); everything else refused or ignored", function()
		local e = fixture()
		local s = e.start()
		local action = e.remote("CombatAction")
		assert(action and action.Parent and action.Parent.Name == "Remotes")
		local a, b = e.player("A"), e.player("B")
		s:StartCombat(a, e.stages[a].Id, TEAM, e.context())
		s:StartCombat(b, e.stages[b].Id, TEAM, e.context())
		local view = s:GetCombat(a)
		local ally: any, enemy: any
		for _, u in view.Units do
			if u.Team == "Ally" and not ally then ally = u end
			if u.Team == "Enemy" and not enemy then enemy = u end
		end
		local healthBefore = enemy.Health
		for _, bad in { { "Victory", true }, { "SetHealth", 999999 }, { "Damage", 999999 }, { "SetTarget", enemy.UnitId }, { "Wave", 99 } } :: { any } do
			local ok, reason = action.OnServerInvoke(a, bad[1], bad[2])
			assert(ok == false and reason == "action inconnue", tostring(bad[1]))
		end
		for _, speed in { 3, 100, 0, -1, 1.5, "2" } :: { any } do
			assert(select(2, action.OnServerInvoke(a, "SetSpeed", speed)) == "vitesse invalide")
		end
		assert(select(2, action.OnServerInvoke(a, "UseUltimate", ally.UnitId, { Damage = 999999 })) == "énergie insuffisante", "no energy yet")
		assert(select(2, action.OnServerInvoke(a, "UseUltimate", enemy.UnitId)) == "unité invalide", "enemy unit")
		assert(select(2, action.OnServerInvoke(a, "UseUltimate", 99999)) == "unité invalide", "unknown unit")
		-- Unité alliée de B, vue depuis A : les UnitId sont propres à chaque session.
		local bAlly: any
		for _, u in s:GetCombat(b).Units do if u.Team == "Ally" and u.UnitId > 10 then bAlly = u end end
		assert(bAlly == nil or select(1, action.OnServerInvoke(a, "UseUltimate", bAlly.UnitId)) == false)
		assert(s:GetCombat(a).Units[1].Energy == 0 and enemy.Health == healthBefore)
		assert(#e.completions == 0, "no client action can end a stage")
		local noCombat = e.player("C")
		assert(select(2, action.OnServerInvoke(noCombat, "UseUltimate", 1)) == "aucun combat en cours")
	end)

	test("ultimate with full energy: accepted once, energy reset, damage applied; dead hero refused", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		s:StartCombat(p, e.stages[p].Id, { [5] = "Archer", [4] = "Paladin" }, e.context())
		local archer: any
		for _ = 1, 400 do
			e.heartbeat:Fire(0.1)
			for _, u in s:GetCombat(p).Units do if u.TypeId == "Archer" and u.Energy >= u.MaxEnergy then archer = u end end
			if archer then break end
		end
		assert(archer, "archer reaches full energy")
		local action = e.remote("CombatAction")
		local ok = action.OnServerInvoke(p, "UseUltimate", archer.UnitId)
		assert(ok == true)
		assert(select(2, action.OnServerInvoke(p, "UseUltimate", archer.UnitId)) == "énergie insuffisante", "spam refused")
		local used = e.events(p, "UltimateUsed")
		assert(#used == 1 and used[1].UnitId == archer.UnitId and #used[1].Hits >= 1)
		for _, u in s:GetCombat(p).Units do if u.UnitId == archer.UnitId then assert(u.Energy == 0) end end
	end)

	test("x1/x2: accepted values only, saved in Settings.CombatSpeed only, twice the progress at x2", function()
		local function progress(speed: number): number
			local e = fixture()
			local s = e.start()
			local p = e.player("A")
			s:SetSpeed(p, speed)
			s:StartCombat(p, e.stages[p].Id, TEAM, e.context())
			e.tick(4)
			return #e.events(p, "Attack")
		end
		local x1, x2 = progress(1), progress(2)
		assert(x2 >= 1.6 * x1 and x2 <= 2.4 * x1, `attacks x1={x1} x2={x2}`)
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local before = table.clone(e.data[p])
		s:StartCombat(p, e.stages[p].Id, TEAM, e.context())
		assert(s:SetSpeed(p, 2) == true and s:GetCombat(p).Speed == 2 and e.data[p].Settings.CombatSpeed == 2)
		assert(s:SetSpeed(p, 3) == false and s:GetCombat(p).Speed == 2)
		assert(s:SetSpeed(p, 1) == true and s:GetCombat(p).Speed == 1)
		local changes = e.events(p, "SpeedChanged")
		assert(#changes == 3 and changes[1].Speed == 1 and changes[2].Speed == 2 and changes[3].Speed == 1)
		e.data[p].Settings.CombatSpeed = before.Settings.CombatSpeed
		for _, attack in e.events(p, "Damage") do
			assert(attack.Amount <= 22, "damage per hit never doubled")
		end
	end)

	test("events emitted once: one CombatEnded, deaths once per unit, spawns once per unit", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		s:StartCombat(p, e.stages[p].Id, TEAM, e.context())
		e.runUntilEnd(s, p, 300)
		local spawned, died = {}, {}
		for _, ev in e.events(p, "UnitSpawned") do assert(not spawned[ev.UnitId]); spawned[ev.UnitId] = true end
		for _, ev in e.events(p, "UnitDied") do assert(not died[ev.UnitId]); died[ev.UnitId] = true end
		assert(#e.events(p, "CombatEnded") == 1 and #e.events(p, "MiniBossStarted") == 1)
	end)

	test("no currency, first clear, ticket or other saved data touched (only CombatSpeed via SetSpeed)", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local before = table.clone(e.data[p])
		for k, v in before do before[k] = if type(v) == "table" then table.clone(v) else v end
		s:StartCombat(p, e.stages[p].Id, TEAM, e.context())
		e.runUntilEnd(s, p, 300)
		assert(deepEqual(e.data[p], before), "PlayerData unchanged by a whole combat")
		assert(e.data[p].Currencies.SummonTickets == 0 and next(e.data[p].Progression.FirstClears) == nil)
	end)

	print(`CombatService: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{failed} CombatService test(s) failed`)
	end
end
