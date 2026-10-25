--!strict
-- Hors du dossier Services : jamais exécuté par le bootstrap.
-- Exécute le vrai ZoneService avec la vraie StageConfig (ou une config de test)
-- et des doubles de DataService, PlotService, QuestService et RewardService.

return function(createService: any, productionConfig: any, eliteConfig: any, Difficulty: any)
	local function fixture(config: any?, elite: any?): any
		local env: any = { data = {}, plots = {}, questEvents = {}, rewardCalls = {}, order = {}, warnings = {}, instances = {} }
		local removing: any = { listeners = {} }
		function removing:Connect(fn: any) table.insert(self.listeners, fn) end
		env.players = { PlayerRemoving = removing }
		local replicated: any = { Shared = { Utils = { Log = {
			debug = function() end,
			info = function() end,
			warn = function(_scope: string, message: string) table.insert(env.warnings, message) end,
		} }, Types = { PlayerDataTypes = {} } } }
		function replicated:FindFirstChild(name: string): any
			for _, instance in env.instances do
				if instance.Name == name and instance.Parent == replicated then return instance end
			end
			return nil
		end
		env.replicated = replicated
		env.game = { GetService = function(_self: any, name: string): any
			return ({ Players = env.players, ReplicatedStorage = replicated })[name]
		end }
		local dataService: any = {}
		function dataService:GetData(player: any): any return env.data[player] end
		local plotService: any = {}
		function plotService:GetPlot(player: any): any return env.plots[player] end
		local questService: any = {}
		function questService:HandleGameplayEvent(player: any, eventName: string, payload: any): boolean
			table.insert(env.questEvents, { player = player, event = eventName, payload = payload })
			table.insert(env.order, "Quest")
			return true
		end
		local rewardService: any = {}
		function rewardService:HandleStageCompleted(player: any, zone: number, stage: number, completionId: number, mode: string?): any
			table.insert(env.rewardCalls, { player = player, zone = zone, stage = stage, completionId = completionId, mode = mode })
			table.insert(env.order, "Reward")
			return env.rewardResult
		end
		env.rewardResult = { FirstClear = false, Rewards = {} }
		env.script = { Parent = { DataService = dataService, PlotService = plotService, QuestService = questService,
			RewardService = rewardService,
			Parent = { Config = { StageConfig = config or productionConfig, EliteConfig = elite or eliteConfig },
				Combat = { Difficulty = Difficulty } } } }
		env.require = function(module: any): any return module end
		env.Instance = { new = function(class: string): any
			local instance = { ClassName = class, Name = class }
			table.insert(env.instances, instance)
			return instance
		end }

		function env.freshData(): any
			return {
				DataVersion = 1,
				Currencies = { Gold = 0, Gems = 0, SummonTickets = 0 },
				Progression = { CurrentZone = 1, HighestStage = 0, FirstClears = {}, EliteFirstClears = {} },
				Heroes = {}, Team = {}, Kingdom = { Level = 1, VisualState = 1 },
				Quests = { DefendDomain = { Progress = 0, Claimed = false } }, Settings = { CombatSpeed = 1 },
			}
		end
		-- Joueur présent, données chargées et plot attribué (état normal après PlotService).
		function env.player(name: string, withPlot: boolean?): any
			local player: any = { Name = name, Parent = env.players, attributes = { DataLoaded = true } }
			function player:GetAttribute(key: string): any return self.attributes[key] end
			env.data[player] = env.freshData()
			if withPlot ~= false then env.plots[player] = { Name = "Plot_" .. name } end
			return player
		end
		function env.leave(player: any)
			for _, fn in removing.listeners do fn(player) end
			player.Parent = nil
			env.data[player], env.plots[player] = nil, nil
		end
		function env.remote(): any
			for _, instance in env.instances do
				if instance.Name == "RequestStartStage" then return instance end
			end
			return nil
		end
		function env.start(): any
			env.service = createService(env)
			env.service:Init()
			env.service:Start()
			return env.service
		end
		return env
	end

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

	local function deepEqual(a: any, b: any): boolean
		if type(a) ~= "table" or type(b) ~= "table" then return a == b end
		for k, v in a do if not deepEqual(v, b[k]) then return false end end
		for k in b do if a[k] == nil then return false end end
		return true
	end

	local function twoStageConfig(): any
		local stage = function(enemyId: string): any
			return { Waves = { { Enemies = { { EnemyId = enemyId, Count = 1 } } } } }
		end
		return { Zones = {
			{ Stages = { stage("Slime"), stage("Gobelin") } },
			{ Stages = { stage("Boss") } },
		} }
	end

	-- Mode Élite (#69) -------------------------------------------------------------------------

	local function clearNormal(e: any, p: any, upTo: number)
		for stage = 1, upTo do e.data[p].Progression.FirstClears[`1-{stage}`] = true end
	end

	test("#69 Elite locked before 1-5 Normal: list all Locked, start refused, IsEliteUnlocked false", function()
		local e = fixture()
		local s = e.start()
		assert(#e.warnings == 0, "elite config valid: " .. table.concat(e.warnings, "; "))
		local p = e.player("A")
		clearNormal(e, p, 4)
		assert(s:IsEliteUnlocked(p, 1) == false)
		local list = s:ListStages(p, "Elite")
		assert(#list == 5)
		for _, entry in list do assert(entry.Mode == "Elite" and entry.Status == "Locked" and entry.Cleared == false) end
		local ok, why = s:CanStartStage(p, 1, 1, "Elite")
		assert(ok == false and why == "Élite verrouillé")
		assert(s:StartStage(p, 1, 1, "Elite") == nil)
	end)

	test("#69 1-5 Normal cleared -> 1-1E unlocked, 1-2E locked until 1-1E cleared; chain to 1-5E; no 1-6E", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		clearNormal(e, p, 5)
		assert(s:IsEliteUnlocked(p, 1) == true)
		local list = s:ListStages(p, "Elite")
		assert(list[1].Status == "Unlocked" and list[2].Status == "Locked")
		local ok, why = s:CanStartStage(p, 1, 2, "Elite")
		assert(ok == false and why == "stage verrouillé", "1-2E before 1-1E")
		local clears = e.data[p].Progression.EliteFirstClears
		for stage = 1, 5 do
			assert(s:CanStartStage(p, 1, stage, "Elite") == true, `1-{stage}E playable`)
			if stage < 5 then
				assert(s:CanStartStage(p, 1, stage + 1, "Elite") == false, `1-{stage + 1}E still locked`)
			end
			clears[`1-{stage}`] = true
		end
		local six, whySix = s:CanStartStage(p, 1, 6, "Elite")
		assert(six == false and whySix == "stage inconnu", "no 1-6E")
		assert(s:CanStartStage(p, 2, 1, "Elite") == false, "no Elite outside zone 1")
	end)

	test("#69 Normal and Elite progressions are separate (FirstClears vs EliteFirstClears)", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		clearNormal(e, p, 5)
		e.data[p].Progression.EliteFirstClears["1-1"] = true
		local normal = s:ListStages(p)
		for _, entry in normal do
			assert(entry.Mode == "Normal" and entry.Cleared == (entry.Zone == 1))
		end
		local elite = s:ListStages(p, "Elite")
		assert(elite[1].Cleared == true and elite[2].Cleared == false and elite[2].Status == "Unlocked")
		local fresh = e.player("B")
		e.data[fresh].Progression.EliteFirstClears = nil -- profil v4 avant Reconcile : toléré
		assert(s:ListStages(fresh, "Elite")[1].Status == "Locked" and s:IsEliteUnlocked(fresh, 1) == false)
	end)

	test("#69 Elite session: Mode Elite + difficulty multipliers; Normal session: Mode Normal, no difficulty", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		clearNormal(e, p, 5)
		local session = s:StartStage(p, 1, 1, "Elite")
		assert(session and session.Mode == "Elite" and session.Zone == 1 and session.Stage == 1)
		assert(session.Difficulty.MaxHealth == 1.5 and session.Difficulty.AttackDamage == 1.25)
		assert(session.Config == productionConfig.Zones[1].Stages[1] or session.Config.Waves[1].Enemies[1].EnemyId == "Slime", "same stage content")
		s:CancelStage(p)
		local normal = s:StartStage(p, 1, 3)
		assert(normal and normal.Mode == "Normal" and normal.Difficulty == nil)
		s:CancelStage(p)
		local expected = { { 1.5, 1.25 }, { 1.65, 1.3 }, { 1.8, 1.35 }, { 2.0, 1.4 }, { 2.25, 1.5 } }
		for stage, m in expected do
			e.data[p].Progression.EliteFirstClears[`1-{stage - 1}`] = true
			local st = s:StartStage(p, 1, stage, "Elite")
			assert(st and st.Difficulty.MaxHealth == m[1] and st.Difficulty.AttackDamage == m[2], `1-{stage}E multipliers`)
			s:CancelStage(p)
		end
	end)

	test("#69 Elite completion: EliteStageCompleted quest event (never StageCompleted), reward call in Elite mode", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		clearNormal(e, p, 5)
		local session = s:StartStage(p, 1, 3 - 2, "Elite")
		assert(s:CompleteStage(p, session.Id, true))
		local q = e.questEvents[#e.questEvents]
		assert(q.event == "EliteStageCompleted" and q.payload.Zone == 1 and q.payload.Stage == 1)
		local r = e.rewardCalls[#e.rewardCalls]
		assert(r.mode == "Elite" and r.zone == 1 and r.stage == 1)
		local normal = s:StartStage(p, 1, 1)
		s:CompleteStage(p, normal.Id, true)
		assert(e.questEvents[#e.questEvents].event == "StageCompleted" and e.rewardCalls[#e.rewardCalls].mode == "Normal")
	end)

	test("#69 spoofed mode / stage refused: unknown mode, numbers, tables, 1-6E, locked stage; remote too", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		clearNormal(e, p, 5)
		for _, mode in { "Hard", "elite", 5, {}, true } :: { any } do
			local ok, why = s:CanStartStage(p, 1, 1, mode)
			assert(ok == false and why == "mode inconnu", tostring(mode))
		end
		local remote = e.remote().OnServerInvoke
		assert(remote(p, 1, 1, "Hard") == false and remote(p, 1, 1, { MaxHealth = 0.1 }) == false)
		assert(remote(p, 1, 6, "Elite") == false and remote(p, 1, 2, "Elite") == false, "1-6E and locked 1-2E refused")
		assert(remote(p, 1, 1, "Elite") == true, "valid Elite request")
		assert(s:GetSession(p).Difficulty.MaxHealth == 1.5, "multipliers come from the server config only")
	end)

	test("#69 two players: A has Elite (1-5 cleared), B does not; independent sessions and modes", function()
		local e = fixture()
		local s = e.start()
		local a, b = e.player("A"), e.player("B")
		clearNormal(e, a, 5)
		clearNormal(e, b, 3)
		local sa = s:StartStage(a, 1, 1, "Elite")
		assert(sa and sa.Mode == "Elite")
		assert(s:StartStage(b, 1, 1, "Elite") == nil, "B locked")
		local sb = s:StartStage(b, 1, 1)
		assert(sb and sb.Mode == "Normal" and sb.Difficulty == nil and s:GetSession(a).Mode == "Elite")
		assert(next(e.data[b].Progression.EliteFirstClears) == nil)
	end)

	test("#69 elite config: unknown stat or bad factor refused (warning, stage not playable in Elite)", function()
		local bad = { Zones = { [1] = { UnlockAfter = "1-5", Stages = { [1] = { MoveSpeed = 2 }, [2] = { MaxHealth = -1 }, [3] = { MaxHealth = 1.2 } } } } }
		local e = fixture(nil, bad)
		local s = e.start()
		assert(#e.warnings >= 2)
		local p = e.player("A")
		clearNormal(e, p, 5)
		assert(s:CanStartStage(p, 1, 1, "Elite") == false, "invalid multipliers: stage not offered")
		local list = s:ListStages(p, "Elite")
		assert(#list == 1 and list[1].Stage == 3)
	end)

	test("production config: Zone 1 / Stage 1 exists, entry stage by config (2 Slime, 2 Gobelin, no mini-boss)", function()
		local e = fixture()
		local s = e.start()
		assert(#e.warnings == 0, "production config valid: " .. table.concat(e.warnings, "; "))
		local stage = productionConfig.Zones[1].Stages[1]
		assert(stage.Waves[1].Enemies[1].EnemyId == "Slime" and stage.Waves[1].Enemies[1].Count == 2)
		assert(stage.Waves[1].Enemies[2].EnemyId == "Gobelin" and stage.Waves[1].Enemies[2].Count == 2)
		assert(stage.MiniBoss == nil, "entry stage: winnable by the starter alone")
		local p = e.player("A")
		assert(s:CanStartStage(p, 1, 1) == true, "new player can start 1-1")
	end)

	test("unknown zone or stage refused, invalid ids refused", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		for _, case in { { 1, 6 }, { 7, 1 }, { 2, 6 }, { 0, 1 }, { 1, 0 }, { 1.5, 1 }, { "1", 1 } } :: { any } do
			local session, reason = s:StartStage(p, case[1], case[2])
			assert(session == nil and reason == "stage inconnu", `{case[1]}/{case[2]} -> {reason}`)
		end
		assert(s:GetSession(p) == nil)
	end)

	test("player without data, not ready, gone, or without plot refused", function()
		local e = fixture()
		local s = e.start()
		local noData = e.player("NoData")
		e.data[noData] = nil
		local notReady = e.player("NotReady")
		notReady.attributes.DataLoaded = nil
		local gone = e.player("Gone")
		gone.Parent = nil
		local noPlot = e.player("NoPlot", false)
		for _, p in { noData, notReady, gone } do
			local session, reason = s:StartStage(p, 1, 1)
			assert(session == nil and reason == "données non chargées", p.Name .. " -> " .. tostring(reason))
		end
		local session, reason = s:StartStage(noPlot, 1, 1)
		assert(session == nil and reason == "aucun plot")
	end)

	test("StartStage creates a session from the config, without touching saved data", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local before = e.freshData()
		local session, reason = s:StartStage(p, 1, 1)
		assert(session and reason == nil)
		assert(session.Zone == 1 and session.Stage == 1 and session.Status == "Running" and typeof(session.Id) == "number")
		assert(deepEqual(session.Config, productionConfig.Zones[1].Stages[1]), "config copied from StageConfig")
		local current = s:GetSession(p)
		assert(current and current.Id == session.Id)
		assert(deepEqual(e.data[p], before), "PlayerData untouched at start (no FirstClears, no progress)")
		assert(#e.questEvents == 0, "no quest event at start")
	end)

	test("second StartStage while running refused; two players independent", function()
		local e = fixture()
		local s = e.start()
		local a, b = e.player("A"), e.player("B")
		local sa = s:StartStage(a, 1, 1)
		local again, reason = s:StartStage(a, 1, 1)
		assert(again == nil and reason == "session déjà en cours")
		assert(s:CanStartStage(a, 1, 1) == false)
		local sb = s:StartStage(b, 1, 1)
		assert(sa and sb and sa.Id ~= sb.Id)
		assert(s:CompleteStage(a, sa.Id, true))
		local bSession = s:GetSession(b)
		assert(bSession and bSession.Id == sb.Id, "completing A leaves B running")
		assert(#e.questEvents == 1 and e.questEvents[1].player == a)
	end)

	test("session view and config are read-only", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local session = s:StartStage(p, 1, 1)
		assert(session)
		assert(not pcall(function() (session :: any).Stage = 2 end), "view frozen")
		assert(not pcall(function() session.Config.Waves[1].Enemies[1].Count = 99 end), "config frozen")
		assert(not pcall(function() table.insert(session.Config.Waves, {}) end), "waves frozen")
		assert(productionConfig.Zones[1].Stages[1].Waves[1].Enemies[1].Count == 2, "source config untouched")
		local current = s:GetSession(p)
		assert(current and current.Stage == 1 and current.Config.Waves[1].Enemies[1].Count == 2)
	end)

	test("cancel frees the session without progress", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		s:StartStage(p, 1, 1)
		assert(s:CancelStage(p) == true and s:GetSession(p) == nil)
		assert(s:CancelStage(p) == false, "nothing left to cancel")
		assert(#e.questEvents == 0)
		assert(s:StartStage(p, 1, 1) ~= nil, "can start again")
	end)

	test("defeat frees the session and never reaches QuestService nor RewardService", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local session = s:StartStage(p, 1, 1)
		assert(session)
		local ok, reward = s:CompleteStage(p, session.Id, false)
		assert(ok == true and reward == nil)
		assert(s:GetSession(p) == nil and #e.questEvents == 0 and #e.rewardCalls == 0)
		assert(s:StartStage(p, 1, 1) ~= nil)
	end)

	test("victory frees the session and emits StageCompleted exactly once with the exact payload", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local session = s:StartStage(p, 1, 1)
		assert(session and s:CompleteStage(p, session.Id, true) == true)
		assert(s:GetSession(p) == nil)
		assert(#e.questEvents == 1)
		local event = e.questEvents[1]
		assert(event.player == p and event.event == "StageCompleted")
		assert(deepEqual(event.payload, { Zone = 1, Stage = 1 }), "payload { Zone = 1, Stage = 1 }")
		assert(s:CompleteStage(p, session.Id, true) == false and s:CompleteStage(p, session.Id, false) == false)
		assert(#e.questEvents == 1, "repeated completion does not re-emit")
		assert(#e.rewardCalls == 1, "repeated completion does not reward again")
	end)

	test("victory: QuestService then RewardService, with the session id as completion id; result returned", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		e.rewardResult = { FirstClear = true, Rewards = { { Kind = "SummonTicket", Amount = 1, New = true } } }
		local session = s:StartStage(p, 1, 1)
		assert(session)
		local ok, reward = s:CompleteStage(p, session.Id, true)
		assert(ok == true and reward == e.rewardResult, "RewardService result returned to the caller")
		assert(deepEqual(e.order, { "Quest", "Reward" }), "quest progress, then rewards")
		local call = e.rewardCalls[1]
		assert(call.player == p and call.zone == 1 and call.stage == 1 and call.completionId == session.Id)
		local other = s:StartStage(p, 1, 1)
		assert(other and other.Id ~= session.Id)
		s:CompleteStage(p, other.Id, true)
		assert(e.rewardCalls[2].completionId == other.Id, "each victory is a distinct completion")
	end)


	test("#72 victory returns the RewardService result untouched, Loot included; a defeat returns nothing", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		e.rewardResult = { FirstClear = false, Rewards = {}, Loot = { Items = { { InstanceId = "I_T1", ItemId = "item_015" } }, Resources = {}, Overflow = false } }
		local won = s:StartStage(p, 1, 1)
		assert(won)
		local ok, reward = s:CompleteStage(p, won.Id, true)
		assert(ok == true and reward and reward.Loot == e.rewardResult.Loot, "Loot travels with the result, ZoneService adds nothing")
		local lost = s:StartStage(p, 1, 1)
		assert(lost)
		local okLost, rewardLost = s:CompleteStage(p, lost.Id, false)
		assert(okLost == true and rewardLost == nil, "defeat: no result, hence no loot")
	end)
	test("victory refused by RewardService: session still ends, warning logged", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		e.rewardResult = nil
		local session = s:StartStage(p, 1, 1)
		assert(session)
		local ok, reward = s:CompleteStage(p, session.Id, true)
		assert(ok == true and reward == nil and s:GetSession(p) == nil)
		assert(#e.warnings == 1, "missing reward is reported")
	end)

	test("stale completion of an old session cannot end the new one", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local old = s:StartStage(p, 1, 1)
		assert(old and s:CancelStage(p))
		local new = s:StartStage(p, 1, 1)
		assert(new and new.Id ~= old.Id)
		assert(s:CompleteStage(p, old.Id, true) == false, "old id refused")
		local current = s:GetSession(p)
		assert(current and current.Id == new.Id and #e.questEvents == 0)
	end)

	test("leave removes the session: no late completion, no quest progress", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local session = s:StartStage(p, 1, 1)
		assert(session)
		local plot = e.plots[p]
		e.leave(p)
		-- La session est supprimée dès PlayerRemoving, pas seulement masquée : même si l'objet
		-- joueur redevenait valide avant tout autre appel, elle ne réapparaîtrait pas.
		p.Parent, e.data[p], e.plots[p] = e.players, e.freshData(), plot
		assert(s:GetSession(p) == nil)
		assert(s:CompleteStage(p, session.Id, true) == false and #e.questEvents == 0)
		local q = e.player("B")
		local other = s:StartStage(q, 1, 1)
		e.leave(q)
		assert(s:GetSession(q) == nil and s:CompleteStage(q, other.Id, true) == false and #e.questEvents == 0)
	end)

	test("data loss or plot loss invalidates the session", function()
		local e = fixture()
		local s = e.start()
		local a, b, c, d = e.player("A"), e.player("B"), e.player("C"), e.player("D")
		local sa, sb, sc, sd = s:StartStage(a, 1, 1), s:StartStage(b, 1, 1), s:StartStage(c, 1, 1), s:StartStage(d, 1, 1)
		assert(sa and sb and sc and sd)
		a.attributes.DataLoaded = nil -- perte du profil, avant la livraison de tout signal
		e.plots[b] = nil -- plot perdu
		e.plots[c] = { Name = "AutrePlot" } -- plot réattribué
		e.data[d] = nil -- profil déjà retiré par DataService, attribut pas encore mis à jour
		for _, pair in { { a, sa }, { b, sb }, { c, sc }, { d, sd } } :: { any } do
			assert(s:GetSession(pair[1]) == nil, pair[1].Name .. " session invalidated")
			assert(s:CompleteStage(pair[1], pair[2].Id, true) == false)
		end
		assert(#e.questEvents == 0)
	end)

	test("Stage 2 and Zone 2 added by config only, unlocked by the previous FirstClear", function()
		local e = fixture(twoStageConfig(), { Zones = {} })
		local s = e.start()
		assert(#e.warnings == 0)
		local p = e.player("A")
		local session, reason = s:StartStage(p, 1, 2)
		assert(session == nil and reason == "stage verrouillé", "1-2 locked before 1-1 cleared")
		assert(select(2, s:StartStage(p, 2, 1)) == "stage verrouillé", "2-1 locked")
		local first = s:StartStage(p, 1, 1)
		assert(first and s:CompleteStage(p, first.Id, true))
		assert(select(2, s:StartStage(p, 1, 2)) == "stage verrouillé", "victory alone does not unlock: FirstClears belongs to #9")
		e.data[p].Progression.FirstClears["1-1"] = true -- écrit par RewardService (#9)
		local second = s:StartStage(p, 1, 2)
		assert(second and second.Config.Waves[1].Enemies[1].EnemyId == "Gobelin")
		assert(s:CompleteStage(p, second.Id, true))
		assert(deepEqual(e.questEvents[2].payload, { Zone = 1, Stage = 2 }))
		e.data[p].Progression.FirstClears["1-2"] = true
		local zone2 = s:StartStage(p, 2, 1)
		assert(zone2 and zone2.Zone == 2 and zone2.Config.Waves[1].Enemies[1].EnemyId == "Boss")
	end)

	test("invalid configs: warnings, broken stage not startable, no crash", function()
		local good = { Waves = { { Enemies = { { EnemyId = "Slime", Count = 1 } } } } }
		local badStages: { any } = {
			{ Waves = {} },
			{ Waves = { { Enemies = {} } } },
			{ Waves = { { Enemies = { { EnemyId = "", Count = 1 } } } } },
			{ Waves = { { Enemies = { { EnemyId = "Slime", Count = 0 } } } } },
			{ Waves = { { Enemies = { { EnemyId = "Slime", Count = 1.5 } } } } },
			{ Waves = { { Enemies = { { EnemyId = "Slime" } } } } },
			{ Waves = { { Enemies = { { EnemyId = "Slime", Count = 1 } } } }, MiniBoss = { Count = 1 } },
			{ Waves = { [1] = { Enemies = { { EnemyId = "Slime", Count = 1 } } }, [3] = { Enemies = {} } } },
			{ Waves = { { Enemies = { { EnemyId = "Slime", Count = 1 } } } }, MiniBoss = "Boss" },
		}
		for index, bad in badStages do
			local e = fixture({ Zones = { { Stages = { good, bad } } } })
			local s = e.start()
			assert(#e.warnings >= 1, `stage config {index} warned`)
			local p = e.player("A")
			e.data[p].Progression.FirstClears["1-1"] = true
			local session, reason = s:StartStage(p, 1, 2)
			assert(session == nil and reason == "stage indisponible", `config {index} -> {reason}`)
			assert(s:StartStage(p, 1, 1) ~= nil, "valid stage still playable")
		end
		local broken: { any } = {
			{},
			{ Zones = {} },
			{ Zones = { [2] = { Stages = { good } } } },
			{ Zones = { { Stages = { [2] = good } } } },
			{ Zones = { { Stages = {} } } },
			{ Zones = { "zone" } },
		}
		for index, config in broken do
			local e = fixture(config)
			local s = e.start()
			assert(#e.warnings >= 1, `zones config {index} warned`)
			local p = e.player("A")
			assert(s:StartStage(p, 1, 1) == nil, `zones config {index}: nothing startable`)
		end
	end)

	test("RequestStartStage remote: validates arguments, delegates to the server rules", function()
		local e = fixture()
		local s = e.start()
		local remote = e.remote()
		assert(remote and remote.ClassName == "RemoteFunction")
		assert(remote.Parent and remote.Parent.Name == "Remotes" and remote.Parent.Parent == e.replicated)
		local p = e.player("A")
		for _, args in { { "1", 1 }, { 1, nil }, { {}, 1 }, { 1, 1.5 }, { -1, 1 } } :: { any } do
			local ok, reason = remote.OnServerInvoke(p, args[1], args[2])
			assert(ok == false and reason == "requête invalide")
		end
		-- 3e argument = mode (nom seulement) : une table ou une valeur inconnue est refusée
		local bad, badReason = remote.OnServerInvoke(p, 1, 1, { Victory = true, Waves = {}, EnemyId = "Boss" })
		assert(bad == false and badReason == "requête invalide", "no client data as mode")
		local ok, reason = remote.OnServerInvoke(p, 1, 1, nil, { Victory = true, Waves = {}, EnemyId = "Boss" })
		assert(ok == true and reason == nil, "extra client arguments are ignored")
		local session = s:GetSession(p)
		assert(session and session.Config.Waves[1].Enemies[1].Count == 2, "server config used, not client data")
		ok, reason = remote.OnServerInvoke(p, 1, 1)
		assert(ok == false and reason == "session déjà en cours")
		local noPlot = e.player("B", false)
		ok, reason = remote.OnServerInvoke(noPlot, 1, 1)
		assert(ok == false and reason == "aucun plot")
		assert(#e.questEvents == 0, "the remote can never complete a stage")
	end)

	test("ZoneService itself never writes PlayerData (rewards delegated to RewardService)", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local before = e.freshData()
		local session = s:StartStage(p, 1, 1)
		assert(session)
		for key in session :: any do
			assert(key == "Id" or key == "Mode" or key == "Zone" or key == "Stage" or key == "Status" or key == "Config" or key == "Difficulty", "no combat field: " .. key)
		end
		s:CompleteStage(p, session.Id, true)
		local again = s:StartStage(p, 1, 1)
		assert(again)
		s:CompleteStage(p, again.Id, false)
		assert(deepEqual(e.data[p], before), "PlayerData never modified by ZoneService")
		assert(#e.questEvents == 1, "only the victory reached QuestService")
		assert(#e.rewardCalls == 1, "only the victory reached RewardService")
	end)

	test("ListStages: every stage in order, locked until the previous First Clear, cleared flag", function()
		local e = fixture(twoStageConfig())
		local s = e.start()
		local p = e.player("A")
		local list = s:ListStages(p)
		assert(#list == 3)
		assert(list[1].Zone == 1 and list[1].Stage == 1 and list[1].Status == "Unlocked" and list[1].Cleared == false)
		assert(list[2].Zone == 1 and list[2].Stage == 2 and list[2].Status == "Locked")
		assert(list[3].Zone == 2 and list[3].Stage == 1 and list[3].Status == "Locked")
		assert(list[1].Config.Waves[1].Enemies[1].EnemyId == "Slime", "config for the enemy summary")
		e.data[p].Progression.FirstClears["1-1"] = true
		list = s:ListStages(p)
		assert(list[1].Cleared == true and list[2].Status == "Unlocked" and list[3].Status == "Locked")
		e.data[p].Progression.FirstClears["1-2"] = true
		assert(s:ListStages(p)[3].Status == "Unlocked", "zone 2 opens after the last stage of zone 1")
	end)

	test("ListStages: invalid stage Unavailable; no data -> empty list", function()
		local bad = twoStageConfig()
		bad.Zones[1].Stages[2] = { Waves = {} }
		local e = fixture(bad)
		local s = e.start()
		local p = e.player("A")
		local list = s:ListStages(p)
		assert(list[2].Status == "Unavailable" and list[2].Config == nil)
		p.attributes.DataLoaded = nil
		assert(#s:ListStages(p) == 0)
	end)

	test("#13 production Zone 1: 5 valid stages, unlocked one by one by the previous First Clear, no 1-6", function()
		local e = fixture()
		local s = e.start()
		assert(#e.warnings == 0, "valid: " .. table.concat(e.warnings, "; "))
		local p = e.player("A")
		local function statuses(): string
			local out = {}
			for _, entry in s:ListStages(p) do
				if entry.Zone == 1 then table.insert(out, entry.Status) end
			end
			return table.concat(out, ",")
		end
		assert(statuses() == "Unlocked,Locked,Locked,Locked,Locked", statuses())
		for stage = 2, 5 do
			local ok, why = s:CanStartStage(p, 1, stage)
			assert(ok == false and why == "stage verrouillé", `1-{stage} locked on a new account`)
		end
		local expected = { "Unlocked,Unlocked,Locked,Locked,Locked", "Unlocked,Unlocked,Unlocked,Locked,Locked",
			"Unlocked,Unlocked,Unlocked,Unlocked,Locked", "Unlocked,Unlocked,Unlocked,Unlocked,Unlocked" }
		for stage = 1, 4 do
			e.data[p].Progression.FirstClears[`1-{stage}`] = true
			assert(statuses() == expected[stage], `after 1-{stage}: {statuses()}`)
		end
		local ok, why = s:CanStartStage(p, 1, 6)
		assert(ok == false and why == "stage inconnu")
		for index, stage in productionConfig.Zones[1].Stages do
			assert((stage.MiniBoss ~= nil) == (index == 5), `MiniBoss only on 1-5 (1-{index})`)
		end
	end)

	test("production Zones 2-6: 5 stages each, boss on X-5, X-1 opened by the previous zone's X-5, no 6-6 / 7-1", function()
		local e = fixture()
		local s = e.start()
		assert(#e.warnings == 0, "valid: " .. table.concat(e.warnings, "; "))
		assert(#productionConfig.Zones == 6, "6 zones")
		local p = e.player("A")
		assert(#s:ListStages(p) == 30, "30 stages")
		local clears = e.data[p].Progression.FirstClears
		for zone = 2, 6 do
			local stages = productionConfig.Zones[zone].Stages
			assert(#stages == 5, `zone {zone}: 5 stages`)
			for index, stage in stages do
				assert((stage.MiniBoss ~= nil) == (index == 5), `MiniBoss only on {zone}-5 ({zone}-{index})`)
			end
			local ok, why = s:CanStartStage(p, zone, 1)
			assert(ok == false and why == "stage verrouillé", `{zone}-1 locked before {zone - 1}-5`)
			for stage = 1, 5 do clears[`{zone - 1}-{stage}`] = true end
			assert(s:CanStartStage(p, zone, 1) == true, `{zone}-1 opened by {zone - 1}-5`)
			assert(s:CanStartStage(p, zone, 2) == false, `{zone}-2 still locked`)
		end
		for _, case in { { 6, 6 }, { 7, 1 } } do
			local ok, why = s:CanStartStage(p, case[1], case[2])
			assert(ok == false and why == "stage inconnu", `{case[1]}-{case[2]} unknown`)
		end
	end)

	test("production progression: all 30 stages unlock in order without unlocking another player", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local other = e.player("B")
		for index = 1, 30 do
			local zone = math.floor((index - 1) / 5) + 1
			local stage = (index - 1) % 5 + 1
			local list = s:ListStages(p)
			for i, entry in list do
				assert(entry.Status == (if i <= index then "Unlocked" else "Locked"), `step {index}, entry {i}`)
				assert(entry.Cleared == (i < index), `clear flag {index}/{i}`)
			end
			local session = s:StartStage(p, zone, stage)
			assert(session and session.Zone == zone and session.Stage == stage)
			assert(s:CompleteStage(p, session.Id, true))
			-- RewardService owns persistence; this fixture only records its calls.
			local call = e.rewardCalls[#e.rewardCalls]
			assert(call.player == p and call.zone == zone and call.stage == stage)
			e.data[p].Progression.FirstClears[`{zone}-{stage}`] = true
			for i, entry in s:ListStages(other) do
				assert(entry.Status == (if i == 1 then "Unlocked" else "Locked") and not entry.Cleared, `B isolated at {index}/{i}`)
			end
		end
		assert(#e.rewardCalls == 30 and #e.questEvents == 30)
	end)

	test("zone Difficulty: Normal session carries it; Elite multiplies it; Zone 1 Normal has none", function()
		local stage = { Waves = { { Enemies = { { EnemyId = "Slime", Count = 1 } } } } }
		local config = { Zones = {
			{ Stages = { stage } },
			{ Difficulty = { MaxHealth = 2, AttackDamage = 1.5 }, Stages = { stage } },
		} }
		local elite = { Zones = { [2] = { UnlockAfter = "2-1", Stages = { [1] = { MaxHealth = 1.5, AttackDamage = 2 } } } } }
		local e = fixture(config, elite)
		local s = e.start()
		assert(#e.warnings == 0, table.concat(e.warnings, "; "))
		local p = e.player("A")
		local first = s:StartStage(p, 1, 1)
		assert(first and first.Difficulty == nil, "zone 1 Normal: base stats")
		s:CancelStage(p)
		e.data[p].Progression.FirstClears["1-1"] = true
		local normal = s:StartStage(p, 2, 1)
		assert(normal and normal.Difficulty.MaxHealth == 2 and normal.Difficulty.AttackDamage == 1.5)
		s:CancelStage(p)
		e.data[p].Progression.FirstClears["2-1"] = true
		local hard = s:StartStage(p, 2, 1, "Elite")
		assert(hard and hard.Difficulty.MaxHealth == 3 and hard.Difficulty.AttackDamage == 3, "zone x Elite")
		assert(table.isfrozen(hard.Difficulty))
	end)

	test("zone Difficulty invalid: warning, the zone's stages Unavailable, other zones playable", function()
		local stage = { Waves = { { Enemies = { { EnemyId = "Slime", Count = 1 } } } } }
		local e = fixture({ Zones = {
			{ Stages = { stage } },
			{ Difficulty = { MaxHealth = -1, Speed = 2 }, Stages = { stage } },
		} })
		local s = e.start()
		assert(#e.warnings >= 2, "warnings logged")
		local p = e.player("A")
		e.data[p].Progression.FirstClears["1-1"] = true
		local list = s:ListStages(p)
		assert(list[1].Status == "Unlocked" and list[2].Status == "Unavailable")
		local ok, why = s:CanStartStage(p, 2, 1)
		assert(ok == false and why == "stage indisponible")
	end)

	print(`ZoneService: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{failed} ZoneService test(s) failed`)
	end
end
