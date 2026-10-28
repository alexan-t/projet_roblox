--!strict
-- Hors du dossier Services : jamais exécuté par le bootstrap.
-- Exécute le vrai EquipmentService (vraies EquipmentRules, vraie EquipmentConfig, vrais catalogues) avec des doubles
-- de DataService, HeroService, InventoryService, CombatService et des API Roblox : remote d'écriture validée côté
-- serveur, refus, combat en cours, anti-rafale, deux joueurs, nettoyage au chargement.

return function(createService: any, EquipmentRules: any, modules: any)
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

	local function fixture(options: any?): any
		options = options or {}
		local env: any = { data = {}, instances = {}, pushes = {}, combat = {}, warnings = {}, ready = {}, now = 100 }
		env.players = { PlayerRemoving = { Connect = function() end } }
		local replicated: any = { Shared = {
			Config = { ItemConfig = modules.ItemConfig, RarityConfig = modules.RarityConfig },
			Utils = { Log = { info = function() end, debug = function() end, warn = function(_s: string, m: string) table.insert(env.warnings, m) end } },
		} }
		function replicated:FindFirstChild(name: string): any
			for _, i in env.instances do if i.Name == name and i.Parent == replicated then return i end end
			return nil
		end
		env.game = { GetService = function(_self: any, name: string): any
			return ({ Players = env.players, ReplicatedStorage = replicated })[name]
		end }
		env.require = function(module: any): any return module end
		env.Instance = { new = function(class: string): any
			local i: any = { ClassName = class, Name = class }
			table.insert(env.instances, i)
			return i
		end }
		env.os = { clock = function(): number return env.now end }
		local dataService: any = {}
		function dataService:GetData(player: any): any return env.data[player] end
		function dataService:OnPlayerReady(fn: any) table.insert(env.ready, fn) end
		local function spy(name: string): any
			local s: any = {}
			function s:Push(player: any) table.insert(env.pushes, `{name}:{player.Name}`) end
			return s
		end
		local combatService: any = {}
		function combatService:IsInCombat(player: any): boolean return env.combat[player] == true end
		env.script = { Parent = { DataService = dataService, HeroService = spy("Heroes"), InventoryService = spy("Inventory"), CombatService = combatService,
			Parent = { Config = { EquipmentConfig = options.config or modules.EquipmentConfig }, Inventory = { EquipmentRules = EquipmentRules } } } }
		function env.player(name: string): any
			local p: any = { Name = name, Parent = env.players, attributes = { DataLoaded = true } }
			function p:GetAttribute(key: string): any return self.attributes[key] end
			env.data[p] = {
				Heroes = { [name .. "_H1"] = { HeroId = "ecuyer_du_rempart", Level = 1, XP = 0 }, [name .. "_H2"] = { HeroId = "ecuyer_du_rempart", Level = 1, XP = 0 } },
				Inventory = { Equipment = {
					[name .. "_W1"] = { ItemId = "item_015", UpgradeLevel = 0 }, [name .. "_W2"] = { ItemId = "item_042", UpgradeLevel = 0 },
					[name .. "_A1"] = { ItemId = "item_008", UpgradeLevel = 0 },
				}, Resources = {} },
				HeroEquipment = {},
			}
			return p
		end
		env.service = createService(env)
		env.service:Init()
		env.service:Start()
		for _, i in env.instances do
			if i.Name == "EquipmentAction" then env.action = i end
		end
		-- appel client : avance l'horloge au-delà du délai anti-rafale, sauf demande contraire
		function env.call(p: any, ...: any): (boolean, any)
			env.now += 1
			return env.action.OnServerInvoke(p, ...)
		end
		return env
	end

	test("#12 one write remote only: EquipmentAction (RemoteFunction); no stat or grant remote", function()
		local e = fixture()
		local names = {}
		for _, i in e.instances do
			if i.ClassName == "RemoteEvent" or i.ClassName == "RemoteFunction" then table.insert(names, `{i.ClassName}:{i.Name}`) end
		end
		assert(table.concat(names, ",") == "RemoteFunction:EquipmentAction", table.concat(names, ","))
	end)

	test("Equip: the server finds the slot; HeroesChanged then InventoryChanged pushed once", function()
		local e = fixture()
		local p = e.player("A")
		local ok, result = e.call(p, "Equip", "A_H1", "A_W1")
		assert(ok and result.Slot == "weapon" and result.Replaced == nil, tostring(result))
		assert(e.data[p].HeroEquipment.A_H1.weapon == "A_W1")
		assert(table.concat(e.pushes, ",") == "Heroes:A,Inventory:A", table.concat(e.pushes, ","))
	end)

	test("replace then Unequip: the old item and the removed item stay in the inventory", function()
		local e = fixture()
		local p = e.player("A")
		e.call(p, "Equip", "A_H1", "A_W1")
		local ok, result = e.call(p, "Equip", "A_H1", "A_W2")
		assert(ok and result.Replaced == "A_W1")
		local off, removed = e.call(p, "Unequip", "A_H1", "weapon")
		assert(off and removed.Replaced == "A_W2")
		local inv = e.data[p].Inventory.Equipment
		assert(inv.A_W1 and inv.A_W2 and inv.A_A1, "nothing destroyed")
		assert(e.data[p].HeroEquipment.A_H1 == nil)
	end)

	test("#12 forged requests refused without mutation: stats, ItemId, slot, rarity, extra args, unknown verb", function()
		local e = fixture()
		local p = e.player("A")
		local before = #e.pushes
		for _, args in {
			{ "Equip", "A_H1", "item_042" }, -- ItemId du catalogue au lieu d'un exemplaire
			{ "Equip", "A_H1", { ItemId = "item_042", AttackDamage = 999 } },
			{ "Equip", "A_H1", "A_W1", "weapon" }, -- slot imposé par le client
			{ "Equip", "A_H1", "A_W1", { AttackDamage = 999 } },
			{ "Equip", "A_H1", "A_W1", "Legendaire" },
			{ "Equip", { HeroId = "x" }, "A_W1" },
			{ "SetStats", "A_H1", { MaxHealth = 9999 } },
			{ "Unequip", "A_H1", "weapon", "extra" },
			{ "Grant", "item_100" },
		} :: { any } do
			local ok, why = e.call(p, table.unpack(args))
			assert(ok == false and typeof(why) == "string", table.concat({ tostring(args[1]), tostring(args[3]) }, " "))
		end
		assert(#e.pushes == before and next(e.data[p].HeroEquipment) == nil, "no mutation, no push")
	end)

	test("#12 another player's hero or item is refused (two players isolated)", function()
		local e = fixture()
		local a, b = e.player("A"), e.player("B")
		local ok1, why1 = e.call(a, "Equip", "A_H1", "B_W1")
		local ok2, why2 = e.call(a, "Equip", "B_H1", "A_W1")
		assert(not ok1 and why1 == "équipement inconnu" and not ok2 and why2 == "héros inconnu")
		assert(e.call(a, "Equip", "A_H1", "A_W1") and e.call(b, "Equip", "B_H1", "B_W1"))
		assert(e.data[a].HeroEquipment.A_H1.weapon == "A_W1" and e.data[b].HeroEquipment.B_H1.weapon == "B_W1")
		assert(e.data[a].HeroEquipment.B_H1 == nil and e.data[b].HeroEquipment.A_H1 == nil)
	end)

	test("an instance worn by one copy of a hero cannot be worn by the other copy", function()
		local e = fixture()
		local p = e.player("A")
		assert(e.call(p, "Equip", "A_H1", "A_W1"))
		local ok, why = e.call(p, "Equip", "A_H2", "A_W1")
		assert(not ok and why == "équipé par un autre héros")
		assert(e.data[p].HeroEquipment.A_H2 == nil)
	end)

	test("combat in progress: Equip and Unequip refused (frozen roster); allowed again after the combat", function()
		local e = fixture()
		local p = e.player("A")
		assert(e.call(p, "Equip", "A_H1", "A_W1"))
		e.combat[p] = true
		local ok1, why1 = e.call(p, "Equip", "A_H1", "A_W2")
		local ok2, why2 = e.call(p, "Unequip", "A_H1", "weapon")
		assert(not ok1 and why1 == "combat en cours" and not ok2 and why2 == "combat en cours")
		assert(e.data[p].HeroEquipment.A_H1.weapon == "A_W1", "unchanged during the combat")
		e.combat[p] = nil
		assert(e.call(p, "Equip", "A_H1", "A_W2"))
	end)

	test("#12 burst: a second action within ActionCooldown is refused", function()
		local e = fixture()
		local p = e.player("A")
		assert(e.call(p, "Equip", "A_H1", "A_W1"))
		local ok, why = e.action.OnServerInvoke(p, "Unequip", "A_H1", "weapon") -- même instant
		assert(not ok and why == "réessaie dans un instant")
		e.now += modules.EquipmentConfig.ActionCooldown + 0.01
		assert(e.action.OnServerInvoke(p, "Unequip", "A_H1", "weapon"))
	end)

	test("data not loaded: refused", function()
		local e = fixture()
		local p = e.player("A")
		p.attributes.DataLoaded = false
		local ok, why = e.call(p, "Equip", "A_H1", "A_W1")
		assert(not ok and why == "données non chargées")
	end)

	test("invalid config: equipment disabled with a warning, nothing changes", function()
		local bad = table.clone(modules.EquipmentConfig)
		bad.SlotStats = { weapon = { AttackDamage = 3 } }
		local e = fixture({ config = bad })
		local p = e.player("A")
		local ok, why = e.call(p, "Equip", "A_H1", "A_W1")
		assert(not ok and why == "équipement indisponible" and #e.warnings > 0)
		assert(next(e.data[p].HeroEquipment) == nil)
	end)

	test("on player ready: invalid links are cleaned (removed hero, missing item, wrong slot), items kept", function()
		local e = fixture()
		local p = e.player("A")
		e.data[p].HeroEquipment = { A_H1 = { weapon = "A_W1", helmet = "A_A1" }, Gone = { weapon = "A_W2" } }
		for _, fn in e.ready do fn(p, e.data[p]) end
		assert(e.data[p].HeroEquipment.A_H1.weapon == "A_W1" and e.data[p].HeroEquipment.A_H1.helmet == nil and e.data[p].HeroEquipment.Gone == nil)
		local n = 0
		for _ in e.data[p].Inventory.Equipment do n += 1 end
		assert(n == 3 and #e.warnings == 1, `{n} items, {#e.warnings} warning(s)`)
	end)

	print(`EquipmentService: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{failed} EquipmentService test(s) failed`)
	end
end
