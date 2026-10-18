--!strict
-- Guidage du tutoriel (voir docs/QUESTS.md § Guidage), purement visuel, côté client.
-- La quête active (Remotes.GetActiveQuest / QuestChanged) peut porter GuideTarget (QuestConfig.Guide) :
--   joueur → flèches dorées couchées au sol (GuideArrows, même flèche que la flèche UI), régulièrement
--   espacées et tournées vers la suite du chemin, avec une vague qui « avance » vers la cible → la cible
--   elle-même pulse (WorldPulse : voile doré qui respire, lumière, étincelles) et une grosse flèche
--   rebondit au-dessus d'elle (balise visible de loin). Aucune pancarte « OBJECTIF ».
-- GuidePlacement (quête DefendDomain) : tant qu'aucun héros n'est posé, une fois arrivé à l'arène, le
--   guidage apprend la pose : le héros à prendre pulse dans la hotbar (ArenaStore.guide.hotbar) et la dalle
--   ArenaConfig.PlacementSlot pulse, la balise passe au-dessus de la dalle ; le joueur pose lui-même
--   (hotbar puis E). Un héros posé : la pancarte pulse de nouveau, la fenêtre Expédition et la pastille
--   « F · Lancer » mettent « Lancer » en avant (ArenaStore.guide.expedition).
-- La cible est toujours résolue dans le plot du joueur local (PlotView + Shared.Quests.QuestGuide),
-- jamais Workspace.PlotTravail ni le plot d'un autre joueur.
-- Masqué pendant le combat, l'outro, les écrans (récompenses, invocation, stages), quête terminée ; près
-- de la cible le chemin s'efface (la cible pulse plus fort) et l'interaction normale (E) prend le relais.
-- Chemin : PathfindingService (client), recalculé seulement si la cible change, si le joueur s'est assez
-- déplacé, ou si le chemin a échoué ; rayon vers le sol pour chaque flèche. 10 flèches au plus.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)
local QuestGuide = require(ReplicatedStorage.Shared.Quests.QuestGuide)
local ArenaStore = require(script.Parent.Parent.Arena.ArenaStore)
local PlotView = require(script.Parent.Parent.Arena.PlotView)
local ScreenState = require(script.Parent.Parent.UI.ScreenState)
local GuideArrows = require(script.Parent.Parent.UI.GuideArrows)
local WorldPulse = require(script.Parent.Parent.UI.WorldPulse)

local QuestGuideController = {}

local REFRESH = 0.2 -- s entre deux décisions (mode, cible)
local MARKS = 10 -- flèches visibles au plus, devant le joueur
local SPACING = 4.5 -- studs entre deux flèches
local SKIP = 3.5 -- studs devant le joueur avant la première flèche
local HOVER = 0.3 -- hauteur des flèches au-dessus du sol (studs) : posées, sans z-fighting
local LIFT = 0.25 -- petit soulèvement de la flèche au passage de la vague (studs)
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
-- Grosse flèche au-dessus de la cible active (portail, pancarte ou dalle) : une seule.
local beacon: { instance: Instance, beacon: GuideArrows.Beacon }? = nil
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

local bases: { [Model]: CFrame } = {}

local function setBeacon(instance: Instance?)
	local current = beacon
	if current and current.instance == instance and instance and instance.Parent then
		return
	end
	if current then
		current.beacon.stop()
	end
	beacon = if instance then { instance = instance, beacon = GuideArrows.beacon(instance, guideFolder()) } else nil
end

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
			mark = GuideArrows.ground()
			marks[index] = mark
		end
		local ground = groundAt(sample.position)
		if ground then
			GuideArrows.place(mark, ground + Vector3.new(0, HOVER, 0), sample.direction)
			bases[mark] = mark:GetPivot()
			mark.Parent = parent
		else
			mark.Parent = nil -- pas de sol sous ce point : pas de flèche perdue dans le vide
		end
	end
	for index = #samples + 1, #marks do
		marks[index].Parent = nil
	end
end

-- Une vague avance vers la cible (flèches plus loin = plus tard) : la flèche au passage de la vague est
-- pleine et se soulève un peu, les autres s'estompent légèrement. Le sens du chemin se lit d'un coup d'œil.
local function pulse(now: number)
	for index, mark in marks do
		local base = bases[mark]
		if mark.Parent and base then
			local wave = 0.5 + 0.5 * math.sin(now * 5 - index * 0.8)
			mark:PivotTo(base + Vector3.new(0, LIFT * wave, 0))
			GuideArrows.setFade(mark, 0.6 * (1 - wave))
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
		setBeacon(nil)
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
		setBeacon(pose or slab)
		return
	end
	showSlab(nil, nil, false)
	-- un héros posé, déjà à l'arène : la pancarte pulse, pas de chemin dans l'arène (F lance aussi)
	local inArena = teaching and root ~= nil and arenaDistance(root) <= ARENA_NEAR
	showTarget(target, focus, mode == "Near" or inArena)
	setBeacon(focus or target)
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
