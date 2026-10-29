--!strict
-- Flèche UI du tutoriel (voir docs/TUTORIAL_GUIDANCE.md, docs/UI_DESIGN_SYSTEM.md § Guidage) : UNE
-- seule à la fois, par-dessus toutes les interfaces. Elle pointe un élément affiché (GuideTargets) :
--   • une flèche 3D dorée (Icons « Fleche », même langage que les icônes) qui rebondit vers la cible,
--     placée du côté libre : flèche et légende entières dans l'écran, sur le moins de boutons et de
--     textes possible (au-dessus, en dessous, à droite ou à gauche ; à droite pour le menu de gauche) ;
--   • une lueur dorée qui respire autour de la cible (valeurs UITheme.World.Guide) ;
--   • une légende très courte, facultative, dans une pastille bois.
-- Elle suit la cible à chaque image (fenêtre qui s'ouvre, liste qui défile) et se cache tant que la cible
-- n'est pas affichée. Elle ne capte aucun clic : le joueur clique la cible elle-même.
-- Une cible avec l'attribut GuideGlow = false a sa propre mise en avant (ex. le halo rond du menu) : la
-- flèche ne dessine alors pas son cadre de lueur.
-- API :
--   GuidePointer.show(target, { Text: string?, OnActivated: (() -> ())? }) -- remplace la flèche actuelle
--   GuidePointer.hide()
--   GuidePointer.target() -> GuiObject?

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local GuideTargets = require(script.Parent.GuideTargets)
local Icons = require(script.Parent.Icons)
local UIKit = require(script.Parent.UIKit)

local C = UITheme.Colors
local GUIDE = UITheme.World.Guide

export type Options = { Text: string?, OnActivated: (() -> ())? }

local GuidePointer = {}

local ARROW = 76 -- px (écran de 1080 px de haut)
local GAP = 10 -- px entre la pointe et la cible
local BOB = 10 -- px d'amplitude du rebond
local BOB_SPEED = 6 -- rad/s
local PAD = 6 -- px de lueur autour de la cible
local CAPTION = 34 -- px de haut de la légende
local EDGE = 4 -- px de marge minimale au bord de l'écran

type Side = { name: string, direction: Vector2, angle: number }

type State = {
	target: GuiObject,
	options: Options,
	connections: { RBXScriptConnection },
	started: number,
	side: Side?, -- place choisie (choose : côté et glissement), gardée tant qu'une autre n'est pas nettement meilleure
	shift: number?,
	sideKey: string?,
	sideChecked: number?,
}

local screen: ScreenGui? = nil
local glow: Frame? = nil
local glowStroke: UIStroke? = nil
local arrow: Frame? = nil
local arrowModel: Model? = nil
local caption: Frame? = nil
local captionText: TextLabel? = nil
local state: State? = nil
local render: RBXScriptConnection? = nil

local function scale(): number
	local camera = Workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else 1080
	return math.clamp(height / 1080, 0.7, 1.25)
end

local function build()
	if screen and screen.Parent then
		return
	end
	local s = Instance.new("ScreenGui")
	s.Name = "GuidageTutoriel"
	s.ResetOnSpawn = false
	-- AbsolutePosition est toujours donné sous la barre du haut (même pour un écran qui l'ignore) : cet
	-- écran ne l'ignore pas, la flèche se pose donc exactement sur la cible, quel que soit son écran.
	s.IgnoreGuiInset = false
	s.DisplayOrder = 50 -- au-dessus des fenêtres (10 à 15) et du HUD
	s.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	s.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	screen = s

	local g = Instance.new("Frame")
	g.Name = "Lueur"
	g.BackgroundColor3 = GUIDE.Color
	g.BackgroundTransparency = 1
	g.Active = false
	g.Visible = false
	g.Parent = s
	UIKit.corner(g, UITheme.Radius.Medium)
	local stroke = UIKit.stroke(g, UITheme.Stroke.Thick + 1, GUIDE.Color)
	glow, glowStroke = g, stroke

	local a = Instance.new("Frame")
	a.Name = "Fleche"
	a.BackgroundTransparency = 1
	a.Active = false
	a.AnchorPoint = Vector2.new(0.5, 0.5)
	a.Visible = false
	a.Parent = s
	local viewport = Icons.viewport(a, "Fleche")
	arrowModel = viewport:FindFirstChildOfClass("Model")
	arrow = a

	local pill = Instance.new("Frame")
	pill.Name = "Legende"
	pill.AnchorPoint = Vector2.new(0.5, 0.5)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.BackgroundColor3 = C.WoodDeep
	pill.BackgroundTransparency = UITheme.Transparency.PanelStrong
	pill.Active = false
	pill.Visible = false
	pill.Parent = s
	UIKit.corner(pill, UITheme.Radius.Pill)
	UIKit.stroke(pill, UITheme.Stroke.Regular)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, UITheme.Spacing.M)
	padding.PaddingRight = UDim.new(0, UITheme.Spacing.M)
	padding.Parent = pill
	local text = UIKit.text(pill, "", UITheme.Typography.Size.Label, { Color = C.GoldLight })
	text.AutomaticSize = Enum.AutomaticSize.X
	text.Size = UDim2.fromScale(0, 1)
	caption, captionText = pill, text
end

local function setVisible(on: boolean)
	local current = state
	local ownGlow = current ~= nil and current.target:GetAttribute("GuideGlow") == false
	if glow then glow.Visible = on and not ownGlow end
	if arrow then arrow.Visible = on end
	if caption then caption.Visible = on and captionText ~= nil and captionText.Text ~= "" end
end

local function shown(gui: GuiObject): boolean
	local node: Instance? = gui
	while node do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		elseif node:IsA("LayerCollector") then
			return node.Enabled and node:IsDescendantOf(game)
		end
		node = node.Parent
	end
	return false
end

------------------------------------------------------------------ côté de la flèche

-- Side.direction : de la flèche vers la cible ; ordre de préférence à place égale : au-dessus, en dessous, à droite, à gauche
local SIDES: { Side } = {
	{ name = "Above", direction = Vector2.new(0, 1), angle = 0 },
	{ name = "Below", direction = Vector2.new(0, -1), angle = 180 },
	{ name = "Right", direction = Vector2.new(-1, 0), angle = 90 },
	{ name = "Left", direction = Vector2.new(1, 0), angle = -90 },
}
local MENU_SIDE: Side = { name = "Menu", direction = Vector2.new(-1, 0), angle = 90 }

local function viewportSize(): Vector2
	local s = screen
	if s and s.AbsoluteSize.X > 0 then
		return s.AbsoluteSize
	end
	local camera = Workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.new(1920, 1080)
end

-- Glissements possibles de la flèche le long du bord visé (part de sa longueur, 0 = centrée) : une cible
-- large garde sa flèche dessus tout en évitant un bouton voisin (ex. l'en-tête du héros sous l'onglet Héros)
local SHIFTS = { 0, -0.3, 0.3, -0.42, 0.42 }

-- Centres de la flèche et de la légende pour un côté (target : centre et taille de la cible avec sa lueur),
-- glissée de `shift` le long du bord visé
local function layout(side: Side, shift: number, center: Vector2, size: Vector2, arrowSize: number, captionSize: Vector2, s: number, bob: number): (Vector2, Vector2)
	local direction = side.direction
	local along = if direction.X ~= 0 then Vector2.new(0, size.Y * shift) else Vector2.new(size.X * shift, 0)
	local edge = center - direction * size / 2 + along
	local arrowCenter = edge - direction * (arrowSize / 2 + GAP * s + bob)
	if side == MENU_SIDE then
		return arrowCenter, arrowCenter - direction * (arrowSize / 2) + Vector2.new(0, arrowSize * 0.75)
	elseif direction.X ~= 0 then
		return arrowCenter, arrowCenter - direction * (arrowSize / 2 + captionSize.X / 2 + 4 * s)
	end
	return arrowCenter, arrowCenter - direction * (arrowSize / 2 + 18 * s)
end

-- Partie affichée d'un élément (ancêtres visibles, coupée par les cadres qui coupent leurs enfants), ou nil
local function visibleRect(gui: GuiObject): (Vector2?, Vector2?)
	if not gui.Visible then
		return nil, nil
	end
	local low, high = gui.AbsolutePosition, gui.AbsolutePosition + gui.AbsoluteSize
	local node = gui.Parent
	while node do
		if node:IsA("GuiObject") then
			if not node.Visible then
				return nil, nil
			end
			if node.ClipsDescendants then
				low, high = low:Max(node.AbsolutePosition), high:Min(node.AbsolutePosition + node.AbsoluteSize)
			end
		elseif node:IsA("LayerCollector") then
			if not node.Enabled then
				return nil, nil
			end
			break
		end
		node = node.Parent
	end
	if high.X - low.X < 2 or high.Y - low.Y < 2 then
		return nil, nil
	end
	return low, high
end

local function overlap(aLow: Vector2, aHigh: Vector2, bLow: Vector2, bHigh: Vector2): number
	local w = math.min(aHigh.X, bHigh.X) - math.max(aLow.X, bLow.X)
	local h = math.min(aHigh.Y, bHigh.Y) - math.max(aLow.Y, bLow.Y)
	return if w > 0 and h > 0 then w * h else 0
end

type Obstacle = { low: Vector2, high: Vector2, weight: number }

-- Éléments à ne pas couvrir : boutons (poids 2) et textes (poids 0,5) affichés sur un écran au moins aussi
-- haut que celui de la cible, hors cible elle-même et ses ancêtres, hors grands fonds (> 30 % de l'écran).
local function obstacles(target: GuiObject): { Obstacle }
	local list: { Obstacle } = {}
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local own = target:FindFirstAncestorWhichIsA("LayerCollector")
	if not playerGui or not own then
		return list
	end
	local order = if own:IsA("ScreenGui") then own.DisplayOrder else 0
	local view = viewportSize()
	local big = view.X * view.Y * 0.3
	for _, gui in playerGui:GetChildren() do
		if gui == screen or not gui:IsA("ScreenGui") or not gui.Enabled or gui.DisplayOrder < order then
			continue
		end
		for _, node in gui:GetDescendants() do
			local weight = if node:IsA("GuiButton") or node:IsA("TextBox") then 2
				elseif node:IsA("TextLabel") and node.Text ~= "" then 0.5
				else 0
			if weight == 0 then
				continue
			end
			local item = node :: GuiObject
			if item == target or item:IsDescendantOf(target) or target:IsDescendantOf(item) then
				continue
			end
			local low, high = visibleRect(item)
			if low and high and (high.X - low.X) * (high.Y - low.Y) < big then
				table.insert(list, { low = low, high = high, weight = weight })
			end
		end
	end
	return list
end

local RECHECK = 1 -- s entre deux choix de la place (et aussitôt que la cible bouge ou que la légende change)
local KEEP = 0.15 -- part de la surface de la flèche : un autre côté doit faire mieux pour la déplacer

-- Place libre pour la flèche et la légende (côté et glissement) : entières dans l'écran, sur le moins de
-- boutons et de textes possible, jamais sur la cible ; à place égale l'ordre de SIDES, centrée de
-- préférence ; la place actuelle reste sauf nette amélioration (pas de clignotement).
local function choose(current: State, low: Vector2, size: Vector2, arrowSize: number, captionSize: Vector2, s: number): (Side, number)
	local now = os.clock()
	local key = `{math.floor(low.X / 4)},{math.floor(low.Y / 4)},{math.floor(size.X / 4)},{math.floor(size.Y / 4)},{math.floor(captionSize.X)}`
	if current.side and current.sideKey == key and now - (current.sideChecked or 0) < RECHECK then
		return current.side :: Side, current.shift or 0
	end
	current.sideKey, current.sideChecked = key, now
	local view = viewportSize()
	local center = low + size / 2
	local high = low + size
	local blockers = obstacles(current.target)
	local area = arrowSize * arrowSize
	local body = arrowSize * 0.8 -- la flèche 3D n'occupe pas tout son cadre
	local function score(side: Side, index: number, shift: number): number
		local arrowCenter, captionCenter = layout(side, shift, center, size, arrowSize, captionSize, s, BOB * s)
		local boxes = { { arrowCenter - Vector2.new(body, body) / 2, arrowCenter + Vector2.new(body, body) / 2 } }
		if captionSize.X > 0 then
			table.insert(boxes, { captionCenter - captionSize / 2, captionCenter + captionSize / 2 })
		end
		local total = (index - 1) * area * 0.02 + math.abs(shift) * area * 0.1
		for _, b in boxes do
			local inside = overlap(b[1], b[2], Vector2.new(EDGE, EDGE), view - Vector2.new(EDGE, EDGE))
			local full = (b[2].X - b[1].X) * (b[2].Y - b[1].Y)
			total += (full - inside) * 4 -- hors de l'écran : à éviter avant tout
			total += overlap(b[1], b[2], low, high) * 2 -- sur la cible
			for _, o in blockers do
				total += overlap(b[1], b[2], o.low, o.high) * o.weight
			end
		end
		return total
	end
	local best, bestShift, bestScore = SIDES[1], 0, math.huge
	local kept: number? = nil
	for index, side in SIDES do
		for _, shift in SHIFTS do
			local value = score(side, index, shift)
			if side == current.side and shift == (current.shift or 0) then
				kept = value
			end
			if value < bestScore then
				best, bestShift, bestScore = side, shift, value
			end
		end
	end
	if current.side and kept and kept <= bestScore + area * KEEP then
		return current.side :: Side, current.shift or 0
	end
	current.side, current.shift = best, bestShift
	return best, bestShift
end

local function step()
	local current = state
	local g, a, pill, stroke, model = glow, arrow, caption, glowStroke, arrowModel
	if not current or not g or not a or not pill or not stroke then
		return
	end
	local target = current.target
	if not target.Parent or not shown(target) or target.AbsoluteSize.X < 1 then
		setVisible(false)
		return
	end
	setVisible(true)
	local s = scale()
	local now = os.clock() - current.started
	local position = target.AbsolutePosition
	local size = target.AbsoluteSize
	local center = position + size / 2
	-- lueur qui respire (mêmes valeurs que les cibles du monde)
	local wave = 0.5 + 0.5 * math.sin(now * 2 * math.pi / GUIDE.Period)
	local pad = PAD * s
	g.Position = UDim2.fromOffset(position.X - pad, position.Y - pad)
	g.Size = UDim2.fromOffset(size.X + 2 * pad, size.Y + 2 * pad)
	g.BackgroundTransparency = 0.92 - 0.2 * wave
	stroke.Transparency = 0.45 * (1 - wave)

	local arrowSize = ARROW * s
	local bob = (0.5 + 0.5 * math.sin(now * BOB_SPEED)) * BOB * s
	-- légende jamais sous Caption (14 px réels, design system), même sur un petit écran
	local textSize = math.max(UITheme.Typography.Size.Label * s, UITheme.Typography.Size.Caption)
	local label = captionText
	if label then
		label.TextSize = textSize
	end
	local captionSize = Vector2.new(
		if label and label.Text ~= "" then label.TextBounds.X + 2 * UITheme.Spacing.M else 0,
		math.max(CAPTION * s, textSize + 2 * UITheme.Spacing.S)
	)
	-- côté de la flèche : menu principal en grille → à droite (au-dessus, elle cacherait le bouton voisin) ;
	-- menu sur une ligne (petit écran) → en dessous ; ailleurs le côté libre (choose : écran, boutons)
	local menu = GuideTargets.get("Menu.Area")
	local inMenu = menu ~= nil and center.X >= menu.AbsolutePosition.X and center.X <= menu.AbsolutePosition.X + menu.AbsoluteSize.X
		and center.Y >= menu.AbsolutePosition.Y and center.Y <= menu.AbsolutePosition.Y + menu.AbsoluteSize.Y
	local side: Side, shift = SIDES[1], 0
	if inMenu and menu and menu.AbsoluteSize.X > menu.AbsoluteSize.Y * 1.5 then
		side = SIDES[2] -- menu sur une ligne : flèche dessous, pointe vers le haut
	elseif inMenu then
		side = MENU_SIDE -- pointe vers la gauche, légende sous la flèche
	else
		side, shift = choose(current, position - Vector2.new(pad, pad), size + Vector2.new(2 * pad, 2 * pad), arrowSize, captionSize, s)
	end
	local arrowCenter, captionCenter = layout(side, shift, center, size + Vector2.new(2 * pad, 2 * pad), arrowSize, captionSize, s, bob)
	a.Size = UDim2.fromOffset(arrowSize, arrowSize)
	a.Position = UDim2.fromOffset(arrowCenter.X, arrowCenter.Y)
	if model and model:GetAttribute("Angle") ~= side.angle then
		model:SetAttribute("Angle", side.angle)
		model:PivotTo(CFrame.Angles(0, 0, math.rad(side.angle)))
	end
	-- légende toujours entière à l'écran (jamais coupée par un bord)
	local view = viewportSize()
	local half = captionSize / 2
	captionCenter = Vector2.new(
		math.clamp(captionCenter.X, half.X + EDGE, math.max(half.X + EDGE, view.X - half.X - EDGE)),
		math.clamp(captionCenter.Y, half.Y + EDGE, math.max(half.Y + EDGE, view.Y - half.Y - EDGE))
	)
	pill.Size = UDim2.fromOffset(0, captionSize.Y)
	pill.Position = UDim2.fromOffset(captionCenter.X, captionCenter.Y)
end

local function disconnect(current: State)
	for _, connection in current.connections do
		connection:Disconnect()
	end
	table.clear(current.connections)
end

function GuidePointer.hide()
	local current = state
	if current then
		disconnect(current)
	end
	state = nil
	setVisible(false)
	if render then
		render:Disconnect()
		render = nil
	end
end

function GuidePointer.show(target: GuiObject, options: Options?)
	local opts: Options = options or {}
	local current = state
	if current and current.target == target and current.options.Text == opts.Text then
		current.options = opts -- même cible : la flèche ne repart pas de zéro
		return
	end
	GuidePointer.hide()
	build()
	local nextState: State = { target = target, options = opts, connections = {}, started = os.clock() }
	state = nextState
	local label = captionText
	if label then
		label.Text = opts.Text or ""
	end
	local button: Instance? = if target:IsA("GuiButton") then target else target:FindFirstChildWhichIsA("GuiButton", true)
	if button and button:IsA("GuiButton") then
		table.insert(nextState.connections, button.Activated:Connect(function()
			local onActivated = nextState.options.OnActivated
			if state == nextState and onActivated then
				onActivated()
			end
		end))
	end
	table.insert(nextState.connections, target.Destroying:Connect(function()
		if state == nextState then
			GuidePointer.hide()
		end
	end))
	render = RunService.RenderStepped:Connect(step)
	step()
	local a = arrow
	if a then
		UIKit.popIn(a, 0, 1.15)
	end
end

function GuidePointer.target(): GuiObject?
	local current = state
	return if current then current.target else nil
end

return GuidePointer
