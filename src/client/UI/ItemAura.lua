--!strict
-- Aura de rareté d'un item 2D (docs/ITEMS.md § 7) : fond teinté de la couleur de rareté,
-- reflet qui balaie le fond, puis, selon le rang, halo qui respire, rayons qui tournent, éclats qui
-- scintillent et particules en orbite. Réglages : ItemAuraConfig ; couleurs : RarityStyle (UITheme).
-- Items seulement : les monstres et les ressources n'ont aucune rareté.
--
-- Tout est posé dans la case de l'icône (target), qui reste à sa place dans sa mise en page :
--   Aura (halo, rayons, déborde) < Fond (teinte, contour, reflet) < contenu existant < Eclats.
-- Une seule boucle RenderStepped pour toutes les auras ; une aura s'arrête avec sa case.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.ItemAuraConfig)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local RarityStyle = require(script.Parent.RarityStyle)
local UIKit = require(script.Parent.UIKit)

local C = UITheme.Colors

local ItemAura = {}

export type Options = {
	-- 0..1 : part du débordement (halo, rayons, orbite) ; par défaut resserré sous Config.Compact px.
	Spread: number?,
}

------------------------------------------------------------------ boucle commune

local active: { [GuiObject]: (now: number) -> () } = {}
local removers: { [GuiObject]: () -> () } = setmetatable({}, { __mode = "k" }) :: any
local loop: RBXScriptConnection? = nil

local function step()
	local now = os.clock()
	for target, update in active do
		if target.Parent then
			update(now)
		end
	end
end

local function track(target: GuiObject, update: (now: number) -> ())
	active[target] = update
	if not loop then
		loop = RunService.RenderStepped:Connect(step)
	end
end

local function untrack(target: GuiObject)
	active[target] = nil
	if next(active) == nil and loop then
		loop:Disconnect()
		loop = nil
	end
end

------------------------------------------------------------------ couches

local function layer(parent: Instance, name: string, z: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = z
	frame.Parent = parent
	return frame
end

local function square(object: GuiObject)
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.Parent = object
end

local function centered(parent: Instance, name: string, scale: number): Frame
	local frame = layer(parent, name, 1)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(scale, scale)
	return frame
end

-- Trait plein au centre, effacé aux bouts (rayon ou branche d'éclat). Sans image : rien à charger.
local function beam(parent: Instance, size: UDim2, position: UDim2, anchor: Vector2, fade: NumberSequence, rotation: number): Frame
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	frame.AnchorPoint = anchor
	frame.Position = position
	frame.Size = size
	frame.Parent = parent
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation
	gradient.Transparency = fade
	gradient.Parent = frame
	return frame
end

-- Couronne de rayons qui part du centre (même dessin que UIKit.rays, mais à l'échelle de la case).
local RAY_FADE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.6, 0.6),
	NumberSequenceKeypoint.new(1, 0.25),
})
local function rayCrown(parent: Instance, name: string, scale: number, count: number): (Frame, { Frame })
	local holder = centered(parent, name, scale)
	square(holder)
	local beams = {}
	for i = 1, count do
		local arm = layer(holder, `Bras{i}`, 1)
		arm.Rotation = (i - 1) * 360 / count
		local width = if i % 2 == 0 then 0.07 else 0.11
		table.insert(beams, beam(arm, UDim2.fromScale(width, 0.5), UDim2.fromScale(0.5, 0), Vector2.new(0.5, 0), RAY_FADE, 90))
	end
	return holder, beams
end

-- Éclat à quatre branches (croix fine qui scintille).
local GLINT_FADE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(1, 1),
})
local function glint(parent: Instance, name: string, scale: number): (Frame, { Frame })
	local holder = centered(parent, name, scale)
	square(holder)
	local center = UDim2.fromScale(0.5, 0.5)
	local mid = Vector2.new(0.5, 0.5)
	return holder, {
		beam(holder, UDim2.fromScale(1, 0.14), center, mid, GLINT_FADE, 0),
		beam(holder, UDim2.fromScale(0.14, 1), center, mid, GLINT_FADE, 90),
	}
end

-- Éclats autour de l'icône (coins d'abord, puis milieux des bords), en fraction de la case.
local SPARKLES = {
	Vector2.new(-0.06, -0.06), Vector2.new(1.04, 0.16), Vector2.new(0.1, 1.04), Vector2.new(0.98, 0.98),
	Vector2.new(0.5, -0.14), Vector2.new(-0.14, 0.56), Vector2.new(1.12, 0.62), Vector2.new(0.58, 1.12),
}

local function spreadOf(target: GuiObject, options: Options?): number
	if options and options.Spread then
		return math.clamp(options.Spread, 0, 1)
	end
	local size = if target.AbsoluteSize.X > 0 then target.AbsoluteSize.X else target.Size.X.Offset
	return if size > 0 and size < Config.Compact then Config.CompactSpread else 1
end

------------------------------------------------------------------ API

-- Pose l'aura de la rareté `rarity` (Id de RarityConfig) sur la case `target` d'une icône d'item.
-- Remplace une aura déjà posée. Renvoie une fonction qui la retire.
function ItemAura.apply(target: GuiObject, rarity: string?, options: Options?): () -> ()
	ItemAura.remove(target)
	local aura = Config.forRarity(rarity)
	local prism = RarityStyle.prismatic(rarity)
	local dark = aura.Dark == 1
	local color = RarityStyle.color(rarity)
	local shine = if dark then UITheme.Rarity.Epique else color:Lerp(C.Cream, 0.45)
	local spread = spreadOf(target, options)
	local reach = 1 + (aura.Reach - 1) * spread

	-- le contenu existant passe au-dessus du fond et de l'aura
	local low, high = math.huge, 1
	for _, child in target:GetChildren() do
		if child:IsA("GuiObject") then
			low, high = math.min(low, child.ZIndex), math.max(high, child.ZIndex)
		end
	end
	if low == math.huge then
		low = 1
	end
	for _, item in target:GetDescendants() do
		if item:IsA("GuiObject") then
			item.ZIndex += 2
		end
	end

	-- fond : la case devient transparente, la teinte et le contour passent sur la couche Fond
	local corner = target:FindFirstChildOfClass("UICorner")
	local radius = if corner then corner.CornerRadius else UITheme.Radius.Small
	local oldStroke = target:FindFirstChildOfClass("UIStroke")
	local saved = { Transparency = target.BackgroundTransparency, Stroke = oldStroke and oldStroke.Enabled }
	target.BackgroundTransparency = 1
	if oldStroke then
		oldStroke.Enabled = false
	end

	local back = layer(target, "Aura", low)
	local fill = layer(target, "Fond", low + 1)
	fill.BackgroundColor3 = color
	fill.BackgroundTransparency = aura.Fill
	UIKit.corner(fill, radius)
	local stroke = UIKit.stroke(fill, aura.Stroke, if dark then C.Ink else color)
	if prism then
		RarityStyle.paint(fill, rarity)
		RarityStyle.paint(stroke, rarity)
	else
		local shade = Instance.new("UIGradient")
		shade.Rotation = 90
		local bottom = if dark then Config.Shade * 0.5 else Config.Shade
		shade.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(bottom, bottom, bottom))
		shade.Parent = fill
	end

	local sheen = layer(fill, "Reflet", 1)
	sheen.BackgroundTransparency = 0
	sheen.BackgroundColor3 = C.Cream
	UIKit.corner(sheen, radius)
	local band = Instance.new("UIGradient")
	band.Rotation = 20
	band.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.5, if dark then 0.75 else Config.SheenAlpha),
		NumberSequenceKeypoint.new(0.58, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	band.Offset = Vector2.new(1, 0)
	band.Parent = sheen

	-- halo : anneaux arrondis qui respirent, du plus large (derrière) au plus serré
	local rings: { Frame } = {}
	for k = aura.Halo, 1, -1 do
		local ring = centered(back, `Halo{k}`, 1 + (reach - 1) * k / aura.Halo)
		ring.BackgroundTransparency = Config.HaloInner + (Config.HaloOuter - Config.HaloInner) * k / aura.Halo
		ring.BackgroundColor3 = if dark and k > 1 then C.Ink else color
		ring.ZIndex = aura.Halo - k + 2
		UIKit.corner(ring, UDim.new(0.35, 0))
		rings[k] = ring
	end

	-- rayons : derrière le halo ; la seconde couche tourne en sens inverse
	local rays: { Frame } = {}
	local rayBeams: { { Frame } } = {}
	for k = 1, aura.Rays do
		local ray, beams = rayCrown(back, `Rayons{k}`, (reach + 0.6 * spread) * (if k == 1 then 1 else 0.82), if k == 1 then 10 else 14)
		ray.ZIndex = 1
		for _, b in beams do
			b.BackgroundColor3 = if dark then C.Ink else color
			b.BackgroundTransparency = Config.RayAlpha[k]
		end
		rays[k], rayBeams[k] = ray, beams
	end

	-- éclats et particules : au-dessus de l'icône
	local front = layer(target, "Eclats", high + 3)
	local sparkles: { Frame } = {}
	local sparkleBars: { { Frame } } = {}
	for i = 1, math.min(aura.Sparkles, #SPARKLES) do
		local sparkle, bars = glint(front, `Eclat{i}`, if i == 1 then 0.34 else 0.24)
		sparkle.Position = UDim2.fromScale(SPARKLES[i].X, SPARKLES[i].Y)
		for _, bar in bars do
			bar.BackgroundColor3 = shine
		end
		sparkles[i], sparkleBars[i] = sparkle, bars
	end
	local motes: { Frame } = {}
	for i = 1, aura.Motes do
		local mote = centered(front, `Particule{i}`, 0.09)
		mote.BackgroundTransparency = 0.15
		mote.BackgroundColor3 = shine
		UIKit.corner(mote, UDim.new(0.5, 0))
		square(mote)
		motes[i] = mote
	end

	local orbit = 0.5 * reach + 0.04
	local orbitSpeed = math.max(aura.Spin / 30, 0.8)
	local phase = math.random() * 10 -- les cartes voisines ne battent pas à l'unisson
	track(target, function(clock: number)
		local now = clock + phase
		local sweep = (now % aura.Sheen) / aura.Sheen
		band.Offset = Vector2.new(math.clamp(sweep / 0.4, 0, 1) * 2 - 1, 0)
		for k, ring in rings do
			local wave = if aura.Pulse > 0 then math.sin(now * 2 * math.pi / aura.Pulse + k * 0.6) else 0
			local size = (1 + (reach - 1) * k / aura.Halo) * (1 + Config.PulseAmount * wave)
			ring.Size = UDim2.fromScale(size, size)
			ring.BackgroundTransparency = Config.HaloInner + (Config.HaloOuter - Config.HaloInner) * k / aura.Halo - 0.05 * wave
			if prism then
				ring.BackgroundColor3 = RarityStyle.colorAt(rarity, now + k * 0.4)
			end
		end
		for k, ray in rays do
			ray.Rotation = (now * aura.Spin * (if k == 1 then 1 else -0.6)) % 360
			if prism then
				for j, b in rayBeams[k] do
					b.BackgroundColor3 = RarityStyle.colorAt(rarity, now + k + j * 0.3)
				end
			end
		end
		for i, sparkle in sparkles do
			local twinkle = 0.5 + 0.5 * math.sin(now * 3 + i * 1.9)
			sparkle.Rotation = (now * 40 + i * 30) % 360
			for _, bar in sparkleBars[i] do
				bar.BackgroundTransparency = 0.85 * twinkle
				if prism then
					bar.BackgroundColor3 = RarityStyle.colorAt(rarity, now + i * 0.5)
				end
			end
		end
		for i, mote in motes do
			local angle = now * orbitSpeed + i * 2 * math.pi / #motes
			mote.Position = UDim2.fromScale(0.5 + math.cos(angle) * orbit, 0.5 + math.sin(angle) * orbit * 0.85)
			if prism then
				mote.BackgroundColor3 = RarityStyle.colorAt(rarity, now + i * 0.5)
			end
		end
	end)

	local destroying = target.Destroying:Connect(function()
		removers[target] = nil
		untrack(target)
	end)
	local function remove()
		destroying:Disconnect()
		untrack(target)
		for _, layerFrame in { back, fill, front } do
			layerFrame:Destroy()
		end
		for _, item in target:GetDescendants() do
			if item:IsA("GuiObject") then
				item.ZIndex -= 2
			end
		end
		target.BackgroundTransparency = saved.Transparency
		if oldStroke and saved.Stroke ~= nil then
			oldStroke.Enabled = saved.Stroke
		end
		target:SetAttribute("AuraRarete", nil)
	end
	target:SetAttribute("AuraRarete", rarity or "Commun")
	removers[target] = remove
	return remove
end

-- Retire l'aura posée sur `target` (sans effet s'il n'y en a pas).
function ItemAura.remove(target: GuiObject)
	local remove = removers[target]
	if remove then
		removers[target] = nil
		remove()
	end
end

return ItemAura
