--!strict
-- Hors du dossier Services : jamais exécuté par le bootstrap.
-- Intégration du vrai chemin de fin de combat, avec les vrais modules et les vraies configs :
--   CombatEngine → CombatService → ZoneService:CompleteStage → QuestService → RewardService
--   → CombatEnded envoyé au client (FirstClear, Rewards).
-- Seuls DataService, PlotService et les API Roblox sont des doubles.

return function(factories: any, configs: any, CombatEngine: any, RewardRules: any)
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

	local function world(): any
		local env: any = { data = {}, plots = {}, fired = {}, instances = {}, warnings = {} }
		local function signal(): any
			local sig: any = { listeners = {} }
			function sig:Connect(fn: any) table.insert(self.listeners, fn) end
			function sig:Fire(...: any) for _, fn in self.listeners do fn(...) end end
			return sig
		end
		env.players = { PlayerRemoving = signal() }
		env.heartbeat = signal()
		local replicated: any = { Shared = {
			Utils = { Log = { debug = function() end, info = function() end,
				warn = function(_s: string, m: string) table.insert(env.warnings, m) end } },
			Types = { PlayerDataTypes = {} },
		} }
		function replicated:FindFirstChild(name: string): any
			for _, i in env.instances do if i.Name == name and i.Parent == replicated then return i end end
			return nil
		end
		env.game = { GetService = function(_self: any, name: string): any
			return ({ Players = env.players, ReplicatedStorage = replicated, RunService = { Heartbeat = env.heartbeat } })[name]
		end }
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
		env.Random = { new = function(): any return seeded(11) end }
		env.Vector3 = { new = vector, zero = vector(0, 0, 0) }
		env.CFrame = { lookAt = function(pos: any, look: any): any
			local d = look - pos
			local m = d.Magnitude
			return { Position = pos, LookVector = if m > 0 then d / m else vector(0, 0, -1) }
		end }
		env.task = { delay = function() end, spawn = function(fn: any, ...: any) fn(...) end }

		local dataService: any = {}
		function dataService:GetData(player: any): any return env.data[player] end
		function dataService:OnPlayerReady(_callback: any) end
		local plotService: any = {}
		function plotService:GetPlot(player: any): any return env.plots[player] end
		local services: any = { DataService = dataService, PlotService = plotService }
		local tree = { Config = configs, Combat = { CombatEngine = CombatEngine }, Rewards = { RewardRules = RewardRules } }
		local function scriptFor(): any return { Parent = setmetatable({ Parent = tree }, { __index = services }) } end
		services.RewardService = factories.reward(env, scriptFor())
		services.QuestService = factories.quest(env, scriptFor())
		services.ZoneService = factories.zone(env, scriptFor())
		services.CombatService = factories.combat(env, scriptFor())
		-- Même ordre que le bootstrap : tous les Init, puis tous les Start.
		local loaded: { any } = { services.RewardService, services.QuestService, services.ZoneService, services.CombatService }
		for _, phase in { "Init", "Start" } do
			for _, s in loaded do
				local run = s[phase]
				if run ~= nil then (run :: any)(s) end
			end
		end
		env.services = services

		function env.player(name: string): any
			local p: any = { Name = name, Parent = env.players, attributes = { DataLoaded = true } }
			function p:GetAttribute(key: string): any return self.attributes[key] end
			env.data[p] = {
				DataVersion = 1,
				Currencies = { Gold = 0, Gems = 0, SummonTickets = 0 },
				Progression = { CurrentZone = 1, HighestStage = 0, FirstClears = {} },
				Heroes = {}, Team = {}, Hotbar = {}, Kingdom = { Level = 1, VisualState = 1 },
				Quests = {}, Settings = { CombatSpeed = 1 },
			}
			env.plots[p] = { Name = "Plot_" .. name }
			services.QuestService:GetActiveQuest(p) -- quête active comme après le chargement
			return p
		end
		function env.context(): any
			local heroes, enemies = {}, {}
			for n = 1, 9 do
				heroes[n] = vector(((n - 1) % 3) * 9, 0, ((n - 1) // 3) * 9)
				enemies[n] = vector(((n - 1) % 3) * 9, 0, -21 - ((n - 1) // 3) * 4.7)
			end
			return { HeroPositions = heroes, EnemyPositions = enemies, SpawnUnit = function(_unit: any, feet: any): any
				local model: any = { attributes = {}, pivot = { Position = feet, LookVector = vector(0, 0, -1) } }
				function model:SetAttribute(k: string, v: any) self.attributes[k] = v end
				function model:GetPivot(): any return self.pivot end
				function model.PivotTo(self: any, cf: any) self.pivot = cf end
				function model:Destroy() end
				return model
			end }
		end
		-- Un combat complet : stage 1-1 lancé, formation, simulation jusqu'à la fin.
		function env.fight(p: any, formation: any): any
			local zone = services.ZoneService:StartStage(p, 1, 1)
			assert(zone, "stage 1-1 started")
			assert(services.CombatService:StartCombat(p, zone.Id, formation, env.context()))
			for _ = 1, 300 * 4 do
				env.heartbeat:Fire(0.25)
				if not services.CombatService:GetCombat(p) then break end
			end
			local ended = {}
			for _, batch in env.fired do
				if batch.player == p then
					for _, e in batch.events do if e.Type == "CombatEnded" then table.insert(ended, e) end end
				end
			end
			return ended
		end
		return env
	end

	local STRONG = { [1] = "Epeiste", [2] = "Paladin", [7] = "Archer", [9] = "Magicien" }
	local WEAK = { [5] = "Magicien" }
	local FIRST = configs.RewardConfig.Stages["1-1"].FirstClearReward

	test("Victory: CompleteStage -> quest progresses -> rewards granted -> one enriched CombatEnded", function()
		local w = world()
		local p = w.player("A")
		local ended = w.fight(p, STRONG)
		assert(#ended == 1, "a single CombatEnded reaches the client, got " .. #ended)
		local e = ended[1]
		assert(e.Result == "Victory" and e.FirstClear == true)
		assert(#e.Rewards == #FIRST)
		local tickets = 0
		for _, r in e.Rewards do if r.Kind == "SummonTicket" then tickets += r.Amount end end
		assert(tickets == 1)
		local d = w.data[p]
		assert(d.Progression.FirstClears["1-1"] == true and d.Currencies.SummonTickets == 1, "saved before display")
		local quest = w.services.QuestService:GetActiveQuest(p)
		assert(quest and quest.Completed == true, "QuestService progressed on the same StageCompleted")
	end)

	test("Defeat: no reward, FirstClear false, no quest progress", function()
		local w = world()
		local p = w.player("A")
		local ended = w.fight(p, WEAK)
		assert(#ended == 1 and ended[1].Result == "Defeat" and ended[1].FirstClear == false)
		assert(typeof(ended[1].Rewards) == "table" and #ended[1].Rewards == 0)
		local d = w.data[p]
		assert(d.Currencies.Gold == 0 and d.Currencies.SummonTickets == 0 and next(d.Progression.FirstClears) == nil)
		assert(w.services.QuestService:GetActiveQuest(p).Completed == false)
	end)

	test("Victory replay: RepeatReward, no second initial ticket", function()
		local w = world()
		local p = w.player("A")
		w.fight(p, STRONG)
		local before = table.clone(w.data[p].Currencies)
		local ended = w.fight(p, STRONG)
		local last = ended[#ended]
		assert(last.Result == "Victory" and last.FirstClear == false)
		for _, r in last.Rewards do assert(r.Kind ~= "SummonTicket", "no ticket on replay") end
		assert(w.data[p].Currencies.SummonTickets == 1 and w.data[p].Currencies.Gold > before.Gold)
	end)

	test("same victory completed twice (late duplicate call): one attribution only", function()
		local w = world()
		local p = w.player("A")
		local zone = w.services.ZoneService:StartStage(p, 1, 1)
		local ok1, r1 = w.services.ZoneService:CompleteStage(p, zone.Id, true)
		local ok2, r2 = w.services.ZoneService:CompleteStage(p, zone.Id, true)
		assert(ok1 and r1 and r1.FirstClear == true)
		assert(ok2 == false and r2 == nil, "the stage session ends once")
		local r3 = w.services.RewardService:HandleStageCompleted(p, 1, 1, zone.Id)
		assert(r3 == nil, "even a direct duplicate for the same completion is refused")
		assert(w.data[p].Currencies.SummonTickets == 1)
	end)

	test("two players fighting: independent rewards and events", function()
		local w = world()
		local a, b = w.player("A"), w.player("B")
		w.fight(a, STRONG)
		local eb = w.fight(b, WEAK)
		assert(eb[#eb].Result == "Defeat")
		assert(w.data[a].Currencies.SummonTickets == 1 and w.data[b].Currencies.SummonTickets == 0)
		for _, batch in w.fired do
			for _, e in batch.events do
				if e.Type == "CombatEnded" and batch.player == b then assert(e.FirstClear == false) end
			end
		end
	end)

	print(`RewardFlow: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{failed} RewardFlow test(s) failed`)
	end
end
