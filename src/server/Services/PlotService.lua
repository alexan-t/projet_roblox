--!strict
-- Attribution serveur des emplacements créés dans Studio (voir docs/PLOTS.md).
-- Le PlotId est temporaire : il ne fait jamais partie des données sauvegardées.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Log = require(ReplicatedStorage.Shared.Utils.Log)
local DataService = require(script.Parent.DataService)

local SCOPE = "PlotService"
local RUNTIME_NAME = "Runtime"
local ROOT_TIMEOUT = 10
local SPAWN_HEIGHT = 4

type Plot = { model: Model, id: number, spawn: BasePart }
type Assignment = {
	plot: Plot,
	runtime: Folder,
	characterConnection: RBXScriptConnection?,
	dataConnection: RBXScriptConnection?,
}
type AssignedCallback = (player: Player, plot: Model) -> ()

local PlotService = {}
local plots: { Plot } = {}
local assignments: { [Player]: Assignment } = {}
local owners: { [Model]: Player } = {}
local assigned = Instance.new("BindableEvent")

local function isUsable(plot: Plot): boolean
	return plot.model:IsDescendantOf(Workspace) and plot.spawn.Parent == plot.model
end

local function moveCharacter(player: Player, character: Model, assignment: Assignment): boolean
	local root = character:WaitForChild("HumanoidRootPart", ROOT_TIMEOUT)
	-- L'attente peut finir après un leave, une perte de session ou un autre respawn.
	if not root or not root:IsA("BasePart")
		or assignments[player] ~= assignment
		or player.Parent ~= Players or player.Character ~= character
		or not character:IsDescendantOf(Workspace) or not isUsable(assignment.plot)
	then
		return false
	end

	character:PivotTo(assignment.plot.spawn.CFrame * CFrame.new(0, SPAWN_HEIGHT, 0))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	return true
end

local function release(player: Player)
	local assignment = assignments[player]
	if not assignment then
		return
	end
	-- Invalider d'abord les tâches de spawn encore en attente.
	assignments[player] = nil
	if assignment.characterConnection then
		assignment.characterConnection:Disconnect()
	end
	if assignment.dataConnection then
		assignment.dataConnection:Disconnect()
	end
	assignment.runtime:Destroy()
	assignment.plot.model:SetAttribute("OwnerUserId", nil)
	player:SetAttribute("PlotId", nil)
	owners[assignment.plot.model] = nil
	Log.debug(SCOPE, `Plot {assignment.plot.id} libéré par {player.Name}`)
end

local function assign(player: Player)
	-- OnPlayerReady peut rejouer un joueur déjà prêt ; aucune double attribution.
	if assignments[player] or player.Parent ~= Players or not DataService:GetData(player) then
		return
	end

	local available: Plot? = nil
	for _, plot in plots do
		if not owners[plot.model] and isUsable(plot) and not plot.model:FindFirstChild(RUNTIME_NAME) then
			available = plot
			break
		end
	end
	if not available then
		Log.warn(SCOPE, `Aucun plot disponible pour {player.Name} ({#plots} configuré(s))`)
		player:Kick("Aucun emplacement de royaume n'est disponible sur ce serveur. Rejoins une autre partie.")
		return
	end

	-- Aucun yield entre la recherche et la réservation : deux joins ne peuvent
	-- pas obtenir le même emplacement, même si leur personnage charge lentement.
	local runtime = Instance.new("Folder")
	runtime.Name = RUNTIME_NAME
	runtime.Parent = available.model
	local assignment: Assignment = { plot = available, runtime = runtime }
	assignments[player] = assignment
	owners[available.model] = player
	available.model:SetAttribute("OwnerUserId", player.UserId)
	player:SetAttribute("PlotId", available.id)
	assignment.characterConnection = player.CharacterAdded:Connect(function(character: Model)
		task.defer(moveCharacter, player, character, assignment)
	end)
	assignment.dataConnection = player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
		if player:GetAttribute("DataLoaded") ~= true then
			release(player)
		end
	end)
	if player.Character then
		task.defer(moveCharacter, player, player.Character, assignment)
	end
	assigned:Fire(player, available.model)
	Log.debug(SCOPE, `Plot {available.id} attribué à {player.Name}`)
end

function PlotService:Init()
	local folder = Workspace:FindFirstChild("Plots")
	if not folder or not folder:IsA("Folder") then
		Log.warn(SCOPE, "Workspace.Plots (Folder) introuvable ; préparer la map selon docs/PLOTS.md")
		return
	end

	-- Compter les identifiants avant de valider : aucun des doublons n'est retenu.
	local idCounts: { [number]: number } = {}
	for _, child in folder:GetChildren() do
		local id = child:GetAttribute("PlotId")
		if child:IsA("Model") and typeof(id) == "number" and id > 0 and id < math.huge and id % 1 == 0 then
			idCounts[id] = (idCounts[id] or 0) + 1
		end
	end
	for _, child in folder:GetChildren() do
		local id = child:GetAttribute("PlotId")
		local spawn = child:FindFirstChild("Spawn")
		if not child:IsA("Model") or typeof(id) ~= "number" or idCounts[id] ~= 1
			or not spawn or not spawn:IsA("BasePart") or spawn:IsA("SpawnLocation") or not spawn.Anchored
			or child:FindFirstChild(RUNTIME_NAME)
		then
			Log.warn(SCOPE, `Plot ignoré : {child:GetFullName()} (vérifier PlotId unique, Spawn ancré et absence de Runtime)`)
			continue
		end
		child:SetAttribute("OwnerUserId", nil)
		table.insert(plots, { model = child, id = id, spawn = spawn })
	end
	table.sort(plots, function(a: Plot, b: Plot): boolean
		return a.id < b.id
	end)
	if #plots < 8 or #plots > 12 then
		Log.warn(SCOPE, `{#plots} plot(s) valide(s) ; la map Alpha doit en proposer 8 à 12`)
	end
end

function PlotService:Start()
	Players.PlayerRemoving:Connect(release)
	DataService:OnPlayerReady(assign)
end

function PlotService:GetPlot(player: Player): Model?
	local assignment = assignments[player]
	return if assignment then assignment.plot.model else nil
end

function PlotService:GetOwner(plot: Model): Player?
	return owners[plot]
end

function PlotService:GetRuntime(player: Player): Folder?
	local assignment = assignments[player]
	return if assignment then assignment.runtime else nil
end

-- Retour d'expédition : peut attendre le HumanoidRootPart jusqu'à ROOT_TIMEOUT.
function PlotService:TeleportToPlot(player: Player): boolean
	local assignment = assignments[player]
	local character = player.Character
	if not assignment or not character then
		return false
	end
	return moveCharacter(player, character, assignment)
end

-- Depuis Start(), comme DataService:OnPlayerReady. Inclut les plots déjà attribués.
-- Les callbacks doivent revérifier GetPlot/GetRuntime après toute attente.
function PlotService:OnPlotAssigned(callback: AssignedCallback): RBXScriptConnection
	local function notify(player: Player, plot: Model)
		if self:GetPlot(player) == plot then
			callback(player, plot)
		end
	end
	local connection = assigned.Event:Connect(notify)
	for player, assignment in assignments do
		task.defer(function()
			if connection.Connected then
				notify(player, assignment.plot.model)
			end
		end)
	end
	return connection
end

return PlotService
