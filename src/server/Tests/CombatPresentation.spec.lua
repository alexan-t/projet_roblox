--!strict
-- Jamais exécuté par le jeu : lancé par tools/test-presentation.ps1.
-- Teste les modules purs de la mise en scène du combat (docs/COMBAT_PRESENTATION.md) : la vraie
-- EnemyPresentationConfig, la garde du sac (RewardBagGuard),
-- l'outro de fin de combat (OutroGate), le guidage de quête (QuestGuide) et la pose du héros invoqué
-- (SummonLanding).

return function(Config: any, RewardBagGuard: any, OutroGate: any, QuestGuide: any, vector: any, SummonLanding: any, OnboardingView: any)
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

	------------------------------------------------------------------ profils

	test("profiles: Slime / Gobelin / Boss resolve to their family styles, unknown falls back to Default", function()
		local slime = Config.profile("Slime")
		assert(slime.Family == "Slime" and slime.SpawnStyle == "Lake" and slime.AttackStyle == "SlimeHeadbutt" and slime.DeathStyle == "SlimeBurst")
		local gobelin = Config.profile("Gobelin")
		assert(gobelin.Family == "Goblin" and gobelin.SpawnStyle == "Camp" and gobelin.AttackStyle == "SpearThrust" and gobelin.DeathStyle == "HumanoidFall")
		local boss = Config.profile("Boss")
		assert(boss.SpawnStyle == "CampBoss" and boss.AttackStyle == "HeavyWeapon" and boss.DeathStyle == "HumanoidFallHeavy")
		assert(Config.profile("Dragon") == Config.Default and Config.profile(nil) == Config.Default and Config.profile(5) == Config.Default)
	end)

	test("profiles: every profile uses a known spawn style, attack and death style; impacts are early", function()
		local attacks = { SlimeHeadbutt = true, SpearThrust = true, HeavyWeapon = true, Animation = true }
		local deaths = { SlimeBurst = true, HumanoidFall = true, HumanoidFallHeavy = true, Dissolve = true }
		local function check(profile: any)
			assert(Config.SpawnStyles[profile.SpawnStyle], profile.SpawnStyle)
			assert(attacks[profile.AttackStyle], profile.AttackStyle)
			assert(deaths[profile.DeathStyle], profile.DeathStyle)
			assert(profile.Impact == nil or (profile.Impact > 0 and profile.Impact < 1), "impact")
		end
		for _, profile in Config.Profiles do
			check(profile)
		end
		check(Config.Default)
		assert(Config.Profiles.Gobelin.Impact == 0.45, "spear thrust key of Assets.Animations.Gobelin.Attaque")
		assert(table.isfrozen(Config.Profiles) and table.isfrozen(Config.Profiles.Slime) and table.isfrozen(Config.SpawnStyles))
	end)

	test("origins: Lake takes the ponds, Camp the camp in preference order, CampBoss the ramp", function()
		-- les 11 repères réels d'un plot (Arene.Zones.Zone1_PlaineDuRoyaume.SourcesEnnemis), triés par nom
		local sources = {
			{ Name = "BordPlateau1", Mode = "SautPlateau" }, { Name = "BordPlateau2", Mode = "SautPlateau" },
			{ Name = "BuissonEst", Mode = "SortieBuisson" }, { Name = "BuissonMare", Mode = "SortieBuisson" },
			{ Name = "BuissonOuest", Mode = "SortieBuisson" }, { Name = "FrontEnnemi", Mode = nil },
			{ Name = "HautRampe", Mode = "DescenteRampe" }, { Name = "MareFond", Mode = "SautMare" },
			{ Name = "MareGrande", Mode = "SautMare" }, { Name = "MareMilieu", Mode = "SautMare" },
			{ Name = "SommetTour", Mode = "SautTour" }, { Name = "Tente", Mode = "SortieTente" },
		}
		local function names(indexes: { number }): string
			local list = {}
			for _, i in indexes do
				table.insert(list, sources[i].Name)
			end
			return table.concat(list, ",")
		end
		assert(names(Config.sourcesFor(Config.SpawnStyles.Lake, sources)) == "MareFond,MareGrande,MareMilieu")
		assert(names(Config.sourcesFor(Config.SpawnStyles.Camp, sources)) == "Tente,HautRampe,BordPlateau1,BordPlateau2")
		assert(names(Config.sourcesFor(Config.SpawnStyles.CampBoss, sources)) == "HautRampe,Tente")
		assert(Config.spawnStyle(Config.Default) == Config.SpawnStyles.Bush)
		-- aucun repère du style : n'importe quel repère du décor (jamais FrontEnnemi, qui n'a pas de Mode)
		local fallback = Config.sourcesFor(Config.SpawnStyles.Lake, { { Name = "Tente", Mode = "SortieTente" }, { Name = "FrontEnnemi" } })
		assert(#fallback == 1 and fallback[1] == 1)
		assert(#Config.sourcesFor(Config.SpawnStyles.Lake, {}) == 0)
	end)

	test("effect color: model attribute (Color3) wins, else profile, else water", function()
		local slime = Config.profile("Slime")
		assert(Config.effectColor(nil, slime) == slime.EffectColor)
		assert(Config.effectColor("bleu", slime) == slime.EffectColor, "a non-Color3 attribute is ignored")
		assert(Config.effectColor(nil, Config.profile("Gobelin")) == Config.Palette.Water)
	end)

	------------------------------------------------------------------ sac

	local function position(tag: string): any
		return { tag = tag }
	end

	test("bag: one bag per won combat, at the LAST enemy death position", function()
		local guard = RewardBagGuard.new()
		local where = { [3] = position("slime"), [4] = position("gobelin"), [9] = position("hero") }
		local function at(id: number): any
			return where[id]
		end
		assert(guard:observe(1, { { Type = "UnitDied", UnitId = 3, Team = "Enemy" } }, at) == nil, "not on a death alone")
		assert(guard:observe(1, { { Type = "UnitDied", UnitId = 9, Team = "Ally" } }, at) == nil, "hero deaths do not count")
		local drop = guard:observe(1, { { Type = "UnitDied", UnitId = 4, Team = "Enemy" }, { Type = "CombatEnded", Result = "Victory" } }, at)
		assert(drop and drop.tag == "gobelin", "last enemy")
		assert(guard:observe(1, { { Type = "CombatEnded", Result = "Victory" } }, at) == nil, "never twice for the same combat")
	end)

	test("bag: never on defeat; CombatEnded in a later batch still drops once; each combat is separate", function()
		local guard = RewardBagGuard.new()
		local function at(id: number): any
			return position(tostring(id))
		end
		guard:observe(1, { { Type = "UnitDied", UnitId = 5, Team = "Enemy" } }, at)
		assert(guard:observe(1, { { Type = "CombatEnded", Result = "Defeat" } }, at) == nil, "no bag on defeat")
		guard:observe(2, { { Type = "UnitDied", UnitId = 7, Team = "Enemy" } }, at)
		local drop = guard:observe(2, { { Type = "CombatEnded", Result = "Victory" } }, at)
		assert(drop and drop.tag == "7", "victory announced in a later batch")
		assert(guard:observe(3, { { Type = "CombatEnded", Result = "Victory" } }, at) == nil, "no enemy died: no bag")
		-- rafale : deux morts et la fin dans le même lot
		local burst = guard:observe(4, {
			{ Type = "UnitDied", UnitId = 11, Team = "Enemy" },
			{ Type = "UnitDied", UnitId = 12, Team = "Enemy" },
			{ Type = "CombatEnded", Result = "Victory" },
			{ Type = "CombatEnded", Result = "Victory" },
		}, at)
		assert(burst and burst.tag == "12", "burst: last death, one bag")
	end)

	------------------------------------------------------------------ outro

	local OUTRO = Config.Outro

	test("outro: death timings are ordered (body down, then bag, then fade) for every family", function()
		for id, profile in Config.Profiles do
			local t = profile.DeathTiming
			assert(t and t.BagDrop > 0 and t.FadeStart <= t.Complete, id)
			assert(t.GroundImpact == nil or t.BagDrop >= t.GroundImpact, id .. ": bag after the body touches the ground")
		end
		local goblin = Config.Profiles.Gobelin.DeathTiming
		assert(goblin.FadeStart >= goblin.BagDrop + OUTRO.BagBounce, "the goblin fades only after the bag bounced")
		local boss = Config.Profiles.Boss.DeathTiming
		assert(boss.FadeStart >= boss.BagDrop + OUTRO.BagBounce and boss.GroundImpact > goblin.GroundImpact, "boss falls heavier")
	end)

	test("outro: victory = bag after the last death, bounce, breather, VICTOIRE, then the screen (3 s or more)", function()
		local goblin = Config.Profiles.Gobelin.DeathTiming
		local schedule = OutroGate.schedule(true, { bagAt = 100 + goblin.BagDrop, completeAt = 100 + goblin.Complete }, 100, OUTRO)
		assert(schedule.bagAt == 100 + goblin.BagDrop)
		assert(schedule.victoryAt == schedule.bagAt + OUTRO.BagBounce + OUTRO.Breather)
		assert(schedule.finishAt == schedule.victoryAt + OUTRO.VictoryHold)
		local total = schedule.finishAt - 100
		assert(total >= 3 and total <= 3.8, `goblin outro {total}`)
		local slime = Config.Profiles.Slime.DeathTiming
		local quick = OutroGate.schedule(true, { bagAt = 10 + slime.BagDrop, completeAt = 10 + slime.Complete }, 10, OUTRO)
		assert(quick.finishAt - 10 >= 2.5, "even a slime gives a breather before the screen")
		local late = OutroGate.schedule(true, { bagAt = 5, completeAt = 6 }, 9, OUTRO)
		assert(late.bagAt == 9, "never in the past")
	end)

	test("outro: defeat = no bag, no VICTOIRE, short hold after the last death", function()
		local schedule = OutroGate.schedule(false, { bagAt = 3, completeAt = 4 }, 2, OUTRO)
		assert(schedule.bagAt == nil and schedule.victoryAt == nil)
		assert(schedule.finishAt == 4 + OUTRO.DefeatHold)
	end)

	test("gate: the reward screen waits for the outro, opens once; either order works", function()
		local gate = OutroGate.new()
		assert(gate:ended(1, { Result = "Victory" }, 0) == nil, "blocked while the outro plays")
		local shown = gate:outroFinished(1)
		assert(shown and shown.Result == "Victory")
		assert(gate:outroFinished(1) == nil and gate:ended(1, { Result = "Victory" }, 1) == nil, "never twice")
		assert(gate:outroFinished(2) == nil, "outro finished before CombatEnded")
		local late = gate:ended(2, { Result = "Defeat" }, 5)
		assert(late and late.Result == "Defeat")
	end)

	test("gate: safety timeout opens a stuck screen once, never early", function()
		local gate = OutroGate.new()
		gate:ended(3, { Result = "Victory" }, 0)
		assert(#gate:expired(OUTRO.Safety - 0.1, OUTRO.Safety) == 0, "not before the safety delay")
		local due = gate:expired(OUTRO.Safety, OUTRO.Safety)
		assert(#due == 1 and due[1].combatId == 3)
		assert(#gate:expired(100, OUTRO.Safety) == 0 and gate:outroFinished(3) == nil, "shown once")
		gate:ended(4, { Result = "Victory" }, 0)
		gate:clear()
		assert(#gate:expired(100, OUTRO.Safety) == 0, "cleared: nothing pending")
	end)

	------------------------------------------------------------------ guidage de quête

	local function inst(name: string, children: { any }?): any
		local node: any = { Name = name, children = children or {} }
		function node:FindFirstChild(child: string): any
			for _, c in self.children do
				if c.Name == child then
					return c
				end
			end
			return nil
		end
		return node
	end
	local function plot(name: string): any
		return inst(name, {
			inst("Arene", { inst("PanneauStage", { inst("Banniere") }), inst("Emplacements", { inst("Heros") }) }),
			inst("PortailInvocation"),
			inst("Royaume"),
		})
	end

	test("guide: targets resolve inside the given plot only (Plot isolation)", function()
		local mine, other = plot("Plot_1"), plot("Plot_2")
		local sign, focus = QuestGuide.resolve(mine, "StageSign")
		assert(sign == mine.children[1].children[1] and focus == sign.children[1], "PanneauStage -> Banniere of MY plot")
		assert(QuestGuide.resolve(other, "StageSign") ~= sign, "another plot gives another sign")
		assert(QuestGuide.resolve(mine, "SummonPortal") == mine.children[2])
		assert(QuestGuide.resolve(mine, "Kingdom") == mine.children[3])
		assert(QuestGuide.resolve(mine, "HeroPlacement") == mine.children[1].children[2].children[1])
		assert(QuestGuide.resolve(nil, "StageSign") == nil, "no plot yet: nothing")
		assert(QuestGuide.resolve(inst("Plot_3"), "StageSign") == nil, "plot without arena: nothing")
	end)

	test("guide: no unknown target (PlotTravail, typos, non-strings)", function()
		for _, name in { "PlotTravail", "stagesign", "", 5 } do
			assert(not QuestGuide.isTarget(name), tostring(name))
			assert(QuestGuide.resolve(plot("Plot_1"), name) == nil)
		end
		assert(not QuestGuide.isTarget(nil))
		for name in QuestGuide.Targets do
			assert(QuestGuide.isTarget(name))
		end
	end)

	test("guide: hidden during combat, intro, CTA, reward / summon screens, after completion; Near close to the target", function()
		local base = { target = "StageSign", completed = false, combat = false, presentation = "Idle", screen = nil, distance = 40 }
		local function with(changes: any): string
			local c = table.clone(base)
			for k, v in changes do
				c[k] = v
			end
			return QuestGuide.mode(c)
		end
		assert(with({}) == "Path")
		assert(with({ combat = true }) == "Hidden")
		for _, state in { "EnemyIntro", "AwaitingDefense", "Combat", "Reward" } do
			assert(with({ presentation = state }) == "Hidden", state)
		end
		for _, screen in { "Reward", "Summon", "Stage" } do
			assert(with({ screen = screen }) == "Hidden", screen)
		end
		assert(with({ completed = true }) == "Hidden", "quest done: no path")
		assert(QuestGuide.mode({ target = nil, combat = false }) == "Hidden", "no guide")
		assert(with({ distance = QuestGuide.Targets.StageSign.Arrive }) == "Near", "arrived: target only")
		local noDistance = table.clone(base)
		noDistance.distance = nil
		assert(QuestGuide.mode(noDistance) == "Hidden", "no character")
		assert(with({ presentation = "WaitingForArenaEntry" }) == "Path", "Lancer pressed but outside: keep guiding")
	end)

	test("guide: marks are evenly spaced along the path, skip the player, capped in number", function()
		local points = { vector(0, 0, 0), vector(10, 0, 0), vector(10, 0, 30) }
		local marks = QuestGuide.sample(points, 3, 2, 12)
		assert(#marks == 12, `{#marks}`)
		assert(marks[1].position.X == 2 and marks[2].position.X == 5)
		assert(marks[4].position.Z == 1 and marks[4].direction.Z == 1, "turns the corner")
		local short = QuestGuide.sample({ vector(0, 0, 0), vector(4, 0, 0) }, 3, 2, 12)
		assert(#short == 1, "short path: few marks")
	end)

	------------------------------------------------------------------ invocation : pose au sol

	test("summoned hero sits above the pad surface: feet = pad top + tiny clearance (0.03..0.08)", function()
		local pad = SummonLanding.Pad
		for _, groundY in { 0, 3.6, 4.38, -12.5 } do
			local stoneTop = groundY + pad.StoneLift + pad.StoneThickness / 2
			local rimTop = groundY + pad.RimLift + pad.RimThickness / 2
			local top = SummonLanding.padTop(groundY)
			assert(math.abs(top - math.max(stoneTop, rimTop)) < 1e-9, "pad top = highest visible disc")
			local feet = SummonLanding.feetY(groundY)
			assert(feet > top and feet - top >= 0.03 and feet - top <= 0.08, `feet just above the pad ({feet - top})`)
		end
	end)

	test("summon ground: walkable visible surfaces stop the ray (portal steps), effects / invisible parts do not", function()
		assert(SummonLanding.isGround({ CanCollide = true, Transparency = 0 }), "portal step marche_1")
		assert(not SummonLanding.isGround({ CanCollide = false, Transparency = 0 }), "orbiting stone, effect")
		assert(not SummonLanding.isGround({ CanCollide = true, Transparency = 1 }), "invisible collider")
		-- cas réel mesuré en Studio : sol sous la marche 3,60, dessus de la marche 4,38
		assert(SummonLanding.feetY(4.38) > 4.38 and SummonLanding.feetY(4.38) - SummonLanding.feetY(3.6) > 0.7,
			"the hero now stands on the step instead of 0.78 stud inside it")
	end)

	------------------------------------------------------------------ onboarding : caméra du premier spawn

	test("onboarding camera: only during the onboarding quest, once per session (no replay after reset / death)", function()
		local onboarding = { Id = "SummonStarter", Onboarding = true, Completed = false }
		assert(OnboardingView.shouldPlay(onboarding, false) == true, "first spawn of a new player")
		assert(OnboardingView.shouldPlay(onboarding, true) == false, "reset / death: already played")
		assert(OnboardingView.shouldPlay({ Id = "DefendDomain", Onboarding = false }, false) == false, "tutorial already advanced")
		assert(OnboardingView.shouldPlay(nil, false) == false, "no quest (old player, chain over)")
		assert(OnboardingView.shouldPlay({ Onboarding = true, Completed = true }, false) == false)
		assert(OnboardingView.Duration >= 0.4 and OnboardingView.Duration <= 0.8, "short placement")
	end)

	test("onboarding camera: behind and above the character, looking toward its own arena", function()
		local root = vector(100, 5, 50)
		local arena = vector(100, 0, 0) -- arène au nord (-Z)
		local dir = OnboardingView.facing(root, arena)
		assert(dir and math.abs(dir.Z + 1) < 1e-9 and math.abs(dir.X) < 1e-9 and dir.Y == 0, "flat direction to the arena")
		local eye, look = OnboardingView.frame(root, dir)
		assert(eye.Z > root.Z and eye.Y > root.Y, "camera behind (away from the arena) and above")
		assert(look.Z < root.Z, "looks past the character toward the arena")
		assert(OnboardingView.facing(root, vector(100.1, 9, 50.1)) == nil, "target on the character: no direction")
	end)

	print(`CombatPresentation: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{failed} CombatPresentation test(s) failed`)
	end
end
