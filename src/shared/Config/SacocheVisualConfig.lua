--!strict
-- Icônes propres à la fenêtre Sacoche (design figé : Sacoche.dc.html, assets/sacoche) — SEULE source de
-- leurs AssetIds (aucun dans HeroBarController). PNG 128 px du ZIP, fond transparent, publiés tels quels.
-- Réutilisées ailleurs, jamais dupliquées ici : icône Sac (MenuIconConfig.Buttons.Bag), coche « Posé »
-- (ExpeditionVisualConfig.Check), icônes d'items (ItemConfig.Items[id].Icon).
-- Les portraits du ZIP (ecuyer_v3, tireuse_v3) étaient PROVISOIRES : vrais modèles via UIKit.portrait.

local SacocheVisualConfig = table.freeze({
	-- Onglets (tab_*.png).
	Tabs = table.freeze({
		Heroes = "rbxassetid://93034773312821", -- tab_heros.png
		Equipment = "rbxassetid://113923797102021", -- tab_equipement.png
		Resources = "rbxassetid://111218878275942", -- tab_ressources.png
	}),
	-- Emplacements d'équipement vides (slot_*.png), posés à UITheme.Transparency.Disabled ; clés = ItemConfig.SlotTypes.
	Slots = table.freeze({
		weapon = "rbxassetid://91358948872694",
		helmet = "rbxassetid://119150253627022",
		armor = "rbxassetid://73137988937145",
		gloves = "rbxassetid://108939891155564",
		boots = "rbxassetid://108741255122841",
		accessory = "rbxassetid://111930769386469",
		relic = "rbxassetid://72597162415818",
	}),
	Hotbar = "rbxassetid://102231596141989", -- hotbar.png : action « raccourci » (secondaire)
	Search = "rbxassetid://77119765427865", -- search.png : loupe
	Health = "rbxassetid://140268540942115", -- heart.png : bloc PV
	Attack = "rbxassetid://123036272750493", -- sword.png : bloc ATK
})

return SacocheVisualConfig
