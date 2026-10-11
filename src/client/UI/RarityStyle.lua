--!strict
-- Rendu d'une rareté de héros côté client (RarityConfig + couleurs UITheme.Rarity) : couleur, libellé,
-- badge, et le dégradé qui tourne de Transcendant. Les monstres n'ont aucune rareté.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RarityConfig = require(ReplicatedStorage.Shared.Config.RarityConfig)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local UIKit = require(script.Parent.UIKit)

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

-- Badge de rareté (pastille contourée Ink, libellé clair).
function RarityStyle.badge(parent: Instance, id: string?): Frame
	local badge = UIKit.badge(parent, RarityStyle.name(id), RarityStyle.color(id))
	badge.Name = "Rarete"
	RarityStyle.paint(badge, id)
	return badge
end

-- Badge de rareté à cheval sur le bord haut d'une carte.
function RarityStyle.edgeBadge(parent: Instance, id: string?): Frame
	local badge = UIKit.edgeBadge(parent, RarityStyle.name(id), RarityStyle.color(id))
	badge.Name = "Rarete"
	RarityStyle.paint(badge, id)
	return badge
end

return RarityStyle
