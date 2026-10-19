--!strict
-- Hors du dossier Services : jamais exécuté par le bootstrap.
-- Côté CLIENT de l'issue #72 (pas de logique serveur) : modèles purs Shared.Sacoche.InventoryModel (Sacoche >
-- Équipement / Ressources) et Shared.Sacoche.LootModel (écran de fin), avec les VRAIS catalogues ItemConfig /
-- ResourceConfig / RarityConfig et les mesures réelles d'UITheme.Pack : tools/test-sacoche.ps1.

return function(Inventory: any, Loot: any, ItemConfig: any, ResourceConfig: any, RarityConfig: any, Pack: any)
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
	local function rankOf(id: string?): number
		return if id then RarityConfig.Rank[id] or 1 else 1
	end
	local function v2(x: number, y: number): any
		return { X = x, Y = y }
	end
	local R = Pack.Reward
	local S = Pack.Sacoche

	local itemCtx = { Items = ItemConfig.Items, RankOf = rankOf, SlotNames = ItemConfig.SlotTypeNames }
	local function ctx(extra: any?): any
		local c = { Items = ItemConfig.Items, RankOf = rankOf, SlotNames = ItemConfig.SlotTypeNames, Slot = "all" }
		for k, v in extra or {} do c[k] = v end
		return c
	end
	local resourceCtx = { Resources = ResourceConfig.Resources, Families = ResourceConfig.Families }
	local function ids(list: any, key: string): string
		local out = {}
		for _, entry in list do table.insert(out, entry[key]) end
		return table.concat(out, ",")
	end
	local function hasKeyLike(tbl: any, pattern: string): boolean
		for key, value in tbl do
			if typeof(key) == "string" and string.find(string.lower(key), pattern) then return true end
			if typeof(value) == "table" and hasKeyLike(value, pattern) then return true end
		end
		return false
	end

	------------------------------------------------------------------ sanitize

	test("sanitize: non-table -> nil; malformed entries are dropped, never repaired", function()
		assert(Inventory.sanitize(nil) == nil and Inventory.sanitize("x") == nil and Inventory.sanitize(5) == nil)
		local view = Inventory.sanitize({
			Equipment = { { InstanceId = "I_T1", ItemId = "item_015", UpgradeLevel = 0 }, { InstanceId = 5, ItemId = "item_001" }, "bad", { ItemId = "item_002" } },
			Resources = {
				{ ResourceId = "resource_011", Amount = 3 }, { ResourceId = "resource_012", Amount = 0 }, { ResourceId = "resource_013", Amount = -2 },
				{ ResourceId = "resource_014", Amount = "9" }, { ResourceId = "resource_015", Amount = 0 / 0 }, { Amount = 4 }, { ResourceId = "resource_016", Amount = 2.9 },
			},
			Count = 1, Cap = 500,
		})
		assert(view ~= nil)
		assert(#view.Equipment == 1 and view.Equipment[1].InstanceId == "I_T1")
		assert(ids(view.Resources, "ResourceId") == "resource_011,resource_016", ids(view.Resources, "ResourceId"))
		assert(view.Resources[2].Amount == 2, "fractional amounts are floored")
		assert(view.Count == 1 and view.Cap == 500)
	end)

	test("sanitize: missing tables give an empty (not nil) view; Count falls back to the equipment size", function()
		local view = Inventory.sanitize({})
		assert(view ~= nil and #view.Equipment == 0 and #view.Resources == 0 and view.Count == 0 and view.Cap == nil)
		local two = Inventory.sanitize({ Equipment = { { InstanceId = "a", ItemId = "item_001" }, { InstanceId = "b", ItemId = "item_001" } } })
		assert(two ~= nil and two.Count == 2)
	end)

	------------------------------------------------------------------ équipement : cartes, tri, filtre

	local entries = {
		{ InstanceId = "I_T5", ItemId = "item_001", UpgradeLevel = 0 }, -- Commun
		{ InstanceId = "I_T2", ItemId = "item_015", UpgradeLevel = 0 }, -- Rare, arme
		{ InstanceId = "I_T1", ItemId = "item_015", UpgradeLevel = 2 }, -- doublon du même ItemId
		{ InstanceId = "I_T3", ItemId = "item_011", UpgradeLevel = 0 }, -- Rare, accessoire, catalogue avant 015
		{ InstanceId = "I_T4", ItemId = "item_100", UpgradeLevel = 0 }, -- Transcendant
		{ InstanceId = "I_T6", ItemId = "item_004", UpgradeLevel = 0 }, -- Commun, casque
	}

	test("equipment: one card per INSTANCE, duplicates of the same ItemId are never merged", function()
		local cards = Inventory.equipmentCards(entries, ctx())
		assert(#cards == 6, `{#cards} cards`)
		local seen = {}
		local sameItem = 0
		for _, card in cards do
			assert(not seen[card.InstanceId], "InstanceId appears once")
			seen[card.InstanceId] = true
			if card.ItemId == "item_015" then sameItem += 1 end
		end
		assert(sameItem == 2, "two separate cards for the two copies")
	end)

	test("equipment: sort = rarity descending, then catalogue order, then InstanceId", function()
		local cards = Inventory.equipmentCards(entries, ctx())
		assert(ids(cards, "InstanceId") == "I_T4,I_T3,I_T1,I_T2,I_T5,I_T6", ids(cards, "InstanceId"))
		-- identique quel que soit l'ordre d'arrivée
		local reversed = {}
		for i = #entries, 1, -1 do table.insert(reversed, entries[i]) end
		assert(ids(Inventory.equipmentCards(reversed, ctx()), "InstanceId") == "I_T4,I_T3,I_T1,I_T2,I_T5,I_T6")
	end)

	test("equipment: name, rarity and slot come from ItemConfig (the server sends none)", function()
		local card = Inventory.equipmentCards({ { InstanceId = "I_T9", ItemId = "item_015", UpgradeLevel = 0 } }, ctx())[1]
		assert(card.Name == "Lame des Ronces" and card.Rarity == "Rare" and card.SlotType == "weapon" and card.SlotName == "Arme")
		assert(card.Rank == RarityConfig.Rank.Rare and card.Icon == ItemConfig.Items.item_015.Icon)
	end)

	test("equipment: no \"+0\" — the level shows only when the upgrade level is above 0", function()
		assert(Inventory.levelText(0) == nil and Inventory.levelText(nil) == nil and Inventory.levelText(-1) == nil)
		assert(Inventory.levelText(2) == "+2")
		local cards = Inventory.equipmentCards(entries, ctx())
		for _, card in cards do
			assert(card.LevelText == (if card.InstanceId == "I_T1" then "+2" else nil), card.InstanceId)
		end
	end)

	test("equipment: slot filter keeps only that slot; unknown ItemId is ignored", function()
		local weapons = Inventory.equipmentCards(entries, ctx({ Slot = "weapon" }))
		for _, card in weapons do assert(card.SlotType == "weapon") end
		assert(ids(weapons, "InstanceId") == "I_T1,I_T2,I_T5", ids(weapons, "InstanceId"))
		local withUnknown = { { InstanceId = "I_T1", ItemId = "item_999" }, { InstanceId = "I_T2", ItemId = "item_001" } }
		assert(#Inventory.equipmentCards(withUnknown, ctx()) == 1)
	end)

	test("equipment: slot filters list only owned slots (catalogue order) with counts; stale filter falls back to all", function()
		local order = {}
		for _, slotType in ItemConfig.SlotTypes do table.insert(order, slotType.Id) end
		local filters = Inventory.slotFilters(entries, ctx(), order)
		assert(ids(filters, "Id") == "all,weapon,helmet,accessory,relic", ids(filters, "Id"))
		assert(filters[1].Count == 6 and filters[2].Count == 3 and filters[1].Label == "Tous" and filters[2].Label == "Arme")
		assert(Inventory.activeSlot(filters, "weapon") == "weapon")
		assert(Inventory.activeSlot(filters, "boots") == "all" and Inventory.activeSlot(filters, nil) == "all")
		assert(#Inventory.slotFilters({}, ctx(), order) == 1 and Inventory.slotFilters({}, ctx(), order)[1].Count == 0)
	end)

	test("equipment: « Nouveau » comes only from the fresh set", function()
		local cards = Inventory.equipmentCards(entries, ctx({ New = { I_T3 = true } }))
		for _, card in cards do assert(card.New == (card.InstanceId == "I_T3"), card.InstanceId) end
		for _, card in Inventory.equipmentCards(entries, ctx()) do assert(card.New == false) end
	end)

	test("equipment: cards carry no hero-style state (no Equip action field)", function()
		local card = Inventory.equipmentCards(entries, ctx())[1]
		for key in card do
			assert(not string.find(string.lower(key), "equip") and not string.find(string.lower(key), "action"), key)
		end
	end)

	------------------------------------------------------------------ ressources

	local resourceEntries = {
		{ ResourceId = "resource_023", Amount = 5 }, -- horde
		{ ResourceId = "resource_011", Amount = 12 }, -- slime
		{ ResourceId = "resource_021", Amount = 2 }, -- horde
		{ ResourceId = "resource_011", Amount = 1 }, -- doublon d'entrée : additionné
		{ ResourceId = "resource_999", Amount = 9 }, -- inconnue : ignorée
		{ ResourceId = "resource_012", Amount = 0 }, -- invalide : ignorée
	}

	test("resources: groups per NON-EMPTY family, catalogue family order, tiles in catalogue order", function()
		local groups = Inventory.resourceGroups(resourceEntries, resourceCtx)
		assert(ids(groups, "Id") == "slime,horde", ids(groups, "Id"))
		assert(groups[1].Name == "Slimes" and groups[2].Name == "Gobelins et orcs")
		assert(ids(groups[2].Tiles, "ResourceId") == "resource_021,resource_023")
		assert(groups[1].Tiles[1].Amount == 13 and groups[1].Tiles[1].AmountText == "13" and groups[1].Total == 13)
		assert(#Inventory.resourceGroups({}, resourceCtx) == 0, "no resource -> no group (empty state)")
	end)

	test("resources: no rarity anywhere in the resource groups or tiles", function()
		local groups = Inventory.resourceGroups(resourceEntries, resourceCtx)
		assert(not hasKeyLike(groups, "rarit") and not hasKeyLike(groups, "rarete") and not hasKeyLike(groups, "rank"), "rarity key on a resource")
		for _, info in ResourceConfig.Ordered do assert(info.Rarity == nil, info.Id) end
	end)

	test("resources: amount text — plain below 10 000, abbreviated above; initials fallback is UTF-8 safe", function()
		assert(Inventory.amountText(7) == "7" and Inventory.amountText(9999) == "9999" and Inventory.amountText(12500) == "12k")
		assert(Inventory.initials("Gelée d'Eau") == "GE" and Inventory.initials("Épée du Rempart") == "ÉP" and Inventory.initials("A") == "A")
	end)

	------------------------------------------------------------------ butin de l'écran de fin

	local lootCtx = { Items = ItemConfig.Items, Resources = ResourceConfig.Resources, RankOf = rankOf, SlotNames = ItemConfig.SlotTypeNames }

	test("loot: best item = highest rank; ties -> catalogue order; MoreItems counts the others", function()
		local parsed = Loot.parse({
			Items = { { InstanceId = "I_T1", ItemId = "item_001" }, { InstanceId = "I_T2", ItemId = "item_015" }, { InstanceId = "I_T3", ItemId = "item_011" } },
			Resources = {}, Overflow = false,
		}, lootCtx)
		assert(parsed.Best ~= nil and parsed.Best.ItemId == "item_011", "two Rare: catalogue order")
		assert(parsed.MoreItems == 2 and #parsed.Items == 3 and not parsed.Empty)
		local single = Loot.parse({ Items = { { InstanceId = "I_T1", ItemId = "item_100" } }, Resources = {} }, lootCtx)
		assert(single.Best.ItemId == "item_100" and single.MoreItems == 0)
		assert(Loot.moreItemsText(1) == "+1 équipement" and Loot.moreItemsText(3) == "+3 équipements")
	end)

	test("loot: resources only — no best card, resources in catalogue order across families", function()
		local parsed = Loot.parse({ Items = {}, Resources = { { ResourceId = "resource_023", Amount = 2 }, { ResourceId = "resource_011", Amount = 3 } }, Overflow = false }, lootCtx)
		assert(parsed.Best == nil and parsed.MoreItems == 0 and #parsed.Items == 0)
		assert(ids(parsed.Resources, "ResourceId") == "resource_011,resource_023", ids(parsed.Resources, "ResourceId"))
		assert(parsed.Resources[1].Amount == 3 and parsed.Resources[1].AmountText == "3")
		assert(not parsed.Empty and not parsed.Overflow)
	end)

	test("loot: nil / defeat / garbage payloads are empty; unknown or invalid entries are ignored", function()
		for _, payload in { false, "x", 3 } do assert(Loot.parse(payload, lootCtx).Empty) end
		assert(Loot.parse(nil, lootCtx).Empty and Loot.parse({}, lootCtx).Empty and Loot.parse({ Items = {}, Resources = {} }, lootCtx).Empty)
		local parsed = Loot.parse({
			Items = { { InstanceId = "I_T1", ItemId = "item_999" }, "bad", { ItemId = 4 } },
			Resources = { { ResourceId = "resource_999", Amount = 3 }, { ResourceId = "resource_011", Amount = 0 }, { ResourceId = "resource_012", Amount = "2" } },
		}, lootCtx)
		assert(parsed.Empty and #parsed.Items == 0 and #parsed.Resources == 0)
	end)

	test("loot: Overflow alone is not empty (the honest message is shown) and never adds an item", function()
		local parsed = Loot.parse({ Items = {}, Resources = {}, Overflow = true }, lootCtx)
		assert(parsed.Overflow and not parsed.Empty and parsed.Best == nil and #parsed.Resources == 0)
	end)

	test("loot: Rewards (currencies) are never read — gold in the payload is ignored", function()
		local parsed = Loot.parse({ Items = {}, Resources = {}, Rewards = { { Kind = "Gold", Amount = 100 } }, Gold = 100 }, lootCtx)
		assert(parsed.Empty and #parsed.Resources == 0)
	end)

	test("loot: no rarity on resources in the parsed payload", function()
		local parsed = Loot.parse({ Items = {}, Resources = { { ResourceId = "resource_011", Amount = 1 }, { ResourceId = "resource_030", Amount = 1 } } }, lootCtx)
		assert(not hasKeyLike(parsed.Resources, "rarit") and not hasKeyLike(parsed.Resources, "rank"))
	end)

	test("chips: all shown when they fit; otherwise the last slot becomes « +N autres » (N = hidden kinds)", function()
		local function make(n: number): any
			local out = {}
			for i = 1, n do table.insert(out, { ResourceId = `resource_0{10 + i}`, Name = "x", Amount = 1, AmountText = "1", Index = 10 + i }) end
			return out
		end
		local slots = Loot.chipSlots(R)
		assert(slots == 6, `{slots} slots`)
		local fits = Loot.chips(make(6), slots)
		assert(#fits.Shown == 6 and fits.More == 0)
		local over = Loot.chips(make(8), slots)
		assert(#over.Shown == 5 and over.More == 3 and #over.Shown + over.More == 8)
		assert(Loot.moreResourcesText(3) == "+3 autres")
		local tiny = Loot.chips(make(3), 1)
		assert(#tiny.Shown == 0 and tiny.More == 3)
		assert(#Loot.chips({}, slots).Shown == 0 and Loot.chips({}, slots).More == 0)
	end)

	------------------------------------------------------------------ mise en page de l'écran de fin

	local function layout(extra: any?): any
		local input = { Cards = 0, Heroes = 0, Band = false, Chips = 0, Caption = false, Note = false }
		for k, v in extra or {} do input[k] = v end
		return Loot.layout(input, R)
	end

	test("layout: without loot the positions are those of the previous screen (cards, heroes, button)", function()
		local l = layout({ Cards = 3, Heroes = 2 })
		assert(l.CardsY == 185 and l.HeroesY == 379 and l.ButtonY == 549 and l.Height == 629 and l.LootHeight == 0, `{l.HeroesY}/{l.ButtonY}/{l.Height}`)
		local cardsOnly = layout({ Cards = 3 })
		assert(cardsOnly.ButtonY == 379 + 20 and cardsOnly.Height == 520)
		local defeat = layout({})
		assert(defeat.ButtonY == 205 and defeat.Height == 520, `{defeat.ButtonY}/{defeat.Height}`)
	end)

	test("layout: the loot block pushes the heroes and the button down by exactly its height", function()
		local base = layout({ Cards = 3, Heroes = 2 })
		local withLoot = layout({ Cards = 3, Heroes = 2, Band = true, Chips = 3, Caption = true })
		local block = R.BandSize.Y + R.LootGap + R.ChipSize.Y + R.LootGap + R.CaptionHeight
		assert(withLoot.LootHeight == block, `{withLoot.LootHeight} vs {block}`)
		assert(withLoot.HeroesY == base.HeroesY + block + R.AfterLoot and withLoot.ButtonY == base.ButtonY + block + R.AfterLoot)
		assert(withLoot.Height == base.Height + block + R.AfterLoot)
	end)

	test("layout: elements of the loot block never overlap and stay inside the block", function()
		local l = layout({ Cards = 1, Band = true, Chips = 6, Caption = true, Note = true })
		assert(l.BandY == l.LootY)
		assert(l.ChipsY >= l.BandY + R.BandSize.Y)
		assert(l.CaptionY >= l.ChipsY + R.ChipSize.Y)
		assert(l.NoteY >= l.CaptionY + R.CaptionHeight)
		assert(l.LootY + l.LootHeight == l.NoteY + R.NoteHeight)
		assert(l.HeroesY >= l.LootY + l.LootHeight)
	end)

	test("layout: resources only (no band) and overflow only are laid out without a hole", function()
		local resources = layout({ Cards = 1, Chips = 2, Caption = true })
		assert(resources.ChipsY == resources.LootY and resources.LootHeight == R.ChipSize.Y + R.LootGap + R.CaptionHeight)
		local overflow = layout({ Cards = 1, Note = true })
		assert(overflow.NoteY == overflow.LootY and overflow.LootHeight == R.NoteHeight)
	end)

	test("layout: height is monotonic — adding an element never shrinks the screen", function()
		local previous = 0
		for _, extra in { {}, { Cards = 3 }, { Cards = 3, Heroes = 1 }, { Cards = 3, Heroes = 1, Chips = 3, Caption = true }, { Cards = 3, Heroes = 1, Band = true, Chips = 3, Caption = true },
			{ Cards = 3, Heroes = 4, Band = true, Chips = 6, Caption = true, Note = true } } do
			local l = layout(extra)
			assert(l.Height >= previous, `{l.Height} < {previous}`)
			previous = l.Height
		end
	end)

	test("layout: heroes wrap over rows of two (300 px chips in a 740 px row)", function()
		local one, two, three, four = layout({ Heroes = 1 }), layout({ Heroes = 2 }), layout({ Heroes = 3 }), layout({ Heroes = 4 })
		assert(one.HeroPerRow == 2 and one.HeroRows == 1 and two.HeroRows == 1 and three.HeroRows == 2 and four.HeroRows == 2)
		assert(one.HeroesHeight == R.HeroHeading + R.HeroChip.Y)
		assert(three.HeroesHeight == R.HeroHeading + 2 * R.HeroChip.Y + R.HeroGap)
		assert(three.ButtonY > two.ButtonY and three.Height > two.Height)
	end)

	test("fit: the reference scale (1080 px) is kept when everything fits, like the previous screen", function()
		local l = layout({ Cards = 3, Heroes = 2 })
		assert(Loot.fit(v2(1920, 1080), v2(l.Width, l.Height), R) == 1)
		assert(math.abs(Loot.fit(v2(1280, 720), v2(l.Width, l.Height), R) - 720 / 1080) < 1e-9)
	end)

	test("fit: shrinks on the HEIGHT axis when the content is too tall", function()
		local tall = layout({ Cards = 3, Heroes = 8, Band = true, Chips = 6, Caption = true, Note = true }) -- 4 rangées de héros
		local viewport = v2(1920, 1080)
		local scale = Loot.fit(viewport, v2(tall.Width, tall.Height), R)
		assert(tall.Height > viewport.Y - 2 * R.Margin and scale < 1 and scale >= R.MinScale, `{tall.Height} / {scale}`)
		assert(tall.Height * scale <= viewport.Y - 2 * R.Margin + 1e-6, "fits vertically")
	end)

	test("fit: shrinks on the WIDTH axis on a narrow portrait screen", function()
		local l = layout({ Cards = 2 })
		local scale = Loot.fit(v2(600, 1200), v2(l.Width, l.Height), R)
		assert(scale < 1 and scale >= R.MinScale)
		assert(l.Width * scale <= 600 - 2 * R.Margin + 1e-6, "fits horizontally")
	end)

	test("fit: never below MinScale nor above the reference/MaxScale", function()
		local l = layout({ Cards = 3, Heroes = 4, Band = true, Chips = 6, Caption = true, Note = true })
		assert(Loot.fit(v2(300, 200), v2(l.Width, l.Height), R) == R.MinScale)
		assert(Loot.fit(v2(7680, 4320), v2(760, 520), R) <= R.MaxScale)
	end)

	test("fit: the full screen (currencies + best item + chips + 4 heroes + overflow) fits at 720p and above", function()
		local worst = layout({ Cards = 3, Heroes = 4, Band = true, Chips = 6, Caption = true, Note = true })
		local typical = layout({ Cards = 3, Heroes = 2, Band = true, Chips = 4, Caption = true })
		for _, size in { v2(1920, 1080), v2(1600, 900), v2(1366, 768), v2(1280, 720), v2(1180, 820), v2(1024, 768) } do
			for name, l in { worst = worst, typical = typical } do
				local scale = Loot.fit(size, v2(l.Width, l.Height), R)
				assert(l.Height * scale <= size.Y - 2 * R.Margin + 1e-6 and l.Width * scale <= size.X - 2 * R.Margin + 1e-6,
					`{name} {size.X}x{size.Y} scale {scale} does not fit`)
			end
		end
		-- téléphone en paysage : l'échelle plancher s'applique (recette Studio obligatoire, risque connu)
		local phone = Loot.fit(v2(844, 390), v2(typical.Width, typical.Height), R)
		print(`INFO 844x390 typical loot screen: scale {phone}, {math.floor(typical.Height * phone)} px of {390 - 2 * R.Margin} px`)
	end)

	------------------------------------------------------------------ tailles minimales (design system)

	test("sizes: new texts >= 14 px, new touch targets and compact tiles >= 44 px", function()
		for name, layoutPack in { Wide = S.Wide, Phone = S.Phone } do
			for _, key in { "ItemNameSize", "ItemLineSize", "ResNameSize", "ResAmountSize", "ResHeaderSize", "ResHintSize" } do
				assert(layoutPack[key] >= 14, `Sacoche.{name}.{key} = {layoutPack[key]}`)
			end
			assert(layoutPack.FilterHeight >= 44, `Sacoche.{name}.FilterHeight`)
			assert(layoutPack.ResTileH >= 44, `Sacoche.{name}.ResTileH`)
			assert(layoutPack.ResIcon * 1 >= 32, `Sacoche.{name}.ResIcon`)
		end
		for _, key in { "BandHeadSize", "BandNameSize", "BandLineSize", "BandMoreSize", "ChipAmountSize", "ChipMoreSize", "CaptionSize", "NoteSize" } do
			assert(R[key] >= 14, `Reward.{key} = {R[key]}`)
		end
		assert(R.ChipSize.Y >= 44, "chips >= 44")
	end)

	print(`SacocheInventory: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{failed} SacocheInventory test(s) failed`)
	end
end
