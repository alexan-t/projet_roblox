--!strict
-- Hors du dossier Services : jamais exécuté par le bootstrap.
-- Teste le vrai ArenaPrep (préparation dans le monde, touche E) avec des doubles explicites de
-- ZoneService (session de stage), HeroService (possession) et CombatService.

return function(ArenaPrep: any)
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
		local env: any = { stages = {}, nextStage = 0, started = 0, cancelledStages = 0, combats = {}, cancelledCombats = 0, owned = {}, refuseStage = nil }
		env.A = { Name = "A" }
		env.B = { Name = "B" }
		env.owned[env.A] = { H1 = "Archer", H2 = "Epeiste", H3 = "Barbare", H4 = "Paladin", H5 = "Magicien", H6 = "Tireur" }
		env.owned[env.B] = { B1 = "Archer", B2 = "Paladin" }
		env.manager = ArenaPrep.new({
			maxHeroes = 4,
			name = function(p: any): string return p.Name end,
			startStage = function(p: any): (number?, string?)
				if env.refuseStage then return nil, env.refuseStage end
				env.nextStage += 1
				env.started += 1
				env.stages[p] = env.nextStage
				return env.nextStage, nil
			end,
			sessionAlive = function(p: any, id: number): boolean return env.stages[p] == id end,
			cancelStage = function(p: any)
				env.stages[p] = nil
				env.cancelledStages += 1
			end,
			heroOf = function(p: any, id: any): (string?, string?)
				local heroes = env.owned[p]
				local heroId = if heroes and typeof(id) == "string" then heroes[id] else nil
				if heroId then return heroId, nil end
				return nil, "héros inconnu"
			end,
			startCombat = function(p: any, sessionId: number, classes: any): (number?, string?)
				table.insert(env.combats, { player = p, sessionId = sessionId, classes = classes })
				return #env.combats, nil
			end,
			cancelCombat = function(_p: any) env.cancelledCombats += 1 end,
		})
		return env
	end
	local function count(t: any): number
		local n = 0
		for _ in t do n += 1 end
		return n
	end

	-- Placement --------------------------------------------------------------

	test("3. valid cell: hero placed, arena reserved, stage session started once", function()
		local e = fixture()
		assert(e.manager:place(e.A, 2, "H1") == true)
		local prep = e.manager.current
		assert(prep and prep.player == e.A and prep.phase == "Placement" and prep.formation[2] == "H1")
		assert(e.manager:place(e.A, 5, "H2") == true and e.started == 1, "one stage session for the whole preparation")
	end)

	test("4. invalid cell refused, nothing reserved", function()
		local e = fixture()
		for _, bad in { 0, 10, 2.5, "3", {} } :: { any } do
			local ok, reason = e.manager:place(e.A, bad, "H1")
			assert(ok == false and reason == "case invalide")
		end
		assert(e.manager.current == nil and e.started == 0)
	end)

	test("5. unknown or not owned hero refused (another player's hero included)", function()
		local e = fixture()
		for _, bad in { "Dragon", "B1", 42, "" } :: { any } do
			local ok, reason = e.manager:place(e.A, 1, bad)
			assert(ok == false and reason == "héros inconnu", tostring(bad))
		end
		assert(e.manager.current == nil and e.started == 0)
	end)

	test("6. same hero twice: moved, never duplicated", function()
		local e = fixture()
		e.manager:place(e.A, 1, "H1")
		assert(e.manager:place(e.A, 8, "H1") == true)
		local f = e.manager.current.formation
		assert(f[1] == nil and f[8] == "H1" and count(f) == 1)
	end)

	test("7-8. four heroes OK; a fifth on an empty cell refused; replacing stays allowed", function()
		local e = fixture()
		for slot, id in { [1] = "H1", [2] = "H2", [3] = "H3", [5] = "H4" } do
			assert(e.manager:place(e.A, slot, id) == true)
		end
		local ok, reason = e.manager:place(e.A, 9, "H5")
		assert(ok == false and reason == "4 héros maximum" and e.manager.current.formation[9] == nil)
		assert(e.manager:place(e.A, 5, "H5") == true, "replace on an occupied cell")
		local f = e.manager.current.formation
		assert(f[5] == "H5" and count(f) == 4)
	end)

	test("9. remove: back to 3/4; removing the last hero frees the arena and cancels the stage", function()
		local e = fixture()
		for slot, id in { [1] = "H1", [2] = "H2", [3] = "H3", [5] = "H4" } do e.manager:place(e.A, slot, id) end
		assert(e.manager:remove(e.A, 2) == true and count(e.manager.current.formation) == 3)
		local ok, reason = e.manager:remove(e.A, 2)
		assert(ok == false and reason == "case vide")
		for _, slot in { 1, 3, 5 } do e.manager:remove(e.A, slot) end
		assert(e.manager.current == nil and e.cancelledStages == 1 and e.stages[e.A] == nil)
	end)

	test("10. reposition a placed hero onto another cell", function()
		local e = fixture()
		e.manager:place(e.A, 1, "H1")
		e.manager:place(e.A, 2, "H2")
		assert(e.manager:place(e.A, 9, "H2") == true)
		local f = e.manager.current.formation
		assert(f[1] == "H1" and f[2] == nil and f[9] == "H2")
	end)

	test("11. no placement, move or removal once the combat started", function()
		local e = fixture()
		e.manager:place(e.A, 1, "H1")
		assert(e.manager:fight(e.A) == true)
		for _, attempt in {
			{ e.manager:place(e.A, 2, "H2") },
			{ e.manager:place(e.A, 4, "H1") },
			{ e.manager:remove(e.A, 1) },
		} do
			assert(attempt[1] == false and attempt[2] == "combat déjà lancé")
		end
		assert(e.manager.current.formation[1] == "H1" and count(e.manager.current.formation) == 1)
	end)

	test("12. player B can never change A's preparation; B gets the arena once A is done", function()
		local e = fixture()
		e.manager:place(e.A, 1, "H1")
		for _, attempt in {
			{ e.manager:place(e.B, 2, "B1") },
			{ e.manager:place(e.B, 1, "B1") },
			{ e.manager:remove(e.B, 1) },
			{ e.manager:fight(e.B) },
		} do
			assert(attempt[1] == false and attempt[2] == "Arène occupée par A")
		end
		assert(e.manager:leave(e.B) == false)
		assert(e.manager.current.player == e.A and e.manager.current.formation[1] == "H1" and #e.combats == 0)
		e.manager:fight(e.A)
		assert(e.manager:combatEnded(e.A, 1) == true and e.manager.current == nil)
		assert(e.manager:place(e.B, 3, "B2") == true and e.manager.current.player == e.B)
	end)

	-- Touche E -----------------------------------------------------------------

	test("13. E with no hero placed is refused", function()
		local e = fixture()
		local ok, reason = e.manager:fight(e.A)
		assert(ok == false and reason == "Place au moins un héros" and #e.combats == 0)
	end)

	test("14. E with a valid formation starts the combat at once (slot -> HeroId, same stage session)", function()
		local e = fixture()
		e.manager:place(e.A, 2, "H1")
		e.manager:place(e.A, 5, "H4")
		assert(e.manager:fight(e.A) == true)
		assert(#e.combats == 1)
		local combat = e.combats[1]
		assert(combat.player == e.A and combat.sessionId == e.stages[e.A])
		assert(combat.classes[2] == "Archer" and combat.classes[5] == "Paladin" and count(combat.classes) == 2)
		assert(e.manager.current.phase == "Combat" and e.manager.current.combatId == 1)
	end)

	test("15. E never opens a selection: no preparation, no stage session, nothing started", function()
		local e = fixture()
		e.manager:fight(e.A)
		e.manager:fight(e.B)
		assert(e.manager.current == nil and e.started == 0 and #e.combats == 0)
	end)

	test("16. double E: a single combat session", function()
		local e = fixture()
		e.manager:place(e.A, 1, "H1")
		assert(e.manager:fight(e.A) == true)
		local ok, reason = e.manager:fight(e.A)
		assert(ok == false and reason == "combat déjà lancé" and #e.combats == 1)
	end)

	-- Cycle de vie -------------------------------------------------------------

	test("hero lost before E: combat refused, nothing started", function()
		local e = fixture()
		e.manager:place(e.A, 1, "H1")
		e.owned[e.A].H1 = nil
		local ok, reason = e.manager:fight(e.A)
		assert(ok == false and reason == "héros inconnu" and #e.combats == 0)
	end)

	test("stage refused: no reservation; stage session lost: arena freed", function()
		local e = fixture()
		e.refuseStage = "zone verrouillée"
		local ok, reason = e.manager:place(e.A, 1, "H1")
		assert(ok == false and reason == "zone verrouillée" and e.manager.current == nil)
		e.refuseStage = nil
		e.manager:place(e.A, 1, "H1")
		e.stages[e.A] = nil -- fin de session décidée ailleurs (debug, profil)
		assert(e.manager:check() == true and e.manager.current == nil)
		assert(e.manager:place(e.B, 1, "B1") == true, "B can take the freed arena")
	end)

	test("leave during combat: combat and stage cancelled, arena freed; combat end of an old combat ignored", function()
		local e = fixture()
		e.manager:place(e.A, 1, "H1")
		e.manager:fight(e.A)
		assert(e.manager:leave(e.A) == true)
		assert(e.cancelledCombats == 1 and e.cancelledStages == 1 and e.manager.current == nil)
		e.manager:place(e.A, 2, "H2")
		e.manager:fight(e.A)
		assert(e.manager:combatEnded(e.A, 1) == false and e.manager.current ~= nil, "old combat id ignored")
		assert(e.manager:release(e.A) == true and e.manager.current == nil)
	end)

	print(`ArenaPrep: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{failed} ArenaPrep test(s) failed`)
	end
end
