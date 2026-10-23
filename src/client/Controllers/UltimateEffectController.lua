--!strict
-- Effets des ultimes (purement visuels, côté client) — issue #16, brief docs/ultimes/ULTIMES.md.
-- Chaque héros choisit son effet par l'attribut texte « EffetUltime » de son modèle de combat
-- (RempartFerme, DernierCarreau) ; l'instant du coup est l'attribut Impact de sa séquence « Ultime ».
-- Sans attribut : « Charge du Rempart », décrite ci-dessous.
-- Le héros joue son animation « Ultime » (MonsterAnimationController) ; cet effet l'accompagne :
--   1. lueur dorée sur le héros et étincelles qui montent pendant qu'il se ramasse ;
--   2. à l'impact de l'animation (ANIMATION_IMPACT), une lame d'énergie dorée part de l'épée et
--      file vers la cible (TRAVEL_TIME) ;
--   3. elle explose en anneau doré au sol, du rayon de la zone touchée, avec un éclair de lumière,
--      des étincelles et une bouffée de poussière dorée.
-- Le serveur a déjà appliqué les dégâts : CombatViewController retarde de IMPACT_DELAY les chiffres
-- de dégâts et la disparition des ennemis touchés pour qu'ils tombent avec l'anneau.
-- API : UltimateEffectController.Play(caster, center, radius, speed?) ; ImpactDelay(speed?, caster?) :
-- instant réel où le coup touche (impact de l'animation + trajet de l'effet, divisé par la vitesse).
-- Tag "ApercuUltime" (Model riggé, Studio) : démonstration en boucle, cible à 10 studs devant lui.
--   Attribut optionnel ApercuPause (s entre deux ultimes).

local CollectionService = game:GetService("CollectionService")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AnimationSets = require(ReplicatedStorage.Shared.Animation.AnimationSets)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local AudioController = require(script.Parent.AudioController)

local TAG_APERCU = "ApercuUltime"
-- Instant du coup dans l'animation « Ultime » (style Rempart de tools/animation/AnimationKit.luau).
local ANIMATION_IMPACT = 0.3
local TRAVEL_TIME = 0.15
local RING_TIME = 0.45
local RING_SEGMENTS = 24
local DEFAULT_RADIUS = 8 -- CombatConfig.Ultimate.Radius (le client ne lit pas la config serveur)

-- Couleurs : or des emblèmes de la map (docs/UI_DESIGN_SYSTEM.md).
local GOLD = Color3.fromHex("#E6B23A")
local GOLD_LIGHT = Color3.fromHex("#F5CB5C")
local CREAM = Color3.fromHex("#FFF6E4")
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local DUST_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local UltimateEffectController = {}

UltimateEffectController.IMPACT_DELAY = ANIMATION_IMPACT + TRAVEL_TIME

-- Trajet (s, à x1) entre l'impact de l'animation et le coup sur la cible, par effet.
local SHIELD_TRAVEL = 0.15
local BOLT_TRAVEL = 0.12
local TRAVEL: { [string]: number } = { Rempart = TRAVEL_TIME, RempartFerme = SHIELD_TRAVEL, DernierCarreau = BOLT_TRAVEL }

local function effectOf(caster: Model?): string
	local name = caster and caster:GetAttribute("EffetUltime")
	return if typeof(name) == "string" and TRAVEL[name] then name else "Rempart"
end

-- Instant du coup dans l'animation « Ultime » du héros (attribut Impact de la séquence).
local function impactOf(caster: Model?): number
	local sequence = caster and AnimationSets.find(caster, "Ultime", true)
	local impact = sequence and sequence:GetAttribute("Impact")
	return if typeof(impact) == "number" then impact else ANIMATION_IMPACT
end

function UltimateEffectController.ImpactDelay(speed: number?, caster: Model?): number
	if not caster then
		return UltimateEffectController.IMPACT_DELAY / (speed or 1)
	end
	return (impactOf(caster) + TRAVEL[effectOf(caster)]) / (speed or 1)
end

local function effectPart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = Workspace
	return part
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local particles = Instance.new("ParticleEmitter")
	particles.Enabled = false
	for key, value in props do
		(particles :: any)[key] = value
	end
	particles.Parent = parent
	return particles
end

local function sparkEmitter(parent: Instance, size: number, speed: NumberRange): ParticleEmitter
	return emitter(parent, {
		Texture = SPARK_TEXTURE,
		Color = ColorSequence.new(GOLD_LIGHT),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.4, 0.8),
		Speed = speed,
		SpreadAngle = Vector2.new(40, 40),
		EmissionDirection = Enum.NormalId.Top,
		Drag = 2,
		LightEmission = 1,
	})
end

-- Point de départ de la lame : l'arme tenue en main droite (os ArmeDroite du squelette commun,
-- sinon d'après le nom de la pièce), sinon le bras droit.
local function weaponPosition(caster: Model, fallback: Vector3): Vector3
	local held = AnimationSets.pieces(caster, "ArmeDroite")
	if #held > 0 then
		return held[1].Position
	end
	for _, item in caster:GetDescendants() do
		if item:IsA("BasePart") then
			local name = string.lower(item.Name)
			if string.find(name, "sword", 1, true) or string.find(name, "epee", 1, true) or string.find(name, "weapon", 1, true) or string.find(name, "blade", 1, true) then
				return item.Position
			end
		end
	end
	local arm = caster:FindFirstChild("right_arm_geom", true)
	return if arm and arm:IsA("BasePart") then arm.Position else fallback
end

-- 1. Lueur sur le héros pendant qu'il se ramasse.
local function aura(caster: Model, box: CFrame, size: Vector3, speed: number, impact: number)
	local glow = Instance.new("Highlight")
	glow.Name = "UltimeLueur"
	glow.Adornee = caster
	glow.FillColor = GOLD_LIGHT
	glow.OutlineColor = GOLD
	glow.FillTransparency = 0.55
	glow.OutlineTransparency = 0.1
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Parent = caster
	local fade = TweenInfo.new(0.55 / speed, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, impact * 0.6 / speed)
	TweenService:Create(glow, fade, { FillTransparency = 1, OutlineTransparency = 1 }):Play()
	task.delay((impact + 0.7) / speed, function()
		glow:Destroy()
	end)
	local host = effectPart({ Transparency = 1, Size = Vector3.new(size.X, 0.2, size.Z), CFrame = box * CFrame.new(0, -size.Y / 2, 0) })
	sparkEmitter(host, 0.5, NumberRange.new(3, 6)):Emit(14)
	task.delay(1.5, function()
		host:Destroy()
	end)
end

-- 2 et 3. Lame qui file de l'épée vers le centre, puis anneau au sol.
local function wave(from: Vector3, center: Vector3, radius: number, speed: number)
	local travel = TRAVEL_TIME / speed
	local direction = center - from
	local flat = Vector3.new(direction.X, 0, direction.Z)
	local look = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
	local blade = effectPart({
		Name = "UltimeLame",
		Color = GOLD_LIGHT,
		Transparency = 0.15,
		Size = Vector3.new(2.4, 0.25, 1.2),
		CFrame = CFrame.lookAt(from, from + look),
	})
	local trail = sparkEmitter(blade, 0.35, NumberRange.new(0.5, 1.5))
	trail.Rate = 120
	trail.Enabled = true
	TweenService:Create(blade, TweenInfo.new(travel, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		CFrame = CFrame.lookAt(center + Vector3.new(0, 0.6, 0), center + Vector3.new(0, 0.6, 0) + look),
		Size = Vector3.new(3.2, 0.25, 1.6),
	}):Play()
	task.delay(travel, function()
		trail.Enabled = false
		blade.Transparency = 1
		task.delay(0.8, function()
			blade:Destroy()
		end)

		-- Anneau doré : un cercle de segments qui s'élargit jusqu'au rayon de la zone touchée, reste
		-- bien visible puis s'efface sur la fin ; disque clair au centre, plus bref.
		local flatCylinder = CFrame.Angles(0, 0, math.rad(90))
		local ground = center + Vector3.new(0, 0.12, 0)
		local segments: { BasePart } = {}
		for i = 1, RING_SEGMENTS do
			segments[i] = effectPart({ Name = "UltimeAnneau", Color = GOLD, Transparency = 0.05, Size = Vector3.new(0.4, 0.2, 0.35) })
		end
		local disc = effectPart({ Name = "UltimeDisque", Shape = Enum.PartType.Cylinder, Color = CREAM, Transparency = 0.35, Size = Vector3.new(0.1, 1, 1), CFrame = CFrame.new(ground) * flatCylinder })
		TweenService:Create(disc, TweenInfo.new(RING_TIME * 0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.1, radius * 1.2, radius * 1.2), Transparency = 1 }):Play()
		local ringStart = os.clock()
		local ringLoop: RBXScriptConnection
		ringLoop = RunService.RenderStepped:Connect(function()
			local progress = math.clamp((os.clock() - ringStart) / RING_TIME, 0, 1)
			local r = math.max(0.5, radius * (1 - (1 - progress) ^ 4))
			local alpha = if progress < 0.55 then 0.05 else 0.05 + 0.95 * (progress - 0.55) / 0.45
			local length = 2 * math.pi * r / RING_SEGMENTS * 1.05 -- segments jointifs : une onde continue
			for i, segment in segments do
				local angle = 2 * math.pi * i / RING_SEGMENTS
				local offset = Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
				segment.Size = Vector3.new(length, 0.2, 0.5)
				segment.CFrame = CFrame.lookAt(ground + offset, ground) -- X (longueur) tangent au cercle
				segment.Transparency = alpha
			end
			if progress >= 1 then
				ringLoop:Disconnect()
				for _, segment in segments do
					segment:Destroy()
				end
			end
		end)

		local light = Instance.new("PointLight")
		light.Color = GOLD_LIGHT
		light.Range = radius * 2
		light.Brightness = 4
		light.Parent = disc
		TweenService:Create(light, TweenInfo.new(RING_TIME), { Brightness = 0 }):Play()

		local host = effectPart({ Transparency = 1, Shape = Enum.PartType.Block, Size = Vector3.new(radius * 1.4, 0.2, radius * 1.4), CFrame = CFrame.new(center) })
		emitter(host, {
			Texture = DUST_TEXTURE,
			Color = ColorSequence.new(GOLD_LIGHT:Lerp(CREAM, 0.5)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(0.5, 0.9),
			Speed = NumberRange.new(2, 4),
			SpreadAngle = Vector2.new(70, 70),
			EmissionDirection = Enum.NormalId.Top,
			Drag = 3,
			Shape = Enum.ParticleEmitterShape.Box,
			LightEmission = 0.3,
		}):Emit(math.floor(6 + radius))
		sparkEmitter(host, 0.6, NumberRange.new(5, 10)):Emit(math.floor(14 + radius * 2))

		task.delay(RING_TIME + 1.2, function()
			disc:Destroy()
			host:Destroy()
		end)
	end)
end

local WOOD = Color3.fromHex("#6B4426")

-- Bouffée au sol : poussière claire et éclats (fin d'un choc, impact d'un carreau).
local function puff(at: Vector3, color: Color3, amount: number)
	local host = effectPart({ Transparency = 1, Size = Vector3.new(1.5, 0.2, 1.5), CFrame = CFrame.new(at) })
	emitter(host, {
		Texture = DUST_TEXTURE,
		Color = ColorSequence.new(color),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.8) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.35, 0.6),
		Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(60, 60),
		EmissionDirection = Enum.NormalId.Top,
		Drag = 4,
	}):Emit(amount)
	sparkEmitter(host, 0.35, NumberRange.new(4, 8)):Emit(amount)
	task.delay(1, function()
		host:Destroy()
	end)
end

-- 01 Écuyer « Rempart Fermé » : un choc court en forme d'écu (rectangle + pointe) part du bouclier
-- planté et frappe devant lui, quelques studs seulement, puis s'efface.
local function shieldShock(caster: Model, center: Vector3, speed: number)
	local box, size = caster:GetBoundingBox()
	local feet = box.Position - Vector3.new(0, size.Y / 2, 0)
	local toward = Vector3.new(center.X - feet.X, 0, center.Z - feet.Z)
	local look = if toward.Magnitude > 1e-3 then toward.Unit else caster:GetPivot().LookVector
	local start = feet + look * 1.4 + Vector3.new(0, math.max(1.2, size.Y * 0.32), 0)
	local finish = start + look * math.clamp(toward.Magnitude - 1.5, 2, 5)
	local top = effectPart({ Name = "UltimeEcu", Color = GOLD_LIGHT, Transparency = 0.25, Size = Vector3.new(2, 1.2, 0.15) })
	local tip = effectPart({ Name = "UltimeEcuPointe", Color = GOLD_LIGHT, Transparency = 0.25, Size = Vector3.new(1.42, 1.42, 0.15) })
	local travel = SHIELD_TRAVEL / speed
	local fade = 0.2 / speed
	local started = os.clock()
	local loop: RBXScriptConnection
	loop = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		local eased = 1 - (1 - math.clamp(t / travel, 0, 1)) ^ 2
		local scale = 1 + 0.35 * eased
		local at = start:Lerp(finish, eased)
		local frame = CFrame.lookAt(at, at + look)
		top.Size = Vector3.new(2 * scale, 1.2 * scale, 0.15)
		top.CFrame = frame * CFrame.new(0, 0.35 * scale, 0)
		tip.Size = Vector3.new(1.42 * scale, 1.42 * scale, 0.15)
		tip.CFrame = frame * CFrame.new(0, -0.25 * scale, 0) * CFrame.Angles(0, 0, math.rad(45))
		local alpha = if t <= travel then 0.25 else 0.25 + 0.75 * math.clamp((t - travel) / fade, 0, 1)
		top.Transparency, tip.Transparency = alpha, alpha
		if t >= travel + fade then
			loop:Disconnect()
			top:Destroy()
			tip:Destroy()
		end
	end)
	task.delay(travel, function()
		puff(Vector3.new(finish.X, feet.Y + 0.1, finish.Z), CREAM, 8)
	end)
end

-- 02 Tireuse « Le Dernier Carreau » : un carreau lourd part de l'arbalète et traverse la cible (tir
-- perforant) en laissant une fine traînée tendue ; éclats de bois à l'impact.
local function heavyBolt(caster: Model, center: Vector3, speed: number)
	local box = caster:GetBoundingBox()
	local from = weaponPosition(caster, box.Position)
	local target = center + Vector3.new(0, 1.2, 0)
	local direction = target - from
	if direction.Magnitude < 1e-3 then
		return
	end
	local finish = target + direction.Unit * 3
	local bolt = effectPart({ Name = "UltimeCarreau", Material = Enum.Material.Wood, Color = WOOD, Size = Vector3.new(0.16, 0.16, 1.4), CFrame = CFrame.lookAt(from, target) })
	local tail1 = Instance.new("Attachment")
	tail1.Position = Vector3.new(0, 0.05, 0.7)
	tail1.Parent = bolt
	local tail2 = Instance.new("Attachment")
	tail2.Position = Vector3.new(0, -0.05, 0.7)
	tail2.Parent = bolt
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = tail1, tail2
	trail.Color = ColorSequence.new(CREAM)
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	trail.Lifetime = 0.3 / speed
	trail.LightEmission = 0.6
	trail.FaceCamera = true
	trail.Parent = bolt
	local travel = BOLT_TRAVEL / speed
	local through = travel * (direction.Magnitude + 3) / direction.Magnitude
	TweenService:Create(bolt, TweenInfo.new(through, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(finish, finish + direction.Unit) }):Play()
	task.delay(travel, function()
		puff(target, WOOD:Lerp(CREAM, 0.5), 10)
	end)
	task.delay(through + 0.05, function()
		bolt.Transparency = 1
		task.delay(0.4, function()
			bolt:Destroy()
		end)
	end)
end

-- Lance l'effet. caster : modèle du héros ; center : point AU SOL au centre de la zone touchée ;
-- radius : rayon de l'anneau (studs). Renvoie IMPACT_DELAY (instant où l'anneau éclate).
-- Annonce « ce héros lance son ultime » (en plus de son animation et de l'onde) : capte l'attention
-- sur le lanceur, pas sur la cible.
--   - « ULTIME ! » au-dessus du héros (Fredoka Title, GoldLight, contour Ink Large) : rebond, tenue,
--     puis montée et fondu ;
--   - colonne de lumière dorée qui jaillit du héros et se resserre ;
--   - onde dorée au sol qui s'élargit sous ses pieds, avec un éclair de lumière.
function UltimateEffectController.Announce(caster: Model, speed: number?)
	local rate = speed or 1
	local box, bounds = caster:GetBoundingBox()
	local size: any = bounds
	local feet = box.Position - Vector3.new(0, size.Y / 2, 0)
	local typography = UITheme.Typography
	local animation: any = UITheme.Animation

	local gui = Instance.new("BillboardGui")
	gui.Name = "AnnonceUltime"
	gui.Size = UDim2.fromOffset(240, 64)
	gui.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 3.6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = UITheme.World.CombatDistance
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.FontFace = typography.Display
	text.TextSize = typography.Size.Title
	text.TextColor3 = UITheme.Colors.GoldLight
	text.Text = "ULTIME !"
	text.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = UITheme.Stroke.Color
	stroke.Thickness = typography.TextStroke.Large
	stroke.LineJoinMode = UITheme.Stroke.LineJoin
	stroke.Parent = text
	local scale = Instance.new("UIScale")
	scale.Scale = animation.Scale.OpenFrom
	scale.Parent = text
	gui.Parent = caster
	TweenService:Create(scale, TweenInfo.new(animation.Toast.Time / rate, animation.Toast.EasingStyle, animation.Toast.EasingDirection), {
		Scale = animation.Scale.Pop,
	}):Play()
	task.delay((animation.Toast.Time + 0.55) / rate, function()
		if not gui.Parent then return end
		local fade = TweenInfo.new(0.4 / rate, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(gui, fade, { StudsOffsetWorldSpace = gui.StudsOffsetWorldSpace + Vector3.new(0, 1.5, 0) }):Play()
		TweenService:Create(text, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
		task.delay(0.45 / rate, function() gui:Destroy() end)
	end)

	-- Colonne de lumière : haute et large au départ, elle se resserre en s'effaçant.
	local height = size.Y * 3.2
	local pillar = effectPart({
		Shape = Enum.PartType.Cylinder,
		Color = GOLD_LIGHT,
		Transparency = 0.5, -- le héros reste visible dans la colonne
		Size = Vector3.new(height, math.max(size.X, size.Z) * 1.1, math.max(size.X, size.Z) * 1.1),
		CFrame = CFrame.new(feet + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	})
	local flash = Instance.new("PointLight")
	flash.Color = GOLD_LIGHT
	flash.Range = 18
	flash.Brightness = 4
	flash.Parent = pillar
	local pillarFade = TweenInfo.new(0.45 / rate, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(pillar, pillarFade, { Transparency = 1, Size = Vector3.new(height, 0.4, 0.4) }):Play()
	TweenService:Create(flash, pillarFade, { Brightness = 0 }):Play()

	-- Onde au sol sous le héros.
	local ring = effectPart({
		Shape = Enum.PartType.Cylinder,
		Color = GOLD,
		Transparency = 0.2,
		Size = Vector3.new(0.15, 2, 2),
		CFrame = CFrame.new(feet + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	})
	local reach = math.max(size.X, size.Z) * 3 + 6
	TweenService:Create(ring, TweenInfo.new(0.5 / rate, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.15, reach, reach),
		Transparency = 1,
	}):Play()
	local host = effectPart({ Transparency = 1, Size = Vector3.new(size.X, 0.2, size.Z), CFrame = CFrame.new(feet) })
	sparkEmitter(host, 0.7, NumberRange.new(8, 14)):Emit(24)
	task.delay(1.2 / rate, function()
		pillar:Destroy()
		ring:Destroy()
	end)
	task.delay(1.5, function() host:Destroy() end)
end

function UltimateEffectController.Play(caster: Model, center: Vector3, radius: number?, speed: number?): number
	local scale = speed or 1
	if not caster.Parent then
		return 0
	end
	local box, size = caster:GetBoundingBox()
	local impact = impactOf(caster)
	local effect = effectOf(caster)
	aura(caster, box, size, scale, impact)
	-- sons (#18) : lancement, puis le coup
	AudioController.Play("UltimeLancement", { Position = box.Position })
	AudioController.Play("UltimeImpact", { Delay = UltimateEffectController.ImpactDelay(scale, caster), Position = center })
	task.delay(impact / scale, function()
		if not caster.Parent then
			return
		end
		if effect == "RempartFerme" then
			shieldShock(caster, center, scale)
		elseif effect == "DernierCarreau" then
			heavyBolt(caster, center, scale)
		else
			wave(weaponPosition(caster, box.Position), center, radius or DEFAULT_RADIUS, scale)
		end
	end)
	return UltimateEffectController.ImpactDelay(scale, caster)
end

-- Démonstration Studio : l'animation « Ultime » du jeu de combat du modèle (attribut
-- JeuAnimationsCombat, sinon JeuAnimations, puis jeu commun : AnimationSets), enregistrée à la volée, puis l'effet.
local function demoTrack(model: Model): AnimationTrack?
	local sequence = AnimationSets.find(model, "Ultime", true)
	local controller = model:FindFirstChildOfClass("AnimationController")
	local animator = controller and controller:FindFirstChildOfClass("Animator")
	if not sequence or not animator then
		warn(`[UltimateEffect] {model:GetFullName()} : animation Ultime ou Animator introuvable`)
		return nil
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = KeyframeSequenceProvider:RegisterKeyframeSequence(sequence)
	local track = (animator :: Animator):LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action
	return track
end

local function runDemo(model: Model)
	-- Avec le streaming, le modèle arrive avant ses pièces : attendre la racine et l'Animator.
	local deadline = os.clock() + 15
	while model.Parent and not (model.PrimaryPart and model:FindFirstChildOfClass("AnimationController")) and os.clock() < deadline do
		task.wait(0.2)
	end
	local track = demoTrack(model)
	while model.Parent and CollectionService:HasTag(model, TAG_APERCU) do
		local pause = model:GetAttribute("ApercuPause")
		local speed = model:GetAttribute("ApercuVitesse") or (model.Parent and model.Parent:GetAttribute("ApercuVitesse"))
		speed = if typeof(speed) == "number" and speed > 0 then speed else 1
		-- tout le cycle (pause comprise) suit la vitesse, comme la cadence du combat en x2
		task.wait((if typeof(pause) == "number" then math.max(pause, 1.5) else 2) / speed)
		local root = model.PrimaryPart
		if not root then
			continue
		end
		if track then
			track:Play(0.1)
			track:AdjustSpeed(speed)
		end
		local box, size = model:GetBoundingBox()
		local feet = Vector3.new(box.Position.X, box.Position.Y - size.Y / 2, box.Position.Z)
		UltimateEffectController.Play(model, feet + root.CFrame.LookVector * 10, DEFAULT_RADIUS, speed)
		task.wait(1 / speed)
	end
end

function UltimateEffectController:Start()
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

return UltimateEffectController
