--!strict
-- Fenêtre Expédition — reproduit la maquette figée « Expedition.dc.html » (voir docs/ZONES.md § Fenêtre
-- Expédition, docs/UI_DESIGN_SYSTEM.md § Expédition). Présentation seulement : ZoneService dit quels stages
-- sont accessibles, ArenaService envoie l'aperçu de chaque stage (StagePreview : vagues, boss, XP par héros,
-- récompenses de stage réelles, multiplicateurs Élite, butin si #72 le fournit) et revérifie SelectStage /
-- Ready. Aucun chiffre de gameplay ici ; la logique d'affichage est Shared.Expedition.ExpeditionModel.
--   Plaque « Expédition » (épées ; couronne rouge royal en Élite), X ; en-tête : zone, sous-titre, onglets
--   NORMAL / ÉLITE (verrouillé : cadenas, « Verrouillé ») ; rail des 5 stages (barre de progression, badges
--   Disponible / Terminé / Verrouillé / Élite / Boss / Boss · Terminé, carte choisie soulevée, contour doré,
--   pointe) ; Élite verrouillée : voile et « Termine le Stage 1-5 pour débloquer l'Élite » (progression
--   Normal réelle) ; détail : ennemis par vague (vrais modèles en ViewportFrame, ×n), boss (Roi Orc),
--   récompenses (« Première victoire » une fois, « Ensuite / À chaque victoire » avec l'XP par héros),
--   butin possible (masqué / « Butin à venir » sans table réelle) ; pied : équipe X/4 (portraits des héros
--   posés), « Préparer l'équipe » (mis en avant sans héros), « Lancer » (sous-texte : stage ou raison).
--   Trois dispositions (UITheme.Pack.Expedition) : PC, tablette (espacements réduits), téléphone (844 x 390,
--   ses propres tailles, sections compactes).
-- API : ExpeditionView.Show(data, options) ; ExpeditionView.Hide().
--   data = { Zone, Title?, Subtitle?, Stages = { stage }, EliteStages = { stage }?, EliteUnlocked?, Mode?,
--            PreviousZone?, NextZone? } (flèches < > autour du titre, avec options.OnZone(zone) ; pas d'onglet
--            Élite sans EliteStages)
--     stage = { Zone, Stage, Status, Cleared, Waves = { { Enemies = { { EnemyId, Count } } } }, Boss?,
--               HeroXP, FirstClearRewards, RepeatRewards, Multipliers?, PotentialDrops? } (ArenaService)
--   options = { OnLaunch(zone, stage, mode)?, OnClose?, Selected?, OnSelect(zone, stage, mode)?,
--               Team = { Placed, Max, Heroes = { HeroId } }?, OnPrepare?, Guide? }
-- Guidage : cibles « Expedition.Stage » (stage proposé), « Expedition.Launch », « Expedition.Prepare »,
-- « Expedition.Next » (l'action possible) ; la fenêtre signale l'interface « Expedition ».

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)
local CurrencyVisualConfig = require(ReplicatedStorage.Shared.Config.CurrencyVisualConfig)
local ExpeditionModel = require(ReplicatedStorage.Shared.Expedition.ExpeditionModel)
local ExpeditionVisualConfig = require(ReplicatedStorage.Shared.Config.ExpeditionVisualConfig)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local ResourceConfig = require(ReplicatedStorage.Shared.Config.ResourceConfig)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local GuideTargets = require(script.Parent.Parent.GuideTargets)
local Icons = require(script.Parent.Parent.Icons)
local UIKit = require(script.Parent.Parent.UIKit)

local C = UITheme.Colors
local PACK = UITheme.Pack.Expedition
local INK = UITheme.Stroke.Color
local ICON = ExpeditionVisualConfig

export type Stage = ExpeditionModel.Stage & { Waves: { any }?, Multipliers: { MaxHealth: number, AttackDamage: number }? }
export type Data = { Zone: number, Title: string?, Subtitle: string?, Stages: { Stage }, EliteStages: { Stage }?, EliteUnlocked: boolean?, Mode: string?,
	PreviousZone: number?, NextZone: number? }
export type Team = { Placed: number, Max: number, Heroes: { string }? }
export type Options = {
	OnLaunch: ((zone: number, stage: number, mode: string) -> ())?,
	OnClose: (() -> ())?,
	Selected: number?,
	OnSelect: ((zone: number, stage: number, mode: string) -> ())?,
	Team: Team?,
	OnPrepare: (() -> ())?,
	Guide: boolean?,
	OnZone: ((zone: number) -> ())?,
}

local ExpeditionView = {}

type Current = { screen: ScreenGui, panel: Frame, veil: GuiObject, tweens: { Tween }, alive: boolean }
local current: Current? = nil

------------------------------------------------------------------ petits outils

local function corner(parent: Instance, radius: number)
	UIKit.corner(parent, UDim.new(0, radius))
end

local function gradient(parent: Instance, top: Color3, bottom: Color3, rotation: number?)
	local g = Instance.new("UIGradient")
	g.Rotation = rotation or 90
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

local function text(parent: Instance, content: string, size: number, color: Color3?, stroke: boolean?): TextLabel
	local label = UIKit.text(parent, content, size, { Color = color or C.TextLight, Stroke = stroke ~= false })
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromOffset(0, math.ceil(size * 1.15))
	return label
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

local function row(parent: Instance, gap: number, align: Enum.VerticalAlignment?, wraps: boolean?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = align or Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Wraps = wraps == true
	layout.Parent = parent
	return layout
end

local function column(parent: Instance, gap: number): UIListLayout
	local layout = Instance.new("UIListLayout")
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

-- Pastille arrondie (badge) : icône facultative + texte contouré.
local function pill(parent: Instance, content: string, color: Color3, size: number, icon: string?, height: number?): Frame
	local p = box(parent, "Pastille", color, 0, 999, UITheme.Stroke.Thin)
	p.AutomaticSize = Enum.AutomaticSize.X
	p.Size = UDim2.fromOffset(0, height or math.ceil(size * 1.7))
	padding(p, 0, 8, 0)
	row(p, 3)
	if icon then
		image(p, icon, math.floor(size * 1.3)).LayoutOrder = 1
	end
	local label = text(p, content, size)
	label.LayoutOrder = 2
	return p
end

-- Respiration (scale 1 → 1,04) d'un bouton mis en avant, avec un halo doré.
local function breathe(c: Current, holder: GuiObject, halo: UIStroke?)
	local scale = holder:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = holder
	local info = TweenInfo.new(PACK.Breathe / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local t = TweenService:Create(scale, info, { Scale = 1.04 })
	t:Play()
	table.insert(c.tweens, t)
	if halo then
		halo.Transparency = 1
		local h = TweenService:Create(halo, info, { Transparency = 0.4 })
		h:Play()
		table.insert(c.tweens, h)
	end
end

-- Reflet discret qui traverse un bouton (maquette : shine).
local function shine(c: Current, face: GuiObject)
	local band = Instance.new("Frame")
	band.Name = "Reflet"
	band.BackgroundColor3 = Color3.new(1, 1, 1)
	band.BorderSizePixel = 0
	band.AnchorPoint = Vector2.new(0.5, 0.5)
	band.Size = UDim2.new(0.18, 0, 1.6, 0)
	band.Rotation = 20
	band.Position = UDim2.fromScale(-0.3, 0.5)
	band.ZIndex = (face.ZIndex :: number) + 3
	band.Parent = face
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.5), NumberSequenceKeypoint.new(1, 1) })
	fade.Parent = band
	task.spawn(function()
		while c.alive and band.Parent do
			band.Position = UDim2.fromScale(-0.3, 0.5)
			local t = TweenService:Create(band, TweenInfo.new(PACK.Shine * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Position = UDim2.fromScale(1.3, 0.5) })
			t:Play()
			task.wait(PACK.Shine)
		end
	end)
end

export type Chunky = { holder: Frame, face: TextButton, halo: UIStroke }

-- Bouton chunky de la maquette : face en dégradé sur une lèvre plus sombre, contour Ink épais, enfoncé au clic.
local function chunky(parent: Instance, size: Vector2, top: Color3, bottom: Color3, lip: Color3, onClick: () -> ()): Chunky
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(size.X, (size.Y :: number) + 5)
	holder.Parent = parent
	local lipFrame = box(holder, "Levre", lip, 0, 14, 4)
	lipFrame.Position = UDim2.fromOffset(0, 5)
	lipFrame.Size = UDim2.fromOffset(size.X, size.Y)
	local face = Instance.new("TextButton")
	face.Name = "Face"
	face.AutoButtonColor = false
	face.Text = ""
	face.BackgroundColor3 = Color3.new(1, 1, 1)
	face.BorderSizePixel = 0
	face.ClipsDescendants = true
	face.Size = UDim2.fromOffset(size.X, size.Y)
	face.ZIndex = 2
	face.Parent = holder
	corner(face, 14)
	UIKit.stroke(face, 4)
	gradient(face, top, bottom)
	-- halo doré (mis en avant), sur un cadre à part : la face garde son contour Ink
	local haloFrame = Instance.new("Frame")
	haloFrame.Name = "Halo"
	haloFrame.BackgroundTransparency = 1
	haloFrame.Position = UDim2.fromOffset(-4, -4)
	haloFrame.Size = UDim2.new(1, 8, 0, (size.Y :: number) + 8)
	haloFrame.Parent = holder
	corner(haloFrame, 18)
	local halo = UIKit.stroke(haloFrame, 6, C.GoldLight)
	halo.Transparency = 1
	face.MouseButton1Down:Connect(function()
		TweenService:Create(face, UITheme.Animation.Press, { Position = UDim2.fromOffset(0, 4) }):Play()
	end)
	local function release()
		TweenService:Create(face, UITheme.Animation.Press, { Position = UDim2.fromOffset(0, 0) }):Play()
	end
	face.MouseButton1Up:Connect(release)
	face.MouseLeave:Connect(release)
	face.Activated:Connect(onClick)
	return { holder = holder, face = face, halo = halo }
end

-- Portrait d'un vrai modèle (ennemi, héros) dans une tuile sable ; rien si le modèle n'est pas répliqué.
local function portrait(parent: Instance, model: Model?, full: boolean?)
	if model then
		local view = UIKit.portrait(parent, model, full)
		view.ZIndex = (parent :: any).ZIndex + 1
	end
end

------------------------------------------------------------------ disposition

local function layoutFor(device: string): { [string]: any }
	local L = table.clone(if device == "phone" then PACK.Phone else PACK.Wide)
	if device == "tablet" then
		for key, value in PACK.Tablet do
			L[key] = value
		end
		L.Window = PACK.Wide.Window
		L.Top = PACK.Wide.Top
	end
	return L
end

-- Échelle de la disposition : la maquette est dessinée pour son écran de référence (Device).
local function scaleFor(L: { [string]: any }, viewport: Vector2, device: string): number
	local device2: Vector2 = L.Device
	local s = math.min(viewport.X / device2.X, viewport.Y / device2.Y)
	if device == "phone" then
		return math.clamp(s, 0.85, 1.4)
	end
	return math.clamp(s, 0.7, 1.3)
end

------------------------------------------------------------------ vue

function ExpeditionView.Show(data: Data, options: Options?)
	ExpeditionView.Hide()
	local opts: Options = options or {}
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1600, 900)
	local device = ExpeditionModel.device(viewport.X, viewport.Y)
	local wide = device ~= "phone"
	local L = layoutFor(device)

	local screen = Instance.new("ScreenGui")
	screen.Name = "Expedition"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.DisplayOrder = 10
	local uiScale = Instance.new("UIScale")
	uiScale.Scale = scaleFor(L, viewport, device)
	uiScale.Parent = screen
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local veil = UIKit.overlay(screen)
	local W, H = L.Window.X, L.Window.Y
	local panel = Instance.new("Frame")
	panel.Name = "Panneau"
	panel.BackgroundTransparency = 1
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.new(0.5, 0, 0.5, L.Top - (L.Device.Y - H) / 2)
	panel.Size = UDim2.fromOffset(W, H)
	panel.Parent = screen
	local c: Current = { screen = screen, panel = panel, veil = veil, tweens = {}, alive = true }
	current = c

	local function close()
		ExpeditionView.Hide()
		if opts.OnClose then
			opts.OnClose()
		end
	end
	veil.Activated:Connect(close)

	local team: Team = opts.Team or { Placed = 0, Max = ArenaConfig.MaxHeroes, Heroes = {} }
	local mode: string = if data.Mode == "Elite" and data.EliteStages then "Elite" else "Normal"
	local eliteUnlocked = data.EliteUnlocked == true
	local selected: Stage? = nil
	local dynamic: { Instance } = {}
	local render: () -> ()

	local function stagesOf(m: string): { Stage }
		return if m == "Elite" then data.EliteStages or {} else data.Stages
	end
	local function track(instance: Instance)
		table.insert(dynamic, instance)
	end

	-- fenêtre : bois sombre, contour Ink ; en Élite, liseré intérieur rouge royal
	local window = box(panel, "Fenetre", C.WoodDeep, 0.22, 18, UITheme.Stroke.Thick)
	window.Size = UDim2.fromScale(1, 1)
	local eliteLine = box(window, "LisereElite", C.WoodDeep, 1, 15, 3, C.RoyalRed)
	eliteLine.Position = UDim2.fromOffset(3, 3)
	eliteLine.Size = UDim2.new(1, -6, 1, -6)

	local closeButton = UIKit.roundButton(panel, { Text = "X", Name = "Fermer", OnClick = close })
	closeButton.AnchorPoint = Vector2.new(0.5, 0.5)
	closeButton.Position = UDim2.new(1, -4, 0, 4)
	closeButton.ZIndex = 8

	-- y courant dans la fenêtre
	local x0, inner = L.Pad.Side, W - 2 * L.Pad.Side
	local headHeight = L.ModeHeight + 8 + 2 * L.HeadPad
	local railHeight = L.RailPad.Top + L.NodeHeightBoss + L.RailPad.Bottom
	local footHeight = L.CtaHeight + 5
	local yHead = L.Pad.Top
	local yRail = yHead + headHeight + L.Gap
	local yDetail = yRail + railHeight + L.Gap
	local yFoot = H - L.Pad.Bottom - footHeight
	local detailHeight = yFoot - L.Gap - yDetail

	render = function()
		for _, instance in dynamic do
			instance:Destroy()
		end
		table.clear(dynamic)
		for _, t in c.tweens do
			t:Cancel()
		end
		table.clear(c.tweens)
		local elite = mode == "Elite"
		local eliteOpen = elite and eliteUnlocked
		local eliteLocked = elite and not eliteUnlocked
		local stages = stagesOf(mode)
		local nodes = ExpeditionModel.nodes(stages, mode, eliteUnlocked)
		eliteLine.Visible = elite
		local stage = selected
		if not stage then
			stage = ExpeditionModel.default(stages, mode, eliteUnlocked, opts.Selected) -- stage choisi côté serveur (SelectStage)
			selected = stage
		end

		-- plaque de titre « Expédition »
		local plate = box(panel, "Titre", C.Wood, 0, 12, 4)
		track(plate)
		plate.AnchorPoint = Vector2.new(0.5, 0)
		plate.Position = UDim2.new(0.5, 0, 0, L.TabTop)
		plate.AutomaticSize = Enum.AutomaticSize.X
		plate.Size = UDim2.fromOffset(0, L.TabIcon + 10)
		plate.ZIndex = 6
		if elite then
			gradient(plate, C.EliteTop, C.EliteBottom)
			plate.BackgroundColor3 = Color3.new(1, 1, 1)
		end
		padding(plate, 0, 24, 0)
		row(plate, 8)
		local plateIcon = image(plate, if elite then ICON.Crown else ICON.Swords, L.TabIcon)
		plateIcon.ZIndex = 7
		local plateText = text(plate, "Expédition", L.TabSize)
		plateText.ZIndex = 7

		-- en-tête : zone, sous-titre, onglets Normal / Élite
		local head = box(window, "Entete", C.Ink, if elite then 0 else 0.65, 14, 3, if elite then C.GoldLight else INK)
		track(head)
		head.Position = UDim2.fromOffset(x0, yHead)
		head.Size = UDim2.fromOffset(inner, headHeight)
		if elite then
			head.BackgroundColor3 = Color3.new(1, 1, 1)
			local g = Instance.new("UIGradient")
			g.Color = ColorSequence.new(C.RoyalRed, C.EliteCardBottom)
			g.Transparency = NumberSequence.new(0.15, 0.4)
			g.Parent = head
		end
		local titleBlock = Instance.new("Frame")
		titleBlock.BackgroundTransparency = 1
		titleBlock.Position = UDim2.fromOffset(16, 0)
		titleBlock.Size = UDim2.new(1, -16, 1, 0)
		titleBlock.Parent = head
		local titleList = column(titleBlock, 2)
		titleList.VerticalAlignment = Enum.VerticalAlignment.Center
		local zoneArrows = opts.OnZone ~= nil and (data.PreviousZone ~= nil or data.NextZone ~= nil)
		local titleRow = Instance.new("Frame")
		titleRow.BackgroundTransparency = 1
		titleRow.AutomaticSize = Enum.AutomaticSize.X
		titleRow.Size = UDim2.fromOffset(0, math.max(math.ceil(L.ZoneSize * 1.2), if zoneArrows then UITheme.Spacing.TouchTarget else 0))
		titleRow.Parent = titleBlock
		row(titleRow, 10)
		text(titleRow, data.Title or `Zone {data.Zone}`, L.ZoneSize, if elite then C.GoldLight else C.TextLight).LayoutOrder = 1
		if zoneArrows then
			-- flèches de zone : consulter la zone voisine (aucun choix envoyé tant qu'aucun stage n'est choisi)
			for _, info in { { Zone = data.PreviousZone, Text = "<", Name = "ZonePrecedente", Order = 0 },
				{ Zone = data.NextZone, Text = ">", Name = "ZoneSuivante", Order = 3 } } do
				local target = info.Zone
				local arrow = UIKit.roundButton(titleRow, { Text = info.Text, Name = info.Name, Color = if target then C.Wood else C.Disabled,
					TextSize = L.ZoneSize, OnClick = function()
						if target and opts.OnZone then
							opts.OnZone(target)
						end
					end })
				arrow.LayoutOrder = info.Order
				if not target then
					arrow.BackgroundTransparency = 0.45
				end
			end
		end
		if eliteOpen then
			local tag = pill(titleRow, "ÉLITE", C.RoyalRed, 14, ICON.Crown, 26)
			tag.LayoutOrder = 2
			UIKit.stroke(tag, UITheme.Stroke.Thin)
			UIKit.popIn(tag, 0, 1.12)
		end
		local subtitle = if elite then "Mêmes stages, ennemis bien plus coriaces" else data.Subtitle
		if wide and subtitle then
			local sub = text(titleBlock, subtitle, L.SubSize, C.TextMuted, false)
			sub.LayoutOrder = 2
		end

		local tabs = box(head, "Modes", C.Ink, 0.45, 14, 3)
		tabs.AnchorPoint = Vector2.new(1, 0.5)
		tabs.Position = UDim2.new(1, -L.HeadPad, 0.5, 0)
		tabs.AutomaticSize = Enum.AutomaticSize.X
		tabs.Size = UDim2.fromOffset(0, L.ModeHeight + 8)
		padding(tabs, 4, 4, 4)
		row(tabs, 6)
		-- Zone sans Élite configurée (EliteStages absent) : seul l'onglet Normal.
		local modeTabs = if data.EliteStages then { { Id = "Normal", Label = "Normal" }, { Id = "Elite", Label = "Élite" } }
			else { { Id = "Normal", Label = "Normal" } }
		for index, info in modeTabs do
			local on = mode == info.Id
			local isElite = info.Id == "Elite"
			local tab = Instance.new("TextButton")
			tab.Name = `Mode_{info.Id}`
			tab.LayoutOrder = index
			tab.AutoButtonColor = false
			tab.Text = ""
			tab.AutomaticSize = Enum.AutomaticSize.X
			tab.Size = UDim2.fromOffset(0, L.ModeHeight)
			tab.BackgroundColor3 = Color3.new(1, 1, 1)
			tab.Parent = tabs
			corner(tab, 10)
			local ring = if on then (if isElite then C.GoldLight else INK) elseif isElite and eliteUnlocked then C.RoyalRed else INK
			UIKit.stroke(tab, 3, ring)
			if on then
				gradient(tab, if isElite then C.EliteFaceTop else C.GoldLight, if isElite then C.EliteFaceBottom else C.GoldDeep)
			elseif isElite and not eliteUnlocked then
				tab.BackgroundColor3, tab.BackgroundTransparency = C.Disabled, 0.45
			elseif isElite then
				tab.BackgroundColor3, tab.BackgroundTransparency = C.RoyalRed, 0.65
			else
				tab.BackgroundColor3, tab.BackgroundTransparency = C.WoodDeep, 0.12
			end
			padding(tab, 0, L.ModePadX, 0)
			row(tab, 6)
			local tabIcon = image(tab, if isElite then (if eliteUnlocked then ICON.Crown else ICON.Lock) else ICON.Swords, L.ModeIcon)
			tabIcon.LayoutOrder = 1
			tabIcon.ImageTransparency = if isElite and not eliteUnlocked then 0.2 else 0
			local labels = Instance.new("Frame")
			labels.LayoutOrder = 2
			labels.BackgroundTransparency = 1
			labels.AutomaticSize = Enum.AutomaticSize.XY
			labels.Size = UDim2.fromOffset(0, 0)
			labels.Parent = tab
			column(labels, 0)
			text(labels, info.Label, L.ModeSize).LayoutOrder = 1
			if isElite and not eliteUnlocked and wide then
				text(labels, "Verrouillé", 13, C.TextMuted, false).LayoutOrder = 2
			end
			if isElite and eliteUnlocked and not on then
				-- l'Élite débloquée attire l'œil (couronne, rouge royal)
				UIKit.pop(tab)
			end
			tab.Activated:Connect(function()
				if mode ~= info.Id then
					mode = info.Id
					selected = ExpeditionModel.default(stagesOf(mode), mode, eliteUnlocked, nil)
					render()
				end
			end)
		end

		-- rail des stages
		local rail = box(window, "Rail", C.Ink, 0.65, 14)
		track(rail)
		rail.Position = UDim2.fromOffset(x0, yRail)
		rail.Size = UDim2.fromOffset(inner, railHeight)
		local trackBar = box(rail, "Progression", C.Ink, 0.25, 999, 2)
		trackBar.Position = UDim2.fromOffset(L.TrackInset, L.TrackTop)
		trackBar.Size = UDim2.fromOffset(inner - 2 * L.TrackInset, 10)
		trackBar.ClipsDescendants = true
		local fill = box(trackBar, "Remplissage", if elite then Color3.new(1, 1, 1) else C.Progress, 0, 999)
		fill.Size = UDim2.fromScale(if eliteLocked then 0 else ExpeditionModel.track(nodes), 1)
		if elite then
			gradient(fill, C.RoyalRed, C.GoldLight, 0)
		end
		local weights = { 1, 1, 1, 1, 1.25 }
		local railInner = inner - 2 * L.RailPad.Side
		local unit = (railInner - (#nodes - 1) * L.NodeGap) / 5.25
		local x = L.RailPad.Side
		for index, node in nodes do
			local entry = stages[index]
			local w = unit * (weights[index] or 1)
			local h = if node.Boss then L.NodeHeightBoss else L.NodeHeight
			local isSel = selected ~= nil and entry.Stage == selected.Stage
			local locked = node.State == "Locked"
			local card = Instance.new("TextButton")
			card.Name = `Stage_{entry.Stage}`
			card.AutoButtonColor = false
			card.Text = ""
			card.BackgroundColor3 = Color3.new(1, 1, 1)
			card.AnchorPoint = Vector2.new(0, 1)
			card.Position = UDim2.fromOffset(x, railHeight - L.RailPad.Bottom - (if isSel then PACK.Lift else 0))
			card.Size = UDim2.fromOffset(w, h)
			card.ZIndex = 3
			card.Parent = rail
			corner(card, 14)
			UIKit.stroke(card, if isSel then 4 else 3, if isSel then (if elite then C.GoldLight else C.Selected) else INK)
			if locked then
				gradient(card, C.LockedTop, C.LockedBottom)
			elseif elite then
				gradient(card, if node.Boss then C.EliteBottom else C.EliteCardTop, C.EliteCardBottom)
			else
				gradient(card, C.Cream, if node.Boss then C.SandWarm else C.Sand)
			end
			if isSel then
				-- lueur douce + pointe sous la carte
				local glow = Instance.new("Frame")
				glow.Name = "Lueur"
				glow.BackgroundTransparency = 1
				glow.Position = UDim2.fromOffset(-6, -6)
				glow.Size = UDim2.new(1, 12, 1, 12)
				glow.ZIndex = 2
				glow.Parent = card
				corner(glow, 18)
				local g = UIKit.stroke(glow, 5, C.GoldLight)
				g.Transparency = 0.45
				local tip = box(card, "Pointe", if elite then C.GoldLight else C.Selected, 0)
				tip.AnchorPoint = Vector2.new(0.5, 0.5)
				tip.Position = UDim2.new(0.5, 0, 1, 4)
				tip.Size = UDim2.fromOffset(14, 14)
				tip.Rotation = 45
				tip.ZIndex = 2
			end
			local light = not locked and not elite
			-- badge d'état à cheval sur le bord haut
			local badgeColor = if node.BadgeKind == "Boss" then C.RoyalRed elseif node.BadgeKind == "Done" then C.Success
				elseif node.BadgeKind == "Open" then C.Gold elseif node.BadgeKind == "Elite" then C.RoyalRed else C.StoneGrey
			local badgeIcon = if node.BadgeKind == "Boss" then ICON.Skull elseif node.BadgeKind == "Done" then ICON.Check
				elseif node.BadgeKind == "Open" then ICON.Swords elseif node.BadgeKind == "Elite" then ICON.Crown else ICON.Lock
			local badge = pill(card, node.Badge, badgeColor, L.BadgeSize, badgeIcon, 24)
			badge.AnchorPoint = Vector2.new(0.5, 0.5)
			badge.Position = UDim2.fromScale(0.5, 0)
			badge.ZIndex = 5
			for _, d in badge:GetDescendants() do
				if d:IsA("GuiObject") then d.ZIndex = 6 end
			end
			-- contenu : portrait du boss (vrai modèle) ou épées / cadenas
			if wide and node.Boss then
				local ring = box(card, "PortraitBoss", C.Sand, 0, 999, 3)
				ring.AnchorPoint = Vector2.new(0.5, 0)
				ring.Position = UDim2.new(0.5, 0, 0, 18)
				ring.Size = UDim2.fromOffset(L.BossPortrait, L.BossPortrait)
				ring.ClipsDescendants = true
				ring.ZIndex = 4
				local outer = Instance.new("Frame")
				outer.BackgroundTransparency = 1
				outer.Position = UDim2.fromOffset(-4, -4)
				outer.Size = UDim2.new(1, 8, 1, 8)
				outer.Parent = ring
				corner(outer, 999)
				UIKit.stroke(outer, 3, if locked then C.StoneGrey else C.GoldLight)
				portrait(ring, Icons.enemyModel(entry.Boss :: string))
			elseif wide and L.NodeIcon > 0 then
				local nodeIcon = image(card, if locked then ICON.Lock else ICON.Swords, L.NodeIcon)
				nodeIcon.AnchorPoint = Vector2.new(0.5, 0)
				nodeIcon.Position = UDim2.new(0.5, 0, 0, 18)
				nodeIcon.ZIndex = 4
			end
			local label = UIKit.text(card, ExpeditionModel.label(entry, mode, wide), L.NodeSize, { Color = if light then C.InkSoft else C.TextLight, Stroke = not light })
			label.AnchorPoint = Vector2.new(0.5, 1)
			label.Position = UDim2.new(0.5, 0, 1, -8)
			label.Size = UDim2.new(1, -8, 0, L.NodeSize + 4)
			label.ZIndex = 4
			card.Activated:Connect(function()
				if selected == entry then
					return
				end
				selected = entry
				if ExpeditionModel.isOpen(entry, mode, eliteUnlocked) and opts.OnSelect then
					opts.OnSelect(data.Zone, entry.Stage, mode)
				end
				render()
			end)
			if isSel then
				GuideTargets.register("Expedition.Stage", card)
			end
			x += w + L.NodeGap
		end
		if eliteLocked then
			-- Élite verrouillée : voile sur le rail, carte de déblocage (progression Normal réelle)
			local cover = box(rail, "EliteVerrouillee", C.Ink, 0.45, 14)
			cover.Size = UDim2.fromScale(1, 1)
			cover.ZIndex = 8
			local note = box(cover, "Deblocage", Color3.new(1, 1, 1), 0, 14, 3)
			gradient(note, C.Cream, C.Sand)
			note.AnchorPoint = Vector2.new(0.5, 0.5)
			note.Position = UDim2.fromScale(0.5, 0.5)
			note.AutomaticSize = Enum.AutomaticSize.XY
			note.Size = UDim2.fromOffset(0, 0)
			note.ZIndex = 9
			padding(note, 10, 18, 10)
			row(note, 12)
			image(note, ICON.Lock, L.LockIcon).ZIndex = 10
			local lines = Instance.new("Frame")
			lines.BackgroundTransparency = 1
			lines.AutomaticSize = Enum.AutomaticSize.XY
			lines.Size = UDim2.fromOffset(0, 0)
			lines.ZIndex = 10
			lines.Parent = note
			column(lines, 2)
			local unlock: Stage? = data.Stages[#data.Stages]
			local unlockStage = if unlock ~= nil then unlock.Stage else 5
			local first = text(lines, `Termine le Stage {data.Zone}-{unlockStage} pour débloquer l'Élite`, L.LockSize, C.InkSoft, false)
			first.ZIndex = 10
			local second = text(lines, `Bats le Roi Orc en Normal · {ExpeditionModel.cleared(data.Stages)}/{#data.Stages} stages terminés`, 14, C.WoodDark, false)
			second.ZIndex = 10
			UIKit.popIn(note, 0, 1.04)
		end

		-- détail du stage choisi
		local detail = box(window, "Detail", C.Ink, 0.45, 14, 3, if elite then C.RoyalRed else INK)
		track(detail)
		detail.Position = UDim2.fromOffset(x0, yDetail)
		detail.Size = UDim2.fromOffset(inner, detailHeight)
		padding(detail, L.DetailPad.Top, L.DetailPad.Side)
		local colW = inner - 2 * L.DetailPad.Side - 2 * L.ColumnGap
		local totalWeight = L.Columns[1] + L.Columns[2] + L.Columns[3]
		local cx = 0
		local cols: { Frame } = {}
		for index, weight in L.Columns do
			local col = Instance.new("Frame")
			col.Name = `Colonne{index}`
			col.BackgroundTransparency = 1
			col.Position = UDim2.fromOffset(cx, 0)
			col.Size = UDim2.new(0, colW * weight / totalWeight, 1, 0)
			col.Parent = detail
			column(col, L.SectionGap)
			cols[index] = col
			cx += colW * weight / totalWeight + L.ColumnGap
		end
		if stage then
			-- colonne 1 : ennemis par vague (vrais modèles), boss
			local titleLine = Instance.new("Frame")
			titleLine.BackgroundTransparency = 1
			titleLine.AutomaticSize = Enum.AutomaticSize.X
			titleLine.Size = UDim2.fromOffset(0, math.ceil(L.SectionSize * 1.2))
			titleLine.LayoutOrder = 1
			titleLine.Parent = cols[1]
			row(titleLine, 8)
			text(titleLine, ExpeditionModel.title(stage, mode), L.SectionSize).LayoutOrder = 1
			local m = stage.Multipliers
			if elite and m then
				local chip = box(titleLine, "Multiplicateurs", C.WoodDeep, 0, 999, 2, C.RoyalRed)
				chip.LayoutOrder = 2
				chip.AutomaticSize = Enum.AutomaticSize.X
				chip.Size = UDim2.fromOffset(0, 22)
				padding(chip, 0, 8, 0)
				local function fr(n: number): string
					return (string.format("×%.2f", n):gsub("%.", ","))
				end
				text(chip, `PV {fr(m.MaxHealth)} · ATK {fr(m.AttackDamage)}`, 14, C.ElitePale, false)
			end
			local wavesBox = Instance.new("Frame")
			wavesBox.Name = "Vagues"
			wavesBox.BackgroundTransparency = 1
			wavesBox.AutomaticSize = Enum.AutomaticSize.Y
			wavesBox.Size = UDim2.fromScale(1, 0)
			wavesBox.LayoutOrder = 2
			wavesBox.Parent = cols[1]
			if wide then
				column(wavesBox, L.WaveGap)
			else
				row(wavesBox, 12, Enum.VerticalAlignment.Top, true)
			end
			local waves = stage.Waves or {}
			for index, wave in waves do
				local line = Instance.new("Frame")
				line.BackgroundTransparency = 1
				line.AutomaticSize = Enum.AutomaticSize.XY
				line.Size = UDim2.fromOffset(0, 0)
				line.LayoutOrder = index
				line.Parent = wavesBox
				row(line, if wide then 10 else 6)
				local many = #waves > 1 or stage.Boss ~= nil
				local labelText = if many then (if wide then `Vague {index}` else `V{index}`) else (if wide then "Ennemis" else "")
				if labelText ~= "" then
					local waveLabel = UIKit.text(line, labelText, 14, { Color = C.TextMuted, Stroke = false })
					waveLabel.TextXAlignment = Enum.TextXAlignment.Left
					waveLabel.TextWrapped = true
					waveLabel.Size = UDim2.fromOffset(L.WaveLabel, L.Monster)
					waveLabel.LayoutOrder = 0
				end
				for order, group in wave.Enemies or {} do
					local holder = Instance.new("Frame")
					holder.BackgroundTransparency = 1
					holder.LayoutOrder = order
					holder.Size = UDim2.fromOffset(L.Monster, L.Monster + (if wide then 20 else 0))
					holder.Parent = line
					local tile = box(holder, "Portrait", C.Sand, 0, 12, 3, if elite then C.RoyalRed else INK)
					tile.Size = UDim2.fromOffset(L.Monster, L.Monster)
					tile.ClipsDescendants = true
					portrait(tile, Icons.enemyModel(group.EnemyId), true)
					local count = box(holder, "Nombre", C.WoodDeep, 0, 999, 2)
					count.AnchorPoint = Vector2.new(1, 0)
					count.Position = UDim2.fromOffset(L.Monster + 8, -6)
					count.AutomaticSize = Enum.AutomaticSize.X
					count.Size = UDim2.fromOffset(0, 20)
					count.ZIndex = 4
					padding(count, 0, 6, 0)
					text(count, `×{group.Count}`, 15).ZIndex = 5
					if wide then
						local name = UIKit.text(holder, ArenaConfig.EnemyNames[group.EnemyId] or group.EnemyId, 14)
						name.AnchorPoint = Vector2.new(0.5, 1)
						name.Position = UDim2.new(0.5, 0, 1, 0)
						name.Size = UDim2.fromOffset(L.Monster + 20, 18)
					end
				end
			end
			if stage.Boss then
				local bossBox = box(cols[1], "Boss", Color3.new(1, 1, 1), 0, 14, 3)
				bossBox.LayoutOrder = 3
				bossBox.AutomaticSize = Enum.AutomaticSize.XY
				bossBox.Size = UDim2.fromOffset(0, 0)
				local g = Instance.new("UIGradient")
				g.Color = ColorSequence.new(C.RoyalRed)
				g.Transparency = NumberSequence.new(0.45, 0.85)
				g.Parent = bossBox
				padding(bossBox, if wide then 8 else 3, if wide then 10 else 6, if wide then 8 else 3)
				row(bossBox, 8)
				local inside = Instance.new("Frame")
				inside.BackgroundTransparency = 1
				inside.Size = UDim2.fromScale(1, 1)
				inside.Parent = bossBox
				inside.Visible = false
				local tile = box(bossBox, "Portrait", C.Sand, 0, 14, 3)
				tile.Size = UDim2.fromOffset(L.BossTile, L.BossTile)
				tile.ClipsDescendants = true
				tile.LayoutOrder = 1
				portrait(tile, Icons.enemyModel(stage.Boss))
				local info = Instance.new("Frame")
				info.BackgroundTransparency = 1
				info.AutomaticSize = Enum.AutomaticSize.XY
				info.Size = UDim2.fromOffset(0, 0)
				info.LayoutOrder = 2
				info.Parent = bossBox
				column(info, 4)
				pill(info, "BOSS", C.RoyalRed, 14, ICON.Skull, 22).LayoutOrder = 1
				text(info, ArenaConfig.EnemyNames[stage.Boss] or stage.Boss, L.BossSize, C.GoldLight).LayoutOrder = 2
				if wide then
					text(info, "Après la dernière vague", 14, C.TextMuted, false).LayoutOrder = 3
				end
			end

			-- colonne 2 : récompenses réelles du stage
			local rewards = ExpeditionModel.rewards(stage, wide)
			text(cols[2], "Récompenses", L.SectionSize).LayoutOrder = 1
			local boxes = Instance.new("Frame")
			boxes.BackgroundTransparency = 1
			boxes.AutomaticSize = Enum.AutomaticSize.Y
			boxes.Size = UDim2.fromScale(1, 0)
			boxes.LayoutOrder = 2
			boxes.Parent = cols[2]
			if wide then
				column(boxes, 10)
			else
				row(boxes, 6, Enum.VerticalAlignment.Top)
			end
			local function tile(parent: Instance, asset: string, quantity: string, color: Color3, dim: boolean?)
				local t = box(parent, "Recompense", C.Sand, 0.08, 12, 3)
				t.Size = UDim2.fromOffset(L.Reward, L.Reward)
				local icon = image(t, asset, math.floor(L.Reward * 0.72))
				icon.AnchorPoint = Vector2.new(0.5, 0.5)
				icon.Position = UDim2.fromScale(0.5, 0.5)
				if dim then
					icon.ImageColor3 = C.StoneGrey
					icon.ImageTransparency = 0.3
				end
				local q = UIKit.text(t, quantity, L.QuantitySize, color)
				q.AnchorPoint = Vector2.new(1, 1)
				q.Position = UDim2.new(1, 6, 1, 8)
				q.Size = UDim2.fromOffset(L.Reward + 20, L.QuantitySize + 4)
				q.TextXAlignment = Enum.TextXAlignment.Right
				q.ZIndex = 3
			end
			local function currencyTile(parent: Instance, reward: ExpeditionModel.Reward, dim: boolean?)
				local visual = CurrencyVisualConfig.visual(reward.Kind)
				tile(parent, if visual then visual.Small else "", `+{reward.Amount}`, if visual then visual.Color else C.TextLight, dim)
			end
			local function rewardBox(name: string, order: number): Frame
				local b = box(boxes, name, C.WoodDeep, 0.3, 12, 3)
				b.LayoutOrder = order
				b.AutomaticSize = Enum.AutomaticSize.Y
				b.Size = if wide then UDim2.fromScale(1, 0) else UDim2.new(0.5, -3, 0, 0)
				padding(b, L.BoxPad, if wide then 12 else 6, L.BoxPad + 4)
				column(b, 6)
				return b
			end
			if #rewards.FirstClear > 0 then
				-- « Première victoire » : donnée UNE fois (RewardRules) ; obtenue → grisée, jamais re-proposée
				local fc = rewardBox("PremiereVictoire", 1)
				if rewards.FirstClearDone then
					fc.BackgroundTransparency = 0.4
				elseif elite then
					fc.BackgroundColor3, fc.BackgroundTransparency = C.RoyalRed, 0.55
				else
					fc.BackgroundColor3, fc.BackgroundTransparency = C.SandGold, 0.75
				end
				local ring = fc:FindFirstChildOfClass("UIStroke")
				if ring and not rewards.FirstClearDone then
					ring.Color = C.Selected
				end
				local top = Instance.new("Frame")
				top.BackgroundTransparency = 1
				top.Size = UDim2.new(1, 0, 0, L.BoxSize + 6)
				top.Parent = fc
				text(top, if wide then "Première victoire" else "1re victoire", L.BoxSize, if rewards.FirstClearDone then C.TextMuted else C.GoldLight)
				if rewards.FirstClearDone then
					local got = Instance.new("Frame")
					got.BackgroundTransparency = 1
					got.AnchorPoint = Vector2.new(1, 0)
					got.Position = UDim2.fromScale(1, 0)
					got.AutomaticSize = Enum.AutomaticSize.X
					got.Size = UDim2.fromOffset(0, L.BoxSize + 4)
					got.Parent = top
					row(got, 4)
					image(got, ICON.Check, 18)
					if wide then
						text(got, "Obtenue", 14, C.SuccessLight)
					end
				elseif wide then
					local once = pill(top, "Une fois", C.RoyalRed, 14, nil, 22)
					once.AnchorPoint = Vector2.new(1, 0)
					once.Position = UDim2.fromScale(1, 0)
				end
				local items = Instance.new("Frame")
				items.BackgroundTransparency = 1
				items.AutomaticSize = Enum.AutomaticSize.Y
				items.Size = UDim2.new(1, 0, 0, L.Reward)
				items.Parent = fc
				row(items, L.TileGap, Enum.VerticalAlignment.Top, wide)
				for _, reward in rewards.FirstClear do
					currencyTile(items, reward, rewards.FirstClearDone)
				end
			end
			-- « Ensuite, à chaque victoire » : XP de CHAQUE héros posé, puis la récompense de replay réelle
			local rep = rewardBox("ChaqueVictoire", 2)
			text(rep, rewards.RepeatTitle, L.BoxSize)
			local items = Instance.new("Frame")
			items.BackgroundTransparency = 1
			items.AutomaticSize = Enum.AutomaticSize.Y
			items.Size = UDim2.new(1, 0, 0, L.Reward)
			items.Parent = rep
			row(items, L.TileGap, Enum.VerticalAlignment.Top, true)
			if rewards.HeroXP > 0 then
				tile(items, ICON.XP, `+{rewards.HeroXP}`, C.RiverLight)
			end
			for _, reward in rewards.Repeat do
				currencyTile(items, reward)
			end
			if wide then
				text(rep, "XP pour chaque héros posé", 14, C.TextMuted, false)
			end

			-- colonne 3 : butin possible (table de loot réelle uniquement, #72)
			local dropHead = Instance.new("Frame")
			dropHead.BackgroundTransparency = 1
			dropHead.AutomaticSize = Enum.AutomaticSize.X
			dropHead.Size = UDim2.fromOffset(0, math.ceil(L.SectionSize * 1.2))
			dropHead.LayoutOrder = 1
			dropHead.Parent = cols[3]
			row(dropHead, 8)
			text(dropHead, "Butin possible", L.SectionSize).LayoutOrder = 1
			if wide then
				local per = box(dropHead, "ParVictoire", C.WoodDeep, 0, 999, 2)
				per.LayoutOrder = 2
				per.AutomaticSize = Enum.AutomaticSize.X
				per.Size = UDim2.fromOffset(0, 22)
				padding(per, 0, 8, 0)
				text(per, "par victoire", 14, C.TextMuted, false)
			end
			local drops = stage.PotentialDrops
			if drops and #drops > 0 then
				local list = Instance.new("ScrollingFrame")
				list.Name = "Butin"
				list.LayoutOrder = 2
				list.BackgroundTransparency = 1
				list.BorderSizePixel = 0
				list.ScrollBarThickness = 4
				list.AutomaticCanvasSize = Enum.AutomaticSize.Y
				list.CanvasSize = UDim2.new()
				list.Size = UDim2.new(1, 0, 1, -math.ceil(L.SectionSize * 1.2) - L.SectionGap)
				list.Parent = cols[3]
				column(list, L.DropGap)
				for order, drop in drops do
					local config = if drop.Kind == "Item" then ItemConfig.Items[drop.Id] else ResourceConfig.Resources[drop.Id]
					local name = if config then config.Name else drop.Id
					local line = Instance.new("Frame")
					line.BackgroundTransparency = 1
					line.LayoutOrder = order
					line.Size = UDim2.new(1, -6, 0, L.DropIcon)
					line.Parent = list
					local iconBox = box(line, "Icone", C.Sand, 0.08, 10, 3)
					iconBox.Size = UDim2.fromOffset(L.DropIcon, L.DropIcon)
					if config and config.Icon then
						local img = image(iconBox, config.Icon, L.DropIcon - 8)
						img.AnchorPoint = Vector2.new(0.5, 0.5)
						img.Position = UDim2.fromScale(0.5, 0.5)
					else
						UIKit.text(iconBox, string.upper(string.sub(name, 1, 2)), math.floor(L.DropIcon * 0.34), { Color = C.WoodDark, Stroke = false })
					end
					local label = UIKit.text(line, name, L.DropSize)
					label.TextXAlignment = Enum.TextXAlignment.Left
					label.TextTruncate = Enum.TextTruncate.AtEnd
					label.Position = UDim2.fromOffset(L.DropIcon + 10, 0)
					label.Size = UDim2.new(1, -(L.DropIcon + 20 + L.ChanceWidth), 1, 0)
					local percent = drop.Chance * 100
					local chanceColor = if drop.Chance >= 1 or percent >= 20 then C.Success elseif percent >= 10 then C.Info elseif percent >= 5 then C.DropChanceLow else C.Gold
					local chance = box(line, "Chance", chanceColor, 0, 999, 2)
					chance.AnchorPoint = Vector2.new(1, 0.5)
					chance.Position = UDim2.fromScale(1, 0.5)
					chance.AutomaticSize = Enum.AutomaticSize.X
					chance.Size = UDim2.fromOffset(L.ChanceWidth, L.DropSize + 6)
					padding(chance, 0, 8, 0)
					UIKit.text(chance, ExpeditionModel.chance(drop.Chance), L.DropSize)
				end
			else
				-- pas encore de table de loot (#72) : aucun pourcentage inventé
				local soon = UIKit.text(cols[3], "Butin à venir", L.DropSize, { Color = C.TextMuted, Stroke = false })
				soon.LayoutOrder = 2
				soon.TextXAlignment = Enum.TextXAlignment.Left
				soon.Size = UDim2.new(1, 0, 0, L.DropSize + 6)
				if wide then
					local sub = UIKit.text(cols[3], "Équipements et ressources : bientôt", 14, { Color = C.TextMuted, Stroke = false })
					sub.LayoutOrder = 3
					sub.TextXAlignment = Enum.TextXAlignment.Left
					sub.TextWrapped = true
					sub.Size = UDim2.new(1, 0, 0, 36)
				end
			end
		end

		-- pied : équipe, Préparer, Lancer
		local teamInfo = ExpeditionModel.team(team.Placed, team.Max)
		local launch = ExpeditionModel.launch(stage, mode, eliteUnlocked, team.Placed)
		local foot = Instance.new("Frame")
		foot.Name = "Pied"
		foot.BackgroundTransparency = 1
		foot.Position = UDim2.fromOffset(x0, yFoot)
		foot.Size = UDim2.fromOffset(inner, footHeight)
		foot.Parent = window
		track(foot)
		local launchWidth = L.LaunchWidth
		local prepWidth = if wide then 230 else 150
		local teamWidth = inner - launchWidth - prepWidth - 2 * L.FootGap
		local teamBox = box(foot, "Equipe", C.Ink, 0.45, 14, 3, if teamInfo.Full then C.Selected else INK)
		teamBox.Size = UDim2.fromOffset(teamWidth, L.CtaHeight)
		padding(teamBox, 0, 14, 0)
		row(teamBox, 12)
		local slots = Instance.new("Frame")
		slots.BackgroundTransparency = 1
		slots.AutomaticSize = Enum.AutomaticSize.X
		slots.Size = UDim2.fromOffset(0, L.Slot)
		slots.LayoutOrder = 1
		slots.Parent = teamBox
		row(slots, 6)
		local heroes = team.Heroes or {}
		for index = 1, team.Max do
			local on = index <= team.Placed
			local slot = box(slots, `Place{index}`, if on then C.SandGold else C.Ink, if on then 0.6 else 0.5, 10, 3, if on then (if teamInfo.Full then C.Selected else C.SandGold) else C.StoneGrey)
			slot.LayoutOrder = index
			slot.Size = UDim2.fromOffset(L.Slot, L.Slot)
			slot.ClipsDescendants = true
			local heroId = heroes[index]
			if on and heroId then
				portrait(slot, Icons.heroModel(heroId))
			end
		end
		local teamText = Instance.new("Frame")
		teamText.BackgroundTransparency = 1
		teamText.AutomaticSize = Enum.AutomaticSize.XY
		teamText.Size = UDim2.fromOffset(0, 0)
		teamText.LayoutOrder = 2
		teamText.Parent = teamBox
		column(teamText, 0)
		text(teamText, `Équipe {team.Placed}/{team.Max}`, L.TeamSize, if team.Placed == 0 then C.ElitePale elseif teamInfo.Full then C.GoldLight else C.TextLight).LayoutOrder = 1
		local hint = text(teamText, teamInfo.Hint, 14, C.TextMuted, false)
		hint.LayoutOrder = 2

		local prepare = chunky(foot, Vector2.new(prepWidth, L.CtaHeight),
			if teamInfo.Ready then C.WoodLight else C.GoldLight, if teamInfo.Ready then C.Wood else C.GoldDeep,
			if teamInfo.Ready then C.WoodDark else C.GoldLip, function()
				if opts.OnPrepare then
					local onPrepare = opts.OnPrepare
					ExpeditionView.Hide()
					onPrepare()
				end
			end)
		prepare.holder.Name = "Preparer"
		prepare.holder.Position = UDim2.fromOffset(teamWidth + L.FootGap, 0)
		local prepLabel = UIKit.text(prepare.face, if wide then "Préparer l'équipe" else "Préparer", L.CtaSize)
		prepLabel.ZIndex = 3
		if not teamInfo.Ready then
			breathe(c, prepare.holder, prepare.halo) -- l'action à faire : poser un héros
		end
		GuideTargets.register("Expedition.Prepare", prepare.holder)

		local ready = launch.Enabled
		local launchButton = chunky(foot, Vector2.new(launchWidth, L.CtaHeight),
			if not ready then C.Disabled elseif elite then C.EliteFaceTop else C.GoldLight,
			if not ready then C.StoneGrey elseif elite then C.EliteFaceBottom else C.GoldDeep,
			if not ready then C.DisabledLip elseif elite then C.EliteLip else C.GoldLip, function()
				local s = selected
				if launch.Enabled and s and opts.OnLaunch then
					local onLaunch = opts.OnLaunch
					local launchMode = mode
					ExpeditionView.Hide()
					onLaunch(data.Zone, s.Stage, launchMode)
				end
			end)
		launchButton.holder.Name = "Lancer"
		launchButton.holder.Position = UDim2.fromOffset(teamWidth + prepWidth + 2 * L.FootGap, 0)
		if ready and elite then
			UIKit.stroke(launchButton.face, 4).Color = INK
			local inner = Instance.new("Frame")
			inner.BackgroundTransparency = 1
			inner.Position = UDim2.fromOffset(3, 3)
			inner.Size = UDim2.new(1, -6, 1, -6)
			inner.ZIndex = 3
			inner.Parent = launchButton.face
			corner(inner, 11)
			UIKit.stroke(inner, 2, C.GoldLight)
		end
		local content = Instance.new("Frame")
		content.BackgroundTransparency = 1
		content.Size = UDim2.fromScale(1, 1)
		content.ZIndex = 3
		content.Parent = launchButton.face
		local contentRow = row(content, 8)
		contentRow.HorizontalAlignment = Enum.HorizontalAlignment.Center
		if not ready then
			local lock = image(content, ICON.Lock, 26)
			lock.ImageTransparency = 0.25
			lock.LayoutOrder = 1
			lock.ZIndex = 4
		end
		local labels = Instance.new("Frame")
		labels.BackgroundTransparency = 1
		labels.AutomaticSize = Enum.AutomaticSize.XY
		labels.Size = UDim2.fromOffset(0, 0)
		labels.LayoutOrder = 2
		labels.ZIndex = 4
		labels.Parent = content
		local labelList = column(labels, 0)
		labelList.HorizontalAlignment = Enum.HorizontalAlignment.Center
		local launchLabel = UIKit.text(labels, "Lancer", L.CtaSize)
		launchLabel.AutomaticSize = Enum.AutomaticSize.X
		launchLabel.Size = UDim2.fromOffset(0, L.CtaSize + 2)
		launchLabel.TextTransparency = if ready then 0 else 0.45
		launchLabel.ZIndex = 4
		local sub = UIKit.text(labels, launch.Sub, 14)
		sub.AutomaticSize = Enum.AutomaticSize.X
		sub.Size = UDim2.fromOffset(0, 16)
		sub.TextTransparency = if ready then 0 else 0.25
		sub.ZIndex = 4
		if ready then
			breathe(c, launchButton.holder, launchButton.halo)
			shine(c, launchButton.face)
		end
		GuideTargets.register("Expedition.Launch", launchButton.holder)
		if teamInfo.Ready or not opts.OnPrepare then
			GuideTargets.register("Expedition.Next", launchButton.holder, "Lance le combat")
		else
			GuideTargets.register("Expedition.Next", prepare.holder, "Pose un héros d'abord")
		end
		if opts.Guide and ready then
			UIKit.pop(launchButton.holder)
		end
	end

	render()
	UIKit.open(panel, veil)
	GuideTargets.open("Expedition")
	-- l'écran change de taille (rotation, fenêtre) : l'échelle suit (la disposition reste celle de l'ouverture)
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if current == c then
				uiScale.Scale = scaleFor(L, camera.ViewportSize, device)
			end
		end)
	end
end

function ExpeditionView.Hide()
	local c = current
	if not c then
		return
	end
	current = nil
	c.alive = false
	for _, t in c.tweens do
		t:Cancel()
	end
	GuideTargets.close("Expedition")
	UIKit.close(c.panel, c.veil, true, function()
		c.screen:Destroy()
	end)
end

return ExpeditionView
