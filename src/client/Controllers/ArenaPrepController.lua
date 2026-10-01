--!strict
-- Préparation et HUD minimal du combat, côté client (voir docs/ARENA_PROTOTYPE.md, docs/COMBAT.md).
-- Principe : on agit sur le champ de bataille, pas dans des menus.
--   • Placement : la « main » (héros disponibles) en bas de l'écran. Glisser un héros sur une case
--     du 3x3, ou le toucher puis toucher une case. Un héros posé se déplace en le glissant vers une
--     autre case, ou se retire en le glissant vers la main. La grille n'est bien visible que pendant
--     une sélection ou un glisser ; sinon elle reste presque invisible.
--   • Combat : seuls x1/x2 et Quitter restent à l'écran ; PV et mana sont au-dessus des unités
--     (CombatViewController). Une annonce brève signale les vagues et le mini-boss.
-- Le client n'envoie que des demandes ; ArenaService et CombatService décident tout.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)

local ArenaPrepController = {}

local TAG_CASE = "CaseHeros"
local DRAG_THRESHOLD = 8 -- pixels avant qu'un appui devienne un glisser
local GRID_HIDDEN = 0.85 -- transparence locale des cases hors placement (presque invisibles)

-- Palette provisoire reprise de l'intro de combat (or, rouge) et de la bannière du royaume (bleu).
local COLORS = {
	panel = Color3.fromRGB(24, 26, 34),
	card = Color3.fromRGB(42, 46, 60),
	hero = Color3.fromRGB(52, 96, 176),
	enemy = Color3.fromRGB(150, 60, 50),
	gold = Color3.fromRGB(255, 205, 80),
	text = Color3.fromRGB(240, 240, 240),
	muted = Color3.fromRGB(150, 155, 170),
}

local classById: { [string]: { Id: string, Name: string, Icon: string } } = {}
for _, class in ArenaConfig.HeroClasses do
	classById[class.Id] = class
end

type Drag = { classId: string, fromSlot: number?, start: Vector2, moving: boolean }

local action: RemoteFunction? = nil
local combatAction: RemoteFunction? = nil
local state: { [string]: any } = { Phase = "Closed" }
local selection: { classId: string, fromSlot: number? }? = nil
local drag: Drag? = nil
local ui: { [string]: any } = {}
local caseModels: { [number]: Instance } = {}
local highlight: Highlight? = nil
local message: string? = nil -- dernier refus ou message du serveur

------------------------------------------------------------------ outils

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function label(parent: Instance, content: string, size: number, bold: boolean?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	l.TextSize = size
	l.TextColor3 = COLORS.text
	l.Text = content
	l.Parent = parent
	return l
end

local function button(parent: Instance, content: string, color: Color3, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = color
	b.Font = Enum.Font.GothamBold
	b.TextSize = 16
	b.TextColor3 = COLORS.text
	b.Text = content
	b.Parent = parent
	corner(b, 8)
	b.Activated:Connect(onClick)
	return b
end

local function request(name: string, ...: any)
	local remote = action
	if remote then
		local ok, reason = remote:InvokeServer(name, ...)
		message = if ok then nil else reason
		if ui.hint and message then
			ui.hint.Text = message
		end
	end
end

local function formation(): { [number]: string }
	local map = {}
	for _, entry in state.Formation or {} do
		map[entry.Slot] = entry.ClassId
	end
	return map
end

------------------------------------------------------------------ grille 3D

-- Cases taguées de l'arène de test (attribut Slot).
local function refreshCases()
	table.clear(caseModels)
	for _, case in CollectionService:GetTagged(TAG_CASE) do
		local arena = case:FindFirstAncestor(ArenaConfig.ArenaPath[#ArenaConfig.ArenaPath])
		local slot = case:GetAttribute("Slot")
		if arena and arena.Parent and arena.Parent.Name == ArenaConfig.ArenaPath[1] and typeof(slot) == "number" then
			caseModels[slot] = case
		end
	end
end

-- Transparence locale uniquement (le modèle du design n'est jamais modifié).
local function setGrid(visible: boolean?)
	local modifier = if visible == nil then 0 elseif visible then 0 else GRID_HIDDEN
	for _, case in caseModels do
		for _, part in case:GetDescendants() do
			if part:IsA("BasePart") and part.Name ~= "PointDePose" then
				part.LocalTransparencyModifier = modifier
			end
		end
	end
end

local function setHover(slot: number?)
	local h = highlight
	if not h then
		return
	end
	h.Adornee = if slot then caseModels[slot] else nil
	h.Enabled = slot ~= nil
end

local function caseAt(position: Vector2): number?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local list = {}
	for _, case in caseModels do
		table.insert(list, case)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = list
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

local function overHand(position: Vector2): boolean
	local hand: Frame? = ui.hand
	if not hand or not hand.Visible then
		return false
	end
	local p, s = hand.AbsolutePosition, hand.AbsoluteSize
	return position.X >= p.X and position.X <= p.X + s.X and position.Y >= p.Y - 20 and position.Y <= p.Y + s.Y
end

------------------------------------------------------------------ rendu

local function render()
	local screen: ScreenGui? = ui.screen
	if not screen then
		return
	end
	local phase = state.Phase
	local placing = phase == "Placement"
	screen.Enabled = phase ~= "Closed" or ui.toast.Visible
	ui.placement.Visible = placing
	ui.combat.Visible = phase == "Combat"
	local choosing = placing and (selection ~= nil or (drag ~= nil and drag.moving))
	if phase == "Closed" then
		setGrid(nil)
	else
		setGrid(choosing)
	end
	if not placing then
		return
	end

	local placed = formation()
	local count = #(state.Formation or {})
	local max = state.MaxHeroes or ArenaConfig.MaxHeroes
	local enemies = {}
	for _, enemy in state.Enemies or {} do
		table.insert(enemies, if enemy.MiniBoss then `★ {enemy.EnemyId}` else `{enemy.EnemyId} ×{enemy.Count}`)
	end
	ui.roster.Text = `Stage {state.Zone}-{state.Stage} · {table.concat(enemies, " · ")}`
	ui.count.Text = `{count}/{max}`
	for classId, card in ui.cards do
		local slot: number? = nil
		for s, placedClass in placed do
			if placedClass == classId then
				slot = s
			end
		end
		local selected = selection ~= nil and selection.classId == classId
		card.frame.BackgroundColor3 = if slot then COLORS.hero else COLORS.card
		card.frame.BackgroundTransparency = if slot then 0.35 else 0
		card.selection.Thickness = if selected then 3 else 0
		card.placed.Visible = slot ~= nil
		card.frame.Position = UDim2.new(0, 0, 0, if selected then -8 else 0)
	end
	ui.fight.Active = count > 0
	ui.fight.BackgroundColor3 = if count > 0 then COLORS.gold else COLORS.card
	ui.fight.TextColor3 = if count > 0 then COLORS.panel else COLORS.muted
	if selection then
		ui.hint.Text = if selection.fromSlot
			then "Touche une case pour le déplacer, ou la main pour le retirer"
			else "Touche une case pour le poser"
	else
		ui.hint.Text = message or (if count == 0 then "Glisse un héros sur une case" else "")
	end
end

------------------------------------------------------------------ construction

local function miniature(parent: Instance)
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.new(1, 0, 1, -18)
	viewport.Parent = parent
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Combat")
	local template = folder and folder:FindFirstChild(ArenaConfig.HeroTemplate)
	if template and template:IsA("Model") then
		local model = template:Clone()
		model:PivotTo(CFrame.new())
		model.Parent = viewport
		local camera = Instance.new("Camera")
		local _, size = model:GetBoundingBox()
		camera.CFrame = CFrame.lookAt(Vector3.new(0, size.Y * 0.25, -size.Y * 0.9), Vector3.new(0, size.Y * 0.2, 0))
		camera.Parent = viewport
		viewport.CurrentCamera = camera
	end
end

local function build()
	local screen = Instance.new("ScreenGui")
	screen.Name = "PreparationCombat"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = false -- mêmes coordonnées que les entrées (souris, toucher)
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Enabled = false
	ui.screen = screen

	-- Placement : roster en haut, main en bas, deux actions.
	local placement = Instance.new("Frame")
	placement.BackgroundTransparency = 1
	placement.Size = UDim2.fromScale(1, 1)
	placement.Parent = screen
	ui.placement = placement

	local roster = label(placement, "", 15, true)
	roster.AnchorPoint = Vector2.new(0.5, 0)
	roster.Position = UDim2.new(0.5, 0, 0, 10)
	roster.Size = UDim2.fromOffset(460, 30)
	roster.BackgroundColor3 = COLORS.panel
	roster.BackgroundTransparency = 0.35
	roster.TextColor3 = COLORS.gold
	corner(roster, 15)
	ui.roster = roster

	local hand = Instance.new("Frame")
	hand.Name = "Main"
	hand.AnchorPoint = Vector2.new(0.5, 1)
	hand.Position = UDim2.new(0.5, 0, 1, -12)
	hand.Size = UDim2.fromOffset(6 * 76 + 150, 104)
	hand.BackgroundTransparency = 1
	hand.Parent = placement
	ui.hand = hand
	local cards = Instance.new("Frame")
	cards.BackgroundTransparency = 1
	cards.Size = UDim2.new(1, -150, 1, 0)
	cards.Parent = hand
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.Padding = UDim.new(0, 6)
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = cards
	ui.cards = {}
	for index, class in ArenaConfig.HeroClasses do
		local slotFrame = Instance.new("Frame")
		slotFrame.BackgroundTransparency = 1
		slotFrame.Size = UDim2.fromOffset(70, 96)
		slotFrame.LayoutOrder = index
		slotFrame.Parent = cards
		local frame = Instance.new("TextButton")
		frame.Name = class.Id
		frame.AutoButtonColor = false
		frame.Text = ""
		frame.BackgroundColor3 = COLORS.card
		frame.Size = UDim2.fromScale(1, 1)
		frame.Parent = slotFrame
		corner(frame, 10)
		-- Cadre neutre : la rareté des héros n'existe pas encore (#10).
		stroke(frame, COLORS.muted, 1)
		local selectedStroke = stroke(frame, COLORS.gold, 0)
		miniature(frame)
		local icon = label(frame, class.Icon, 20)
		icon.Position = UDim2.fromOffset(4, 2)
		icon.Size = UDim2.fromOffset(24, 24)
		local name = label(frame, class.Name, 11, true)
		name.AnchorPoint = Vector2.new(0, 1)
		name.Position = UDim2.fromScale(0, 1)
		name.Size = UDim2.new(1, 0, 0, 18)
		local check = label(frame, "✓", 16, true)
		check.AnchorPoint = Vector2.new(1, 0)
		check.Position = UDim2.new(1, -4, 0, 2)
		check.Size = UDim2.fromOffset(18, 18)
		check.TextColor3 = COLORS.gold
		frame.InputBegan:Connect(function(input: InputObject)
			if state.Phase == "Placement" and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
				drag = { classId = class.Id, fromSlot = nil, start = Vector2.new(input.Position.X, input.Position.Y), moving = false }
			end
		end)
		ui.cards[class.Id] = { frame = frame, selection = selectedStroke, placed = check }
	end
	local side = Instance.new("Frame")
	side.BackgroundTransparency = 1
	side.AnchorPoint = Vector2.new(1, 0)
	side.Position = UDim2.fromScale(1, 0)
	side.Size = UDim2.new(0, 140, 1, 0)
	side.Parent = hand
	ui.count = label(side, "", 14, true)
	ui.count.Size = UDim2.new(1, 0, 0, 20)
	ui.count.TextColor3 = COLORS.muted
	ui.fight = button(side, "Combattre", COLORS.gold, function()
		if #(state.Formation or {}) > 0 then
			selection = nil
			request("Fight")
		end
	end)
	ui.fight.Position = UDim2.fromOffset(0, 24)
	ui.fight.Size = UDim2.new(1, 0, 0, 44)
	local quit = button(side, "Quitter", COLORS.card, function()
		request("Leave")
	end)
	quit.Position = UDim2.fromOffset(0, 72)
	quit.Size = UDim2.new(1, 0, 0, 30)
	quit.TextSize = 14

	local hint = label(placement, "", 14)
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -122)
	hint.Size = UDim2.fromOffset(460, 20)
	hint.TextStrokeTransparency = 0.4
	ui.hint = hint

	local ghost = label(placement, "", 30)
	ghost.AnchorPoint = Vector2.new(0.5, 0.5)
	ghost.Size = UDim2.fromOffset(48, 48)
	ghost.BackgroundColor3 = COLORS.hero
	ghost.BackgroundTransparency = 0.2
	ghost.Visible = false
	ghost.ZIndex = 10
	corner(ghost, 24)
	ui.ghost = ghost

	-- Combat : x1 / x2 / Quitter, discrets en haut à droite.
	local combat = Instance.new("Frame")
	combat.BackgroundTransparency = 1
	combat.Size = UDim2.fromScale(1, 1)
	combat.Parent = screen
	ui.combat = combat
	local controls = Instance.new("Frame")
	controls.AnchorPoint = Vector2.new(1, 0)
	controls.Position = UDim2.new(1, -12, 0, 12)
	controls.Size = UDim2.fromOffset(150, 36)
	controls.BackgroundTransparency = 1
	controls.Parent = combat
	local function speed(value: number)
		local remote = combatAction
		if remote then
			remote:InvokeServer("SetSpeed", value)
		end
	end
	ui.speed1 = button(controls, "x1", COLORS.card, function() speed(1) end)
	ui.speed1.Size = UDim2.fromOffset(44, 36)
	ui.speed2 = button(controls, "x2", COLORS.card, function() speed(2) end)
	ui.speed2.Position = UDim2.fromOffset(50, 0)
	ui.speed2.Size = UDim2.fromOffset(44, 36)
	-- "X" plutôt que "✕" : la police de l'interface n'a pas ce glyphe (carré vide).
	local stop = button(controls, "X", COLORS.card, function()
		request("Leave")
	end)
	stop.Position = UDim2.fromOffset(106, 0)
	stop.Size = UDim2.fromOffset(44, 36)

	-- Annonces brèves (vague, mini-boss) et message de fin.
	local banner = label(screen, "", 26, true)
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 60)
	banner.Size = UDim2.fromOffset(500, 40)
	banner.TextColor3 = COLORS.gold
	banner.TextStrokeTransparency = 0.3
	banner.Visible = false
	ui.banner = banner
	local toast = label(screen, "", 30, true)
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, 100)
	toast.Size = UDim2.fromOffset(600, 50)
	toast.TextColor3 = COLORS.gold
	toast.TextStrokeTransparency = 0.3
	toast.Visible = false
	ui.toast = toast

	local h = Instance.new("Highlight")
	h.FillColor = COLORS.gold
	h.OutlineColor = COLORS.gold
	h.FillTransparency = 0.6
	h.OutlineTransparency = 0.1
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Enabled = false
	h.Parent = screen
	highlight = h

	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function flash(target: TextLabel, text: string, seconds: number)
	target.Text = text
	target.Visible = true
	task.delay(seconds, function()
		if target.Text == text then
			target.Visible = false
			render()
		end
	end)
end

------------------------------------------------------------------ entrées

local function endDrag(position: Vector2)
	local current = drag
	drag = nil
	ui.ghost.Visible = false
	setHover(nil)
	if not current then
		return
	end
	if not current.moving then
		-- Simple appui : sélection (main) ou prise d'un héros posé (terrain).
		if selection and selection.classId == current.classId and selection.fromSlot == current.fromSlot then
			selection = nil
		else
			selection = { classId = current.classId, fromSlot = current.fromSlot }
		end
		render()
		return
	end
	selection = nil
	local target = caseAt(position)
	if target then
		request("Assign", target, current.classId)
	elseif current.fromSlot and overHand(position) then
		request("Clear", current.fromSlot)
	end
	render()
end

local function onInputBegan(input: InputObject, processed: boolean)
	if state.Phase ~= "Placement" or processed then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local position = Vector2.new(input.Position.X, input.Position.Y)
	local slot = caseAt(position)
	local placed = formation()
	if selection and slot then
		-- Deuxième toucher : poser ou déplacer le héros sélectionné.
		local chosen = selection
		selection = nil
		request("Assign", slot, chosen.classId)
		render()
	elseif slot and placed[slot] then
		drag = { classId = placed[slot], fromSlot = slot, start = position, moving = false }
	end
end

local function onInputChanged(input: InputObject)
	local current = drag
	if not current then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local position = Vector2.new(input.Position.X, input.Position.Y)
	if not current.moving and (position - current.start).Magnitude >= DRAG_THRESHOLD then
		current.moving = true
		ui.ghost.Text = classById[current.classId].Icon
		ui.ghost.Visible = true
		render()
	end
	if current.moving then
		ui.ghost.Position = UDim2.fromOffset(position.X, position.Y)
		setHover(caseAt(position))
	end
end

local function onInputEnded(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		if drag then
			endDrag(Vector2.new(input.Position.X, input.Position.Y))
		elseif selection and selection.fromSlot and overHand(Vector2.new(input.Position.X, input.Position.Y)) then
			-- Héros pris sur le terrain puis main touchée : retrait.
			local slot = selection.fromSlot
			selection = nil
			request("Clear", slot)
			render()
		end
	end
end

------------------------------------------------------------------ état serveur

local function applyState(newState: { [string]: any })
	local previous = state.Phase
	state = newState
	if newState.Phase == "Placement" and previous ~= "Placement" then
		selection, drag = nil, nil
		refreshCases()
		-- Restes visuels de l'intro de démonstration (client) posés sur les mêmes cases.
		for _, child in Workspace:GetChildren() do
			if child.Name == "IntroCombat" then
				child:Destroy()
			end
		end
	end
	local text = newState.Message
	if newState.Phase == "Closed" and typeof(text) == "string" and text ~= "" then
		flash(ui.toast, text, 4)
	else
		message = newState.Message
	end
	render()
end

local function onCombatEvents(_combatId: number, events: { { [string]: any } })
	for _, event in events do
		if event.Type == "WaveStarted" then
			flash(ui.banner, if event.WaveCount > 1 then `Vague {event.Wave}/{event.WaveCount}` else "Vague", 2)
		elseif event.Type == "MiniBossStarted" then
			flash(ui.banner, `★ {event.EnemyId}`, 2.5)
		elseif event.Type == "SpeedChanged" then
			ui.speed1.BackgroundColor3 = if event.Speed == 1 then COLORS.gold else COLORS.card
			ui.speed2.BackgroundColor3 = if event.Speed == 2 then COLORS.gold else COLORS.card
		end
	end
end

function ArenaPrepController:Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local stateEvent = remotes:WaitForChild("ArenaState", 30)
	local remote = remotes:WaitForChild("ArenaAction", 30)
	if not stateEvent or not stateEvent:IsA("RemoteEvent") or not remote or not remote:IsA("RemoteFunction") then
		return -- prototype désactivé côté serveur
	end
	action = remote
	build()
	stateEvent.OnClientEvent:Connect(applyState)
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputChanged:Connect(onInputChanged)
	UserInputService.InputEnded:Connect(onInputEnded)
	local combatRemote = remotes:WaitForChild("CombatAction", 30)
	local combatEvents = remotes:WaitForChild("CombatEvent", 30)
	if combatRemote and combatRemote:IsA("RemoteFunction") and combatEvents and combatEvents:IsA("RemoteEvent") then
		combatAction = combatRemote
		combatEvents.OnClientEvent:Connect(onCombatEvents)
	end
end

return ArenaPrepController
