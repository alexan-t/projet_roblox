--!strict
-- Icônes du menu principal (voir docs/TUTORIAL_GUIDANCE.md § Menu). SEULE source des AssetIds du menu :
-- aucun AssetId ailleurs (MenuView, MenuController, InfoView, QuestPanelView les lisent ici).
-- Source de vérité visuelle : le pack validé (ZIP « Icones Menu », PNG 512 x 512, fond transparent),
-- publié tel quel, sans retouche. Les SVG du pack ne servent que de source.
--   Buttons[id].Icon      : icône normale (icons/png/<id>.png) ;
--   Buttons[id].BadgeIcon : même icône avec le « ! » intégré (icons/png/<id>-badge.png). Publiée et gardée
--                           ici, mais la maquette (« Quêtes HUD ») affiche l'icône normale + Badge par-dessus ;
--   Badge                 : le « ! » seul (icons/png/badge.png), posé au coin de la tuile et qui flotte
--                           (état « attention », MenuController.SetAttention).
-- Publier une nouvelle version : téléverser le PNG sur Roblox, coller ici « rbxassetid://<id> ».
-- Une valeur vide ("") n'affiche rien plutôt qu'un faux identifiant (jamais de rbxassetid inventé).

export type MenuIcon = { Icon: string, BadgeIcon: string }

local MenuIconConfig = {
	Buttons = {
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
		Quest = {
			Icon = "rbxassetid://74149875739571", -- quest.png
			BadgeIcon = "rbxassetid://88273688024239", -- quest-badge.png
		},
	} :: { [string]: MenuIcon },
	Badge = "rbxassetid://136687332355384", -- badge.png
}

return MenuIconConfig
