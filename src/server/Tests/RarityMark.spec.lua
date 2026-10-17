--!strict
-- Hors du dossier Services : jamais exécuté par le bootstrap.
-- Vérifie le second repère de rareté (UITheme.RarityMark) contre la vraie RarityConfig et
-- docs/UI_DESIGN_SYSTEM.md § 2 : chaque rareté se distingue sans sa couleur.
-- sources (facultatif, fourni par tools/test-ui-theme.ps1) : texte de la doc et de RarityStyle.lua,
-- pour vérifier que le tableau du § 2 et les formes dessinées suivent les tokens.

return function(uiTheme: any, rarityConfig: any, sources: { doc: string?, style: string? }?)
	local passed, failed, skipped = 0, 0, 0
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
	local function skip(name: string, reason: string)
		skipped += 1
		print("SKIP " .. name .. ": " .. reason)
	end

	local marks = uiTheme.RarityMark
	local docText = sources and sources.doc
	local styleText = sources and sources.style

	-- Formes dessinées par src/client/UI/RarityStyle.lua (table SHAPES), lues dans sa source si fournie.
	local SHAPES: { [string]: boolean } = {}
	if styleText then
		local block = string.match(styleText, "local SHAPES[^\n]*\n(.-)\n}")
		for line in string.gmatch(block or "", "[^\n]+") do
			local key = string.match(line, "^%s*(%w+)%s*=%s*{")
			if key then
				SHAPES[key] = true
			end
		end
	else
		SHAPES = { Circle = true, Diamond = true, Cross = true, Ring = true, Burst = true, Star = true }
	end

	-- Mot du tableau de la doc (§ 2) pour chaque forme.
	local SHAPE_WORDS = {
		Circle = "rond",
		Diamond = "losange",
		Cross = "croix",
		Ring = "anneau",
		Burst = "éclat",
		Star = "étoile",
	}

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
		assert(next(SHAPES), "no shape found in RarityStyle SHAPES")
		for id, mark in marks do
			assert(SHAPES[mark.Shape], `{id}: shape {tostring(mark.Shape)} not drawn by RarityStyle`)
			assert(type(mark.Count) == "number", `{id}: count is not a number`)
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

	test("a shape covers consecutive tiers, counting 1, 2, 3 upward", function()
		local last: { [string]: number } = {} -- forme -> rang du dernier palier qui l'utilise
		local count: { [string]: number } = {}
		for rank, tier in rarityConfig.Tiers do
			local mark = marks[tier.Id]
			local previous = last[mark.Shape]
			assert(previous == nil or previous == rank - 1, `{tier.Id}: {mark.Shape} is not contiguous`)
			local expected = (count[mark.Shape] or 0) + 1
			assert(mark.Count == expected, `{tier.Id}: {mark.Shape} count {mark.Count}, expected {expected}`)
			last[mark.Shape] = rank
			count[mark.Shape] = expected
		end
	end)

	test("close colors get different shapes (UI_DESIGN_SYSTEM § 2)", function()
		assert(marks.Epique.Shape ~= marks.Maudit.Shape, "Épique / Maudit")
		assert(marks.Calamite.Shape ~= marks.Mythique.Shape, "Calamité / Mythique")
		assert(marks.Rare.Shape ~= marks.Transcendant.Shape, "Rare / Transcendant")
		assert(marks.Commun.Shape ~= marks.Supreme.Shape, "Commun / Suprême")
	end)

	test("semantic colors (Error…) carry no rarity mark", function()
		for name in uiTheme.Colors do
			assert(marks[name] == nil or uiTheme.Rarity[name], `semantic color {name} has a mark`)
		end
		assert(marks.Error == nil, "Error has a mark")
		assert(marks.Calamite ~= nil, "Calamité has no mark (would read as Error)")
	end)

	test("marks are frozen", function()
		assert(table.isfrozen(marks), "RarityMark")
		for id, mark in marks do
			assert(table.isfrozen(mark), id)
		end
	end)

	if docText then
		test("UI_DESIGN_SYSTEM § 2 table matches RarityMark", function()
			local rows: { [string]: string } = {}
			for line in string.gmatch(docText, "[^\n]+") do
				line = string.gsub(line, "\r$", "")
				local name, cell = string.match(line, "^| ([^|]-) |.*| (%d [^|]-) |$")
				if name and cell then
					rows[name] = cell
				end
			end
			for _, tier in rarityConfig.Tiers do
				local cell = rows[tier.Name]
				assert(cell, `no row for {tier.Name}`)
				local mark = marks[tier.Id]
				local n = tonumber(string.match(cell, "^(%d)"))
				assert(n == mark.Count, `{tier.Name}: doc says {cell}, token count {mark.Count}`)
				local word = SHAPE_WORDS[mark.Shape]
				assert(word and string.find(cell, word, 1, true), `{tier.Name}: doc says {cell}, token {mark.Shape}`)
			end
		end)
	else
		skip("UI_DESIGN_SYSTEM § 2 table matches RarityMark", "doc text not provided")
	end

	print(`RarityMark: {passed} passed, {failed} failed, {skipped} skipped`)
	if failed > 0 then
		error(`{failed} RarityMark test(s) failed`)
	end
end
