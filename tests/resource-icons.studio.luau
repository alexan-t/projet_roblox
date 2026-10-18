-- Read-only audit. Pass the Git ResourceConfig evaluated in memory when Rojo is disconnected.
-- Execute in EDIT; do not create a Script or ModuleScript in the scene.
return function(config)
	assert(game.PlaceId == 120616399792561, "Expected test 3")
	local slots = workspace.Bestiaire.Inventaire.Ressources.Panneau.Affichage.Fond.Emplacements
	local count, delivered = 0, 0
	local missingIds = {}
	for _, child in slots:GetChildren() do
		if child:IsA("GuiObject") then
			count += 1
			local index = tonumber(child.Name:match("^Ressource_(%d+)$"))
			assert(index and config.Ordered[index], "Unexpected card: " .. child.Name)
		end
	end
	assert(count == 60, "Expected 60 cards")
	for _, info in config.Ordered do
		local card = slots:FindFirstChild(config.slotName(info.Index))
		assert(card, info.Id .. ": missing card")
		assert(card:GetAttribute("ResourceId") == info.Id, info.Id .. ": ResourceId")
		assert(card:GetAttribute("Index") == info.Index, info.Id .. ": Index")
		assert(card:GetAttribute("Famille") == config.FamilyNames[info.Family], info.Id .. ": Famille")
		assert(card.Nom.Text == info.Name, info.Id .. ": Nom")
		assert(card.Illustration.Icone.Image == (info.Icon or ""), info.Id .. ": Image != Git")
		assert(card:GetAttribute("AssetId") == (info.Icon or ""), info.Id .. ": AssetId != Git")
		if info.Icon then
			delivered += 1
		else
			table.insert(missingIds, info.Id)
		end
	end
	local atelier = workspace:FindFirstChild("AtelierIcones")
	assert(atelier and #atelier:GetChildren() == 0, "AtelierIcones must be empty")
	local camera = workspace.CurrentCamera
	print(`PASS Studio: {count} cards match Git, {delivered} images, {count - delivered} empty; atelier empty`)
	return { cards = count, delivered = delivered, missing = count - delivered, missingIds = missingIds, cameraType = camera and tostring(camera.CameraType) }
end
