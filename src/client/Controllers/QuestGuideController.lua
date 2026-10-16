--!strict
-- Guidage du tutoriel (voir docs/QUESTS.md § Guidage), purement visuel, côté client.
-- La quête active (Remotes.GetActiveQuest / QuestChanged) peut porter GuideTarget (QuestConfig.Guide) :
--   joueur → boules lumineuses dorées (asset Assets.Guide.OrbeGuide) qui flottent un peu au-dessus du sol,
--   régulièrement espacées, avec une vague de lumière qui « avance » vers la cible → la cible elle-même
--   pulse (WorldPulse : voile doré qui respire, lumière, étincelles). Aucune pancarte « OBJECTIF ».
-- GuidePlacement (quête DefendDomain) : tant qu'aucun héros n'est posé, une fois arrivé à l'arène, le
--   guidage apprend la pose : le héros à prendre pulse dans la hotbar (ArenaStore.guide.hotbar) et la dalle
--   ArenaConfig.PlacementSlot pulse ; le joueur pose lui-même (hotbar puis E). Un héros posé : la pancarte
--   pulse de nouveau, la fenêtre Expédition et la pastille « F · Lancer » mettent « Lancer » en avant
--   (ArenaStore.guide.expedition).
-- La cible est toujours résolue dans le plot du joueur local (PlotView + Shared.Quests.QuestGuide),
-- jamais Workspace.PlotTravail ni le plot d'un autre joueur.
-- Masqué pendant le combat, l'outro, les écrans (récompenses, invocation, stages), quête terminée ; près
-- de la cible le chemin s'efface (la cible pulse plus fort) et l'interaction normale (E) prend le relais.
-- Chemin : PathfindingService (client), recalculé seulement si la cible change, si le joueur s'est assez
-- déplacé, ou si le chemin a échoué ; rayon vers le sol pour chaque boule. 10 boules au plus.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)
local QuestGuide = require(ReplicatedStorage.Shared.Quests.QuestGuide)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local ArenaStore = require(script.Parent.Parent.Arena.ArenaStore)
local PlotView = require(script.Parent.Parent.Arena.PlotView)
local ScreenState = require(script.Parent.Parent.UI.ScreenState)
local WorldPulse = require(script.Parent.Parent.UI.WorldPulse)

local QuestGuideController = {}

local REFRESH = 0.2 -- s entre deux décisions (mode, cible)
local MARKS = 10 -- boules visibles au plus, devant le joueur
local SPACING = 4.5 -- studs entre deux boules
local SKIP = 3.5 -- studs devant le joueur avant la première boule
local HOVER = 1.6 -- hauteur des boules au-dessus du sol (studs)
local BOB = 0.25 -- amplitude du flottement (studs)
local REPATH_DISTANCE = 6 -- studs parcourus avant de recalculer le chemin
local REPATH_RETRY = 3 -- s avant de réessayer un chemin qui a échoué
local GOAL_OFFSET = 3.5 -- studs devant la cible (côté joueur) : point d'arrivée accessible
local ARENA_NEAR = 30 -- studs autour de la dalle du tutoriel : le joueur est « à l'arène »
local TAG_CASE = "CaseHeros"

local quest: { [string]: any }? = nil
local folder: Folder? = nil
local marks: { Model } = {}
-- Cibles qui pulsent : la cible de la quête (portail, pancarte) et la dalle du tutoriel.
local targetPulse: { instance: Instance, pulse: WorldPulse.Pulse }? = nil
local slabPulse: { instance: Instance, pulse: WorldPulse.Pulse }? = nil
local path: { Vector3 } = {}
local pathOrigin: Vector3? = nil
local pathTarget: Instance? = nil
local pathFailedAt = -math.huge
local computing = false
local mode = "Hidden"

------------------------------------------------------------------ objets locaux

local function guideFolder(): Folder
	local existing = folder
	if existing and existing.Parent then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "GuideQuete_" .. Players.LocalPlayer.UserId
	created.Parent = Workspace
	folder = created
	return created
end

-- Boule lumineuse : asset Studio Assets.Guide.OrbeGuide (cœur doré, halo, reflet, lumière douce) ;
-- à défaut, une boule dorée simple (le guidage ne doit jamais disparaître faute d'asset).
local function orb(): Model
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local guide = assets and assets:FindFirstChild("Guide")
	local template = guide and guide:FindFirstChild("OrbeGuide")
	local model: Model
	if template and template:IsA("Model") then
		model = template:Clone()
	else
		model = Instance.new("Model")
		local core = Instance.new("Part")
		core.Name = "Coeur"
		core.Shape = Enum.PartType.Ball
		core.Size = Vector3.one * 1.1
		core.Color = UITheme.Colors.GoldLight
		core.Material = Enum.Material.Neon
		core.Parent = model
		model.PrimaryPart = core
	end
	model.Name = "Orbe"
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
			part.CastShadow = false
		end
	end
	return model
end

local bases: { [Model]: Vector3 } = {}

local function hideMarks()
	for _, mark in marks do
		mark.Parent = nil
	end
end

local function clearMarks()
	for _, mark in marks do
		mark:Destroy()
	end
	table.clear(marks)
	table.clear(bases)
end

-- Fait pulser `instance` (nil : plus rien) ; une seule cible par emplacement, recréée si elle change.
local function setPulse(current: { instance: Instance, pulse: WorldPulse.Pulse }?, instance: Instance?, focus: Instance?): { instance: Instance, pulse: WorldPulse.Pulse }?
	if current and current.instance == instance and instance and instance.Parent then
		return current
	end
	if current then
		current.pulse.stop()
	end
	if not instance then
		return nil
	end
	return { instance = instance, pulse = WorldPulse.start(instance, focus) }
end

local function showTarget(target: Instance?, focus: Instance?, near: boolean)
	targetPulse = setPulse(targetPulse, target, focus)
	local current = targetPulse
	if current then
		current.pulse.setNear(near) -- arrivé : la cible respire plus fort, le chemin s'efface
	end
end

local function showSlab(slab: Instance?, pose: Instance?, held: boolean)
	slabPulse = setPulse(slabPulse, slab, pose)
	local current = slabPulse
	if current then
		current.pulse.setNear(true)
		-- héros en main : la dalle a déjà sa lumière de placement, on garde la lueur et les étincelles
		current.pulse.setHighlight(not held)
	end
end

-- Dalle du tutoriel (ArenaConfig.PlacementSlot) de l'arène du joueur local, sinon la première dalle
-- libre ; nil si l'arène n'est pas encore répliquée.
local function tutorialSlab(): (Instance?, BasePart?)
	local arena = PlotView.arena()
	if not arena then
		return nil, nil
	end
	local formation = ArenaStore.formation()
	local best: Instance?, bestPose: BasePart?, bestSlot = nil, nil, math.huge
	for _, case in CollectionService:GetTagged(TAG_CASE) do
		local slot = case:GetAttribute("Slot")
		local pose = case:FindFirstChild("PointDePose", true)
		if case:IsDescendantOf(arena) and typeof(slot) == "number" and not formation[slot] and pose and pose:IsA("BasePart") then
			local rank = if slot == ArenaConfig.PlacementSlot then 0 else slot
			if rank < bestSlot then
				best, bestPose, bestSlot = case, pose, rank
			end
		end
	end
	return best, bestPose
end

-- Distance horizontale entre le personnage et la dalle la plus proche de SON arène (math.huge sans arène).
local function arenaDistance(root: BasePart): number
	local arena = PlotView.arena()
	local best = math.huge
	if not arena then
		return best
	end
	for _, case in CollectionService:GetTagged(TAG_CASE) do
		local pose = case:FindFirstChild("PointDePose", true)
		if case:IsDescendantOf(arena) and pose and pose:IsA("BasePart") then
			best = math.min(best, ((pose.Position - root.Position) * Vector3.new(1, 0, 1)).Magnitude)
		end
	end
	return best
end

-- Premier héros de la hotbar (celui à poser).
local function heroToPlace(): string?
	for _, id in ArenaStore.hotbar do
		if id ~= "" and ArenaStore.heroes[id] then
			return id
		end
	end
	return nil
end

------------------------------------------------------------------ chemin

local function rootPart(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function focusPosition(focus: Instance): Vector3?
	if focus:IsA("BasePart") then
		return focus.Position
	elseif focus:IsA("Model") then
		return focus:GetPivot().Position
	end
	return nil
end

local function goalFor(focus: Instance, from: Vector3): Vector3?
	local center = focusPosition(focus)
	if not center then
		return nil
	end
	local toward = (from - center) * Vector3.new(1, 0, 1)
	return center + (if toward.Magnitude > 0.1 then toward.Unit * GOAL_OFFSET else Vector3.zero)
end

local function computePath(root: BasePart, target: Instance, focus: Instance)
	if computing then
		return
	end
	local goal = goalFor(focus, root.Position)
	if not goal then
		return
	end
	computing = true
	task.spawn(function()
		local from = root.Position
		local route = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 4 })
		local ok = pcall(function()
			route:ComputeAsync(from, goal)
		end)
		local points: { Vector3 } = {}
		if ok and route.Status == Enum.PathStatus.Success then
			for _, waypoint in route:GetWaypoints() do
				table.insert(points, waypoint.Position)
			end
		else
			-- pas de chemin calculable : ligne droite (le joueur sait au moins dans quelle direction aller)
			points = { from, goal }
			pathFailedAt = os.clock()
		end
		path, pathOrigin, pathTarget = points, from, target
		computing = false
	end)
end

-- Reste du chemin à partir du point le plus proche du joueur.
local function remaining(from: Vector3): { Vector3 }
	local best, bestDistance = 1, math.huge
	for index, point in path do
		local d = ((point - from) * Vector3.new(1, 0, 1)).Magnitude
		if d < bestDistance then
			best, bestDistance = index, d
		end
	end
	local points = { from }
	for index = best + 1, #path do
		table.insert(points, path[index])
	end
	return points
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function groundAt(position: Vector3): Vector3?
	local exclude: { Instance } = { guideFolder() }
	local character = Players.LocalPlayer.Character
	if character then
		table.insert(exclude, character)
	end
	rayParams.FilterDescendantsInstances = exclude
	local hit = Workspace:Raycast(position + Vector3.new(0, 6, 0), Vector3.new(0, -20, 0), rayParams)
	return if hit then hit.Position else nil
end

local function placeMarks(from: Vector3)
	local samples = QuestGuide.sample(remaining(from), SPACING, SKIP, MARKS)
	local parent = guideFolder()
	for index, sample in samples do
		local mark = marks[index]
		if not mark then
			mark = orb()
			marks[index] = mark
		end
		local ground = groundAt(sample.position)
		if ground then
			local base = ground + Vector3.new(0, HOVER, 0)
			bases[mark] = base
			mark:PivotTo(CFrame.new(base))
			mark.Parent = parent
		else
			mark.Parent = nil -- pas de sol sous ce point : pas de boule perdue dans le vide
		end
	end
	for index = #samples + 1, #marks do
		marks[index].Parent = nil
	end
end

-- Les boules flottent doucement ; une vague de lumière avance vers la cible (boules plus loin = plus tard).
local function pulse(now: number)
	for index, mark in marks do
		local base = bases[mark]
		if mark.Parent and base then
			local wave = 0.5 + 0.5 * math.sin(now * 4 - index * 0.7)
			mark:PivotTo(CFrame.new(base + Vector3.new(0, BOB * math.sin(now * 2.5 + index * 0.6), 0)))
			local halo = mark:FindFirstChild("Halo")
			if halo and halo:IsA("BasePart") then
				halo.Transparency = 0.75 - 0.3 * wave
			end
			local light = mark:FindFirstChildWhichIsA("PointLight", true)
			if light then
				light.Brightness = 0.6 + 1.0 * wave
			end
		end
	end
end

------------------------------------------------------------------ décision

local function update()
	local view = quest
	local plot = PlotView.plot() -- plot du joueur local uniquement
	local targetName = view and view.GuideTarget
	local target, focus = QuestGuide.resolve(plot, targetName)
	local root = rootPart()
	local distance: number? = nil
	if root and focus then
		local center = focusPosition(focus)
		distance = if center then ((center - root.Position) * Vector3.new(1, 0, 1)).Magnitude else nil
	end
	mode = QuestGuide.mode({
		target = if target then targetName else nil,
		completed = view and view.Completed == true,
		-- outro et écran de fin d'un combat qui vient de finir : rien par-dessus
		combat = ArenaStore.inCombat() or ArenaStore.awaitingResult,
		screen = ScreenState.current(),
		distance = distance,
	})
	-- Apprendre la pose (GuidePlacement) : aucun héros posé, un héros à prendre dans la hotbar.
	local teaching = view ~= nil and view.GuidePlacement == true and mode ~= "Hidden"
	local hero = if teaching and ArenaStore.placedCount() == 0 then heroToPlace() else nil
	local slab, pose = nil, nil
	if hero and root then
		slab, pose = tutorialSlab()
		if not (mode == "Near" or arenaDistance(root) <= ARENA_NEAR) then
			slab, pose = nil, nil -- encore loin : d'abord le chemin vers la pancarte, à l'entrée de l'arène
		end
	end
	local held = ArenaStore.placement.held ~= nil
	ArenaStore.setGuide(if slab and not held then hero else nil, teaching and ArenaStore.placedCount() >= 1)
	if mode == "Hidden" then
		hideMarks()
		showTarget(nil, nil, false)
		showSlab(nil, nil, false)
		if not targetName or (view and view.Completed) then
			clearMarks() -- quête terminée ou sans guidage : plus aucun objet
			path, pathTarget = {}, nil
		end
		return
	end
	if slab then
		-- à l'arène, aucun héros posé : une seule chose à faire, poser le héros (hotbar + dalle)
		hideMarks()
		showTarget(nil, nil, false)
		showSlab(slab, pose, held)
		return
	end
	showSlab(nil, nil, false)
	-- un héros posé, déjà à l'arène : la pancarte pulse, pas de chemin dans l'arène (F lance aussi)
	local inArena = teaching and root ~= nil and arenaDistance(root) <= ARENA_NEAR
	showTarget(target, focus, mode == "Near" or inArena)
	if mode == "Near" or inArena then
		hideMarks() -- arrivé : le chemin s'efface, l'interaction normale (E) prend le relais
		return
	end
	if root and target and focus then
		local moved = if pathOrigin then (root.Position - pathOrigin).Magnitude else math.huge
		local stale = pathTarget ~= target or #path == 0 or moved > REPATH_DISTANCE
		local failed = os.clock() - pathFailedAt < REPATH_RETRY
		if stale and not (failed and pathTarget == target and moved <= REPATH_DISTANCE) then
			computePath(root, target, focus)
		end
		if #path > 0 and pathTarget == target then
			placeMarks(root.Position)
		end
	end
end

local function setQuest(view: any)
	quest = if typeof(view) == "table" then view else nil
	update()
end

function QuestGuideController:Start()
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= REFRESH then
			elapsed = 0
			update()
		end
		if mode == "Path" then
			pulse(os.clock())
		end
	end)
	ScreenState.changed.Event:Connect(update)
	ArenaStore.changed.Event:Connect(update)
	Players.LocalPlayer.CharacterAdded:Connect(function()
		path, pathOrigin = {}, nil -- respawn : nouveau chemin depuis le nouveau point de départ
	end)
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local changed = remotes:WaitForChild("QuestChanged", 30)
	if changed and changed:IsA("RemoteEvent") then
		changed.OnClientEvent:Connect(setQuest)
	end
	local get = remotes:WaitForChild("GetActiveQuest", 30)
	if get and get:IsA("RemoteFunction") then
		local ok, view = pcall(function()
			return get:InvokeServer()
		end)
		if ok then
			setQuest(view)
		end
	end
end

return QuestGuideController
