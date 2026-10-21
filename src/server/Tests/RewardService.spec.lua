--!strict
-- Hors du dossier Services : jamais exécuté par le bootstrap.
-- Exécute le vrai RewardService avec les vraies RewardRules et la vraie RewardConfig (ou une config
-- de test), et des doubles de DataService et des API Roblox utilisées.

return function(createService: any, RewardRules: any, productionConfig: any, loot: any)
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

	-- Générateur à graine (xorshift32) de même interface que Random (NextNumber / NextInteger).
	local function seeded(seed: number): any
		local s = bit32.bor((seed * 2654435761) % 4294967296, 1)
		local function nextBits(): number
			s = bit32.bxor(s, bit32.lshift(s, 13))
			s = bit32.bxor(s, bit32.rshift(s, 17))
			s = bit32.bxor(s, bit32.lshift(s, 5))
			return s
		end
		for _ = 1, 4 do nextBits() end
		local rng: any = {}
		function rng.NextNumber(_self: any): number return nextBits() / 4294967296 end
		function rng.NextInteger(self: any, min: number, max: number): number
			return min + math.floor(self:NextNumber() * (max - min + 1))
		end
		return rng
	end

	-- config : RewardConfig de test (nil = la vraie) ; lootConfig : LootConfig de test (nil = la vraie) ;
	-- seed : graine du Random du service. InventoryService est un double (le vrai est dans RewardFlow).
	local function fixture(config: any?, lootConfig: any?, seed: number?): any
		local env: any = { data = {}, warnings = {}, removing = {}, pushed = {}, ids = 0 }
		env.players = { PlayerRemoving = { Connect = function(_self: any, fn: any) table.insert(env.removing, fn) end } }
		env.game = { GetService = function(_self: any, name: string): any
			return ({ Players = env.players, ReplicatedStorage = { Shared = {
				Config = { ItemConfig = loot.ItemConfig, ResourceConfig = loot.ResourceConfig, RarityConfig = loot.RarityConfig },
				Utils = { Log = {
					debug = function() end,
					info = function() end,
					warn = function(_scope: string, message: string) table.insert(env.warnings, message) end,
				} } } } })[name]
		end }
		env.Random = { new = function(): any return seeded(seed or 1) end }
		local dataService: any = {}
		function dataService:GetData(player: any): any return env.data[player] end
		local inventoryService: any = {}
		function inventoryService:NewInstanceId(): string
			env.ids += 1
			return string.format("I_T%010d%04d_T", 1000, env.ids)
		end
		function inventoryService:Push(player: any) table.insert(env.pushed, player) end
		env.inventoryService = inventoryService
		env.script = { Parent = { DataService = dataService, InventoryService = inventoryService,
			Parent = { Config = { RewardConfig = config or productionConfig, LootConfig = lootConfig or loot.LootConfig },
				Rewards = { RewardRules = RewardRules }, Loot = { LootRules = loot.LootRules }, Inventory = { InventoryRules = loot.InventoryRules } } } }
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

	-- Loot (#72) -------------------------------------------------------------------------------------
	-- Valeurs de LootConfig = placeholders (ALPHA 0.0.2 PROVISOIRE) : on vérifie la plomberie et les invariants.

	local NORMAL_POOL = { "Commun", "PeuCommun", "Rare" }
	local ELITE_POOL = { "Rare", "Epique", "Legendaire" }
	local function rarityOf(itemId: string): string return loot.ItemConfig.Items[itemId].Rarity end
	local function count(t: any): number
		local n = 0
		for _ in t do n += 1 end
		return n
	end
	local function resourcesTotal(d: any): number
		local n = 0
		if d.Inventory then for _, amount in d.Inventory.Resources do n += amount end end
		return n
	end
	-- LootConfig de test dérivée de la vraie (même Zones, mêmes catalogues).
	local function lootWith(stages: any, elite: any?, cap: number?): any
		local config = table.clone(loot.LootConfig)
		config.Stages = stages
		config.EliteStages = elite or {}
		config.EquipmentCap = cap or 500
		return config
	end

	test("#72 production LootConfig loads without warning; Result.Loot has Items / Resources / Overflow", function()
		local e = fixture()
		local s = e.start()
		assert(#e.warnings == 0, table.concat(e.warnings, "; "))
		local p = e.player("A")
		local result = s:HandleStageCompleted(p, 1, 1, 1)
		assert(result and result.Loot and typeof(result.Loot.Items) == "table" and typeof(result.Loot.Resources) == "table" and result.Loot.Overflow == false)
		assert(#result.Rewards == #FIRST, "Rewards stay currencies: loot is never mixed in")
		for _, r in result.Rewards do assert(r.Kind == "Gold" or r.Kind == "Gems" or r.Kind == "SummonTicket") end
	end)

	test("#72 Normal victories: loot from the Normal table only, saved in Inventory exactly as announced", function()
		local e = fixture(nil, nil, 3)
		local s = e.start()
		local p = e.player("A")
		local d = e.data[p]
		local announcedItems, announcedUnits = 0, 0
		local allowed = {}
		for stage = 1, 5 do
			for _, r in loot.LootConfig.Stages[`1-{stage}`].Resources do allowed[r.ResourceId] = true end
		end
		for n = 1, 120 do
			local stage = 1 + n % 5
			local result = s:HandleStageCompleted(p, 1, stage, n)
			assert(result and result.Loot)
			for _, item in result.Loot.Items do
				announcedItems += 1
				assert(table.find(NORMAL_POOL, rarityOf(item.ItemId)), `{rarityOf(item.ItemId)} is not a Normal rarity`)
				assert(d.Inventory.Equipment[item.InstanceId].ItemId == item.ItemId and d.Inventory.Equipment[item.InstanceId].UpgradeLevel == 0)
			end
			for _, r in result.Loot.Resources do
				announcedUnits += r.Amount
				assert(allowed[r.ResourceId], r.ResourceId .. " not in a Normal table")
			end
		end
		assert(announcedItems > 0 and count(d.Inventory.Equipment) == announcedItems, "inventory == announced items")
		assert(resourcesTotal(d) == announcedUnits and announcedUnits > 0, "inventory == announced resources")
		for _, p2 in e.pushed do assert(p2 == p) end
		assert(#e.pushed == 120, "InventoryChanged pushed after each mutation")
	end)

	test("#72 Elite victories: loot from the Elite table only (Rare / Epique / Legendaire), more generous than Normal", function()
		local e = fixture(nil, nil, 4)
		local s = e.start()
		local p = e.player("A")
		local d = e.data[p]
		local items, units = 0, 0
		for n = 1, 120 do
			local result = s:HandleStageCompleted(p, 1, 1 + n % 5, n, "Elite")
			assert(result and result.Loot)
			for _, item in result.Loot.Items do
				items += 1
				assert(table.find(ELITE_POOL, rarityOf(item.ItemId)), rarityOf(item.ItemId))
			end
			for _, r in result.Loot.Resources do units += r.Amount end
		end
		local n = fixture(nil, nil, 4)
		local ns = n.start()
		local np = n.player("A")
		for k = 1, 120 do ns:HandleStageCompleted(np, 1, 1 + k % 5, k) end
		assert(items > count(n.data[np].Inventory.Equipment), "Elite drops more equipment than Normal")
		assert(units > resourcesTotal(n.data[np]), "Elite drops more resources than Normal")
		assert(count(d.Inventory.Equipment) == items and resourcesTotal(d) == units)
	end)

	test("#72 same completion twice: one loot only (inventory, payload and pushes unchanged)", function()
		local e = fixture(nil, nil, 5)
		local s = e.start()
		local p = e.player("A")
		local first = s:HandleStageCompleted(p, 1, 5, 77)
		local before = count(e.data[p].Inventory.Equipment) * 1000 + resourcesTotal(e.data[p])
		local pushes = #e.pushed
		local again, reason = s:HandleStageCompleted(p, 1, 5, 77)
		assert(first and again == nil and reason == "completion déjà récompensée")
		assert(count(e.data[p].Inventory.Equipment) * 1000 + resourcesTotal(e.data[p]) == before and #e.pushed == pushes)
		for _ = 1, 10 do s:HandleStageCompleted(p, 1, 5, 77, "Normal") end
		assert(count(e.data[p].Inventory.Equipment) * 1000 + resourcesTotal(e.data[p]) == before, "no replay ever doubles the loot")
	end)

	test("#72 1-5 Normal first clear: one guaranteed equipment (Normal pool) + resource_030; replay: no guarantee", function()
		-- Entrée sans tirage d'équipement aléatoire : seul le garanti compte. Config de test dérivée de la vraie 1-5.
		local entry = table.clone(loot.LootConfig.Stages["1-5"])
		entry.Equipment = nil
		local config = lootWith({ ["1-5"] = entry })
		for seed = 1, 40 do
			local e = fixture(nil, config, seed)
			local s = e.start()
			assert(#e.warnings == 0, table.concat(e.warnings, "; "))
			local p = e.player("A")
			local first = s:HandleStageCompleted(p, 1, 5, 1)
			assert(first and first.FirstClear == true and #first.Loot.Items == 1, "exactly one guaranteed item on the first clear")
			assert(table.find(NORMAL_POOL, rarityOf(first.Loot.Items[1].ItemId)))
			local horn = 0
			for _, r in first.Loot.Resources do if r.ResourceId == "resource_030" then horn = r.Amount end end
			assert(horn == 1, "Corne du Roi Orc x1")
			local replay = s:HandleStageCompleted(p, 1, 5, 2)
			assert(replay and replay.FirstClear == false and #replay.Loot.Items == 0, "no guarantee on a replay")
			local replayHorn = 0
			for _, r in replay.Loot.Resources do if r.ResourceId == "resource_030" then replayHorn = r.Amount end end
			assert(replayHorn == 1, "resource_030 on every 1-5 victory")
			assert(count(e.data[p].Inventory.Equipment) == 1 and e.data[p].Inventory.Resources.resource_030 == 2)
		end
	end)

	test("#72 Elite 1-5: resource_030 on every victory, no first-clear guarantee in Elite", function()
		local e = fixture(nil, nil, 9)
		local s = e.start()
		local p = e.player("A")
		for n = 1, 6 do
			local r = s:HandleStageCompleted(p, 1, 5, n, "Elite")
			local horn = 0
			for _, res in r.Loot.Resources do if res.ResourceId == "resource_030" then horn = res.Amount end end
			assert(horn == 1)
		end
		assert(e.data[p].Inventory.Resources.resource_030 == 6)
	end)

	test("#72 x1 / x2: the combat speed never changes the loot (same seed, same loot)", function()
		local results = {}
		for _, speed in { 1, 2 } do
			local e = fixture(nil, nil, 12)
			local s = e.start()
			local p = e.player("A")
			e.data[p].Settings.CombatSpeed = speed
			local parts = {}
			for n = 1, 30 do
				local r = s:HandleStageCompleted(p, 1, 1 + n % 5, n, if n % 2 == 0 then "Elite" else nil)
				for _, item in r.Loot.Items do table.insert(parts, item.ItemId) end
				for _, res in r.Loot.Resources do table.insert(parts, `{res.ResourceId}x{res.Amount}`) end
			end
			table.insert(results, table.concat(parts, ","))
		end
		assert(results[1] == results[2] and results[1] ~= "")
	end)

	test("#72 two players are independent (inventories, ids, completion ids)", function()
		local e = fixture(nil, nil, 21)
		local s = e.start()
		local a, b = e.player("A"), e.player("B")
		for n = 1, 40 do s:HandleStageCompleted(a, 1, 1 + n % 5, n, "Elite") end
		assert(e.data[b].Inventory == nil, "B untouched while A farms")
		local rb = s:HandleStageCompleted(b, 1, 1, 1, "Elite")
		assert(rb and rb.Loot, "same completion id for another player is a different completion")
		for id in e.data[b].Inventory.Equipment do assert(e.data[a].Inventory.Equipment[id] == nil, "instance ids never shared") end
		assert(count(e.data[a].Inventory.Equipment) > count(e.data[b].Inventory.Equipment))
	end)

	test("#72 rejoin keeps the inventory (data saved before display) and the loot goes on stacking", function()
		local e = fixture(nil, nil, 31)
		local s = e.start()
		local p = e.player("A")
		for n = 1, 30 do s:HandleStageCompleted(p, 1, 1 + n % 5, n, "Elite") end
		local saved = e.data[p]
		local equipment, units = count(saved.Inventory.Equipment), resourcesTotal(saved)
		for _, fn in e.removing do fn(p) end
		local back = e.player("A")
		e.data[back] = saved
		assert(count(saved.Inventory.Equipment) == equipment and resourcesTotal(saved) == units)
		s:HandleStageCompleted(back, 1, 5, 1000, "Elite")
		assert(count(saved.Inventory.Equipment) >= equipment and resourcesTotal(saved) > units)
	end)

	test("#72 plafond: beyond the cap no equipment is created (Overflow), resources and currencies still granted", function()
		local entry = { Equipment = { Chance = 1, Rarities = { { Rarity = "Rare", Weight = 1 } } },
			Resources = { { ResourceId = "resource_011", Chance = 1, Min = 2, Max = 2 } } }
		local e = fixture(nil, lootWith({ ["1-1"] = entry }, { ["1-1"] = entry }, 2), 1)
		local s = e.start()
		assert(#e.warnings == 0, table.concat(e.warnings, "; "))
		local p = e.player("A")
		local r1 = s:HandleStageCompleted(p, 1, 1, 1)
		local r2 = s:HandleStageCompleted(p, 1, 1, 2)
		local r3 = s:HandleStageCompleted(p, 1, 1, 3)
		assert(#r1.Loot.Items == 1 and #r2.Loot.Items == 1 and r1.Loot.Overflow == false and r2.Loot.Overflow == false)
		assert(#r3.Loot.Items == 0 and r3.Loot.Overflow == true, "third item refused")
		assert(count(e.data[p].Inventory.Equipment) == 2)
		assert(#r3.Loot.Resources == 1 and r3.Loot.Resources[1].Amount == 2 and e.data[p].Inventory.Resources.resource_011 == 6, "resources still granted")
		assert(e.data[p].Currencies.Gold == total(FIRST, "Gold") + 2 * total(REPEAT, "Gold"), "currencies still granted")
	end)

	test("#72 invalid LootConfig: warning, no loot, First Clear and currencies untouched", function()
		local bad = lootWith({ ["1-1"] = { Equipment = { Chance = 1, Rarities = { { Rarity = "Mythique", Weight = 1 } } } } })
		local e = fixture(nil, bad)
		local s = e.start()
		assert(#e.warnings >= 1, "reported at Init")
		local p = e.player("A")
		local result = s:HandleStageCompleted(p, 1, 1, 1)
		assert(result and result.FirstClear == true and result.Loot == nil)
		assert(e.data[p].Progression.FirstClears["1-1"] == true and e.data[p].Currencies.Gold == total(FIRST, "Gold") and e.data[p].Currencies.SummonTickets == 1)
		assert(e.data[p].Inventory == nil and #e.pushed == 0, "nothing written")
	end)

	test("#72 a loot error at runtime never blocks First Clear nor currencies", function()
		local e = fixture(nil, nil, 2)
		local s = e.start()
		local p = e.player("A")
		function e.inventoryService:NewInstanceId(): string error("boom") end
		local failures = 0
		for n = 1, 60 do
			local result = s:HandleStageCompleted(p, 1, 5, n, "Elite")
			assert(result, "the victory is still rewarded")
			if result.Loot == nil then failures += 1 end
		end
		assert(failures > 0 and #e.warnings > 0)
		local first = fixture(nil, nil, 2)
		local fs = first.start()
		local fp = first.player("A")
		function first.inventoryService:NewInstanceId(): string error("boom") end
		local r = fs:HandleStageCompleted(fp, 1, 5, 1)
		assert(r and r.FirstClear == true and first.data[fp].Progression.FirstClears["1-5"] == true, "First Clear recorded")
		assert(r.Loot == nil and #first.warnings >= 1, "loot lost, reported")
		local again = fs:HandleStageCompleted(fp, 1, 5, 1)
		assert(again == nil, "and the completion is consumed: never looted twice")
	end)

	test("#72 stage without a loot table (future zones): no loot, no error, rewards unchanged", function()
		local rewards = { Stages = { ["1-1"] = productionConfig.Stages["1-1"], ["2-1"] = { FirstClearReward = { { Kind = "Gold", Amount = 5 } }, RepeatReward = {} } }, EliteStages = {} }
		local e = fixture(rewards)
		local s = e.start()
		assert(#e.warnings == 0)
		local p = e.player("A")
		local result = s:HandleStageCompleted(p, 2, 1, 1)
		assert(result and result.FirstClear == true and result.Loot == nil and e.data[p].Currencies.Gold == 5)
		assert(e.data[p].Inventory == nil and #e.warnings == 0, "no error, nothing written")
		local elite = s:HandleStageCompleted(p, 1, 1, 2, "Elite")
		assert(elite == nil, "no Elite reward entry in this test config: stage unknown")
	end)

	test("#72 old v4 profile (no Inventory): created on first loot, other data untouched", function()
		local e = fixture(nil, nil, 6)
		local s = e.start()
		local p = e.player("A")
		local d = e.data[p]
		assert(d.Inventory == nil)
		s:HandleStageCompleted(p, 1, 1, 1)
		assert(typeof(d.Inventory) == "table" and typeof(d.Inventory.Equipment) == "table" and typeof(d.Inventory.Resources) == "table")
		assert(d.Heroes ~= nil and d.Settings.CombatSpeed == 1 and d.Progression.FirstClears["1-1"] == true)
	end)

	test("#12 #72 no client input reaches the loot: HandleStageCompleted takes only server identities", function()
		-- Le service n'expose aucun remote ; un client ne peut ni choisir ItemId / ResourceId / quantité / rareté
		-- ni rejouer une completion. Toute valeur étrangère en 3e / 6e argument est ignorée ou refusée.
		local e = fixture(nil, nil, 8)
		local s = e.start()
		local p = e.player("A")
		for _, forged in { { ItemId = "item_100" }, "item_100", { Rarity = "Transcendant" }, 1e9 } :: { any } do
			local r = s:HandleStageCompleted(p, 1, 1, forged, nil)
			assert(r == nil or r.Loot == nil or #r.Loot.Items == 0 or rarityOf(r.Loot.Items[1].ItemId) ~= "Transcendant")
		end
		for _, item in e.data[p].Inventory and e.data[p].Inventory.Equipment or {} do
			assert(item.ItemId ~= "item_100" and rarityOf(item.ItemId) ~= "Transcendant", "only the server table decides")
		end
	end)

	print(`RewardService: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{failed} RewardService test(s) failed`)
	end
end
