--!strict
-- Visuels des monnaies (pack « Monnaies » validé) — SEULE source de leurs AssetIds et de leurs modèles 3D.
-- Les PNG sont publiés tels quels (fond transparent, aucune retouche) ; les SVG du pack ne sont que la source.
--   Small  : version simple, lisible sous 64 px (HUD des monnaies, récompenses des cartes de quête) ;
--   Normal : grande illustration (fenêtres, cartes de récompense) ;
--   Glow   : version avec halo et éclats (gain, reveal de récompense) ;
--   Model  : modèle 3D de ReplicatedStorage.Assets.Currencies (Studio, pas Git) pour les feedbacks
--            (CurrencyFx : vol vers le HUD, rotation, rebond). Le modèle n'est QU'UN feedback client.
--   Label  : nom affiché ; Color : couleur du montant dans un reveal (UITheme.Colors).
-- Clés : celles des récompenses (QuestConfig.Rewards, RewardConfig : Gold, Gems, SummonTicket) ;
-- Currency : clé de PlayerData.Currencies (le ticket y est au pluriel : SummonTickets).
-- Une valeur vide ("") n'affiche rien plutôt qu'un faux identifiant (jamais de rbxassetid inventé).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)

export type Visual = {
	Small: string,
	Normal: string,
	Glow: string,
	Model: string,
	Label: string,
	Color: Color3,
	Currency: string,
}

local Kinds: { [string]: Visual } = {
	Gold = {
		Small = "rbxassetid://95445697266464", -- monnaies/png/or_small.png
		Normal = "rbxassetid://106378955368900", -- monnaies/png/or.png
		Glow = "rbxassetid://79206278048757", -- monnaies/png/or_glow.png
		Model = "Gold",
		Label = "Or",
		Color = UITheme.Colors.GoldLight,
		Currency = "Gold",
	},
	Gems = {
		Small = "rbxassetid://110862122720467", -- monnaies/png/gemme_small.png
		Normal = "rbxassetid://100395552667631", -- monnaies/png/gemme.png
		Glow = "rbxassetid://138886409284548", -- monnaies/png/gemme_glow.png
		Model = "Gems",
		Label = "Gemmes",
		Color = UITheme.Colors.CurrencyGems,
		Currency = "Gems",
	},
	SummonTicket = {
		Small = "rbxassetid://101743325337703", -- monnaies/png/ticket_small.png
		Normal = "rbxassetid://79324172992941", -- monnaies/png/ticket.png
		Glow = "rbxassetid://89196569897472", -- monnaies/png/ticket_glow.png
		Model = "SummonTicket",
		Label = "Ticket",
		Color = UITheme.Colors.TicketLight,
		Currency = "SummonTickets",
	},
}

local CurrencyVisualConfig = {
	Kinds = Kinds,
	-- Ordre d'affichage dans le HUD (de gauche à droite).
	Order = { "Gold", "Gems", "SummonTicket" },
}

-- Visuel d'une récompense (Gold, Gems, SummonTicket) OU d'une clé de PlayerData.Currencies (SummonTickets),
-- nil si inconnue.
function CurrencyVisualConfig.visual(kind: any): Visual?
	if typeof(kind) ~= "string" then
		return nil
	end
	local direct = Kinds[kind]
	if direct then
		return direct
	end
	for _, visual in Kinds do
		if visual.Currency == kind then
			return visual
		end
	end
	return nil
end

-- Clé de récompense (Gold, Gems, SummonTicket) d'une clé de PlayerData.Currencies, ou nil.
function CurrencyVisualConfig.kindOf(currency: any): string?
	for kind, visual in Kinds do
		if visual.Currency == currency or kind == currency then
			return kind
		end
	end
	return nil
end

return CurrencyVisualConfig
