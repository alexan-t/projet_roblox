--!strict
-- Hors du dossier Services : jamais exécuté par le bootstrap.
-- Teste le vrai HeroRules (héros possédés, kit de départ, hotbar) avec la vraie HeroConfig et la
-- vraie CombatConfig.

return function(HeroRules: any, heroConfig: any, combatConfig: any)
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

	local SIZE = heroConfig.HotbarSize
	test("manual shortcuts: replace, move, swap, clear preserve collection and persisted order", function()
		local d = { Heroes = { A = { HeroId = "Archer" }, B = { HeroId = "Paladin" } }, Hotbar = table.create(10, "") }
		assert(HeroRules.hotbarAction(d, SIZE, "Assign", "A", 4))
		assert(d.Hotbar[4] == "A")
		assert(HeroRules.hotbarAction(d, SIZE, "Assign", "B", 4))
		assert(d.Hotbar[4] == "B" and d.Heroes.A)
		assert(HeroRules.hotbarAction(d, SIZE, "Assign", "A", 2))
		assert(HeroRules.hotbarAction(d, SIZE, "Swap", 2, 4))
		assert(d.Hotbar[2] == "B" and d.Hotbar[4] == "A")
		assert(HeroRules.hotbarAction(d, SIZE, "Assign", "A", 10))
		assert(d.Hotbar[4] == "" and d.Hotbar[10] == "A")
		assert(HeroRules.hotbarAction(d, SIZE, "Swap", 10, 8))
		assert(d.Hotbar[10] == "" and d.Hotbar[8] == "A")
		assert(HeroRules.hotbarAction(d, SIZE, "Clear", 2))
		assert(d.Hotbar[2] == "" and d.Heroes.B)
		local persisted = table.clone(d.Hotbar)
		HeroRules.normalizeHotbar(d, SIZE)
		for i = 1, SIZE do assert(d.Hotbar[i] == persisted[i]) end
		assert(#d.Hotbar == 10)
	end)
	test("hotbar invalid input never mutates data; full bar moves without duplicates", function()
		local d = { Heroes = {}, Hotbar = {} }
		for i = 1, 10 do d.Heroes[`H{i}`] = { HeroId = "Archer" }; d.Hotbar[i] = `H{i}` end
		local before = table.concat(d.Hotbar, "|")
		for _, value in { 0, 11, 1.5, "1", {}, math.huge, 0/0 } do
			assert(not HeroRules.hotbarAction(d, SIZE, "Assign", "H1", value))
			assert(not HeroRules.hotbarAction(d, SIZE, "Clear", value))
			assert(not HeroRules.hotbarAction(d, SIZE, "Swap", 1, value))
		end
		assert(not HeroRules.hotbarAction(d, SIZE, "Assign", "ForeignHero", 1))
		assert(not HeroRules.hotbarAction(d, SIZE, "Delete", 1))
		assert(table.concat(d.Hotbar, "|") == before)
		assert(HeroRules.hotbarAction(d, SIZE, "Assign", "H1", 10))
		assert(d.Hotbar[1] == "" and d.Hotbar[10] == "H1" and d.Heroes.H10)
		local seen = {}
		for _, id in d.Hotbar do if id ~= "" then assert(not seen[id]); seen[id] = true end end
	end)
	local function data(): any
		local hotbar = {}
		for i = 1, SIZE do hotbar[i] = "" end
		return { Heroes = {}, Hotbar = hotbar, Currencies = { Gold = 0 } }
	end
	local function ids(): () -> string
		local n = 0
		return function(): string
			n += 1
			return "H" .. n
		end
	end

	test("new player: exactly one starter, ecuyer_du_rempart, in shortcut 1; never twice", function()
		local d = data()
		assert(#heroConfig.StarterHeroes == 1 and heroConfig.StarterHeroes[1] == "ecuyer_du_rempart")
		assert(HeroRules.grantStarter(d, heroConfig.StarterHeroes, ids()) == 1)
		local count = 0
		for _, hero in d.Heroes do
			count += 1
			assert(hero.HeroId == "ecuyer_du_rempart" and hero.Level == 1)
		end
		assert(count == 1)
		assert(d.Hotbar[1] ~= "" and d.Heroes[d.Hotbar[1]])
		for i = 2, SIZE do assert(d.Hotbar[i] == "", "shortcut " .. i .. " empty") end
		assert(HeroRules.grantStarter(d, heroConfig.StarterHeroes, ids()) == 0, "never twice (rejoin)")
	end)

	test("starter guaranteed by HeroId: a profile owning other heroes but no starter receives it once", function()
		local d = data()
		HeroRules.addHero(d, "T1", "tireuse_des_faubourgs")
		assert(HeroRules.grantStarter(d, heroConfig.StarterHeroes, ids()) == 1)
		assert(HeroRules.owns(d, "ecuyer_du_rempart") and d.Hotbar[1] == "T1" and d.Hotbar[2] ~= "")
		assert(HeroRules.grantStarter(d, heroConfig.StarterHeroes, ids()) == 0)
	end)

	test("catalog: real HeroId != combat profile; every hero has stats and a combat template", function()
		for heroId, info in heroConfig.Heroes do
			assert(not combatConfig.Heroes[heroId], heroId .. " must not be a combat class")
			assert(combatConfig.Heroes[info.CombatProfile], heroId .. " profile " .. tostring(info.CombatProfile))
			assert(typeof(info.CombatTemplate) == "string" and info.CombatTemplate ~= "", heroId .. " template")
			assert(typeof(info.Name) == "string" and info.Name ~= "")
		end
		assert(heroConfig.Heroes.ecuyer_du_rempart.CombatProfile == "Epeiste")
		assert(heroConfig.Heroes.ecuyer_du_rempart.CombatTemplate == "Heros_EcuyerDuRempart")
		assert(heroConfig.Heroes.tireuse_des_faubourgs.CombatProfile == "Tireur")
		assert(heroConfig.Heroes.tireuse_des_faubourgs.CombatTemplate == "Heros_Tireur")
		assert(heroConfig.HotbarSize == 10)
	end)

	test("new hero: first free shortcut, otherwise collection only (10 shortcuts max)", function()
		local d = data()
		for i = 1, SIZE do
			assert(HeroRules.addHero(d, "X" .. i, "Archer") == i)
		end
		assert(HeroRules.addHero(d, "X11", "Paladin") == nil, "hotbar full: collection")
		assert(d.Heroes.X11 and table.find(d.Hotbar, "X11") == nil and #d.Hotbar == SIZE)
	end)

	test("hotbar normalized: exact size, owned instances only, no duplicates, no holes", function()
		local d = data()
		d.Heroes = { A = { HeroId = "Archer", Level = 1 }, B = { HeroId = "Paladin", Level = 1 } }
		d.Hotbar = { "A", "Ghost", "A", "B" } -- trop court, inconnu, doublon
		assert(HeroRules.normalizeHotbar(d, SIZE) == true)
		assert(#d.Hotbar == SIZE and d.Hotbar[1] == "A" and d.Hotbar[2] == "" and d.Hotbar[3] == "" and d.Hotbar[4] == "B")
		for i = 1, SIZE do assert(typeof(d.Hotbar[i]) == "string") end
		assert(HeroRules.normalizeHotbar(d, SIZE) == false, "already valid")
		local missing = data()
		missing.Hotbar = nil
		HeroRules.normalizeHotbar(missing, SIZE)
		assert(#missing.Hotbar == SIZE)
	end)

	test("combat hero: owned + activated -> real HeroId with its temporary profile and template", function()
		local d = data()
		d.Heroes = {
			E = { HeroId = "ecuyer_du_rempart", Level = 1 },
			T = { HeroId = "tireuse_des_faubourgs", Level = 1 },
			L = { HeroId = "Epeiste", Level = 1 }, -- ancienne classe : plus un HeroId
			B = { HeroId = "barde_de_fer", Level = 1 }, -- asset réel, pas encore activé
		}
		local e = HeroRules.combatHero(d, "E", heroConfig.Heroes, combatConfig.Heroes)
		assert(e and e.HeroId == "ecuyer_du_rempart" and e.CombatProfile == "Epeiste" and e.CombatTemplate == "Heros_EcuyerDuRempart")
		local t = HeroRules.combatHero(d, "T", heroConfig.Heroes, combatConfig.Heroes)
		assert(t and t.HeroId == "tireuse_des_faubourgs" and t.CombatProfile == "Tireur" and t.CombatTemplate == "Heros_Tireur")
		assert(select(2, HeroRules.combatHero(d, "Z", heroConfig.Heroes, combatConfig.Heroes)) == "héros inconnu")
		assert(select(2, HeroRules.combatHero(d, 5, heroConfig.Heroes, combatConfig.Heroes)) == "héros inconnu")
		assert(select(2, HeroRules.combatHero(d, "L", heroConfig.Heroes, combatConfig.Heroes)) == "héros non disponible au combat")
		assert(select(2, HeroRules.combatHero(d, "B", heroConfig.Heroes, combatConfig.Heroes)) == "héros non disponible au combat")
	end)

	test("removing a hero frees its shortcut and never touches anything else", function()
		local d = data()
		HeroRules.addHero(d, "A", "Archer")
		HeroRules.addHero(d, "B", "Paladin")
		assert(HeroRules.removeHero(d, "A") == true and d.Heroes.A == nil and d.Hotbar[1] == "" and d.Hotbar[2] == "B")
		assert(HeroRules.removeHero(d, "A") == false and d.Currencies.Gold == 0)
	end)

	test("client view: copy of heroes and hotbar", function()
		local d = data()
		HeroRules.addHero(d, "B", "Paladin")
		HeroRules.addHero(d, "A", "Archer")
		local view = HeroRules.view(d)
		assert(#view.Heroes == 2 and view.Heroes[1].Id == "A" and view.Heroes[1].HeroId == "Archer")
		view.Hotbar[1] = "hack"
		assert(d.Hotbar[1] == "B", "the view is a copy")
	end)

	print(`HeroRules: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{failed} HeroRules test(s) failed`)
	end
end
