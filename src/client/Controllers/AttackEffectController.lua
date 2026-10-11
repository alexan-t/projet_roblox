--!strict
-- Effets d'impact des attaques (purement visuels, côté client) — issue #16.
-- Le modèle choisit son effet avec l'attribut texte EffetAttaque (posé sur l'asset dans Studio) ;
-- l'effet part à l'instant du coup de son animation « Attaque » (attribut Impact de la
-- KeyframeSequence, voir tools/animation/AnimationKit.luau).
--   • "Seisme" (Roi Orc) : là où l'arme touche le sol, onde de choc, éclats de roche projetés,
--     poussière, et une courte secousse de caméra pour le joueur proche.
-- API : AttackEffectController.ImpactOf(model) -> instant du coup à x1 (s, 0 si inconnu) ;
--       AttackEffectController.Play(model, speed?) -> instant réel du coup (impact / vitesse du combat),
--       et lance l'effet du modèle s'il en a un à cet instant.
-- Tag "ApercuAttaque" (Model riggé, Studio) : attaque + effet en boucle. Attributs optionnels ApercuPause,
--   ApercuVitesse (sur le modèle ou son dossier, ex. 2 pour voir le rendu en x2).

local CollectionService = game:GetService("CollectionService")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AudioController = require(script.Parent.AudioController)

local TAG_APERCU = "ApercuAttaque"
local DUST_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

-- Matières de la map (docs/UI_DESIGN_SYSTEM.md) : sable, pierre, terre.
local SAND = Color3.fromHex("#E2D4B8")
local STONE = Color3.fromHex("#A89880")
local STONE_GREY = Color3.fromHex("#968A7E")
local WOOD_DARK = Color3.fromHex("#6C442A")

local AttackEffectController = {}

local function effectPart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
	part.CastShadow = false
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = Workspace
	return part
end

local function attackSequence(model: Model): KeyframeSequence?
	local setName = model:GetAttribute("JeuAnimationsCombat") or model:GetAttribute("JeuAnimations")
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local animations = assets and assets:FindFirstChild("Animations")
	local set = if typeof(setName) == "string" and animations then animations:FindFirstChild(setName) else nil
	local sequence = set and set:FindFirstChild("Attaque")
	return if sequence and sequence:IsA("KeyframeSequence") then sequence else nil
end

function AttackEffectController.ImpactOf(model: Model): number
	local sequence = attackSequence(model)
	local impact = sequence and sequence:GetAttribute("Impact")
	return if typeof(impact) == "number" then impact else 0
end

-- Pièce tenue en main droite (articulation Tenu_* du bras droit), sinon la plus basse en main.
local function weapon(model: Model): BasePart?
	local fallback: BasePart? = nil
	for _, motor in model:GetDescendants() do
		if motor:IsA("Motor6D") and string.sub(motor.Name, 1, 5) == "Tenu_" and motor.Part1 then
			if motor.Part0 and string.find(string.lower((motor.Part0 :: BasePart).Name), "right", 1, true) then
				return motor.Part1
			end
			fallback = fallback or motor.Part1
		end
	end
	return fallback
end

-- Point d'impact au sol : l'extrémité la plus basse de l'arme, sinon devant le modèle.
local function impactPoint(model: Model, groundY: number): Vector3
	local blade = weapon(model)
	if blade then
		local lowest: Vector3? = nil
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local corner = blade.CFrame:PointToWorldSpace(Vector3.new(sx, sy, sz) * blade.Size / 2)
					if not lowest or corner.Y < lowest.Y then
						lowest = corner
					end
				end
			end
		end
		if lowest then
			return Vector3.new(lowest.X, groundY, lowest.Z)
		end
	end
	local pivot = model:GetPivot()
	local front = pivot.Position + pivot.LookVector * 6
	return Vector3.new(front.X, groundY, front.Z)
end

local function shake(center: Vector3, strength: number)
	local player = Players.LocalPlayer
	local character = player and player.Character
	local camera = Workspace.CurrentCamera
	if not character or not camera then
		return
	end
	local distance = (character:GetPivot().Position - center).Magnitude
	local amount = strength * math.clamp(1 - distance / 60, 0, 1)
	if amount <= 0.01 then
		return
	end
	local start = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if t > 0.3 then
			connection:Disconnect()
			return
		end
		local decay = amount * (1 - t / 0.3)
		camera.CFrame *= CFrame.new(math.noise(t * 40, 0, 0) * decay, math.noise(0, t * 40, 0) * decay, 0)
	end)
end

-- Séisme : onde de choc au sol, éclats de roche, poussière, secousse.
local function seisme(model: Model)
	local box, size = model:GetBoundingBox()
	local groundY = box.Position.Y - size.Y / 2
	local center = impactPoint(model, groundY)
	local scale = math.clamp(size.Y / 6, 1, 3) -- un boss (≈ 13 studs) frappe plus large qu'un monstre

	-- Onde : terre soulevée en anneau irrégulier (hauteur et inclinaison propres à chaque motte),
	-- basse et brève, qui s'élargit puis retombe.
	local random = Random.new()
	local segments: { { part: BasePart, lift: number, tilt: number, jitter: number } } = {}
	local count = 26
	for i = 1, count do
		local shade = random:NextNumber(0, 1)
		segments[i] = {
			part = effectPart({ Name = "SeismeOnde", Material = Enum.Material.Ground, Color = STONE:Lerp(WOOD_DARK, shade * 0.6), Size = Vector3.new(1, 0.3, 0.8) }),
			lift = random:NextNumber(0.35, 1),
			tilt = random:NextNumber(15, 40),
			jitter = random:NextNumber(-0.25, 0.25),
		}
	end
	local radius = 4.5 * scale
	local start = os.clock()
	local wave: RBXScriptConnection
	wave = RunService.RenderStepped:Connect(function()
		local progress = math.clamp((os.clock() - start) / 0.45, 0, 1)
		local r = 0.8 + radius * (1 - (1 - progress) ^ 3)
		local rise = math.sin(math.pi * math.min(progress * 1.3, 1))
		for i, segment in segments do
			local angle = 2 * math.pi * (i + segment.jitter) / count
			local height = 0.45 * scale * segment.lift * rise
			local offset = Vector3.new(math.cos(angle) * r, height / 2 - 0.15, math.sin(angle) * r)
			segment.part.Size = Vector3.new(2 * math.pi * r / count * 0.95, math.max(height, 0.05), 0.5 + 0.3 * segment.lift)
			-- penchée vers l'extérieur : la terre est repoussée par le choc
			segment.part.CFrame = CFrame.lookAt(center + offset, center + Vector3.new(0, offset.Y, 0)) * CFrame.Angles(math.rad(-segment.tilt), 0, 0)
			segment.part.Transparency = if progress < 0.55 then 0 else (progress - 0.55) / 0.45
		end
		if progress >= 1 then
			wave:Disconnect()
			for _, segment in segments do
				segment.part:Destroy()
			end
		end
	end)

	-- Éclats de roche et de terre projetés en cloche depuis toute la zone d'impact, qui retombent.
	for _ = 1, math.floor(10 * scale) do
		local chunkSize = random:NextNumber(0.2, 0.5) * scale
		local spawnOffset = Vector3.new(random:NextNumber(-1, 1), 0, random:NextNumber(-1, 1)) * 1.2 * scale
		local chunk = effectPart({
			Name = "SeismeEclat",
			Material = Enum.Material.Slate,
			Color = if random:NextNumber() < 0.6 then STONE_GREY else WOOD_DARK,
			Size = Vector3.new(chunkSize, chunkSize * random:NextNumber(0.5, 0.9), chunkSize * random:NextNumber(0.6, 1)),
			CFrame = CFrame.new(center + spawnOffset + Vector3.new(0, 0.2, 0)) * CFrame.Angles(random:NextNumber(0, 6.28), random:NextNumber(0, 6.28), 0),
		})
		local angle = random:NextNumber(0, 2 * math.pi)
		local reach = random:NextNumber(1.5, 4.5) * scale
		local peak = random:NextNumber(1.5, 4) * scale
		local flight = random:NextNumber(0.45, 0.75)
		local from = chunk.CFrame
		local spin = CFrame.Angles(random:NextNumber(-8, 8), random:NextNumber(-8, 8), 0)
		local launched = os.clock()
		local fly: RBXScriptConnection
		fly = RunService.RenderStepped:Connect(function()
			local p = math.clamp((os.clock() - launched) / flight, 0, 1)
			local horizontal = Vector3.new(math.cos(angle), 0, math.sin(angle)) * reach * p
			local vertical = peak * 4 * p * (1 - p)
			chunk.CFrame = (from + horizontal + Vector3.new(0, vertical, 0)) * spin:Lerp(CFrame.identity, 1 - p)
			chunk.Transparency = if p < 0.75 then 0 else (p - 0.75) / 0.25
			if p >= 1 then
				fly:Disconnect()
				chunk:Destroy()
			end
		end)
	end

	-- Poussière soulevée tout autour du point d'impact.
	local host = effectPart({ Name = "SeismePoussiere", Transparency = 1, Size = Vector3.new(radius, 0.2, radius), CFrame = CFrame.new(center) })
	local dust = Instance.new("ParticleEmitter")
	dust.Enabled = false
	dust.Texture = DUST_TEXTURE
	dust.Shape = Enum.ParticleEmitterShape.Box
	dust.EmissionDirection = Enum.NormalId.Top
	dust.Color = ColorSequence.new(SAND:Lerp(STONE, 0.3))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2 * scale), NumberSequenceKeypoint.new(1, 3 * scale) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(0.6, 0.55), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(0.6, 1.1)
	dust.Speed = NumberRange.new(3, 7)
	dust.SpreadAngle = Vector2.new(75, 75)
	dust.Drag = 3.5
	dust.Rotation = NumberRange.new(0, 360)
	dust.RotSpeed = NumberRange.new(-40, 40)
	dust.Parent = host
	dust:Emit(math.floor(10 * scale))
	task.delay(1.6, function()
		host:Destroy()
	end)

	shake(center, 0.35 * scale)
end

local EFFECTS: { [string]: (Model) -> () } = {
	Seisme = seisme,
}

function AttackEffectController.Play(model: Model, speed: number?): number
	local impact = AttackEffectController.ImpactOf(model) / (speed or 1)
	local kind = model:GetAttribute("EffetAttaque")
	local effect = if typeof(kind) == "string" then EFFECTS[kind] else nil
	if effect then
		task.delay(impact, function()
			if model.Parent then
				effect(model)
				AudioController.Play(kind :: string, { Position = model:GetPivot().Position }) -- son de l'effet (#18), même nom que l'effet
			end
		end)
	end
	return impact
end

-- Démonstration Studio : l'animation « Attaque » du jeu de combat du modèle, puis l'effet.
local function runDemo(model: Model)
	-- Avec le streaming, le modèle arrive avant ses pièces : attendre la racine et l'Animator.
	local deadline = os.clock() + 15
	while model.Parent and not (model.PrimaryPart and model:FindFirstChildOfClass("AnimationController")) and os.clock() < deadline do
		task.wait(0.2)
	end
	local sequence = attackSequence(model)
	local controller = model:FindFirstChildOfClass("AnimationController")
	local animator = controller and controller:FindFirstChildOfClass("Animator")
	if not sequence or not animator then
		warn(`[AttackEffect] {model:GetFullName()} : animation Attaque ou Animator introuvable`)
		return
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = KeyframeSequenceProvider:RegisterKeyframeSequence(sequence)
	local track = (animator :: Animator):LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action
	while model.Parent and CollectionService:HasTag(model, TAG_APERCU) do
		local pause = model:GetAttribute("ApercuPause")
		local speed = model:GetAttribute("ApercuVitesse") or (model.Parent and model.Parent:GetAttribute("ApercuVitesse"))
		speed = if typeof(speed) == "number" and speed > 0 then speed else 1
		-- tout le cycle (pause comprise) suit la vitesse, comme la cadence du combat en x2
		task.wait((if typeof(pause) == "number" then math.max(pause, 1) else 1.5) / speed)
		track:Play(0.1)
		track:AdjustSpeed(speed)
		AttackEffectController.Play(model, speed)
		task.wait((if track.Length > 0 then track.Length else 1.4) / speed)
	end
end

function AttackEffectController:Start()
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

return AttackEffectController
