--!strict
-- Hors du dossier Services : jamais exécuté par le bootstrap.
-- Vérifie la vraie ItemConfig contre la répartition de docs/ITEMS.md § 2 et la vraie RarityConfig.

return function(itemConfig: any, rarityConfig: any)
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

	-- docs/ITEMS.md § 2.
	local BY_RARITY = {
		Commun = 4, PeuCommun = 6, Rare = 10, Epique = 14, Legendaire = 18,
		Mythique = 18, Maudit = 12, Supreme = 8, Calamite = 6, Transcendant = 4,
	}
	local BY_SLOT = { weapon = 26, relic = 21, accessory = 17, armor = 15, helmet = 14, boots = 5, gloves = 2 }

	test("100 items item_001..item_100, Index and lookup consistent", function()
		assert(#itemConfig.Ordered == 100, `{#itemConfig.Ordered} items`)
		local count = 0
		for _ in itemConfig.Items do count += 1 end
		assert(count == 100, `{count} ItemIds`)
		for index, info in itemConfig.Ordered do
			assert(info.Index == index, info.Id)
			assert(info.Id == string.format("item_%03d", index), info.Id)
			assert(itemConfig.Items[info.Id] == info, info.Id)
			assert(itemConfig.slotName(index) == string.format("Item_%03d", index))
		end
		assert(itemConfig.slotName(37) == "Item_037")
	end)

	test("rarities exist in RarityConfig, ascend in contiguous tiers, match ITEMS.md counts", function()
		local counts = {}
		local lastRank = 0
		for _, info in itemConfig.Ordered do
			local rank = rarityConfig.Rank[info.Rarity]
			assert(rank, `{info.Id}: rareté inconnue {info.Rarity}`)
			assert(rank >= lastRank, `{info.Id}: rareté hors ordre`)
			lastRank = rank
			counts[info.Rarity] = (counts[info.Rarity] or 0) + 1
		end
		for rarity, expected in BY_RARITY do
			assert(counts[rarity] == expected, `{rarity}: {counts[rarity]} au lieu de {expected}`)
		end
	end)

	test("slot types are known and match ITEMS.md counts", function()
		local counts = {}
		for _, info in itemConfig.Ordered do
			assert(itemConfig.SlotTypeNames[info.SlotType], `{info.Id}: emplacement inconnu {info.SlotType}`)
			counts[info.SlotType] = (counts[info.SlotType] or 0) + 1
		end
		for slotType, expected in BY_SLOT do
			assert(counts[slotType] == expected, `{slotType}: {counts[slotType]} au lieu de {expected}`)
		end
		assert(#itemConfig.SlotTypes == 7)
	end)

	test("names are set and unique; icons are nil or an asset id", function()
		local seen = {}
		for _, info in itemConfig.Ordered do
			assert(type(info.Name) == "string" and info.Name ~= "", info.Id)
			assert(not seen[info.Name], `{info.Id}: nom en double {info.Name}`)
			seen[info.Name] = true
			assert(info.Icon == nil or string.match(info.Icon, "^rbxassetid://%d+$"), `{info.Id}: icône {info.Icon}`)
		end
	end)

	test("catalogue is frozen", function()
		assert(table.isfrozen(itemConfig.Items) and table.isfrozen(itemConfig.Ordered))
		assert(table.isfrozen(itemConfig.Ordered[1]))
		assert(not pcall(function() itemConfig.Ordered[1].Name = "x" end))
	end)

	print(`ItemConfig: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{failed} ItemConfig test(s) failed`)
	end
end
