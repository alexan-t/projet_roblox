--!strict
-- Transposition de HeroCard.dc.html : cadre PNG original, portrait et plaque aux coordonnées du ZIP.
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Assets = require(RS.Shared.Config.InvocationVisualConfig)
local Theme = require(RS.Shared.Config.UITheme)
local UIKit = require(script.Parent.UIKit)
local Rarity = require(script.Parent.RarityStyle)
local HeroCard = {}

function HeroCard.image(parent: Instance, key: string, size: UDim2, position: UDim2?): ImageLabel
	local image = Instance.new("ImageLabel")
	image.Name = key
	image.BackgroundTransparency = 1
	image.Size = size
	image.Position = position or UDim2.new()
	image.Image = (Assets :: any)[key] or key
	image.ScaleType = Enum.ScaleType.Fit
	image.Parent = parent
	return image
end

function HeroCard.new(parent: Instance, hero: any, width: number, options: any?): Frame
	local opts = options or {}
	local rank = Rarity.rank(hero.Rarity)
	local root = Instance.new("Frame")
	root.Name = "HeroCard_" .. (hero.HeroId or hero.Name or "Hero")
	root.Size = UDim2.fromOffset(width, width * 266 / 200)
	root.BackgroundTransparency = 1
	root.Parent = parent
	local fx = opts.Effects ~= false and width >= 100
	local rays: ImageLabel? = nil
	if fx and rank >= 5 then
		rays = HeroCard.image(root, "rays", UDim2.fromScale(1.8, 1.4), UDim2.fromScale(.5, .44))
		rays.AnchorPoint = Vector2.new(.5, .5)
		rays.ImageColor3 = if rank == 7 then Theme.Colors.Ink else Rarity.color(hero.Rarity)
		rays.ImageTransparency = .3
	end
	local frame = HeroCard.image(root, "card_frame_" .. rank, UDim2.fromScale(1, 1))
	frame.ZIndex = 2
	local portrait = Instance.new("Frame")
	portrait.Name = "Portrait"
	portrait.Position, portrait.Size = UDim2.fromScale(.095, 25/266), UDim2.fromScale(.81, 165/266)
	portrait.BackgroundTransparency = 1
	portrait.ClipsDescendants = true
	portrait.ZIndex = 3
	portrait.Parent = root
	if hero.Model then
		local viewport = UIKit.portrait(portrait, hero.Model, true)
		viewport.ZIndex = 3
	else
		local sil = HeroCard.image(portrait, "hero_placeholder", UDim2.fromScale(.84, 1), UDim2.fromScale(.08, .05))
		sil.ImageTransparency = .58
		sil.ZIndex = 3
	end
	local font = if width >= 190 then 19 elseif width >= 130 then 14 else 11
	local name = UIKit.text(root, hero.Name or "", font)
	name.Name = "Nom"
	name.TextWrapped = true
	name.Position, name.Size = UDim2.fromScale(.08, .735), UDim2.fromScale(.84, .17)
	name.ZIndex = 4
	name.Visible = width >= 70 -- variante xs de HeroCard.dc.html : vignette sans nom
	if width >= 130 then
		local rarity = UIKit.text(root, string.upper(Rarity.name(hero.Rarity)), if width >= 190 then 14 else 12)
		rarity.Position, rarity.Size = UDim2.fromScale(.06, .902), UDim2.fromScale(.88, .06)
		rarity.ZIndex = 4
		Rarity.paint(rarity, hero.Rarity)
	end
	if hero.New then
		local badge = UIKit.badge(root, "NOUVEAU", Theme.Colors.RoyalRed)
		badge.Position = UDim2.fromScale(.04, -.025)
		badge.ZIndex = 6
	end
	if (hero.Count or 1) > 1 then
		local badge = UIKit.badge(root, "×" .. hero.Count, Theme.Colors.WoodDeep)
		badge.AnchorPoint = Vector2.new(1, 1)
		badge.Position = UDim2.fromScale(1.04, 1.02)
		badge.ZIndex = 6
	end
	local sparkles = {}
	if fx and rank >= 4 then
		for i, pos in { Vector2.new(.08,.12), Vector2.new(.76,.26), Vector2.new(.16,.50), Vector2.new(.70,.04) } do
			if i > math.min(4, rank - 2) then break end
			local sparkle = HeroCard.image(root, "sparkle", UDim2.fromOffset(if i == 1 then 22 else 12, if i == 1 then 22 else 12), UDim2.fromScale(pos.X,pos.Y))
			sparkle.ZIndex = 5
			sparkle.ImageColor3 = if rank >= 8 then Theme.Colors.CurrencyGems elseif rank == 7 then Theme.Rarity.Epique else Theme.Colors.GoldLight
			table.insert(sparkles, sparkle)
		end
	end
	if rays or #sparkles > 0 then
		local connection: RBXScriptConnection
		connection = RunService.RenderStepped:Connect(function()
			local now = os.clock()
			if rays then rays.Rotation = now * 20 % 360 end
			for i, sparkle in sparkles do sparkle.ImageTransparency = .4 + .4 * math.sin(now * 3 + i) end
		end)
		root.Destroying:Connect(function() connection:Disconnect() end)
	end
	return root
end

return HeroCard
