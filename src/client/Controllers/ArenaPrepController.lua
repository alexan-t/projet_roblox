--!strict
-- PROTOTYPE de préparation de combat, côté client (voir docs/ARENA_PROTOTYPE.md).
-- Panneau provisoire (le style de l'UI appartient au design, #11) : ennemis à affronter,
-- choix de la classe, clic sur une case du 3x3 pour poser ou retirer un héros, puis Combattre.
-- Le client n'envoie que des demandes ; ArenaService valide et place tout.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)

local TAG_CASE = "CaseHeros"

local ArenaPrepController = {}

local action: RemoteFunction? = nil
local phase = "Closed"
local selectedClass: string = ArenaConfig.HeroClasses[1].Id
local gui: ScreenGui? = nil
local widgets: { [string]: any } = {}

local function label(parent: Instance, text: string, height: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, height)
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextSize = 16
	l.Text = text
	l.Parent = parent
	return l
end

local function button(parent: Instance, text: string, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 30)
	b.TextSize = 16
	b.Text = text
	b.Parent = parent
	b.Activated:Connect(onClick)
	return b
end

local function request(name: string, ...: any)
	local remote = action
	if not remote then
		return
	end
	local ok, reason = remote:InvokeServer(name, ...)
	if not ok and reason and widgets.message then
		widgets.message.Text = reason
	end
end

local function refreshClassButtons()
	for id, b in widgets.classes do
		b.Text = if id == selectedClass then `▶ {b:GetAttribute("Nom")}` else b:GetAttribute("Nom")
	end
end

local function build(): ScreenGui
	local screen = Instance.new("ScreenGui")
	screen.Name = "PreparationCombat"
	screen.ResetOnSpawn = false
	screen.Enabled = false
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -16, 0.5, 0)
	panel.Size = UDim2.fromOffset(280, 470)
	panel.BackgroundColor3 = Color3.new(0, 0, 0)
	panel.BackgroundTransparency = 0.4
	panel.Parent = screen
	local padding = Instance.new("UIPadding")
	padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 10), UDim.new(0, 10)
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	padding.Parent = panel
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = panel

	widgets.title = label(panel, "Préparation", 22)
	widgets.enemies = label(panel, "", 60)
	widgets.hint = label(panel, "Choisis un héros puis clique une case (reclic = retirer).", 36)
	widgets.classes = {}
	for _, class in ArenaConfig.HeroClasses do
		local b = button(panel, class.Name, function()
			selectedClass = class.Id
			refreshClassButtons()
		end)
		b:SetAttribute("Nom", class.Name)
		widgets.classes[class.Id] = b
	end
	widgets.count = label(panel, "", 20)
	widgets.fight = button(panel, "Combattre", function() request("Fight") end)
	widgets.leave = button(panel, "Quitter", function() request("Leave") end)
	widgets.message = label(panel, "", 36)
	refreshClassButtons()
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return screen
end

local function applyState(state: { [string]: any })
	local screen = gui
	if not screen then
		return
	end
	phase = state.Phase
	if phase == "Closed" then
		screen.Enabled = false
		return
	end
	if phase == "Placement" then
		-- Restes visuels de l'intro de démonstration (client) posés sur les mêmes cases.
		for _, child in Workspace:GetChildren() do
			if child.Name == "IntroCombat" then
				child:Destroy()
			end
		end
	end
	screen.Enabled = true
	widgets.title.Text = `Stage {state.Zone}-{state.Stage} — {if phase == "Placement" then "placement" else "combat"}`
	local lines = {}
	for _, enemy in state.Enemies do
		table.insert(lines, if enemy.MiniBoss then `Mini-boss : {enemy.EnemyId}` else `{enemy.EnemyId} ×{enemy.Count}`)
	end
	widgets.enemies.Text = "Ennemis : " .. table.concat(lines, ", ")
	widgets.count.Text = `Héros placés : {#state.Formation}/{ArenaConfig.MaxHeroes}`
	local placing = phase == "Placement"
	widgets.hint.Visible = placing
	widgets.fight.Visible = placing
	for _, b in widgets.classes do
		b.Visible = placing
	end
	widgets.message.Text = state.Message or (if placing then "" else "Ennemis placés au hasard. Combat réel : #8.")
end

-- Case du 3x3 sous la souris, d'après les cases taguées de l'arène de test.
local function caseUnderMouse(position: Vector2): number?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local cases = {}
	for _, case in CollectionService:GetTagged(TAG_CASE) do
		local arena = case:FindFirstAncestor(ArenaConfig.ArenaPath[#ArenaConfig.ArenaPath])
		if arena and arena.Parent and arena.Parent.Name == ArenaConfig.ArenaPath[1] then
			table.insert(cases, case)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = cases
	local ray = camera:ViewportPointToRay(position.X, position.Y)
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	local node: Instance? = hit and hit.Instance
	while node do
		local slot = node:GetAttribute("Slot")
		if typeof(slot) == "number" then
			return slot
		end
		node = node.Parent
	end
	return nil
end

function ArenaPrepController:Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local stateEvent = remotes:WaitForChild("ArenaState", 30)
	local remote = remotes:WaitForChild("ArenaAction", 30)
	if not stateEvent or not stateEvent:IsA("RemoteEvent") or not remote or not remote:IsA("RemoteFunction") then
		return -- prototype désactivé côté serveur
	end
	action = remote
	gui = build()
	stateEvent.OnClientEvent:Connect(applyState)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or phase ~= "Placement" then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			local slot = caseUnderMouse(Vector2.new(input.Position.X, input.Position.Y))
			if slot then
				request("Toggle", slot, selectedClass)
			end
		end
	end)
end

return ArenaPrepController
