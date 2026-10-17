--!strict
-- Flèche UI du tutoriel (voir docs/TUTORIAL_GUIDANCE.md, docs/UI_DESIGN_SYSTEM.md § Guidage) : UNE
-- seule à la fois, par-dessus toutes les interfaces. Elle pointe un élément affiché (GuideTargets) :
--   • une flèche 3D dorée (Icons « Fleche », même langage que les icônes) qui rebondit vers la cible,
--     placée du côté où il y a de la place (au-dessus, en dessous, ou à droite pour le menu de gauche) ;
--   • une lueur dorée qui respire autour de la cible (valeurs UITheme.World.Guide) ;
--   • une légende très courte, facultative, dans une pastille bois.
-- Elle suit la cible à chaque image (fenêtre qui s'ouvre, liste qui défile) et se cache tant que la cible
-- n'est pas affichée. Elle ne capte aucun clic : le joueur clique la cible elle-même.
-- API :
--   GuidePointer.show(target, { Text: string?, OnActivated: (() -> ())? }) -- remplace la flèche actuelle
--   GuidePointer.hide()
--   GuidePointer.target() -> GuiObject?

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
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

type State = {
	target: GuiObject,
	options: Options,
	connections: { RBXScriptConnection },
	started: number,
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
	if glow then glow.Visible = on end
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

	-- côté de la flèche : à droite pour le menu de gauche (au-dessus, elle cacherait le bouton voisin),
	-- sinon au-dessus, sinon en dessous
	local arrowSize = ARROW * s
	local bob = (0.5 + 0.5 * math.sin(now * BOB_SPEED)) * BOB * s
	local direction: Vector2, angle: number
	if center.X < UITheme.Spacing.MenuColumn * s then
		direction, angle = Vector2.new(-1, 0), 90 -- pointe vers la gauche
	elseif position.Y - arrowSize - GAP * s > 0 then
		direction, angle = Vector2.new(0, 1), 0 -- pointe vers le bas
	else
		direction, angle = Vector2.new(0, -1), 180 -- pointe vers le haut
	end
	-- bord de la cible du côté de la flèche, puis la flèche recule de sa demi-taille, de l'écart et du rebond
	local edge = center - direction * Vector2.new(size.X / 2 + pad, size.Y / 2 + pad)
	local arrowCenter = edge - direction * (arrowSize / 2 + GAP * s + bob)
	a.Size = UDim2.fromOffset(arrowSize, arrowSize)
	a.Position = UDim2.fromOffset(arrowCenter.X, arrowCenter.Y)
	if model and model:GetAttribute("Angle") ~= angle then
		model:SetAttribute("Angle", angle)
		model:PivotTo(CFrame.Angles(0, 0, math.rad(angle)))
	end
	-- légende derrière la flèche (côté opposé à la cible)
	local captionCenter = arrowCenter - direction * (arrowSize / 2 + 18 * s)
	if direction.X ~= 0 then
		captionCenter = arrowCenter - direction * (arrowSize / 2) + Vector2.new(0, arrowSize * 0.75)
	end
	pill.Size = UDim2.fromOffset(0, 34 * s)
	pill.Position = UDim2.fromOffset(captionCenter.X, captionCenter.Y)
	local label = captionText
	if label then
		label.TextSize = UITheme.Typography.Size.Label * s
	end
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
