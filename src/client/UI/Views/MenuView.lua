--!strict
-- Menu principal (HUD, à gauche) — reproduit le menu de la maquette « Quêtes HUD » (pack validé).
-- Présentation seulement : MenuController décide de ce qu'ouvre chaque bouton, des « ! » et des mises
-- en avant. Icônes : PNG du pack (Shared.Config.MenuIconConfig), mesures : UITheme.Pack.Menu.
--   Grille de 2 colonnes x 3 lignes (Boutique Sac / Index Guilde / Stats Quêtes).
--   Chaque entrée : tuile chunky (face Cream → Sand sur lèvre WoodDark, contour Ink), icône qui déborde
--   au-dessus de la tuile, nom en Fredoka contouré dessous.
--   États :
--     survol      : la tuile gonfle légèrement (souris ; jamais seul indicateur) ;
--     enfoncé     : la tuile se tasse ;
--     sélectionné : face dorée (GoldLight → GoldDeep), contour Selected (sa fenêtre est ouverte) ;
--     attention   : le « ! » du pack (Badge) au coin haut droit, qui flotte doucement ;
--     mis en avant (tutoriel) : halo doré qui respire autour de la tuile, léger gonflement.
-- Chaque tuile est la cible de guidage « Menu.<Id> » (GuideTargets) ; attribut GuideGlow = false : la
-- flèche UI ne dessine pas son cadre, le halo du menu le remplace.
-- Placement : MenuView.Fit(top, bottom) le place dans la bande libre (coordonnées absolues), centré, le
-- réduit si elle est trop courte et l'agrandit un peu si elle est haute. Bande trop basse pour la grille
-- (téléphone en paysage) : les icônes passent sur une seule ligne. Sa zone est la cible « Menu.Area »
-- (la sacoche s'ouvre juste à côté, la flèche UI se place à sa droite).
-- API : MenuView.Build(entries, onSelect) ; SetSelected(id?) ; SetAttention(id, on) ; SetHighlighted(id, on) ;
--   IsAttention(id) ; IsHighlighted(id) ; SetVisible(on) ; Fit(top, bottom).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local MenuIconConfig = require(ReplicatedStorage.Shared.Config.MenuIconConfig)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local GuideTargets = require(script.Parent.Parent.GuideTargets)
local UIKit = require(script.Parent.Parent.UIKit)

local Colors = UITheme.Colors
local Animation = UITheme.Animation
local GUIDE = UITheme.World.Guide
local PACK = UITheme.Pack.Menu

local LIP = UITheme.Shadow.ButtonLip -- la face est posée quelques px au-dessus de sa lèvre
local CELL = Vector2.new(PACK.Column, PACK.IconRise + PACK.Tile.Y + PACK.LabelHeight)
local COLUMNS = 2
local GRID_MIN = 0.8 -- en dessous de cette réduction, la grille passe sur une seule ligne
local MIN_FIT = 0.55 -- réduction maximale quand la place manque
local MAX_FIT = 1.3 -- agrandissement maximal quand la bande est haute (petit écran de PC : icônes lisibles)
local HALO = 8 -- px de halo autour de la tuile mise en avant

export type Entry = { Id: string, Label: string }

type ButtonUI = {
	id: string,
	holder: Frame,
	tile: TextButton,
	gradient: UIGradient,
	faceStroke: UIStroke,
	icon: ImageLabel,
	press: UIScale,
	pulse: UIScale,
	halo: Frame,
	haloStroke: UIStroke,
	badge: ImageLabel,
	selected: boolean,
	attention: boolean,
	highlighted: boolean,
}

local MenuView = {}

local buttons: { [string]: ButtonUI } = {}
local screen: ScreenGui? = nil
local column: Frame? = nil
local fit: UIScale? = nil
local grid: UIGridLayout? = nil
local animation: RBXScriptConnection? = nil
local count = 0

local function paint(button: ButtonUI)
	local top, bottom = Colors.Cream, Colors.Sand
	if button.selected then
		top, bottom = Colors.GoldLight, Colors.GoldDeep
	end
	button.gradient.Color = ColorSequence.new(top, bottom)
	button.faceStroke.Color = if button.selected then Colors.Selected else UITheme.Stroke.Color
	button.halo.Visible = button.highlighted
	button.badge.Visible = button.attention
end

-- Animations continues (« ! » qui flotte, halo qui respire) : une seule connexion, coupée quand plus
-- aucun bouton n'en a besoin.
local function step()
	local now = os.clock()
	local any = false
	local bob = math.sin(now * 2 * math.pi / PACK.BadgePeriod)
	local wave = 0.5 + 0.5 * math.sin(now * 2 * math.pi / GUIDE.Period)
	for _, button in buttons do
		if button.attention then
			any = true
			button.badge.Position = UDim2.new(1, PACK.BadgeOffset.X, 0, PACK.BadgeOffset.Y + PACK.BadgeBob * bob)
		end
		if button.highlighted then
			any = true
			button.halo.BackgroundTransparency = 0.75 - 0.3 * wave
			button.haloStroke.Transparency = 0.5 * (1 - wave)
			button.pulse.Scale = 1 + (Animation.Scale.Highlight - 1) * wave
		end
	end
	if not any and animation then
		animation:Disconnect()
		animation = nil
	end
end

local function animate()
	if not animation then
		animation = RunService.RenderStepped:Connect(step)
	end
end

local function build(parent: Instance, entry: Entry, order: number, onSelect: (string) -> ()): ButtonUI
	local holder = Instance.new("Frame")
	holder.Name = entry.Id
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(CELL.X, CELL.Y)
	holder.LayoutOrder = order

	-- tuile : lèvre bois + face crème, centrée dans la colonne, sous l'icône qui dépasse
	local tile = Instance.new("TextButton")
	tile.Name = "Tuile"
	tile.AutoButtonColor = false
	tile.Text = ""
	tile.AnchorPoint = Vector2.new(0.5, 0)
	tile.Position = UDim2.new(0.5, 0, 0, PACK.IconRise)
	tile.Size = UDim2.fromOffset(PACK.Tile.X, PACK.Tile.Y)
	tile.BackgroundColor3 = Colors.WoodDark
	tile:SetAttribute("GuideGlow", false)
	tile.Parent = holder
	UIKit.corner(tile, UITheme.Radius.Large)
	UIKit.stroke(tile, UITheme.Stroke.Regular)
	local press = Instance.new("UIScale")
	press.Parent = tile

	local halo = Instance.new("Frame")
	halo.Name = "Halo"
	halo.Active = false
	halo.BackgroundColor3 = GUIDE.Color
	halo.Position = UDim2.fromOffset(-HALO, -HALO - LIP)
	halo.Size = UDim2.new(1, 2 * HALO, 1, 2 * HALO)
	halo.Visible = false
	halo.ZIndex = 0
	halo.Parent = tile
	UIKit.corner(halo, UDim.new(0, UITheme.Radius.Large.Offset + HALO))
	local haloStroke = UIKit.stroke(halo, UITheme.Stroke.Thick, GUIDE.Color)

	local face = Instance.new("Frame")
	face.Name = "Face"
	face.Active = false
	face.BackgroundColor3 = Color3.new(1, 1, 1)
	face.Position = UDim2.fromOffset(0, -LIP)
	face.Size = UDim2.fromScale(1, 1)
	face.ZIndex = 2
	face.Parent = tile
	UIKit.corner(face, UITheme.Radius.Large)
	local faceStroke = UIKit.stroke(face, UITheme.Stroke.Regular)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Parent = face

	local config = MenuIconConfig.Buttons[entry.Id]
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icone"
	icon.Active = false
	icon.BackgroundTransparency = 1
	icon.Image = if config then config.Icon else ""
	icon.ScaleType = Enum.ScaleType.Fit
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.new(0.5, 0, 0, -PACK.IconRise)
	icon.Size = UDim2.fromOffset(PACK.Icon, PACK.Icon)
	icon.ZIndex = 3
	icon.Parent = tile

	local badge = Instance.new("ImageLabel")
	badge.Name = "Attention"
	badge.Active = false
	badge.BackgroundTransparency = 1
	badge.Image = MenuIconConfig.Badge
	badge.ScaleType = Enum.ScaleType.Fit
	badge.Position = UDim2.new(1, PACK.BadgeOffset.X, 0, PACK.BadgeOffset.Y)
	badge.Size = UDim2.fromOffset(PACK.Badge.X, PACK.Badge.Y)
	badge.Visible = false
	badge.ZIndex = 5
	badge.Parent = tile

	local label = UIKit.text(holder, entry.Label, PACK.Label)
	label.Name = "Nom"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, 0)
	label.Size = UDim2.fromOffset(CELL.X + 16, PACK.LabelHeight)
	label.ZIndex = 4

	local pulse = Instance.new("UIScale")
	pulse.Name = "Respiration"
	pulse.Parent = holder

	local ui: ButtonUI = {
		id = entry.Id, holder = holder, tile = tile, gradient = gradient, faceStroke = faceStroke,
		icon = icon, press = press, pulse = pulse, halo = halo, haloStroke = haloStroke, badge = badge,
		selected = false, attention = false, highlighted = false,
	}
	paint(ui)
	tile.MouseEnter:Connect(function()
		TweenService:Create(press, Animation.Hover, { Scale = Animation.Scale.Hover }):Play()
	end)
	tile.MouseLeave:Connect(function()
		TweenService:Create(press, Animation.Hover, { Scale = 1 }):Play()
	end)
	tile.MouseButton1Down:Connect(function()
		TweenService:Create(press, Animation.Press, { Scale = Animation.Scale.Pressed }):Play()
	end)
	tile.MouseButton1Up:Connect(function()
		TweenService:Create(press, Animation.Hover, { Scale = 1 }):Play()
	end)
	tile.Activated:Connect(function()
		onSelect(entry.Id)
	end)
	holder.Parent = parent
	GuideTargets.register(`Menu.{entry.Id}`, tile)
	return ui
end

-- Taille (px, avant échelle) du menu sur `columns` colonnes.
local function sizeFor(columns: number): Vector2
	local rows = math.ceil(count / columns)
	local gapY = PACK.GapY - PACK.IconRise
	return Vector2.new(columns * CELL.X + (columns - 1) * PACK.GapX, rows * CELL.Y + (rows - 1) * gapY)
end

-- Construit le menu (une seule fois : un nouvel appel remplace l'ancien écran et ses connexions).
function MenuView.Build(entries: { Entry }, onSelect: (string) -> ())
	if screen then
		screen:Destroy()
	end
	if animation then
		animation:Disconnect()
		animation = nil
	end
	table.clear(buttons)
	local s = UIKit.screen("MenuNavigation", 3)
	-- coordonnées sous la barre de Roblox, comme AbsolutePosition : Fit place le menu sans conversion
	s.IgnoreGuiInset = false
	screen = s
	count = #entries
	local frame = Instance.new("Frame")
	frame.Name = "Menu"
	frame.BackgroundTransparency = 1
	frame.Position = UDim2.fromOffset(UITheme.Spacing.ScreenMargin, 0)
	local size = sizeFor(COLUMNS)
	frame.Size = UDim2.fromOffset(size.X, size.Y)
	frame.Parent = s
	column = frame
	GuideTargets.register("Menu.Area", frame)
	local scale = Instance.new("UIScale")
	scale.Name = "Ajustement"
	scale.Parent = frame
	fit = scale
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(CELL.X, CELL.Y)
	layout.CellPadding = UDim2.fromOffset(PACK.GapX, PACK.GapY - PACK.IconRise)
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.FillDirectionMaxCells = COLUMNS
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	grid = layout
	for index, entry in entries do
		buttons[entry.Id] = build(frame, entry, index, onSelect)
	end
end

-- Place le menu dans la bande verticale libre [top, bottom] (px, sous la barre de Roblox).
function MenuView.Fit(top: number, bottom: number)
	local s, frame, scale, layout = screen, column, fit, grid
	if not s or not frame or not scale or not layout then
		return
	end
	local base = s:FindFirstChildOfClass("UIScale")
	local screenScale = if base then base.Scale else 1
	local band = bottom - top
	local columns = COLUMNS
	if band / (sizeFor(COLUMNS).Y * screenScale) < GRID_MIN then
		columns = count -- une seule ligne
	end
	local size = sizeFor(columns)
	if layout.FillDirectionMaxCells ~= columns then
		layout.FillDirectionMaxCells = columns
	end
	if frame.Size.X.Offset ~= size.X or frame.Size.Y.Offset ~= size.Y then
		frame.Size = UDim2.fromOffset(size.X, size.Y)
	end
	local k = math.clamp(band / math.max(size.Y * screenScale, 1), MIN_FIT, MAX_FIT)
	if math.abs(scale.Scale - k) > 0.01 then
		scale.Scale = k
	end
	-- centré verticalement dans la bande (comme la maquette : menu au milieu à gauche)
	local height = size.Y * screenScale * k
	local y = math.max(top, top + (band - height) / 2) / screenScale
	if math.abs(frame.Position.Y.Offset - y) > 0.5 then
		frame.Position = UDim2.fromOffset(UITheme.Spacing.ScreenMargin, y)
	end
end

function MenuView.SetVisible(on: boolean)
	local s = screen
	if s and s.Enabled ~= on then
		s.Enabled = on
	end
end

function MenuView.SetSelected(id: string?)
	for buttonId, button in buttons do
		local on = buttonId == id
		if button.selected ~= on then
			button.selected = on
			paint(button)
		end
	end
end

function MenuView.SetAttention(id: string, on: boolean)
	local button = buttons[id]
	if not button or button.attention == on then
		return
	end
	button.attention = on
	paint(button)
	if on then
		UIKit.popIn(button.badge, 0, Animation.Scale.Pop)
		animate()
	end
end

function MenuView.SetHighlighted(id: string, on: boolean)
	local button = buttons[id]
	if not button or button.highlighted == on then
		return
	end
	button.highlighted = on
	if not on then
		button.pulse.Scale = 1
	end
	paint(button)
	if on then
		animate()
	end
end

function MenuView.IsAttention(id: string): boolean
	local button = buttons[id]
	return button ~= nil and button.attention
end

function MenuView.IsHighlighted(id: string): boolean
	local button = buttons[id]
	return button ~= nil and button.highlighted
end

return MenuView
