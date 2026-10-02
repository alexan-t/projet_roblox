--!strict
-- Composants d'interface du design system (docs/UI_DESIGN_SYSTEM.md) — issue #19.
-- Toutes les valeurs de style viennent de UITheme : un écran construit avec UIKit n'a aucune couleur,
-- police, rayon ni durée en dur. UIKit ne contient aucune règle de jeu.
--   UIKit.screen(name, order?)                 ScreenGui + UIScale global (écran de référence 1080 px)
--   UIKit.text(parent, text, size, options?)    texte Fredoka clair contouré Ink
--   UIKit.button(parent, options)               bouton « chunky » (face + lèvre) : Primary, Secondary, Disabled
--   UIKit.roundButton(parent, options)          bouton rond (fermer « X », action ronde)
--   UIKit.panel(parent, options)                panneau / fenêtre (bandeau de titre en bois, fermer)
--   UIKit.pill(parent, size)                    pastille HUD
--   UIKit.badge(parent, text, color)            badge d'état à cheval sur le bord haut
--   UIKit.bar(parent, options)                  barre (PV, énergie, progression)
--   UIKit.tabs(parent, options)                 onglets (actif doré)
--   UIKit.card(parent, options)                 carte (héros, récompense, slot) avec zone d'illustration
--   UIKit.portrait(parent, model)               portrait 3D d'un modèle (ViewportFrame)
--   UIKit.overlay(screen)                       voile Ink derrière une fenêtre modale
--   UIKit.open(object, overlay?) / UIKit.close(object, overlay?, destroy?)  transitions de fenêtre
--   UIKit.popIn(object, delay?, peak?)          pop 0 → peak → 1 (apparition)
--   UIKit.bump(object, peak?)                   pop 1 → peak → 1 (gain sur un élément affiché)
--   UIKit.announce(screen, text, options?)      annonce (vague, mini-boss, quête) : pop, tenue, fondu
--   UIKit.rays(parent, length, count?)          rayons dorés tournants (victoire, héros obtenu)
--   UIKit.curtain(title?, onMiddle?, hold?)     transition entre deux scènes (bloquante)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)

local Colors = UITheme.Colors
local Typography = UITheme.Typography
local Animation = UITheme.Animation
local Spacing = UITheme.Spacing

local REFERENCE_HEIGHT = 1080 -- tailles du design system données pour un écran de 1080 px de haut
local MIN_SCALE, MAX_SCALE = 0.7, 1.25 -- en dessous, le texte passerait sous 14 px réels

local UIKit = {}

function UIKit.tween(instance: Instance, info: TweenInfo, goal: { [string]: any }): Tween
	local t = TweenService:Create(instance, info, goal)
	t:Play()
	return t
end
local tween = UIKit.tween

function UIKit.corner(parent: Instance, radius: UDim): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
	return c
end

-- Contour Ink : Border sur un cadre (suit les coins arrondis), Contextual sur un texte.
function UIKit.stroke(parent: Instance, thickness: number, color: Color3?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color or UITheme.Stroke.Color
	s.Thickness = thickness
	s.LineJoinMode = UITheme.Stroke.LineJoin
	s.ApplyStrokeMode = if parent:IsA("TextLabel") or parent:IsA("TextButton") then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

-- Épaisseur du contour d'un texte selon sa taille (design system § 4).
function UIKit.textStroke(size: number): number
	return if size <= 18 then Typography.TextStroke.Small elseif size <= 32 then Typography.TextStroke.Medium else Typography.TextStroke.Large
end

function UIKit.screen(name: string, order: number?): ScreenGui
	local screen = Instance.new("ScreenGui")
	screen.Name = name
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.DisplayOrder = order or 0
	local scale = Instance.new("UIScale")
	scale.Parent = screen
	local function fit()
		local camera = Workspace.CurrentCamera
		local height = if camera then camera.ViewportSize.Y else REFERENCE_HEIGHT
		scale.Scale = math.clamp(height / REFERENCE_HEIGHT, MIN_SCALE, MAX_SCALE)
	end
	fit()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return screen
end

export type TextOptions = { Color: Color3?, Stroke: boolean?, Font: Font?, Align: Enum.TextXAlignment? }

-- Texte Fredoka clair contouré Ink (tout texte posé sur un fond transparent). Stroke = false pour un
-- texte sombre sur fond clair (InkSoft sur Cream).
function UIKit.text(parent: Instance, text: string, size: number, options: TextOptions?): TextLabel
	local opts: TextOptions = options or {}
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = opts.Font or Typography.Display
	l.TextSize = size
	l.TextColor3 = opts.Color or Colors.TextLight
	l.TextXAlignment = opts.Align or Enum.TextXAlignment.Center
	l.Text = text
	l.Size = UDim2.fromScale(1, 1)
	l.Parent = parent
	if opts.Stroke ~= false then
		UIKit.stroke(l, UIKit.textStroke(size))
	end
	return l
end

------------------------------------------------------------------ boutons

local BUTTON_STYLES = {
	Primary = { Top = Colors.GoldLight, Bottom = Colors.GoldDeep, Lip = Colors.GoldDeep:Lerp(Colors.Ink, 0.35) },
	Secondary = { Top = Colors.WoodLight, Bottom = Colors.Wood, Lip = Colors.WoodDark },
	Danger = { Top = Colors.RoyalRed, Bottom = Colors.RoyalRed:Lerp(Colors.Ink, 0.2), Lip = Colors.RoyalRed:Lerp(Colors.Ink, 0.45) },
	Disabled = { Top = Colors.Disabled, Bottom = Colors.StoneGrey, Lip = Colors.StoneGrey:Lerp(Colors.Ink, 0.4) },
}

export type ButtonOptions = {
	Text: string,
	Style: string?, -- "Primary" (un seul par écran), "Secondary", "Danger", "Disabled"
	Size: Vector2?,
	TextSize: number?,
	Name: string?,
	OnClick: (() -> ())?,
}
export type Button = {
	Holder: Frame,
	Face: TextButton,
	Label: TextLabel,
	SetStyle: (style: string) -> (),
	SetText: (text: string) -> (),
	SetSelected: (selected: boolean) -> (),
}

-- Bouton « chunky » : une face (dégradé vertical léger) et une lèvre plus sombre décalée vers le bas.
-- États : survol (1,04), appui (la face descend sur la lèvre, 0,94), désactivé (gris, aucun retour),
-- sélectionné (contour Selected épais).
function UIKit.button(parent: Instance, options: ButtonOptions): Button
	local lipHeight = UITheme.Shadow.ButtonLip
	local size = options.Size or Vector2.new(200, 52)
	local holder = Instance.new("Frame")
	holder.Name = options.Name or options.Text
	holder.Size = UDim2.fromOffset(size.X, size.Y + lipHeight)
	holder.BackgroundTransparency = 1
	holder.Parent = parent
	local lip = Instance.new("Frame")
	lip.Name = "Levre"
	lip.Position = UDim2.fromOffset(0, lipHeight)
	lip.Size = UDim2.new(1, 0, 1, -lipHeight)
	lip.Parent = holder
	UIKit.corner(lip, UITheme.Radius.Medium)
	UIKit.stroke(lip, UITheme.Stroke.Regular)
	local face = Instance.new("TextButton")
	face.Name = "Face"
	face.AutoButtonColor = false
	face.Text = ""
	face.Size = UDim2.new(1, 0, 1, -lipHeight)
	face.BackgroundColor3 = Color3.new(1, 1, 1)
	face.Parent = holder
	UIKit.corner(face, UITheme.Radius.Medium)
	local border = UIKit.stroke(face, UITheme.Stroke.Regular)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Parent = face
	local textSize = options.TextSize or Typography.Size.Button
	local label = UIKit.text(face, options.Text, textSize)
	label.ZIndex = 2
	local scale = Instance.new("UIScale")
	scale.Parent = holder

	local style = options.Style or "Secondary"
	local function apply()
		local colors = BUTTON_STYLES[style] or BUTTON_STYLES.Secondary
		gradient.Color = ColorSequence.new(colors.Top, colors.Bottom)
		lip.BackgroundColor3 = colors.Lip
		label.TextTransparency = if style == "Disabled" then UITheme.Transparency.Disabled else 0
		face.Active = style ~= "Disabled"
	end
	apply()
	local function release()
		face.Position = UDim2.fromOffset(0, 0)
		tween(scale, Animation.Hover, { Scale = 1 })
	end
	face.MouseEnter:Connect(function()
		if style ~= "Disabled" then
			tween(scale, Animation.Hover, { Scale = Animation.Scale.Hover })
		end
	end)
	face.MouseLeave:Connect(release)
	face.MouseButton1Down:Connect(function()
		if style ~= "Disabled" then
			tween(scale, Animation.Press, { Scale = Animation.Scale.Pressed })
			face.Position = UDim2.fromOffset(0, lipHeight)
		end
	end)
	face.MouseButton1Up:Connect(release)
	face.Activated:Connect(function()
		if style ~= "Disabled" and options.OnClick then
			options.OnClick()
		end
	end)
	return {
		Holder = holder,
		Face = face,
		Label = label,
		SetStyle = function(newStyle: string)
			style = newStyle
			apply()
		end,
		SetText = function(text: string)
			label.Text = text
		end,
		SetSelected = function(selected: boolean)
			border.Color = if selected then Colors.Selected else UITheme.Stroke.Color
			border.Thickness = if selected then UITheme.Stroke.Thick else UITheme.Stroke.Regular
		end,
	}
end

export type RoundOptions = { Text: string, Color: Color3?, Size: number?, TextSize: number?, Name: string?, OnClick: (() -> ())? }

-- Bouton rond (fermer : RoyalRed « X » ; la police n'a pas « ✕ »).
function UIKit.roundButton(parent: Instance, options: RoundOptions): TextButton
	local size = options.Size or Spacing.TouchTarget
	local b = Instance.new("TextButton")
	b.Name = options.Name or "Bouton"
	b.AutoButtonColor = false
	b.Text = ""
	b.Size = UDim2.fromOffset(size, size)
	b.BackgroundColor3 = options.Color or Colors.RoyalRed
	b.Parent = parent
	UIKit.corner(b, UITheme.Radius.Pill)
	UIKit.stroke(b, UITheme.Stroke.Regular)
	local label = UIKit.text(b, options.Text, options.TextSize or Typography.Size.Button)
	label.Name = "Texte"
	local scale = Instance.new("UIScale")
	scale.Parent = b
	b.MouseEnter:Connect(function()
		tween(scale, Animation.Hover, { Scale = Animation.Scale.Hover })
	end)
	b.MouseLeave:Connect(function()
		tween(scale, Animation.Hover, { Scale = 1 })
	end)
	b.MouseButton1Down:Connect(function()
		tween(scale, Animation.Press, { Scale = Animation.Scale.Pressed })
	end)
	b.MouseButton1Up:Connect(function()
		tween(scale, Animation.Hover, { Scale = 1 })
	end)
	b.Activated:Connect(function()
		if options.OnClick then
			options.OnClick()
		end
	end)
	return b
end

------------------------------------------------------------------ surfaces

export type PanelOptions = { Size: Vector2, Title: string?, OnClose: (() -> ())?, Name: string? }

-- Panneau / fenêtre : WoodDeep à Panel, contour épais, rayon Large, ombre pleine décalée. Titre dans un
-- bandeau en bois à cheval sur le bord haut ; bouton fermer rond à cheval sur le coin haut droit.
-- Renvoie le panneau (à positionner) et son cadre de contenu.
function UIKit.panel(parent: Instance, options: PanelOptions): (Frame, Frame)
	local panel = Instance.new("Frame")
	panel.Name = options.Name or "Panneau"
	panel.Size = UDim2.fromOffset(options.Size.X, options.Size.Y)
	panel.BackgroundTransparency = 1
	panel.Parent = parent
	local shadow = Instance.new("Frame")
	shadow.Name = "Ombre"
	shadow.Position = UITheme.Shadow.Offset
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.BackgroundColor3 = UITheme.Shadow.Color
	shadow.BackgroundTransparency = UITheme.Shadow.Transparency
	shadow.Parent = panel
	UIKit.corner(shadow, UITheme.Radius.Large)
	local body = Instance.new("Frame")
	body.Name = "Fond"
	body.Size = UDim2.fromScale(1, 1)
	body.BackgroundColor3 = Colors.WoodDeep
	body.BackgroundTransparency = UITheme.Transparency.Panel
	body.Parent = panel
	UIKit.corner(body, UITheme.Radius.Large)
	UIKit.stroke(body, UITheme.Stroke.Thick)
	local content = Instance.new("Frame")
	content.Name = "Contenu"
	content.BackgroundTransparency = 1
	local top = if options.Title then Spacing.XXL else Spacing.L
	content.Position = UDim2.fromOffset(Spacing.L, top)
	content.Size = UDim2.new(1, -2 * Spacing.L, 1, -top - Spacing.L)
	content.Parent = panel
	if options.Title then
		local banner = Instance.new("Frame")
		banner.Name = "Bandeau"
		banner.AnchorPoint = Vector2.new(0.5, 0.5)
		banner.Position = UDim2.fromScale(0.5, 0)
		banner.Size = UDim2.fromOffset(math.max(180, #options.Title * 18 + 2 * Spacing.XL), 48)
		banner.BackgroundColor3 = Colors.Wood
		banner.ZIndex = 3
		banner.Parent = panel
		UIKit.corner(banner, UITheme.Radius.Medium)
		UIKit.stroke(banner, UITheme.Stroke.Thick)
		local title = UIKit.text(banner, options.Title, Typography.Size.Title)
		title.ZIndex = 4
	end
	if options.OnClose then
		local close = UIKit.roundButton(panel, { Text = "X", Name = "Fermer", OnClick = options.OnClose })
		close.AnchorPoint = Vector2.new(0.5, 0.5)
		close.Position = UDim2.new(1, -Spacing.S, 0, Spacing.S)
		close.ZIndex = 5
		for _, child in close:GetDescendants() do
			if child:IsA("GuiObject") then
				child.ZIndex = 6
			end
		end
	end
	return panel, content
end

-- Sous-panneau (ligne de quête, zone de texte long) : WoodDeep à PanelStrong, contour Thin.
function UIKit.subPanel(parent: Instance, size: UDim2): Frame
	local f = Instance.new("Frame")
	f.Size = size
	f.BackgroundColor3 = Colors.WoodDeep
	f.BackgroundTransparency = UITheme.Transparency.PanelStrong
	f.Parent = parent
	UIKit.corner(f, UITheme.Radius.Medium)
	UIKit.stroke(f, UITheme.Stroke.Thin)
	return f
end

-- Pastille HUD (monnaies, barre de combat) : WoodDeep à HUD, contour Regular.
function UIKit.pill(parent: Instance, size: Vector2): Frame
	local f = Instance.new("Frame")
	f.Size = UDim2.fromOffset(size.X, size.Y)
	f.BackgroundColor3 = Colors.WoodDeep
	f.BackgroundTransparency = UITheme.Transparency.HUD
	f.Parent = parent
	UIKit.corner(f, UITheme.Radius.Pill)
	UIKit.stroke(f, UITheme.Stroke.Regular)
	return f
end

-- Badge d'état, à cheval sur le bord haut du parent (Disponible, Équipé, Nouveau, Verrouillé, Max).
function UIKit.badge(parent: Instance, text: string, color: Color3): Frame
	local b = Instance.new("Frame")
	b.Name = "Badge"
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = UDim2.new(0.5, 0, 0, 0)
	b.Size = UDim2.fromOffset(math.max(84, #text * 9 + 2 * Spacing.M), 24)
	b.BackgroundColor3 = color
	b.ZIndex = 5
	b.Parent = parent
	UIKit.corner(b, UITheme.Radius.Pill)
	UIKit.stroke(b, UITheme.Stroke.Thin)
	local l = UIKit.text(b, text, Typography.Size.Caption)
	l.ZIndex = 6
	return b
end

export type BarOptions = { Color: Color3, Size: UDim2?, Thin: boolean? }
export type Bar = { Frame: Frame, Fill: Frame, Set: (ratio: number, animate: boolean?) -> (), SetColor: (color: Color3) -> () }

-- Barre : fond BarTrack à Track, contour Thin, rayon Pill, remplissage opaque.
function UIKit.bar(parent: Instance, options: BarOptions): Bar
	local track = Instance.new("Frame")
	track.Name = "Barre"
	track.Size = options.Size or UDim2.new(1, 0, 0, 12)
	track.BackgroundColor3 = Colors.BarTrack
	track.BackgroundTransparency = UITheme.Transparency.Track
	track.Parent = parent
	UIKit.corner(track, UITheme.Radius.Pill)
	UIKit.stroke(track, UITheme.Stroke.Thin)
	local fill = Instance.new("Frame")
	fill.Name = "Remplissage"
	fill.BackgroundColor3 = options.Color
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = track
	UIKit.corner(fill, UITheme.Radius.Pill)
	return {
		Frame = track,
		Fill = fill,
		Set = function(ratio: number, animate: boolean?)
			local goal = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
			if animate then
				tween(fill, Animation.Count, { Size = goal })
			else
				fill.Size = goal
			end
		end,
		SetColor = function(color: Color3)
			fill.BackgroundColor3 = color
		end,
	}
end

export type TabsOptions = { Items: { string }, Selected: number?, Size: Vector2?, OnSelect: ((index: number) -> ())? }
export type Tabs = { Frame: Frame, Select: (index: number) -> () }

-- Onglets en pastilles : actif Gold opaque, inactif WoodDeep à PanelStrong.
function UIKit.tabs(parent: Instance, options: TabsOptions): Tabs
	local size = options.Size or Vector2.new(56, Spacing.TouchTarget)
	local frame = Instance.new("Frame")
	frame.Name = "Onglets"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromOffset(#options.Items * size.X + (#options.Items - 1) * Spacing.S, size.Y)
	frame.Parent = parent
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.Padding = UDim.new(0, Spacing.S)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = frame
	local buttons: { TextButton } = {}
	local function select(index: number)
		for i, b in buttons do
			local active = i == index
			b.BackgroundColor3 = if active then Colors.Gold else Colors.WoodDeep
			b.BackgroundTransparency = if active then 0 else UITheme.Transparency.PanelStrong
		end
	end
	for i, item in options.Items do
		local b = Instance.new("TextButton")
		b.Name = item
		b.AutoButtonColor = false
		b.Text = ""
		b.LayoutOrder = i
		b.Size = UDim2.fromOffset(size.X, size.Y)
		b.Parent = frame
		UIKit.corner(b, UITheme.Radius.Medium)
		UIKit.stroke(b, UITheme.Stroke.Regular)
		UIKit.text(b, item, Typography.Size.Label)
		local scale = Instance.new("UIScale")
		scale.Parent = b
		b.MouseButton1Down:Connect(function()
			tween(scale, Animation.Press, { Scale = Animation.Scale.Pressed })
		end)
		b.MouseButton1Up:Connect(function()
			tween(scale, Animation.Hover, { Scale = 1 })
		end)
		b.MouseLeave:Connect(function()
			tween(scale, Animation.Hover, { Scale = 1 })
		end)
		b.Activated:Connect(function()
			if options.OnSelect then
				options.OnSelect(i)
			end
		end)
		buttons[i] = b
	end
	select(options.Selected or 1)
	return { Frame = frame, Select = select }
end

------------------------------------------------------------------ cartes et portraits

-- Portrait 3D d'un modèle (copie) dans un ViewportFrame, cadré sur le haut du corps, éclairé d'en
-- haut à gauche. La caméra regarde l'avant du modèle (déduit des bras pour les héros générés).
function UIKit.portrait(parent: Instance, template: Model, full: boolean?): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Portrait"
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.Ambient = Colors.Cream
	viewport.LightColor = Color3.new(1, 1, 1)
	viewport.LightDirection = Vector3.new(1, -1, 1)
	viewport.Parent = parent
	local model = template:Clone()
	for _, item in model:GetDescendants() do
		if item:IsA("Script") or item:IsA("LocalScript") or item:IsA("BillboardGui") or item:IsA("Highlight") then
			item:Destroy()
		end
	end
	model.Parent = viewport
	local box, size = model:GetBoundingBox()
	local front = model:GetPivot().LookVector
	local left = model:FindFirstChild("left_arm_geom", true)
	local right = model:FindFirstChild("right_arm_geom", true)
	if left and right and left:IsA("BasePart") and right:IsA("BasePart") then
		local side = (right.Position - left.Position) * Vector3.new(1, 0, 1)
		if side.Magnitude > 1e-3 then
			front = Vector3.yAxis:Cross(side.Unit)
		end
	end
	front = Vector3.new(front.X, 0, front.Z).Unit
	-- trois quarts : un peu de côté, un peu au-dessus
	local side = Vector3.yAxis:Cross(front)
	local target = box.Position + Vector3.new(0, if full then 0 else size.Y * 0.18, 0)
	local distance = (if full then size.Y * 1.9 else size.Y * 1.25) + math.max(size.X, size.Z) * 0.3
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.CFrame = CFrame.lookAt(target + (front + side * 0.35).Unit * distance + Vector3.new(0, size.Y * 0.12, 0), target)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return viewport
end

export type CardOptions = {
	Size: Vector2?,
	Name: string?,
	Model: Model?,
	Badge: string?,
	BadgeColor: Color3?,
	Selected: boolean?,
	Locked: boolean?,
	Empty: boolean?,
}

-- Carte standard : Cream à PanelStrong, contour Regular, grande zone d'illustration Sand (≥ 60 %), nom
-- dessous, badge d'état à cheval sur le bord haut. Slot vide : WoodDeep, sans contenu.
function UIKit.card(parent: Instance, options: CardOptions): Frame
	local size = options.Size or Vector2.new(132, 168)
	local frame = Instance.new("Frame")
	frame.Name = options.Name or "Carte"
	frame.Size = UDim2.fromOffset(size.X, size.Y)
	frame.BackgroundColor3 = if options.Empty then Colors.WoodDeep else Colors.Cream
	frame.BackgroundTransparency = UITheme.Transparency.PanelStrong
	frame.Parent = parent
	UIKit.corner(frame, UITheme.Radius.Medium)
	local border = UIKit.stroke(frame, UITheme.Stroke.Regular)
	if options.Selected then
		border.Color = Colors.Selected
		border.Thickness = UITheme.Stroke.Thick
	end
	if options.Empty then
		return frame
	end
	local art = Instance.new("Frame")
	art.Name = "Illustration"
	art.Position = UDim2.fromOffset(Spacing.S, Spacing.S + 4)
	art.Size = UDim2.new(1, -2 * Spacing.S, 0.66, -Spacing.S)
	art.BackgroundColor3 = Colors.Sand
	art.BackgroundTransparency = UITheme.Transparency.PanelStrong
	art.ClipsDescendants = true
	art.Parent = frame
	UIKit.corner(art, UITheme.Radius.Small)
	if options.Model then
		UIKit.portrait(art, options.Model)
	end
	if options.Name then
		local name = UIKit.text(frame, options.Name, Typography.Size.Label, { Color = Colors.InkSoft, Stroke = false })
		name.Name = "Nom"
		name.Position = UDim2.new(0, Spacing.XS, 0.66, Spacing.XS)
		name.Size = UDim2.new(1, -2 * Spacing.XS, 0.34, -Spacing.S)
		name.TextWrapped = true
	end
	if options.Badge then
		UIKit.badge(frame, options.Badge, options.BadgeColor or Colors.RoyalRed)
	end
	if options.Locked then
		for _, item in frame:GetDescendants() do
			if item:IsA("ViewportFrame") then
				item.ImageTransparency = 0.6
			elseif item:IsA("TextLabel") then
				item.TextTransparency = 0.6
			end
		end
		frame.BackgroundTransparency = 0.6
	end
	return frame
end

------------------------------------------------------------------ transitions

-- Voile Ink à Overlay derrière une fenêtre modale (jamais noir plein). Absorbe les clics.
function UIKit.overlay(screen: Instance): TextButton
	local veil = Instance.new("TextButton")
	veil.Name = "Voile"
	veil.AutoButtonColor = false
	veil.Text = ""
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Colors.Ink
	veil.BackgroundTransparency = 1
	veil.ZIndex = 0
	veil.Parent = screen
	return veil
end

-- Une seule UIScale par élément (Roblox n'en applique qu'une) : ouverture, pop et survol la partagent.
local function scaleOf(object: GuiObject): UIScale
	local scale = object:FindFirstChildOfClass("UIScale")
	if scale then
		return scale
	end
	local created = Instance.new("UIScale")
	created.Name = "Echelle"
	created.Parent = object
	return created
end

local function canvasOf(object: GuiObject): CanvasGroup?
	local parent = object.Parent
	return if parent and parent:IsA("CanvasGroup") then parent else nil
end

-- Ouverture : 0,9 → 1 en 0,22 s (Back Out) + fondu du voile.
function UIKit.open(object: GuiObject, veil: GuiObject?)
	local scale = scaleOf(object)
	scale.Scale = Animation.Scale.OpenFrom
	object.Visible = true
	tween(scale, Animation.Open, { Scale = 1 })
	if veil then
		veil.Visible = true
		veil.BackgroundTransparency = 1
		tween(veil, Animation.Fade, { BackgroundTransparency = UITheme.Transparency.Overlay })
	end
	local canvas = canvasOf(object)
	if canvas then
		canvas.GroupTransparency = 1
		tween(canvas, Animation.Fade, { GroupTransparency = 0 })
	end
end

-- Fermeture : 1 → 0,9 + fondu en 0,12 s, puis masque (ou détruit).
function UIKit.close(object: GuiObject, veil: GuiObject?, destroy: boolean?, onDone: (() -> ())?)
	local scale = scaleOf(object)
	local t = tween(scale, Animation.Close, { Scale = Animation.Scale.OpenFrom })
	if veil then
		tween(veil, Animation.Close, { BackgroundTransparency = 1 })
	end
	local canvas = canvasOf(object)
	if canvas then
		tween(canvas, Animation.Close, { GroupTransparency = 1 })
	end
	t.Completed:Connect(function()
		if destroy then
			object:Destroy()
			if veil then
				veil:Destroy()
			end
		else
			object.Visible = false
			if veil then
				veil.Visible = false
			end
		end
		if onDone then
			onDone()
		end
	end)
end

-- Pop 0 → peak → 1 (gain, badge « Nouveau », carte).
function UIKit.popIn(object: GuiObject, delay: number?, peak: number?)
	local scale = scaleOf(object)
	scale.Scale = 0
	task.delay(delay or 0, function()
		if not scale.Parent then
			return
		end
		local up = tween(scale, TweenInfo.new(Animation.Toast.Time * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = peak or Animation.Scale.Pop })
		up.Completed:Wait()
		if scale.Parent then
			tween(scale, TweenInfo.new(Animation.Toast.Time * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 })
		end
	end)
end

-- Pop d'un élément déjà affiché : 1 → peak → 1 (gain, compteur qui avance).
function UIKit.bump(object: GuiObject, peak: number?)
	local s = scaleOf(object)
	local up = tween(s, TweenInfo.new(Animation.Toast.Time * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = peak or Animation.Scale.Pop })
	up.Completed:Connect(function()
		tween(s, TweenInfo.new(Animation.Toast.Time * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 })
	end)
end

export type AnnounceOptions = { Color: Color3?, Size: number?, Hold: number?, Y: number? }

-- Annonce (vague, mini-boss, quête terminée) : texte contouré sans fond, pop, tenue 2 à 3 s, fondu.
function UIKit.announce(screen: Instance, text: string, options: AnnounceOptions?): TextLabel
	local opts: AnnounceOptions = options or {}
	local size = opts.Size or Typography.Size.Title
	local label = UIKit.text(screen, text, size, { Color = opts.Color or Colors.GoldLight })
	label.Name = "Annonce"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, opts.Y or 120)
	label.Size = UDim2.fromOffset(800, size + 16)
	label.ZIndex = 20
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = label
	tween(scale, Animation.Toast, { Scale = 1 })
	task.delay(Animation.Toast.Time + (opts.Hold or 2), function()
		if not label.Parent then
			return
		end
		local stroke = label:FindFirstChildOfClass("UIStroke")
		tween(label, Animation.Fade, { TextTransparency = 1 })
		if stroke then
			tween(stroke, Animation.Fade, { Transparency = 1 })
		end
		task.delay(Animation.Fade.Time, function()
			label:Destroy()
		end)
	end)
	return label
end

-- Rayons dorés lents derrière un titre ou une carte (victoire, héros obtenu). Un GuiObject tourne
-- autour de son propre centre : chaque rayon est un carré transparent centré qui porte un faisceau
-- partant du centre vers le haut. Renvoie le support (à positionner) ; il tourne jusqu'à sa destruction.
function UIKit.rays(parent: Instance, length: number, count: number?): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Rayons"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Size = UDim2.fromOffset(length * 2, length * 2)
	holder.BackgroundTransparency = 1
	holder.Parent = parent
	local n = count or 12
	for i = 1, n do
		local arm = Instance.new("Frame")
		arm.Size = UDim2.fromScale(1, 1)
		arm.BackgroundTransparency = 1
		arm.Rotation = (i - 1) * 360 / n
		arm.Parent = holder
		local beam = Instance.new("Frame")
		beam.AnchorPoint = Vector2.new(0.5, 0)
		beam.Position = UDim2.fromScale(0.5, 0)
		beam.Size = UDim2.new(0, if i % 2 == 0 then length * 0.1 else length * 0.15, 0.5, 0)
		beam.BackgroundColor3 = Colors.GoldLight
		beam.BorderSizePixel = 0
		beam.Parent = arm
		-- plein près du centre, effacé vers l'extérieur ; pas de reflet glossy
		local fade = Instance.new("UIGradient")
		fade.Rotation = 90
		fade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.75, 0.7),
			NumberSequenceKeypoint.new(1, 0.55),
		})
		fade.Parent = beam
	end
	local spin = tween(holder, TweenInfo.new(14, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Rotation = 360 })
	holder.Destroying:Connect(function()
		spin:Cancel()
	end)
	return holder
end

-- Transition entre deux scènes (plot → arène, combat → plot) : voile Ink qui monte en fondu avec un
-- titre contouré, onMiddle() est appelé une fois couvert (téléportation, changement de décor), puis le
-- voile redescend. Le monde reste deviné derrière (voile à Overlay renforcé, jamais noir plein).
function UIKit.curtain(title: string?, onMiddle: (() -> ())?, hold: number?)
	local screen = UIKit.screen("Transition", 50)
	local veil = Instance.new("Frame")
	veil.Name = "Voile"
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Colors.Ink
	veil.BackgroundTransparency = 1
	veil.Parent = screen
	local label: TextLabel? = nil
	if title then
		local l = UIKit.text(screen, title, Typography.Size.Title)
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.5, 0.5)
		l.Size = UDim2.fromOffset(800, 60)
		l.TextTransparency = 1
		local s = l:FindFirstChildOfClass("UIStroke")
		if s then
			s.Transparency = 1
		end
		label = l
	end
	local covered = UITheme.Transparency.Overlay * 0.3 -- monde encore deviné
	local function fadeText(target: number)
		local l = label
		if l then
			tween(l, Animation.Fade, { TextTransparency = target })
			local s = l:FindFirstChildOfClass("UIStroke")
			if s then
				tween(s, Animation.Fade, { Transparency = target })
			end
		end
	end
	tween(veil, Animation.Fade, { BackgroundTransparency = covered }).Completed:Wait()
	fadeText(0)
	if onMiddle then
		onMiddle()
	end
	task.wait(hold or 0.6)
	fadeText(1)
	tween(veil, Animation.Fade, { BackgroundTransparency = 1 }).Completed:Wait()
	screen:Destroy()
end

return UIKit
