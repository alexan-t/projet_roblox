--!strict
-- Disparition des unités vaincues (purement visuelle, côté client) — issue #16.
-- Le jeu est surtout en one-shot : pas d'animation de douleur. À la mort, l'unité :
--   1. s'éclaire d'un flash clair bref (le coup fatal se lit) ;
--   2. fait un petit sursaut (grossit un instant) en basculant légèrement en arrière ;
--   3. se dissout de haut en bas : chaque pièce s'efface en se tassant, pendant que des bouffées
--      de poussière (teinte de la créature) et quelques étincelles dorées s'élèvent.
-- Durée totale DURATION. CombatService retire le modèle 1,4 s après la mort (CORPSE_DELAY) : de quoi
-- jouer l'effet, même retardé jusqu'à l'impact d'un ultime.
-- API : DefeatEffectController.Play(model, delay?) -> fin de l'effet (s). delay : attente avant de
-- commencer (ex. ultime : l'ennemi disparaît quand l'onde l'atteint). Ne touche à aucune donnée de jeu :
-- tout est local (LocalTransparencyModifier, échelle et position vues par ce client).
-- Tag "ApercuDisparition" (Model, Studio) : démonstration en boucle sur une copie figée du modèle,
--   puis réapparition. Attribut optionnel ApercuPause (s entre deux disparitions).

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TAG_APERCU = "ApercuDisparition"
local DURATION = 0.85
local FLASH_TIME = 0.2 -- durée du flash
local POP_TIME = 0.1 -- montée du sursaut
local POP_SCALE = 1.07
local END_SCALE = 0.8
local TILT_DEGREES = 10 -- bascule vers l'arrière
local DISSOLVE_START = 0.18 -- première pièce (en haut)
local DISSOLVE_SPREAD = 0.42 -- décalage de la dernière pièce (en bas) : elle finit à DURATION
local PART_FADE = 0.25 -- durée d'effacement d'une pièce
local DUST_WAVES = 3

-- Couleurs : matière sable de la map (docs/UI_DESIGN_SYSTEM.md, palette relevée dans la map).
local SAND = Color3.fromHex("#E2D4B8")
local FLASH = Color3.fromHex("#FFF6E4")
local SPARK = Color3.fromHex("#F5CB5C")
local DUST_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local DefeatEffectController = {}

type Piece = { item: BasePart | Decal, start: number }

local function easeOut(x: number): number
	return 1 - (1 - x) ^ 3
end

local function easeIn(x: number): number
	return x ^ 3
end

-- Teinte moyenne des pièces visibles (pondérée par le volume), rapprochée du sable de la map.
local function dustColor(parts: { BasePart }): Color3
	local r, g, b, total = 0, 0, 0, 0
	for _, part in parts do
		local weight = part.Size.X * part.Size.Y * part.Size.Z
		r += part.Color.R * weight
		g += part.Color.G * weight
		b += part.Color.B * weight
		total += weight
	end
	if total <= 0 then
		return SAND
	end
	return Color3.new(r / total, g / total, b / total):Lerp(SAND, 0.35)
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local particles = Instance.new("ParticleEmitter")
	particles.Enabled = false
	particles.Shape = Enum.ParticleEmitterShape.Box
	particles.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	particles.EmissionDirection = Enum.NormalId.Top
	for key, value in props do
		(particles :: any)[key] = value
	end
	particles.Parent = parent
	return particles
end

-- Pièce invisible qui porte les particules : elle reste dans Workspace après la disparition du
-- modèle (retiré par le serveur), le temps que les dernières bouffées s'effacent.
local function particleHost(size: Vector3, color: Color3, height: number): (BasePart, ParticleEmitter, ParticleEmitter)
	local host = Instance.new("Part")
	host.Name = "DisparitionParticules"
	host.Anchored = true
	host.CanCollide, host.CanTouch, host.CanQuery = false, false, false
	host.Transparency = 1
	host.Size = size
	local base = math.clamp(height * 0.2, 0.7, 3.5)
	local dust = emitter(host, {
		Texture = DUST_TEXTURE,
		Color = ColorSequence.new(color),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, base * 0.6),
			NumberSequenceKeypoint.new(0.4, base),
			NumberSequenceKeypoint.new(1, base * 1.4),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.6, 0.5),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(0.6, 1.0),
		Speed = NumberRange.new(1.5, 3.5),
		SpreadAngle = Vector2.new(60, 60),
		Drag = 3,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-60, 60),
		LightEmission = 0.2,
	})
	local sparks = emitter(host, {
		Texture = SPARK_TEXTURE,
		Color = ColorSequence.new(SPARK),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, base * 0.5),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new(3, 6),
		SpreadAngle = Vector2.new(35, 35),
		Drag = 2,
		LightEmission = 1,
	})
	host.Parent = Workspace
	return host, dust, sparks
end

local run: (model: Model) -> ()

-- Lance la disparition de model, après delay secondes. Renvoie l'instant de fin (0 si rien à faire).
function DefeatEffectController.Play(model: Model, delay: number?): number
	if model:GetAttribute("EnDisparition") == true or not model.Parent then
		return 0
	end
	model:SetAttribute("EnDisparition", true)
	local startDelay = delay or 0
	if startDelay > 0 then
		task.delay(startDelay, run, model)
	else
		run(model)
	end
	return startDelay + DURATION
end

run = function(model: Model)
	if not model.Parent then
		return
	end

	local parts: { BasePart } = {}
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" and item.Transparency < 1 then
			table.insert(parts, item)
		end
	end
	if #parts == 0 then
		return
	end

	local box, size = model:GetBoundingBox()
	local height = math.max(size.Y, 0.5)
	local top = box.Position.Y + size.Y / 2
	local feet = Vector3.new(box.Position.X, box.Position.Y - size.Y / 2, box.Position.Z)
	local basePivot = model:GetPivot()
	local baseScale = model:GetScale()
	local tiltAxis = box.RightVector

	-- Ordre de dissolution : du haut vers le bas, de la pièce la plus haute (rang 0) à la plus
	-- basse (rang 1), pour que la dernière finisse avec l'effet.
	local highest, lowest = -math.huge, math.huge
	for _, part in parts do
		highest = math.max(highest, part.Position.Y)
		lowest = math.min(lowest, part.Position.Y)
	end
	local span = math.max(highest - lowest, 1e-3)
	local pieces: { Piece } = {}
	for _, part in parts do
		local rank = (highest - part.Position.Y) / span
		local start = DISSOLVE_START + DISSOLVE_SPREAD * rank
		table.insert(pieces, { item = part, start = start })
		for _, decal in part:GetChildren() do
			if decal:IsA("Decal") then
				table.insert(pieces, { item = decal, start = start })
			end
		end
	end

	local flash = Instance.new("Highlight")
	flash.Name = "DisparitionFlash"
	flash.Adornee = model
	flash.FillColor = FLASH
	flash.FillTransparency = 0.15
	flash.OutlineTransparency = 1
	flash.DepthMode = Enum.HighlightDepthMode.Occluded
	flash.Parent = model

	local host, dust, sparks = particleHost(Vector3.new(size.X, height / DUST_WAVES, size.Z), dustColor(parts), height)
	local volumeFactor = math.clamp(size.X * size.Z * height / 40, 1, 6)
	local nextWave = 1
	local sparked = false

	local startTime = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - startTime
		if not model.Parent then
			connection:Disconnect()
			return
		end

		flash.FillTransparency = 0.15 + 0.85 * math.clamp(t / FLASH_TIME, 0, 1)

		-- Sursaut puis tassement, autour des pieds, avec une légère bascule et un enfoncement.
		local scale = if t < POP_TIME
			then 1 + (POP_SCALE - 1) * easeOut(t / POP_TIME)
			else POP_SCALE + (END_SCALE - POP_SCALE) * easeIn(math.clamp((t - POP_TIME) / (DURATION - POP_TIME), 0, 1))
		local tilt = CFrame.fromAxisAngle(tiltAxis, math.rad(TILT_DEGREES) * easeOut(math.clamp(t / 0.35, 0, 1)))
		local sink = 0.12 * height * easeIn(math.clamp(t / DURATION, 0, 1))
		model:ScaleTo(baseScale * scale)
		local offset = tilt:VectorToWorldSpace((basePivot.Position - feet) * scale)
		model:PivotTo(CFrame.new(feet + offset - Vector3.new(0, sink, 0)) * tilt * basePivot.Rotation)

		for _, piece in pieces do
			piece.item.LocalTransparencyModifier = math.clamp((t - piece.start) / PART_FADE, 0, 1)
		end

		-- Poussière par bandes, du haut vers le bas, au rythme de la dissolution.
		if nextWave <= DUST_WAVES and t >= DISSOLVE_START + DISSOLVE_SPREAD * (nextWave - 1) / (DUST_WAVES - 1) then
			local bandY = top - height * (nextWave - 0.5) / DUST_WAVES - sink
			host.CFrame = CFrame.new(box.Position.X, bandY, box.Position.Z)
			-- la dernière bande, au sol, est la plus fournie : elle masque le bas qui s'efface
			dust:Emit(math.floor((if nextWave == DUST_WAVES then 8 else 5) * volumeFactor))
			nextWave += 1
		end
		if not sparked and t >= DISSOLVE_START then
			sparked = true
			sparks:Emit(10 + math.floor(3 * volumeFactor))
		end

		if t >= DURATION then
			connection:Disconnect()
			for _, piece in pieces do
				piece.item.LocalTransparencyModifier = 1
			end
			flash:Destroy()
		end
	end)
	task.delay(DURATION + 1.2, function()
		host:Destroy()
	end)
end

-- Copie figée (pose du moment, sans squelette ni animation) pour la démonstration.
local function frozenCopy(model: Model): Model
	local wasArchivable = model.Archivable
	model.Archivable = true
	local copy = model:Clone()
	model.Archivable = wasArchivable
	for _, item in copy:GetDescendants() do
		if item:IsA("JointInstance") or item:IsA("AnimationController") or item:IsA("Humanoid") or item:IsA("LuaSourceContainer") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored = true
		end
	end
	for _, tag in CollectionService:GetTags(copy) do
		CollectionService:RemoveTag(copy, tag)
	end
	copy:SetAttribute("EnDisparition", nil)
	copy.Parent = model.Parent
	return copy
end

local function setHidden(model: Model, hidden: boolean)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") or item:IsA("Decal") then
			item.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

local function runDemo(model: Model)
	while model.Parent and CollectionService:HasTag(model, TAG_APERCU) do
		local pause = model:GetAttribute("ApercuPause")
		task.wait(if typeof(pause) == "number" then pause else 1.6)
		if not model.Parent then
			break
		end
		local copy = frozenCopy(model)
		setHidden(model, true)
		task.wait(DefeatEffectController.Play(copy) + 0.6)
		copy:Destroy()
		setHidden(model, false)
	end
end

function DefeatEffectController:Start()
	if not RunService:IsStudio() then
		return
	end
	for _, model in CollectionService:GetTagged(TAG_APERCU) do
		if model:IsA("Model") then
			task.spawn(runDemo, model)
		end
	end
	CollectionService:GetInstanceAddedSignal(TAG_APERCU):Connect(function(model)
		if model:IsA("Model") then
			task.spawn(runDemo, model)
		end
	end)
end

return DefeatEffectController
