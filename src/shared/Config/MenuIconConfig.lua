--!strict
-- Icônes du menu principal (voir docs/TUTORIAL_GUIDANCE.md § Menu). SEULE source des AssetIds du menu :
-- aucun AssetId ailleurs (MenuView, MenuController, InfoView les lisent ici).
-- Source de vérité visuelle : le ZIP « Icones Menu » (PNG 512 x 512, fond transparent), publié tel quel,
-- sans retouche. Les SVG du ZIP ne servent que de source.
--   Icon      : icône normale (icons/png/<id>.png) ;
--   BadgeIcon : même icône avec le point d'exclamation intégré (icons/png/<id>-badge.png), état
--               « attention » (MenuController.SetAttention). Vide : pas de variante, l'icône normale reste.
-- Publier une nouvelle version : téléverser le PNG sur Roblox, coller ici « rbxassetid://<id> ».
-- Une valeur vide ("") n'affiche rien plutôt qu'un faux identifiant (jamais de rbxassetid inventé).

export type MenuIcon = { Icon: string, BadgeIcon: string }

local MenuIconConfig: { [string]: MenuIcon } = {
	Shop = {
		Icon = "rbxassetid://99196320622532", -- shop.png
		BadgeIcon = "rbxassetid://85826072680601", -- shop-badge.png
	},
	Bag = {
		Icon = "rbxassetid://136778535271316", -- bag.png
		BadgeIcon = "rbxassetid://90070653444659", -- bag-badge.png
	},
	Index = {
		Icon = "rbxassetid://110304348557255", -- index.png
		BadgeIcon = "rbxassetid://84939816948421", -- index-badge.png
	},
	Guild = {
		Icon = "rbxassetid://92005819130900", -- guild.png
		BadgeIcon = "rbxassetid://92733545672676", -- guild-badge.png
	},
	Stats = {
		Icon = "rbxassetid://120914669665094", -- stats.png
		BadgeIcon = "rbxassetid://94067632581322", -- stats-badge.png
	},
}

return table.freeze(MenuIconConfig)
