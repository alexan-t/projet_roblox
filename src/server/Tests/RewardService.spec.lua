--!strict
-- Hors du dossier Services : jamais exécuté par le bootstrap.
-- Exécute le vrai RewardService avec les vraies RewardRules et la vraie RewardConfig (ou une config
-- de test), et des doubles de DataService et des API Roblox utilisées.

return function(createService: any, RewardRules: any, productionConfig: any)
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

	local function fixture(config: any?): any
		local env: any = { data = {}, warnings = {}, removing = {} }
		env.players = { PlayerRemoving = { Connect = function(_self: any, fn: any) table.insert(env.removing, fn) end } }
		env.game = { GetService = function(_self: any, name: string): any
			return ({ Players = env.players, ReplicatedStorage = { Shared = { Utils = { Log = {
				debug = function() end,
				info = function() end,
				warn = function(_scope: string, message: string) table.insert(env.warnings, message) end,
			} } } } })[name]
		end }
		local dataService: any = {}
		function dataService:GetData(player: any): any return env.data[player] end
		env.script = { Parent = { DataService = dataService,
			Parent = { Config = { RewardConfig = config or productionConfig }, Rewards = { RewardRules = RewardRules } } } }
		env.require = function(module: any): any return module end
		function env.player(name: string): any
			local p: any = { Name = name, Parent = env.players, attributes = { DataLoaded = true } }
			function p:GetAttribute(key: string): any return self.attributes[key] end
			env.data[p] = {
				Currencies = { Gold = 0, Gems = 0, SummonTickets = 0 },
				Progression = { CurrentZone = 1, HighestStage = 0, FirstClears = {} },
				Heroes = {}, Settings = { CombatSpeed = 1 },
			}
			return p
		end
		function env.start(): any
			env.service = createService(env)
			env.service:Init()
			env.service:Start()
			return env.service
		end
		return env
	end

	local FIRST = productionConfig.Stages["1-1"].FirstClearReward
	local REPEAT = productionConfig.Stages["1-1"].RepeatReward
	local function total(list: any, kind: string): number
		local n = 0
		for _, r in list do if r.Kind == kind then n += r.Amount end end
		return n
	end
	local function snapshot(d: any): string
		local keys = {}
		for k in d.Progression.FirstClears do table.insert(keys, k) end
		table.sort(keys)
		return `{d.Currencies.Gold}/{d.Currencies.Gems}/{d.Currencies.SummonTickets}/{table.concat(keys, ",")}`
	end

	test("production config valid; 1-1 first clear contains exactly +1 SummonTicket", function()
		local e = fixture()
		e.start()
		assert(#e.warnings == 0, table.concat(e.warnings, "; "))
		assert(total(FIRST, "SummonTicket") == 1, "first clear gives the initial summon ticket")
		assert(total(REPEAT, "SummonTicket") == 0, "replay never gives a summon ticket")
	end)

	test("1-2. first clear 1-1: FirstClears['1-1'] = true and +1 SummonTicket", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local result = s:HandleStageCompleted(p, 1, 1, 101)
		local d = e.data[p]
		assert(result and result.FirstClear == true)
		assert(d.Progression.FirstClears["1-1"] == true)
		assert(d.Currencies.SummonTickets == 1)
	end)

	test("3. first clear reward exactly as configured (currencies and returned list)", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local result = s:HandleStageCompleted(p, 1, 1, 1)
		local d = e.data[p]
		assert(d.Currencies.Gold == total(FIRST, "Gold") and d.Currencies.Gems == total(FIRST, "Gems"))
		assert(#result.Rewards == #FIRST)
		for i, r in FIRST do
			assert(result.Rewards[i].Kind == r.Kind and result.Rewards[i].Amount == r.Amount and result.Rewards[i].New == r.New)
		end
		result.Rewards[1].Amount = 999999
		assert(FIRST[1].Amount ~= 999999, "returned list never shares the config tables")
	end)

	test("4-5. replay: RepeatReward, no new First Clear ticket", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		s:HandleStageCompleted(p, 1, 1, 1)
		local before = table.clone(e.data[p].Currencies)
		local result = s:HandleStageCompleted(p, 1, 1, 2)
		local d = e.data[p]
		assert(result.FirstClear == false and #result.Rewards == #REPEAT)
		assert(d.Currencies.Gold == before.Gold + total(REPEAT, "Gold"))
		assert(d.Currencies.SummonTickets == 1, "still a single ticket after a replay")
	end)

	test("6. same completion handled twice: a single attribution in total", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		assert(s:HandleStageCompleted(p, 1, 1, 7))
		local after = snapshot(e.data[p])
		local again, reason = s:HandleStageCompleted(p, 1, 1, 7)
		assert(again == nil and reason == "completion déjà récompensée")
		assert(snapshot(e.data[p]) == after, "no FirstClearReward + RepeatReward for one victory")
	end)

	test("7. two real completions: First Clear then Repeat", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local first = s:HandleStageCompleted(p, 1, 1, 10)
		local second = s:HandleStageCompleted(p, 1, 1, 11)
		local third = s:HandleStageCompleted(p, 1, 1, 12)
		assert(first.FirstClear and not second.FirstClear and not third.FirstClear)
		assert(e.data[p].Currencies.SummonTickets == 1)
		assert(e.data[p].Currencies.Gold == total(FIRST, "Gold") + 2 * total(REPEAT, "Gold"))
	end)

	test("8. two players: independent First Clears, currencies and completion ids", function()
		local e = fixture()
		local s = e.start()
		local a, b = e.player("A"), e.player("B")
		assert(s:HandleStageCompleted(a, 1, 1, 1).FirstClear == true)
		local rb = s:HandleStageCompleted(b, 1, 1, 1)
		assert(rb and rb.FirstClear == true, "same completion id for another player is a different completion")
		assert(e.data[a].Currencies.SummonTickets == 1 and e.data[b].Currencies.SummonTickets == 1)
		s:HandleStageCompleted(a, 1, 1, 2)
		assert(e.data[b].Currencies.Gold == total(FIRST, "Gold"), "A's replay never touches B")
	end)

	test("9. data not loaded or player gone: refused, nothing changed", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local before = snapshot(e.data[p])
		p.attributes.DataLoaded = nil
		assert(select(2, s:HandleStageCompleted(p, 1, 1, 1)) == "données non chargées")
		p.attributes.DataLoaded = true
		local data = e.data[p]
		e.data[p] = nil
		assert(select(2, s:HandleStageCompleted(p, 1, 1, 2)) == "données non chargées")
		e.data[p] = data
		p.Parent = nil
		assert(select(2, s:HandleStageCompleted(p, 1, 1, 3)) == "données non chargées")
		assert(snapshot(data) == before)
	end)

	test("10. unknown stage or missing completion id: refused, nothing changed", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local before = snapshot(e.data[p])
		assert(select(2, s:HandleStageCompleted(p, 9, 9, 1)) == "stage inconnu")
		assert(select(2, s:HandleStageCompleted(p, 1, 1, nil)) == "completion inconnue")
		assert(snapshot(e.data[p]) == before)
	end)

	test("11. invalid config detected at start: no incorrect reward applied", function()
		local bad = { Stages = {
			["1-1"] = { FirstClearReward = { { Kind = "Diamond", Amount = 5 } }, RepeatReward = {} },
			["1-2"] = { FirstClearReward = { { Kind = "Gold", Amount = -10 } }, RepeatReward = {} },
			["1-3"] = { FirstClearReward = { { Kind = "Gold", Amount = 1.5 } }, RepeatReward = {} },
			["1-4"] = { FirstClearReward = { { Kind = "Gems", Amount = math.huge } }, RepeatReward = {} },
			["1-5"] = { FirstClearReward = { { Kind = "Gems", Amount = 0 / 0 } }, RepeatReward = {} },
			["1-6"] = { FirstClearReward = { { Kind = "Gold", Amount = 5 } } }, -- RepeatReward manquant
			["2-1"] = { FirstClearReward = { { Kind = "Gold", Amount = 5 } }, RepeatReward = { { Kind = "Gold", Amount = 1 } } },
		} }
		local e = fixture(bad)
		local s = e.start()
		assert(#e.warnings >= 6, "every invalid entry reported: " .. #e.warnings)
		local p = e.player("A")
		local before = snapshot(e.data[p])
		for stage = 1, 6 do
			assert(select(2, s:HandleStageCompleted(p, 1, stage, stage)) == "récompenses invalides", `1-{stage}`)
		end
		assert(snapshot(e.data[p]) == before, "no FirstClear, no currency")
		assert(s:HandleStageCompleted(p, 2, 1, 99).FirstClear == true, "valid entries still work")
		assert(#RewardRules.stageProblems(productionConfig.Stages["1-1"]) == 0)
	end)

	test("12. defeat: RewardService is never called; data untouched (contract checked in ZoneService)", function()
		local e = fixture()
		e.start()
		local p = e.player("A")
		assert(snapshot(e.data[p]) == "0/0/0/", "nothing granted without a victory")
	end)

	test("13. First Clear already saved (rejoin simulated): only RepeatReward", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		s:HandleStageCompleted(p, 1, 1, 1)
		local saved = e.data[p]
		-- départ : le serveur oublie ses completions ; la sauvegarde garde FirstClears et le ticket
		for _, fn in e.removing do fn(p) end
		local rejoined = e.player("A")
		e.data[rejoined] = saved
		local result = s:HandleStageCompleted(rejoined, 1, 1, 1000)
		assert(result.FirstClear == false and saved.Currencies.SummonTickets == 1)
		assert(saved.Progression.FirstClears["1-1"] == true)
	end)

	test("grant is synchronous: FirstClear marked before currencies, Progression fields untouched", function()
		local d = { Currencies = { Gold = 0, Gems = 0, SummonTickets = 0 },
			Progression = { CurrentZone = 1, HighestStage = 0, FirstClears = {} } }
		local entry = { FirstClearReward = { { Kind = "SummonTicket", Amount = 1 } }, RepeatReward = {} }
		local r1 = RewardRules.grant(d, "1-1", entry)
		local r2 = RewardRules.grant(d, "1-1", entry)
		assert(r1.FirstClear and not r2.FirstClear and d.Currencies.SummonTickets == 1)
		assert(d.Progression.HighestStage == 0 and d.Progression.CurrentZone == 1, "#9 does not invent progression")
	end)

	-- Mode Élite (#69) --------------------------------------------------------------------------

	test("#69 Elite completion: EliteFirstClears only, Normal FirstClears and currencies untouched", function()
		local e = fixture()
		local s = e.start()
		assert(#e.warnings == 0)
		local p = e.player("A")
		local d = e.data[p]
		d.Progression.FirstClears = { ["1-1"] = true, ["1-5"] = true }
		local result = s:HandleStageCompleted(p, 1, 1, 501, "Elite")
		assert(result and result.FirstClear == true and #result.Rewards == 0, "Elite first clear, no Elite economy yet")
		assert(d.Progression.EliteFirstClears["1-1"] == true)
		assert(d.Progression.FirstClears["1-1"] == true and d.Progression.FirstClears["1-2"] == nil, "Normal progression untouched")
		assert(d.Currencies.Gold == 0 and d.Currencies.Gems == 0 and d.Currencies.SummonTickets == 0)
		local again = s:HandleStageCompleted(p, 1, 1, 502, "Elite")
		assert(again and again.FirstClear == false, "Elite replay")
		assert(s:HandleStageCompleted(p, 1, 1, 502, "Elite") == nil, "same completion never twice")
	end)

	test("#69 Normal completion never touches EliteFirstClears; unknown mode refused; 1-6E unknown", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local d = e.data[p]
		s:HandleStageCompleted(p, 1, 1, 601)
		assert(d.Progression.FirstClears["1-1"] == true and (d.Progression.EliteFirstClears == nil or next(d.Progression.EliteFirstClears) == nil))
		local none, why = s:HandleStageCompleted(p, 1, 2, 602, "Hard")
		assert(none == nil and why == "mode inconnu")
		local six, whySix = s:HandleStageCompleted(p, 1, 6, 603, "Elite")
		assert(six == nil and whySix == "stage inconnu")
		assert(productionConfig.EliteStages["1-5"] and #productionConfig.EliteStages["1-5"].FirstClearReward == 0, "Elite rewards: architecture ready, empty")
	end)

	test("#80 ALPHA 0.0.2 provisional replay economy: normal, boss, Elite, no duplicate rewards",function()
		local e=fixture();local service=e.start();local p=e.player("Economy")
		local expected={Normal={0,1,1,2,5},Elite={2,2,2,2,10}}
		for mode,amounts in expected do
			for stage,amount in amounts do
				local session=1000+(if mode=="Elite" then 100 else 0)+stage*2
				service:HandleStageCompleted(p,1,stage,session,mode)
				local before=e.data[p].Currencies.SummonTickets
				local replay=service:HandleStageCompleted(p,1,stage,session+1,mode)
				assert(replay and not replay.FirstClear)
				assert(e.data[p].Currencies.SummonTickets==before+amount)
				assert(service:HandleStageCompleted(p,1,stage,session+1,mode)==nil)
				assert(e.data[p].Currencies.SummonTickets==before+amount)
			end
		end
	end)

	print(`RewardService: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{failed} RewardService test(s) failed`)
	end
end
