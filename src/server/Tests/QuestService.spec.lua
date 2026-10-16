--!strict
-- Hors du dossier Services : jamais exécuté par le bootstrap.
-- Exécute le vrai QuestService avec la vraie QuestConfig (ou une config de test) et un double de DataService.
-- Les mécanismes génériques (progression, réclamation manuelle « Récupérer », récompenses, remotes) sont
-- testés sur MANUAL, une quête réclamable à la main ; la vraie chaîne du tutoriel (SummonStarter →
-- DefendDomain, AutoClaim) est testée avec productionConfig.

return function(createService: any, productionConfig: any, QuestGuide: any, arenaConfig: any)
	local MANUAL = {
		FirstQuestId = "DefendDomain",
		Quests = {
			DefendDomain = {
				Title = "Défends ton domaine",
				Objective = { Event = "StageCompleted", Match = { Zone = 1, Stage = 1 }, Target = 1 },
				Guide = { Target = "StageSign" },
				Rewards = { { Kind = "SummonTicket", Amount = 1 } },
			},
		},
	}
	local function fixture(config: any?): any
		local env: any = { data = {}, readyCallbacks = {}, warnings = {}, infos = {} }
		local dataService: any = {}
		function dataService:GetData(player: any): any return env.data[player] end
		function dataService:OnPlayerReady(callback: any)
			table.insert(env.readyCallbacks, callback)
			for player, data in env.data do callback(player, data) end
		end
		local log = {
			debug = function() end,
			info = function(_scope: string, message: string) table.insert(env.infos, message) end,
			warn = function(_scope: string, message: string) table.insert(env.warnings, message) end,
		}
		-- Instances minimales : dossier Remotes, RemoteEvent (envois enregistrés), RemoteFunction.
		env.fired = {}
		local function inst(className: string): any
			local i: any = { ClassName = className, Name = className, children = {} }
			function i:FindFirstChild(n: string): any
				for _, c in self.children do if c.Name == n then return c end end
				return nil
			end
			return setmetatable({}, {
				__index = i,
				__newindex = function(t: any, k: string, v: any)
					i[k] = v
					if k == "Parent" and typeof(v) == "table" and v.children then table.insert(v.children, t) end
				end,
			})
		end
		local replicated = inst("ReplicatedStorage")
		replicated.Shared = { Utils = { Log = log }, Types = { PlayerDataTypes = {} }, Quests = { QuestGuide = QuestGuide } }
		env.replicated = replicated
		env.Instance = { new = function(className: string): any
			local i = inst(className)
			if className == "RemoteEvent" then
				i.FireClient = function(self: any, player: any, payload: any, extra: any)
					table.insert(env.fired, { remote = self.Name, player = player, payload = payload, extra = extra })
				end
			end
			return i
		end }
		env.game = { GetService = function(_self: any, name: string): any
			assert(name == "ReplicatedStorage", name)
			return replicated
		end }
		function env.remote(name: string): any
			local remotes = replicated:FindFirstChild("Remotes")
			return remotes and remotes:FindFirstChild(name)
		end
		function env.sent(player: any): { any }
			local out = {}
			for _, f in env.fired do if f.player == player and f.remote == "QuestChanged" then table.insert(out, f.payload or false) end end -- false = plus de quête
			return out
		end
		-- Quêtes AutoClaim annoncées terminées (2e argument de QuestChanged), dans l'ordre.
		function env.finished(player: any): { any }
			local out = {}
			for _, f in env.fired do if f.player == player and f.remote == "QuestChanged" and f.extra then table.insert(out, f.extra) end end
			return out
		end
		env.script = { Parent = { DataService = dataService,
			Parent = { Config = { QuestConfig = config or MANUAL } } } }
		env.require = function(module: any): any return module end

		function env.player(name: string): any return { Name = name, Parent = "Players" } end
		-- Données fraîches, comme DefaultPlayerData (le reste du profil sert à vérifier qu'il n'est pas touché).
		function env.freshData(): any
			return {
				DataVersion = 1,
				Currencies = { Gold = 0, Gems = 0, SummonTickets = 0 },
				Progression = { CurrentZone = 1, HighestStage = 0, FirstClears = {} },
				Heroes = {}, Team = {}, Kingdom = { Level = 1, VisualState = 1 },
				Quests = {}, Settings = { CombatSpeed = 1 },
			}
		end
		-- Joueur prêt : DataService fournit ses données puis notifie OnPlayerReady.
		function env.join(player: any, data: any?): any
			env.data[player] = data or env.freshData()
			for _, callback in env.readyCallbacks do callback(player, env.data[player]) end
			return env.data[player]
		end
		function env.leave(player: any): any
			local data = env.data[player]
			env.data[player] = nil
			return data
		end
		function env.start(): any
			env.service = createService(env)
			env.service:Init()
			env.service:Start()
			return env.service
		end
		return env
	end

	local STAGE_1_1 = { Zone = 1, Stage = 1 }
	-- Victoire comme ZoneService puis RewardService : événement de quête, puis First Clear enregistré.
	local function win(s: any, p: any, data: any, stage: number)
		s:HandleGameplayEvent(p, "StageCompleted", { Zone = 1, Stage = stage })
		data.Progression.FirstClears[`1-{stage}`] = true
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

	test("production config: Zone 1 chain SummonStarter -> 1-1 -> 1-2 -> 1-3 -> 1-4 -> Roi Orc, rewards in QuestConfig only", function()
		local e = fixture(productionConfig)
		e.start()
		assert(#e.warnings == 0, "production config valid")
		assert(productionConfig.FirstQuestId == "SummonStarter")
		local first = productionConfig.Quests.SummonStarter
		assert(first.Title == "Invoque ton premier héros" and first.NextQuestId == "DefendDomain")
		assert(first.Objective.Event == "StarterHeroSummoned" and first.Objective.Target == 1 and first.Objective.Match == nil)
		assert(first.Guide.Target == "SummonPortal" and first.AutoClaim == true and first.Onboarding == true)
		assert(first.Rewards == nil, "the Ecuyer and its reveal are the reward")
		local expected = {
			{ "DefendDomain", "Gagne la défense 1-1", 1, "DefendStage12", { Gold = 50 } },
			{ "DefendStage12", "Gagne la défense 1-2", 2, "DefendStage13", { Gold = 75, Gems = 5 } },
			{ "DefendStage13", "Gagne la défense 1-3", 3, "DefendStage14", { Gold = 100, Gems = 10 } },
			{ "DefendStage14", "Gagne la défense 1-4", 4, "DefeatRoiOrc", { Gold = 150, Gems = 15 } },
			{ "DefeatRoiOrc", "Vaincre le Roi Orc", 5, nil, { Gold = 250, Gems = 25, SummonTicket = 1 } },
		}
		for _, row in expected do
			local quest = productionConfig.Quests[row[1]]
			assert(quest and quest.Title == row[2] and quest.NextQuestId == row[4], row[1])
			assert(quest.Objective.Event == "StageCompleted" and quest.Objective.Target == 1, row[1])
			assert(quest.Objective.Match.Zone == 1 and quest.Objective.Match.Stage == row[3], row[1])
			assert(quest.Guide.Target == "StageSign" and quest.AutoClaim == nil, row[1] .. ": waits for Récupérer")
			local rewards = {}
			for _, reward in quest.Rewards do rewards[reward.Kind] = reward.Amount end
			assert(deepEqual(rewards, row[5]), row[1] .. " rewards")
		end
		assert(productionConfig.Quests.DefendDomain.Guide.Placement == true, "1-1 teaches the placement")
	end)

	test("boss quest title uses the official boss name (ArenaConfig.EnemyNames.Boss)", function()
		assert(arenaConfig.EnemyNames.Boss == "Roi Orc")
		assert(productionConfig.Quests.DefeatRoiOrc.Title == `Vaincre le {arenaConfig.EnemyNames.Boss}`)
	end)
	test("new player: first quest SummonStarter activated at Progress 0 (onboarding, guided to the portal)", function()
		local e = fixture(productionConfig)
		local s = e.start()
		local p = e.player("A")
		local data = e.join(p)
		assert(deepEqual(data.Quests, { SummonStarter = { Progress = 0, Claimed = false } }))
		local active = s:GetActiveQuest(p)
		assert(active and active.Id == "SummonStarter" and active.Title == "Invoque ton premier héros")
		assert(active.Progress == 0 and active.Target == 1 and active.Completed == false)
		assert(active.GuideTarget == "SummonPortal" and active.Onboarding == true and active.AutoClaim == true and active.GuidePlacement == false)
		assert(deepEqual(s:GetQuestState(p, "SummonStarter"), { Progress = 0, Claimed = false }))
	end)

	test("SummonStarter -> DefendDomain chain: the starter summon auto-claims and activates DefendDomain", function()
		local e = fixture(productionConfig)
		local s = e.start()
		local p = e.player("A")
		local data = e.join(p)
		assert(s:HandleGameplayEvent(p, "StageCompleted", STAGE_1_1) == false, "DefendDomain not active yet")
		assert(s:HandleGameplayEvent(p, "StarterHeroSummoned") == true)
		assert(deepEqual(data.Quests, { SummonStarter = { Progress = 1, Claimed = true }, DefendDomain = { Progress = 0, Claimed = false } }))
		local active = s:GetActiveQuest(p)
		assert(active and active.Id == "DefendDomain" and active.Title == "Gagne la défense 1-1" and active.Progress == 0)
		assert(active.GuideTarget == "StageSign" and active.GuidePlacement == true and active.Onboarding == false)
		local sent, finished = e.sent(p), e.finished(p)
		assert(#sent == 2 and sent[2].Id == "DefendDomain", "one push: straight to the next quest (no Récupérer step)")
		assert(#finished == 1 and finished[1].Id == "SummonStarter" and finished[1].Title == "Invoque ton premier héros" and #finished[1].Rewards == 0)
		assert(s:HandleGameplayEvent(p, "StarterHeroSummoned") == false, "never twice")
		local ok, why = s:ClaimQuest(p, "SummonStarter")
		assert(ok == false and why == "déjà réclamée", "nothing left to claim")
		assert(data.Currencies.SummonTickets == 0 and data.Currencies.Gold == 0 and data.Currencies.Gems == 0, "no quest reward")
	end)

	test("DefendDomain completes only on Stage 1-1, then waits for Récupérer: 50 Gold once, DefendStage12 next", function()
		local e = fixture(productionConfig)
		local s = e.start()
		local p = e.player("A")
		local data = e.join(p)
		s:HandleGameplayEvent(p, "StarterHeroSummoned")
		for _, payload in { { Zone = 1, Stage = 2 }, { Zone = 2, Stage = 1 }, {} } :: { any } do
			assert(s:HandleGameplayEvent(p, "StageCompleted", payload) == false)
		end
		assert(data.Quests.DefendDomain.Progress == 0)
		win(s, p, data, 1)
		assert(data.Quests.DefendDomain.Progress == 1 and data.Quests.DefendDomain.Claimed == false, "no auto-claim from 1-1 on")
		local view = s:GetActiveQuest(p)
		assert(view and view.Id == "DefendDomain" and view.Completed == true and view.AutoClaim == false and view.GuideTarget == nil)
		assert(data.Currencies.Gold == 0, "nothing before the click")
		local ok, why, granted = e.remote("ClaimQuest").OnServerInvoke(p, "DefendDomain")
		assert(ok == true and why == nil and granted and #granted == 1 and granted[1].Kind == "Gold" and granted[1].Amount == 50)
		assert(data.Currencies.Gold == 50 and data.Currencies.Gems == 0 and data.Currencies.SummonTickets == 0)
		local nextView = s:GetActiveQuest(p)
		assert(nextView and nextView.Id == "DefendStage12" and nextView.Title == "Gagne la défense 1-2" and nextView.GuideTarget == "StageSign")
		local sent = e.sent(p)
		assert(sent[#sent].Id == "DefendStage12", "QuestChanged carries the next quest after the claim")
	end)

	test("full Zone 1 chain: each win waits for Récupérer, rewards exactly once each, chain ends after the Roi Orc", function()
		local e = fixture(productionConfig)
		local s = e.start()
		local p = e.player("A")
		local data = e.join(p)
		s:HandleGameplayEvent(p, "StarterHeroSummoned")
		local claim = e.remote("ClaimQuest").OnServerInvoke
		local chain = { "DefendDomain", "DefendStage12", "DefendStage13", "DefendStage14", "DefeatRoiOrc" }
		local totals = { { 50, 0, 0 }, { 125, 5, 0 }, { 225, 15, 0 }, { 375, 30, 0 }, { 625, 55, 1 } }
		for stage, id in chain do
			assert(s:GetActiveQuest(p).Id == id, `active {id}`)
			assert(claim(p, id) == false, `{id}: refused before the win`)
			win(s, p, data, stage)
			assert(claim(p, id) == true, `{id} claimed`)
			for _ = 1, 5 do assert(claim(p, id) == false, `{id}: never twice`) end
			local c = data.Currencies
			assert(c.Gold == totals[stage][1] and c.Gems == totals[stage][2] and c.SummonTickets == totals[stage][3], `{id} totals {c.Gold}/{c.Gems}/{c.SummonTickets}`)
		end
		assert(s:GetActiveQuest(p) == nil, "Zone 1 chain finished")
		local sent = e.sent(p)
		assert(sent[#sent] == false, "nil view sent at the end of the chain")
	end)

	test("#12 Zone 1 quest claims: forged / not active / not finished / spam -> refused, rewards only from QuestConfig", function()
		local e = fixture(productionConfig)
		local s = e.start()
		local p = e.player("A")
		local data = e.join(p)
		s:HandleGameplayEvent(p, "StarterHeroSummoned")
		local claim = e.remote("ClaimQuest").OnServerInvoke
		for _, bad in { "DefeatRoiOrc", "DefendStage14", "Inconnue", 42, {}, nil, "SummonStarter" } :: { any } do
			assert(claim(p, bad, { Kind = "Gold", Amount = 1e9 }) == false, tostring(bad))
		end
		-- une quête future, même déjà « commencée » à la main, n'est pas réclamable tant qu'elle n'est pas active
		data.Quests.DefeatRoiOrc = { Progress = 1, Claimed = false }
		local okFuture, whyFuture = claim(p, "DefeatRoiOrc")
		assert(okFuture == false and whyFuture == "quête non active")
		data.Quests.DefeatRoiOrc = nil
		assert(data.Currencies.Gold == 0 and data.Currencies.Gems == 0 and data.Currencies.SummonTickets == 0)
		win(s, p, data, 1)
		local successes = 0
		for _ = 1, 20 do if claim(p, "DefendDomain", 999) == true then successes += 1 end end
		assert(successes == 1 and data.Currencies.Gold == 50, "20 clicks: 50 Gold once, extra arguments ignored")
	end)

	test("stage already won before its quest is active: completed at activation, claimable, never replayed", function()
		local e = fixture(productionConfig)
		local s = e.start()
		local p = e.player("A")
		local data = e.join(p)
		s:HandleGameplayEvent(p, "StarterHeroSummoned")
		win(s, p, data, 1) -- 1-1 gagné, oublie de récupérer
		win(s, p, data, 2) -- puis gagne 1-2 quand même
		assert(data.Quests.DefendStage12 == nil, "not active yet")
		assert(e.remote("ClaimQuest").OnServerInvoke(p, "DefendDomain") == true)
		local view = s:GetActiveQuest(p)
		assert(view and view.Id == "DefendStage12" and view.Progress == 1 and view.Completed == true, "synced from FirstClears 1-2")
		assert(data.Quests.DefendStage12.Claimed == false)
		local ok, _, granted = e.remote("ClaimQuest").OnServerInvoke(p, "DefendStage12")
		assert(ok and #granted == 2 and data.Currencies.Gold == 125 and data.Currencies.Gems == 5)
		local third = s:GetActiveQuest(p)
		assert(third and third.Id == "DefendStage13" and third.Completed == false, "1-3 not won: normal quest")
	end)
	test("rejoin: before the summon, after it, after 1-1 before / after the claim", function()
		local e = fixture(productionConfig)
		local s = e.start()
		local a = e.player("A")
		local data = e.join(a)
		local function rejoin()
			data = e.join(a, e.leave(a))
		end
		rejoin()
		assert(s:GetActiveQuest(a).Id == "SummonStarter", "quit before the summon")
		s:HandleGameplayEvent(a, "StarterHeroSummoned")
		rejoin()
		local view = s:GetActiveQuest(a)
		assert(view.Id == "DefendDomain" and view.GuideTarget == "StageSign", "quit after the summon")
		win(s, a, data, 1)
		rejoin()
		view = s:GetActiveQuest(a)
		assert(view.Id == "DefendDomain" and view.Completed == true and data.Currencies.Gold == 0, "quit before the claim: still to claim")
		assert(e.remote("ClaimQuest").OnServerInvoke(a, "DefendDomain") == true)
		rejoin()
		assert(s:GetActiveQuest(a).Id == "DefendStage12" and data.Currencies.Gold == 50, "quit after the claim: next quest, reward kept once")
		assert(e.remote("ClaimQuest").OnServerInvoke(a, "DefendDomain") == false)
	end)
	test("migrated old profile (stage quests claimed by the migration) resumes at the first stage not won", function()
		local e = fixture(productionConfig)
		local s = e.start()
		local old = e.freshData()
		old.Progression.FirstClears = { ["1-1"] = true }
		old.Quests = { SummonStarter = { Progress = 1, Claimed = true }, DefendDomain = { Progress = 1, Claimed = true } }
		local p = e.player("Ancien")
		local data = e.join(p, old)
		local view = s:GetActiveQuest(p)
		assert(view.Id == "DefendStage12" and view.Progress == 0 and data.Currencies.Gold == 0)
		local q = e.player("Ancien2")
		local done = e.freshData()
		done.Quests = { SummonStarter = { Progress = 1, Claimed = true }, DefendDomain = { Progress = 1, Claimed = true },
			DefendStage12 = { Progress = 1, Claimed = true }, DefendStage13 = { Progress = 1, Claimed = true },
			DefendStage14 = { Progress = 1, Claimed = true }, DefeatRoiOrc = { Progress = 1, Claimed = true } }
		e.join(q, done)
		assert(s:GetActiveQuest(q) == nil, "Zone 1 already finished: nothing to do, nothing given")
	end)
	test("AutoClaim quest saved completed but unclaimed (older version) is settled at load, once", function()
		local e = fixture(productionConfig)
		local s = e.start()
		local saved = e.freshData()
		saved.Quests = { SummonStarter = { Progress = 1, Claimed = false } }
		local p = e.player("A")
		local data = e.join(p, saved)
		assert(data.Quests.SummonStarter.Claimed == true and s:GetActiveQuest(p).Id == "DefendDomain")
		for _, callback in e.readyCallbacks do callback(p, data) end
		assert(data.Currencies.Gold == 0 and data.Quests.DefendDomain.Claimed == false)
	end)
	test("two players: each runs its own tutorial chain, QuestChanged to the right player only", function()
		local e = fixture(productionConfig)
		local s = e.start()
		local a, b = e.player("A"), e.player("B")
		local da, db = e.join(a), e.join(b)
		s:HandleGameplayEvent(a, "StarterHeroSummoned")
		assert(da.Quests.DefendDomain and db.Quests.DefendDomain == nil and db.Quests.SummonStarter.Progress == 0)
		assert(#e.finished(a) == 1 and #e.finished(b) == 0)
		assert(s:GetActiveQuest(b).Id == "SummonStarter" and s:GetActiveQuest(a).Id == "DefendDomain")
	end)

	test("new player: first quest activated at Progress 0", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local data = e.join(p)
		assert(deepEqual(data.Quests, { DefendDomain = { Progress = 0, Claimed = false } }))
		local active = s:GetActiveQuest(p)
		assert(active and active.Id == "DefendDomain" and active.Title == "Défends ton domaine")
		assert(active.Progress == 0 and active.Target == 1 and active.Completed == false and active.AutoClaim == false)
		assert(deepEqual(s:GetQuestState(p, "DefendDomain"), { Progress = 0, Claimed = false }))
	end)

	test("repeated activation never resets saved progress", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local data = e.join(p)
		assert(s:HandleGameplayEvent(p, "StageCompleted", STAGE_1_1))
		for _, callback in e.readyCallbacks do callback(p, data) end -- rejeu de OnPlayerReady
		s:GetActiveQuest(p)
		s:GetActiveQuest(p)
		assert(data.Quests.DefendDomain.Progress == 1 and data.Quests.DefendDomain.Claimed == false)
	end)

	test("no data: every call is a no-op", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		assert(s:GetActiveQuest(p) == nil and s:GetQuestState(p, "DefendDomain") == nil)
		assert(s:HandleGameplayEvent(p, "StageCompleted", STAGE_1_1) == false)
		local ok, reason = s:ClaimQuest(p, "DefendDomain")
		assert(ok == false and reason == "données non chargées")
	end)

	test("unknown event, wrong stage, wrong zone, bad payload: no progress", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local data = e.join(p)
		local cases: { { any } } = {
			{ "EnemyKilled", STAGE_1_1 },
			{ "StageCompleted", { Zone = 1, Stage = 2 } },
			{ "StageCompleted", { Zone = 2, Stage = 1 } },
			{ "StageCompleted", { Zone = "1", Stage = "1" } },
			{ "StageCompleted", { Zone = 1 } },
			{ "StageCompleted", {} },
			{ "StageCompleted", nil },
		}
		for index, case in cases do
			assert(s:HandleGameplayEvent(p, case[1], case[2]) == false, "case " .. index)
			assert(data.Quests.DefendDomain.Progress == 0, "case " .. index)
		end
	end)

	test("StageCompleted Zone 1 / Stage 1 completes, repeats stay capped at the target", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local data = e.join(p)
		assert(s:HandleGameplayEvent(p, "StageCompleted", { Zone = 1, Stage = 1, Extra = true }) == true)
		assert(data.Quests.DefendDomain.Progress == 1)
		for _ = 1, 3 do assert(s:HandleGameplayEvent(p, "StageCompleted", STAGE_1_1) == false) end
		assert(data.Quests.DefendDomain.Progress == 1 and data.Quests.DefendDomain.Claimed == false)
		local active = s:GetActiveQuest(p)
		assert(active and active.Completed == true and active.Id == "DefendDomain", "completed but not claimed")
	end)

	test("claim refused before completion, accepted once, refused afterwards", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local data = e.join(p)
		local ok, reason = s:ClaimQuest(p, "DefendDomain")
		assert(ok == false and reason == "quête non terminée" and data.Quests.DefendDomain.Claimed == false)
		s:HandleGameplayEvent(p, "StageCompleted", STAGE_1_1)
		ok, reason = s:ClaimQuest(p, "DefendDomain")
		assert(ok == true and reason == nil and data.Quests.DefendDomain.Claimed == true)
		ok, reason = s:ClaimQuest(p, "DefendDomain")
		assert(ok == false and reason == "déjà réclamée")
		ok, reason = s:ClaimQuest(p, "Inconnue")
		assert(ok == false and reason == "quête inconnue")
		-- Chaîne terminée : plus de quête active, plus aucune progression possible.
		assert(s:GetActiveQuest(p) == nil)
		assert(s:HandleGameplayEvent(p, "StageCompleted", STAGE_1_1) == false)
		assert(deepEqual(data.Quests, { DefendDomain = { Progress = 1, Claimed = true } }))
	end)

	test("rejoin keeps claimed and in-progress states", function()
		local e = fixture()
		local s = e.start()
		local a, b = e.player("A"), e.player("B")
		e.join(a)
		s:HandleGameplayEvent(a, "StageCompleted", STAGE_1_1)
		assert(s:ClaimQuest(a, "DefendDomain"))
		local savedA = e.leave(a)
		local rejoinedA = e.join(a, savedA)
		assert(deepEqual(rejoinedA.Quests, { DefendDomain = { Progress = 1, Claimed = true } }))
		assert(s:ClaimQuest(a, "DefendDomain") == false, "still claimed after rejoin")
		-- Progression sauvegardée d'un autre joueur, non réclamée : jamais écrasée au join.
		local saved = e.freshData()
		saved.Quests.DefendDomain = { Progress = 1, Claimed = false }
		local dataB = e.join(b, saved)
		assert(dataB.Quests.DefendDomain.Progress == 1 and dataB.Quests.DefendDomain.Claimed == false)
		assert(s:ClaimQuest(b, "DefendDomain") == true)
	end)

	test("two players are independent", function()
		local e = fixture()
		local s = e.start()
		local a, b = e.player("A"), e.player("B")
		local dataA, dataB = e.join(a), e.join(b)
		assert(s:HandleGameplayEvent(a, "StageCompleted", STAGE_1_1))
		assert(dataA.Quests.DefendDomain.Progress == 1 and dataB.Quests.DefendDomain.Progress == 0)
		assert(s:ClaimQuest(a, "DefendDomain"))
		assert(dataB.Quests.DefendDomain.Claimed == false)
		assert(s:ClaimQuest(b, "DefendDomain") == false, "B has not completed it")
		local activeB = s:GetActiveQuest(b)
		assert(activeB and activeB.Progress == 0)
	end)

	test("NextQuestId activates the next quest after the claim (test config)", function()
		local config = {
			FirstQuestId = "Q1",
			Quests = {
				Q1 = { Title = "Un", Objective = { Event = "StageCompleted", Match = { Zone = 1, Stage = 1 }, Target = 1 }, NextQuestId = "Q2" },
				Q2 = { Title = "Deux", Objective = { Event = "HeroSummoned", Target = 2 } },
			},
		}
		local e = fixture(config)
		local s = e.start()
		assert(#e.warnings == 0)
		local p = e.player("A")
		local data = e.join(p)
		assert(data.Quests.Q2 == nil, "next quest not active before the claim")
		assert(s:HandleGameplayEvent(p, "HeroSummoned", {}) == false, "Q2 event ignored while Q1 active")
		s:HandleGameplayEvent(p, "StageCompleted", STAGE_1_1)
		assert(s:ClaimQuest(p, "Q1"))
		assert(deepEqual(data.Quests.Q2, { Progress = 0, Claimed = false }))
		local active = s:GetActiveQuest(p)
		assert(active and active.Id == "Q2" and active.Target == 2)
		-- Objectif sans Match : tout événement du bon nom compte, jusqu'à la cible.
		assert(s:HandleGameplayEvent(p, "HeroSummoned", nil) and s:HandleGameplayEvent(p, "HeroSummoned", { Any = 1 }))
		assert(s:HandleGameplayEvent(p, "HeroSummoned", nil) == false and data.Quests.Q2.Progress == 2)
		assert(s:ClaimQuest(p, "Q2") and s:GetActiveQuest(p) == nil)
		-- Rejoin au milieu de la chaîne : Q1 déjà réclamée, Q2 reprise sans reset.
		local saved = e.freshData()
		saved.Quests = { Q1 = { Progress = 1, Claimed = true }, Q2 = { Progress = 1, Claimed = false } }
		local q = e.player("B")
		e.join(q, saved)
		local activeB = s:GetActiveQuest(q)
		assert(activeB and activeB.Id == "Q2" and activeB.Progress == 1)
	end)

	test("NextQuestId = nil ends the chain cleanly", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		e.join(p)
		s:HandleGameplayEvent(p, "StageCompleted", STAGE_1_1)
		assert(s:ClaimQuest(p, "DefendDomain"))
		assert(s:GetActiveQuest(p) == nil and #e.warnings == 0)
		assert(e.infos[#e.infos]:find("DefendDomain réclamée", 1, true) ~= nil)
	end)

	test("invalid configs: warnings, quests disabled, no crash", function()
		local base = function(): any
			return { Title = "T", Objective = { Event = "StageCompleted", Target = 1 } }
		end
		local broken: { any } = {
			{ FirstQuestId = "Absente", Quests = { Q = base() } },
			{ FirstQuestId = "Q", Quests = { Q = { Objective = { Event = "E", Target = 1 } } } },
			{ FirstQuestId = "Q", Quests = { Q = { Title = "T", Objective = { Target = 1 } } } },
			{ FirstQuestId = "Q", Quests = { Q = { Title = "T", Objective = { Event = "E", Target = 0 } } } },
			{ FirstQuestId = "Q", Quests = { Q = { Title = "T", Objective = { Event = "E", Target = 1.5 } } } },
			{ FirstQuestId = "Q", Quests = { Q = { Title = "T", Objective = { Event = "E", Target = 1, Match = 3 } } } },
			{ FirstQuestId = "Q", Quests = { Q = { Title = "T", Objective = { Event = "E", Target = 1 }, NextQuestId = "Z" } } },
			{ FirstQuestId = "Q", Quests = {
				Q = { Title = "T", Objective = { Event = "E", Target = 1 }, NextQuestId = "R" },
				R = { Title = "T", Objective = { Event = "E", Target = 1 }, NextQuestId = "Q" },
			} },
			{ FirstQuestId = "Q" },
		}
		for index, config in broken do
			local e = fixture(config)
			local s = e.start()
			assert(#e.warnings >= 2, "config " .. index .. " warned")
			local p = e.player("A")
			local data = e.join(p)
			assert(next(data.Quests) == nil, "config " .. index .. " activates nothing")
			assert(s:GetActiveQuest(p) == nil and s:HandleGameplayEvent(p, "E", {}) == false)
			assert(s:ClaimQuest(p, "Q") == false)
		end
	end)

	test("QuestService touches nothing but Quests, plus the configured reward once at the claim", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local data = e.join(p)
		local function withoutQuests(d: any): any
			local copy = table.clone(d)
			copy.Quests = nil
			return copy
		end
		local snapshot = withoutQuests(data)
		local frozen = {}
		for k, v in snapshot do frozen[k] = if type(v) == "table" then table.clone(v) else v end
		s:HandleGameplayEvent(p, "StageCompleted", STAGE_1_1)
		s:GetActiveQuest(p)
		assert(deepEqual(withoutQuests(data), frozen), "progress alone changes only Quests")
		s:ClaimQuest(p, "DefendDomain")
		s:ClaimQuest(p, "DefendDomain")
		s:GetActiveQuest(p)
		-- seule différence : le ticket de la première quête (QuestConfig.Rewards), une seule fois
		frozen.Currencies.SummonTickets += 1
		assert(deepEqual(withoutQuests(data), frozen), "only Quests and the configured reward changed")
		assert(data.Currencies.SummonTickets == 1 and data.Currencies.Gold == 0 and next(data.Progression.FirstClears) == nil)
	end)

	-- Remotes (#11) ---------------------------------------------------------------

	test("remote GetActiveQuest: read-only view of the active quest, never PlayerData", function()
		local e = fixture()
		e.start()
		local p = e.player("A")
		local data = e.join(p)
		local view = e.remote("GetActiveQuest").OnServerInvoke(p)
		assert(view and view.Id == "DefendDomain" and view.Progress == 0 and view.Target == 1 and view.Completed == false)
		assert(view.Quests == nil and view.Currencies == nil, "no profile data")
		view.Progress = 99
		assert(data.Quests.DefendDomain.Progress == 0, "a copy: editing the view changes nothing")
		assert(e.remote("GetActiveQuest").OnServerInvoke(e.player("SansDonnees")) == nil)
	end)

	test("QuestChanged: sent on activation, on progress, on claim (nil when the chain is over)", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		e.join(p)
		local sent = e.sent(p)
		assert(#sent == 1 and sent[1].Id == "DefendDomain" and sent[1].Progress == 0, "activation")
		s:HandleGameplayEvent(p, "StageCompleted", { Zone = 1, Stage = 2 })
		assert(#e.sent(p) == 1, "no progress, nothing sent")
		s:HandleGameplayEvent(p, "StageCompleted", STAGE_1_1)
		sent = e.sent(p)
		assert(#sent == 2 and sent[2].Progress == 1 and sent[2].Completed == true, "progress")
		local ok = e.remote("ClaimQuest").OnServerInvoke(p, "DefendDomain")
		sent = e.sent(p)
		assert(ok == true and #sent == 3 and sent[3] == false, "claimed, no next quest (nil sent)")
	end)

	test("remote ClaimQuest: too early refused, valid once, double refused, bad ids refused", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local data = e.join(p)
		local claim = e.remote("ClaimQuest").OnServerInvoke
		local ok, why = claim(p, "DefendDomain")
		assert(ok == false and why == "quête non terminée" and data.Quests.DefendDomain.Claimed == false)
		for _, bad in { 42, nil, {}, "Inconnue" } :: { any } do
			local okBad = claim(p, bad)
			assert(okBad == false, tostring(bad))
		end
		assert(data.Currencies.SummonTickets == 0, "nothing before completion")
		s:HandleGameplayEvent(p, "StageCompleted", STAGE_1_1)
		local okClaim, _, granted = claim(p, "DefendDomain")
		assert(okClaim == true and data.Quests.DefendDomain.Claimed == true)
		assert(granted and #granted == 1 and granted[1].Kind == "SummonTicket" and granted[1].Amount == 1, "granted rewards returned for display")
		local again, why2, none = claim(p, "DefendDomain")
		assert(again == false and why2 == "déjà réclamée" and none == nil)
		assert(data.Currencies.Gold == 0 and data.Currencies.SummonTickets == 1, "exactly the configured ticket, no extra reward")
	end)

	test("two players: independent quests and QuestChanged to the right player only", function()
		local e = fixture()
		local s = e.start()
		local a, b = e.player("A"), e.player("B")
		local da, db = e.join(a), e.join(b)
		s:HandleGameplayEvent(a, "StageCompleted", STAGE_1_1)
		assert(da.Quests.DefendDomain.Progress == 1 and db.Quests.DefendDomain.Progress == 0)
		assert(#e.sent(a) == 2 and #e.sent(b) == 1)
		assert(e.remote("ClaimQuest").OnServerInvoke(b, "DefendDomain") == false, "B has not finished")
		assert(e.remote("ClaimQuest").OnServerInvoke(a, "DefendDomain") == true)
		assert(db.Quests.DefendDomain.Claimed == false)
	end)

	test("#12 ClaimQuest spam after completion: 20 claims -> one success, progression never forged", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local data = e.join(p)
		local claim = e.remote("ClaimQuest").OnServerInvoke
		for _ = 1, 20 do assert(claim(p, "DefendDomain") == false, "before completion") end
		assert(data.Quests.DefendDomain.Progress == 0 and data.Quests.DefendDomain.Claimed == false)
		s:HandleGameplayEvent(p, "StageCompleted", STAGE_1_1)
		local ok = 0
		for _ = 1, 20 do if claim(p, "DefendDomain") == true then ok += 1 end end
		assert(ok == 1 and data.Quests.DefendDomain.Claimed == true and data.Quests.DefendDomain.Progress == 1)
		assert(data.Currencies.SummonTickets == 1, "20 claims: the quest ticket is granted exactly once")
		assert(s:HandleGameplayEvent(p, "StageCompleted", STAGE_1_1) == false, "no progress after the chain ended")
	end)

	-- Guidage (QuestGuide) ----------------------------------------------------------

	test("guide: DefendDomain guides to StageSign while in progress, nothing once completed", function()
		assert(productionConfig.Quests.DefendDomain.Guide.Target == "StageSign")
		assert(productionConfig.Quests.SummonStarter.Guide.Target == "SummonPortal")
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		e.join(p)
		local view = s:GetActiveQuest(p)
		assert(view and view.GuideTarget == "StageSign", "in progress: guided")
		s:HandleGameplayEvent(p, "StageCompleted", STAGE_1_1)
		local done = s:GetActiveQuest(p)
		assert(done and done.Completed and done.GuideTarget == nil, "completed: no more path")
	end)

	test("guide: every configured Guide.Target is a known QuestGuide target (production config)", function()
		for id, quest in productionConfig.Quests do
			if quest.Guide ~= nil then
				assert(QuestGuide.isTarget(quest.Guide.Target), `{id} : cible {tostring(quest.Guide.Target)}`)
			end
		end
	end)

	test("guide: an unknown or malformed Guide.Target makes the config invalid (warning, quests disabled)", function()
		for _, guide in { { Target = "PlotTravail" }, { Target = 5 }, "StageSign" } do
			local e = fixture({
				FirstQuestId = "A",
				Quests = { A = { Title = "A", Objective = { Event = "X", Target = 1 }, Guide = guide } },
			})
			local s = e.start()
			local p = e.player("A")
			e.join(p)
			assert(s:GetActiveQuest(p) == nil, "invalid guide: quests disabled")
			assert(#e.warnings > 0, "a warning explains why")
		end
	end)

	test("rewards: shown in the view, invalid kinds or amounts make the config invalid", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		e.join(p)
		local view = s:GetActiveQuest(p)
		assert(view and #view.Rewards == 1 and view.Rewards[1].Kind == "SummonTicket" and view.Rewards[1].Amount == 1)
		view.Rewards[1].Amount = 99
		assert(s:GetActiveQuest(p).Rewards[1].Amount == 1, "a copy, never the config")
		for _, rewards in { { { Kind = "Diamant", Amount = 1 } }, { { Kind = "Gold", Amount = 0 } }, { { Kind = "Gold", Amount = 1.5 } }, "Gold" } :: { any } do
			local bad = fixture({ FirstQuestId = "A", Quests = { A = { Title = "A", Objective = { Event = "X", Target = 1 }, Rewards = rewards } } })
			local service = bad.start()
			local q = bad.player("A")
			bad.join(q)
			assert(service:GetActiveQuest(q) == nil and #bad.warnings > 0, "invalid rewards refused")
		end
	end)

	test("config: AutoClaim / Onboarding / Guide.Placement must be booleans", function()
		for _, quest in {
			{ Title = "A", Objective = { Event = "X", Target = 1 }, AutoClaim = "oui" },
			{ Title = "A", Objective = { Event = "X", Target = 1 }, Onboarding = 1 },
			{ Title = "A", Objective = { Event = "X", Target = 1 }, Guide = { Target = "StageSign", Placement = "oui" } },
		} :: { any } do
			local bad = fixture({ FirstQuestId = "A", Quests = { A = quest } })
			local service = bad.start()
			local q = bad.player("A")
			bad.join(q)
			assert(service:GetActiveQuest(q) == nil and #bad.warnings > 0)
		end
	end)

	test("guide: a quest without Guide exposes no GuideTarget", function()
		local e = fixture({ FirstQuestId = "A", Quests = { A = { Title = "A", Objective = { Event = "X", Target = 1 } } } })
		local s = e.start()
		local p = e.player("A")
		e.join(p)
		local view = s:GetActiveQuest(p)
		assert(view and view.GuideTarget == nil)
	end)

	print(`QuestService: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{failed} QuestService test(s) failed`)
	end
end
