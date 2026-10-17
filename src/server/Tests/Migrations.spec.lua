--!strict
-- Hors du dossier Services : jamais exécuté par le bootstrap.
-- Teste les vraies migrations v1 -> v2 (classes de combat temporaires -> HeroId réels) et v2 -> v3
-- (onboarding : les anciens profils ne refont pas l'invocation tutorielle).

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

	test("version: CURRENT_VERSION is 4 and v1 / v2 / v3 profiles migrate", function()
		assert(Migrations.CURRENT_VERSION == 4)
		local d = v1({ A = "Archer" })
		assert(Migrations.run(d) == "Ok" and d.DataVersion == 4)
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

	test("v1 with only real heroes and no legacy: heroes untouched; no hero at all stays empty (tutorial)", function()
		local d = v1({ T = "tireuse_des_faubourgs" }, { "T" })
		Migrations.run(d)
		assert(count(d.Heroes) == 1 and d.Heroes.T.HeroId == "tireuse_des_faubourgs" and d.Hotbar[1] == "T")
		local empty = v1({})
		Migrations.run(empty)
		assert(next(empty.Heroes) == nil)
		assert(empty.Quests.SummonStarter == nil, "no hero: the tutorial summon gives the first one")
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

	-- Profil v2 réel : Écuyer reçu au chargement, Tireuse invoquée, 1-1 terminé, quête réclamée.
	local function v2(): any
		local bar = { "E", "T" }
		for i = #bar + 1, hotbarSize do bar[i] = "" end
		return {
			DataVersion = 2,
			Currencies = { Gold = 250, Gems = 25, SummonTickets = 2 },
			Progression = { CurrentZone = 1, HighestStage = 0, FirstClears = { ["1-1"] = true, ["1-2"] = true } },
			Heroes = { E = { HeroId = "ecuyer_du_rempart", Level = 1, XP = 0 }, T = { HeroId = "tireuse_des_faubourgs", Level = 2, XP = 0 } },
			Team = { "E", "T" },
			Hotbar = bar,
			Summons = { Total = 3 },
			Kingdom = { Level = 1, VisualState = 2 },
			Quests = { DefendDomain = { Progress = 1, Claimed = true } },
			Settings = { CombatSpeed = 2 },
		}
	end
	-- Sérialisation stable (clés triées) pour comparer deux profils en entier.
	local function dump(value: any): string
		if typeof(value) ~= "table" then
			return tostring(value)
		end
		local keys = {}
		for key in value do table.insert(keys, tostring(key)) end
		table.sort(keys)
		local parts = {}
		for _, key in keys do
			local item = value[key]
			if item == nil then item = value[tonumber(key)] end
			table.insert(parts, key .. "=" .. dump(item))
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end

	test("v2 -> v3: existing player skips SummonStarter (done + claimed), nothing else changes", function()
		local d = v2()
		local before = v2()
		assert(Migrations.run(d) == "Ok" and d.DataVersion == 4)
		assert(d.Quests.SummonStarter and d.Quests.SummonStarter.Progress == 1 and d.Quests.SummonStarter.Claimed == true)
		assert(d.Quests.DefendStage12 and d.Quests.DefendStage12.Progress == 1 and d.Quests.DefendStage12.Claimed == true, "1-2 already won: its quest is done")
		d.Quests.SummonStarter = nil
		d.Quests.DefendStage12 = nil
		d.DataVersion = 2
		assert(dump(d) == dump(before), "heroes, hotbar, team, currencies, tickets, summons, FirstClears, kingdom, quests kept")
	end)

	test("v2 -> v3: no hero removed, no ticket / currency / summon touched", function()
		local d = v2()
		Migrations.run(d)
		assert(count(d.Heroes) == 2 and d.Heroes.E.HeroId == "ecuyer_du_rempart" and d.Heroes.T.HeroId == "tireuse_des_faubourgs")
		assert(d.Currencies.SummonTickets == 2 and d.Currencies.Gold == 250 and d.Summons.Total == 3)
		assert(d.Progression.FirstClears["1-1"] and d.Progression.FirstClears["1-2"] and d.Kingdom.VisualState == 2)
	end)

	test("v2 -> v3: a profile without any hero keeps the tutorial; an existing SummonStarter state is kept", function()
		local empty = v2()
		empty.Heroes, empty.Team = {}, {}
		for i = 1, hotbarSize do empty.Hotbar[i] = "" end
		Migrations.run(empty)
		assert(empty.Quests.SummonStarter == nil and empty.DataVersion == 4)
		local started = v2()
		started.Quests.SummonStarter = { Progress = 0, Claimed = false }
		Migrations.run(started)
		assert(started.Quests.SummonStarter.Progress == 0 and started.Quests.SummonStarter.Claimed == false)
	end)

	test("v2 -> v3: Zone 1 already finished -> every stage quest claimed, no retroactive reward", function()
		local d = v2()
		for stage = 1, 5 do d.Progression.FirstClears["1-" .. stage] = true end
		d.Quests = {}
		Migrations.run(d)
		for _, id in { "DefendDomain", "DefendStage12", "DefendStage13", "DefendStage14", "DefeatRoiOrc" } do
			assert(d.Quests[id] and d.Quests[id].Progress == 1 and d.Quests[id].Claimed == true, id)
		end
		assert(d.Currencies.Gold == 250 and d.Currencies.Gems == 25 and d.Currencies.SummonTickets == 2, "no currency added by the migration")
	end)

	test("v2 -> v3: stages not won stay open (rewarded later); an existing quest state is never overwritten", function()
		local d = v2()
		d.Progression.FirstClears = { ["1-1"] = true }
		d.Quests = { DefendDomain = { Progress = 1, Claimed = false } }
		Migrations.run(d)
		assert(d.Quests.DefendDomain.Claimed == false, "completed but not claimed before: still claimable")
		assert(d.Quests.DefendStage12 == nil and d.Quests.DefeatRoiOrc == nil, "future stages: normal reward after the migration")
	end)

	test("v3 (new profile): run() does nothing; v2 -> v3 replayed is idempotent", function()
		local fresh: any = { DataVersion = 3, Heroes = {}, Quests = {} }
		assert(Migrations.run(fresh) == "Ok" and fresh.Quests.SummonStarter == nil, "new profile starts the tutorial")
		local d = v2()
		Migrations.run(d)
		local snapshot = dump(d)
		Migrations.steps[2](d)
		assert(Migrations.run(d) == "Ok" and dump(d) == snapshot)
	end)

	-- Profil v3 réel (Alpha 0.0.1) : héros sans XP, un Level conservé.
	local function v3(): any
		local d = v2()
		d.DataVersion = 3
		d.Heroes = { E = { HeroId = "ecuyer_du_rempart", Level = 1 }, T = { HeroId = "tireuse_des_faubourgs", Level = 4 },
			D = { HeroId = "ecuyer_du_rempart", Level = 1 } }
		d.Quests.SummonStarter = { Progress = 1, Claimed = true }
		return d
	end

	test("v3 -> v4: every hero gets XP = 0, valid Level kept, nothing else touched", function()
		local d = v3()
		local before = v3()
		assert(Migrations.run(d) == "Ok" and d.DataVersion == 4)
		assert(count(d.Heroes) == 3, "no hero removed")
		for id, hero in d.Heroes do
			assert(hero.XP == 0, id .. " XP added")
			assert(hero.Level == before.Heroes[id].Level and hero.HeroId == before.Heroes[id].HeroId, id .. " Level / HeroId kept")
		end
		for _, hero in d.Heroes do hero.XP = nil end
		d.DataVersion = 3
		assert(dump(d) == dump(before), "hotbar, team, currencies, FirstClears, summons, kingdom, quests untouched")
	end)

	test("v3 -> v4: invalid Level -> 1, invalid XP -> 0, existing valid XP kept; idempotent", function()
		local d = v3()
		d.Heroes.E.Level = 0
		d.Heroes.T.Level = 2.5
		d.Heroes.D.Level = "3"
		d.Heroes.E.XP = -4
		d.Heroes.T.XP = 0 / 0
		d.Heroes.D.XP = 40
		Migrations.run(d)
		assert(d.Heroes.E.Level == 1 and d.Heroes.T.Level == 1 and d.Heroes.D.Level == 1)
		assert(d.Heroes.E.XP == 0 and d.Heroes.T.XP == 0 and d.Heroes.D.XP == 40)
		local snapshot = dump(d)
		Migrations.steps[3](d)
		assert(dump(d) == snapshot, "replayed step changes nothing")
	end)

	test("#69 v4 profile (no EliteFirstClears yet): still version 4, nothing migrated, no retroactive Elite clear", function()
		-- EliteFirstClears est une clé fixe de Progression : Profile:Reconcile() (récursif) l'ajoute vide
		-- aux anciens profils ; aucune étape de migration, DataVersion reste 4.
		assert(Migrations.CURRENT_VERSION == 4)
		local d = v3()
		Migrations.run(d)
		for stage = 1, 5 do d.Progression.FirstClears[`1-{stage}`] = true end
		local snapshot = dump(d)
		assert(Migrations.run(d) == "Ok" and d.DataVersion == 4 and dump(d) == snapshot)
		assert(d.Progression.EliteFirstClears == nil, "never filled by a migration: no Elite clear given back")
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
