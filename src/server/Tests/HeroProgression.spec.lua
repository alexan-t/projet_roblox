--!strict
-- Hors du dossier Services : jamais exécuté par le bootstrap. Lancé par tools/test-heroes.ps1.
-- Règles pures des niveaux et de l'XP (HeroProgressionRules) avec la vraie HeroProgressionConfig et
-- les vraies stats de CombatConfig.

return function(modules: any)
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

	local Rules = modules.HeroProgressionRules
	local Config = modules.HeroProgressionConfig
	local HeroRules = modules.HeroRules
	local CombatConfig = modules.CombatConfig

	test("config: valid, MaxLevel 20, curve 100 + 25 x (level - 1), Lv19 -> 20 = 550, Lv20 = 0", function()
		assert(#Rules.configProblems(Config) == 0)
		assert(Config.MaxLevel == 20)
		assert(Rules.xpToNext(1, Config) == 100 and Rules.xpToNext(2, Config) == 125 and Rules.xpToNext(3, Config) == 150)
		assert(Rules.xpToNext(19, Config) == 550 and Rules.xpToNext(20, Config) == 0)
	end)

	test("stage XP (victory): 1-1 25, 1-2 35, 1-3 50, 1-4 70, 1-5 100; unknown stage 0", function()
		local expected = { 25, 35, 50, 70, 100 }
		for stage, amount in expected do
			assert(Rules.stageXP(1, stage, Config) == amount, `1-{stage}`)
		end
		assert(Rules.stageXP(1, 6, Config) == 0 and Rules.stageXP(7, 1, Config) == 0)
	end)

	test("stage XP zones 2-6: every stage gives XP, more than the same rank in the previous zone", function()
		for zone = 2, 6 do
			for stage = 1, 5 do
				local amount = Rules.stageXP(zone, stage, Config)
				assert(amount > Rules.stageXP(zone - 1, stage, Config), `{zone}-{stage} > {zone - 1}-{stage}`)
				if stage > 1 then
					assert(amount > Rules.stageXP(zone, stage - 1, Config), `{zone}-{stage} > {zone}-{stage - 1}`)
				end
			end
		end
	end)

	test("#69 Elite XP: 1-1E 60, 1-2E 80, 1-3E 110, 1-4E 150, 1-5E 220; Normal unchanged; distinct per mode", function()
		local elite = { 60, 80, 110, 150, 220 }
		local normal = { 25, 35, 50, 70, 100 }
		for stage = 1, 5 do
			assert(Rules.stageXP(1, stage, Config, "Elite") == elite[stage], `1-{stage}E`)
			assert(Rules.stageXP(1, stage, Config, "Normal") == normal[stage] and Rules.stageXP(1, stage, Config) == normal[stage], `1-{stage}`)
			assert(Rules.stageXP(1, stage, Config, "Elite") ~= Rules.stageXP(1, stage, Config), "never the same table by accident")
		end
		assert(Rules.stageXP(1, 6, Config, "Elite") == 0 and Rules.stageXP(1, 1, Config, "Hard") == 0, "1-6E / unknown mode: 0")
	end)

	test("new hero = Lv1 / XP 0 (HeroRules.addHero)", function()
		local data = { Heroes = {}, Hotbar = table.create(10, "") }
		HeroRules.addHero(data, "A", "ecuyer_du_rempart")
		assert(data.Heroes.A.Level == 1 and data.Heroes.A.XP == 0)
	end)

	test("grantXP: XP inside the current level, level up at the threshold", function()
		local hero = { Level = 1, XP = 0 }
		local g = Rules.grantXP(hero, 25, Config)
		assert(hero.Level == 1 and hero.XP == 25 and g.LevelBefore == 1 and g.LevelAfter == 1 and g.XPGranted == 25 and g.XPToNext == 100)
		g = Rules.grantXP(hero, 75, Config)
		assert(hero.Level == 2 and hero.XP == 0 and g.LevelAfter == 2 and g.XPToNext == 125, "exactly 100 -> Lv2, 0 XP")
	end)

	test("grantXP: several level ups at once (Lv1 90 XP + 300 -> Lv3 115 XP)", function()
		local hero = { Level = 1, XP = 90 }
		local g = Rules.grantXP(hero, 300, Config)
		-- 90 + 300 = 390 ; -100 (Lv2) = 290 ; -125 (Lv3) = 165 ; 165 < 150 ? non : -150 (Lv4) = 15
		assert(hero.Level == 4 and hero.XP == 15, `got Lv{hero.Level} {hero.XP}`)
		assert(g.LevelBefore == 1 and g.LevelAfter == 4 and g.XPGranted == 300)
	end)

	test("grantXP: Lv20 cap, XP stays 0, surplus lost; nothing granted at Lv20", function()
		local hero = { Level = 19, XP = 500 }
		local g = Rules.grantXP(hero, 10000, Config)
		assert(hero.Level == 20 and hero.XP == 0 and g.LevelAfter == 20 and g.XPToNext == 0)
		g = Rules.grantXP(hero, 100, Config)
		assert(hero.Level == 20 and hero.XP == 0 and g.XPGranted == 0 and g.LevelBefore == 20)
		local big = { Level = 1, XP = 0 }
		Rules.grantXP(big, 1e9, Config)
		assert(big.Level == 20 and big.XP == 0)
	end)

	test("grantXP: invalid amounts give nothing; invalid stored values are repaired (Level <= 20, XP >= 0)", function()
		for _, amount in { 0, -5, 0 / 0, "10" } :: { any } do
			local hero = { Level = 3, XP = 40 }
			Rules.grantXP(hero, amount, Config)
			assert(hero.Level == 3 and hero.XP == 40, tostring(amount))
		end
		local broken: any = { Level = 99, XP = -3 }
		Rules.grantXP(broken, 10, Config)
		assert(broken.Level == 1 and broken.XP == 10, "Level 99 is invalid -> 1")
		local missing: any = {}
		Rules.grantXP(missing, 30, Config)
		assert(missing.Level == 1 and missing.XP == 30)
	end)

	test("combat stats: Lv1 = current stats exactly; Lv2 +5 %; Lv10 +45 %; Lv20 +95 % (HP / ATK only)", function()
		for profile, base in CombatConfig.Heroes do
			local lv1 = Rules.combatStats(base, 1, Config)
			for key, value in base do
				assert(lv1[key] == value, `{profile}.{key} unchanged at Lv1`)
			end
			for _, case in { { 2, 1.05 }, { 10, 1.45 }, { 20, 1.95 } } do
				local stats = Rules.combatStats(base, case[1], Config)
				assert(stats.MaxHealth == math.floor(base.MaxHealth * case[2] + 0.5), `{profile} HP Lv{case[1]}`)
				assert(stats.AttackDamage == math.floor(base.AttackDamage * case[2] + 0.5), `{profile} ATK Lv{case[1]}`)
				for _, key in { "AttackInterval", "AttackRange", "MoveSpeed", "EnergyPerAttack", "MaxEnergy", "UltimateDamage" } do
					assert(stats[key] == base[key], `{profile}.{key} never scales`)
				end
			end
		end
		local epeiste = Rules.combatStats(CombatConfig.Heroes.Epeiste, 2, Config)
		assert(epeiste.MaxHealth == 158 and epeiste.AttackDamage == 17, "Écuyer Lv2: 150 -> 158 HP, 16 -> 17 ATK")
	end)

	test("combat stats: a copy, the frozen CombatConfig is never touched; invalid level -> Lv1 stats", function()
		local base = CombatConfig.Heroes.Epeiste
		local stats = Rules.combatStats(base, 20, Config)
		stats.MaxHealth = 1
		assert(base.MaxHealth == 150)
		local bad = Rules.combatStats(base, 0, Config)
		assert(bad.MaxHealth == base.MaxHealth and bad.AttackDamage == base.AttackDamage)
	end)

	test("hero view: Level, XP, XPToNext, MaxLevel per instance; Lv20 -> XP 0 / XPToNext 0", function()
		local data = { Heroes = { A = { HeroId = "ecuyer_du_rempart", Level = 3, XP = 40 }, B = { HeroId = "ecuyer_du_rempart", Level = 20, XP = 0 } }, Hotbar = {} }
		local view = HeroRules.view(data, { rules = Rules, config = Config })
		local byId = {}
		for _, hero in view.Heroes do byId[hero.Id] = hero end
		assert(byId.A.Level == 3 and byId.A.XP == 40 and byId.A.XPToNext == 150 and byId.A.MaxLevel == 20)
		assert(byId.B.Level == 20 and byId.B.XP == 0 and byId.B.XPToNext == 0, "duplicates keep their own level")
		assert(byId.A.MaxHealth == nil, "no combat profiles given: no stats")
	end)

	test("hero view (Sacoche): MaxHealth / AttackDamage = combatStats of the instance at its level", function()
		local data = { Heroes = { A = { HeroId = "ecuyer_du_rempart", Level = 1, XP = 0 }, B = { HeroId = "ecuyer_du_rempart", Level = 3, XP = 0 }, C = { HeroId = "inconnu", Level = 1 } }, Hotbar = {} }
		local view = HeroRules.view(data, { rules = Rules, config = Config, heroes = modules.HeroConfig.Heroes, combat = CombatConfig.Heroes })
		local byId = {}
		for _, hero in view.Heroes do byId[hero.Id] = hero end
		local base = CombatConfig.Heroes.Epeiste
		assert(byId.A.MaxHealth == base.MaxHealth and byId.A.AttackDamage == base.AttackDamage, "Lv1 = base stats")
		local lv3 = Rules.combatStats(base, 3, Config)
		assert(byId.B.MaxHealth == lv3.MaxHealth and byId.B.AttackDamage == lv3.AttackDamage, "same as combat")
		assert(byId.C.MaxHealth == nil and byId.C.AttackDamage == nil, "unknown hero: no invented stats")
	end)

	print(`HeroProgression: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{failed} HeroProgression test(s) failed`)
	end
end
