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

	-- stageConfig : StageConfig de test (par défaut la vraie). Les défaites utilisent HARD.
	local function world(stageConfig: any?): any
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
			Quests = { QuestGuide = configs.QuestGuide }, -- cibles de guidage connues (QuestService)
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
				function i:FireClient(player: any, combatId: any, events: any)
					-- seuls les lots du combat (CombatEvent) ; QuestChanged envoie une vue de quête, pas un lot
					if self.Name ~= "CombatEvent" then return end
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
		local config = configs
		if stageConfig then
			config = table.clone(configs)
			config.StageConfig = stageConfig
		end
		local tree = { Config = config, Combat = { CombatEngine = CombatEngine }, Rewards = { RewardRules = RewardRules } }
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
		function env.fight(p: any, formation: any, stage: number?): any
			local zone = services.ZoneService:StartStage(p, 1, stage or 1)
			assert(zone, `stage 1-{stage or 1} started`)
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
	local STARTER = { [5] = "Epeiste" } -- compte neuf : l'Écuyer du Rempart seul (profil Epeiste)
	-- Stage 1-1 « dur » (l'ancien : 2 Slime, 4 Gobelin, mini-boss) : un héros seul y perd toujours.
	local HARD = { Zones = { { Stages = { { Waves = { { Enemies = { { EnemyId = "Slime", Count = 2 }, { EnemyId = "Gobelin", Count = 4 } } } }, MiniBoss = { EnemyId = "Boss" } } } } } }
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

	test("new player loop: the starter alone wins the real Stage 1-1 -> First Clear and the first ticket", function()
		local w = world()
		local p = w.player("A")
		local ended = w.fight(p, STARTER)
		assert(#ended == 1 and ended[1].Result == "Victory" and ended[1].FirstClear == true, tostring(ended[1] and ended[1].Result))
		assert(w.data[p].Currencies.SummonTickets == 1, "first ticket: the summon is reachable")
	end)

	test("Defeat (hard stage): no reward, FirstClear false, no quest progress", function()
		local w = world(HARD)
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

	test("two players fighting (hard stage): independent rewards and events", function()
		local w = world(HARD)
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

	-- Sécurité (#12) : remotes, doublons, départs, données non chargées -----------------------
	-- Chemin réel : remotes créées par les vrais services, CombatService → ZoneService → Quest → Reward.

	local function remote(w: any, name: string): any
		for _, i in w.instances do
			if i.Name == name and i.OnServerInvoke then return i end
		end
		return nil
	end
	local function leave(w: any, p: any)
		p.Parent = nil
		w.players.PlayerRemoving:Fire(p)
	end
	-- Rejoin : un nouvel objet Player, les mêmes données sauvegardées.
	local function rejoin(w: any, old: any): any
		local p: any = { Name = old.Name, Parent = w.players, attributes = { DataLoaded = true } }
		function p:GetAttribute(key: string): any return self.attributes[key] end
		w.data[p] = w.data[old]
		w.data[old] = nil
		w.plots[p] = w.plots[old]
		return p
	end
	local function snapshot(d: any): string
		local clears = {}
		for k, v in d.Progression.FirstClears do table.insert(clears, `{k}={tostring(v)}`) end
		table.sort(clears)
		local q = d.Quests.DefendDomain
		return `{d.Currencies.Gold}/{d.Currencies.Gems}/{d.Currencies.SummonTickets}|{table.concat(clears, ",")}|{q and q.Progress}/{q and tostring(q.Claimed)}`
	end
	local NEVER = { 0, -1, 1.5, 2 ^ 53, math.huge, -math.huge, 0 / 0, "1", {}, { Zone = 1 } } :: { any }

	test("#12 stage spam: 25 RequestStartStage -> one session, the same one, no reward; bad values refused", function()
		local w = world()
		local p = w.player("A")
		local start = remote(w, "RequestStartStage")
		local accepted = 0
		for _ = 1, 25 do
			if start.OnServerInvoke(p, 1, 1) == true then accepted += 1 end
		end
		local session = w.services.ZoneService:GetSession(p)
		assert(accepted == 1 and session, "one session, got " .. accepted)
		local ok, why = start.OnServerInvoke(p, 1, 1)
		assert(ok == false and why == "session déjà en cours" and w.services.ZoneService:GetSession(p).Id == session.Id, "never replaced")
		for _, bad in NEVER do
			assert(start.OnServerInvoke(p, bad, 1) == false and start.OnServerInvoke(p, 1, bad) == false, tostring(bad))
		end
		assert(start.OnServerInvoke(p) == false, "nil refused")
		assert(snapshot(w.data[p]) == "0/0/0||0/false", "no reward from starting: " .. snapshot(w.data[p]))
		local q = w.player("Q")
		assert(start.OnServerInvoke(q, 1, 2) == false and w.services.ZoneService:GetSession(q) == nil, "unknown / locked stage refused")
		assert(w.services.CombatService:GetCombat(p) == nil, "starting a stage never starts a combat")
	end)

	test("#12 one combat per stage session: a second StartCombat (spam) is refused; foreign session useless", function()
		local w = world()
		local p = w.player("A")
		local zone = w.services.ZoneService:StartStage(p, 1, 1)
		assert(w.services.CombatService:StartCombat(p, zone.Id, STARTER, w.context()))
		for _ = 1, 20 do
			local id, why = w.services.CombatService:StartCombat(p, zone.Id, STARTER, w.context())
			assert(id == nil and why == "combat déjà en cours")
		end
		local other = w.player("B")
		local idB, whyB = w.services.CombatService:StartCombat(other, zone.Id, STARTER, w.context())
		assert(idB == nil and whyB == "session de stage invalide", "another player's stage session is useless")
	end)

	test("#12 duplicate victory, 3 layers: combat ends once, CompleteStage once, completionId rewarded once", function()
		local w = world()
		local p = w.player("A")
		local ended = w.fight(p, STARTER)
		for _ = 1, 20 do w.heartbeat:Fire(0.25) end -- ticks après la fin : la session est verrouillée
		assert(#ended == 1 and ended[1].Result == "Victory")
		local count = 0
		for _, batch in w.fired do
			for _, e in batch.events do if e.Type == "CombatEnded" and batch.player == p then count += 1 end end
		end
		assert(count == 1, "one CombatEnded")
		local after = snapshot(w.data[p])
		-- ZoneService : une même session ne se termine qu'une fois
		local zone = w.services.ZoneService:StartStage(p, 1, 1)
		assert(w.services.ZoneService:CompleteStage(p, zone.Id, true) == true)
		assert(w.services.ZoneService:CompleteStage(p, zone.Id, true) == false, "second CompleteStage refused")
		local replay = snapshot(w.data[p])
		-- RewardService : même completionId rejoué directement
		assert(w.services.RewardService:HandleStageCompleted(p, 1, 1, zone.Id) == nil)
		assert(snapshot(w.data[p]) == replay, "duplicate completion gives nothing")
		assert(after ~= replay, "the real replay (new session) gave the RepeatReward")
		assert(w.data[p].Currencies.SummonTickets == 1, "never a second first-clear ticket")
	end)

	test("#12 combat disconnect: combat and stage session gone, models destroyed, no reward; rejoin can play", function()
		local w = world()
		local p = w.player("A")
		local destroyed, spawned = 0, 0
		local ctx = w.context()
		local spawn = ctx.SpawnUnit
		ctx.SpawnUnit = function(...: any): any
			local m = spawn(...)
			spawned += 1
			function m:Destroy() destroyed += 1 end
			return m
		end
		local zone = w.services.ZoneService:StartStage(p, 1, 1)
		assert(w.services.CombatService:StartCombat(p, zone.Id, STARTER, ctx))
		w.heartbeat:Fire(0.25)
		leave(w, p)
		assert(destroyed == spawned, "models destroyed at once on PlayerRemoving (stop), before any tick")
		for _ = 1, 400 do w.heartbeat:Fire(0.25) end
		assert(w.services.CombatService:GetCombat(p) == nil and w.services.ZoneService:GetSession(p) == nil, "no ghost session")
		assert(spawned > 0 and destroyed == spawned, `runtime models cleaned ({destroyed}/{spawned})`)
		assert(snapshot(w.data[p]) == "0/0/0||0/false", "no reward, no first clear, no quest progress: " .. snapshot(w.data[p]))
		local back = rejoin(w, p)
		local ended = w.fight(back, STARTER)
		assert(ended[#ended].Result == "Victory" and w.data[back].Currencies.SummonTickets == 1, "rejoin plays normally")
	end)

	test("#12 victory then disconnect before the reward screen: everything already saved, rejoin keeps it once", function()
		local w = world()
		local p = w.player("A")
		w.fight(p, STARTER) -- serveur : victoire → Quest → Reward → données mutées → CombatEnded
		local saved = snapshot(w.data[p])
		leave(w, p) -- le client n'a jamais affiché l'écran
		local back = rejoin(w, p)
		local d = w.data[back]
		assert(snapshot(d) == saved and d.Progression.FirstClears["1-1"] == true and d.Currencies.Gold == 100
			and d.Currencies.Gems == 10 and d.Currencies.SummonTickets == 1 and d.Quests.DefendDomain.Progress == 1, saved)
		w.fight(back, STARTER)
		assert(w.data[back].Currencies.SummonTickets == 1, "replay after rejoin: RepeatReward only, no second ticket")
	end)

	test("#12 no client reward remote: Continuer / reopened screen / forged client cannot grant anything", function()
		local w = world()
		local p = w.player("A")
		w.fight(p, STARTER)
		local before = snapshot(w.data[p])
		for _, i in w.instances do
			local name = string.lower(i.Name)
			local rewardLike = name:find("reward") or name:find("claim") or name:find("collect") or name:find("give")
			-- ClaimQuest marque la quête réclamée et ne donne aucune récompense (vérifié ci-dessous)
			assert(not (rewardLike and i.OnServerInvoke) or i.Name == "ClaimQuest", "no client-invocable reward remote: " .. i.Name)
		end
		-- client falsifié : n'importe quoi sur les seules remotes du flux combat
		for _, args in { { "Victory" }, { 1, true }, { { Rewards = { { Kind = "Gold", Amount = 1e9 } } } } } :: { any } do
			for _, name in { "RequestStartStage", "SetCombatSpeed" } do
				pcall(remote(w, name).OnServerInvoke, p, table.unpack(args))
			end
		end
		local claim = remote(w, "ClaimQuest")
		for _ = 1, 20 do pcall(claim.OnServerInvoke, p, "DefendDomain") end
		local d = w.data[p]
		assert(d.Currencies.Gold == 100 and d.Currencies.Gems == 10 and d.Currencies.SummonTickets == 1, "claiming the quest (spam) grants nothing")
		assert(d.Quests.DefendDomain.Claimed == true)
		d.Quests.DefendDomain.Claimed = false -- remis pour comparer le reste
		assert(snapshot(d) == before, "rewards untouched")
	end)

	test("#12 CombatSpeed: only 1 and 2; anything else refused, Settings and session speed unchanged", function()
		local w = world()
		local p = w.player("A")
		local speed = remote(w, "SetCombatSpeed")
		local zone = w.services.ZoneService:StartStage(p, 1, 1)
		assert(w.services.CombatService:StartCombat(p, zone.Id, STARTER, w.context()))
		assert(speed.OnServerInvoke(p, 2) == true and w.data[p].Settings.CombatSpeed == 2 and w.services.CombatService:GetCombat(p).Speed == 2)
		local fake: any = setmetatable({}, { __tostring = function() return "Instance" end })
		local values: { any } = { 0, -1, 1.5, 3, math.huge, -math.huge, 0 / 0, "2", {}, fake }
		local ok0, why0 = speed.OnServerInvoke(p, nil)
		assert(ok0 == false and why0 == "vitesse invalide", "nil")
		for _, bad in values do
			local ok, why = speed.OnServerInvoke(p, bad)
			assert(ok == false and why == "vitesse invalide", tostring(bad))
			assert(w.data[p].Settings.CombatSpeed == 2 and w.services.CombatService:GetCombat(p).Speed == 2, "unchanged after " .. tostring(bad))
		end
		assert(speed.OnServerInvoke(p, 1) == true and w.data[p].Settings.CombatSpeed == 1)
	end)

	test("#12 DataLoaded lost / profile gone: no stage, no combat, no reward, no late completion", function()
		local w = world()
		local p = w.player("A")
		local zone = w.services.ZoneService:StartStage(p, 1, 1)
		assert(w.services.CombatService:StartCombat(p, zone.Id, STARTER, w.context()))
		p.attributes.DataLoaded = nil -- profil perdu pendant le combat
		w.heartbeat:Fire(0.05)
		assert(w.services.CombatService:GetCombat(p) == nil, "dropped on the very next tick (contextAlive)")
		for _ = 1, 400 do w.heartbeat:Fire(0.25) end
		assert(w.services.CombatService:GetCombat(p) == nil, "combat dropped")
		assert(w.services.ZoneService:CompleteStage(p, zone.Id, true) == false, "no late completion")
		assert(w.services.RewardService:HandleStageCompleted(p, 1, 1, "late") == nil, "no late reward")
		assert(w.services.ZoneService:StartStage(p, 1, 1) == nil and remote(w, "RequestStartStage").OnServerInvoke(p, 1, 1) == false)
		assert(snapshot(w.data[p]) == "0/0/0||0/false")
		local gone = w.player("G")
		w.data[gone] = nil -- données absentes
		assert(w.services.ZoneService:StartStage(gone, 1, 1) == nil and w.services.RewardService:HandleStageCompleted(gone, 1, 1, 1) == nil)
	end)

	-- Zone 1 complète (#13) : chemin réel 1-1 → 1-5 ---------------------------------------------

	local PAIR = { [2] = "Epeiste", [8] = "Tireur" } -- équipe garantie : Écuyer (Epeiste) + Tireuse (Tireur)

	-- Événements envoyés à p à partir de l'indice `from` de w.fired.
	local function eventsSince(w: any, p: any, from: number, kind: string): { any }
		local out = {}
		for i = from + 1, #w.fired do
			local batch = w.fired[i]
			if batch.player == p then
				for _, e in batch.events do if e.Type == kind then table.insert(out, e) end end
			end
		end
		return out
	end

	test("#13 Zone 1 chain on a new account: 1-1 alone, then 1-2..1-5 with the guaranteed pair; boss only on 1-5", function()
		local w = world()
		local p = w.player("A")
		local zone = w.services.ZoneService
		local function statuses(): string
			local s = {}
			for _, entry in zone:ListStages(p) do table.insert(s, `{entry.Stage}:{entry.Status}`) end
			return table.concat(s, " ")
		end
		assert(statuses() == "1:Unlocked 2:Locked 3:Locked 4:Locked 5:Locked", statuses())
		assert(zone:StartStage(p, 1, 5) == nil and zone:StartStage(p, 1, 2) == nil, "no skipping from a new account")
		for stage = 1, 5 do
			local before = #w.fired
			local ended = w.fight(p, if stage == 1 then STARTER else PAIR, stage)
			local last = ended[#ended]
			assert(last and last.Result == "Victory" and last.FirstClear == true, `1-{stage}: {last and last.Result}`)
			local bosses = eventsSince(w, p, before, "MiniBossStarted")
			if stage == 5 then
				assert(#bosses == 1 and bosses[1].EnemyId == "Boss", "the Roi Orc boss is fought on 1-5")
			else
				assert(#bosses == 0, `no boss on 1-{stage}`)
			end
			if stage < 5 then
				assert(zone:ListStages(p)[stage + 1].Status == "Unlocked", `1-{stage + 1} unlocked by the First Clear of 1-{stage}`)
			end
		end
		local d = w.data[p]
		for stage = 1, 5 do assert(d.Progression.FirstClears[`1-{stage}`] == true, `FirstClear 1-{stage}`) end
		assert(d.Currencies.Gold == 100 and d.Currencies.Gems == 10 and d.Currencies.SummonTickets == 1,
			"only 1-1 gives currencies (1-2..1-5 rewards are empty for now)")
		assert(#zone:ListStages(p) == 5 and zone:StartStage(p, 1, 6) == nil, "no stage 1-6")
		-- replays : 1-1 → +20 or, aucun ticket ; 1-5 → pas de second First Clear
		local r1 = w.fight(p, PAIR, 1)
		assert(r1[#r1].FirstClear == false and d.Currencies.Gold == 120 and d.Currencies.SummonTickets == 1)
		local r5 = w.fight(p, PAIR, 5)
		assert(r5[#r5].Result == "Victory" and r5[#r5].FirstClear == false and #r5[#r5].Rewards == 0)
		assert(d.Currencies.Gold == 120 and d.Currencies.SummonTickets == 1)
	end)

	test("#13 RewardConfig: a valid entry for every stage of StageConfig (First Clear = unlock)", function()
		local stages = configs.StageConfig.Zones[1].Stages
		assert(#stages == 5)
		for stage = 1, #stages do
			local entry = configs.RewardConfig.Stages[`1-{stage}`]
			assert(entry, `RewardConfig 1-{stage}`)
			assert(#RewardRules.stageProblems(entry) == 0, `valid 1-{stage}`)
		end
		local first = configs.RewardConfig.Stages["1-1"]
		assert(#first.FirstClearReward == 3 and first.RepeatReward[1].Kind == "Gold" and first.RepeatReward[1].Amount == 20, "1-1 contract unchanged")
		local w = world()
		assert(#w.warnings == 0, "no config warning: " .. table.concat(w.warnings, "; "))
	end)

	print(`RewardFlow: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{failed} RewardFlow test(s) failed`)
	end
end
