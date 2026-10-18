--!strict
-- Rendu d'une rareté de héros côté client (RarityConfig + couleurs UITheme.Rarity) : couleur, libellé,
-- badge, le dégradé qui tourne de Transcendant, et le second repère (forme × nombre, UITheme.RarityMark)
-- qui distingue les dix raretés sans la couleur. Les monstres n'ont aucune rareté.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RarityConfig = require(ReplicatedStorage.Shared.Config.RarityConfig)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local UIKit = require(script.Parent.UIKit)

local Colors = UITheme.Colors

local RarityStyle = {}

local PRISM_PERIOD = 3 -- s pour un tour complet du dégradé Transcendant

function RarityStyle.rank(id: string?): number
	return if id then RarityConfig.Rank[id] or 1 else 1
end

function RarityStyle.name(id: string?): string
	local tier = RarityConfig.tier(id)
	return if tier then tier.Name else RarityConfig.Tiers[1].Name
end

function RarityStyle.color(id: string?): Color3
	return (UITheme.Rarity :: any)[id or ""] or UITheme.Rarity.Commun
end

function RarityStyle.prismatic(id: string?): boolean
	return id == "Transcendant"
end

-- Couleur à l'instant t (Transcendant : parcourt le prisme ; sinon la couleur fixe).
function RarityStyle.colorAt(id: string?, t: number): Color3
	if not RarityStyle.prismatic(id) then
		return RarityStyle.color(id)
	end
	local prism = UITheme.RarityPrism
	local x = (t / PRISM_PERIOD % 1) * #prism
	local i = math.floor(x)
	return prism[i + 1]:Lerp(prism[(i + 1) % #prism + 1], x - i)
end

-- Séquence de couleurs pour particules / faisceaux.
function RarityStyle.sequence(id: string?): ColorSequence
	if not RarityStyle.prismatic(id) then
		return ColorSequence.new(RarityStyle.color(id))
	end
	local prism = UITheme.RarityPrism
	local keys = {}
	for i, color in prism do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#prism - 1), color))
	end
	return ColorSequence.new(keys)
end

-- Dégradé prismatique qui tourne, posé sur un GuiObject ou un UIStroke (détruit avec lui).
function RarityStyle.prism(target: Instance)
	local gradient = Instance.new("UIGradient")
	gradient.Color = RarityStyle.sequence("Transcendant")
	gradient.Parent = target
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		if not gradient.Parent then
			connection:Disconnect()
			return
		end
		gradient.Rotation = (os.clock() / PRISM_PERIOD * 360) % 360
	end)
end

-- Colore un objet (fond, texte ou contour) selon la rareté ; Transcendant reçoit le prisme.
function RarityStyle.paint(target: Instance, id: string?)
	local color = RarityStyle.color(id)
	if target:IsA("UIStroke") then
		target.Color = if RarityStyle.prismatic(id) then Color3.new(1, 1, 1) else color
	elseif target:IsA("TextLabel") then
		target.TextColor3 = if RarityStyle.prismatic(id) then Color3.new(1, 1, 1) else color
	elseif target:IsA("GuiObject") then
		target.BackgroundColor3 = if RarityStyle.prismatic(id) then Color3.new(1, 1, 1) else color
	end
	if RarityStyle.prismatic(id) then
		RarityStyle.prism(target)
	end
end

-- Pièces d'une forme, en fraction de sa case carrée : silhouette Ink derrière (contour « cuit », comme
-- les icônes), face claire devant ; Hole = creux Ink posé sur la face.
type Piece = { W: number, H: number, Rotation: number?, Round: boolean?, Hole: boolean? }
local SHAPES: { [string]: { Piece } } = {
	Circle = { { W = 0.78, H = 0.78, Round = true } },
	Diamond = { { W = 0.6, H = 0.6, Rotation = 45 } },
	Cross = { { W = 0.95, H = 0.26, Rotation = 45 }, { W = 0.95, H = 0.26, Rotation = -45 } },
	Ring = { { W = 0.84, H = 0.84, Round = true }, { W = 0.36, H = 0.36, Round = true, Hole = true } },
	Burst = { { W = 0.95, H = 0.24, Rotation = 90 }, { W = 0.95, H = 0.24, Rotation = 30 }, { W = 0.95, H = 0.24, Rotation = 150 } },
	Star = { { W = 0.62, H = 0.62 }, { W = 0.62, H = 0.62, Rotation = 45 } },
}

local MAX_COUNT = 1
for _, spec in UITheme.RarityMark do
	MAX_COUNT = math.max(MAX_COUNT, spec.Count)
end

local function markSpec(id: string?): { Shape: string, Count: number }
	return (UITheme.RarityMark :: any)[id or ""] or UITheme.RarityMark.Commun
end

local function markWidth(count: number, size: number): number
	return count * size + (count - 1) * UITheme.Spacing.XS
end

local function piece(cell: Frame, p: Piece, color: Color3, grow: number, z: number)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.new(p.W, 2 * grow, p.H, 2 * grow)
	f.Rotation = p.Rotation or 0
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.ZIndex = z
	f.Parent = cell
	if p.Round then
		UIKit.corner(f, UITheme.Radius.Pill)
	end
end

-- Second repère d'une rareté : sa forme répétée Count fois, claire et contourée Ink, lisible sur
-- n'importe quel fond. size = côté d'une forme (px). Cadre transparent à la taille exacte du repère.
function RarityStyle.mark(parent: Instance, id: string?, size: number): Frame
	local spec = markSpec(id)
	local outline = UITheme.Stroke.Thin
	local frame = Instance.new("Frame")
	frame.Name = "Repere"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromOffset(markWidth(spec.Count, size), size)
	frame.Parent = parent
	for i = 1, spec.Count do
		local cell = Instance.new("Frame")
		cell.Name = spec.Shape
		cell.BackgroundTransparency = 1
		cell.Position = UDim2.fromOffset((i - 1) * (size + UITheme.Spacing.XS), 0)
		cell.Size = UDim2.fromOffset(size, size)
		cell.Parent = frame
		for _, p in SHAPES[spec.Shape] or SHAPES.Circle do
			if p.Hole then
				piece(cell, p, Colors.Ink, 0, 3)
			else
				piece(cell, p, Colors.Ink, outline, 1)
				piece(cell, p, Colors.TextLight, 0, 2)
			end
		end
	end
	return frame
end

-- Pastille de rareté sans texte (listes, coin de carte) : fond de la couleur de la rareté, contour Ink,
-- repère au centre. Même largeur pour toutes les raretés (repère le plus long) : les listes s'alignent.
function RarityStyle.chip(parent: Instance, id: string?, size: number): Frame
	local chip = Instance.new("Frame")
	chip.Name = "Rarete"
	chip.Size = UDim2.fromOffset(markWidth(MAX_COUNT, size) + 2 * UITheme.Spacing.S, size + 2 * UITheme.Spacing.XS)
	chip.Parent = parent
	UIKit.corner(chip, UITheme.Radius.Pill)
	UIKit.stroke(chip, UITheme.Stroke.Thin)
	RarityStyle.paint(chip, id)
	local mark = RarityStyle.mark(chip, id, size)
	mark.AnchorPoint = Vector2.new(0.5, 0.5)
	mark.Position = UDim2.fromScale(0.5, 0.5)
	return chip
end

-- Range le repère puis le libellé d'un badge côte à côte, centrés.
local function withMark(badge: Frame, id: string?, size: number)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, UITheme.Spacing.XS)
	layout.Parent = badge
	local label = badge:FindFirstChildOfClass("TextLabel")
	if label then
		label.LayoutOrder = 2
		label.AutomaticSize = Enum.AutomaticSize.X
		label.Size = UDim2.fromScale(0, 1)
	end
	local mark = RarityStyle.mark(badge, id, size)
	mark.LayoutOrder = 1
	mark.ZIndex = if label then label.ZIndex else badge.ZIndex
end

-- Badge de rareté (pastille contourée Ink, repère puis libellé clair).
function RarityStyle.badge(parent: Instance, id: string?): Frame
	local badge = UIKit.badge(parent, RarityStyle.name(id), RarityStyle.color(id))
	badge.Name = "Rarete"
	RarityStyle.paint(badge, id)
	withMark(badge, id, UITheme.Typography.Size.Caption)
	return badge
end

-- Badge de rareté à cheval sur le bord haut d'une carte, élargi pour le repère.
function RarityStyle.edgeBadge(parent: Instance, id: string?): Frame
	local badge = UIKit.edgeBadge(parent, RarityStyle.name(id), RarityStyle.color(id))
	badge.Name = "Rarete"
	RarityStyle.paint(badge, id)
	local size = UITheme.Typography.Size.Caption
	local extra = markWidth(markSpec(id).Count, size) + UITheme.Spacing.XS
	badge.Size = UDim2.fromOffset(badge.Size.X.Offset + extra, badge.Size.Y.Offset)
	withMark(badge, id, size)
	return badge
end

return RarityStyle
