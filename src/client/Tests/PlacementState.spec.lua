--!strict
-- Hors du dossier Controllers : jamais exécuté par le bootstrap client.
-- Teste le vrai PlacementState (héros « en main ») : hotbar, sacoche > Placer, clic sur une case.

return function(PlacementState: any)
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

	local HOTBAR = { "H1", "H2", "H3", "", "", "", "", "", "", "H10" }

	test("1. hotbar key: the hero is in hand (placement mode)", function()
		local s = PlacementState.new()
		assert(PlacementState.selectHotbar(s, 1, HOTBAR, {}) == true)
		assert(s.held and s.held.instanceId == "H1" and s.held.fromSlot == nil)
		assert(PlacementState.selectHotbar(s, 10, HOTBAR, {}) and s.held.instanceId == "H10", "key 0 = 10th shortcut")
	end)

	test("1b. same key again puts the hero back; empty shortcut empties the hand", function()
		local s = PlacementState.new()
		PlacementState.selectHotbar(s, 2, HOTBAR, {})
		assert(PlacementState.selectHotbar(s, 2, HOTBAR, {}) == false and s.held == nil)
		PlacementState.selectHotbar(s, 2, HOTBAR, {})
		assert(PlacementState.selectHotbar(s, 5, HOTBAR, {}) == false and s.held == nil)
	end)

	test("2. collection > Placer: exactly the same mode as the hotbar", function()
		local a, b = PlacementState.new(), PlacementState.new()
		PlacementState.selectHotbar(a, 3, HOTBAR, {})
		assert(PlacementState.selectCollection(b, "H3", {}) == true)
		assert(a.held.instanceId == b.held.instanceId and a.held.fromSlot == b.held.fromSlot)
		assert(PlacementState.selectCollection(b, "H3", {}) == true and b.held ~= nil, "Placer twice keeps it in hand")
	end)

	test("3. click a cell with a hero in hand: Place request, hand emptied", function()
		local s = PlacementState.new()
		PlacementState.selectHotbar(s, 1, HOTBAR, {})
		local request = PlacementState.clickCase(s, 2, {})
		assert(request and request.Action == "Place" and request.Slot == 2 and request.HeroInstanceId == "H1")
		assert(s.held == nil)
	end)

	test("click a cell with nothing in hand: nothing sent; a placed hero is picked up", function()
		local s = PlacementState.new()
		assert(PlacementState.clickCase(s, 4, {}) == nil and s.held == nil)
		assert(PlacementState.clickCase(s, 4, { [4] = "H2" }) == nil)
		assert(s.held and s.held.instanceId == "H2" and s.held.fromSlot == 4)
	end)

	test("10. move: pick up a placed hero, click another cell; same cell = put back", function()
		local s = PlacementState.new()
		local formation = { [4] = "H2" }
		PlacementState.clickCase(s, 4, formation)
		local request = PlacementState.clickCase(s, 7, formation)
		assert(request and request.Action == "Place" and request.Slot == 7 and request.HeroInstanceId == "H2")
		PlacementState.clickCase(s, 4, formation)
		assert(PlacementState.clickCase(s, 4, formation) == nil and s.held == nil)
		PlacementState.selectHotbar(s, 2, HOTBAR, formation)
		assert(s.held.fromSlot == 4, "hotbar on a placed hero knows where it stands")
	end)

	test("9. remove the hero in hand from the arena (it stays in the hotbar)", function()
		local s = PlacementState.new()
		PlacementState.selectHotbar(s, 2, HOTBAR, { [6] = "H2" })
		local request = PlacementState.removeHeld(s)
		assert(request and request.Action == "Remove" and request.Slot == 6 and s.held == nil)
		PlacementState.selectHotbar(s, 1, HOTBAR, {})
		assert(PlacementState.removeHeld(s) == nil, "a hero that is not placed has nothing to remove")
		assert(HOTBAR[2] == "H2")
	end)

	test("11. combat locks the formation: nothing in hand, no request", function()
		local s = PlacementState.new()
		PlacementState.selectHotbar(s, 1, HOTBAR, {})
		PlacementState.setLocked(s, true)
		assert(s.held == nil)
		assert(PlacementState.selectHotbar(s, 1, HOTBAR, {}) == false and s.held == nil)
		assert(PlacementState.selectCollection(s, "H1", {}) == false)
		assert(PlacementState.clickCase(s, 1, { [1] = "H1" }) == nil and s.held == nil)
		PlacementState.setLocked(s, false)
		assert(PlacementState.selectHotbar(s, 1, HOTBAR, {}) == true)
	end)

	test("server answer: the held hero follows the real formation", function()
		local s = PlacementState.new()
		PlacementState.selectHotbar(s, 1, HOTBAR, {})
		PlacementState.syncFormation(s, { [3] = "H1" })
		assert(s.held.fromSlot == 3)
		PlacementState.syncFormation(s, {})
		assert(s.held.fromSlot == nil)
	end)

	print(`PlacementState: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{failed} PlacementState test(s) failed`)
	end
end
