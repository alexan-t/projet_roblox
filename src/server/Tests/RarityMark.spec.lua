--!strict
-- Hors du dossier Services : jamais exécuté par le bootstrap.
-- Vérifie le second repère de rareté (UITheme.RarityMark) contre la vraie RarityConfig et
-- docs/UI_DESIGN_SYSTEM.md § 2 : chaque rareté se distingue sans sa couleur.

return function(uiTheme: any, rarityConfig: any)
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

	-- Formes dessinées par src/client/UI/RarityStyle.lua (SHAPES).
	local SHAPES = { Circle = true, Diamond = true, Cross = true, Ring = true, Burst = true, Star = true }
	local marks = uiTheme.RarityMark

	test("every RarityConfig tier has a mark, and no mark without a tier", function()
		for _, tier in rarityConfig.Tiers do
			assert(marks[tier.Id], `no mark for {tier.Id}`)
			assert(uiTheme.Rarity[tier.Id], `no color for {tier.Id}`)
		end
		for id in marks do
			assert(rarityConfig.tier(id), `mark for unknown rarity {id}`)
		end
	end)

	test("marks use known shapes, 1 to 3 times", function()
		for id, mark in marks do
			assert(SHAPES[mark.Shape], `{id}: unknown shape {tostring(mark.Shape)}`)
			assert(mark.Count >= 1 and mark.Count <= 3 and mark.Count % 1 == 0, `{id}: count {mark.Count}`)
		end
	end)

	test("every (shape, count) pair is unique", function()
		local seen = {}
		for id, mark in marks do
			local key = `{mark.Shape}x{mark.Count}`
			assert(not seen[key], `{id} and {seen[key]} share {key}`)
			seen[key] = id
		end
	end)

	test("close colors get different shapes (UI_DESIGN_SYSTEM § 2)", function()
		assert(marks.Epique.Shape ~= marks.Maudit.Shape, "Épique / Maudit")
		assert(marks.Calamite.Shape ~= marks.Mythique.Shape, "Calamité / Mythique")
		assert(marks.Rare.Shape ~= marks.Transcendant.Shape, "Rare / Transcendant")
		assert(marks.Commun.Shape ~= marks.Supreme.Shape, "Commun / Suprême")
	end)

	test("marks are frozen", function()
		assert(table.isfrozen(marks), "RarityMark")
		for id, mark in marks do
			assert(table.isfrozen(mark), id)
		end
	end)

	print(`RarityMark: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{failed} RarityMark test(s) failed`)
	end
end
