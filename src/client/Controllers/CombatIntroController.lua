--!strict
-- Mise en scène de l'entrée en combat (purement visuelle, côté client, sans toucher à la caméra).
--   1. L'étendard du royaume tombe du ciel et se plante sur Emplacements.PointEtendard (onde de choc),
--      au milieu du champ de bataille ; il s'enfonce dans le sol une fois tous les ennemis en place.
--   2. Les héros se matérialisent en silhouettes dorées sur les cases taguées "CaseHeros".
--   3. Les ennemis sortent du décor de la zone, depuis les repères de Zones.<Zone>.SourcesEnnemis :
--        attribut Mode = SautMare | SautPlateau | DescenteRampe | SortieTente | SortieBuisson | SautTour
--        enfants optionnels "Etape1", "Etape2"... = points de passage avant d'aller au front.
--      Ils se placent dans la zone "FrontEnnemi", face aux héros.
-- Déclenchement (arène taguée "AreneCombat") :
--   • attribut IntroDemo (nombre) : chaque changement rejoue l'intro ;
--   • attribut IntroDemoBoucle (booléen, Studio uniquement) : rejoue en boucle.
-- Attribut VitesseCombat (1 ou 2) : accélère toute la séquence.
-- Prototype : la vague d'ennemis est une vague de démonstration, le futur CombatService la fournira.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TAG_ARENE = "AreneCombat"
local TAG_CASE = "CaseHeros"
local TAG_BUISSON = "BuissonEmbuscade"
local TAG_APERCU = "ApercuStudio"
local BOUCLE_DELAI = 12

local OR = Color3.fromRGB(255, 205, 80)
local ROUGE = Color3.fromRGB(230, 90, 70)

type Wave = { { type: string, mode: string } }

local DEMO_WAVE: Wave = {
	{ type = "Slime", mode = "SautMare" },
	{ type = "Gobelin", mode = "SautPlateau" },
	{ type = "Slime", mode = "SautMare" },
	{ type = "Gobelin", mode = "SortieBuisson" },
	{ type = "Gobelin", mode = "DescenteRampe" },
	{ type = "Gobelin", mode = "SortieTente" },
	{ type = "Boss", mode = "SautTour" },
}

-- positions au front (repère de la pièce FrontEnnemi, +Z = côté héros)
local FRONT_SLOTS = {
	Vector3.new(-9, 0, 4), Vector3.new(-3, 0, 4.5), Vector3.new(3, 0, 4.5), Vector3.new(9, 0, 4),
	Vector3.new(-6, 0, -1), Vector3.new(6, 0, -1),
}
local BOSS_SLOT = Vector3.new(0, 0, -5)

local CombatIntroController = {}

local templates: Folder? = nil
local running: { [Instance]: Folder } = {}

------------------------------------------------------------------ outils

local function speedOf(arena: Instance): number
	local v = arena:GetAttribute("VitesseCombat")
	return if typeof(v) == "number" and v > 0 then v else 1
end

-- appelle step(alpha) pendant `duration` secondes, puis step(1)
local function run(duration: number, step: (number) -> ())
	if duration <= 0 then
		step(1)
		return
	end
	local start = os.clock()
	while true do
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

local function groundY(p: BasePart): number
	return p.Position.Y - p.Size.Y / 2
end

-- modèle de personnage : pivot = HumanoidRootPart, décalage pieds → racine
type Actor = { model: Model, foot: number }

local function spawnActor(name: string, parent: Instance): Actor?
	local folder = templates
	local template = folder and folder:FindFirstChild(name)
	if not template or not template:IsA("Model") then
		warn(`[CombatIntro] Modèle introuvable : {name}`)
		return nil
	end
	local model = template:Clone()
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		model.PrimaryPart = root
		root.Anchored = true
	end
	local minY = math.huge
	for _, p in parts(model) do
		p.CanCollide = false
		minY = math.min(minY, p.Position.Y - p.Size.Y / 2)
	end
	local pivotY = model:GetPivot().Position.Y
	model.Parent = parent
	return { model = model, foot = pivotY - minY }
end

local function placeActor(actor: Actor, feet: Vector3, lookAt: Vector3)
	local pos = feet + Vector3.new(0, actor.foot, 0)
	local target = Vector3.new(lookAt.X, pos.Y, lookAt.Z)
	if (target - pos).Magnitude < 1e-3 then
		target = pos + Vector3.new(0, 0, -1)
	end
	actor.model:PivotTo(CFrame.lookAt(pos, target))
end

type Look = { part: BasePart, color: Color3, material: Enum.Material, transparency: number }

local function snapshot(model: Model): ({ Look }, { Decal })
	local looks, decals = {}, {}
	for _, p in parts(model) do
		table.insert(looks, { part = p, color = p.Color, material = p.Material, transparency = p.Transparency })
	end
	for _, d in model:GetDescendants() do
		if d:IsA("Decal") then
			table.insert(decals, d)
		end
	end
	return looks, decals
end

local function setVisible(model: Model, alpha: number)
	for _, p in parts(model) do
		if p.Name ~= "HumanoidRootPart" then
			p.LocalTransparencyModifier = 1 - alpha
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("Decal") then
			d.LocalTransparencyModifier = 1 - alpha
		end
	end
end

local function effectPart(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

-- onde de choc au sol (anneau qui s'élargit et s'efface)
local function shockwave(parent: Instance, center: Vector3, radius: number, color: Color3, duration: number)
	task.spawn(function()
		local ring = effectPart(parent, { Shape = Enum.PartType.Cylinder, Color = color, Transparency = 0.2 })
		run(duration, function(a)
			local r = 1 + (radius - 1) * (1 - (1 - a) ^ 3)
			ring.Size = Vector3.new(0.15, r * 2, r * 2)
			ring.CFrame = CFrame.new(center + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
			ring.Transparency = 0.2 + 0.8 * a
		end)
		ring:Destroy()
	end)
end

-- petites boules qui jaillissent (poussière, éclaboussures)
local function burst(parent: Instance, center: Vector3, color: Color3, count: number, spread: number, duration: number)
	task.spawn(function()
		local balls = {}
		for i = 1, count do
			local a = (i / count) * math.pi * 2 + math.random() * 0.5
			local dir = Vector3.new(math.cos(a), 0, math.sin(a)) * spread * (0.6 + math.random() * 0.6)
			local b = effectPart(parent, { Shape = Enum.PartType.Ball, Material = Enum.Material.SmoothPlastic, Color = color, Size = Vector3.one * 0.6 })
			table.insert(balls, { part = b, dir = dir, up = 2 + math.random() * 3 })
		end
		run(duration, function(a)
			for _, b in balls do
				local h = b.up * 4 * a * (1 - a)
				b.part.Position = center + b.dir * a + Vector3.new(0, 0.3 + h, 0)
				b.part.Size = Vector3.one * (0.6 + a * 0.8)
				b.part.Transparency = a
			end
		end)
		for _, b in balls do
			b.part:Destroy()
		end
	end)
end

-- saut en arc d'un acteur
local function jump(actor: Actor, from: Vector3, to: Vector3, height: number, duration: number, lookAt: Vector3)
	local flat = (to - from) * Vector3.new(1, 0, 1)
	run(duration, function(a)
		local p = from:Lerp(to, a) + Vector3.new(0, 4 * height * a * (1 - a), 0)
		-- regarde dans le sens du saut, puis se tourne vers l'adversaire en fin de course
		local look = if flat.Magnitude > 0.5 and a < 0.8 then p + flat.Unit * 5 else lookAt
		placeActor(actor, p, look)
	end)
end

-- marche le long d'une liste de points (petit rebond de pas)
local function walk(actor: Actor, points: { Vector3 }, speed: number, finalLook: Vector3)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local dist = (b - a).Magnitude
		local look = if i == #points - 1 then finalLook else b
		run(dist / speed, function(t)
			local p = a:Lerp(b, t)
			local bob = math.abs(math.sin(t * dist * 1.4)) * 0.25
			placeActor(actor, p + Vector3.new(0, bob, 0), if (b - a).Magnitude > 0.1 then p + (b - a).Unit * 5 else look)
		end)
	end
	placeActor(actor, points[#points], finalLook)
end

local function waypoints(source: BasePart): { Vector3 }
	local list = {}
	local i = 1
	while true do
		local step = source:FindFirstChild("Etape" .. i)
		if not step or not step:IsA("BasePart") then
			break
		end
		table.insert(list, step.Position)
		i += 1
	end
	return list
end

-- buissons proches d'une source : tremblement + yeux lumineux
local function shakeBushes(parent: Instance, center: Vector3, duration: number)
	local near = {}
	for _, bush in CollectionService:GetTagged(TAG_BUISSON) do
		if bush:IsA("BasePart") and (bush.Position - center).Magnitude < 5 then
			table.insert(near, { part = bush, base = bush.CFrame })
		end
	end
	local eyes = {}
	for _, s in { -1, 1 } do
		table.insert(eyes, effectPart(parent, { Shape = Enum.PartType.Ball, Color = Color3.fromRGB(255, 230, 90), Size = Vector3.one * 0.35, Position = center + Vector3.new(s * 0.35, 1.2, 0), Transparency = 1 }))
	end
	run(duration, function(a)
		for _, b in near do
			local k = 0.12 * (1 - a * 0.3)
			b.part.CFrame = b.base * CFrame.new(math.sin(os.clock() * 45) * k, 0, math.cos(os.clock() * 38) * k)
		end
		for _, e in eyes do
			e.Transparency = if a > 0.3 then 0 else 1
		end
	end)
	for _, b in near do
		b.part.CFrame = b.base
	end
	for _, e in eyes do
		e:Destroy()
	end
end

------------------------------------------------------------------ séquence

local function activeZone(arena: Instance): Instance?
	local zones = arena:FindFirstChild("Zones")
	if not zones then
		return nil
	end
	for _, z in zones:GetChildren() do
		if z:FindFirstChild("SourcesEnnemis") then
			return z
		end
	end
	return nil
end

local function setApercuHidden(hidden: boolean)
	for _, apercu in CollectionService:GetTagged(TAG_APERCU) do
		for _, d in apercu:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				(d :: any).LocalTransparencyModifier = if hidden then 1 else 0
			end
		end
	end
end

local function spawnBanner(arena: Instance, stage: Folder, speed: number): Model?
	local emplacements = arena:FindFirstChild("Emplacements")
	local point = emplacements and emplacements:FindFirstChild("PointEtendard")
	local template = templates and templates:FindFirstChild("Etendard_Niveau1")
	if not point or not point:IsA("BasePart") or not template or not template:IsA("Model") then
		return nil
	end
	local banner = template:Clone()
	local flutter = {}
	for _, d in banner:GetDescendants() do
		if CollectionService:HasTag(d, "DrapeauFlotte") then
			CollectionService:RemoveTag(d, "DrapeauFlotte") -- remis après l'impact, sinon l'ancrage serait pris en l'air
			table.insert(flutter, d)
		end
	end
	local debris = {}
	for _, p in parts(banner) do
		if p.Name == "Debris" then
			p.LocalTransparencyModifier = 1
			table.insert(debris, p)
		end
	end
	local target = CFrame.new(point.Position) * point.CFrame.Rotation
	banner:PivotTo(target + Vector3.new(0, 45, 0))
	banner.Parent = stage
	run(0.45 / speed, function(a)
		banner:PivotTo(target * CFrame.Angles(0, 0, math.rad(12 * (1 - a))) + Vector3.new(0, 45 * (1 - a * a), 0))
	end)
	for _, p in debris do
		p.LocalTransparencyModifier = 0
	end
	shockwave(stage, point.Position, 26, OR, 0.7 / speed)
	burst(stage, point.Position, Color3.fromRGB(210, 190, 150), 10, 5, 0.6 / speed)
	for _, d in flutter do
		CollectionService:AddTag(d, "DrapeauFlotte")
	end
	return banner
end

local function spawnHeroes(arena: Instance, stage: Folder, speed: number, facing: Vector3)
	local cases = {}
	for _, c in CollectionService:GetTagged(TAG_CASE) do
		if c:IsDescendantOf(arena) then
			table.insert(cases, c)
		end
	end
	table.sort(cases, function(a, b)
		return (a:GetAttribute("Slot") or 0) < (b:GetAttribute("Slot") or 0)
	end)
	for _, case in cases do
		local pose = case:FindFirstChild("PointDePose")
		if pose and pose:IsA("BasePart") then
			task.spawn(function()
				local actor = spawnActor("MannequinHeros", stage)
				if not actor then
					return
				end
				local feet = Vector3.new(pose.Position.X, groundY(pose) + 0.1, pose.Position.Z)
				local looks, decals = snapshot(actor.model)
				for _, l in looks do
					l.part.Material = Enum.Material.Neon
					l.part.Color = OR
				end
				for _, d in decals do
					d.Transparency = 1
				end
				local beam = effectPart(stage, { Shape = Enum.PartType.Cylinder, Color = OR, Transparency = 0.4 })
				run(0.3 / speed, function(a)
					placeActor(actor, feet + Vector3.new(0, -1.2 * (1 - a), 0), feet + facing)
					setVisible(actor.model, a)
					beam.Size = Vector3.new(9, 3 * (1 - a) + 0.3, 3 * (1 - a) + 0.3)
					beam.CFrame = CFrame.new(feet + Vector3.new(0, 4.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
					beam.Transparency = 0.4 + 0.6 * a
				end)
				beam:Destroy()
				run(0.45 / speed, function(a)
					for _, l in looks do
						l.part.Color = OR:Lerp(l.color, a)
					end
				end)
				for _, l in looks do
					l.part.Material = l.material
					l.part.Color = l.color
				end
				for _, d in decals do
					d.Transparency = 0
				end
			end)
			task.wait(0.15 / speed)
		end
	end
end

local function enemyEntrance(stage: Folder, source: BasePart, typ: string, dest: Vector3, facing: Vector3, speed: number)
	local mode = source:GetAttribute("Mode")
	local name = if typ == "Boss" then "MannequinBoss" elseif typ == "Slime" then "MannequinSlime" else "MannequinGobelin"
	local actor = spawnActor(name, stage)
	if not actor then
		return
	end
	local start = Vector3.new(source.Position.X, groundY(source) + source.Size.Y / 2, source.Position.Z)
	local path = waypoints(source)
	table.insert(path, 1, start)
	table.insert(path, dest)

	if mode == "SautMare" then
		setVisible(actor.model, 1)
		placeActor(actor, start - Vector3.new(0, 4, 0), dest)
		burst(stage, start, Color3.fromRGB(150, 215, 250), 9, 3, 0.6 / speed)
		run(0.2 / speed, function(a)
			placeActor(actor, start - Vector3.new(0, 4 * (1 - a), 0), dest)
		end)
		jump(actor, start, dest, 6, 0.75 / speed, facing)
	elseif mode == "SautPlateau" then
		setVisible(actor.model, 0)
		placeActor(actor, start, dest)
		run(0.2 / speed, function(a)
			setVisible(actor.model, a)
		end)
		task.wait(0.15 / speed)
		jump(actor, start, dest, 5, 0.8 / speed, facing)
		burst(stage, dest, Color3.fromRGB(210, 190, 150), 6, 2, 0.4 / speed)
	elseif mode == "SortieBuisson" then
		setVisible(actor.model, 0)
		shakeBushes(stage, start, 0.7 / speed)
		placeActor(actor, start, dest)
		setVisible(actor.model, 1)
		jump(actor, start, dest, 3, 0.6 / speed, facing)
	elseif mode == "SautTour" then
		setVisible(actor.model, 0)
		placeActor(actor, start, dest)
		run(0.3 / speed, function(a)
			setVisible(actor.model, a)
		end)
		task.wait(0.4 / speed)
		jump(actor, start, dest, 10, 1.1 / speed, facing)
		shockwave(stage, dest, 16, ROUGE, 0.6 / speed)
		burst(stage, dest, Color3.fromRGB(210, 190, 150), 12, 4, 0.6 / speed)
	else -- DescenteRampe, SortieTente, et tout mode inconnu : apparaît puis marche
		setVisible(actor.model, 0)
		placeActor(actor, start, path[2] or dest)
		run(0.25 / speed, function(a)
			setVisible(actor.model, a)
		end)
		walk(actor, path, 16 * speed, facing)
	end
	placeActor(actor, dest, facing)
end

local function spawnEnemies(arena: Instance, stage: Folder, speed: number, facing: Vector3)
	local zone = activeZone(arena)
	local folder = zone and zone:FindFirstChild("SourcesEnnemis")
	local front = folder and folder:FindFirstChild("FrontEnnemi")
	if not folder or not front or not front:IsA("BasePart") then
		return
	end
	local byMode: { [string]: { BasePart } } = {}
	for _, s in folder:GetChildren() do
		local mode = s:GetAttribute("Mode")
		if s:IsA("BasePart") and typeof(mode) == "string" then
			byMode[mode] = byMode[mode] or {}
			table.insert(byMode[mode], s)
		end
	end
	local used: { [string]: number } = {}
	local slot = 0
	local pending = 0
	local frontY = groundY(front)
	for _, entry in DEMO_WAVE do
		local list = byMode[entry.mode]
		if list and #list > 0 then
			used[entry.mode] = (used[entry.mode] or 0) % #list + 1
			local source = list[used[entry.mode]]
			local offset
			if entry.type == "Boss" then
				offset = BOSS_SLOT
			else
				slot += 1
				offset = FRONT_SLOTS[(slot - 1) % #FRONT_SLOTS + 1]
			end
			local p = (front.CFrame * CFrame.new(offset)).Position
			local dest = Vector3.new(p.X, frontY, p.Z)
			pending += 1
			task.spawn(function()
				enemyEntrance(stage, source, entry.type, dest, facing, speed)
				pending -= 1
			end)
			task.wait((if entry.type == "Boss" then 0.6 else 0.3) / speed)
		end
	end
	-- attend que tous les ennemis soient en place
	while pending > 0 and stage.Parent do
		RunService.Heartbeat:Wait()
	end
end

-- l'étendard s'enfonce dans le sol et s'efface quand le combat commence
local function removeBanner(banner: Model?, stage: Folder, speed: number)
	if not banner or not banner.Parent then
		return
	end
	for _, d in banner:GetDescendants() do
		CollectionService:RemoveTag(d, "DrapeauFlotte") -- sinon le tissu resterait accroché à sa position d'ondulation
	end
	local base = banner:GetPivot()
	burst(stage, base.Position, Color3.fromRGB(210, 190, 150), 8, 3, 0.5 / speed)
	run(0.6 / speed, function(a)
		banner:PivotTo(base - Vector3.new(0, 4 * a * a, 0))
		for _, p in parts(banner) do
			p.LocalTransparencyModifier = a
		end
	end)
	banner:Destroy()
end

function CombatIntroController:Play(arena: Instance)
	local previous = running[arena]
	if previous then
		previous:Destroy()
	end
	local stage = Instance.new("Folder")
	stage.Name = "IntroCombat"
	stage.Parent = Workspace
	running[arena] = stage
	setApercuHidden(true)

	local speed = speedOf(arena)
	local emplacements = arena:FindFirstChild("Emplacements")
	local bannerPoint = emplacements and emplacements:FindFirstChild("PointEtendard")
	local zone = activeZone(arena)
	local sources = zone and zone:FindFirstChild("SourcesEnnemis")
	local front = sources and sources:FindFirstChild("FrontEnnemi")
	local heroesFace = if front and front:IsA("BasePart") then front.Position else Vector3.zero
	-- les ennemis regardent le centre de la formation des héros
	local sum, n = Vector3.zero, 0
	for _, c in CollectionService:GetTagged(TAG_CASE) do
		local pose = c:IsDescendantOf(arena) and c:FindFirstChild("PointDePose")
		if pose and pose:IsA("BasePart") then
			sum += pose.Position
			n += 1
		end
	end
	local enemiesFace = if n > 0 then sum / n elseif bannerPoint and bannerPoint:IsA("BasePart") then bannerPoint.Position else Vector3.zero

	local banner = spawnBanner(arena, stage, speed)
	task.wait(0.15 / speed)
	spawnHeroes(arena, stage, speed, heroesFace)
	task.wait(0.5 / speed)
	spawnEnemies(arena, stage, speed, enemiesFace)
	task.wait(0.5 / speed)
	removeBanner(banner, stage, speed)
end

function CombatIntroController:Init()
	templates = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Combat") :: Folder
end

local function watch(arena: Instance)
	arena:GetAttributeChangedSignal("IntroDemo"):Connect(function()
		task.spawn(CombatIntroController.Play, CombatIntroController, arena)
	end)
	if RunService:IsStudio() then
		task.spawn(function()
			while arena.Parent do
				if arena:GetAttribute("IntroDemoBoucle") == true then
					task.spawn(CombatIntroController.Play, CombatIntroController, arena)
					task.wait(BOUCLE_DELAI / speedOf(arena))
				else
					task.wait(1)
				end
			end
		end)
	end
end

function CombatIntroController:Start()
	for _, arena in CollectionService:GetTagged(TAG_ARENE) do
		watch(arena)
	end
	CollectionService:GetInstanceAddedSignal(TAG_ARENE):Connect(watch)
end

return CombatIntroController
