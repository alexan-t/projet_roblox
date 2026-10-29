--!strict
-- UNE seule fonction de carte d'équipement (issue #72) pour tout le client : grille de la Sacoche (variante
-- « Tile », carte crème) et écran de fin (variante « Band », bandeau bois du meilleur objet).
-- Règles de rareté (docs/UI_DESIGN_SYSTEM.md § 2, « Rendu des raretés ») :
--   - cadre extérieur NEUTRE (Ink) ; le contour de sélection et le badge du haut restent réservés à l'état
--     (« Nouveau », « Équipé : X » — #73) ; le bonus de l'objet (« +4 ATK ») est une ligne de texte ;
--   - la rareté est du TEXTE (ItemCard.rarityText -> RarityStyle.name), jamais une couleur seule ;
--   - POINT DE BASCULE UNIQUE pour #61 (zone d'illustration teintée) et #75 (RarityStyle.chip) : tout passe par
--     ItemCard.rarity(...) ; aucune autre vue ne dessine la rareté d'un item ;
--   - l'icône PNG n'est jamais teintée.
-- Les ressources n'ont aucune rareté : elles n'utilisent pas cette fonction (voir SacocheView, RewardScreen).
--   ItemCard.create(parent, card, options) -> Frame
--   ItemCard.icon(parent, card, size)      -> GuiObject  (icône du catalogue, sinon deux lettres)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local InventoryModel = require(ReplicatedStorage.Shared.Sacoche.InventoryModel)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local RarityStyle = require(script.Parent.RarityStyle)
local UIKit = require(script.Parent.UIKit)

local C = UITheme.Colors
local T = UITheme.Transparency

local ItemCard = {}

export type Options = {
	Variant: string, -- "Tile" | "Band"
	NameSize: number,
	LineSize: number,
	ArtSize: number, -- côté (Band) ou hauteur (Tile) de la zone d'illustration
	Head: string?, -- Band : petite mention au-dessus du nom
	Size: UDim2?,
	Width: number?, -- Tile : largeur de la cellule (px), pour borner le badge d'état
	BadgeSize: number?, -- Tile : taille du texte du badge d'état (défaut : Caption)
}

-- Texte de rareté d'un item. SEUL point de lecture de la rareté d'une carte d'item (voir en-tête).
function ItemCard.rarity(rarity: string): string
	return RarityStyle.name(rarity)
end

-- « Rare · Arme » : rareté en texte puis emplacement (bandeau de fin, détail de la Sacoche #73).
function ItemCard.rarityLine(card: InventoryModel.ItemCard): string
	return `{ItemCard.rarity(card.Rarity)} · {card.SlotName}`
end

-- Zone d'illustration : icône du catalogue (jamais teintée), sinon repli propre (deux lettres du nom).
function ItemCard.icon(parent: Instance, card: InventoryModel.ItemCard, size: number): GuiObject
	if card.Icon then
		local image = Instance.new("ImageLabel")
		image.Name = "Icone"
		image.BackgroundTransparency = 1
		image.Image = card.Icon
		image.ScaleType = Enum.ScaleType.Fit
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.Size = UDim2.fromOffset(size, size)
		image.Parent = parent
		return image
	end
	local fallback = UIKit.text(parent, InventoryModel.initials(card.Name), math.max(math.floor(size * 0.4), 14), { Color = C.WoodDark, Stroke = false })
	fallback.Name = "Icone"
	return fallback
end

local function artBox(parent: Instance): Frame
	local art = Instance.new("Frame")
	art.Name = "Illustration"
	art.BackgroundColor3 = C.Sand
	art.BackgroundTransparency = T.Art
	art.BorderSizePixel = 0
	art.ClipsDescendants = true
	art.Parent = parent
	UIKit.corner(art, UITheme.Radius.Small)
	return art
end

local function levelBadge(art: Frame, text: string)
	local badge = UIKit.badge(art, text, C.WoodDeep)
	badge.Name = "Niveau"
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.new(1, -4, 0, 4)
	badge.ZIndex = 3
	for _, child in badge:GetDescendants() do
		if child:IsA("GuiObject") then
			child.ZIndex = 4
		end
	end
end

-- Badge d'état à cheval sur le bord haut : largeur du texte, bornée à la carte (texte tronqué au besoin).
local function stateBadge(frame: Frame, content: string, color: Color3, options: Options)
	local size = options.BadgeSize or UITheme.Typography.Size.Caption
	local pad = UITheme.Spacing.S
	local measured = TextService:GetTextSize(content, size, Enum.Font.FredokaOne, Vector2.new(1000, 100)).X
	local width = measured + 2 * pad + 4
	if options.Width then
		width = math.min(width, options.Width - 8)
	end
	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.fromScale(0.5, 0)
	badge.Size = UDim2.fromOffset(math.max(width, 2 * UITheme.Spacing.M), size + 10)
	badge.BackgroundColor3 = color
	badge.ZIndex = 6
	badge.Parent = frame
	UIKit.corner(badge, UITheme.Radius.Pill)
	UIKit.stroke(badge, UITheme.Stroke.Thin)
	local label = UIKit.text(badge, content, size)
	label.Name = "Etat"
	label.Position = UDim2.fromOffset(pad, 0)
	label.Size = UDim2.new(1, -2 * pad, 1, 0)
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.ZIndex = 7
end

local function tile(parent: Instance, card: InventoryModel.ItemCard, options: Options): Frame
	local frame = Instance.new("Frame")
	frame.Name = card.InstanceId
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.Size = options.Size or UDim2.fromScale(1, 1)
	frame.Parent = parent
	UIKit.corner(frame, UITheme.Radius.Medium)
	UIKit.stroke(frame, UITheme.Stroke.Regular) -- cadre neutre : jamais la couleur de rareté
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(C.Cream, C.Sand)
	gradient.Parent = frame

	local art = artBox(frame)
	art.Position = UDim2.fromOffset(5, 5)
	art.Size = UDim2.new(1, -10, 0, options.ArtSize)
	ItemCard.icon(art, card, options.ArtSize - 10)
	if card.LevelText then
		levelBadge(art, card.LevelText)
	end

	local y = 5 + options.ArtSize + 3
	local nameHeight = math.ceil(options.NameSize * 1.15) * 2
	local name = UIKit.text(frame, card.Name, options.NameSize, { Color = C.InkSoft, Stroke = false })
	name.Name = "Nom"
	name.Position = UDim2.fromOffset(6, y)
	name.Size = UDim2.new(1, -12, 0, nameHeight)
	name.TextWrapped = true
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.TextYAlignment = Enum.TextYAlignment.Top
	y += nameHeight

	local lineHeight = math.ceil(options.LineSize * 1.2)
	local rarity = UIKit.text(frame, ItemCard.rarity(card.Rarity), options.LineSize, { Color = C.InkSoft, Stroke = false })
	rarity.Name = "Rarete"
	rarity.Position = UDim2.fromOffset(6, y)
	rarity.Size = UDim2.new(1, -12, 0, lineHeight)
	y += lineHeight
	local slot = UIKit.text(frame, card.SlotName, options.LineSize, { Color = C.WoodDark, Stroke = false })
	slot.Name = "Emplacement"
	slot.Position = UDim2.fromOffset(6, y)
	slot.Size = UDim2.new(1, -12, 0, lineHeight)
	y += lineHeight
	-- bonus de l'objet (#73), calculé par le serveur : « +4 ATK », « +30 PV »
	if card.BonusText then
		local bonus = UIKit.text(frame, card.BonusText, options.LineSize, { Color = C.InkSoft, Stroke = false })
		bonus.Name = "Bonus"
		bonus.Position = UDim2.fromOffset(6, y)
		bonus.Size = UDim2.new(1, -12, 0, lineHeight)
		bonus.TextTruncate = Enum.TextTruncate.AtEnd
	end

	-- badge du haut = l'ÉTAT seul (« Équipé : X », « Nouveau »), jamais la rareté
	local badgeText = card.Badge or (if card.New then "Nouveau" else nil)
	if badgeText then
		local kind = card.BadgeKind or "New"
		stateBadge(frame, badgeText, if kind == "Equipped" then C.Success else C.RoyalRed, options)
	end
	return frame
end

local function band(parent: Instance, card: InventoryModel.ItemCard, options: Options): Frame
	local frame = UIKit.subPanel(parent, options.Size or UDim2.fromScale(1, 1))
	frame.Name = "MeilleurObjet"
	local pad = UITheme.Spacing.S
	local art = artBox(frame)
	art.Position = UDim2.fromOffset(pad, pad)
	art.Size = UDim2.new(0, options.ArtSize, 1, -2 * pad)
	ItemCard.icon(art, card, options.ArtSize - 12)
	if card.LevelText then
		levelBadge(art, card.LevelText)
	end
	local left = options.ArtSize + 2 * pad + UITheme.Spacing.XS
	-- colonne de textes empilés et centrés : si l'écran de fin grossit un texte (LootModel.textSize), les
	-- lignes se décalent au lieu de se chevaucher
	local texts = Instance.new("Frame")
	texts.Name = "Textes"
	texts.BackgroundTransparency = 1
	texts.Position = UDim2.fromOffset(left, pad)
	texts.Size = UDim2.new(1, -left - pad - 150, 1, -2 * pad)
	texts.Parent = frame
	local stack = Instance.new("UIListLayout")
	stack.FillDirection = Enum.FillDirection.Vertical
	stack.VerticalAlignment = Enum.VerticalAlignment.Center
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Parent = texts
	local function row(text: string, size: number, name: string, order: number, color: Color3?): TextLabel
		local label = UIKit.text(texts, text, size, { Color = color, Align = Enum.TextXAlignment.Left })
		label.Name = name
		label.LayoutOrder = order
		label.Size = UDim2.fromScale(1, 0)
		label.AutomaticSize = Enum.AutomaticSize.Y
		return label
	end
	if options.Head then
		row(options.Head, UITheme.Typography.Size.Caption + 2, "Mention", 1, C.TextMuted)
	end
	row(card.Name, options.NameSize, "Nom", 2).TextTruncate = Enum.TextTruncate.AtEnd
	-- rareté en texte + emplacement : « Rare · Arme »
	row(ItemCard.rarityLine(card), options.LineSize, "Rarete", 3, C.TextLight)
	return frame
end

function ItemCard.create(parent: Instance, card: InventoryModel.ItemCard, options: Options): Frame
	if options.Variant == "Band" then
		return band(parent, card, options)
	end
	return tile(parent, card, options)
end

return ItemCard
