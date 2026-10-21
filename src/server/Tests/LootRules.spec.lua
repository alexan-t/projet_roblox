--!strict
-- Hors du dossier Services : jamais exécuté par le bootstrap.
-- Règles pures du loot (#72) avec la VRAIE LootConfig et les VRAIS catalogues. Les valeurs de LootConfig sont
-- des placeholders (ALPHA 0.0.2 PROVISOIRE) : ces tests vérifient les INVARIANTS de zone, de format et de
-- déterminisme, jamais un équilibrage.

return function(LootRules: any, LootConfig: any, catalogs: any)
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

	-- Générateur à graine (xorshift32), même interface que Random.
	local function seeded(seed: number): any
		-- Mélange de la graine (les petites graines donneraient de petites premières valeurs), jamais 0.
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
	local function ctx(firstClear: boolean?): any return { FirstClear = firstClear, Catalogs = catalogs } end
	local function rank(rarity: string): number return catalogs.Rarity.Rank[rarity] end
	local function keys(t: any): { string }
		local out = {}
		for k in t do table.insert(out, k) end
		table.sort(out)
		return out
	end
	local function rarityOf(itemId: string): string return catalogs.Item.Items[itemId].Rarity end
	local function inSet(list: { string }, value: string): boolean return table.find(list, value) ~= nil end
	local function dump(r: any): string
		local parts = {}
		for _, i in r.Items do table.insert(parts, i.ItemId) end
		for _, i in r.Resources do table.insert(parts, `{i.ResourceId}x{i.Amount}`) end
		return table.concat(parts, ",")
	end
	local ZONE = LootConfig.Zones[1]
	local ALL = { { "Stages", "Normal", ZONE.Normal }, { "EliteStages", "Elite", ZONE.Elite } }

	test("production LootConfig is valid; tables exist for 1-1..1-5 in Normal and Elite", function()
		local problems = LootRules.problems(LootConfig, catalogs)
		assert(#problems == 0, table.concat(problems, " | "))
		for _, section in ALL do
			local list = keys(LootConfig[section[1]])
			assert(table.concat(list, ",") == "1-1,1-2,1-3,1-4,1-5", section[1] .. ": " .. table.concat(list, ","))
		end
		assert(LootConfig.EquipmentCap == 500)
	end)

	test("zone 1 rarity invariants: Normal in {Commun, PeuCommun, Rare}, Elite in {Rare, Epique, Legendaire}", function()
		assert(table.concat(ZONE.Normal, ",") == "Commun,PeuCommun,Rare" and table.concat(ZONE.Elite, ",") == "Rare,Epique,Legendaire")
		for _, section in ALL do
			for key, entry in LootConfig[section[1]] do
				for _, list in { entry.Equipment and entry.Equipment.Rarities, entry.FirstClearEquipment and entry.FirstClearEquipment.Rarities } :: { any } do
					for _, r in list do assert(inSet(section[3], r.Rarity), `{section[1]} {key}: {r.Rarity}`) end
				end
			end
		end
	end)

	test("no rarity above Legendaire can ever be rolled in Zone 1 (25 000 rolls, Normal and Elite, first clear included)", function()
		local ceiling = rank("Legendaire")
		for _, section in ALL do
			for key, entry in LootConfig[section[1]] do
				for seed = 1, 2500 do
					local rolled = LootRules.roll(entry, seeded(seed * 7919), ctx(seed % 2 == 0))
					for _, drop in rolled.Items do
						local r = rarityOf(drop.ItemId)
						assert(rank(r) <= ceiling, `{key}: {r}`)
						assert(inSet(section[3], r), `{section[1]} {key}: {r} outside the zone pool`)
					end
				end
			end
		end
	end)

	test("zone 1 resource invariants: only slime / horde, catalogue ids, 010 and 020 excluded, no duplicate", function()
		for _, section in ALL do
			for key, entry in LootConfig[section[1]] do
				local seen = {}
				for _, drop in entry.Resources do
					local info = catalogs.Resource.Resources[drop.ResourceId]
					assert(info, `{key}: {drop.ResourceId} not in ResourceConfig`)
					assert(info.Family == "slime" or info.Family == "horde", `{key}: {drop.ResourceId} family {info.Family}`)
					assert(drop.ResourceId ~= "resource_010" and drop.ResourceId ~= "resource_020", `{key}: boss trophy of an absent boss`)
					assert(not seen[drop.ResourceId], "duplicate " .. drop.ResourceId)
					seen[drop.ResourceId] = true
					assert(drop.Chance > 0 and drop.Chance <= 1 and drop.Min >= 1 and drop.Max >= drop.Min)
				end
			end
		end
	end)

	test("item ids and rarities come from the existing catalogues (nothing invented)", function()
		for _, section in ALL do
			for _, entry in LootConfig[section[1]] do
				for _, list in { entry.Equipment and entry.Equipment.Rarities, entry.FirstClearEquipment and entry.FirstClearEquipment.Rarities } :: { any } do
					for _, r in list do
						assert(catalogs.Rarity.Rank[r.Rarity], r.Rarity)
						assert(#(function(): { any } local pool = {} for _, i in catalogs.Item.Ordered do if i.Rarity == r.Rarity then table.insert(pool, i) end end return pool end)() > 0)
					end
				end
			end
		end
		assert(#catalogs.Item.Ordered == 100 and #catalogs.Resource.Ordered == 60, "catalogues untouched")
	end)

	test("determinism: the same seed gives the same loot, another seed another one", function()
		local entry = LootConfig.Stages["1-5"]
		local a = dump(LootRules.roll(entry, seeded(42), ctx(true)))
		local b = dump(LootRules.roll(entry, seeded(42), ctx(true)))
		assert(a == b and a ~= "")
		local different = false
		for seed = 43, 60 do
			if dump(LootRules.roll(entry, seeded(seed), ctx(true))) ~= a then different = true end
		end
		assert(different)
		for seed = 1, 20 do
			local one = dump(LootRules.roll(LootConfig.EliteStages["1-3"], seeded(seed), ctx(false)))
			local two = dump(LootRules.roll(LootConfig.EliteStages["1-3"], seeded(seed), ctx(false)))
			assert(one == two)
		end
	end)

	test("roll never mutates the config and returns fresh tables", function()
		local entry = LootConfig.Stages["1-2"]
		local before = #entry.Resources
		local r = LootRules.roll(entry, seeded(5), ctx(false))
		r.Resources[1] = nil
		r.Items[1] = nil
		assert(#entry.Resources == before and LootConfig.Stages["1-2"] == entry)
	end)

	test("amounts stay within Min..Max, resources come out in catalogue order without duplicate", function()
		for _, section in ALL do
			for key, entry in LootConfig[section[1]] do
				local bounds = {}
				for _, d in entry.Resources do bounds[d.ResourceId] = d end
				for seed = 1, 400 do
					local rolled = LootRules.roll(entry, seeded(seed), ctx(false))
					local last = 0
					for _, drop in rolled.Resources do
						local d = bounds[drop.ResourceId]
						assert(d and drop.Amount >= d.Min and drop.Amount <= d.Max and drop.Amount % 1 == 0, `{key} {drop.ResourceId}`)
						local index = catalogs.Resource.Resources[drop.ResourceId].Index
						assert(index > last, "catalogue order, no duplicate")
						last = index
					end
				end
			end
		end
	end)

	test("1-5 Normal: one guaranteed equipment on the FIRST clear only, drawn in the Normal pool", function()
		local entry = LootConfig.Stages["1-5"]
		assert(entry.FirstClearEquipment, "guarantee configured (PROVISOIRE)")
		local replayWithout = 0
		for seed = 1, 500 do
			local first = LootRules.roll(entry, seeded(seed), ctx(true))
			assert(#first.Items >= 1, "at least one equipment on the first clear (seed " .. seed .. ")")
			assert(inSet(ZONE.Normal, rarityOf(first.Items[1].ItemId)))
			if #LootRules.roll(entry, seeded(seed), ctx(false)).Items == 0 then replayWithout += 1 end
		end
		assert(replayWithout > 0, "a replay is not guaranteed to drop equipment")
		for key, other in LootConfig.Stages do
			if key ~= "1-5" then assert(other.FirstClearEquipment == nil, key .. " has no guarantee") end
		end
		for key, other in LootConfig.EliteStages do assert(other.FirstClearEquipment == nil, "Elite " .. key .. " has no guarantee") end
	end)

	test("resource_030 (Corne du Roi Orc): every 1-5 Normal and 1-5 Elite victory, nowhere else", function()
		for seed = 1, 300 do
			for _, entry in { LootConfig.Stages["1-5"], LootConfig.EliteStages["1-5"] } do
				local found = false
				for _, d in LootRules.roll(entry, seeded(seed), ctx(seed % 2 == 0)).Resources do
					if d.ResourceId == "resource_030" then found = d.Amount == 1 end
				end
				assert(found, "resource_030 x1, seed " .. seed)
			end
		end
		for _, section in ALL do
			for key, entry in LootConfig[section[1]] do
				for _, d in entry.Resources do
					assert(d.ResourceId ~= "resource_030" or key == "1-5", "resource_030 outside 1-5: " .. key)
				end
			end
		end
	end)

	test("resource_029 (Défense d'Orc): a real chance in 1-5 Normal and Elite only", function()
		for _, section in ALL do
			for key, entry in LootConfig[section[1]] do
				for _, d in entry.Resources do
					if d.ResourceId == "resource_029" then assert(key == "1-5" and d.Chance > 0 and d.Chance < 1) end
				end
			end
		end
		local hits, runs = 0, 2000
		for seed = 1, runs do
			for _, d in LootRules.roll(LootConfig.Stages["1-5"], seeded(seed), ctx(false)).Resources do
				if d.ResourceId == "resource_029" then hits += 1 end
			end
		end
		assert(hits > 0 and hits < runs)
	end)

	test("Normal and Elite use distinct tables; 1-5 Elite is the best Zone 1 source of equipment", function()
		local best = LootConfig.EliteStages["1-5"].Equipment.Chance
		for key, entry in LootConfig.Stages do
			assert(entry ~= LootConfig.EliteStages[key], key .. ": tables must be distinct")
			assert(LootConfig.EliteStages[key].Equipment.Chance > entry.Equipment.Chance, key .. ": Elite chance > Normal chance")
		end
		for key, entry in LootConfig.EliteStages do assert(entry.Equipment.Chance <= best, key) end
		-- les ressources aussi : espérance de quantité d'une victoire 1-5 Élite >= 1-5 Normal
		local function expected(entry: any): number
			local n = 0
			for _, d in entry.Resources do n += d.Chance * (d.Min + d.Max) / 2 end
			return n
		end
		assert(expected(LootConfig.EliteStages["1-5"]) > expected(LootConfig.Stages["1-5"]))
	end)

	test("equipment: rarity first (weights), then the item uniformly inside the rarity", function()
		local entry = { Equipment = { Chance = 1, Rarities = { { Rarity = "Rare", Weight = 1 } } } }
		local counts, rares = {}, {}
		for _, info in catalogs.Item.Ordered do if info.Rarity == "Rare" then table.insert(rares, info.Id) end end
		local rng = seeded(2026)
		local total = 6000
		for _ = 1, total do
			local rolled = LootRules.roll(entry, rng, ctx(false))
			assert(#rolled.Items == 1)
			counts[rolled.Items[1].ItemId] = (counts[rolled.Items[1].ItemId] or 0) + 1
		end
		for _, id in rares do
			local share = (counts[id] or 0) / total
			assert(share > 0.07 and share < 0.13, `{id} share {share}`)
		end
		local weighted = { Equipment = { Chance = 1, Rarities = { { Rarity = "Commun", Weight = 3 }, { Rarity = "Rare", Weight = 1 } } } }
		local common = 0
		for _ = 1, total do
			if rarityOf(LootRules.roll(weighted, rng, ctx(false)).Items[1].ItemId) == "Commun" then common += 1 end
		end
		assert(common / total > 0.70 and common / total < 0.80, `weights 3:1 -> {common / total}`)
	end)

	test("equipment chance is respected (0.5 over 4000 rolls) and Chance 1 never fails", function()
		local half = { Equipment = { Chance = 0.5, Rarities = { { Rarity = "Commun", Weight = 1 } } } }
		local hits = 0
		local rng = seeded(7)
		for _ = 1, 4000 do hits += #LootRules.roll(half, rng, ctx(false)).Items end
		assert(hits > 1800 and hits < 2200, tostring(hits))
		local sure = { Resources = { { ResourceId = "resource_011", Chance = 1, Min = 2, Max = 2 } } }
		for seed = 1, 100 do
			local r = LootRules.roll(sure, seeded(seed), ctx(false))
			assert(#r.Resources == 1 and r.Resources[1].Amount == 2 and #r.Items == 0)
		end
	end)

	test("precise items (Items) are rolled with their own chance and listed by the preview", function()
		local entry = { Items = { { ItemId = "item_015", Chance = 1 }, { ItemId = "item_011", Chance = 0.25 } },
			Resources = { { ResourceId = "resource_011", Chance = 0.5, Min = 1, Max = 3 } } }
		local r = LootRules.roll(entry, seeded(3), ctx(false))
		assert(r.Items[1].ItemId == "item_015")
		local config = { Stages = { ["1-1"] = entry }, EliteStages = {} }
		local d = LootRules.preview(config, "Normal", "1-1")
		assert(d and #d == 3 and d[1].Kind == "Resource" and d[2].Kind == "Item" and d[2].Id == "item_015" and d[2].Chance == 1 and d[3].Id == "item_011" and d[3].Chance == 0.25)
	end)

	test("preview: real resource chances only, no random equipment line, Elite reads EliteStages", function()
		local normal = LootRules.preview(LootConfig, "Normal", "1-5")
		local elite = LootRules.preview(LootConfig, "Elite", "1-5")
		assert(normal and elite and #normal == #LootConfig.Stages["1-5"].Resources and #elite == #LootConfig.EliteStages["1-5"].Resources)
		for i, drop in normal do
			local source = LootConfig.Stages["1-5"].Resources[i]
			assert(drop.Kind == "Resource" and drop.Id == source.ResourceId and drop.Chance == source.Chance and drop.Min == source.Min and drop.Max == source.Max)
			assert(drop.Chance > 0 and drop.Chance <= 1)
		end
		local has030 = false
		for _, drop in elite do
			assert(drop.Kind == "Resource", "random equipment is not listed")
			if drop.Id == "resource_030" then has030 = drop.Chance == 1 end
		end
		assert(has030)
		assert(LootRules.preview(LootConfig, "Normal", "9-9") == nil and LootRules.preview(LootConfig, nil, "2-1") == nil, "no table = no preview")
		assert(LootRules.preview(nil, "Normal", "1-1") == nil)
		-- mode nil = Normal
		assert(#(LootRules.preview(LootConfig, nil, "1-1") :: any) == #LootConfig.Stages["1-1"].Resources)
	end)

	-- Validation : la config invalide est détectée ------------------------------------------------

	local function withEntry(entry: any, mode: string?): any
		local config = table.clone(LootConfig)
		if mode == "Elite" then
			config.EliteStages = { ["1-1"] = entry }
			config.Stages = {}
		else
			config.Stages = { ["1-1"] = entry }
			config.EliteStages = {}
		end
		return config
	end
	local function bad(entry: any, mode: string?, expect: string?)
		local problems = LootRules.problems(withEntry(entry, mode), catalogs)
		assert(#problems > 0, "invalid entry accepted")
		if expect then
			local found = false
			for _, p in problems do if string.find(p, expect, 1, true) then found = true end end
			assert(found, `expected "{expect}" in: {table.concat(problems, " | ")}`)
		end
	end
	local function res(id: string, chance: number?, min: number?, max: number?): any
		return { ResourceId = id, Chance = chance or 0.5, Min = min or 1, Max = max or 1 }
	end

	test("problems: rarities above Legendaire or outside the zone pool are refused (even if the zone rules were widened)", function()
		for _, rarity in { "Mythique", "Maudit", "Supreme", "Calamite", "Transcendant" } do
			bad({ Equipment = { Chance = 0.5, Rarities = { { Rarity = rarity, Weight = 1 } } } }, "Elite", "dépasse Legendaire")
			local widened = withEntry({ Equipment = { Chance = 0.5, Rarities = { { Rarity = rarity, Weight = 1 } } } }, "Elite")
			widened.Zones = { [1] = table.clone(ZONE) }
			widened.Zones[1].Elite = { "Rare", "Epique", "Legendaire", rarity }
			assert(#LootRules.problems(widened, catalogs) > 0, "hard ceiling independent of the config: " .. rarity)
		end
		bad({ Equipment = { Chance = 0.5, Rarities = { { Rarity = "Epique", Weight = 1 } } } }, "Normal", "hors des raretés autorisées")
		bad({ Equipment = { Chance = 0.5, Rarities = { { Rarity = "Commun", Weight = 1 } } } }, "Elite", "hors des raretés autorisées")
		bad({ FirstClearEquipment = { Rarities = { { Rarity = "Legendaire", Weight = 1 } } } }, "Normal", "hors des raretés autorisées")
		bad({ Equipment = { Chance = 0.5, Rarities = { { Rarity = "Banal", Weight = 1 } } } }, "Normal", "rareté inconnue")
		bad({ Items = { { ItemId = "item_100", Chance = 1 } } }, "Elite", "dépasse Legendaire")
	end)

	test("problems: unknown / out-of-zone / excluded resources and bad numbers are refused", function()
		bad({ Resources = { res("resource_061") } }, "Normal", "ResourceId inconnu")
		bad({ Resources = { res("resource_001") } }, "Normal", "famille foret")
		bad({ Resources = { res("resource_035") } }, "Elite", "famille mine")
		bad({ Resources = { res("resource_010") } }, "Normal", "")
		bad({ Resources = { res("resource_020") } }, "Elite", "exclu du loot")
		bad({ Resources = { res("resource_011"), res("resource_011") } }, "Normal", "en double")
		for _, c in { 0, -0.1, 1.5, 0 / 0, math.huge } do bad({ Resources = { res("resource_011", c) } }, "Normal", "Chance") end
		bad({ Resources = { res("resource_011", 0.5, 0, 1) } }, "Normal", "Min / Max")
		bad({ Resources = { res("resource_011", 0.5, 3, 2) } }, "Normal", "Min / Max")
		bad({ Resources = { res("resource_011", 0.5, 1.5, 2) } }, "Normal", "Min / Max")
		bad({ Resources = { res("resource_011", 0.5, 1, 1e6) } }, "Normal", "Min / Max")
		bad({ Equipment = { Chance = 0.5, Rarities = { { Rarity = "Commun", Weight = 0 } } } }, "Normal", "Weight")
		bad({ Equipment = { Chance = 0.5, Rarities = { { Rarity = "Commun", Weight = 1.5 } } } }, "Normal", "Weight")
		bad({ Equipment = { Chance = 0.5, Rarities = {} } }, "Normal", "liste de raretés")
		bad({ Equipment = { Chance = 2, Rarities = { { Rarity = "Commun", Weight = 1 } } } }, "Normal", "Chance")
		bad({ Equipment = { Chance = 0.5, Rarities = { { Rarity = "Commun", Weight = 1 }, { Rarity = "Commun", Weight = 1 } } } }, "Normal", "en double")
		bad({ Items = { { ItemId = "item_000", Chance = 1 } } }, "Normal", "ItemId inconnu")
		bad("x", "Normal", "entrée attendue")
	end)

	test("problems: zones without a rule, bad keys, bad cap and non-table configs are refused", function()
		local zone2 = table.clone(LootConfig)
		zone2.Stages = { ["2-1"] = { Resources = { res("resource_011") } } }
		zone2.EliteStages = {}
		local p = LootRules.problems(zone2, catalogs)
		assert(#p == 1 and string.find(p[1], "sans règle", 1, true), p[1])
		local badKey = table.clone(LootConfig)
		badKey.Stages = { ["one"] = { Resources = {} } }
		badKey.EliteStages = {}
		assert(#LootRules.problems(badKey, catalogs) > 0)
		for _, cap in { 0, -1, 1.5, "500", 0 / 0 } :: { any } do
			local c = table.clone(LootConfig)
			c.EquipmentCap = cap
			assert(#LootRules.problems(c, catalogs) > 0, tostring(cap))
		end
		assert(#LootRules.problems(nil, catalogs) > 0 and #LootRules.problems("x", catalogs) > 0)
		local noElite = table.clone(LootConfig)
		noElite.EliteStages = nil
		assert(#LootRules.problems(noElite, catalogs) > 0)
	end)

	print(`LootRules: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{failed} LootRules test(s) failed`)
	end
end
