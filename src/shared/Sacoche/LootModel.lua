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
--   pack(viewport, reward)  -> mesures de la disposition : Pack.Reward (PC, tablette), surchargé par
--                              Pack.Reward.Phone sur téléphone (Device = "wide" | "phone")
--   layout(input, pack)     -> positions (px du design) et HAUTEUR CALCULÉE du contenu ; deux colonnes
--                              (monnaies + butin | héros + bouton) si pack.TwoColumns (téléphone)
--   fit(viewport, size, pack) -> échelle sur les DEUX axes (jamais plus grande que la référence 1080)
-- Les mesures viennent d'UITheme.Pack.Reward (passé en argument : aucune valeur de style ici).

local InventoryModel = require(script.Parent.InventoryModel)
local SacocheModel = require(script.Parent.SacocheModel)

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
	-- centres horizontaux (px du design) : une colonne = tous au centre ; téléphone = deux colonnes
	CardsX: number, LootX: number, HeroesX: number, HeroesWidth: number, ButtonX: number,
}

-- Disposition selon l'écran : téléphone (mêmes seuils que la Sacoche et l'Expédition, SacocheModel.device)
-- = mesures de base surchargées par pack.Phone ; PC et tablette = mesures de base. Device : "phone" | "wide".
function LootModel.pack(viewport: Vector2, pack: any): any
	local layout = table.clone(pack)
	layout.Phone = nil
	layout.Device = "wide"
	if pack.Phone and SacocheModel.device(viewport.X, viewport.Y) == "phone" then
		for key, value in pack.Phone do
			layout[key] = value
		end
		layout.Device = "phone"
	end
	return layout
end

-- Bloc butin empilé à partir de lootY : objet, pastilles, légende, message. Hauteur 0 sans butin.
local function lootStack(input: LayoutInput, pack: any, lootY: number): (number, number, number, number, number)
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
	return if cursor > 0 then cursor - gap else 0, bandY, chipsY, captionY, noteY
end

-- Héros : une seule ligne (PC, tablette) ou HeroPerRow par ligne (téléphone). Retourne par ligne, lignes, hauteur.
local function heroGrid(heroes: number, pack: any): (number, number, number)
	local perRow = if pack.HeroPerRow then math.clamp(heroes, 1, pack.HeroPerRow) else math.max(heroes, 1)
	local rows = if heroes > 0 then math.ceil(heroes / perRow) else 0
	local height = if rows > 0 then pack.HeroHeading + rows * pack.HeroChip.Y + (rows - 1) * pack.HeroGap else 0
	return perRow, rows, height
end

-- Téléphone (pack.TwoColumns) : titre, puis colonne gauche (monnaies, butin) et colonne droite (héros, puis
-- « Continuer » aligné sur le bas du contenu). Sans monnaie ni butin, la colonne droite est centrée.
local function twoColumns(input: LayoutInput, pack: any): Layout
	local bodyY = pack.TitleY + pack.BelowTitle
	local y = bodyY
	local left = 0
	if input.Cards > 0 then
		left = pack.CardSize.Y
		y += pack.CardSize.Y + pack.AfterCards
	end
	local lootHeight, bandY, chipsY, captionY, noteY = lootStack(input, pack, y)
	if lootHeight > 0 then
		left = y + lootHeight - bodyY
	end
	local perRow, rows, heroesHeight = heroGrid(input.Heroes, pack)
	local button = pack.ButtonSize.Y + pack.ButtonLip
	local right = heroesHeight + (if rows > 0 then pack.ButtonGap else 0) + button
	local body = math.max(left, right)
	local width = pack.Width
	local leftWidth = pack.ChipRowWidth
	local rightWidth = width - leftWidth - pack.ColumnGap
	local rightX = if left == 0 then width / 2 else leftWidth + pack.ColumnGap + rightWidth / 2
	return {
		Width = width, Height = math.max(pack.MinHeight, bodyY + body + pack.BottomPad), TitleY = pack.TitleY, CardsY = bodyY,
		LootY = y, LootHeight = lootHeight, BandY = bandY, ChipsY = chipsY, CaptionY = captionY, NoteY = noteY,
		HeroesY = bodyY, HeroesHeight = heroesHeight, HeroRows = rows, HeroPerRow = perRow, ButtonY = bodyY + body - button,
		CardsX = leftWidth / 2, LootX = leftWidth / 2, HeroesX = rightX, HeroesWidth = rightWidth, ButtonX = rightX,
	}
end

-- Ordre vertical : titre, cartes de monnaie, butin (objet, pastilles, légende, message), héros, bouton. Sans
-- butin, les positions sont celles de l'écran d'avant (cartes et héros inchangés).
function LootModel.layout(input: LayoutInput, pack: any): Layout
	if pack.TwoColumns then
		return twoColumns(input, pack)
	end
	local y = pack.TitleY + pack.BelowTitle
	local cardsY = y
	if input.Cards > 0 then
		y += pack.CardSize.Y + pack.AfterCards
	end
	local lootY = y
	local lootHeight, bandY, chipsY, captionY, noteY = lootStack(input, pack, lootY)
	if lootHeight > 0 then
		y += lootHeight + pack.AfterLoot
	end
	-- héros sur une seule ligne, de taille identique : l'écran s'élargit (l'échelle tient compte de la largeur)
	local perRow, rows, heroesHeight = heroGrid(input.Heroes, pack)
	local heroesWidth = perRow * pack.HeroChip.X + (perRow - 1) * pack.HeroGap
	local width = math.max(pack.Width, if rows > 0 then heroesWidth + 2 * pack.SideMargin else 0)
	local heroesY = y
	y += heroesHeight
	local buttonY = y + pack.ButtonGap
	local height = math.max(pack.MinHeight, buttonY + pack.BottomPad)
	return {
		Width = width, Height = height, TitleY = pack.TitleY, CardsY = cardsY,
		LootY = lootY, LootHeight = lootHeight, BandY = bandY, ChipsY = chipsY, CaptionY = captionY, NoteY = noteY,
		HeroesY = heroesY, HeroesHeight = heroesHeight, HeroRows = rows, HeroPerRow = perRow, ButtonY = buttonY,
		CardsX = width / 2, LootX = width / 2, HeroesX = width / 2, HeroesWidth = width - 2 * pack.SideMargin, ButtonX = width / 2,
	}
end

-- Échelle : la référence (écran de 1080 px de haut), réduite si le contenu ne tient pas dans la fenêtre sur
-- l'un OU l'autre axe (marge de chaque côté). Jamais en dessous de MinScale.
function LootModel.fit(viewport: Vector2, size: Vector2, pack: any): number
	return LootModel.place(viewport, size, pack, 0, viewport.Y).Scale
end

-- Échelle et centre vertical (px écran) du contenu dans la zone libre : bas du HUD du haut (top) → haut de
-- la hotbar (bottom), marge de chaque côté.
-- Zone trop étroite pour le contenu à MinScale (téléphone en paysage, HUD inconnu) : Overlap = true, le
-- contenu descend jusqu'au bas de l'écran (l'écran de fin masque alors EXPLICITEMENT la hotbar, jamais un
-- chevauchement silencieux) en restant sous les monnaies s'il y tient à MinScale, sinon il prend tout
-- l'écran ; l'échelle peut descendre jusqu'à FloorScale pour ne jamais sortir de l'écran.
function LootModel.place(viewport: Vector2, size: Vector2, pack: any, top: number, bottom: number): { Scale: number, Y: number, Overlap: boolean }
	local zoneTop = math.max(top, 0) + pack.Margin
	local zoneBottom = math.min(bottom, viewport.Y) - pack.Margin
	local overlap = zoneBottom - zoneTop < size.Y * pack.MinScale
	if overlap then
		zoneBottom = viewport.Y - pack.Margin
		if zoneBottom - zoneTop < size.Y * pack.MinScale then
			zoneTop = pack.Margin
		end
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
