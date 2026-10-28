--!strict
-- Fenêtre Sacoche — reproduit la maquette figée « Sacoche.dc.html » (docs/UI_DESIGN_SYSTEM.md § Sacoche),
-- avec UNE différence voulue : la fenêtre est CENTRÉE (la maquette la collait au menu, winL = 130 px).
-- Présentation seulement : HeroBarController possède l'état (héros choisi, onglet, filtre, recherche) et les
-- actions (Placer, Retirer de l'arène, raccourcis) ; la logique d'affichage est Shared.Sacoche.SacocheModel.
--   Plaque « Sacoche » (icône Sac du menu) et X ; onglets Héros / Équipement / Ressources (icônes du pack,
--   onglet choisi doré et soulevé, « ! » s'il y a du nouveau) ;
--   Héros : filtres Tous / Posés / Raccourcis, loupe (recherche), grille de cartes (vrai modèle en
--   ViewportFrame, Nv., touche du raccourci, « Nouveau » / « Posé », carte choisie soulevée avec contour
--   doré, lueur et pop) ; fiche (portrait, nom, rareté, Nv., états, XP, PV / ATK du serveur, UNE action
--   principale, l'action raccourci en secondaire) ;
--   Équipement (#72) : une carte par INSTANCE (ItemCard, rareté en texte, jamais fusionnées), tri rareté
--     décroissante / catalogue / InstanceId, filtre par emplacement (cibles >= 44), « Nouveau » tant que
--     l'onglet n'a pas été vu ; « +n » seulement si le niveau d'amélioration est > 0.
--   Équipement V1 (#73) : poupée du héros courant (flèches) avec les objets portés (icône du catalogue,
--     repli deux lettres), PV / ATK finales et leur bonus, « x/7 équipés » ; toucher un emplacement filtre la
--     liste sur cet emplacement. Cartes : bonus en texte, badge du haut = état (« Équipé : X », « Nouveau »).
--     Toucher une carte remplace la poupée par le détail de l'objet (même panneau, pas de nouvel écran) :
--     état, comparaison avant / après pour le héros courant, UNE action (Équiper / Retirer), refus du
--     serveur en clair, raison si l'action est désactivée (combat), « Retour ».
--   Ressources (#72) : tuiles compactes (icône, nom, quantité) groupées par famille NON vide, cadre neutre,
--     aucune rareté. Inventaire indisponible ou vide : états honnêtes, aucun faux inventaire.
--   Trois dispositions (UITheme.Pack.Sacoche) : PC, tablette, téléphone (onglets verticaux, fiche compacte).
-- Ouverture : scale 0,94 → 1,01 → 1 et fondu, au centre (pas de glissement). Position : SacocheModel.frame.
-- API :
--   SacocheView.Mount(parent, handlers)     -- parent : ScreenGui (jeu) ou Frame (aperçu Studio)
--   SacocheView.Layout(viewport, top, bottom) -- zone libre : bas du HUD du haut → haut de la hotbar (px)
--   SacocheView.Render(state)  SacocheView.Open()  SacocheView.Close()  SacocheView.IsOpen()
--   SacocheView.Card(id) -> GuiObject?       -- carte d'un exemplaire (cible du drag, guidage)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local EquipmentModel = require(ReplicatedStorage.Shared.Sacoche.EquipmentModel)
local ExpeditionVisualConfig = require(ReplicatedStorage.Shared.Config.ExpeditionVisualConfig)
local HeroConfig = require(ReplicatedStorage.Shared.Config.HeroConfig)
local InventoryModel = require(ReplicatedStorage.Shared.Sacoche.InventoryModel)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local MenuIconConfig = require(ReplicatedStorage.Shared.Config.MenuIconConfig)
local SacocheModel = require(ReplicatedStorage.Shared.Sacoche.SacocheModel)
local SacocheVisualConfig = require(ReplicatedStorage.Shared.Config.SacocheVisualConfig)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local GuideTargets = require(script.Parent.Parent.GuideTargets)
local Icons = require(script.Parent.Parent.Icons)
local ItemCard = require(script.Parent.Parent.ItemCard)
local RarityStyle = require(script.Parent.Parent.RarityStyle)
local UIKit = require(script.Parent.Parent.UIKit)

local C = UITheme.Colors
local T = UITheme.Transparency
local PACK = UITheme.Pack.Sacoche
local INK = UITheme.Stroke.Color
local ICON = SacocheVisualConfig

export type Handlers = {
	OnClose: () -> (),
	OnTab: (tab: string) -> (),
	OnSelect: (id: string) -> (),
	OnFilter: (filter: string) -> (),
	OnQuery: (query: string) -> (),
	OnSearch: (open: boolean) -> (),
	OnSlot: (slot: string) -> (),
	OnPrimary: (action: string) -> (),
	OnSecondary: (action: string) -> (),
	OnEquipHero: (step: number) -> (),
	OnDollSlot: (slot: string, instanceId: string?) -> (), -- #73 : emplacement de la poupée touché
	OnItem: (instanceId: string) -> (), -- #73 : carte d'objet touchée (détail ; re-toucher ferme)
	OnItemBack: () -> (), -- #73 : retour à la poupée
	OnEquipAction: () -> (), -- #73 : action principale du détail (Équiper / Retirer)
	BindDrag: (frame: GuiObject, id: string) -> (),
}
-- Équipement V1 (#73), préparé par le contrôleur avec Shared.Sacoche.EquipmentModel (vues serveur seulement).
export type Equip = {
	Hero: string?, -- HeroInstanceId de la poupée
	Doll: EquipmentModel.Doll,
	Selected: string?, -- InstanceId de l'objet choisi
	Card: InventoryModel.ItemCard?, -- carte de l'objet choisi (en-tête du détail)
	Detail: EquipmentModel.Detail?,
	Error: string?, -- dernier refus du serveur, en clair
	Busy: boolean,
	Slot: string, -- filtre d'emplacement courant (surligné sur la poupée)
}
-- Inventaire déjà préparé par le contrôleur (Shared.Sacoche.InventoryModel) : la vue ne trie ni ne filtre.
export type Inventory = {
	Loaded: boolean, -- false : pas encore reçu du serveur (jamais présenté comme « vide »)
	Revision: number,
	Cards: { InventoryModel.ItemCard }, -- déjà triées et filtrées par emplacement
	Filters: { InventoryModel.SlotFilter },
	Slot: string,
	Groups: { InventoryModel.ResourceGroup },
	Count: number,
	Cap: number?,
	FreshCount: number,
}
export type State = {
	Tab: string, -- "Heroes" | "Equipment" | "Resources"
	Cards: { SacocheModel.Card },
	Detail: SacocheModel.Detail?,
	Filter: string,
	Query: string,
	SearchOpen: boolean,
	HasNew: boolean, -- héros nouveau
	HasNewEquipment: boolean?, -- équipement nouveau (« ! » de l'onglet Équipement)
	Inventory: Inventory?,
	Total: number, -- héros possédés (avant filtre)
	EquipHero: { HeroId: string, Name: string, Level: number }?,
	Equip: Equip?, -- onglet Équipement seulement
	Picking: boolean,
}

local SacocheView = {}

type CardUI = { cell: Frame, button: TextButton, scale: UIScale, stroke: UIStroke, glow: UIStroke, key: Frame, keyText: TextLabel,
	edge: Frame, edgeText: TextLabel, edgeIcon: ImageLabel, level: TextLabel, name: TextLabel, selected: boolean? }

local handlers: Handlers? = nil
local ui: { [string]: any } = {}
local cards: { [string]: CardUI } = {}
local L: { [string]: any } = PACK.Wide
local device = "pc"
local opened = false
local lastState: State? = nil
local detailKey = ""
local tabKey = ""
local loops: { Tween } = {}

------------------------------------------------------------------ petits outils

local function corner(parent: Instance, radius: number)
	UIKit.corner(parent, UDim.new(0, radius))
end

local function gradient(parent: Instance, top: Color3, bottom: Color3)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(top, bottom)
	g.Parent = parent
end

local function box(parent: Instance, name: string, color: Color3, transparency: number?, radius: number?, ring: number?, ringColor: Color3?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency or 0
	f.BorderSizePixel = 0
	f.Parent = parent
	if radius then
		corner(f, radius)
	end
	if ring then
		UIKit.stroke(f, ring, ringColor)
	end
	return f
end

local function image(parent: Instance, asset: string, size: number): ImageLabel
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Image = asset
	img.ScaleType = Enum.ScaleType.Fit
	img.Size = UDim2.fromOffset(size, size)
	img.Parent = parent
	return img
end

local function text(parent: Instance, content: string, size: number, color: Color3?, stroke: boolean?): TextLabel
	local label = UIKit.text(parent, content, size, { Color = color or C.TextLight, Stroke = stroke ~= false })
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromOffset(0, math.ceil(size * 1.15))
	return label
end

local function list(parent: Instance, horizontal: boolean, gap: number, align: Enum.VerticalAlignment?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	layout.VerticalAlignment = align or Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = parent
	return layout
end

local function padding(parent: Instance, top: number, side: number, bottom: number?)
	local p = Instance.new("UIPadding")
	p.PaddingTop, p.PaddingBottom = UDim.new(0, top), UDim.new(0, bottom or top)
	p.PaddingLeft, p.PaddingRight = UDim.new(0, side), UDim.new(0, side)
	p.Parent = parent
end

-- Pastille (Nv., rareté, « Nouveau », « Posé ») : fond plein, contour Ink, texte contouré.
local function pill(parent: Instance, content: string, color: Color3, size: number, icon: string?): (Frame, TextLabel, ImageLabel)
	local p = box(parent, "Pastille", color, 0, 999, UITheme.Stroke.Thin)
	p.AutomaticSize = Enum.AutomaticSize.X
	p.Size = UDim2.fromOffset(0, math.ceil(size * 1.55))
	padding(p, 0, 7, 0)
	list(p, true, 3)
	local img = image(p, icon or "", math.floor(size * 1.15))
	img.LayoutOrder = 1
	img.Visible = icon ~= nil
	local label = text(p, content, size)
	label.LayoutOrder = 2
	return p, label, img
end

local function loop(target: Instance, info: TweenInfo, goal: { [string]: any })
	local t = TweenService:Create(target, info, goal)
	t:Play()
	table.insert(loops, t)
end

local function stopLoops()
	for _, t in loops do
		t:Cancel()
	end
	table.clear(loops)
end

local function breatheInfo(period: number): TweenInfo
	return TweenInfo.new(period / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
end

-- Bouton chunky de la maquette : face en dégradé sur une lèvre plus sombre (5 px), contour Ink 4 px.
local function chunky(parent: Instance, height: number, top: Color3, bottom: Color3, lip: Color3, onClick: () -> ()): (Frame, TextButton)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, height + 5)
	holder.Parent = parent
	local lipFrame = box(holder, "Levre", lip, 0, 14, UITheme.Stroke.Thick)
	lipFrame.Position = UDim2.fromOffset(0, 5)
	lipFrame.Size = UDim2.new(1, 0, 0, height)
	local face = Instance.new("TextButton")
	face.Name = "Face"
	face.AutoButtonColor = false
	face.Text = ""
	face.BackgroundColor3 = Color3.new(1, 1, 1)
	face.BorderSizePixel = 0
	face.ClipsDescendants = true
	face.Size = UDim2.new(1, 0, 0, height)
	face.ZIndex = 2
	face.Parent = holder
	corner(face, 14)
	UIKit.stroke(face, UITheme.Stroke.Thick)
	gradient(face, top, bottom)
	face.MouseButton1Down:Connect(function()
		TweenService:Create(face, UITheme.Animation.Press, { Position = UDim2.fromOffset(0, 4) }):Play()
	end)
	local function release()
		TweenService:Create(face, UITheme.Animation.Press, { Position = UDim2.fromOffset(0, 0) }):Play()
	end
	face.MouseButton1Up:Connect(release)
	face.MouseLeave:Connect(release)
	face.Activated:Connect(onClick)
	return holder, face
end

-- Puce de filtre (Tous / Posés / Raccourcis) : dorée si active.
local function chip(parent: Instance, content: string, on: boolean, icon: string?, onClick: () -> (), height: number?): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.Text = ""
	b.AutomaticSize = Enum.AutomaticSize.X
	b.Size = UDim2.fromOffset(0, height or L.ChipHeight)
	b.BackgroundColor3 = if on then Color3.new(1, 1, 1) else C.WoodDeep
	b.Parent = parent
	corner(b, 999)
	UIKit.stroke(b, UITheme.Stroke.Regular)
	if on then
		gradient(b, C.GoldLight, C.GoldDeep)
	end
	padding(b, 0, 12, 0)
	list(b, true, 5)
	if icon then
		image(b, icon, 20).LayoutOrder = 1
	end
	text(b, content, L.ChipSize).LayoutOrder = 2
	b.Activated:Connect(onClick)
	return b
end

-- État vide : cadre pointillé (contour StoneGrey), icône à 0,5, titre et sous-titre.
local function empty(parent: Instance, icon: string, title: string, subtitle: string?): Frame
	local f = Instance.new("Frame")
	f.Name = "Vide"
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromScale(1, 1)
	f.Parent = parent
	local layout = list(f, false, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local frame = box(f, "Cadre", C.Ink, 1, 20, UITheme.Stroke.Regular, C.StoneGrey)
	frame.Size = UDim2.fromOffset(L.EmptyIcon, L.EmptyIcon)
	frame.LayoutOrder = 1
	local img = image(frame, icon, math.floor(L.EmptyIcon * 0.6))
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.Position = UDim2.fromScale(0.5, 0.5)
	img.ImageTransparency = 0.5
	text(f, title, L.EmptyTitle).LayoutOrder = 2
	if subtitle then
		local sub = text(f, subtitle, 15, C.TextMuted, false)
		sub.LayoutOrder = 3
	end
	return f
end

------------------------------------------------------------------ structure

local function clearChildren(frame: Instance)
	for _, child in frame:GetChildren() do
		if not child:IsA("UILayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function buildWindow(parent: Instance)
	local h = handlers :: Handlers
	local frame = Instance.new("Frame")
	frame.Name = "Sacoche"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = parent
	ui.frame = frame
	local scale = Instance.new("UIScale")
	scale.Parent = frame
	ui.scale = scale
	-- ombre portée (6, 8) puis la fenêtre : bois sombre à 0,2, contour Ink 4 px
	local shadow = box(frame, "Ombre", C.Ink, T.Shadow, 18)
	shadow.Position = UDim2.fromOffset(6, 8)
	shadow.Size = UDim2.fromScale(1, 1)
	local window = box(frame, "Fenetre", C.WoodDeep, 0.2, 18, UITheme.Stroke.Thick)
	window.Size = UDim2.fromScale(1, 1)
	ui.window = window

	-- plaque de titre (icône Sac du menu, « Sacoche ») et X
	local plate = box(frame, "Titre", C.Wood, 0, 12, UITheme.Stroke.Thick)
	plate.AnchorPoint = Vector2.new(0.5, 0)
	plate.AutomaticSize = Enum.AutomaticSize.X
	plate.ZIndex = 6
	padding(plate, 0, 24, 0)
	list(plate, true, 8)
	local plateIcon = image(plate, MenuIconConfig.Buttons.Bag.Icon, 52)
	plateIcon.ZIndex = 7
	local plateText = text(plate, "Sacoche", 30)
	plateText.ZIndex = 7
	ui.plate, ui.plateIcon, ui.plateText = plate, plateIcon, plateText

	local close = UIKit.roundButton(frame, { Text = "X", Name = "Fermer", OnClick = h.OnClose })
	close.AnchorPoint = Vector2.new(0.5, 0.5)
	close.Position = UDim2.new(1, -4, 0, 4)
	close.ZIndex = 8

	local body = Instance.new("Frame")
	body.Name = "Corps"
	body.BackgroundTransparency = 1
	body.Parent = window
	ui.body = body
	local tabs = Instance.new("Frame")
	tabs.Name = "Onglets"
	tabs.BackgroundTransparency = 1
	tabs.Parent = body
	ui.tabs = tabs
	local content = Instance.new("Frame")
	content.Name = "Contenu"
	content.BackgroundTransparency = 1
	content.Parent = body
	ui.content = content

	-- onglet Héros : colonne liste (filtres + grille) et fiche
	local heroes = Instance.new("Frame")
	heroes.Name = "Heros"
	heroes.BackgroundTransparency = 1
	heroes.Size = UDim2.fromScale(1, 1)
	heroes.Parent = content
	ui.heroes = heroes
	local column = Instance.new("Frame")
	column.Name = "Liste"
	column.BackgroundTransparency = 1
	column.Parent = heroes
	ui.column = column
	local bar = Instance.new("Frame")
	bar.Name = "Filtres"
	bar.BackgroundTransparency = 1
	bar.Parent = column
	ui.filters = bar
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Grille"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = UITheme.Stroke.ScrollBar
	grid.ScrollBarImageColor3 = C.Cream
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.Parent = column
	ui.grid = grid
	local layout = Instance.new("UIGridLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	ui.gridLayout = layout
	padding(grid, 14, 8, 8) -- place pour les pastilles à cheval et la carte soulevée
	local none = empty(column, ICON.Tabs.Heroes, "Aucun héros")
	none.Visible = false
	ui.none = none
	local detail = box(heroes, "Fiche", C.Ink, 0.45, 14, UITheme.Stroke.Regular)
	ui.detail = detail

	-- onglets Équipement / Ressources : contenu reconstruit à l'affichage (état vide sans backend)
	local other = Instance.new("Frame")
	other.Name = "Autre"
	other.BackgroundTransparency = 1
	other.Size = UDim2.fromScale(1, 1)
	other.Visible = false
	other.Parent = content
	ui.other = other
end

------------------------------------------------------------------ disposition

local function applyLayout()
	local frame = ui.frame
	if not frame then
		return
	end
	local wide = device ~= "phone"
	local W, H = L.Window.X, L.Window.Y
	frame.Size = UDim2.fromOffset(W, H)
	ui.plate.Visible = wide
	ui.plate.Position = UDim2.new(0.5, 0, 0, L.TabTop)
	ui.plate.Size = UDim2.fromOffset(0, 54)
	-- corps : onglets en ligne au-dessus (PC / tablette), en colonne à gauche (téléphone)
	ui.body.Position = UDim2.fromOffset(L.Pad.Side, L.Pad.Top)
	ui.body.Size = UDim2.new(1, -2 * L.Pad.Side, 1, -L.Pad.Top - L.Pad.Bottom)
	if wide then
		ui.tabs.Position = UDim2.fromOffset(0, 0)
		ui.tabs.Size = UDim2.new(1, 0, 0, L.TabHeightOn)
		ui.content.Position = UDim2.fromOffset(0, L.TabHeightOn + L.Gap)
		ui.content.Size = UDim2.new(1, 0, 1, -L.TabHeightOn - L.Gap)
	else
		ui.tabs.Position = UDim2.fromOffset(0, 0)
		ui.tabs.Size = UDim2.new(0, L.TabWidth + 6, 1, 0)
		ui.content.Position = UDim2.fromOffset(L.TabWidth + 6 + L.Gap, 0)
		ui.content.Size = UDim2.new(1, -(L.TabWidth + 6 + L.Gap), 1, 0)
	end
	ui.column.Size = UDim2.new(1, -(L.DetailWidth + L.Gap), 1, 0)
	ui.detail.Position = UDim2.new(1, -L.DetailWidth, 0, 0)
	ui.detail.Size = UDim2.new(0, L.DetailWidth, 1, 0)
	ui.filters.Size = UDim2.new(1, 0, 0, L.ChipHeight)
	ui.grid.Position = UDim2.fromOffset(-8, L.ChipHeight + 6)
	ui.grid.Size = UDim2.new(1, 16, 1, -(L.ChipHeight + 6))
	ui.none.Position = ui.grid.Position
	ui.none.Size = ui.grid.Size
	-- largeur de la grille connue ici (offsets seulement) : cellules 4/5, colonnes de la disposition
	local contentWidth = W - 2 * L.Pad.Side - (if wide then 0 else L.TabWidth + 6 + L.Gap)
	ui.contentWidth = contentWidth -- onglets Équipement / Ressources (cellules des grilles)
	local gridWidth = contentWidth - L.DetailWidth - L.Gap
	local cell = math.floor((gridWidth - (L.HeroCols - 1) * L.CardGap) / L.HeroCols)
	ui.gridLayout.CellSize = UDim2.fromOffset(cell, math.floor(cell * 5 / 4))
	ui.gridLayout.CellPadding = UDim2.fromOffset(L.CardGap, L.CardGap + 6)
	ui.cell = cell
	tabKey, detailKey = "", "" -- tout est redessiné à la prochaine passe
	for id, entry in cards do
		entry.cell:Destroy()
		cards[id] = nil
	end
end

-- viewport : taille de l'écran (px) ; top / bottom : zone libre (bas du HUD du haut, haut de la hotbar).
function SacocheView.Layout(viewport: Vector2, top: number, bottom: number)
	local nextDevice = SacocheModel.device(viewport.X, viewport.Y)
	local layout = table.clone(if nextDevice == "phone" then PACK.Phone else PACK.Wide)
	if nextDevice == "tablet" then
		for key, value in PACK.Tablet do
			layout[key] = value
		end
	end
	local changed = nextDevice ~= device or layout.Window ~= L.Window
	device, L = nextDevice, layout
	-- téléphone : la fenêtre peut prendre presque tout l'écran (le HUD du haut passe dessous)
	local margin = if device == "phone" then PACK.Margin / 2 else PACK.Margin
	-- PC / tablette : la plaque « Sacoche » dépasse au-dessus de la fenêtre (TabTop), elle aussi sous le HUD
	local zoneTop = if device == "phone" then 0 else top - L.TabTop
	local f = SacocheModel.frame(viewport, zoneTop, bottom, L.Window, margin, PACK.MinScale, PACK.MaxScale)
	if changed then
		applyLayout()
	end
	if ui.frame then
		ui.frame.Position = UDim2.fromOffset(f.X, f.Y)
		ui.fit = f.Scale
		if not ui.animating then
			ui.scale.Scale = f.Scale
		end
	end
	if changed and lastState and opened then
		SacocheView.Render(lastState)
	end
end

------------------------------------------------------------------ onglets

local TABS = {
	{ Id = "Heroes", Label = "Héros" },
	{ Id = "Equipment", Label = "Équipement" },
	{ Id = "Resources", Label = "Ressources" },
}

local function renderTabs(state: State)
	local key = `{state.Tab}|{state.HasNew}|{state.HasNewEquipment == true}|{device}`
	if key == tabKey then
		return
	end
	tabKey = key
	local h = handlers :: Handlers
	local wide = device ~= "phone"
	clearChildren(ui.tabs)
	local layout = ui.tabs:FindFirstChildOfClass("UIListLayout") or list(ui.tabs, wide, L.TabsGap, Enum.VerticalAlignment.Bottom)
	layout.FillDirection = if wide then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = if wide then Enum.VerticalAlignment.Bottom else Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, L.TabsGap)
	for index, info in TABS do
		local on = state.Tab == info.Id
		local tab = Instance.new("TextButton")
		tab.Name = `Onglet{info.Id}`
		tab.LayoutOrder = index
		tab.AutoButtonColor = false
		tab.Text = ""
		tab.Size = UDim2.fromOffset(L.TabWidth, if on then L.TabHeightOn else L.TabHeight)
		tab.BackgroundColor3 = if on then Color3.new(1, 1, 1) else C.WoodDeep
		tab.BackgroundTransparency = if on then 0 else 0.12
		tab.Parent = ui.tabs
		corner(tab, 14)
		UIKit.stroke(tab, if on then UITheme.Stroke.Thick else UITheme.Stroke.Regular)
		if on then
			gradient(tab, C.GoldLight, C.GoldDeep)
			-- lueur dorée de l'onglet choisi
			local glow = box(tab, "Lueur", C.GoldLight, 1, 18)
			glow.Position = UDim2.fromOffset(-5, -5)
			glow.Size = UDim2.new(1, 10, 1, 10)
			glow.ZIndex = 0
			local g = UIKit.stroke(glow, 5, C.GoldLight)
			g.Transparency = 0.55
		end
		local inner = Instance.new("Frame")
		inner.BackgroundTransparency = 1
		inner.Size = UDim2.fromScale(1, 1)
		inner.Parent = tab
		local l = list(inner, wide, 6)
		l.HorizontalAlignment = Enum.HorizontalAlignment.Center
		image(inner, ICON.Tabs[info.Id], if on then L.TabIconOn else L.TabIcon).LayoutOrder = 1
		if wide then
			text(inner, info.Label, if on then L.TabSizeOn else L.TabSize).LayoutOrder = 2
		end
		local fresh = if info.Id == "Heroes" then state.HasNew elseif info.Id == "Equipment" then state.HasNewEquipment == true else false
		if fresh and not on then
			local dot = box(tab, "Nouveau", C.RoyalRed, 0, 999, UITheme.Stroke.Thin)
			dot.AnchorPoint = Vector2.new(1, 0)
			dot.Position = UDim2.new(1, 6, 0, -8)
			dot.Size = UDim2.fromOffset(24, 24)
			dot.ZIndex = 4
			text(dot, "!", 15).ZIndex = 5
		end
		tab.Activated:Connect(function()
			h.OnTab(info.Id)
		end)
	end
end

------------------------------------------------------------------ héros

local function cardFor(c: SacocheModel.Card): CardUI
	local existing = cards[c.Id]
	if existing then
		return existing
	end
	local h = handlers :: Handlers
	local cell = Instance.new("Frame")
	cell.Name = c.Id
	cell.BackgroundTransparency = 1
	cell.Parent = ui.grid
	local button = Instance.new("TextButton")
	button.Name = "Carte"
	button.AutoButtonColor = false
	button.Text = ""
	button.BackgroundColor3 = Color3.new(1, 1, 1)
	button.Size = UDim2.fromScale(1, 1)
	button.Parent = cell
	corner(button, 14)
	gradient(button, C.Cream, C.Sand)
	local stroke = UIKit.stroke(button, UITheme.Stroke.Regular)
	local scale = Instance.new("UIScale")
	scale.Parent = button
	-- lueur de la carte choisie (contour doré flou) : cadre à part, la carte garde son contour
	local glowFrame = Instance.new("Frame")
	glowFrame.Name = "Lueur"
	glowFrame.BackgroundTransparency = 1
	glowFrame.Position = UDim2.fromOffset(-6, -6)
	glowFrame.Size = UDim2.new(1, 12, 1, 12)
	glowFrame.ZIndex = 0
	glowFrame.Parent = button
	corner(glowFrame, 18)
	local glow = UIKit.stroke(glowFrame, 6, C.Selected)
	glow.Transparency = 1
	-- illustration : vrai modèle du héros (ViewportFrame), sinon monogramme provisoire de HeroConfig
	local art = box(button, "Illustration", C.Sand, 0.1, 9)
	art.Position = UDim2.fromOffset(5, 5)
	art.Size = UDim2.new(1, -10, 1, -(L.CardName + 5))
	art.ClipsDescendants = true
	local model = Icons.heroModel(c.HeroId)
	if model then
		UIKit.portrait(art, model).ZIndex = 2
	else
		local info = HeroConfig.Heroes[c.HeroId]
		UIKit.text(art, if info then info.PlaceholderIcon else "?", UITheme.Typography.Size.IconLarge, { Color = C.WoodDark, Stroke = false })
	end
	local level = text(button, "", L.LevelSize)
	level.Name = "Niveau"
	local levelBox = box(button, "NiveauFond", C.WoodDeep, 0, 999, UITheme.Stroke.Thin)
	levelBox.AnchorPoint = Vector2.new(0, 1)
	levelBox.Position = UDim2.new(0, 3, 1, -(L.CardName + 2))
	levelBox.AutomaticSize = Enum.AutomaticSize.X
	levelBox.Size = UDim2.fromOffset(0, L.LevelSize + 6)
	levelBox.ZIndex = 4
	padding(levelBox, 0, 7, 0)
	level.Parent = levelBox
	level.ZIndex = 5
	local name = UIKit.text(button, c.Short, L.CardNameSize, { Color = C.InkSoft, Stroke = false })
	name.Name = "Nom"
	name.AnchorPoint = Vector2.new(0.5, 1)
	name.Position = UDim2.new(0.5, 0, 1, -2)
	name.Size = UDim2.new(1, -12, 0, L.CardName - 5)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	-- touche du raccourci (coin haut droit, carré doré)
	local key = box(button, "Touche", Color3.new(1, 1, 1), 0, 8, UITheme.Stroke.Regular)
	gradient(key, C.GoldLight, C.GoldDeep)
	key.AnchorPoint = Vector2.new(1, 0)
	key.Position = UDim2.new(1, 7, 0, -7)
	key.Size = UDim2.fromOffset(28, 28)
	key.ZIndex = 6
	local keyText = UIKit.text(key, "", 16)
	keyText.ZIndex = 7
	-- « Nouveau » (rouge, rebondit) ou « Posé » (vert, coche) à cheval sur le bord haut
	local edge, edgeText, edgeIcon = pill(button, "", C.Success, 13, ExpeditionVisualConfig.Check)
	edge.AnchorPoint = Vector2.new(0.5, 0.5)
	edge.Position = UDim2.fromScale(0.5, 0)
	edge.ZIndex = 6
	for _, d in edge:GetDescendants() do
		if d:IsA("GuiObject") then d.ZIndex = 7 end
	end
	button.Activated:Connect(function()
		h.OnSelect(c.Id)
	end)
	h.BindDrag(button, c.Id)
	local entry: CardUI = { cell = cell, button = button, scale = scale, stroke = stroke, glow = glow, key = key, keyText = keyText,
		edge = edge, edgeText = edgeText, edgeIcon = edgeIcon, level = level, name = name }
	cards[c.Id] = entry
	return entry
end

local function renderCards(state: State)
	local seen = {}
	local first: CardUI? = nil
	for order, c in state.Cards do
		local entry = cardFor(c)
		seen[c.Id] = true
		first = first or entry
		entry.cell.LayoutOrder = order
		entry.level.Text = `Nv.{c.Level}`
		entry.name.Text = c.Short
		entry.key.Visible = c.Key ~= nil
		entry.keyText.Text = c.Key or ""
		entry.edge.Visible = c.Edge ~= nil
		entry.edgeText.Text = c.Edge or ""
		entry.edge.BackgroundColor3 = if c.New then C.RoyalRed else C.Success
		entry.edgeIcon.Visible = c.Edge == "Posé"
		-- carte choisie : soulevée, contour doré épais, lueur, pop court
		local selected = c.Selected
		entry.stroke.Color = if selected then C.Selected else INK
		entry.stroke.Thickness = if selected then UITheme.Stroke.Thick else UITheme.Stroke.Regular
		entry.glow.Transparency = if selected then 0.4 else 1
		entry.button.Position = UDim2.fromOffset(0, if selected then -PACK.Lift else 0)
		if selected and not entry.selected then
			entry.scale.Scale = 1
			TweenService:Create(entry.scale, TweenInfo.new(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.08 }):Play()
			task.delay(0.11, function()
				if entry.selected then
					TweenService:Create(entry.scale, TweenInfo.new(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.04 }):Play()
				end
			end)
		elseif not selected then
			entry.scale.Scale = 1
		end
		entry.selected = selected
	end
	for id, entry in cards do
		if not seen[id] then
			entry.cell:Destroy()
			cards[id] = nil
		end
	end
	ui.none.Visible = #state.Cards == 0
	ui.grid.Visible = #state.Cards > 0
	if first then
		GuideTargets.register("Bag.FirstHero", first.button)
	end
	ui.first = first
end

local function renderFilters(state: State)
	local h = handlers :: Handlers
	clearChildren(ui.filters)
	if not ui.filters:FindFirstChildOfClass("UIListLayout") then
		list(ui.filters, true, 6)
	end
	for index, f in { { "all", "Tous", nil }, { "placed", "Posés", ExpeditionVisualConfig.Check }, { "hotbar", "Raccourcis", ICON.Hotbar } } do
		local b = chip(ui.filters, f[2], state.Filter == f[1], f[3], function()
			h.OnFilter(f[1])
		end)
		b.LayoutOrder = index
	end
	-- recherche : loupe (à droite), champ quand elle est ouverte
	local right = Instance.new("Frame")
	right.Name = "Recherche"
	right.BackgroundTransparency = 1
	right.LayoutOrder = 10
	right.AutomaticSize = Enum.AutomaticSize.X
	right.Size = UDim2.fromOffset(0, L.ChipHeight)
	right.Parent = ui.filters
	list(right, true, 6)
	if state.SearchOpen then
		local field = Instance.new("TextBox")
		field.Name = "Champ"
		field.LayoutOrder = 1
		field.ClearTextOnFocus = false
		field.PlaceholderText = "Nom…"
		field.Text = state.Query
		field.FontFace = UITheme.Typography.Display
		field.TextSize = 15
		field.TextColor3 = C.InkSoft
		field.PlaceholderColor3 = C.StoneGrey
		field.BackgroundColor3 = C.Cream
		field.Size = UDim2.fromOffset(L.SearchWidth, L.ChipHeight)
		field.Parent = right
		corner(field, 999)
		UIKit.stroke(field, UITheme.Stroke.Regular)
		padding(field, 0, 12, 0)
		field:GetPropertyChangedSignal("Text"):Connect(function()
			h.OnQuery(field.Text)
		end)
		task.defer(function()
			if field.Parent then field:CaptureFocus() end
		end)
	end
	local loupe = Instance.new("TextButton")
	loupe.Name = "Loupe"
	loupe.LayoutOrder = 2
	loupe.AutoButtonColor = false
	loupe.Text = ""
	loupe.Size = UDim2.fromOffset(L.ChipHeight, L.ChipHeight)
	loupe.BackgroundColor3 = if state.SearchOpen then Color3.new(1, 1, 1) else C.WoodDeep
	loupe.Parent = right
	corner(loupe, 999)
	UIKit.stroke(loupe, UITheme.Stroke.Regular)
	if state.SearchOpen then gradient(loupe, C.GoldLight, C.GoldDeep) end
	local img = image(loupe, ICON.Search, 22)
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.Position = UDim2.fromScale(0.5, 0.5)
	loupe.Activated:Connect(function()
		h.OnSearch(not state.SearchOpen)
	end)
end

local function statBlock(parent: Instance, icon: string, value: number, label: string, order: number)
	local b = box(parent, label, C.WoodDeep, 0.15, 12, UITheme.Stroke.Regular)
	b.LayoutOrder = order
	b.Size = UDim2.new(0.5, -4, 1, 0)
	padding(b, 0, 10, 0)
	list(b, true, 8)
	image(b, icon, L.StatIcon).LayoutOrder = 1
	local col = Instance.new("Frame")
	col.BackgroundTransparency = 1
	col.AutomaticSize = Enum.AutomaticSize.XY
	col.Size = UDim2.fromOffset(0, 0)
	col.LayoutOrder = 2
	col.Parent = b
	list(col, false, 0)
	text(col, tostring(value), L.StatSize).LayoutOrder = 1
	text(col, label, 14, C.TextMuted, false).LayoutOrder = 2
end

local function renderDetail(state: State)
	local d = state.Detail
	local key = if d then table.concat({ d.Id, d.Level, d.XP, d.XPToNext, tostring(d.MaxHealth), tostring(d.AttackDamage), tostring(d.HealthBonus), tostring(d.AttackBonus), tostring(d.Placed),
		d.Key or "-", d.Primary.Label, tostring(d.Primary.Enabled), d.Secondary.Label, tostring(d.Secondary.Enabled), tostring(state.Picking), device }, "|")
		else `none|{device}|{ui.first and ui.first.button.Name or ""}`
	if key == detailKey then
		return
	end
	detailKey = key
	local h = handlers :: Handlers
	local wide = device ~= "phone"
	local panel = ui.detail
	clearChildren(panel)
	stopLoops()
	local inner = Instance.new("Frame")
	inner.Name = "Interieur"
	inner.BackgroundTransparency = 1
	inner.Position = UDim2.fromOffset(L.DetailPad, L.DetailPad)
	inner.Size = UDim2.new(1, -2 * L.DetailPad, 1, -2 * L.DetailPad)
	inner.Parent = panel
	if not d then
		-- aucun héros choisi : invitation (cadre pointillé qui rebondit)
		local col = Instance.new("Frame")
		col.BackgroundTransparency = 1
		col.Size = UDim2.fromScale(1, 1)
		col.Parent = inner
		local l = list(col, false, 10)
		l.HorizontalAlignment = Enum.HorizontalAlignment.Center
		local frame = box(col, "Cadre", C.Ink, 1, 14, UITheme.Stroke.Regular, C.StoneGrey)
		frame.Size = UDim2.fromOffset(if wide then 90 else 56, if wide then 110 else 68)
		frame.LayoutOrder = 1
		local img = image(frame, ICON.Tabs.Heroes, if wide then 56 else 36)
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(0.5, 0.5)
		img.ImageTransparency = 0.5
		text(col, "Choisis un héros", if wide then 22 else 17).LayoutOrder = 2
		text(col, "Touche une carte", 15, C.TextMuted, false).LayoutOrder = 3
		-- le tutoriel montre alors la carte à toucher
		if ui.first then
			GuideTargets.register("Bag.Place", ui.first.button)
		end
		return
	end
	local layout = list(inner, false, L.DetailGap, Enum.VerticalAlignment.Top)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	-- tête : portrait (vrai modèle), nom, rareté, Nv., états
	local head = Instance.new("Frame")
	head.Name = "Tete"
	head.BackgroundTransparency = 1
	head.LayoutOrder = 1
	head.Size = UDim2.new(1, 0, 0, math.floor(L.BigWidth * 5 / 4))
	head.Parent = inner
	local big = box(head, "Portrait", Color3.new(1, 1, 1), 0, 14, UITheme.Stroke.Regular)
	gradient(big, C.Cream, C.SandWarm)
	big.Size = UDim2.fromOffset(L.BigWidth, math.floor(L.BigWidth * 5 / 4))
	big.ClipsDescendants = true
	local model = Icons.heroModel(d.HeroId)
	if model then
		UIKit.portrait(big, model)
	end
	UIKit.popIn(big, 0, 1.08)
	local info = Instance.new("Frame")
	info.BackgroundTransparency = 1
	info.Position = UDim2.fromOffset(L.BigWidth + 12, 0)
	info.Size = UDim2.new(1, -(L.BigWidth + 12), 1, 0)
	info.Parent = head
	list(info, false, if wide then 6 else 3)
	local name = UIKit.text(info, d.Name, L.HeroNameSize)
	name.LayoutOrder = 1
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextWrapped = true
	name.Size = UDim2.new(1, 0, 0, if wide then math.ceil(L.HeroNameSize * 2.2) else L.HeroNameSize + 4)
	name.TextScaled = not wide
	local tags = Instance.new("Frame")
	tags.BackgroundTransparency = 1
	tags.LayoutOrder = 2
	tags.Size = UDim2.new(1, 0, 0, 22)
	tags.Parent = info
	list(tags, true, 6)
	local rarity = pill(tags, RarityStyle.name(d.Rarity), RarityStyle.color(d.Rarity), 14)
	rarity.LayoutOrder = 1
	local lv = pill(tags, `Nv. {d.Level}`, C.WoodDeep, 14)
	lv.LayoutOrder = 2
	local lvGlow = UIKit.stroke(lv, 3, C.GoldLight)
	loop(lvGlow, breatheInfo(2.4), { Transparency = 0.3 })
	lvGlow.Transparency = 1
	if wide then
		for index, s in d.States do
			local line = Instance.new("Frame")
			line.BackgroundTransparency = 1
			line.LayoutOrder = 2 + index
			line.AutomaticSize = Enum.AutomaticSize.X
			line.Size = UDim2.fromOffset(0, 20)
			line.Parent = info
			list(line, true, 5)
			local icon = if s.Kind == "Placed" then ExpeditionVisualConfig.Check elseif s.Kind == "Hotbar" then ICON.Hotbar else ICON.Tabs.Heroes
			image(line, icon, 20).LayoutOrder = 1
			text(line, s.Label, 15, if s.Kind == "Placed" then C.SuccessLight elseif s.Kind == "Hotbar" then C.GoldLight else C.TextLight).LayoutOrder = 2
		end
	end
	-- XP (valeurs du serveur) et barre
	local xp = Instance.new("Frame")
	xp.Name = "XP"
	xp.BackgroundTransparency = 1
	xp.LayoutOrder = 2
	xp.Size = UDim2.new(1, 0, 0, 38)
	xp.Parent = inner
	local xpLabel = UIKit.text(xp, "XP", 14, { Align = Enum.TextXAlignment.Left })
	xpLabel.Size = UDim2.new(1, 0, 0, 18)
	local xpValue = UIKit.text(xp, d.XPText, 14, { Align = Enum.TextXAlignment.Right })
	xpValue.Size = UDim2.new(1, 0, 0, 18)
	local bar = UIKit.bar(xp, { Color = C.Progress, Size = UDim2.new(1, 0, 0, 16) })
	bar.Frame.Position = UDim2.fromOffset(0, 22)
	bar.Set(d.XPRatio, true)
	-- PV / ATK : seulement si le serveur les envoie (rien d'inventé)
	if d.MaxHealth and d.AttackDamage then
		local stats = Instance.new("Frame")
		stats.Name = "Stats"
		stats.BackgroundTransparency = 1
		stats.LayoutOrder = 3
		stats.Size = UDim2.new(1, 0, 0, L.StatSize + 30)
		stats.Parent = inner
		list(stats, true, 8)
		-- stats finales du serveur ; la part d'équipement (#73) en clair sous la valeur
		statBlock(stats, ICON.Health, d.MaxHealth, if d.HealthBonus ~= 0 then `PV ({EquipmentModel.signed(d.HealthBonus)})` else "PV", 1)
		statBlock(stats, ICON.Attack, d.AttackDamage, if d.AttackBonus ~= 0 then `ATK ({EquipmentModel.signed(d.AttackBonus)})` else "ATK", 2)
	end
	-- actions : UNE principale (Placer / Retirer de l'arène), le raccourci en secondaire
	local actions = Instance.new("Frame")
	actions.Name = "Actions"
	actions.BackgroundTransparency = 1
	actions.LayoutOrder = 4
	actions.AnchorPoint = Vector2.new(0, 1)
	actions.Parent = inner
	local p = d.Primary
	local on = p.Enabled
	local primaryHolder, primaryFace = chunky(actions, L.CtaHeight,
		if on then C.GoldLight else C.Disabled, if on then C.GoldDeep else C.StoneGrey, if on then C.GoldLip else C.DisabledLip, function()
			if p.Enabled then h.OnPrimary(p.Action) end
		end)
	primaryHolder.Name = "Principale"
	local primaryLabel = UIKit.text(primaryFace, p.Label, L.CtaSize)
	primaryLabel.ZIndex = 3
	primaryLabel.TextTransparency = if on then 0 else T.Disabled
	GuideTargets.register("Bag.Place", primaryHolder)
	if p.Breathe and on then
		local scale = Instance.new("UIScale")
		scale.Parent = primaryHolder
		loop(scale, breatheInfo(PACK.Breathe), { Scale = 1.03 })
		local halo = Instance.new("Frame")
		halo.BackgroundTransparency = 1
		halo.Position = UDim2.fromOffset(-4, -4)
		halo.Size = UDim2.new(1, 8, 0, L.CtaHeight + 8)
		halo.Parent = primaryHolder
		corner(halo, 18)
		local haloStroke = UIKit.stroke(halo, 6, C.GoldLight)
		haloStroke.Transparency = 1
		loop(haloStroke, breatheInfo(PACK.Breathe), { Transparency = 0.45 })
	end
	local s = d.Secondary
	local secondary = Instance.new("TextButton")
	secondary.Name = "Raccourci"
	secondary.AutoButtonColor = false
	secondary.Text = ""
	secondary.BackgroundColor3 = Color3.new(1, 1, 1)
	secondary.Parent = actions
	corner(secondary, 12)
	UIKit.stroke(secondary, UITheme.Stroke.Regular, if state.Picking then C.Selected else INK)
	gradient(secondary, C.WoodLight, C.Wood)
	local secRow = Instance.new("Frame")
	secRow.BackgroundTransparency = 1
	secRow.Size = UDim2.fromScale(1, 1)
	secRow.Parent = secondary
	local secLayout = list(secRow, true, 6)
	secLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	image(secRow, ICON.Hotbar, 28).LayoutOrder = 1
	text(secRow, if wide then s.Label else (if s.Action == "ClearHotbar" then "−" else "+"), if wide then L.Cta2Size else 22).LayoutOrder = 2
	secondary.Activated:Connect(function()
		if s.Enabled then h.OnSecondary(s.Action) end
	end)
	if wide then
		actions.Position = UDim2.new(0, 0, 1, 0)
		actions.Size = UDim2.new(1, 0, 0, L.CtaHeight + 5 + 8 + L.Cta2Height + 8 + 18)
		list(actions, false, 8, Enum.VerticalAlignment.Bottom)
		primaryHolder.LayoutOrder = 1
		secondary.LayoutOrder = 2
		secondary.Size = UDim2.new(1, 0, 0, L.Cta2Height)
		local hint = text(actions, "ou glisse la carte sur la barre du bas", 14, C.TextMuted, false)
		hint.LayoutOrder = 3
		hint.Size = UDim2.new(1, 0, 0, 18)
		hint.AutomaticSize = Enum.AutomaticSize.None
	else
		actions.Position = UDim2.new(0, 0, 1, 0)
		actions.Size = UDim2.new(1, 0, 0, L.CtaHeight + 5)
		list(actions, true, 8, Enum.VerticalAlignment.Top)
		primaryHolder.LayoutOrder = 1
		primaryHolder.Size = UDim2.new(1, -72, 0, L.CtaHeight + 5)
		secondary.LayoutOrder = 2
		secondary.Size = UDim2.fromOffset(64, L.Cta2Height)
	end
	-- les actions restent en bas de la fiche (hors de la liste verticale)
	actions.Parent = panel
	actions.Position = UDim2.new(0, L.DetailPad, 1, -L.DetailPad)
	actions.Size = UDim2.new(1, -2 * L.DetailPad, 0, actions.Size.Y.Offset)
end

------------------------------------------------------------------ équipement / ressources (sans backend)

-- emplacement, colonne, ligne (positions de la maquette)
local SLOT_GRID: { { Id: string, Col: number, Row: number } } = {
	{ Id = "helmet", Col = 2, Row = 1 }, { Id = "weapon", Col = 1, Row = 2 }, { Id = "relic", Col = 3, Row = 2 },
	{ Id = "gloves", Col = 1, Row = 3 }, { Id = "armor", Col = 2, Row = 3 }, { Id = "accessory", Col = 3, Row = 3 },
	{ Id = "boots", Col = 2, Row = 4 },
}

-- Défilement vertical standard des onglets Équipement / Ressources.
local function scroller(parent: Instance, name: string): ScrollingFrame
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = name
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = UITheme.Stroke.ScrollBar
	scroll.ScrollBarImageColor3 = C.Cream
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.Parent = parent
	return scroll
end

-- Tuile de ressource : icône (ou deux lettres), nom, quantité. Cadre neutre : AUCUNE rareté ni couleur de rareté.
local function resourceTile(parent: Instance, tile: InventoryModel.ResourceTile, order: number)
	local box_ = box(parent, `Ressource_{tile.ResourceId}`, C.WoodDeep, 0.15, 12, UITheme.Stroke.Regular)
	box_.LayoutOrder = order
	local iconX = 8
	if tile.Icon then
		local img = image(box_, tile.Icon, L.ResIcon)
		img.AnchorPoint = Vector2.new(0, 0.5)
		img.Position = UDim2.new(0, iconX, 0.5, 0)
	else
		local fallback = UIKit.text(box_, InventoryModel.initials(tile.Name), 14, { Color = C.TextMuted })
		fallback.AnchorPoint = Vector2.new(0, 0.5)
		fallback.Position = UDim2.new(0, iconX, 0.5, 0)
		fallback.Size = UDim2.fromOffset(L.ResIcon, L.ResIcon)
	end
	local amountWidth = 64
	local left = iconX + L.ResIcon + 6
	local name = UIKit.text(box_, tile.Name, L.ResNameSize, { Align = Enum.TextXAlignment.Left })
	name.Name = "Nom"
	name.Position = UDim2.fromOffset(left, 0)
	name.Size = UDim2.new(1, -left - amountWidth - 8, 1, 0)
	name.TextWrapped = true
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local amount = UIKit.text(box_, `×{tile.AmountText}`, L.ResAmountSize, { Color = C.GoldLight, Align = Enum.TextXAlignment.Right })
	amount.Name = "Quantite"
	amount.AnchorPoint = Vector2.new(1, 0.5)
	amount.Position = UDim2.new(1, -8, 0.5, 0)
	amount.Size = UDim2.fromOffset(amountWidth, math.ceil(L.ResAmountSize * 1.3))
end

-- Onglet Ressources : mention muted, puis un groupe par famille NON vide (tuiles compactes en grille).
local function renderResources(other: Instance, inv: Inventory)
	local scroll = scroller(other, "Ressources")
	scroll.Size = UDim2.fromScale(1, 1)
	padding(scroll, 4, 8, 8)
	local column = list(scroll, false, 12, Enum.VerticalAlignment.Top)
	column.HorizontalAlignment = Enum.HorizontalAlignment.Left
	local hint = text(scroll, "Pas encore utilisables : garde-les pour la suite", L.ResHintSize, C.TextMuted, false)
	hint.Name = "Mention"
	hint.LayoutOrder = 0
	hint.Size = UDim2.fromOffset(0, L.ResHintHeight)
	local cols = L.ResCols
	local usable = (ui.contentWidth or 700) - 16 - UITheme.Stroke.ScrollBar - 6
	local cell = math.floor((usable - (cols - 1) * L.ResGap) / cols)
	for order, group in inv.Groups do
		local holder = Instance.new("Frame")
		holder.Name = `Famille_{group.Id}`
		holder.LayoutOrder = order
		holder.BackgroundTransparency = 1
		holder.AutomaticSize = Enum.AutomaticSize.Y
		holder.Size = UDim2.fromOffset(usable, 0)
		holder.Parent = scroll
		list(holder, false, 6, Enum.VerticalAlignment.Top)
		local header = text(holder, group.Name, L.ResHeaderSize, C.TextMuted)
		header.Name = "Famille"
		header.LayoutOrder = 1
		local tiles = Instance.new("Frame")
		tiles.Name = "Tuiles"
		tiles.LayoutOrder = 2
		tiles.BackgroundTransparency = 1
		tiles.AutomaticSize = Enum.AutomaticSize.Y
		tiles.Size = UDim2.fromOffset(usable, 0)
		tiles.Parent = holder
		local grid = Instance.new("UIGridLayout")
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.CellSize = UDim2.fromOffset(cell, L.ResTileH)
		grid.CellPadding = UDim2.fromOffset(L.ResGap, L.ResGap)
		grid.Parent = tiles
		for index, tile in group.Tiles do
			resourceTile(tiles, tile, index)
		end
	end
end

-- Équipement : « Tous » + emplacements possédés (cibles >= FilterHeight), compteur muted, grille de cartes.
local function renderEquipmentList(inventory: Instance, inv: Inventory, selected: string?)
	local h = handlers :: Handlers
	local bar = Instance.new("Frame")
	bar.Name = "Filtres"
	bar.BackgroundTransparency = 1
	bar.Size = UDim2.new(1, 0, 0, L.FilterHeight)
	bar.Parent = inventory
	local count = text(bar, if inv.Cap then `{inv.Count} / {inv.Cap}` else tostring(inv.Count), 14, C.TextMuted, false)
	count.Name = "Compteur"
	count.AutomaticSize = Enum.AutomaticSize.None
	count.AnchorPoint = Vector2.new(1, 0.5)
	count.Position = UDim2.new(1, 0, 0.5, 0)
	count.Size = UDim2.fromOffset(L.CountWidth, 20)
	count.TextXAlignment = Enum.TextXAlignment.Right
	local chips = Instance.new("ScrollingFrame")
	chips.Name = "Emplacements"
	chips.BackgroundTransparency = 1
	chips.BorderSizePixel = 0
	chips.ScrollBarThickness = 0
	chips.AutomaticCanvasSize = Enum.AutomaticSize.X
	chips.CanvasSize = UDim2.new()
	chips.ScrollingDirection = Enum.ScrollingDirection.X
	chips.Size = UDim2.new(1, -L.CountWidth - 6, 1, 0)
	chips.Parent = bar
	list(chips, true, 6)
	for index, filter in inv.Filters do
		local b = chip(chips, `{filter.Label} {filter.Count}`, inv.Slot == filter.Id, ICON.Slots[filter.Id], function()
			h.OnSlot(filter.Id)
		end, L.FilterHeight)
		b.Name = `Filtre_{filter.Id}`
		b.LayoutOrder = index
	end
	if #inv.Cards == 0 then
		-- emplacement choisi sur la poupée sans aucun objet possédé : état honnête, filtres conservés
		local holder = Instance.new("Frame")
		holder.Name = "AucunObjet"
		holder.BackgroundTransparency = 1
		holder.Position = UDim2.fromOffset(0, L.FilterHeight + 6)
		holder.Size = UDim2.new(1, 0, 1, -(L.FilterHeight + 6))
		holder.Parent = inventory
		empty(holder, ICON.Slots[inv.Slot] or ICON.Slots.weapon, "Aucun objet pour cet emplacement", "Il peut tomber à la fin d'un combat")
		return
	end
	local grid = scroller(inventory, "Cartes")
	grid.Position = UDim2.fromOffset(0, L.FilterHeight + 6)
	grid.Size = UDim2.new(1, 0, 1, -(L.FilterHeight + 6))
	padding(grid, 14, 6, 8) -- place pour le badge d'état à cheval sur le bord haut
	ui.cardsScroll, ui.cardsSlot = grid, inv.Slot
	local cols = L.ItemCols
	local width = (ui.contentWidth or 600) - L.DollWidth - L.Gap
	local cell = math.floor((width - 12 - UITheme.Stroke.ScrollBar - 6 - (cols - 1) * L.ItemGap) / cols)
	local layout = Instance.new("UIGridLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.CellSize = UDim2.fromOffset(cell, L.ItemCellH)
	layout.CellPadding = UDim2.fromOffset(L.ItemGap, L.ItemGap + 6)
	layout.Parent = grid
	for index, card in inv.Cards do
		local frame = ItemCard.create(grid, card, {
			Variant = "Tile", NameSize = L.ItemNameSize, LineSize = L.ItemLineSize, ArtSize = L.ItemArt,
			Width = cell, BadgeSize = L.BadgeSize,
		})
		frame.LayoutOrder = index
		-- carte choisie (#73) : contour Selected épais (l'état, jamais la rareté)
		if card.InstanceId == selected then
			local outline = frame:FindFirstChildOfClass("UIStroke")
			if outline then
				outline.Color = C.Selected
				outline.Thickness = UITheme.Stroke.Thick
			end
		end
		local hit = Instance.new("TextButton")
		hit.Name = "Choisir"
		hit.AutoButtonColor = false
		hit.Text = ""
		hit.BackgroundTransparency = 1
		hit.Size = UDim2.fromScale(1, 1)
		hit.ZIndex = 8
		hit.Parent = frame
		hit.Activated:Connect(function()
			h.OnItem(card.InstanceId)
		end)
	end
end

-- Bouton plein de la taille d'un emplacement (poupée) ou d'une action secondaire (Retour).
local function plainButton(parent: Instance, name: string, top: Color3, bottom: Color3, ring: Color3?): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.AutoButtonColor = false
	b.Text = ""
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.BorderSizePixel = 0
	b.Parent = parent
	corner(b, 14)
	UIKit.stroke(b, UITheme.Stroke.Regular, ring)
	gradient(b, top, bottom)
	return b
end

-- Ligne de texte pleine largeur (colonne du détail), repliée si besoin.
local function line(parent: Instance, content: string, size: number, color: Color3?, order: number, wrap: boolean?): TextLabel
	local label = UIKit.text(parent, content, size, { Color = color or C.TextLight, Align = Enum.TextXAlignment.Left })
	label.LayoutOrder = order
	label.Size = UDim2.new(1, 0, 0, math.ceil(size * 1.2))
	if wrap then
		label.TextWrapped = true
		label.AutomaticSize = Enum.AutomaticSize.Y
	else
		label.TextTruncate = Enum.TextTruncate.AtEnd
	end
	return label
end

-- Poupée du héros courant (#73) : emplacements (objet porté ou vide, touchables), PV / ATK finales et leur
-- bonus dans les coins hauts, « x/7 équipés » dans le coin bas droit.
local function renderDoll(doll: Frame, equip: Equip?)
	local h = handlers :: Handlers
	local wide = device ~= "phone"
	local S, M, R, G = L.SlotSize, L.DollMid, L.HeroRow, L.DollGap
	local gridW, gridH = 2 * S + M + 2 * G, 3 * S + R + 3 * G
	local spare = math.max(math.floor((L.DollWidth - gridW) / 2), 6)
	local grid = Instance.new("Frame")
	grid.Name = "Poupee"
	grid.BackgroundTransparency = 1
	grid.AnchorPoint = Vector2.new(0.5, 0.5)
	grid.Position = UDim2.new(0.5, 0, 0.5, 26)
	grid.Size = UDim2.fromOffset(gridW, gridH)
	grid.Parent = doll
	local colX = { 0, S + G, S + G + M + G }
	local colW = { S, M, S }
	local rowY = { 0, S + G, S + G + R + G, S + G + R + G + S + G }
	local rowH = { S, R, S, S }
	local portrait = box(grid, "Heros", Color3.new(1, 1, 1), 0, 14, UITheme.Stroke.Regular)
	gradient(portrait, C.Cream, C.SandWarm)
	portrait.Position = UDim2.fromOffset(colX[2], rowY[2])
	portrait.Size = UDim2.fromOffset(colW[2], rowH[2])
	portrait.ClipsDescendants = true
	local hero = lastState and lastState.EquipHero
	local model = hero and Icons.heroModel(hero.HeroId)
	if model then
		UIKit.portrait(portrait, model)
	end
	local filled: { [string]: EquipmentModel.DollSlot } = {}
	if equip then
		for _, s in equip.Doll.Slots do
			filled[s.Slot] = s
		end
	end
	for _, slot in SLOT_GRID do
		local id, col, row = slot.Id, slot.Col, slot.Row
		local worn = filled[id]
		local on = equip ~= nil and equip.Slot == id
		local cell = if worn and worn.InstanceId
			then plainButton(grid, id, C.Cream, C.Sand, if on then C.Selected else nil)
			else plainButton(grid, id, C.Ink, C.Ink, if on then C.Selected else C.StoneGrey)
		cell.Position = UDim2.fromOffset(colX[col] + (colW[col] - S) / 2, rowY[row] + (rowH[row] - S) / 2)
		cell.Size = UDim2.fromOffset(S, S)
		if not (worn and worn.InstanceId) then
			cell.BackgroundTransparency = 0.5
		end
		local ring = cell:FindFirstChildOfClass("UIStroke")
		if ring and on then
			ring.Thickness = UITheme.Stroke.Thick
		end
		if worn and worn.InstanceId then
			-- objet porté : icône du catalogue (jamais teintée), sinon deux lettres du nom
			local icon = ItemCard.icon(cell, { Icon = worn.Icon, Name = worn.Name or id } :: any, math.floor(S * 0.72))
			icon.ZIndex = 2
		else
			local glyph = image(cell, ICON.Slots[id], math.floor(S * 0.52))
			glyph.AnchorPoint = Vector2.new(0.5, 0.5)
			glyph.Position = UDim2.fromScale(0.5, 0.5)
			glyph.ImageTransparency = T.Disabled
		end
		if wide then
			local tag = pill(cell, ItemConfig.SlotTypeNames[id] or id, C.WoodDeep, L.DollTagSize)
			tag.AnchorPoint = Vector2.new(0.5, 0.5)
			tag.Position = UDim2.new(0.5, 0, 1, 0)
			tag.ZIndex = 3
			for _, child in tag:GetDescendants() do
				if child:IsA("GuiObject") then child.ZIndex = 4 end
			end
		end
		cell.Activated:Connect(function()
			h.OnDollSlot(id, if worn then worn.InstanceId else nil)
		end)
	end
	if not equip then
		return
	end
	-- coins libres de la grille : PV (haut gauche), ATK (haut droit), compteur (bas droit)
	local cornerW = S + spare - 6
	local function cornerBox(name: string, x: number, y: number, align: Enum.HorizontalAlignment): Frame
		local f = Instance.new("Frame")
		f.Name = name
		f.BackgroundTransparency = 1
		f.Position = UDim2.fromOffset(x, y)
		f.Size = UDim2.fromOffset(cornerW, S)
		f.Parent = grid
		local l = list(f, false, 0)
		l.HorizontalAlignment = align
		return f
	end
	local stats = equip.Doll.Stats
	if stats then
		for index, stat in stats do
			local left = index == 1
			local f = cornerBox(stat.Key, if left then -(spare - 6) else colX[3], rowY[1], if left then Enum.HorizontalAlignment.Left else Enum.HorizontalAlignment.Right)
			local value = text(f, stat.ValueText, L.DollStatSize)
			value.LayoutOrder = 1
			if stat.BonusText then
				local extra = text(f, stat.BonusText, L.DollStatSize, C.SuccessLight)
				extra.LayoutOrder = 2
			end
		end
	end
	local count = cornerBox("Equipes", colX[3], rowY[4], Enum.HorizontalAlignment.Right)
	text(count, `{equip.Doll.Count}/{equip.Doll.Total}`, L.DollStatSize + 2).LayoutOrder = 1
	text(count, "équipés", L.EquipNoteSize, C.TextMuted, false).LayoutOrder = 2
end

-- Détail de l'objet choisi (#73), à la place de la poupée : en-tête (icône, nom, rareté en texte via
-- ItemCard, emplacement), bonus, état, comparaison pour le héros courant, refus du serveur, raison, puis
-- « Retour » et UNE action principale.
local function renderItemDetail(doll: Frame, equip: Equip, topHeight: number)
	local h = handlers :: Handlers
	local card = equip.Card :: InventoryModel.ItemCard
	local d = equip.Detail :: EquipmentModel.Detail
	local area = Instance.new("Frame")
	area.Name = "Detail"
	area.BackgroundTransparency = 1
	area.Position = UDim2.fromOffset(10, topHeight)
	area.Size = UDim2.new(1, -20, 1, -topHeight - 10)
	area.Parent = doll
	-- en-tête
	local head = Instance.new("Frame")
	head.Name = "Objet"
	head.BackgroundTransparency = 1
	head.Size = UDim2.new(1, 0, 0, L.EquipIcon)
	head.Parent = area
	local art = box(head, "Illustration", C.Sand, 0.1, 10, UITheme.Stroke.Regular)
	art.Size = UDim2.fromOffset(L.EquipIcon, L.EquipIcon)
	art.ClipsDescendants = true
	ItemCard.icon(art, card, L.EquipIcon - 10)
	local info = Instance.new("Frame")
	info.BackgroundTransparency = 1
	info.Position = UDim2.fromOffset(L.EquipIcon + 8, 0)
	info.Size = UDim2.new(1, -(L.EquipIcon + 8), 1, 0)
	info.Parent = head
	list(info, false, 0)
	line(info, card.Name, L.EquipNameSize, nil, 1)
	-- rareté : texte, par le point d'accès unique ItemCard.rarity ; puis l'emplacement
	line(info, ItemCard.rarityLine(card), L.EquipNoteSize, C.TextMuted, 2)
	-- bas : Retour + action principale
	local bottom = Instance.new("Frame")
	bottom.Name = "Actions"
	bottom.BackgroundTransparency = 1
	bottom.AnchorPoint = Vector2.new(0, 1)
	bottom.Position = UDim2.fromScale(0, 1)
	bottom.Size = UDim2.new(1, 0, 0, L.EquipCtaHeight + 5)
	bottom.Parent = area
	local back = plainButton(bottom, "Retour", C.WoodLight, C.Wood)
	back.Size = UDim2.fromOffset(L.BackWidth, L.EquipCtaHeight)
	UIKit.text(back, "Retour", L.EquipNoteSize)
	back.Activated:Connect(h.OnItemBack)
	local a = d.Action
	local on = a.Enabled and not equip.Busy
	local holder, face = chunky(bottom, L.EquipCtaHeight,
		if on then C.GoldLight else C.Disabled, if on then C.GoldDeep else C.StoneGrey, if on then C.GoldLip else C.DisabledLip, function()
			if on then h.OnEquipAction() end
		end)
	holder.Name = "Principale"
	holder.Position = UDim2.fromOffset(L.BackWidth + 8, 0)
	holder.Size = UDim2.new(1, -(L.BackWidth + 8), 0, L.EquipCtaHeight + 5)
	local label = UIKit.text(face, a.Label, L.EquipCtaSize)
	label.ZIndex = 3
	label.TextTransparency = if on then 0 else T.Disabled
	-- corps : lignes défilantes entre l'en-tête et les actions (rien n'est coupé sur téléphone)
	local body = scroller(area, "Lignes")
	body.Position = UDim2.fromOffset(0, L.EquipIcon + L.EquipGap + 2)
	body.Size = UDim2.new(1, 0, 1, -(L.EquipIcon + L.EquipGap + 2) - (L.EquipCtaHeight + 5) - L.EquipGap)
	padding(body, 0, 2, 0)
	list(body, false, L.EquipGap, Enum.VerticalAlignment.Top)
	local order = 0
	local function add(content: string, size: number, color: Color3?, wrap: boolean?): TextLabel
		order += 1
		return line(body, content, size, color, order, wrap)
	end
	if card.BonusText then
		add(card.BonusText, L.EquipTextSize, C.GoldLight)
	end
	add(d.State.Label, L.EquipTextSize, if d.State.Kind == "Available" then C.TextLight else C.SuccessLight)
	if d.Replaces then
		add(`Remplace : {d.Replaces}`, L.EquipNoteSize, C.TextMuted, true)
	end
	if d.Note then
		add(d.Note, L.EquipNoteSize, C.TextMuted, true)
	end
	-- avant → après pour le héros courant ; le signe est écrit, la couleur ne fait que le doubler
	for _, compare in d.Lines do
		add(compare.Text, L.EquipTextSize,
			if compare.Delta > 0 then C.SuccessLight elseif compare.Delta < 0 then C.Error else C.TextLight)
	end
	if equip.Error then
		add(equip.Error, L.EquipNoteSize, C.Error, true).Name = "Erreur"
	end
	if a.Reason then
		add(a.Reason, L.EquipNoteSize, C.TextMuted, true).Name = "Raison"
	end
end

-- Clé de rendu de l'onglet Équipement (#73) : tout ce que la poupée et le détail affichent.
local function equipKey(e: Equip?): string
	if not e then
		return ""
	end
	local parts = { e.Hero or "", e.Selected or "", e.Error or "", tostring(e.Busy), e.Slot, e.Doll.CountText }
	for _, s in e.Doll.Slots do
		table.insert(parts, s.InstanceId or "-")
	end
	for _, stat in e.Doll.Stats or {} do
		table.insert(parts, stat.Text)
	end
	local d = e.Detail
	if d then
		for _, value in { d.State.Label, d.Action.Label, tostring(d.Action.Enabled), d.Action.Reason or "", d.Note or "", d.Replaces or "" } do
			table.insert(parts, value)
		end
		for _, compare in d.Lines do
			table.insert(parts, compare.Text)
		end
	end
	return table.concat(parts, "|")
end

local function renderOther(state: State)
	local inv = state.Inventory
	local key = table.concat({ state.Tab, device, state.EquipHero and state.EquipHero.HeroId or "", state.EquipHero and state.EquipHero.Level or 0,
		if inv then inv.Revision else -1, if inv then inv.Slot else "", if inv then inv.FreshCount else 0, equipKey(state.Equip) }, "|")
	if ui.otherKey == key then
		return
	end
	-- la liste des cartes garde sa position de défilement quand elle est redessinée sur le même filtre
	local previous: ScrollingFrame? = ui.cardsScroll
	local keepSlot = ui.cardsSlot
	local keepCanvas = if previous and previous.Parent then previous.CanvasPosition else nil
	ui.cardsScroll, ui.cardsSlot = nil, nil
	ui.otherKey = key
	local h = handlers :: Handlers
	local wide = device ~= "phone"
	local other = ui.other
	clearChildren(other)
	local loaded = inv ~= nil and inv.Loaded
	if state.Tab == "Resources" then
		if not inv or not loaded then
			-- remotes absents ou réponse pas encore reçue : jamais présenté comme un inventaire vide
			empty(other, ICON.Tabs.Resources, "Inventaire indisponible", "Réessaie dans un instant")
		elseif #inv.Groups == 0 then
			empty(other, ICON.Tabs.Resources, "Aucune ressource", "Gagne des combats pour en obtenir")
		else
			renderResources(other, inv)
		end
		return
	end
	-- Équipement : poupée du héros courant (ou détail de l'objet choisi) à gauche, exemplaires possédés à droite
	local doll = box(other, "Poupee", C.Ink, 0.45, 14, UITheme.Stroke.Regular)
	doll.Size = UDim2.new(0, L.DollWidth, 1, 0)
	local hero = state.EquipHero
	local top = Instance.new("Frame")
	top.BackgroundTransparency = 1
	top.Position = UDim2.fromOffset(10, 10)
	top.Size = UDim2.new(1, -20, 0, UITheme.Spacing.TouchTarget)
	top.Parent = doll
	local function arrow(content: string, x: number, step: number)
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.Text = ""
		b.BackgroundColor3 = Color3.new(1, 1, 1)
		b.AnchorPoint = Vector2.new(x, 0)
		b.Position = UDim2.fromScale(x, 0)
		b.Size = UDim2.fromOffset(UITheme.Spacing.TouchTarget, UITheme.Spacing.TouchTarget)
		b.Parent = top
		corner(b, 999)
		UIKit.stroke(b, UITheme.Stroke.Regular)
		gradient(b, C.WoodLight, C.Wood)
		UIKit.text(b, content, 20)
		b.Activated:Connect(function()
			h.OnEquipHero(step)
		end)
	end
	arrow("<", 0, -1)
	arrow(">", 1, 1)
	local names = Instance.new("Frame")
	names.BackgroundTransparency = 1
	names.Position = UDim2.fromOffset(UITheme.Spacing.TouchTarget + 6, 0)
	names.Size = UDim2.new(1, -2 * (UITheme.Spacing.TouchTarget + 6), 1, 0)
	names.Parent = top
	local nl = list(names, false, 0)
	nl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local heroName = UIKit.text(names, if hero then hero.Name else "Aucun héros", if wide then 20 else 15)
	heroName.Size = UDim2.new(1, 0, 0, if wide then 22 else 17)
	heroName.TextTruncate = Enum.TextTruncate.AtEnd
	heroName.LayoutOrder = 1
	-- niveau ; le compteur « x/7 équipés » est dans le coin bas droit de la poupée (#73)
	local sub = UIKit.text(names, if hero then `Nv. {hero.Level}` else "", L.EquipNoteSize, { Color = C.TextMuted, Stroke = false })
	sub.Size = UDim2.new(1, 0, 0, 18)
	sub.LayoutOrder = 2
	-- poupée (grille 3 x 4 : héros au centre, emplacements autour), ou détail de l'objet choisi (#73)
	local equip = state.Equip
	if equip and equip.Detail and equip.Card then
		renderItemDetail(doll, equip, 10 + UITheme.Spacing.TouchTarget + 8)
	else
		renderDoll(doll, equip)
	end
	local inventory = Instance.new("Frame")
	inventory.Name = "Inventaire"
	inventory.BackgroundTransparency = 1
	inventory.Position = UDim2.new(0, L.DollWidth + L.Gap, 0, 0)
	inventory.Size = UDim2.new(1, -(L.DollWidth + L.Gap), 1, 0)
	inventory.Parent = other
	if not inv or not loaded then
		empty(inventory, ICON.Slots.weapon, "Inventaire indisponible", "Réessaie dans un instant")
	elseif #inv.Filters == 0 or inv.Filters[1].Count == 0 then
		empty(inventory, ICON.Slots.weapon, "Aucun équipement", "Il peut tomber à la fin d'un combat")
	else
		renderEquipmentList(inventory, inv, if equip then equip.Selected else nil)
		local scroll: ScrollingFrame? = ui.cardsScroll
		if scroll and keepCanvas and keepSlot == inv.Slot then
			task.defer(function()
				if scroll.Parent then scroll.CanvasPosition = keepCanvas end
			end)
		end
	end
end

------------------------------------------------------------------ API

function SacocheView.Mount(parent: Instance, h: Handlers)
	handlers = h
	buildWindow(parent)
	applyLayout()
end

function SacocheView.Render(state: State)
	lastState = state
	if not ui.frame or not opened then
		return
	end
	renderTabs(state)
	local heroes = state.Tab == "Heroes"
	ui.heroes.Visible = heroes
	ui.other.Visible = not heroes
	if heroes then
		local filterKey = `{state.Filter}|{state.SearchOpen}|{device}`
		if ui.filterKey ~= filterKey then
			ui.filterKey = filterKey
			renderFilters(state)
		end
		renderCards(state)
		renderDetail(state)
	else
		renderOther(state)
	end
end

function SacocheView.IsOpen(): boolean
	return opened
end

function SacocheView.Card(id: string): GuiObject?
	local entry = cards[id]
	return if entry then entry.button else nil
end

-- Ouverture au centre : scale 0,94 → 1,01 → 1 (× échelle de la zone) et fondu de la fenêtre.
function SacocheView.Open()
	local frame = ui.frame
	if not frame or opened then
		return
	end
	opened = true
	tabKey, detailKey, ui.filterKey, ui.otherKey = "", "", nil, nil
	frame.Visible = true
	local fit = ui.fit or 1
	ui.animating = true
	ui.scale.Scale = fit * 0.94
	ui.window.BackgroundTransparency = 1
	local grow = TweenInfo.new(PACK.Open * 0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(ui.scale, grow, { Scale = fit * 1.01 }):Play()
	TweenService:Create(ui.window, grow, { BackgroundTransparency = 0.2 }):Play()
	task.delay(PACK.Open * 0.7, function()
		if opened then
			TweenService:Create(ui.scale, TweenInfo.new(PACK.Open * 0.3, Enum.EasingStyle.Quad), { Scale = ui.fit or fit }):Play()
		end
		task.delay(PACK.Open * 0.3, function()
			ui.animating = false
		end)
	end)
	if lastState then
		SacocheView.Render(lastState)
	end
end

function SacocheView.Close()
	local frame = ui.frame
	if not frame or not opened then
		return
	end
	opened = false
	stopLoops()
	ui.animating = true
	local fit = ui.fit or 1
	local t = TweenService:Create(ui.scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = fit * 0.94 })
	t:Play()
	TweenService:Create(ui.window, TweenInfo.new(0.12), { BackgroundTransparency = 1 }):Play()
	t.Completed:Connect(function()
		ui.animating = false
		if not opened then
			frame.Visible = false
			ui.scale.Scale = ui.fit or fit
		end
	end)
end

return SacocheView
