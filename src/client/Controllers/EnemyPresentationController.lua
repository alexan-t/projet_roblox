--!strict
-- Styles de présentation des ennemis par famille (voir docs/COMBAT_PRESENTATION.md), côté client :
--   • entrée depuis le décor (Lake : sort de la mare et rebondit ; Walk : marche le long des étapes) ;
--   • attaque (SlimeHeadbutt : recul, écrasement, coup de tête, gouttes ; SpearThrust : poussée de la lance,
--     étincelle à la pointe ; HeavyWeapon : Fendoir + Seisme existants, AttackEffectController) ;
--   • mort (SlimeBurst : écrasé, gonfle, POP en gouttes ; HumanoidFall : animation Mort, pause, fondu ;
--     HumanoidFallHeavy : chute lourde, poussière) ;
--   • sac de récompenses (visuel seulement) à la mort du dernier ennemi d'un combat gagné.
-- Profils : Shared.Config.EnemyPresentationConfig. Tout est local à ce client (LocalTransparencyModifier,
-- échelle et position vues par lui, effets parentés dans un dossier local détruit à la fin) : aucun
-- dégât, aucune règle, rien n'est répliqué. Les chiffres de dégâts attendent l'instant d'impact renvoyé.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AnimationSets = require(ReplicatedStorage.Shared.Animation.AnimationSets)
local Skeleton = require(ReplicatedStorage.Shared.Animation.Skeleton)
local Config = require(ReplicatedStorage.Shared.Config.EnemyPresentationConfig)
local AudioController = require(script.Parent.AudioController)
local MonsterAnimationController = require(script.Parent.MonsterAnimationController)

local EnemyPresentationController = {}

local PALETTE = Config.Palette

------------------------------------------------------------------ outils

-- Dossier local des effets (jamais répliqué : créé par ce client).
local function effects(): Instance
	local name = "PresentationCombat_" .. Players.LocalPlayer.UserId
	local existing = Workspace:FindFirstChild(name)
	if existing then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = Workspace
	return folder
end

-- step(alpha) pendant duration secondes (temps réel), puis step(1). Interrompu si alive() devient faux.
local function run(duration: number, step: (number) -> (), alive: (() -> boolean)?)
	if duration <= 0 then
		step(1)
		return
	end
	local start = os.clock()
	while true do
		if alive and not alive() then
			return
		end
		local a = (os.clock() - start) / duration
		if a >= 1 then
			break
		end
		step(a)
		RunService.Heartbeat:Wait()
	end
	step(1)
end

local function parts(model: Instance): { BasePart }
	local list = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

function EnemyPresentationController.SetHidden(model: Instance, hidden: boolean)
	for _, d in model:GetDescendants() do
		if (d:IsA("BasePart") and d.Name ~= Skeleton.Root) or d:IsA("Decal") then
			(d :: any).LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

local function setFade(model: Instance, alpha: number)
	for _, d in model:GetDescendants() do
		if (d:IsA("BasePart") and d.Name ~= Skeleton.Root) or d:IsA("Decal") then
			(d :: any).LocalTransparencyModifier = 1 - alpha
		end
	end
end

-- Hauteur pivot → pieds (pour poser un modèle sur le sol, comme ArenaService.spawnModel).
function EnemyPresentationController.FootOffset(model: Model): number
	local box, size = model:GetBoundingBox()
	return model:GetPivot().Position.Y - (box.Position.Y - size.Y / 2)
end

local function place(model: Model, feet: Vector3, lookAt: Vector3, foot: number)
	local position = feet + Vector3.new(0, foot, 0)
	local target = Vector3.new(lookAt.X, position.Y, lookAt.Z)
	if (target - position).Magnitude < 1e-3 then
		target = position + model:GetPivot().LookVector
	end
	model:PivotTo(CFrame.lookAt(position, target))
end

local function effectPart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = effects()
	return p
end

-- Grosses gouttes chunky (peu nombreuses, très courtes) qui jaillissent en arc puis disparaissent.
local function droplets(center: Vector3, color: Color3, count: number, spread: number, duration: number, size: number?)
	task.spawn(function()
		local drops = {}
		local random = Random.new()
		for i = 1, count do
			local angle = (i / count) * math.pi * 2 + random:NextNumber(0, 0.6)
			local dir = Vector3.new(math.cos(angle), 0, math.sin(angle)) * spread * random:NextNumber(0.6, 1.2)
			local d = (size or 0.55) * random:NextNumber(0.8, 1.25)
			table.insert(drops, {
				part = effectPart({ Shape = Enum.PartType.Ball, Color = color, Size = Vector3.one * d, Position = center, Transparency = 0.05 }),
				dir = dir, up = random:NextNumber(1.5, 3), size = d,
			})
		end
		run(duration, function(a)
			for _, drop in drops do
				local h = drop.up * 4 * a * (1 - a)
				drop.part.Position = center + drop.dir * a + Vector3.new(0, h, 0)
				drop.part.Size = Vector3.one * drop.size * (1 - 0.5 * a)
				drop.part.Transparency = 0.05 + 0.95 * a * a
			end
		end)
		for _, drop in drops do
			drop.part:Destroy()
		end
	end)
end

-- Anneau plat au sol qui s'élargit et s'efface (éclaboussure, poussière).
local function ring(center: Vector3, radius: number, color: Color3, duration: number)
	task.spawn(function()
		local disc = effectPart({ Shape = Enum.PartType.Cylinder, Color = color, Transparency = 0.25 })
		run(duration, function(a)
			local r = 0.6 + (radius - 0.6) * (1 - (1 - a) ^ 3)
			disc.Size = Vector3.new(0.15, r * 2, r * 2)
			disc.CFrame = CFrame.new(center + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
			disc.Transparency = 0.25 + 0.75 * a
		end)
		disc:Destroy()
	end)
end

-- Légère secousse de caméra (seulement près du joueur, brève) : jamais de contrôle bloqué.
local function shake(center: Vector3, strength: number)
	local character = Players.LocalPlayer.Character
	local camera = Workspace.CurrentCamera
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not camera or not root or not root:IsA("BasePart") then
		return
	end
	local amount = strength * math.clamp(1 - (root.Position - center).Magnitude / 60, 0, 1)
	if amount <= 0.01 then
		return
	end
	local start = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if t > 0.25 then
			connection:Disconnect()
			return
		end
		local decay = amount * (1 - t / 0.25)
		camera.CFrame *= CFrame.new(math.noise(t * 40, 0, 0) * decay, math.noise(0, t * 40, 0) * decay, 0)
	end)
end

-- Échelle locale d'un modèle (ScaleTo), toujours relative à son échelle d'origine.
local function scaleTo(model: Model, base: number, factor: number)
	if model.Parent then
		model:ScaleTo(base * factor)
	end
end

local function colorOf(model: Model, profile: Config.Profile): Color3
	return Config.effectColor(model:GetAttribute(Config.EffectColorAttribute), profile)
end

local function groundOf(model: Model): number
	local box, size = model:GetBoundingBox()
	return box.Position.Y - size.Y / 2
end

------------------------------------------------------------------ entrées

export type Entrance = {
	Path: { Vector3 }, -- pieds : repère du décor, étapes, case de destination (dernier)
	LookAt: Vector3,
	Duration: number, -- budget total (s)
	Alive: () -> boolean, -- faux : intro annulée (le modèle est détruit par l'appelant)
}

local function entranceLake(model: Model, profile: Config.Profile, entrance: Entrance)
	local path = entrance.Path
	local foot = EnemyPresentationController.FootOffset(model)
	local base = model:GetScale()
	local _, size = model:GetBoundingBox()
	local start, dest = path[1], path[#path]
	local color = colorOf(model, profile)
	local alive = entrance.Alive
	local budget = math.max(entrance.Duration, 0.8)
	-- 1. Caché sous l'eau, remonte en s'étirant un peu.
	place(model, start - Vector3.new(0, size.Y * 0.85, 0), dest, foot)
	EnemyPresentationController.SetHidden(model, false)
	run(budget * 0.22, function(a)
		place(model, start - Vector3.new(0, size.Y * 0.85 * (1 - a), 0), dest, foot)
		scaleTo(model, base, 0.85 + 0.2 * a)
	end, alive)
	if not alive() then
		return
	end
	-- 2. Bond hors de l'eau : gouttelettes de l'eau et de sa couleur.
	droplets(start + Vector3.new(0, 0.4, 0), PALETTE.Water, 7, 2.5, 0.45)
	droplets(start + Vector3.new(0, 0.6, 0), color, 4, 1.8, 0.4, 0.45)
	ring(start, 2.2, PALETTE.Water, 0.4)
	AudioController.Play("Impact", { Position = start, Pitch = 1.5, Volume = 0.5 })
	-- 3. Petits bonds jusqu'à la case (courts et lisibles).
	local hops = { start:Lerp(dest, 0.55), dest }
	local from = start
	for index, target in hops do
		local height = if index == 1 then 3.2 else 1.6
		local duration = budget * (if index == 1 then 0.36 else 0.3)
		run(duration, function(a)
			local p = from:Lerp(target, a) + Vector3.new(0, 4 * height * a * (1 - a), 0)
			place(model, p, if a < 0.85 then target + (target - from) else entrance.LookAt, foot)
			-- écrasé au décollage et à l'atterrissage, étiré en l'air
			scaleTo(model, base, 1 + 0.12 * math.sin(a * math.pi) - 0.1 * (if a < 0.12 or a > 0.88 then 1 else 0))
		end, alive)
		if not alive() then
			return
		end
		from = target
	end
	scaleTo(model, base, 1)
	place(model, dest, entrance.LookAt, foot)
end

local function entranceWalk(model: Model, entrance: Entrance, heavy: boolean)
	local path = entrance.Path
	local foot = EnemyPresentationController.FootOffset(model)
	local alive = entrance.Alive
	local length = 0
	for i = 1, #path - 1 do
		length += (path[i + 1] - path[i]).Magnitude
	end
	local fade = 0.25
	local arrival = if heavy then 0.45 else 0.15
	local speed = math.max(if heavy then 5 else 9, length / math.max(entrance.Duration - fade - arrival, 0.4))
	place(model, path[1], path[2] or entrance.LookAt, foot)
	run(fade, function(a)
		setFade(model, a)
	end, alive)
	EnemyPresentationController.SetHidden(model, false)
	if not alive() then
		return
	end
	local animated = AnimationSets.isAnimated(model)
	if animated then
		MonsterAnimationController.Play(model, "Marche")
	end
	for i = 1, #path - 1 do
		local a, b = path[i], path[i + 1]
		local distance = (b - a).Magnitude
		run(distance / speed, function(t)
			local p = a:Lerp(b, t)
			-- sans animation de marche : petit rebond de pas
			local bob = if animated then 0 else math.abs(math.sin(t * distance * 1.4)) * 0.2
			place(model, p + Vector3.new(0, bob, 0), if distance > 0.1 then p + (b - a).Unit * 5 else entrance.LookAt, foot)
		end, alive)
		if not alive() then
			return
		end
	end
	place(model, path[#path], entrance.LookAt, foot)
	if animated then
		MonsterAnimationController.Stop(model, "Marche")
		MonsterAnimationController.Play(model, "Attente")
	end
	if heavy then
		-- arrêt lourd : poussière au sol, petit choc, légère secousse
		local feet = path[#path]
		ring(feet, 5, PALETTE.Dust, 0.45)
		droplets(feet + Vector3.new(0, 0.3, 0), PALETTE.Dust, 8, 4, 0.5, 0.8)
		AudioController.Play("Impact", { Position = feet, Pitch = 0.6 })
		shake(feet, 0.25)
		task.wait(arrival)
	end
end

-- Fait entrer un modèle LOCAL (copie de présentation) depuis le décor jusqu'à sa case. Bloquant.
function EnemyPresentationController.Enter(model: Model, enemyId: string, entrance: Entrance)
	local profile = Config.profile(enemyId)
	local style = Config.spawnStyle(profile)
	if style.Kind == "Lake" then
		entranceLake(model, profile, entrance)
	else
		entranceWalk(model, entrance, style.Heavy == true)
	end
end

-- Court déplacement d'une copie déjà en scène vers sa vraie case (après Prêt) : un bond pour un slime,
-- quelques pas pour les autres. Bloquant ; finit exactement sur `to`.
function EnemyPresentationController.Move(model: Model, enemyId: string, to: Vector3, lookAt: Vector3, duration: number, alive: () -> boolean)
	local profile = Config.profile(enemyId)
	local style = Config.spawnStyle(profile)
	local foot = EnemyPresentationController.FootOffset(model)
	local pivot = model:GetPivot().Position
	local from = Vector3.new(pivot.X, pivot.Y - foot, pivot.Z)
	local distance = ((to - from) * Vector3.new(1, 0, 1)).Magnitude
	if distance < 0.05 then
		place(model, to, lookAt, foot)
		return
	end
	local animated = style.Kind ~= "Lake" and AnimationSets.isAnimated(model)
	if animated then
		MonsterAnimationController.Play(model, "Marche")
	end
	local base = model:GetScale()
	run(duration, function(a)
		local height = if style.Kind == "Lake" then math.min(distance * 0.35, 2) * 4 * a * (1 - a) else 0
		place(model, from:Lerp(to, a) + Vector3.new(0, height, 0), if a < 0.85 then to + (to - from) else lookAt, foot)
		if style.Kind == "Lake" then
			scaleTo(model, base, 1 + 0.1 * math.sin(a * math.pi))
		end
	end, alive)
	if style.Kind == "Lake" then
		scaleTo(model, base, 1)
	end
	if animated then
		MonsterAnimationController.Stop(model, "Marche")
	end
	place(model, to, lookAt, foot)
end

------------------------------------------------------------------ attaques

-- Décalage local cumulable (comme le recul de DamageFeedbackController) : le serveur reste maître de
-- la position ; on ne pousse que la différence depuis la dernière image.
local function nudge(model: Model, offset: Vector3, applied: Vector3): Vector3
	if model.Parent then
		model:PivotTo(model:GetPivot() + (offset - applied))
	end
	return offset
end

local function slimeHeadbutt(model: Model, target: Model?, profile: Config.Profile, speed: number)
	local pivot = model:GetPivot()
	local toward = if target then (target:GetPivot().Position - pivot.Position) * Vector3.new(1, 0, 1) else pivot.LookVector
	local dir = if toward.Magnitude > 0.1 then toward.Unit else pivot.LookVector
	local impact = (profile.Impact or 0.27) / speed
	local total = 0.55 / speed
	local base = model:GetScale()
	local color = colorOf(model, profile)
	local applied = Vector3.zero
	local alive = function(): boolean
		return model.Parent ~= nil
	end
	-- recul + écrasement, puis bond / coup de tête jusqu'à l'impact, puis retour
	run(impact, function(a)
		local back = math.min(a / 0.45, 1)
		local lunge = math.max((a - 0.45) / 0.55, 0)
		local offset = -dir * 0.5 * back * (1 - lunge) + dir * 1.6 * lunge + Vector3.new(0, 1.1 * math.sin(lunge * math.pi * 0.9), 0)
		applied = nudge(model, offset, applied)
		scaleTo(model, base, if lunge > 0 then 0.9 + 0.18 * lunge else 1 - 0.12 * back)
	end, alive)
	if not alive() then
		return
	end
	local _, size = model:GetBoundingBox()
	local contact = model:GetPivot().Position + dir * size.Z * 0.5
	contact = Vector3.new(contact.X, groundOf(model) + size.Y * 0.45, contact.Z)
	droplets(contact, color, 7, 2.2, 0.35, 0.6)
	AudioController.Play("Impact", { Position = contact, Pitch = 1.35, Volume = 0.6 })
	run(total - impact, function(a)
		applied = nudge(model, dir * 1.6 * (1 - a), applied)
		scaleTo(model, base, 1.08 - 0.08 * a)
	end, alive)
	nudge(model, Vector3.zero, applied)
	scaleTo(model, base, 1)
end

-- Pièce tenue la plus longue (lance) : os ArmeDroite / ArmeGauche (squelette commun), sinon articulation
-- vers une pièce dont le nom désigne un objet tenu (ancien rig : Lance → spear_geom, Tenu_*).
local SHIELD_WORDS = { "shield", "bouclier", "buckler" }

local function isShield(name: string): boolean
	local lower = string.lower(name)
	for _, word in SHIELD_WORDS do
		if string.find(lower, word, 1, true) then
			return true
		end
	end
	return false
end

function EnemyPresentationController.Weapon(model: Model): BasePart?
	local best: BasePart? = nil
	local function consider(part: BasePart)
		if isShield(part.Name) then
			return
		end
		if not best or part.Size.Magnitude > best.Size.Magnitude then
			best = part
		end
	end
	for _, bone in { "ArmeDroite", "ArmeGauche" } do
		for _, piece in AnimationSets.pieces(model, bone) do
			consider(piece)
		end
	end
	if best then
		return best
	end
	for _, motor in model:GetDescendants() do
		if motor:IsA("Motor6D") and motor.Part1 then
			local part = motor.Part1 :: BasePart
			if string.sub(motor.Name, 1, 5) == "Tenu_" or Skeleton.guess(part.Name) == Skeleton.NearestHand then
				consider(part)
			end
		end
	end
	return best
end

-- Pointe de l'arme : l'extrémité de son grand axe la plus éloignée du corps.
local function weaponTip(model: Model, weapon: BasePart): Vector3
	local size = weapon.Size
	local axis = if size.X >= size.Y and size.X >= size.Z then weapon.CFrame.RightVector * size.X
		elseif size.Y >= size.Z then weapon.CFrame.UpVector * size.Y
		else weapon.CFrame.LookVector * size.Z
	local center = model:GetPivot().Position
	local a, b = weapon.Position + axis / 2, weapon.Position - axis / 2
	return if (a - center).Magnitude > (b - center).Magnitude then a else b
end

local function spearThrust(model: Model, profile: Config.Profile, speed: number): number
	local impact = (profile.Impact or 0.45) / speed
	local weapon = EnemyPresentationController.Weapon(model)
	if weapon then
		-- petite traînée sur la pointe pendant la poussée, étincelle et poussière à l'impact
		local tipAttachment = Instance.new("Attachment")
		local tailAttachment = Instance.new("Attachment")
		local tip = weaponTip(model, weapon)
		tipAttachment.WorldPosition = tip
		tailAttachment.WorldPosition = tip:Lerp(weapon.Position, 0.25)
		tipAttachment.Parent, tailAttachment.Parent = weapon, weapon
		local trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = tipAttachment, tailAttachment
		trail.Lifetime = 0.12
		trail.Color = ColorSequence.new(PALETTE.Dust)
		trail.Transparency = NumberSequence.new(0.35, 1)
		trail.FaceCamera = true
		trail.Enabled = false
		trail.Parent = weapon
		task.delay(impact * 0.55, function()
			trail.Enabled = true
		end)
		task.delay(impact, function()
			if weapon.Parent then
				local point = weaponTip(model, weapon)
				droplets(point, PALETTE.Spark, 5, 1.4, 0.25, 0.3)
				droplets(Vector3.new(point.X, groundOf(model) + 0.2, point.Z), PALETTE.Dust, 4, 1.2, 0.3, 0.45)
				AudioController.Play("Impact", { Position = point, Pitch = 1.1, Volume = 0.7 })
			end
			task.delay(0.15 / speed, function()
				trail:Destroy()
				tipAttachment:Destroy()
				tailAttachment:Destroy()
			end)
		end)
	end
	return impact
end

-- Attaque d'un ennemi : effet de sa famille. Renvoie l'instant du coup (s, déjà divisé par la vitesse),
-- ou nil pour garder le chemin existant (AttackEffectController : séquence « Attaque », Seisme...).
function EnemyPresentationController.Attack(model: Model, enemyId: string, target: Model?, speed: number): number?
	local profile = Config.profile(enemyId)
	if profile.AttackStyle == "SlimeHeadbutt" then
		task.spawn(slimeHeadbutt, model, target, profile, speed)
		return (profile.Impact or 0.27) / speed
	elseif profile.AttackStyle == "SpearThrust" then
		return spearThrust(model, profile, speed)
	end
	return nil
end

------------------------------------------------------------------ morts

local function slimeBurst(model: Model, profile: Config.Profile, delay: number, speed: number)
	task.wait(delay)
	if not model.Parent then
		return
	end
	local base = model:GetScale()
	local color = colorOf(model, profile)
	run(0.1 / speed, function(a)
		scaleTo(model, base, 1 - 0.22 * a) -- écrasé
	end)
	run(0.16 / speed, function(a)
		scaleTo(model, base, 0.78 + 0.5 * a) -- gonfle
	end)
	local box, size = model:GetBoundingBox()
	local center = box.Position
	EnemyPresentationController.SetHidden(model, true) -- POP
	scaleTo(model, base, 1)
	droplets(center, color, 9, 3, 0.45 / speed, 0.75)
	ring(Vector3.new(center.X, center.Y - size.Y / 2, center.Z), 2.6, color, 0.35 / speed)
	AudioController.Play("MortEnnemi", { Position = center, Pitch = 1.4 })
end

-- Copie locale articulée (squelette et animations gardés) : la mort se joue même si le serveur retire
-- le modèle d'origine (CombatService, 1,7 s après la mort).
local function deathCopy(model: Model): Model
	local archivable = model.Archivable
	model.Archivable = true
	local copy = model:Clone()
	model.Archivable = archivable
	for _, item in copy:GetDescendants() do
		if item:IsA("BillboardGui") or item:IsA("Highlight") then
			item:Destroy()
		end
	end
	copy.Name = model.Name .. "_Mort"
	copy.Parent = effects()
	return copy
end

local function humanoidFall(model: Model, profile: Config.Profile, delay: number, speed: number, heavy: boolean)
	task.wait(delay)
	if not model.Parent then
		return
	end
	local timing = profile.DeathTiming
	local start = os.clock()
	local copy = deathCopy(model)
	EnemyPresentationController.SetHidden(model, true)
	local pivot = copy:GetPivot()
	local feet = Vector3.new(pivot.Position.X, groundOf(copy), pivot.Position.Z)
	local foot = pivot.Position.Y - feet.Y
	local _, size = copy:GetBoundingBox()
	local track: AnimationTrack? = nil
	if AnimationSets.find(copy, "Mort", true) and AnimationSets.isAnimated(copy) then
		-- les membres jouent « Mort » pendant que le corps entier bascule (le sol se lit sans ambiguïté)
		track = MonsterAnimationController.Play(copy, "Mort", 0.05)
	end
	local hinge = CFrame.new(feet) * pivot.Rotation
	local function lean(angle: number, back: number)
		-- bascule vers l'arrière autour des pieds ; relevé de l'épaisseur pour ne pas traverser le sol
		local lift = size.Z * 0.5 * math.sin(math.rad(angle))
		copy:PivotTo(hinge * CFrame.new(0, lift, back) * CFrame.Angles(math.rad(angle), 0, 0) * CFrame.new(0, foot, 0))
	end
	local react = 0.15 / speed
	local ground = math.max((timing.GroundImpact or 0.8) / speed, react + 0.1)
	-- 1. encaisse : petit recul
	run(react, function(a)
		lean(8 * a, 0.35 * a)
	end)
	-- 2. tombe : de plus en plus vite jusqu'au sol (GroundImpact)
	local finalAngle = if heavy then 84 else 82
	run(ground - react, function(a)
		lean(8 + (finalAngle - 8) * a * a, 0.35 + 0.4 * a)
	end)
	-- 3. impact au sol : poussière, son, secousse si lourd
	ring(feet, if heavy then 7 else 3.2, PALETTE.Dust, 0.5 / speed)
	droplets(feet + Vector3.new(0, 0.3, 0), PALETTE.Dust, if heavy then 10 else 6, if heavy then 5 else 2.4, 0.5 / speed, if heavy then 0.9 else 0.55)
	AudioController.Play("Impact", { Position = feet, Pitch = if heavy then 0.55 else 0.85 })
	AudioController.Play("MortEnnemi", { Position = feet })
	if heavy then
		shake(feet, 0.3)
	end
	if track then
		local remaining = math.max(track.Length - track.TimePosition, 0) / math.max(track.Speed, 0.01)
		task.delay(remaining, function()
			if track and copy.Parent then
				track:AdjustSpeed(0) -- reste au sol, membres figés
			end
		end)
	end
	-- 4. reste au sol (le sac tombe et rebondit à côté), puis s'efface à FadeStart
	local fadeAt = start + timing.FadeStart / speed
	while os.clock() < fadeAt and copy.Parent do
		RunService.Heartbeat:Wait()
	end
	droplets(feet + Vector3.new(0, 0.4, 0), PALETTE.Dust, 5, 2, 0.4 / speed, 0.6)
	run(math.max(timing.Complete - timing.FadeStart, 0.2) / speed, function(a)
		setFade(copy, 1 - a)
	end)
	copy:Destroy()
end

export type DeathRecord = { feet: Vector3, bagAt: number, completeAt: number, enemyId: string }
local lastDeath: DeathRecord? = nil

-- Déroulé de la dernière mort d'ennemi (pour l'outro : le sac tombe près de ce corps, à bagAt).
function EnemyPresentationController.LastDeath(): DeathRecord?
	return lastDeath
end

-- Mort d'un ennemi selon sa famille. Renvoie true si elle est jouée ici (sinon DefeatEffectController).
-- Dans tous les cas, son déroulé est noté (DeathTiming du profil, divisé par la vitesse du combat).
function EnemyPresentationController.Death(model: Model, enemyId: string, delay: number, speed: number): boolean
	local profile = Config.profile(enemyId)
	local timing = profile.DeathTiming
	local pivot = model:GetPivot().Position
	local start = os.clock() + delay
	lastDeath = {
		feet = Vector3.new(pivot.X, groundOf(model), pivot.Z),
		bagAt = start + timing.BagDrop / speed,
		completeAt = start + timing.Complete / speed,
		enemyId = enemyId,
	}
	if profile.DeathStyle == "SlimeBurst" then
		task.spawn(slimeBurst, model, profile, delay, speed)
		return true
	elseif profile.DeathStyle == "HumanoidFall" or profile.DeathStyle == "HumanoidFallHeavy" then
		task.spawn(humanoidFall, model, profile, delay, speed, profile.DeathStyle == "HumanoidFallHeavy")
		return true
	end
	return false
end

------------------------------------------------------------------ sac de récompenses

local bags: { Model } = {}

-- Sac à la position de mort du dernier ennemi : tombe, rebondit, tourne, brille. Visuel seulement.
function EnemyPresentationController.DropBag(corpse: Vector3, toward: Vector3?)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local combat = assets and assets:FindFirstChild("Combat")
	local template = combat and combat:FindFirstChild(Config.BagTemplate)
	if not template or not template:IsA("Model") then
		warn(`[EnemyPresentation] asset {Config.BagTemplate} introuvable dans Assets.Combat`)
		return
	end
	local bag = template:Clone()
	for _, part in parts(bag) do
		part.Anchored = true
		part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
	end
	local foot = EnemyPresentationController.FootOffset(bag)
	-- près du corps (côté héros), pas dessus : on lit « il est tombé » puis « il a lâché le sac »
	local side = if toward then (toward - corpse) * Vector3.new(1, 0, 1) else Vector3.zero
	local feet = corpse + (if side.Magnitude > 0.1 then side.Unit * Config.BagOffset else Vector3.zero)
	local light = Instance.new("PointLight")
	light.Color = PALETTE.Glow
	light.Range = 8
	light.Brightness = 0
	light.Parent = bag.PrimaryPart or parts(bag)[1]
	bag.Parent = effects()
	table.insert(bags, bag)
	-- Face avant (pièce d'or, -Z) tournée vers le joueur une fois posé ; la rotation se termine dessus.
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local viewer = if root and root:IsA("BasePart") then root.Position else feet + Vector3.new(0, 0, 1)
	local facing = CFrame.lookAt(feet, Vector3.new(viewer.X, feet.Y, viewer.Z)).Rotation
	local turn = math.pi * 1.15 -- rotation totale pendant la chute et les rebonds
	local function at(height: number, spin: number)
		bag:PivotTo(CFrame.new(feet + Vector3.new(0, foot + height, 0)) * facing * CFrame.Angles(0, turn - spin, 0))
	end
	task.spawn(function()
		local alive = function(): boolean
			return bag.Parent ~= nil
		end
		-- chute, deux rebonds, rotation courte
		run(0.32, function(a)
			at(6 * (1 - a * a), a * math.pi * 0.8)
		end, alive)
		if not alive() then
			return
		end
		ring(feet, 2.4, PALETTE.Dust, 0.35)
		AudioController.Play("Impact", { Position = feet, Pitch = 1.25, Volume = 0.7 })
		run(0.26, function(a)
			at(1.3 * 4 * a * (1 - a), math.pi * (0.8 + 0.25 * a))
		end, alive)
		run(0.16, function(a)
			at(0.4 * 4 * a * (1 - a), math.pi * (1.05 + 0.1 * a))
		end, alive)
		if not alive() then
			return
		end
		at(0, math.pi * 1.15)
		droplets(feet + Vector3.new(0, 1.2, 0), PALETTE.Spark, 6, 1.6, 0.45, 0.35)
		-- petite lueur pulsée tant que le sac est là (coupée à sa destruction)
		local start = os.clock()
		while alive() do
			light.Brightness = 1.2 + 0.8 * math.sin((os.clock() - start) * 4)
			RunService.Heartbeat:Wait()
		end
	end)
end

-- Retire les sacs (Continuer sur l'écran de fin, nouveau combat, départ).
function EnemyPresentationController.ClearBags()
	for _, bag in bags do
		bag:Destroy()
	end
	table.clear(bags)
end

-- Objets de présentation encore présents (contrôle de nettoyage).
function EnemyPresentationController.Leftovers(): number
	local folder = Workspace:FindFirstChild("PresentationCombat_" .. Players.LocalPlayer.UserId)
	return if folder then #folder:GetChildren() else 0
end

return EnemyPresentationController
