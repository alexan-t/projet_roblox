--!strict
-- Hors du dossier Services : jamais exécuté par le bootstrap.
-- Teste la vraie migration v1 -> v2 (classes de combat temporaires -> HeroId réels).

return function(Migrations: any, HeroRules: any, hotbarSize: number)
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

	local LEGACY = { "Archer", "Epeiste", "Barbare", "Paladin", "Magicien", "Tireur" }
	local function v1(heroes: { [string]: string }, hotbar: { string }?, team: { string }?): any
		local h = {}
		for id, heroId in heroes do h[id] = { HeroId = heroId, Level = 1 } end
		local bar = hotbar or {}
		for i = #bar + 1, hotbarSize do bar[i] = "" end
		return {
			DataVersion = 1,
			Currencies = { Gold = 140, Gems = 12, SummonTickets = 1 },
			Progression = { CurrentZone = 1, HighestStage = 0, FirstClears = { ["1-1"] = true } },
			Heroes = h,
			Team = team or {},
			Hotbar = bar,
			Kingdom = { Level = 1, VisualState = 1 },
			Quests = { DefendDomain = { Progress = 1, Claimed = true } },
			Settings = { CombatSpeed = 2 },
		}
	end
	local function heroIds(d: any): { [string]: string }
		local out = {}
		for id, hero in d.Heroes do out[id] = hero.HeroId end
		return out
	end
	local function count(t: any): number
		local n = 0
		for _ in t do n += 1 end
		return n
	end
	local function noLegacy(d: any)
		for _, hero in d.Heroes do assert(not table.find(LEGACY, hero.HeroId), "legacy left: " .. hero.HeroId) end
	end

	test("version: CURRENT_VERSION is 2 and v1 profiles migrate", function()
		assert(Migrations.CURRENT_VERSION == 2)
		local d = v1({ A = "Archer" })
		assert(Migrations.run(d) == "Ok" and d.DataVersion == 2)
	end)

	test("v1 six legacy classes -> one ecuyer_du_rempart, no legacy left", function()
		local d = v1({ H1 = "Archer", H2 = "Epeiste", H3 = "Barbare", H4 = "Paladin", H5 = "Magicien", H6 = "Tireur" },
			{ "H1", "H2", "H3", "H4", "H5", "H6" })
		Migrations.run(d)
		assert(count(d.Heroes) == 1)
		local _, hero = next(d.Heroes)
		assert(hero.HeroId == "ecuyer_du_rempart")
		noLegacy(d)
	end)

	test("v1 with Epeiste: the same instance id is reused for the starter (Level kept)", function()
		local d = v1({ A = "Archer", E = "Epeiste", T = "Tireur" }, { "A", "E", "T" })
		d.Heroes.E.Level = 3
		Migrations.run(d)
		assert(count(d.Heroes) == 1 and d.Heroes.E and d.Heroes.E.HeroId == "ecuyer_du_rempart" and d.Heroes.E.Level == 3)
		assert(d.Hotbar[1] == "" and d.Hotbar[2] == "E" and d.Hotbar[3] == "", "its shortcut is kept")
	end)

	test("v1 without Epeiste: deterministic legacy instance (smallest id) becomes the starter", function()
		local a = v1({ Z9 = "Tireur", B2 = "Archer", M5 = "Paladin" })
		local b = v1({ M5 = "Paladin", Z9 = "Tireur", B2 = "Archer" })
		Migrations.run(a)
		Migrations.run(b)
		assert(count(a.Heroes) == 1 and a.Heroes.B2 and a.Heroes.B2.HeroId == "ecuyer_du_rempart")
		assert(count(b.Heroes) == 1 and b.Heroes.B2, "same result whatever the table order")
	end)

	test("v1 with a real ecuyer + legacy: real ecuyer kept, legacy removed", function()
		local d = v1({ R = "ecuyer_du_rempart", E = "Epeiste", A = "Archer" }, { "E", "R", "A" })
		Migrations.run(d)
		assert(count(d.Heroes) == 1 and d.Heroes.R.HeroId == "ecuyer_du_rempart")
		assert(d.Hotbar[1] == "" and d.Hotbar[2] == "R" and d.Hotbar[3] == "")
	end)

	test("v1 with other real HeroId: preserved, starter created from a legacy instance", function()
		local d = v1({ B = "barde_de_fer", T = "tireuse_des_faubourgs", X = "Tireur" })
		Migrations.run(d)
		local ids = heroIds(d)
		assert(ids.B == "barde_de_fer" and ids.T == "tireuse_des_faubourgs" and ids.X == "ecuyer_du_rempart")
		assert(count(d.Heroes) == 3)
	end)

	test("v1 with only real heroes and no legacy: untouched (starter granted by HeroService on load)", function()
		local d = v1({ T = "tireuse_des_faubourgs" }, { "T" })
		Migrations.run(d)
		assert(count(d.Heroes) == 1 and d.Heroes.T.HeroId == "tireuse_des_faubourgs" and d.Hotbar[1] == "T")
		local empty = v1({})
		Migrations.run(empty)
		assert(next(empty.Heroes) == nil)
	end)

	test("hotbar: dead legacy references cleared, same size, no holes, valid for normalizeHotbar", function()
		local d = v1({ A = "Archer", E = "Epeiste", P = "Paladin" }, { "A", "", "E", "P", "Ghost" })
		Migrations.run(d)
		assert(#d.Hotbar == hotbarSize)
		for i = 1, hotbarSize do assert(typeof(d.Hotbar[i]) == "string", "slot " .. i) end
		assert(d.Hotbar[1] == "" and d.Hotbar[3] == "E" and d.Hotbar[4] == "" and d.Hotbar[5] == "")
		assert(HeroRules.normalizeHotbar(d, hotbarSize) == false, "already valid after migration")
	end)

	test("team: dead legacy references removed, compact list", function()
		local d = v1({ A = "Archer", E = "Epeiste", B = "barde_de_fer" }, nil, { "A", "B", "E", "Ghost" })
		Migrations.run(d)
		assert(#d.Team == 2 and d.Team[1] == "B" and d.Team[2] == "E")
		for i = 1, #d.Team do assert(d.Team[i] ~= nil) end
	end)

	test("currencies, tickets, FirstClears, quests, kingdom and settings unchanged", function()
		local d = v1({ A = "Archer", E = "Epeiste" })
		Migrations.run(d)
		assert(d.Currencies.Gold == 140 and d.Currencies.Gems == 12 and d.Currencies.SummonTickets == 1)
		assert(d.Progression.FirstClears["1-1"] == true and d.Progression.HighestStage == 0 and d.Progression.CurrentZone == 1)
		assert(d.Quests.DefendDomain.Progress == 1 and d.Quests.DefendDomain.Claimed == true)
		assert(d.Kingdom.VisualState == 1 and d.Kingdom.Level == 1 and d.Settings.CombatSpeed == 2)
	end)

	test("migration replayed: idempotent, no duplication, run() does nothing on v2", function()
		local d = v1({ A = "Archer", E = "Epeiste", B = "barde_de_fer" }, { "A", "E", "B" }, { "E", "A" })
		Migrations.run(d)
		local snapshot = heroIds(d)
		local bar = table.concat(d.Hotbar, "|")
		Migrations.steps[1](d) -- étape rejouée à la main
		assert(Migrations.run(d) == "Ok")
		local again = heroIds(d)
		assert(count(again) == count(snapshot) and count(again) == 2)
		for id, heroId in snapshot do assert(again[id] == heroId) end
		assert(table.concat(d.Hotbar, "|") == bar and #d.Team == 1 and d.Team[1] == "E")
	end)

	test("missing Heroes / Hotbar / Team tables do not crash", function()
		local d: any = { DataVersion = 1 }
		assert(Migrations.run(d) == "Ok" and typeof(d.Heroes) == "table")
		local tooNew: any = { DataVersion = 99, Heroes = { A = { HeroId = "Archer" } } }
		assert(Migrations.run(tooNew) == "TooNew" and tooNew.Heroes.A.HeroId == "Archer", "untouched")
	end)

	print(`Migrations: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{failed} Migrations test(s) failed`)
	end
end
