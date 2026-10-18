--!strict
-- Icônes de la fenêtre Expédition (design figé : Expedition.dc.html, assets/expedition) — SEULE source de
-- leurs AssetIds (aucun dans ExpeditionView). PNG 128 px du ZIP, fond transparent, publiés tels quels ;
-- les SVG ne sont que la source. Les portraits du ZIP (slime, gobelin, roi_orc) étaient PROVISOIRES :
-- remplacés par les vrais modèles (ReplicatedStorage.Assets.Combat) dans des ViewportFrame.
-- Une valeur vide ("") n'affiche rien plutôt qu'un faux identifiant (jamais de rbxassetid inventé).

local ExpeditionVisualConfig = table.freeze({
	Check = "rbxassetid://87532215089778", -- check.png : stage terminé, récompense déjà obtenue
	Crown = "rbxassetid://91640787453984", -- crown.png : onglet et badge Élite
	Lock = "rbxassetid://101511208524771", -- lock.png : stage / onglet Élite verrouillé, Lancer impossible
	Skull = "rbxassetid://81154695607902", -- skull.png : badge Boss, carte 1-5
	Swords = "rbxassetid://90581754137697", -- swords.png : stage normal, onglet Normal, titre
	XP = "rbxassetid://81389523268612", -- xp.png : récompense XP des héros
})

return ExpeditionVisualConfig
