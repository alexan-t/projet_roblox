--!strict
-- Hors du dossier Services : jamais exécuté par le bootstrap.
-- Vérifie la vraie IconConfig contre docs/UI_DESIGN_SYSTEM.md § 7.

return function(iconConfig: any)
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

	-- Les sept icônes prioritaires qui manquaient (revue « Design et expérience » du 16 octobre).
	local PRIORITY = { "Collection", "Royaume", "Carte", "Parametres", "Coche", "Ultime", "Sacoche" }
	local GROUPS = { Classe = true, Objet = true, Navigation = true }

	test("ids unique, lookup consistent, groups known", function()
		local count = 0
		for _ in iconConfig.Icons do count += 1 end
		assert(count == #iconConfig.Ordered, `{count} Icons, {#iconConfig.Ordered} Ordered`)
		for _, info in iconConfig.Ordered do
			assert(iconConfig.Icons[info.Id] == info, info.Id)
			assert(GROUPS[info.Group], `{info.Id}: groupe {info.Group}`)
			assert(type(info.Name) == "string" and info.Name ~= "", info.Id)
			assert(type(info.Hook) == "string" and info.Hook ~= "", info.Id)
		end
	end)

	test("the 7 missing priority icons are catalogued", function()
		for _, id in PRIORITY do
			assert(iconConfig.Icons[id], `{id} absent`)
		end
	end)

	test("images are nil or an asset id; image() follows the catalogue", function()
		for _, info in iconConfig.Ordered do
			assert(info.Image == nil or string.match(info.Image, "^rbxassetid://%d+$"), `{info.Id}: image {info.Image}`)
			assert(iconConfig.image(info.Id) == info.Image, info.Id)
		end
		assert(iconConfig.image("Inconnue") == nil)
	end)

	test("catalogue is frozen", function()
		assert(table.isfrozen(iconConfig.Icons) and table.isfrozen(iconConfig.Ordered))
		assert(table.isfrozen(iconConfig.Ordered[1]))
		assert(not pcall(function() iconConfig.Ordered[1].Name = "x" end))
	end)

	print(`IconConfig: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{failed} IconConfig test(s) failed`)
	end
end
