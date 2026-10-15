--!strict
-- Chemin lumineux de quête (voir docs/QUESTS.md § Guidage), purement visuel, côté client.
-- La quête active (Remotes.GetActiveQuest / QuestChanged) peut porter GuideTarget (QuestConfig.Guide) :
--   joueur → chevrons dorés au sol, régulièrement espacés, orientés vers la cible, avec une vague qui
--   « avance » vers elle → cible mise en évidence (halo + petit marqueur « OBJECTIF »).
-- La cible est toujours résolue dans le plot du joueur local (PlotView + Shared.Quests.QuestGuide),
-- jamais Workspace.PlotTravail ni le plot d'un autre joueur.
-- Masqué pendant le combat, l'intro des ennemis, le CTA, les écrans (récompenses, invocation, stages),
-- quête terminée ; près de la cible le chemin s'efface et l'interaction normale (E) prend le relais.
-- Chemin : PathfindingService (client), recalculé seulement si la cible change, si le joueur s'est assez
-- déplacé, ou si le chemin a échoué ; rayon vers le sol pour chaque chevron. 12 chevrons au plus.

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local QuestGuide = require(ReplicatedStorage.Shared.Quests.QuestGuide)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local ArenaStore = require(script.Parent.Parent.Arena.ArenaStore)
local PlotView = require(script.Parent.Parent.Arena.PlotView)
local ScreenState = require(script.Parent.Parent.UI.ScreenState)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local QuestGuideController = {}

local REFRESH = 0.2 -- s entre deux décisions (mode, cible)
local MARKS = 12 -- chevrons visibles au plus, devant le joueur
local SPACING = 3.5 -- studs entre deux chevrons
local SKIP = 3 -- studs devant le joueur avant le premier chevron
local REPATH_DISTANCE = 6 -- studs parcourus avant de recalculer le chemin
local REPATH_RETRY = 3 -- s avant de réessayer un chemin qui a échoué
local GOAL_OFFSET = 3.5 -- studs devant la cible (côté joueur) : point d'arrivée accessible

local quest: { [string]: any }? = nil
local folder: Folder? = nil
local marks: { Model } = {}
local highlight: Highlight? = nil
local label: BillboardGui? = nil
local overlay: ScreenGui? = nil
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

-- Chevron chunky : deux barres en V, pointe vers l'avant (-Z), à plat sur le sol.
local function chevron(): Model
	local model = Instance.new("Model")
	model.Name = "Chevron"
	for _, side in { -1, 1 } do
		local bar = Instance.new("Part")
		bar.Name = if side < 0 then "Gauche" else "Droite"
		bar.Size = Vector3.new(0.75, 0.16, 2.3)
		bar.Color = UITheme.Colors.GoldLight
		bar.Material = Enum.Material.Neon
		bar.Transparency = 0.4
		bar.Anchored = true
		bar.CanCollide, bar.CanTouch, bar.CanQuery = false, false, false
		bar.CastShadow = false
		-- barre inclinée de 40° : les deux se rejoignent à la pointe, devant
		bar.CFrame = CFrame.new(side * 0.7, 0, 0.15) * CFrame.Angles(0, math.rad(side * -40), 0)
		bar.Parent = model
	end
	model.PrimaryPart = model:FindFirstChild("Gauche") :: BasePart
	model.WorldPivot = CFrame.new()
	return model
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
end

local function buildOverlay()
	local screen = Instance.new("ScreenGui")
	screen.Name = "GuideQueteCible"
	screen.ResetOnSpawn = false
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	overlay = screen

	local glow = Instance.new("Highlight")
	glow.Name = "HaloObjectif"
	glow.FillColor = UITheme.Colors.Gold
	glow.FillTransparency = 0.85
	glow.OutlineColor = UITheme.Colors.GoldLight
	glow.OutlineTransparency = 0.2
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Enabled = false
	glow.Parent = screen
	highlight = glow

	-- petit marqueur flottant « OBJECTIF » : pastille du design system, ne cache pas le décor
	local gui = Instance.new("BillboardGui")
	gui.Name = "MarqueurObjectif"
	gui.Size = UDim2.fromOffset(128, 34)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 250
	gui.Enabled = false
	local pill = UIKit.panel(gui, UITheme.Transparency.HUD, UITheme.Radius.Pill, UITheme.Stroke.Regular)
	pill.Size = UDim2.fromScale(1, 1)
	UIKit.text(pill, "OBJECTIF", UITheme.Typography.Size.Label, UITheme.Colors.Gold)
	gui.Parent = screen
	label = gui
end

local function showTarget(target: Instance?, focus: Instance?, near: boolean)
	local glow, gui = highlight, label
	if glow then
		glow.Adornee = target
		glow.Enabled = target ~= nil
		glow.OutlineTransparency = if near then 0.45 else 0.2 -- arrivé : la cible reste légèrement en évidence
	end
	if gui then
		gui.Adornee = if focus and focus:IsA("BasePart") then focus else nil
		gui.Enabled = focus ~= nil and focus:IsA("BasePart")
	end
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
			mark = chevron()
			marks[index] = mark
		end
		local ground = groundAt(sample.position)
		if ground then
			local flat = Vector3.new(sample.direction.X, 0, sample.direction.Z)
			local look = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
			mark:PivotTo(CFrame.lookAt(ground + Vector3.new(0, 0.12, 0), ground + Vector3.new(0, 0.12, 0) + look))
			mark.Parent = parent
		else
			mark.Parent = nil -- pas de sol sous ce point : pas de chevron flottant
		end
	end
	for index = #samples + 1, #marks do
		marks[index].Parent = nil
	end
end

-- Vague lumineuse qui avance vers la cible (chevrons plus loin = plus tard).
local function pulse(now: number)
	for index, mark in marks do
		if mark.Parent then
			local wave = 0.5 + 0.5 * math.sin(now * 4 - index * 0.7)
			for _, bar in mark:GetChildren() do
				if bar:IsA("BasePart") then
					bar.Transparency = 0.55 - 0.3 * wave
				end
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
		combat = ArenaStore.inCombat(),
		presentation = ArenaStore.presentation,
		screen = ScreenState.current(),
		distance = distance,
	})
	if mode == "Hidden" then
		hideMarks()
		showTarget(nil, nil, false)
		if not targetName or (view and view.Completed) then
			clearMarks() -- quête terminée ou sans guidage : plus aucun objet
			path, pathTarget = {}, nil
		end
		return
	end
	showTarget(target, focus, mode == "Near")
	if mode == "Near" then
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
	buildOverlay()
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
