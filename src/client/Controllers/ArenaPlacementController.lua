--!strict
-- Placement des héros directement sur l'arène, côté client (voir docs/ARENA_PROTOTYPE.md).
--   • Héros en main (hotbar ou sacoche) : la grille 3x3 apparaît, la case survolée s'éclaire,
--     un clic/toucher sur une case demande au serveur de poser le héros (ArenaAction "Place").
--   • Clic sur un héros posé : il est repris en main pour le déplacer, ou le retirer (bouton Retirer).
--   • E près de l'étendard (prompt serveur « Combattre ») démarre le combat aussitôt.
--   • Combat : seulement une pastille légère (vague, x1/x2, X) ; PV et énergie sont dans le monde
--     (CombatViewController). Les ultimes sont automatiques.
-- États des cases : vide, survolée, cible valide, occupée, sélectionnée (UITheme).
-- Le client ne fait que détecter et demander ; ArenaService valide tout.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local ArenaStore = require(script.Parent.Parent.Arena.ArenaStore)
local PlacementState = require(script.Parent.Parent.Arena.PlacementState)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local C = UITheme.Colors
local T = UITheme.Transparency
local S = UITheme.Spacing

local ArenaPlacementController = {}

local TAG_CASE = "CaseHeros"
local GRID_HIDDEN = UITheme.World.GridHidden -- cases hors placement presque invisibles
local ABOVE_HOTBAR = 112 -- hauteur réservée à la hotbar (px)

type CaseState = "Empty" | "Hover" | "ValidTarget" | "Occupied" | "Selected" | "Invalid"

local caseModels: { [number]: Instance } = {}
local caseHighlights: { [number]: Highlight } = {}
local hovered: number? = nil
local gridModifier: number? = nil
local ui: { [string]: any } = {}
local speedRemote: RemoteFunction? = nil
local arenaRoot: Instance? = nil

------------------------------------------------------------------ arène

local function resolveArena(): Instance?
	local node: Instance? = Workspace
	for _, name in ArenaConfig.ArenaPath do
		node = if node then node:FindFirstChild(name) else nil
	end
	return node
end

local function refreshCases()
	table.clear(caseModels)
	local root = resolveArena()
	arenaRoot = root
	if not root then
		return
	end
	for _, case in CollectionService:GetTagged(TAG_CASE) do
		local slot = case:GetAttribute("Slot")
		if case:IsDescendantOf(root) and typeof(slot) == "number" then
			caseModels[slot] = case
		end
	end
end

-- L'arène est prise par un autre joueur ?
local function occupiedByOther(): boolean
	local root = arenaRoot
	local occupant = if root then root:GetAttribute("Occupant") else nil
	return occupant ~= nil and occupant ~= Players.LocalPlayer.UserId
end

-- Héros posés (mannequins de placement), pour les reprendre en main d'un clic.
local function placedModels(): { Instance }
	local list = {}
	local folder = Workspace:FindFirstChild(`PreparationCombat_{Players.LocalPlayer.UserId}`)
	local heroes = folder and folder:FindFirstChild("Heros")
	if heroes and ArenaStore.arena.Phase == "Placement" then
		for _, model in heroes:GetChildren() do
			table.insert(list, model)
		end
	end
	return list
end

-- Case visée (la case elle-même ou le héros posé dessus).
local function caseAt(position: Vector2): number?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local targets = placedModels()
	for _, case in caseModels do
		table.insert(targets, case)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = targets
	local ray = camera:ScreenPointToRay(position.X, position.Y)
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

-- Transparence locale uniquement (le modèle du design n'est jamais modifié).
local function setGrid(modifier: number)
	if gridModifier == modifier then
		return
	end
	gridModifier = modifier
	for _, case in caseModels do
		for _, part in case:GetDescendants() do
			if part:IsA("BasePart") and part.Name ~= "PointDePose" then
				part.LocalTransparencyModifier = modifier
			end
		end
	end
end

-- Styles des états de case : UITheme.World.Case (Vide = aucune surbrillance).
local CASE_STYLE: { [string]: { Fill: Color3, FillT: number, Outline: Color3, OutlineT: number }? } = UITheme.World.Case :: any

local function caseState(slot: number, formation: { [number]: string }, full: boolean): CaseState
	local held = ArenaStore.placement.held
	if not held then
		return if hovered == slot and formation[slot] and ArenaStore.arena.Phase == "Placement" then "Hover" else "Empty"
	end
	if held.fromSlot == slot then
		return "Selected"
	end
	local valid = not occupiedByOther() and (formation[slot] ~= nil or held.fromSlot ~= nil or not full)
	if hovered == slot then
		return if valid then "Hover" else "Invalid"
	end
	if not valid then
		return "Empty"
	end
	return if formation[slot] then "Occupied" else "ValidTarget"
end

local function renderCases()
	local held = ArenaStore.placement.held
	local phase = ArenaStore.arena.Phase
	if held then
		setGrid(0)
	elseif phase == "Placement" or phase == "Combat" then
		setGrid(GRID_HIDDEN)
	else
		setGrid(0)
	end
	local formation = ArenaStore.formation()
	local full = ArenaStore.placedCount() >= (ArenaStore.arena.MaxHeroes or ArenaConfig.MaxHeroes)
	for slot, highlight in caseHighlights do
		local style = CASE_STYLE[caseState(slot, formation, full)]
		highlight.Enabled = style ~= nil and phase ~= "Combat"
		if style then
			highlight.FillColor = style.Fill
			highlight.FillTransparency = style.FillT
			highlight.OutlineColor = style.Outline
			highlight.OutlineTransparency = style.OutlineT
		end
	end
end

------------------------------------------------------------------ interface

local function pill(parent: Instance, transparency: number): Frame
	local frame = UIKit.panel(parent, transparency, UITheme.Radius.Pill, UITheme.Stroke.Regular)
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -ABOVE_HOTBAR)
	return frame
end

local function flash(target: GuiObject, seconds: number)
	target.Visible = true
	UIKit.pop(target)
	local token = {}
	ui.flashToken = ui.flashToken or {}
	ui.flashToken[target] = token
	task.delay(seconds, function()
		if ui.flashToken[target] == token then
			target.Visible = false
		end
	end)
end

local function showToast(text: string)
	local good = text == "Victoire !"
	local bad = text == "Défaite…"
	if good or bad then
		ui.result.Text = text
		ui.result.TextColor3 = if good then C.Gold else C.Error
		flash(ui.result, 3)
		return
	end
	ui.toastText.Text = text
	flash(ui.toast, 2.5)
end

local function build()
	local screen = Instance.new("ScreenGui")
	screen.Name = "PlacementArene"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = false -- mêmes coordonnées que les entrées (souris, toucher)
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ui.screen = screen

	-- Statut du placement, juste au-dessus de la hotbar.
	local status = pill(screen, T.HUD)
	status.Size = UDim2.fromOffset(520, 52)
	ui.status = status
	local statusText = UIKit.text(status, "", UITheme.Typography.Size.Label)
	statusText.Position = UDim2.fromOffset(S.L, 0)
	statusText.Size = UDim2.new(1, -2 * S.L, 1, 0)
	statusText.TextXAlignment = Enum.TextXAlignment.Left
	ui.statusText = statusText
	local actions = Instance.new("Frame")
	actions.BackgroundTransparency = 1
	actions.AnchorPoint = Vector2.new(1, 0.5)
	actions.Position = UDim2.new(1, -S.S, 0.5, 0)
	actions.Size = UDim2.fromOffset(220, 40)
	actions.Parent = status
	ui.actions = actions
	local remove = UIKit.button(actions, "Retirer", "Secondary", UDim2.fromOffset(104, 40), function()
		local request = PlacementState.removeHeld(ArenaStore.placement)
		if request then
			ArenaStore.request("Remove", request.Slot)
		end
		ArenaStore.notify()
	end)
	remove.label.TextSize = UITheme.Typography.Size.Label
	ui.remove = remove
	local cancel = UIKit.button(actions, "Annuler", "Secondary", UDim2.fromOffset(104, 40), function()
		PlacementState.cancel(ArenaStore.placement)
		ArenaStore.notify()
	end)
	cancel.holder.Position = UDim2.fromOffset(112, 0)
	cancel.label.TextSize = UITheme.Typography.Size.Label

	-- Héros en main qui suit le curseur (souris uniquement).
	local ghost = UIKit.panel(screen, T.PanelStrong, UITheme.Radius.Pill, UITheme.Stroke.Regular)
	ghost.AnchorPoint = Vector2.new(0, 1)
	ghost.Size = UDim2.fromOffset(52, 52)
	ghost.Visible = false
	ghost.ZIndex = 10
	ui.ghostIcon = UIKit.text(ghost, "", UITheme.Typography.Size.Icon)
	ui.ghost = ghost

	-- Combat : vague, x1 / x2, quitter. Léger, la map reste visible.
	local combat = pill(screen, T.HUD)
	combat.Size = UDim2.fromOffset(340, 56)
	combat.Visible = false
	ui.combat = combat
	local wave = UIKit.text(combat, "Vague", UITheme.Typography.Size.Label)
	wave.Position = UDim2.fromOffset(S.XL, 0)
	wave.Size = UDim2.fromOffset(110, 56)
	wave.TextXAlignment = Enum.TextXAlignment.Left
	ui.wave = wave
	local function speed(value: number)
		local remote = speedRemote
		if remote then
			remote:InvokeServer(value)
		end
	end
	local x1 = UIKit.button(combat, "x1", "Tab", UDim2.fromOffset(56, 40 + UITheme.Shadow.ButtonLip), function()
		speed(1)
	end)
	x1.holder.Position = UDim2.fromOffset(140, 4)
	x1.label.TextSize = UITheme.Typography.Size.Label
	local x2 = UIKit.button(combat, "x2", "Tab", UDim2.fromOffset(56, 40 + UITheme.Shadow.ButtonLip), function()
		speed(2)
	end)
	x2.holder.Position = UDim2.fromOffset(202, 4)
	x2.label.TextSize = UITheme.Typography.Size.Label
	ui.x1, ui.x2 = x1, x2
	local quit = UIKit.button(combat, "X", "Danger", UDim2.fromOffset(44, 40 + UITheme.Shadow.ButtonLip), function()
		ArenaStore.request("Leave")
	end)
	quit.holder.Position = UDim2.fromOffset(282, 4)

	-- Annonce de vague / mini-boss, et résultat.
	local banner = UIKit.text(screen, "", UITheme.Typography.Size.Title)
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 70)
	banner.Size = UDim2.fromOffset(500, 44)
	banner.TextColor3 = C.Gold
	banner.Visible = false
	ui.banner = banner
	local result = UIKit.text(screen, "", UITheme.Typography.Size.Hero)
	result.AnchorPoint = Vector2.new(0.5, 0.5)
	result.Position = UDim2.fromScale(0.5, 0.32)
	result.Size = UDim2.fromOffset(600, 80)
	result.Visible = false
	ui.result = result
	local toast = UIKit.panel(screen, T.Tooltip, UITheme.Radius.Pill, UITheme.Stroke.Regular)
	toast.BackgroundColor3 = C.Cream
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, 24)
	toast.Size = UDim2.fromOffset(420, 46)
	toast.Visible = false
	ui.toast = toast
	local toastText = Instance.new("TextLabel")
	toastText.BackgroundTransparency = 1
	toastText.FontFace = UITheme.Typography.Display
	toastText.TextSize = UITheme.Typography.Size.Label
	toastText.TextColor3 = C.InkSoft
	toastText.Size = UDim2.fromScale(1, 1)
	toastText.Parent = toast
	ui.toastText = toastText

	-- Une surbrillance discrète par case (aucun néon), pilotée par l'état de la case.
	for slot, case in caseModels do
		local highlight = Instance.new("Highlight")
		highlight.Name = `Case{slot}`
		highlight.Adornee = case
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Enabled = false
		highlight.Parent = screen
		caseHighlights[slot] = highlight
	end

	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function render()
	local held = ArenaStore.placement.held
	local phase = ArenaStore.arena.Phase
	local count = ArenaStore.placedCount()
	local max = ArenaStore.arena.MaxHeroes or ArenaConfig.MaxHeroes
	ui.combat.Visible = phase == "Combat"
	if held then
		local _, info = ArenaStore.heroInfo(held.instanceId)
		local name = if info then info.Name else "Héros"
		ui.statusText.Text = if occupiedByOther()
			then "Arène occupée par un autre joueur"
			else `{name} en main · choisis une case   {count}/{max}`
		ui.remove.holder.Visible = held.fromSlot ~= nil
		ui.status.Visible = true
		ui.ghostIcon.Text = if info then info.PlaceholderIcon else "?"
	elseif phase == "Placement" then
		ui.statusText.Text = `{count}/{max} héros · E près de l'étendard pour combattre`
		ui.remove.holder.Visible = false
		ui.status.Visible = true
	else
		ui.status.Visible = false
	end
	-- Les boutons Retirer / Annuler n'ont de sens qu'avec un héros en main ; le texte leur laisse la place.
	ui.actions.Visible = held ~= nil
	local reserved = if held then ui.actions.Size.X.Offset + S.S else 0
	ui.status.Size = UDim2.fromOffset(440 + reserved, 52)
	ui.statusText.Size = UDim2.new(1, -2 * S.L - reserved, 1, 0)
	ui.ghost.Visible = held ~= nil and UserInputService.MouseEnabled and not UserInputService.TouchEnabled
	renderCases()
end

------------------------------------------------------------------ entrées

local function onInputBegan(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape and ArenaStore.placement.held then
		PlacementState.cancel(ArenaStore.placement)
		ArenaStore.notify()
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	if ArenaStore.inCombat() then
		return
	end
	local slot = caseAt(Vector2.new(input.Position.X, input.Position.Y))
	if not slot then
		return -- clic ailleurs dans le monde : le héros reste en main
	end
	local request = PlacementState.clickCase(ArenaStore.placement, slot, ArenaStore.formation())
	hovered = nil
	if request then
		-- Réponse du serveur d'abord : l'état affiché passe directement à la formation validée.
		ArenaStore.request(request.Action, request.Slot, request.HeroInstanceId)
	end
	ArenaStore.notify()
end

local function onInputChanged(input: InputObject)
	if input.UserInputType ~= Enum.UserInputType.MouseMovement then
		return
	end
	local position = Vector2.new(input.Position.X, input.Position.Y)
	if ArenaStore.placement.held then
		ui.ghost.Position = UDim2.fromOffset(position.X + 14, position.Y - 6)
	end
	local slot = if ArenaStore.inCombat() then nil else caseAt(position)
	if slot ~= hovered then
		hovered = slot
		renderCases()
	end
end

local function onCombatEvents(_combatId: number, events: { { [string]: any } })
	for _, event in events do
		if event.Type == "WaveStarted" then
			local text = if event.WaveCount > 1 then `Vague {event.Wave}/{event.WaveCount}` else "Vague"
			ui.wave.Text = text
			ui.banner.Text = text
			flash(ui.banner, 2)
		elseif event.Type == "MiniBossStarted" then
			ui.wave.Text = "Mini-boss"
			ui.banner.Text = `★ {event.EnemyId}`
			flash(ui.banner, 2.5)
		elseif event.Type == "SpeedChanged" then
			ui.x1.setSelected(event.Speed == 1)
			ui.x2.setSelected(event.Speed == 2)
		end
	end
end

-- L'intro de démonstration (CombatIntroController) occupe les mêmes cases.
-- Pendant une préparation ou un combat, le serveur la suspend lui-même (IntroDemoBoucle = false).
-- Avant le premier héros posé (héros en main, arène libre), ce client la suspend localement
-- (attribut local, non répliqué) ; si la main est vidée sans poser, il la rétablit. Dès qu'une
-- préparation existe, la valeur du serveur reprend la main.
local demoPaused = false
local demoWas: any = nil
local function removeDemoLeftovers()
	for _, child in Workspace:GetChildren() do
		if child.Name == "IntroCombat" then
			child:Destroy()
		end
	end
end
local function updateDemo()
	local root = arenaRoot
	if not root then
		return
	end
	local phase = ArenaStore.arena.Phase
	local pause = ArenaStore.placement.held ~= nil and phase == "Closed" and not occupiedByOther()
	if pause and not demoPaused then
		demoPaused = true
		demoWas = root:GetAttribute("IntroDemoBoucle")
		root:SetAttribute("IntroDemoBoucle", false)
		removeDemoLeftovers()
	elseif not pause and demoPaused then
		demoPaused = false
		if phase == "Closed" then
			root:SetAttribute("IntroDemoBoucle", demoWas) -- main vidée sans poser : la démo reprend
		end
	end
	if phase ~= "Closed" then
		removeDemoLeftovers()
	end
end

function ArenaPlacementController:Start()
	refreshCases()
	build()
	ArenaStore.changed.Event:Connect(function()
		updateDemo()
		render()
	end)
	ArenaStore.toast.Event:Connect(showToast)
	local root = arenaRoot
	if root then
		root:GetAttributeChangedSignal("Occupant"):Connect(render)
	end
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputChanged:Connect(onInputChanged)
	render()
	ArenaStore.start()

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local speedFn = remotes:WaitForChild("SetCombatSpeed", 30)
	local events = remotes:WaitForChild("CombatEvent", 30)
	if speedFn and speedFn:IsA("RemoteFunction") then
		speedRemote = speedFn
	end
	if events and events:IsA("RemoteEvent") then
		events.OnClientEvent:Connect(onCombatEvents)
	end
end

return ArenaPlacementController
