--!strict
-- Hors du dossier Services : jamais exécuté par le bootstrap.
-- Exécute le vrai InventoryService (vraies InventoryRules, vraie LootConfig, vrais catalogues) avec des doubles
-- de DataService et des API Roblox : remotes en LECTURE SEULE, vue, identifiants d'exemplaires.

return function(createService: any, InventoryRules: any, modules: any)
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

	local function fixture(): any
		local env: any = { data = {}, instances = {}, fired = {}, guid = 0 }
		env.players = {}
		local replicated: any = { Shared = { Config = { ItemConfig = modules.ItemConfig, ResourceConfig = modules.ResourceConfig, RarityConfig = modules.RarityConfig } } }
		function replicated:FindFirstChild(name: string): any
			for _, i in env.instances do if i.Name == name and i.Parent == replicated then return i end end
			return nil
		end
		env.game = { GetService = function(_self: any, name: string): any
			return ({
				Players = env.players,
				ReplicatedStorage = replicated,
				HttpService = { GenerateGUID = function(): string env.guid += 1 return string.format("GUID-%08d", env.guid) end },
			})[name]
		end }
		env.require = function(module: any): any return module end
		env.Instance = { new = function(class: string): any
			local i: any = { ClassName = class, Name = class }
			if class == "RemoteEvent" then
				function i:FireClient(player: any, view: any) table.insert(env.fired, { player = player, view = view }) end
			end
			table.insert(env.instances, i)
			return i
		end }
		local dataService: any = {}
		function dataService:GetData(player: any): any return env.data[player] end
		env.script = { Parent = { DataService = dataService, Parent = { Inventory = { InventoryRules = InventoryRules, EquipmentRules = modules.EquipmentRules },
			Config = { LootConfig = modules.LootConfig, EquipmentConfig = modules.EquipmentConfig } } } }
		function env.player(name: string): any
			local p: any = { Name = name, Parent = env.players, attributes = { DataLoaded = true } }
			function p:GetAttribute(key: string): any return self.attributes[key] end
			env.data[p] = { Inventory = { Equipment = {}, Resources = {} } }
			return p
		end
		env.service = createService(env)
		env.service:Start()
		for _, i in env.instances do
			if i.Name == "GetInventory" then env.get = i end
			if i.Name == "InventoryChanged" then env.changed = i end
		end
		return env
	end

	test("#12 exactly two remotes, both read-only: GetInventory and InventoryChanged", function()
		local e = fixture()
		local names = {}
		for _, i in e.instances do
			if i.ClassName == "RemoteEvent" or i.ClassName == "RemoteFunction" then table.insert(names, `{i.ClassName}:{i.Name}`) end
		end
		table.sort(names)
		assert(table.concat(names, ",") == "RemoteEvent:InventoryChanged,RemoteFunction:GetInventory", table.concat(names, ","))
		for _, i in e.instances do
			local lower = string.lower(i.Name)
			assert(not (lower:find("grant") or lower:find("give") or lower:find("add") or lower:find("equip") or lower:find("claim")), "no write remote: " .. i.Name)
		end
	end)

	test("#12 GetInventory ignores every client argument and never mutates", function()
		local e = fixture()
		local p = e.player("A")
		local before = InventoryRules.view(e.data[p], 500, modules)
		for _, args in { { "item_100" }, { { ItemId = "item_100", Amount = 9999 } }, { "resource_011", 1e9 }, { 0 / 0 }, { {} } } :: { any } do
			local view = e.get.OnServerInvoke(p, table.unpack(args))
			assert(view.Count == 0 and #view.Resources == 0 and #view.Equipment == 0)
		end
		assert(next(e.data[p].Inventory.Equipment) == nil and next(e.data[p].Inventory.Resources) == nil, "nothing created by a client call")
		assert(before.Cap == 500)
	end)

	test("GetInventory: nil before data / without DataLoaded, other players are independent", function()
		local e = fixture()
		local a, b = e.player("A"), e.player("B")
		InventoryRules.addResource(e.data[a], "resource_011", 7, modules)
		assert(e.get.OnServerInvoke(a).Resources[1].Amount == 7)
		assert(#e.get.OnServerInvoke(b).Resources == 0, "B never sees A's resources")
		a.attributes.DataLoaded = nil
		assert(e.get.OnServerInvoke(a) == nil)
		a.attributes.DataLoaded = true
		e.data[a] = nil
		assert(e.get.OnServerInvoke(a) == nil)
		a.Parent = nil
		e.data[a] = { Inventory = { Equipment = {}, Resources = {} } }
		assert(e.get.OnServerInvoke(a) == nil, "player gone")
	end)

	test("Push fires InventoryChanged to that player only, with the same view as GetInventory", function()
		local e = fixture()
		local a, b = e.player("A"), e.player("B")
		InventoryRules.addEquipment(e.data[a], "item_015", 500, function(): string return e.service:NewInstanceId() end, modules)
		e.service:Push(a)
		assert(#e.fired == 1 and e.fired[1].player == a and #e.fired[1].view.Equipment == 1)
		assert(e.fired[1].view.Cap == 500 and e.fired[1].view.Equipment[1].ItemId == "item_015")
		e.service:Push(b)
		assert(#e.fired == 2 and e.fired[2].player == b and e.fired[2].view.Count == 0)
		b.attributes.DataLoaded = nil
		e.service:Push(b)
		assert(#e.fired == 2, "no data: nothing pushed")
	end)

	test("view carries no rarity: the client reads the catalogue", function()
		local e = fixture()
		local p = e.player("A")
		InventoryRules.addEquipment(e.data[p], "item_015", 500, function(): string return e.service:NewInstanceId() end, modules)
		InventoryRules.addResource(e.data[p], "resource_030", 1, modules)
		local view = e.get.OnServerInvoke(p)
		-- #73 : Bonus (PV / ATK de l'objet) et, s'il est porté, EquippedBy / EquippedSlot ; jamais de rareté
		local allowed = { InstanceId = true, ItemId = true, UpgradeLevel = true, Bonus = true, EquippedBy = true, EquippedSlot = true }
		for k in view.Equipment[1] do assert(allowed[k], k) end
		for k in view.Equipment[1].Bonus do assert(k == "MaxHealth" or k == "AttackDamage", k) end
		assert(view.Equipment[1].Bonus.AttackDamage == 6 and view.Equipment[1].Bonus.MaxHealth == 0, "item_015 = Rare weapon: +6 ATK")
		assert(view.Equipment[1].EquippedBy == nil, "not worn")
		for k in view.Resources[1] do assert(k == "ResourceId" or k == "Amount", k) end
	end)

	test("NewInstanceId: I_T prefix, unique, fixed width so that string order = obtention order", function()
		local e = fixture()
		local ids = {}
		for _ = 1, 50 do table.insert(ids, e.service:NewInstanceId()) end
		local seen = {}
		for i, id in ids do
			assert(string.sub(id, 1, 3) == "I_T" and not seen[id], id)
			seen[id] = true
			assert(#id == #ids[1], "fixed width")
			if i > 1 then assert(ids[i - 1] < id, "sequence ascending inside one second") end
		end
	end)

	test("cap comes from LootConfig.EquipmentCap", function()
		local e = fixture()
		assert(e.service:GetCap() == modules.LootConfig.EquipmentCap and e.service:GetCap() == 500)
	end)

	print(`InventoryService: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{failed} InventoryService test(s) failed`)
	end
end
