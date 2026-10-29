--!strict
-- Logique d'affichage de la Sacoche (maquette figée « Sacoche.dc.html »), pure et testée
-- (tools/test-sacoche.ps1). Aucune donnée de jeu inventée : tout vient des vues du serveur (HeroesChanged :
-- niveau, XP, PV, ATK par exemplaire ; ArenaState : formation ; hotbar) et de HeroConfig.
--   device(w, h)                  -> "pc" | "tablet" | "phone" (mêmes seuils que la fenêtre Expédition)
--   frame(viewport, top, bottom, window, margin, minScale, maxScale)
--                                 -> { X, Y, Scale } : centre horizontal de l'écran, centre vertical de la
--                                    zone libre [top, bottom] (bas du HUD du haut → haut de la hotbar),
--                                    échelle pour y tenir. Jamais de position gauche fixe.
--   short(name)                   -> premier mot du nom (« Tireuse des Faubourgs » → « Tireuse »)
--   cards(heroes, ctx)            -> cartes triées et filtrées (Tous / Posés / Raccourcis, recherche)
--   detail(hero, info, ctx)       -> fiche : nom, rareté, niveau, XP, PV / ATK, états, action principale
--                                    et action raccourci (secondaire)
--   keyLabel(index)               -> touche du raccourci (1..9, puis 0)

local SacocheModel = {}

export type Hero = { Id: string, HeroId: string, Level: number, XP: number?, XPToNext: number?, MaxLevel: number?,
	MaxHealth: number?, AttackDamage: number?, EquipmentBonus: any? }
export type Info = { Name: string, Rarity: string, Order: number }
export type Context = {
	Infos: { [string]: Info }, -- HeroConfig.Heroes
	Placed: { [string]: boolean }, -- exemplaires posés sur l'arène (formation du serveur)
	Hotbar: { string }, -- ordre du serveur ("" = vide)
	New: { [string]: boolean }?, -- exemplaires apparus depuis l'ouverture du jeu, pas encore vus
	Selected: string?,
	Filter: string?, -- "all" | "placed" | "hotbar"
	Query: string?,
	InCombat: boolean?,
	Busy: boolean?,
}
export type Card = { Id: string, HeroId: string, Level: number, Short: string, Name: string, Key: string?,
	Edge: string?, Selected: boolean, New: boolean, Placed: boolean }
export type Action = { Label: string, Action: string, Enabled: boolean, Breathe: boolean }
export type Detail = {
	Id: string, HeroId: string, Name: string, Rarity: string, Level: number,
	XP: number, XPToNext: number, XPText: string, XPRatio: number, Max: boolean,
	MaxHealth: number?, AttackDamage: number?,
	HealthBonus: number, AttackBonus: number, -- part d'équipement des stats finales (#73), 0 sans équipement
	Placed: boolean, Key: string?, States: { { Kind: string, Label: string } },
	Primary: Action, Secondary: Action,
}

function SacocheModel.device(width: number, height: number): string
	if height < 520 then
		return "phone"
	end
	if width < 1300 or width / math.max(height, 1) < 1.5 then
		return "tablet"
	end
	return "pc"
end

-- Fenêtre centrée : X = milieu de l'écran ; Y = milieu de la zone libre entre `top` (bas du HUD du haut)
-- et `bottom` (haut de la hotbar), marges comprises ; échelle = ce qui tient dans cette zone.
function SacocheModel.frame(viewport: Vector2, top: number, bottom: number, window: Vector2, margin: number,
	minScale: number, maxScale: number): { X: number, Y: number, Scale: number }
	local width: number, height: number = viewport.X, viewport.Y
	local winW: number, winH: number = window.X, window.Y
	local zoneTop = math.max(top, 0) + margin
	local zoneBottom = math.min(bottom, height) - margin
	if zoneBottom - zoneTop < winH * minScale then
		-- zone trop étroite (HUD inconnu, écran minuscule) : tout l'écran, marges comprises
		zoneTop, zoneBottom = margin, height - margin
	end
	local scale = math.min((zoneBottom - zoneTop) / winH, (width - 2 * margin) / winW)
	scale = math.clamp(scale, minScale, maxScale)
	return { X = width / 2, Y = (zoneTop + zoneBottom) / 2, Scale = scale }
end

function SacocheModel.keyLabel(index: number?): string?
	if not index then
		return nil
	end
	return tostring(index % 10)
end

function SacocheModel.short(name: string): string
	return string.match(name, "^[^%s]+") or name
end

-- Recherche sans casse ni accents (« ecuyer » trouve « Écuyer ») : string.lower ignore l'UTF-8.
local ACCENTS = {
	["à"] = "a", ["â"] = "a", ["ä"] = "a", ["À"] = "a", ["Â"] = "a", ["Ä"] = "a",
	["é"] = "e", ["è"] = "e", ["ê"] = "e", ["ë"] = "e", ["É"] = "e", ["È"] = "e", ["Ê"] = "e", ["Ë"] = "e",
	["î"] = "i", ["ï"] = "i", ["Î"] = "i", ["Ï"] = "i", ["ô"] = "o", ["ö"] = "o", ["Ô"] = "o", ["Ö"] = "o",
	["ù"] = "u", ["û"] = "u", ["ü"] = "u", ["Ù"] = "u", ["Û"] = "u", ["Ü"] = "u", ["ç"] = "c", ["Ç"] = "c",
	["œ"] = "oe", ["Œ"] = "oe", ["’"] = "'",
}
local function lower(text: string): string
	local folded = string.gsub(text, utf8.charpattern, function(char: string): string
		return ACCENTS[char] or char
	end)
	return string.lower(folded)
end

function SacocheModel.cards(heroes: { [string]: Hero }, ctx: Context): { Card }
	local list: { Card } = {}
	local filter = ctx.Filter or "all"
	local query = if ctx.Query then lower((ctx.Query:gsub("^%s+", ""):gsub("%s+$", ""))) else ""
	for id, hero in heroes do
		local info = ctx.Infos[hero.HeroId]
		local name = if info then info.Name else hero.HeroId
		local placed = ctx.Placed[id] == true
		local slot = table.find(ctx.Hotbar, id)
		local keep = (filter == "all") or (filter == "placed" and placed) or (filter == "hotbar" and slot ~= nil)
		if keep and query ~= "" then
			keep = string.find(lower(name), query, 1, true) ~= nil
		end
		if keep then
			local new = ctx.New ~= nil and ctx.New[id] == true
			table.insert(list, {
				Id = id, HeroId = hero.HeroId, Level = hero.Level, Name = name, Short = SacocheModel.short(name),
				Key = SacocheModel.keyLabel(slot),
				Edge = if new then "Nouveau" elseif placed then "Posé" else nil,
				Selected = ctx.Selected == id, New = new, Placed = placed,
			})
		end
	end
	-- ordre du catalogue (HeroConfig.Order), puis niveau décroissant, puis exemplaire (stable)
	table.sort(list, function(a: Card, b: Card): boolean
		local ia, ib = ctx.Infos[a.HeroId], ctx.Infos[b.HeroId]
		local oa, ob = if ia then ia.Order else math.huge, if ib then ib.Order else math.huge
		if oa ~= ob then
			return oa < ob
		end
		if a.Level ~= b.Level then
			return a.Level > b.Level
		end
		return a.Id < b.Id
	end)
	return list
end

-- Bonus d'équipement envoyé par le serveur (#73) : entier, 0 si absent ou invalide.
local function bonusOf(bonus: any, key: string): number
	local value = if typeof(bonus) == "table" then bonus[key] else nil
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return 0
	end
	return math.floor(value + 0.5)
end

function SacocheModel.detail(hero: Hero, info: Info?, ctx: Context): Detail
	local placed = ctx.Placed[hero.Id] == true
	local key = SacocheModel.keyLabel(table.find(ctx.Hotbar, hero.Id))
	local need = hero.XPToNext or 0
	local xp = hero.XP or 0
	local max = hero.MaxLevel ~= nil and hero.Level >= hero.MaxLevel
	local states = { if placed then { Kind = "Placed", Label = "Posé dans l'arène" } else { Kind = "Free", Label = "Disponible" } }
	if key then
		table.insert(states, { Kind = "Hotbar", Label = `Raccourci {key}` })
	end
	local locked = ctx.InCombat == true
	-- UNE action principale : Placer (héros libre) ou Retirer de l'arène (héros posé, requête « Remove »)
	local primary: Action = if locked then { Label = "Combat en cours", Action = "None", Enabled = false, Breathe = false }
		elseif placed then { Label = "Retirer de l'arène", Action = "Remove", Enabled = ctx.Busy ~= true, Breathe = false }
		else { Label = "Placer", Action = "Place", Enabled = ctx.Busy ~= true, Breathe = true }
	-- action secondaire : le raccourci (ajouter → choisir une case ; retirer)
	local secondary: Action = if key then { Label = "Retirer du raccourci", Action = "ClearHotbar", Enabled = ctx.Busy ~= true, Breathe = false }
		else { Label = "Ajouter au raccourci", Action = "PickHotbar", Enabled = ctx.Busy ~= true, Breathe = false }
	return {
		Id = hero.Id, HeroId = hero.HeroId, Name = if info then info.Name else hero.HeroId,
		Rarity = if info then info.Rarity else "Commun", Level = hero.Level,
		XP = xp, XPToNext = need, Max = max,
		XPText = if max then "Niveau max" elseif need > 0 then `{xp} / {need}` else "",
		XPRatio = if max then 1 elseif need > 0 then math.clamp(xp / need, 0, 1) else 0,
		MaxHealth = hero.MaxHealth, AttackDamage = hero.AttackDamage,
		HealthBonus = bonusOf(hero.EquipmentBonus, "MaxHealth"), AttackBonus = bonusOf(hero.EquipmentBonus, "AttackDamage"),
		Placed = placed, Key = key, States = states, Primary = primary, Secondary = secondary,
	}
end

return SacocheModel
