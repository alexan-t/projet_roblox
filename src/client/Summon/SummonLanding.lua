--!strict
-- Pose du héros invoqué (pur, testé par tools/test-presentation.ps1) — voir docs/SUMMON.md.
-- Contrat : sol praticable sous la place d'invocation (le dessus des marches du portail compris)
--   → dessus visible de la place d'invocation (disque de pierre + liseré, posés sur ce sol)
--   → bas visible du héros sur ce dessus, avec un minuscule écart (pas de z-fighting).
-- Aucune API Roblox : SummonEffectController fournit les hauteurs et les pièces touchées.

local SummonLanding = {}

-- Place d'invocation (deux cylindres couchés, centrés au-dessus du sol) : élévation du centre et
-- épaisseur de chaque disque (studs).
SummonLanding.Pad = table.freeze({
	StoneLift = 0.08,
	StoneThickness = 0.14,
	RimLift = 0.06,
	RimThickness = 0.12,
})
-- Écart entre le dessus de la place et les pieds (studs) : évite le z-fighting, invisible à l'œil.
SummonLanding.FootClearance = 0.05

-- Hauteur du dessus visible de la place posée sur un sol à la hauteur groundY.
function SummonLanding.padTop(groundY: number): number
	local pad = SummonLanding.Pad
	return groundY + math.max(pad.StoneLift + pad.StoneThickness / 2, pad.RimLift + pad.RimThickness / 2)
end

-- Hauteur où poser le bas visible du héros (ses pieds) : juste au-dessus de la place.
function SummonLanding.feetY(groundY: number): number
	return SummonLanding.padTop(groundY) + SummonLanding.FootClearance
end

-- Une pièce touchée par le rayon vers le sol arrête-t-elle la descente ? Seules les surfaces sur
-- lesquelles on marche et qu'on voit comptent : marches et socle du portail oui ; effets, pierres en
-- orbite, cristaux et pièces invisibles non (le rayon les traverse).
export type Hit = { CanCollide: boolean, Transparency: number }
function SummonLanding.isGround(hit: Hit): boolean
	return hit.CanCollide and hit.Transparency < 0.95
end

return SummonLanding
