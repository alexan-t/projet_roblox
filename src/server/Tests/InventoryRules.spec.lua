--!strict
-- Hors du dossier Services : jamais exécuté par le bootstrap.
-- Règles pures de l'inventaire (#72) avec les VRAIS catalogues ItemConfig / ResourceConfig.

return function(InventoryRules: any, catalogs: any)
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

	local function counter(): () -> string
		local n = 0
		return function(): string
			n += 1
			return string.format("I_T%010d%04d_X", 1000, n)
		end
	end
	local function count(t: any): number
		local n = 0
		for _ in t do n += 1 end
		return n
	end
	local function newData(): any
		return { Inventory = { Equipment = {}, Resources = {} } }
	end

	test("new inventory is empty and the view is empty", function()
		local d = newData()
		local view = InventoryRules.view(d, 500, catalogs)
		assert(#view.Equipment == 0 and #view.Resources == 0 and view.Count == 0 and view.Cap == 500)
	end)

	test("ensure: missing / wrongly typed tables are recreated, valid content is kept", function()
		local d: any = {}
		local inv = InventoryRules.ensure(d)
		assert(inv == d.Inventory and typeof(inv.Equipment) == "table" and typeof(inv.Resources) == "table")
		local e: any = { Inventory = { Equipment = "x", Resources = { resource_011 = 4 } } }
		InventoryRules.ensure(e)
		assert(count(e.Inventory.Equipment) == 0 and e.Inventory.Resources.resource_011 == 4, "valid piles kept")
		local f: any = { Inventory = 5 }
		InventoryRules.ensure(f)
		assert(typeof(f.Inventory) == "table" and typeof(f.Inventory.Equipment) == "table")
	end)

	test("equipment: one unique instance per drop, UpgradeLevel 0, ItemId from the catalogue", function()
		local d = newData()
		local id, why = InventoryRules.addEquipment(d, "item_015", 500, counter(), catalogs)
		assert(id and why == nil)
		local entry = d.Inventory.Equipment[id]
		assert(entry.ItemId == "item_015" and entry.UpgradeLevel == 0 and count(entry) == 2, "no affix, no extra field")
	end)

	test("duplicates of the same ItemId are independent instances (never merged)", function()
		local d = newData()
		local newId = counter()
		local a = InventoryRules.addEquipment(d, "item_001", 500, newId, catalogs)
		local b = InventoryRules.addEquipment(d, "item_001", 500, newId, catalogs)
		local c = InventoryRules.addEquipment(d, "item_001", 500, newId, catalogs)
		assert(a ~= b and b ~= c and a ~= c and count(d.Inventory.Equipment) == 3)
		d.Inventory.Equipment[b].UpgradeLevel = 3 -- une instance change, les autres non
		assert(d.Inventory.Equipment[a].UpgradeLevel == 0 and d.Inventory.Equipment[c].UpgradeLevel == 0)
		assert(InventoryRules.view(d, 500, catalogs).Count == 3)
	end)

	test("an id collision is retried, never overwrites an existing instance", function()
		local d = newData()
		d.Inventory.Equipment.I_FIXED = { ItemId = "item_002", UpgradeLevel = 0 }
		local calls = 0
		local id = InventoryRules.addEquipment(d, "item_001", 500, function(): string
			calls += 1
			return if calls < 3 then "I_FIXED" else "I_NEW"
		end, catalogs)
		assert(id == "I_NEW" and d.Inventory.Equipment.I_FIXED.ItemId == "item_002")
		local stuck, why = InventoryRules.addEquipment(d, "item_001", 500, function(): string return "I_FIXED" end, catalogs)
		assert(stuck == nil and why == "identifiant invalide" and count(d.Inventory.Equipment) == 2)
	end)

	test("unknown ItemId refused, nothing created", function()
		local d = newData()
		for _, bad in { "item_000", "item_101", "", "resource_011", "ITEM_001", 5, true, {} } :: { any } do
			local id, why = InventoryRules.addEquipment(d, bad, 500, counter(), catalogs)
			assert(id == nil and why == "item inconnu", tostring(bad))
		end
		assert(count(d.Inventory.Equipment) == 0)
	end)

	test("resources stack by ResourceId (integer amounts)", function()
		local d = newData()
		assert(InventoryRules.addResource(d, "resource_011", 3, catalogs) == 3)
		assert(InventoryRules.addResource(d, "resource_011", 2, catalogs) == 2)
		assert(InventoryRules.addResource(d, "resource_023", 1, catalogs) == 1)
		assert(d.Inventory.Resources.resource_011 == 5 and d.Inventory.Resources.resource_023 == 1 and count(d.Inventory.Resources) == 2)
	end)

	test("invalid quantities refused: 0, negative, decimal, NaN, infinity, text, nil", function()
		local d = newData()
		for _, bad in { 0, -1, 1.5, 0 / 0, math.huge, -math.huge, "3", true, {} } :: { any } do
			local added, why = InventoryRules.addResource(d, "resource_011", bad, catalogs)
			assert(added == nil and why == "quantité invalide", tostring(bad))
		end
		local added, why = InventoryRules.addResource(d, "resource_011", nil, catalogs)
		assert(added == nil and why == "quantité invalide")
		assert(count(d.Inventory.Resources) == 0, "nothing written")
	end)

	test("unknown ResourceId refused (incl. an ItemId and the 60-resource boundary)", function()
		local d = newData()
		for _, bad in { "resource_000", "resource_061", "item_001", "", 7 } :: { any } do
			local added, why = InventoryRules.addResource(d, bad, 1, catalogs)
			assert(added == nil and why == "ressource inconnue", tostring(bad))
		end
		assert(InventoryRules.addResource(d, "resource_060", 1, catalogs) == 1, "every catalogue resource is accepted")
		assert(count(d.Inventory.Resources) == 1)
	end)

	test("a stack is bounded by MAX_STACK and reports what was really added", function()
		local d = newData()
		d.Inventory.Resources.resource_011 = InventoryRules.MAX_STACK - 2
		assert(InventoryRules.addResource(d, "resource_011", 10, catalogs) == 2)
		assert(d.Inventory.Resources.resource_011 == InventoryRules.MAX_STACK)
		assert(InventoryRules.addResource(d, "resource_011", 1, catalogs) == 0)
	end)

	test("a corrupted stack is never overwritten by a grant", function()
		local d = newData()
		d.Inventory.Resources.resource_011 = "beaucoup"
		d.Inventory.Resources.resource_012 = -4
		local added, why = InventoryRules.addResource(d, "resource_011", 1, catalogs)
		assert(added == nil and why == "pile invalide" and d.Inventory.Resources.resource_011 == "beaucoup")
		assert(InventoryRules.addResource(d, "resource_012", 1, catalogs) == nil and d.Inventory.Resources.resource_012 == -4)
	end)

	test("cap: equipment beyond the cap is not created (Overflow), resources are still granted", function()
		local d = newData()
		local newId = counter()
		for _ = 1, 3 do assert(InventoryRules.addEquipment(d, "item_001", 3, newId, catalogs)) end
		local id, why = InventoryRules.addEquipment(d, "item_001", 3, newId, catalogs)
		assert(id == nil and why == "plafond atteint" and count(d.Inventory.Equipment) == 3)
		local loot = InventoryRules.apply(d, { Items = { { ItemId = "item_005" } }, Resources = { { ResourceId = "resource_012", Amount = 2 } } },
			{ Cap = 3, NewId = newId, Catalogs = catalogs })
		assert(loot.Overflow == true and #loot.Items == 0 and count(d.Inventory.Equipment) == 3, "no item beyond the cap")
		assert(#loot.Resources == 1 and loot.Resources[1].Amount == 2 and d.Inventory.Resources.resource_012 == 2, "resources always granted")
	end)

	test("apply: payload lists the instances really created and resources in catalogue order", function()
		local d = newData()
		local loot = InventoryRules.apply(d, {
			Items = { { ItemId = "item_015" }, { ItemId = "item_015" }, { ItemId = "item_999" } },
			Resources = { { ResourceId = "resource_023", Amount = 2 }, { ResourceId = "resource_011", Amount = 1 }, { ResourceId = "resource_011", Amount = 0 }, { ResourceId = "nope", Amount = 1 } },
		}, { Cap = 500, NewId = counter(), Catalogs = catalogs })
		assert(#loot.Items == 2 and loot.Items[1].ItemId == "item_015" and loot.Items[1].InstanceId ~= loot.Items[2].InstanceId and loot.Overflow == false)
		for _, drop in loot.Items do assert(d.Inventory.Equipment[drop.InstanceId].ItemId == drop.ItemId) end
		assert(#loot.Resources == 2 and loot.Resources[1].ResourceId == "resource_011" and loot.Resources[2].ResourceId == "resource_023")
		assert(d.Inventory.Resources.resource_011 == 1 and d.Inventory.Resources.resource_023 == 2, "invalid drops ignored")
		assert(loot.Rarity == nil and loot.Items[1].Rarity == nil, "the server never sends a rarity")
	end)

	test("view: equipment sorted by InstanceId (obtention order), resources by catalogue order, Amount >= 1, copies", function()
		local d = newData()
		d.Inventory.Equipment.I_T0000000002_b = { ItemId = "item_002", UpgradeLevel = 0 }
		d.Inventory.Equipment.I_T0000000001_a = { ItemId = "item_001", UpgradeLevel = 2 }
		d.Inventory.Equipment.I_T0000000003_c = { ItemId = "item_001", UpgradeLevel = 0 }
		d.Inventory.Resources = { resource_030 = 1, resource_011 = 4, resource_021 = 0 }
		local view = InventoryRules.view(d, 500, catalogs)
		assert(view.Equipment[1].InstanceId == "I_T0000000001_a" and view.Equipment[2].InstanceId == "I_T0000000002_b" and view.Equipment[3].InstanceId == "I_T0000000003_c")
		assert(view.Equipment[1].UpgradeLevel == 2 and view.Count == 3 and view.Cap == 500)
		assert(#view.Resources == 2 and view.Resources[1].ResourceId == "resource_011" and view.Resources[2].ResourceId == "resource_030", "0 not listed")
		view.Equipment[1].ItemId = "item_100"
		view.Resources[1].Amount = 999
		assert(d.Inventory.Equipment.I_T0000000001_a.ItemId == "item_001" and d.Inventory.Resources.resource_011 == 4, "the view shares nothing with PlayerData")
		for key in view.Equipment[1] do assert(key == "InstanceId" or key == "ItemId" or key == "UpgradeLevel", "no extra field: " .. tostring(key)) end
	end)

	test("tolerant reading: invalid entries ignored by the view and the cap, never deleted", function()
		local d = newData()
		d.Inventory.Equipment = {
			I_ok = { ItemId = "item_010", UpgradeLevel = 0 },
			I_unknown = { ItemId = "item_777", UpgradeLevel = 0 }, -- ItemId retiré du catalogue
			I_level = { ItemId = "item_010", UpgradeLevel = -1 },
			I_text = { ItemId = 5, UpgradeLevel = 0 },
			I_bare = "x",
		}
		d.Inventory.Resources = { resource_011 = 3, resource_999 = 5, resource_012 = "x" }
		local view = InventoryRules.view(d, 500, catalogs)
		assert(#view.Equipment == 1 and view.Equipment[1].InstanceId == "I_ok" and #view.Resources == 1)
		assert(InventoryRules.countEquipment(d, catalogs) == 1)
		assert(d.Inventory.Equipment.I_unknown and d.Inventory.Equipment.I_level and d.Inventory.Equipment.I_text and d.Inventory.Equipment.I_bare)
		assert(d.Inventory.Resources.resource_999 == 5 and d.Inventory.Resources.resource_012 == "x", "unknown data kept (a later version may know it)")
	end)

	test("only fixed keys Equipment / Resources: no 'Heroes', 'Equipped' or other field is ever created", function()
		local d = newData()
		InventoryRules.addEquipment(d, "item_001", 500, counter(), catalogs)
		InventoryRules.addResource(d, "resource_011", 1, catalogs)
		local keys = {}
		for k in d.Inventory do table.insert(keys, k) end
		table.sort(keys)
		assert(table.concat(keys, ",") == "Equipment,Resources")
		assert(count(d) == 1, "only Inventory touched in PlayerData")
	end)

	print(`InventoryRules: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{failed} InventoryRules test(s) failed`)
	end
end
