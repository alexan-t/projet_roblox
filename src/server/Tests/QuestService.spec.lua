--!strict
-- Hors du dossier Services : jamais exécuté par le bootstrap.
-- Exécute le vrai QuestService avec la vraie QuestConfig (ou une config de test) et un double de DataService.

return function(createService: any, productionConfig: any)
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
		env.game = { GetService = function(_self: any, name: string): any
			assert(name == "ReplicatedStorage", name)
			return { Shared = { Utils = { Log = log }, Types = { PlayerDataTypes = {} } } }
		end }
		env.script = { Parent = { DataService = dataService,
			Parent = { Config = { QuestConfig = config or productionConfig } } } }
		env.require = function(module: any): any return module end

		function env.player(name: string): any return { Name = name } end
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

	test("production config: first quest DefendDomain, StageCompleted Zone 1 / Stage 1, no next quest", function()
		local e = fixture()
		e.start()
		assert(#e.warnings == 0, "production config valid")
		assert(productionConfig.FirstQuestId == "DefendDomain")
		local quest = productionConfig.Quests.DefendDomain
		assert(quest.Title == "Défends ton domaine" and quest.NextQuestId == nil)
		assert(quest.Objective.Event == "StageCompleted" and quest.Objective.Target == 1)
		assert(quest.Objective.Match.Zone == 1 and quest.Objective.Match.Stage == 1)
	end)

	test("new player: first quest activated at Progress 0", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local data = e.join(p)
		assert(deepEqual(data.Quests, { DefendDomain = { Progress = 0, Claimed = false } }))
		local active = s:GetActiveQuest(p)
		assert(active and active.Id == "DefendDomain" and active.Title == "Défends ton domaine")
		assert(active.Progress == 0 and active.Target == 1 and active.Completed == false)
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

	test("QuestService never touches currencies, first clears, tickets or other data", function()
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
		s:ClaimQuest(p, "DefendDomain")
		s:ClaimQuest(p, "DefendDomain")
		s:GetActiveQuest(p)
		assert(deepEqual(withoutQuests(data), frozen), "only Quests changed")
		assert(data.Currencies.SummonTickets == 0 and next(data.Progression.FirstClears) == nil)
	end)

	print(`QuestService: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{failed} QuestService test(s) failed`)
	end
end
