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

	test("starter kit: the 6 classes once, all in the hotbar (1..6), every one usable in combat", function()
		local d = data()
		assert(HeroRules.grantStarter(d, heroConfig.StarterHeroes, ids()) == 6)
		for index = 1, 6 do
			local id = d.Hotbar[index]
			assert(id ~= "" and d.Heroes[id], "shortcut " .. index)
			assert(combatConfig.Heroes[d.Heroes[id].HeroId], "combat stats for " .. d.Heroes[id].HeroId)
			assert(heroConfig.Heroes[d.Heroes[id].HeroId], "display info for " .. d.Heroes[id].HeroId)
		end
		assert(d.Hotbar[7] == "" and d.Hotbar[10] == "")
		assert(HeroRules.grantStarter(d, heroConfig.StarterHeroes, ids()) == 0, "never twice")
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

	test("ownership: only owned instances with combat stats", function()
		local d = data()
		d.Heroes = { A = { HeroId = "Archer", Level = 1 }, K = { HeroId = "Chevalier", Level = 1 } }
		assert(HeroRules.ownedHeroId(d, "A", combatConfig.Heroes) == "Archer")
		assert(select(2, HeroRules.ownedHeroId(d, "Z", combatConfig.Heroes)) == "héros inconnu")
		assert(select(2, HeroRules.ownedHeroId(d, 5, combatConfig.Heroes)) == "héros inconnu")
		assert(select(2, HeroRules.ownedHeroId(d, "K", combatConfig.Heroes)) == "héros non disponible au combat")
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
