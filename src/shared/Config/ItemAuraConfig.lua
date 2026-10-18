--!strict
-- Aura des items 2D (équipements, voir docs/ITEMS.md § 7) : fond teinté de la couleur de
-- rareté et effet animé autour de l'icône, de plus en plus impressionnant du rang 1 (Commun) au rang
-- 10 (Transcendant). Réglages seulement : les couleurs viennent de UITheme.Rarity (RarityStyle), le
-- rendu de src/client/UI/ItemAura.lua. Les monstres et les ressources n'ont aucune rareté, donc aucune
-- aura. Une ligne par palier de RarityConfig, dans le même ordre.
--   Fill     : transparence du fond teinté (plus bas = plus plein) ;
--   Stroke   : épaisseur du contour de rareté (px) ;
--   Sheen    : s entre deux reflets qui balaient le fond (plus bas = plus vif) ;
--   Halo     : nombre d'anneaux de lueur derrière l'icône (0 = aucun) ;
--   Reach    : taille du halo le plus large, en fois la taille de l'icône ;
--   Pulse    : s d'une respiration du halo (0 = immobile) ;
--   Rays     : couches de rayons qui tournent derrière l'icône (0, 1 ou 2) ;
--   Spin     : vitesse des rayons (degrés par seconde) ;
--   Sparkles : éclats qui scintillent autour de l'icône ;
--   Motes    : particules en orbite autour de l'icône ;
--   Dark     : 1 = ombre (Ink) plutôt que lumière (Maudit, docs/UI_DESIGN_SYSTEM.md § 2).

export type Aura = {
	Fill: number,
	Stroke: number,
	Sheen: number,
	Halo: number,
	Reach: number,
	Pulse: number,
	Rays: number,
	Spin: number,
	Sparkles: number,
	Motes: number,
	Dark: number,
}

local Tiers: { [string]: Aura } = {
	Commun = { Fill = 0.55, Stroke = 1, Sheen = 5, Halo = 0, Reach = 1, Pulse = 0, Rays = 0, Spin = 0, Sparkles = 0, Motes = 0, Dark = 0 },
	PeuCommun = { Fill = 0.5, Stroke = 2, Sheen = 4.5, Halo = 1, Reach = 1.15, Pulse = 2.6, Rays = 0, Spin = 0, Sparkles = 0, Motes = 0, Dark = 0 },
	Rare = { Fill = 0.45, Stroke = 2, Sheen = 4, Halo = 2, Reach = 1.25, Pulse = 2.4, Rays = 0, Spin = 0, Sparkles = 1, Motes = 0, Dark = 0 },
	Epique = { Fill = 0.4, Stroke = 2, Sheen = 3.5, Halo = 2, Reach = 1.35, Pulse = 2.2, Rays = 0, Spin = 0, Sparkles = 2, Motes = 0, Dark = 0 },
	Legendaire = { Fill = 0.35, Stroke = 3, Sheen = 3, Halo = 3, Reach = 1.45, Pulse = 2, Rays = 1, Spin = 20, Sparkles = 3, Motes = 0, Dark = 0 },
	Mythique = { Fill = 0.3, Stroke = 3, Sheen = 2.8, Halo = 3, Reach = 1.55, Pulse = 1.8, Rays = 1, Spin = 26, Sparkles = 4, Motes = 2, Dark = 0 },
	Maudit = { Fill = 0.25, Stroke = 3, Sheen = 2.6, Halo = 3, Reach = 1.6, Pulse = 1.7, Rays = 1, Spin = 28, Sparkles = 4, Motes = 3, Dark = 1 },
	Supreme = { Fill = 0.2, Stroke = 4, Sheen = 2.4, Halo = 4, Reach = 1.7, Pulse = 1.5, Rays = 2, Spin = 32, Sparkles = 5, Motes = 4, Dark = 0 },
	Calamite = { Fill = 0.15, Stroke = 4, Sheen = 2.2, Halo = 4, Reach = 1.8, Pulse = 1.3, Rays = 2, Spin = 40, Sparkles = 6, Motes = 5, Dark = 0 },
	Transcendant = { Fill = 0.1, Stroke = 4, Sheen = 2, Halo = 4, Reach = 1.9, Pulse = 1.1, Rays = 2, Spin = 48, Sparkles = 8, Motes = 6, Dark = 0 },
}
for _, aura in Tiers do
	table.freeze(aura)
end

local ItemAuraConfig = {
	Tiers = table.freeze(Tiers),
	-- Ombrage du fond teinté (multiplicateur bas du dégradé, haut = 1) et éclat du reflet (transparence).
	Shade = 0.72,
	SheenAlpha = 0.55,
	-- Amplitude de la respiration du halo (fraction de sa taille) et transparences de ses anneaux.
	PulseAmount = 0.06,
	HaloInner = 0.45,
	HaloOuter = 0.88,
	-- Transparence des rayons (couche 1, couche 2).
	RayAlpha = { 0.35, 0.55 },
	-- Une icône plus petite que Compact (px) garde une aura resserrée (listes, butin d'Expédition).
	Compact = 56,
	CompactSpread = 0.4,
}

-- Réglages d'une rareté (Id de RarityConfig) ; Commun si l'Id est inconnu.
function ItemAuraConfig.forRarity(id: string?): Aura
	return (if id then Tiers[id] else nil) or Tiers.Commun
end

return table.freeze(ItemAuraConfig)
