--!strict
-- Aura de rareté animée sur les cartes de la vitrine Équipement du Bestiaire (purement visuel, client).
-- Même langage que HeroCard (Invocation V2) : rayons qui tournent dès Légendaire, étincelles qui
-- scintillent dès Épique, contour prismatique qui tourne pour Transcendant. Les rayons restent dans la
-- zone d'illustration (ClipsDescendants), derrière l'icône, pour ne pas déborder sur les cartes voisines.
-- La teinte et le contour de rareté sont posés une fois dans Studio par tools/studio-items-rarete.luau.
-- Sans vitrine dans la place (jeu), ce contrôleur ne fait rien.
-- Images : rays et sparkle d'InvocationVisualConfig. Une image n'est visible que pour le compte qui la
-- possède : une place peut donner les siennes avec les attributs AuraRays / AuraSparkle (rbxassetid)
-- posés sur le dossier Emplacements de la vitrine.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Assets = require(ReplicatedStorage.Shared.Config.InvocationVisualConfig)
local RarityConfig = require(ReplicatedStorage.Shared.Config.RarityConfig)
local Theme = require(ReplicatedStorage.Shared.Config.UITheme)
local Rarity = require(script.Parent.Parent.UI.RarityStyle)

local RANK_RAYS = 5 -- Légendaire
local RANK_SPARKLES = 4 -- Épique
local RANK_CURSED = 7 -- Maudit : rayons d'ombre (Ink) plutôt que de lumière
local RAYS_SPEED = 20 -- degrés / seconde, comme HeroCard
local DISTANCE_MAX = 160 -- au-delà, la vitrine n'est pas animée
local SPARKLE_SPOTS = { Vector2.new(0.08, 0.1), Vector2.new(0.78, 0.18), Vector2.new(0.14, 0.62), Vector2.new(0.72, 0.6) }

local VitrineRareteController = {}

type Card = { rays: ImageLabel?, sparkles: { ImageLabel }, phase: number }

local cards: { Card } = {}
local anchor: BasePart? = nil
local images: { [string]: string } = { rays = Assets.rays, sparkle = Assets.sparkle }

local function image(parent: Instance, key: string, size: UDim2, position: UDim2, zIndex: number): ImageLabel
	local label = Instance.new("ImageLabel")
	label.Name = "Aura_" .. key
	label.BackgroundTransparency = 1
	label.Image = images[key]
	label.ScaleType = Enum.ScaleType.Fit
	label.Size = size
	label.Position = position
	label.ZIndex = zIndex
	label.Parent = parent
	return label
end

local function decorate(card: Instance, index: number)
	local id = RarityConfig.ByName[card:GetAttribute("Rarete") :: any]
	local art = card:FindFirstChild("Illustration")
	if not id or not (art and art:IsA("GuiObject")) then
		return
	end
	local rank = Rarity.rank(id)
	local icon = art:FindFirstChild("Icone")
	if icon and icon:IsA("GuiObject") then
		icon.ZIndex = 3
	end
	art.ClipsDescendants = true

	local entry: Card = { rays = nil, sparkles = {}, phase = index * 0.37 }
	if rank >= RANK_RAYS then
		local rays = image(art, "rays", UDim2.fromScale(1.9, 1.9), UDim2.fromScale(0.5, 0.5), 2)
		rays.AnchorPoint = Vector2.new(0.5, 0.5)
		rays.ImageColor3 = if rank == RANK_CURSED then Theme.Colors.Ink else Rarity.color(id)
		rays.ImageTransparency = Theme.Transparency.Track
		entry.rays = rays
	end
	if rank >= RANK_SPARKLES then
		for i, spot in SPARKLE_SPOTS do
			if i > math.min(#SPARKLE_SPOTS, rank - 2) then
				break
			end
			local size = if i == 1 then 0.26 else 0.16
			local sparkle = image(art, "sparkle", UDim2.fromScale(size, size), UDim2.fromScale(spot.X, spot.Y), 4)
			sparkle.SizeConstraint = Enum.SizeConstraint.RelativeYY
			sparkle.ImageColor3 = if rank >= 8 then Theme.Colors.CurrencyGems elseif rank == RANK_CURSED then Theme.Rarity.Epique else Theme.Colors.GoldLight
			table.insert(entry.sparkles, sparkle)
		end
	end
	if Rarity.prismatic(id) then
		local stroke = art:FindFirstChild("Rarete")
		if stroke and stroke:IsA("UIStroke") then
			local fixed = stroke:FindFirstChildWhichIsA("UIGradient")
			if fixed then
				fixed:Destroy() -- dégradé figé de la vitrine, remplacé par celui qui tourne
			end
			Rarity.paint(stroke, id)
		end
	end
	if entry.rays or #entry.sparkles > 0 then
		table.insert(cards, entry)
	end
end

function VitrineRareteController:Start()
	local bestiaire = Workspace:WaitForChild("Bestiaire", 30)
	local slots = bestiaire and bestiaire:FindFirstChild("Inventaire")
	for _, name in { "Equipement", "Panneau", "Affichage", "Fond", "Emplacements" } do
		slots = slots and slots:WaitForChild(name, 10)
	end
	if not slots then
		return
	end
	for key, attribute in { rays = "AuraRays", sparkle = "AuraSparkle" } do
		local override = slots:GetAttribute(attribute)
		if typeof(override) == "string" and override ~= "" then
			images[key] = override
		end
	end
	local panel = bestiaire and bestiaire:FindFirstChild("Inventaire")
	panel = panel and panel:FindFirstChild("Equipement")
	panel = panel and panel:FindFirstChild("Panneau")
	anchor = if panel and panel:IsA("BasePart") then panel else nil

	for _, card in slots:GetChildren() do
		local index = tonumber(card.Name:match("^Item_(%d+)$"))
		if index then
			decorate(card, index)
		end
	end
	if #cards == 0 then
		return
	end

	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if anchor and camera and (camera.CFrame.Position - anchor.Position).Magnitude > DISTANCE_MAX then
			return
		end
		local now = os.clock()
		for _, entry in cards do
			if entry.rays then
				entry.rays.Rotation = (now * RAYS_SPEED + entry.phase * 90) % 360
			end
			for i, sparkle in entry.sparkles do
				sparkle.ImageTransparency = 0.4 + 0.4 * math.sin(now * 3 + i + entry.phase)
			end
		end
	end)
end

return VitrineRareteController
