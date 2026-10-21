--!strict
-- Décor vivant des arènes de zone (purement visuel, côté client). Voir docs/ZONES.md § Cité Engloutie.
--
-- Progression par stage : l'arène porte l'attribut StageDecor (stage choisi, posé par ArenaService ; absent =
-- 1). Tout Model / BasePart du décor qui porte StageMin et/ou StageMax n'est visible que si
-- StageMin <= StageDecor <= StageMax (LocalTransparencyModifier : rien n'est détruit ni répliqué).
--
-- Tags (CollectionService), attributs optionnels :
--   • "PoissonPasse"  (Model ou BasePart) : va et vient le long de son axe avant local, se retourne au bout.
--       Distance (studs, 40), Periode (s, 14), Ondulation (studs, 0.6).
--   • "MeduseFlotte"  : monte et descend en pulsant. Amplitude (2), Periode (5).
--   • "CorailOndule"  : se balance autour de sa base. Amplitude (degrés, 6), Periode (3.5).
--   • "BulleMonte"    (BasePart) : monte de Hauteur studs puis repart d'en bas, en s'effaçant. Hauteur (10), Periode (4).
--   • "GoutteTombe"   (BasePart) : tombe de Hauteur studs (fuite), puis repart d'en haut. Hauteur (8), Periode (1.2).
--   • "VagueBarriere" (BasePart) : la transparence ondule autour de sa valeur d'origine (barrière magique). Periode (4).
--   • "SequenceOeil"  (Model, enfants Silhouette et Oeil) : derrière la baie vitrée du boss, quelque chose passe,
--       revient, puis un œil géant se colle à la vitre, regarde, et repart. Boucle de Periode (40) secondes.
-- Aucune logique gameplay ici.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DISTANCE_MAX = 320

local DecorVivantController = {}

type Entry = { instance: Instance, kind: string, base: CFrame, phase: number, alpha: number }

local entries: { [Instance]: Entry } = {}

local function num(instance: Instance, name: string, default: number): number
	local v = instance:GetAttribute(name)
	return if typeof(v) == "number" then v else default
end

local function pivotOf(instance: Instance): CFrame?
	if instance:IsA("PVInstance") then
		return (instance :: PVInstance):GetPivot()
	end
	return nil
end

local function setPivot(instance: Instance, cf: CFrame)
	if instance:IsA("Model") then
		instance:PivotTo(cf)
	elseif instance:IsA("BasePart") then
		instance.CFrame = cf
	end
end

local function register(instance: Instance, kind: string)
	local base = pivotOf(instance)
	if not base or entries[instance] then
		return
	end
	local alpha = if instance:IsA("BasePart") then instance.Transparency else 0
	entries[instance] = { instance = instance, kind = kind, base = base, alpha = alpha,
		phase = (base.Position.X * 0.37 + base.Position.Z * 0.11) % 10 }
end

local TAGS = { "PoissonPasse", "MeduseFlotte", "CorailOndule", "BulleMonte", "GoutteTombe", "VagueBarriere", "SequenceOeil" }

------------------------------------------------------------------ progression par stage

local function stageOf(instance: Instance): number
	local node: Instance? = instance
	while node do
		local s = node:GetAttribute("StageDecor")
		if typeof(s) == "number" then
			return s
		end
		node = node.Parent
	end
	return 1
end

local function setVisible(root: Instance, visible: boolean)
	local modifier = if visible then 0 else 1
	local function apply(part: Instance)
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = modifier
		elseif part:IsA("Light") then
			part.Enabled = visible
		end
	end
	apply(root)
	for _, d in root:GetDescendants() do
		apply(d)
	end
end

local function refreshStages()
	for _, inst in Workspace:GetDescendants() do
		local min, max = inst:GetAttribute("StageMin"), inst:GetAttribute("StageMax")
		if typeof(min) == "number" or typeof(max) == "number" then
			local stage = stageOf(inst)
			local visible = stage >= (if typeof(min) == "number" then min else -math.huge)
				and stage <= (if typeof(max) == "number" then max else math.huge)
			setVisible(inst, visible)
		end
	end
end

------------------------------------------------------------------ animations

local function eyeSequence(entry: Entry, t: number)
	local model = entry.instance
	local silhouette = model:FindFirstChild("Silhouette")
	local eye = model:FindFirstChild("Oeil")
	local period = num(model, "Periode", 40)
	local u = (t + entry.phase) % period
	local base = entry.base
	-- Silhouette : passe de gauche à droite (0-7 s), revient plus près (10-17 s), sinon hors champ.
	if silhouette and silhouette:IsA("Model") then
		local x, z = 140, 0
		if u < 7 then
			x, z = -70 + 140 * (u / 7), 0
		elseif u >= 10 and u < 17 then
			x, z = 70 - 140 * ((u - 10) / 7), 10
		end
		-- loin derrière la vitre (24 studs), puis plus près au retour
		setPivot(silhouette, base * CFrame.new(x, -1 + math.sin(u * 0.6) * 1.5, -24 + z) * CFrame.Angles(0, if u < 8 then 0 else math.pi, 0))
	end
	-- Œil : s'approche (19-21 s), reste collé à la vitre en regardant (21-30 s), repart (30-33 s).
	if eye and eye:IsA("Model") then
		local depth = 60
		if u >= 19 and u < 21 then
			depth = 60 * (1 - (u - 19) / 2)
		elseif u >= 21 and u < 30 then
			depth = 0
		elseif u >= 30 and u < 33 then
			depth = 60 * ((u - 30) / 3)
		end
		local look = if u >= 21 and u < 30 then math.sin((u - 21) * 0.9) * 0.25 else 0
		setPivot(eye, base * CFrame.new(0, 0, -depth) * CFrame.Angles(0, look, 0))
	end
end

local function step(entry: Entry, t: number)
	local inst = entry.instance
	local p = entry.phase
	local kind = entry.kind
	if kind == "PoissonPasse" then
		local dist, period = num(inst, "Distance", 40), num(inst, "Periode", 14)
		local u = ((t + p) % period) / period -- aller (0-0,5) puis retour
		local x = if u < 0.5 then -dist / 2 + dist * (u * 2) else dist / 2 - dist * ((u - 0.5) * 2)
		local turn = if u < 0.5 then 0 else math.pi
		local wave = math.sin((t + p) * 2.4) * num(inst, "Ondulation", 0.6)
		setPivot(inst, entry.base * CFrame.new(x, wave * 0.4, wave) * CFrame.Angles(0, turn + math.sin((t + p) * 3) * 0.12, 0))
	elseif kind == "MeduseFlotte" then
		local amp, period = num(inst, "Amplitude", 2), num(inst, "Periode", 5)
		local y = math.sin((t + p) * 2 * math.pi / period) * amp
		setPivot(inst, entry.base * CFrame.new(math.sin((t + p) * 0.4) * 0.8, y, 0))
	elseif kind == "CorailOndule" then
		local amp, period = math.rad(num(inst, "Amplitude", 6)), num(inst, "Periode", 3.5)
		local a = math.sin((t + p) * 2 * math.pi / period) * amp
		setPivot(inst, entry.base * CFrame.Angles(a, 0, a * 0.6))
	elseif kind == "BulleMonte" and inst:IsA("BasePart") then
		local h, period = num(inst, "Hauteur", 10), num(inst, "Periode", 4)
		local u = ((t + p) % period) / period
		inst.CFrame = entry.base + Vector3.new(math.sin((t + p) * 3) * 0.3, h * u, 0)
		inst.Transparency = 0.35 + 0.6 * u
	elseif kind == "GoutteTombe" and inst:IsA("BasePart") then
		local h, period = num(inst, "Hauteur", 8), num(inst, "Periode", 1.2)
		local u = ((t + p) % period) / period
		inst.CFrame = entry.base - Vector3.new(0, h * u * u, 0)
		inst.Transparency = 0.2 + 0.7 * u
	elseif kind == "VagueBarriere" and inst:IsA("BasePart") then
		local period = num(inst, "Periode", 4)
		local w = math.sin((t + p) * 2 * math.pi / period)
		inst.Transparency = math.clamp(entry.alpha + 0.08 * w, 0, 0.95)
	elseif kind == "SequenceOeil" then
		eyeSequence(entry, t)
	end
end

function DecorVivantController:Start()
	for _, tag in TAGS do
		for _, inst in CollectionService:GetTagged(tag) do
			register(inst, tag)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(inst)
			register(inst, tag)
		end)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(function(inst)
			entries[inst] = nil
		end)
	end

	-- progression : au démarrage, à chaque changement de stage d'une arène et à chaque nouveau décor
	refreshStages()
	local pending = false
	local function schedule()
		if pending then return end
		pending = true
		task.delay(0.2, function()
			pending = false
			refreshStages()
		end)
	end
	Workspace.DescendantAdded:Connect(function(inst)
		if inst:GetAttribute("StageMin") ~= nil or inst:GetAttribute("StageMax") ~= nil or inst:GetAttribute("ZoneId") ~= nil then
			schedule()
		end
	end)
	for _, arena in Workspace:GetDescendants() do
		if arena.Name == "Arene" then
			arena:GetAttributeChangedSignal("StageDecor"):Connect(schedule)
		end
	end
	Workspace.DescendantAdded:Connect(function(inst)
		if inst.Name == "Arene" then
			inst:GetAttributeChangedSignal("StageDecor"):Connect(schedule)
		end
	end)

	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if not camera then return end
		local eye = camera.CFrame.Position
		local t = os.clock()
		for inst, entry in entries do
			if not inst.Parent then
				entries[inst] = nil
			elseif (entry.base.Position - eye).Magnitude < DISTANCE_MAX then
				step(entry, t)
			end
		end
	end)
end

return DecorVivantController
