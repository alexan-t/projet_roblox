--!strict
-- Hors du dossier Services : jamais exécuté par le bootstrap.
-- Vérifie la vraie ResourceConfig contre la répartition de docs/RESOURCES.md § 2.

return function(resourceConfig: any)
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

	-- docs/RESOURCES.md § 2 : 6 familles de 10, dans cet ordre.
	local FAMILIES = { "foret", "slime", "horde", "mine", "arcane", "royaume" }
	local PER_FAMILY = 10

	test("60 resources resource_001..resource_060, Index and lookup consistent", function()
		assert(#resourceConfig.Ordered == 60, `{#resourceConfig.Ordered} ressources`)
		local count = 0
		for _ in resourceConfig.Resources do count += 1 end
		assert(count == 60, `{count} ResourceIds`)
		for index, info in resourceConfig.Ordered do
			assert(info.Index == index, info.Id)
			assert(info.Id == string.format("resource_%03d", index), info.Id)
			assert(resourceConfig.Resources[info.Id] == info, info.Id)
			assert(resourceConfig.slotName(index) == string.format("Ressource_%03d", index))
		end
		assert(resourceConfig.slotName(36) == "Ressource_036")
	end)

	test("families are known, in RESOURCES.md order, contiguous tiers of 10", function()
		assert(#resourceConfig.Families == #FAMILIES, `{#resourceConfig.Families} familles`)
		for index, family in resourceConfig.Families do
			assert(family.Id == FAMILIES[index], `famille {index} : {family.Id}`)
			assert(resourceConfig.FamilyNames[family.Id] == family.Name)
		end
		for index, info in resourceConfig.Ordered do
			local expected = FAMILIES[(index - 1) // PER_FAMILY + 1]
			assert(info.Family == expected, `{info.Id}: famille {info.Family}, attendu {expected}`)
		end
	end)

	test("no rarity: resources carry no rarity field", function()
		for _, info in resourceConfig.Ordered do
			assert((info :: any).Rarity == nil, `{info.Id}: rareté inventée`)
		end
	end)

	test("names are set and unique; icons are nil or an asset id", function()
		local seen = {}
		for _, info in resourceConfig.Ordered do
			assert(type(info.Name) == "string" and info.Name ~= "", info.Id)
			assert(not seen[info.Name], `{info.Id}: nom en double {info.Name}`)
			seen[info.Name] = true
			assert(info.Icon == nil or string.match(info.Icon, "^rbxassetid://%d+$"), `{info.Id}: icône {info.Icon}`)
		end
	end)

	test("catalogue is frozen", function()
		assert(table.isfrozen(resourceConfig.Resources) and table.isfrozen(resourceConfig.Ordered))
		assert(table.isfrozen(resourceConfig.Ordered[1]) and table.isfrozen(resourceConfig.Families[1]))
		assert(not pcall(function() resourceConfig.Ordered[1].Name = "x" end))
	end)

	print(`ResourceConfig: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{failed} ResourceConfig test(s) failed`)
	end
end
