--!strict
-- Hors du dossier Services : jamais exécuté par le bootstrap.
-- Règles pures de l'équipement porté (#73) avec les VRAIS ItemConfig, RarityConfig, EquipmentConfig, CombatConfig et
-- la vraie progression de niveau (#68).

return function(EquipmentRules: any, modules: any)
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

	local catalogs = { Item = modules.ItemConfig }
	local config = modules.EquipmentConfig
	local SLOTS = { "weapon", "helmet", "armor", "gloves", "boots", "accessory", "relic" }

	local function count(t: any): number
		local n = 0
		for _ in t do n += 1 end
		return n
	end
	-- Profil : deux exemplaires du MÊME héros (H1, H2) + une Tireuse (H3) ; objets donnés par { id = ItemId }.
	local function newData(items: { [string]: string }?): any
		local data: any = {
			Heroes = {
				H1 = { HeroId = "ecuyer_du_rempart", Level = 1, XP = 0 },
				H2 = { HeroId = "ecuyer_du_rempart", Level = 1, XP = 0 },
				H3 = { HeroId = "tireuse_des_faubourgs", Level = 1, XP = 0 },
			},
			Inventory = { Equipment = {}, Resources = {} },
			HeroEquipment = {},
		}
		for id, itemId in items or {} do
			data.Inventory.Equipment[id] = { ItemId = itemId, UpgradeLevel = 0 }
		end
		return data
	end
	local function copy(t: any): any
		if typeof(t) ~= "table" then return t end
		local out = {}
		for k, v in t do out[k] = copy(v) end
		return out
	end
	local function same(a: any, b: any): boolean
		if typeof(a) ~= "table" or typeof(b) ~= "table" then return a == b end
		for k, v in a do if not same(v, b[k]) then return false end end
		for k in b do if a[k] == nil then return false end end
		return true
	end

	------------------------------------------------------------------ slots et bonus

	test("the 7 slots of ItemConfig are the equipment slots, in display order; the config covers every slot and rarity", function()
		local ids = {}
		for _, slot in modules.ItemConfig.SlotTypes do table.insert(ids, slot.Id) end
		assert(table.concat(ids, ",") == table.concat(SLOTS, ","), table.concat(ids, ","))
		local problems = EquipmentRules.configProblems(config, catalogs, modules.RarityConfig.Tiers)
		assert(#problems == 0, table.concat(problems, " ; "))
	end)

	test("bonus = slot base x rarity multiplier, rounded (ALPHA 0.0.2 PROVISOIRE values)", function()
		local expected = {
			item_001 = { 0, 3 }, -- Commun, arme
			item_004 = { 20, 0 }, -- Commun, casque
			item_008 = { 45, 0 }, -- Peu commun, armure : 30 x 1,5
			item_009 = { 23, 0 }, -- Peu commun, bottes : 15 x 1,5 = 22,5 -> 23
			item_010 = { 15, 2 }, -- Peu commun, accessoire : 10 / 1 x 1,5
			item_013 = { 30, 4 }, -- Rare, relique
			item_015 = { 0, 6 }, -- Rare, arme
			item_029 = { 0, 6 }, -- Épique, gants : 2 x 3
			item_042 = { 0, 12 }, -- Légendaire, arme : 3 x 4
		}
		for itemId, pair in expected do
			local bonus = EquipmentRules.itemBonus(itemId, catalogs, config)
			assert(bonus.MaxHealth == pair[1] and bonus.AttackDamage == pair[2], `{itemId}: {bonus.MaxHealth}/{bonus.AttackDamage}`)
			assert(count(bonus) == 2, "only MaxHealth and AttackDamage")
		end
		local unknown = EquipmentRules.itemBonus("item_999", catalogs, config)
		assert(unknown.MaxHealth == 0 and unknown.AttackDamage == 0)
		assert(EquipmentRules.itemBonus(nil, catalogs, config).AttackDamage == 0)
	end)

	test("all 100 items follow the slot philosophy (weapon/gloves ATK, helmet/armor/boots PV, accessory/relic both), bonus > 0", function()
		local hp = { helmet = true, armor = true, boots = true, accessory = true, relic = true }
		local atk = { weapon = true, gloves = true, accessory = true, relic = true }
		local n = 0
		for _, item in modules.ItemConfig.Ordered do
			local bonus = EquipmentRules.itemBonus(item.Id, catalogs, config)
			assert((bonus.MaxHealth > 0) == (hp[item.SlotType] == true), `{item.Id} {item.SlotType} PV {bonus.MaxHealth}`)
			assert((bonus.AttackDamage > 0) == (atk[item.SlotType] == true), `{item.Id} {item.SlotType} ATK {bonus.AttackDamage}`)
			n += 1
		end
		assert(n == 100, `{n} items`)
	end)

	test("a higher rarity never gives a smaller bonus in the same slot", function()
		local tiers = modules.RarityConfig.Tiers
		for _, slot in SLOTS do
			local previous = { MaxHealth = -1, AttackDamage = -1 }
			for _, tier in tiers do
				local base = config.SlotStats[slot]
				local m = config.RarityMultiplier[tier.Id]
				for key, value in base do
					local v = math.floor(value * m + 0.5)
					assert(v >= (previous :: any)[key], `{slot} {tier.Id} {key}`)
					;(previous :: any)[key] = v
				end
			end
		end
	end)

	test("UpgradeLevel has no effect in V1 (no Forge)", function()
		local d = newData({ I1 = "item_015" })
		EquipmentRules.equip(d, "H1", "I1", catalogs)
		d.Inventory.Equipment.I1.UpgradeLevel = 9
		assert(EquipmentRules.heroBonus(d, "H1", catalogs, config).AttackDamage == 6)
	end)

	------------------------------------------------------------------ équiper / retirer

	test("an item only goes to its own SlotType (the slot is read from the catalogue, never chosen)", function()
		local d = newData({ W = "item_015", A = "item_008", R = "item_013" })
		for id, slot in { W = "weapon", A = "armor", R = "relic" } do
			local ok, why, result = EquipmentRules.equip(d, "H1", id, catalogs)
			assert(ok and why == nil and result.Slot == slot, `{id}: {tostring(why)}`)
			assert(d.HeroEquipment.H1[slot] == id)
		end
		assert(count(d.HeroEquipment.H1) == 3)
	end)

	test("refusals: unknown or not owned hero, unknown or not owned item, wrong types; nothing changes", function()
		local d = newData({ I1 = "item_015" })
		local before = copy(d)
		for _, case in {
			{ "HX", "I1", "héros inconnu" }, { nil, "I1", "héros inconnu" }, { 5, "I1", "héros inconnu" }, { {}, "I1", "héros inconnu" },
			{ "H1", "IX", "équipement inconnu" }, { "H1", "item_015", "équipement inconnu" }, { "H1", 3, "équipement inconnu" },
			{ "H1", { ItemId = "item_042" }, "équipement inconnu" }, { "H1", "", "équipement inconnu" },
		} :: { any } do
			local ok, why = EquipmentRules.equip(d, case[1], case[2], catalogs)
			assert(not ok and why == case[3], `{tostring(case[1])}/{tostring(case[2])}: {tostring(why)}`)
		end
		assert(same(d, before), "no mutation on refusal")
		-- objet dont l'ItemId n'existe plus dans le catalogue
		d.Inventory.Equipment.OLD = { ItemId = "item_999", UpgradeLevel = 0 }
		assert(select(2, EquipmentRules.equip(d, "H1", "OLD", catalogs)) == "équipement inconnu")
	end)

	test("one instance is worn by ONE hero in ONE slot: equipping it on another hero is refused", function()
		local d = newData({ I1 = "item_015" })
		assert(EquipmentRules.equip(d, "H1", "I1", catalogs))
		local ok, why = EquipmentRules.equip(d, "H2", "I1", catalogs)
		assert(not ok and why == "équipé par un autre héros")
		assert(d.HeroEquipment.H2 == nil and d.HeroEquipment.H1.weapon == "I1")
		local again, none, result = EquipmentRules.equip(d, "H1", "I1", catalogs)
		assert(again and none == nil and result.Replaced == nil, "same hero, same slot: no change")
	end)

	test("replacing frees the old item (still owned, available, wearable by another hero)", function()
		local d = newData({ OLD = "item_001", NEW = "item_015" })
		EquipmentRules.equip(d, "H1", "OLD", catalogs)
		local ok, _, result = EquipmentRules.equip(d, "H1", "NEW", catalogs)
		assert(ok and result.Slot == "weapon" and result.Replaced == "OLD")
		assert(d.HeroEquipment.H1.weapon == "NEW" and d.Inventory.Equipment.OLD ~= nil, "old item kept in the inventory")
		assert(EquipmentRules.holders(d, catalogs).OLD == nil, "old item available")
		assert(EquipmentRules.equip(d, "H2", "OLD", catalogs), "and wearable by another hero")
		assert(count(d.Inventory.Equipment) == 2, "nothing created or destroyed")
	end)

	test("unequip keeps the item; empty or unknown slot refused", function()
		local d = newData({ I1 = "item_008" })
		EquipmentRules.equip(d, "H1", "I1", catalogs)
		local ok, why, result = EquipmentRules.unequip(d, "H1", "armor", catalogs)
		assert(ok and why == nil and result.Slot == "armor" and result.Replaced == "I1")
		assert(d.HeroEquipment.H1 == nil and d.Inventory.Equipment.I1.ItemId == "item_008", "item still owned")
		assert(select(2, EquipmentRules.unequip(d, "H1", "armor", catalogs)) == "emplacement vide")
		assert(select(2, EquipmentRules.unequip(d, "H1", "ring", catalogs)) == "emplacement inconnu")
		assert(select(2, EquipmentRules.unequip(d, "HX", "armor", catalogs)) == "héros inconnu")
	end)

	test("two copies of the same HeroId and two copies of the same ItemId are independent", function()
		local d = newData({ A = "item_015", B = "item_015" })
		assert(EquipmentRules.equip(d, "H1", "A", catalogs))
		assert(EquipmentRules.equip(d, "H2", "B", catalogs))
		assert(d.HeroEquipment.H1.weapon == "A" and d.HeroEquipment.H2.weapon == "B")
		EquipmentRules.unequip(d, "H1", "weapon", catalogs)
		assert(EquipmentRules.heroBonus(d, "H1", catalogs, config).AttackDamage == 0)
		assert(EquipmentRules.heroBonus(d, "H2", catalogs, config).AttackDamage == 6, "H2 untouched")
	end)

	test("all 7 slots of one hero can be filled at once; the bonus is their sum", function()
		local d = newData({ w = "item_015", h = "item_004", a = "item_008", g = "item_029", b = "item_009", c = "item_010", r = "item_013" })
		for id in d.Inventory.Equipment do assert(EquipmentRules.equip(d, "H1", id, catalogs)) end
		assert(count(EquipmentRules.heroItems(d, "H1", catalogs)) == 7)
		local bonus = EquipmentRules.heroBonus(d, "H1", catalogs, config)
		assert(bonus.MaxHealth == 20 + 45 + 23 + 15 + 30 and bonus.AttackDamage == 6 + 6 + 2 + 4, `{bonus.MaxHealth}/{bonus.AttackDamage}`)
	end)

	------------------------------------------------------------------ ordre de calcul et stats

	test("order: combat profile -> level (#68) -> + flat equipment bonus; only PV / ATK change", function()
		local progression = modules.HeroProgressionRules
		local base = modules.CombatConfig.Heroes.Epeiste
		local lv1 = progression.combatStats(base, 1, modules.HeroProgressionConfig)
		local noItem = EquipmentRules.applyBonus(lv1, { MaxHealth = 0, AttackDamage = 0 }, config)
		assert(noItem.MaxHealth == 150 and noItem.AttackDamage == 16, "Lv1 without item = current stats")
		local lv2 = progression.combatStats(base, 2, modules.HeroProgressionConfig)
		assert(lv2.MaxHealth == 158 and lv2.AttackDamage == 17, "#68 example: Lv2 = 158 / 17")
		local d = newData({ A = "item_008", W = "item_015" })
		EquipmentRules.equip(d, "H1", "A", catalogs)
		EquipmentRules.equip(d, "H1", "W", catalogs)
		local final = EquipmentRules.applyBonus(lv2, EquipmentRules.heroBonus(d, "H1", catalogs, config), config)
		assert(final.MaxHealth == 158 + 45 and final.AttackDamage == 17 + 6, `{final.MaxHealth}/{final.AttackDamage}`)
		for key, value in lv2 do
			if key ~= "MaxHealth" and key ~= "AttackDamage" then assert(final[key] == value, key .. " unchanged") end
		end
		assert(lv2.MaxHealth == 158, "applyBonus returns a copy")
	end)

	------------------------------------------------------------------ données invalides et persistance

	test("normalize removes only invalid links and never an item: missing hero, missing item, wrong slot, empty, duplicate", function()
		local d = newData({ W = "item_015", A = "item_008", X = "item_001" })
		d.HeroEquipment = {
			H1 = { weapon = "W", helmet = "A", boots = "", ring = "X" }, -- A dans le mauvais slot, vide, slot inconnu
			H2 = { weapon = "W", armor = "A" }, -- W déjà porté par H1 (H1 < H2 : H1 garde W)
			Ghost = { weapon = "X" }, -- héros supprimé
			H3 = { armor = "Missing" }, -- objet absent
			H4 = 5,
		}
		local removed = EquipmentRules.normalize(d, catalogs)
		assert(removed == 7, `{removed}`)
		assert(same(d.HeroEquipment, { H1 = { weapon = "W" }, H2 = { armor = "A" } }), "clean state")
		assert(count(d.Inventory.Equipment) == 3, "every item kept")
		assert(EquipmentRules.normalize(d, catalogs) == 0, "idempotent")
	end)

	test("reads are tolerant and never mutate: missing / wrongly typed HeroEquipment, invalid links ignored", function()
		local d = newData({ W = "item_015" })
		d.HeroEquipment = nil
		assert(count(EquipmentRules.holders(d, catalogs)) == 0 and count(EquipmentRules.heroItems(d, "H1", catalogs)) == 0)
		assert(d.HeroEquipment == nil, "read does not create")
		d.HeroEquipment = { H1 = { helmet = "W" } }
		assert(EquipmentRules.heroBonus(d, "H1", catalogs, config).AttackDamage == 0, "wrong slot ignored")
		assert(d.HeroEquipment.H1.helmet == "W", "read does not clean")
		local e: any = { Heroes = {}, HeroEquipment = "x" }
		assert(typeof(EquipmentRules.ensure(e)) == "table")
	end)

	test("a removed hero frees its items (dropHero)", function()
		local d = newData({ W = "item_015" })
		EquipmentRules.equip(d, "H1", "W", catalogs)
		d.Heroes.H1 = nil
		EquipmentRules.dropHero(d, "H1")
		assert(d.HeroEquipment.H1 == nil and d.Inventory.Equipment.W ~= nil)
		assert(EquipmentRules.equip(d, "H2", "W", catalogs))
	end)

	test("persistence: the equipment survives a serialisation round trip (rejoin) on the right hero", function()
		local d = newData({ A = "item_015", B = "item_015", C = "item_008" })
		EquipmentRules.equip(d, "H1", "A", catalogs)
		EquipmentRules.equip(d, "H2", "B", catalogs)
		EquipmentRules.equip(d, "H2", "C", catalogs)
		local saved = copy(d) -- ce que ProfileStore relit : mêmes tables, sans référence partagée
		assert(EquipmentRules.normalize(saved, catalogs) == 0)
		assert(same(EquipmentRules.heroItems(saved, "H1", catalogs), { weapon = "A" }))
		assert(same(EquipmentRules.heroItems(saved, "H2", catalogs), { weapon = "B", armor = "C" }))
	end)

	test("no duplication: 3 000 seeded random Equip / Unequip keep one holder per instance and every item", function()
		local items = {}
		for i, itemId in { "item_001", "item_015", "item_015", "item_008", "item_004", "item_029", "item_013", "item_010", "item_009", "item_042" } do
			items[`I{i}`] = itemId
		end
		local d = newData(items)
		local ids, heroes = {}, { "H1", "H2", "H3", "HX" }
		for id in items do table.insert(ids, id) end
		table.sort(ids)
		local seed = 12345
		local function rand(n: number): number
			seed = (seed * 1103515245 + 12345) % 2147483648
			return seed % n + 1
		end
		for _ = 1, 3000 do
			if rand(3) == 1 then
				EquipmentRules.unequip(d, heroes[rand(4)], SLOTS[rand(7)], catalogs)
			else
				EquipmentRules.equip(d, heroes[rand(4)], ids[rand(#ids)], catalogs)
			end
			assert(EquipmentRules.normalize(d, catalogs) == 0, "raw data always clean after a mutation")
		end
		local seen = {}
		for _, heroSlots in d.HeroEquipment do
			for _, id in heroSlots do
				assert(not seen[id], "instance worn twice: " .. id)
				seen[id] = true
			end
		end
		assert(count(d.Inventory.Equipment) == 10, "no item lost or created")
	end)

	test("configProblems catches a non-V1 stat, a missing slot or rarity, a non-positive value", function()
		local bad = {
			Stats = { "MaxHealth", "AttackDamage" },
			SlotStats = { weapon = { MoveSpeed = 2 }, helmet = { MaxHealth = -1 } },
			RarityMultiplier = { Commun = 1 },
		}
		local text = table.concat(EquipmentRules.configProblems(bad, catalogs, modules.RarityConfig.Tiers), " | ")
		assert(text:find("weapon.MoveSpeed") and text:find("helmet.MaxHealth") and text:find("SlotStats.armor manquant") and text:find("RarityMultiplier.Rare"), text)
	end)

	test("invalid config: activeConfig is nil and every bonus is zero (never NaN or negative PV in a roster)", function()
		local bad = table.clone(config)
		bad.RarityMultiplier = table.clone(config.RarityMultiplier)
		bad.RarityMultiplier.Rare = 0 / 0
		bad.RarityMultiplier.Commun = -5
		assert(EquipmentRules.activeConfig(bad, catalogs, modules.RarityConfig.Tiers) == nil)
		assert(EquipmentRules.activeConfig(config, catalogs, modules.RarityConfig.Tiers) == config)
		-- même appelée avec la config fautive, itemBonus ignore les valeurs non finies ou négatives
		local rare, common = EquipmentRules.itemBonus("item_015", catalogs, bad), EquipmentRules.itemBonus("item_004", catalogs, bad)
		assert(rare.AttackDamage == 0 and common.MaxHealth == 0, `{rare.AttackDamage}/{common.MaxHealth}`)
		local d = newData({ W = "item_015" })
		EquipmentRules.equip(d, "H1", "W", catalogs)
		local bonus = EquipmentRules.heroBonus(d, "H1", catalogs, nil)
		assert(bonus.MaxHealth == 0 and bonus.AttackDamage == 0)
		local stats = { MaxHealth = 150, AttackDamage = 16, MoveSpeed = 10 }
		local final = EquipmentRules.applyBonus(stats, { MaxHealth = 99, AttackDamage = 99 }, nil)
		assert(final.MaxHealth == 150 and final.AttackDamage == 16 and final ~= stats, "no config: level stats, copied")
	end)

	print(`EquipmentRules: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{failed} EquipmentRules test(s) failed`)
	end
end
