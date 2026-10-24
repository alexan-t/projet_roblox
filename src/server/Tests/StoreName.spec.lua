--!strict
-- Règle du nom de store (src/server/Data/StoreName.lua) : jamais le profil de travail pendant une recette.
return function(storeName: (boolean, any) -> string)
	local failures = 0
	local function check(label: string, got: string, expected: string)
		if got == expected then
			print(`PASS {label}`)
		else
			failures += 1
			print(`FAIL {label} : {got} au lieu de {expected}`)
		end
	end

	check("jeu publié : toujours le store des joueurs", storeName(false, nil), "PlayerData")
	check("jeu publié : l'attribut de recette est ignoré", storeName(false, "Lot96"), "PlayerData")
	check("Studio sans recette : profil de travail", storeName(true, nil), "PlayerData_Studio")
	check("Studio, attribut vide : profil de travail", storeName(true, ""), "PlayerData_Studio")
	check("Studio, recette nommée", storeName(true, "Recette96"), "PlayerData_Recette_Recette96")
	check("Studio, tirets et chiffres", storeName(true, "lot-pilote_2"), "PlayerData_Recette_lot-pilote_2")
	check("Studio, nom invalide : store de recette générique", storeName(true, "a b"), "PlayerData_Recette")
	check("Studio, nom trop long : store de recette générique", storeName(true, string.rep("x", 33)), "PlayerData_Recette")
	check("Studio, valeur non texte : store de recette générique", storeName(true, 42), "PlayerData_Recette")

	if failures > 0 then
		error(`{failures} test(s) StoreName en échec`)
	end
end
