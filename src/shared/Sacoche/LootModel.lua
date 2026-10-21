--!strict
-- Logique de l'écran de fin pour le butin (CombatEnded.Loot, issue #72), pure et testée
-- (tools/test-sacoche.ps1). Le butin n'est JAMAIS mélangé à CombatEnded.Rewards (monnaies) : il a sa propre
-- lecture, son propre bloc et sa propre mise en page. Le serveur n'envoie ni rareté ni nom : tout vient des
-- catalogues (ItemConfig, ResourceConfig). Une entrée inconnue ou invalide est ignorée.
--   parse(loot, ctx)        -> { Items, Best, MoreItems, Resources, Overflow, Empty }
--                              Best = l'équipement de plus haut rang (égalité : ordre du catalogue, puis InstanceId) ;
--                              MoreItems = nombre d'autres équipements (« +N équipements »)
--   chips(resources, slots) -> { Shown, More } : pastilles visibles ; si tout ne tient pas, la dernière place
--                              est une pastille « +N autres » (N = types de ressources masqués)
--   moreItemsText(n)        -> « +1 équipement » / « +2 équipements »
--   layout(input, pack)     -> positions (px du design, 1080) et HAUTEUR CALCULÉE du contenu
--   fit(viewport, size, pack) -> échelle sur les DEUX axes (jamais plus grande que la référence 1080)
-- Les mesures viennent d'UITheme.Pack.Reward (passé en argument : aucune valeur de style ici).

local InventoryModel = require(script.Parent.InventoryModel)

local LootModel = {}

export type Resource = { ResourceId: string, Name: string, Icon: string?, Amount: number, AmountText: string, Index: number }
export type Parsed = {
	Items: { InventoryModel.ItemCard },
	Best: InventoryModel.ItemCard?,
	MoreItems: number,
	Resources: { Resource },
	Overflow: boolean,
	Empty: boolean,
}
export type Context = {
	Items: { [string]: InventoryModel.ItemInfo },
	Resources: { [string]: InventoryModel.ResourceInfo },
	RankOf: (rarity: string?) -> number,
	SlotNames: { [string]: string },
}

function LootModel.parse(loot: any, ctx: Context): Parsed
	local parsed: Parsed = { Items = {}, Best = nil, MoreItems = 0, Resources = {}, Overflow = false, Empty = true }
	if typeof(loot) ~= "table" then
		return parsed
	end
	if typeof(loot.Items) == "table" then
		local entries = {}
		for _, entry in loot.Items do
			if typeof(entry) == "table" and typeof(entry.ItemId) == "string" then
				table.insert(entries, {
					InstanceId = if typeof(entry.InstanceId) == "string" then entry.InstanceId else "",
					ItemId = entry.ItemId,
					UpgradeLevel = 0,
				})
			end
		end
		-- même tri que la Sacoche (rareté décroissante, catalogue, InstanceId) : le premier est le meilleur
		local cards = InventoryModel.equipmentCards(entries, {
			Items = ctx.Items, RankOf = ctx.RankOf, SlotNames = ctx.SlotNames, Slot = "all",
		})
		parsed.Items = cards
		parsed.Best = cards[1]
		parsed.MoreItems = math.max(#cards - 1, 0)
	end
	if typeof(loot.Resources) == "table" then
		local rows: { InventoryModel.ResourceEntry } = {}
		for _, entry in loot.Resources do
			if typeof(entry) == "table" and typeof(entry.ResourceId) == "string" and typeof(entry.Amount) == "number" then
				table.insert(rows, { ResourceId = entry.ResourceId, Amount = entry.Amount })
			end
		end
		local families = {}
		local seen: { [string]: boolean } = {}
		for _, info in ctx.Resources do
			if not seen[info.Family] then
				seen[info.Family] = true
				table.insert(families, { Id = info.Family, Name = info.Family })
			end
		end
		local flat: { Resource } = {}
		for _, group in InventoryModel.resourceGroups(rows, { Resources = ctx.Resources, Families = families }) do
			for _, tile in group.Tiles do
				table.insert(flat, tile)
			end
		end
		-- ordre du catalogue (Index), toutes familles confondues
		table.sort(flat, function(a: Resource, b: Resource): boolean
			return a.Index < b.Index
		end)
		parsed.Resources = flat
	end
	parsed.Overflow = loot.Overflow == true
	parsed.Empty = #parsed.Items == 0 and #parsed.Resources == 0 and not parsed.Overflow
	return parsed
end

-- `slots` = nombre de places de la ligne (pastilles + éventuelle pastille « +N autres »).
function LootModel.chips(resources: { Resource }, slots: number): { Shown: { Resource }, More: number }
	local total = #resources
	local capacity = math.max(math.floor(slots), 1)
	local shown: { Resource } = {}
	if total <= capacity then
		for _, resource in resources do
			table.insert(shown, resource)
		end
		return { Shown = shown, More = 0 }
	end
	local visible = math.max(capacity - 1, 0)
	for index = 1, visible do
		table.insert(shown, resources[index])
	end
	return { Shown = shown, More = total - visible }
end

-- Nombre de pastilles (+N compris) qui tiennent sur une ligne.
function LootModel.chipSlots(pack: any): number
	return math.max(math.floor((pack.ChipRowWidth + pack.ChipGap) / (pack.ChipSize.X + pack.ChipGap)), 1)
end

function LootModel.moreItemsText(count: number): string
	return if count == 1 then "+1 équipement" else `+{count} équipements`
end

function LootModel.moreResourcesText(count: number): string
	return `+{count} autres`
end

export type LayoutInput = {
	Cards: number, -- cartes de monnaie (CombatEnded.Rewards)
	Heroes: number, -- héros engagés (victoire)
	Band: boolean, -- carte « meilleur objet »
	Chips: number, -- pastilles affichées (« +N autres » comprise)
	Caption: boolean, -- « Ajoutées à ta Sacoche »
	Note: boolean, -- message de dépassement (Overflow)
}
export type Layout = {
	Width: number, Height: number, TitleY: number, CardsY: number,
	LootY: number, LootHeight: number, BandY: number, ChipsY: number, CaptionY: number, NoteY: number,
	HeroesY: number, HeroesHeight: number, HeroRows: number, HeroPerRow: number, ButtonY: number,
}

-- Ordre vertical : titre, cartes de monnaie, butin (objet, pastilles, légende, message), héros, bouton. Sans
-- butin, les positions sont celles de l'écran d'avant (cartes et héros inchangés).
function LootModel.layout(input: LayoutInput, pack: any): Layout
	local y = pack.TitleY + pack.BelowTitle
	local cardsY = y
	if input.Cards > 0 then
		y += pack.CardSize.Y + pack.AfterCards
	end
	local lootY = y
	local gap = pack.LootGap
	local bandY, chipsY, captionY, noteY = 0, 0, 0, 0
	local cursor = 0
	if input.Band then
		bandY = lootY + cursor
		cursor += pack.BandSize.Y + gap
	end
	if input.Chips > 0 then
		chipsY = lootY + cursor
		cursor += pack.ChipSize.Y + gap
	end
	if input.Caption then
		captionY = lootY + cursor
		cursor += pack.CaptionHeight + gap
	end
	if input.Note then
		noteY = lootY + cursor
		cursor += pack.NoteHeight + gap
	end
	local lootHeight = if cursor > 0 then cursor - gap else 0
	if lootHeight > 0 then
		y += lootHeight + pack.AfterLoot
	end
	-- héros sur une seule ligne, de taille identique : l'écran s'élargit (l'échelle tient compte de la largeur)
	local perRow = math.max(input.Heroes, 1)
	local rows = if input.Heroes > 0 then 1 else 0
	local heroesWidth = perRow * pack.HeroChip.X + (perRow - 1) * pack.HeroGap
	local width = math.max(pack.Width, if rows > 0 then heroesWidth + 2 * pack.SideMargin else 0)
	local heroesY = y
	local heroesHeight = 0
	if rows > 0 then
		heroesHeight = pack.HeroHeading + rows * pack.HeroChip.Y + (rows - 1) * pack.HeroGap
		y += heroesHeight
	end
	local buttonY = y + pack.ButtonGap
	local height = math.max(pack.MinHeight, buttonY + pack.BottomPad)
	return {
		Width = width, Height = height, TitleY = pack.TitleY, CardsY = cardsY,
		LootY = lootY, LootHeight = lootHeight, BandY = bandY, ChipsY = chipsY, CaptionY = captionY, NoteY = noteY,
		HeroesY = heroesY, HeroesHeight = heroesHeight, HeroRows = rows, HeroPerRow = perRow, ButtonY = buttonY,
	}
end

-- Échelle : la référence (écran de 1080 px de haut), réduite si le contenu ne tient pas dans la fenêtre sur
-- l'un OU l'autre axe (marge de chaque côté). Jamais en dessous de MinScale.
function LootModel.fit(viewport: Vector2, size: Vector2, pack: any): number
	return LootModel.place(viewport, size, pack, 0, viewport.Y).Scale
end

-- Échelle et centre vertical (px écran) du contenu dans la zone libre : bas du HUD du haut (top) → haut de
-- la hotbar (bottom), marge de chaque côté.
-- Zone trop étroite pour le contenu à MinScale (téléphone en paysage, HUD inconnu) : le contenu prend tout
-- l'écran, Overlap = true (l'écran de fin masque alors EXPLICITEMENT la hotbar, jamais un chevauchement
-- silencieux), et l'échelle peut descendre jusqu'à FloorScale pour ne jamais sortir de l'écran.
function LootModel.place(viewport: Vector2, size: Vector2, pack: any, top: number, bottom: number): { Scale: number, Y: number, Overlap: boolean }
	local zoneTop = math.max(top, 0) + pack.Margin
	local zoneBottom = math.min(bottom, viewport.Y) - pack.Margin
	local overlap = zoneBottom - zoneTop < size.Y * pack.MinScale
	if overlap then
		zoneTop, zoneBottom = pack.Margin, viewport.Y - pack.Margin
	end
	local reference = math.clamp(viewport.Y / pack.ReferenceHeight, pack.MinScale, pack.MaxScale)
	local byHeight = (zoneBottom - zoneTop) / math.max(size.Y, 1)
	local byWidth = (viewport.X - 2 * pack.Margin) / math.max(size.X, 1)
	-- écran trop étroit pour le contenu à MinScale (portrait) : même plancher, pour ne jamais sortir de l'écran
	local narrow = size.X * pack.MinScale > viewport.X - 2 * pack.Margin
	local floor = if overlap or narrow then pack.FloorScale else pack.MinScale
	return { Scale = math.max(math.min(reference, byHeight, byWidth), floor), Y = (zoneTop + zoneBottom) / 2, Overlap = overlap }
end

-- Taille de texte (px avant échelle) pour qu'un petit texte du butin fasse au moins MinText px réels.
-- La compensation s'arrête à MinScale (les boîtes du butin sont dimensionnées pour ce pire cas) : sous
-- MinScale (repli Overlap, téléphone), les textes restent proportionnels et peuvent passer sous MinText.
function LootModel.textSize(base: number, scale: number, pack: any): number
	return math.max(base, math.ceil(pack.MinText / math.max(scale, pack.MinScale)))
end

return LootModel
