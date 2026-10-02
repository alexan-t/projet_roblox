--!strict
-- Préparation et HUD minimal du combat, côté client (voir docs/ARENA_PROTOTYPE.md, docs/COMBAT.md).
-- Principe : on agit sur le champ de bataille, pas dans des menus.
--   • Placement : la « main » (héros disponibles) en bas de l'écran. Glisser un héros sur une case
--     du 3x3, ou le toucher puis toucher une case. Un héros posé se déplace en le glissant vers une
--     autre case, ou se retire en le glissant vers la main. La grille n'est bien visible que pendant
--     une sélection ou un glisser ; sinon elle reste presque invisible.
--   • Combat : une pastille basse (vague, x1/x2, quitter) ; PV et mana sont au-dessus des unités
--     (CombatViewController). Une annonce brève signale les vagues et le mini-boss.
--   • Fin : écran Victoire / Défaite (RewardScreenController), puis retour au plot.
-- Présentation : design system (docs/UI_DESIGN_SYSTEM.md § 10), composants UIKit, icônes de classe en 3D
-- (Icons) ; aucune valeur de style en dur — issue #19.
-- Le client n'envoie que des demandes ; ArenaService et CombatService décident tout.
-- Démonstration Studio sans serveur : attribut Workspace.ApercuHudCombat = true (états factices ;
-- « Combattre » joue un combat simulé puis l'écran de victoire).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local Icons = require(script.Parent.Parent.UI.Icons)
local AudioController = require(script.Parent.AudioController)
local RewardScreenController = require(script.Parent.RewardScreenController)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local Colors = UITheme.Colors
local Typography = UITheme.Typography
local Spacing = UITheme.Spacing

local ArenaPrepController = {}

local TAG_CASE = "CaseHeros"
local DRAG_THRESHOLD = 8 -- pixels avant qu'un appui devienne un glisser
local GRID_HIDDEN = 0.85 -- transparence locale des cases hors placement (presque invisibles)
local CARD = Vector2.new(96, 128) -- carte de la main
local LIFT = 12 -- px : carte sélectionnée soulevée
local RESULT_DELAY = 1.2 -- s après CombatEnded : la dernière unité a fini de disparaître

local classById: { [string]: { Id: string, Name: string, Icon: string } } = {}
for _, class in ArenaConfig.HeroClasses do
	classById[class.Id] = class
end

type Drag = { classId: string, fromSlot: number?, start: Vector2, moving: boolean }
type Card = { holder: Frame, frame: Frame, border: UIStroke, badge: Frame? }

local action: RemoteFunction? = nil
local combatAction: RemoteFunction? = nil
local state: { [string]: any } = { Phase = "Closed" }
local selection: { classId: string, fromSlot: number? }? = nil
local drag: Drag? = nil
local ui: { [string]: any } = {}
local cards: { [string]: Card } = {}
local caseModels: { [number]: Instance } = {}
local highlight: Highlight? = nil
local message: string? = nil -- dernier refus ou message du serveur
local resultShown = false -- l'écran de fin remplace l'annonce « Victoire ! » du serveur
local demo: ((name: string, ...any) -> ())? = nil -- démonstration Studio : remplace le serveur

------------------------------------------------------------------ outils

local function request(name: string, ...: any)
	if demo then
		demo(name, ...)
		return
	end
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
	screen.Enabled = phase ~= "Closed" or #ui.announces:GetChildren() > 0
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
		table.insert(enemies, if enemy.MiniBoss then `Mini-boss {enemy.EnemyId}` else `{enemy.EnemyId} ×{enemy.Count}`)
	end
	ui.roster.Text = `Stage {state.Zone}-{state.Stage}  ·  {table.concat(enemies, "  ·  ")}`
	ui.count.Text = `Héros {count}/{max}`
	for classId, card in cards do
		local slot: number? = nil
		for s, placedClass in placed do
			if placedClass == classId then
				slot = s
			end
		end
		local selected = selection ~= nil and selection.classId == classId
		-- carte posée : badge « Équipé » et contour Selected (design system § 6)
		card.border.Color = if slot then Colors.Selected else UITheme.Stroke.Color
		card.border.Thickness = if slot then UITheme.Stroke.Thick else UITheme.Stroke.Regular
		if slot and not card.badge then
			card.badge = UIKit.badge(card.frame, "Équipé", Colors.Gold)
			UIKit.popIn(card.badge :: Frame)
		elseif not slot and card.badge then
			(card.badge :: Frame):Destroy()
			card.badge = nil
		end
		card.frame.Position = UDim2.fromOffset(0, if selected then -LIFT else 0)
	end
	ui.fight.SetStyle(if count > 0 then "Primary" else "Disabled")
	if selection then
		ui.hint.Text = if selection.fromSlot
			then "Touche une case pour le déplacer, ou la main pour le retirer"
			else "Touche une case pour le poser"
	else
		ui.hint.Text = message or (if count == 0 then "Glisse un héros sur une case" else "")
	end
end

------------------------------------------------------------------ construction

local function heroTemplate(): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Combat")
	local template = folder and folder:FindFirstChild(ArenaConfig.HeroTemplate)
	return if template and template:IsA("Model") then template else nil
end

-- Pastille ronde crème qui porte l'icône 3D d'une classe.
local function iconChip(parent: Instance, classId: string, size: number): Frame
	local chip = Instance.new("Frame")
	chip.Name = "Classe"
	chip.Size = UDim2.fromOffset(size, size)
	chip.BackgroundColor3 = Colors.Cream
	chip.Parent = parent
	UIKit.corner(chip, UITheme.Radius.Pill)
	UIKit.stroke(chip, UITheme.Stroke.Thin)
	Icons.viewport(chip, classId)
	return chip
end

local function build()
	local screen = UIKit.screen("PreparationCombat", 5)
	screen.IgnoreGuiInset = false -- mêmes coordonnées que les entrées (souris, toucher)
	screen.Enabled = false
	ui.screen = screen

	-- Placement : roster en haut, main en bas, deux actions.
	local placement = Instance.new("Frame")
	placement.Name = "Placement"
	placement.BackgroundTransparency = 1
	placement.Size = UDim2.fromScale(1, 1)
	placement.Parent = screen
	ui.placement = placement

	local rosterPill = UIKit.pill(placement, Vector2.new(560, 40))
	rosterPill.Name = "Roster"
	rosterPill.AnchorPoint = Vector2.new(0.5, 0)
	rosterPill.Position = UDim2.new(0.5, 0, 0, Spacing.ScreenMargin)
	ui.roster = UIKit.text(rosterPill, "", Typography.Size.Label)

	local handWidth = #ArenaConfig.HeroClasses * (CARD.X + Spacing.S) + 210
	local hand = Instance.new("Frame")
	hand.Name = "Main"
	hand.AnchorPoint = Vector2.new(0.5, 1)
	hand.Position = UDim2.new(0.5, 0, 1, -Spacing.ScreenMargin)
	hand.Size = UDim2.fromOffset(handWidth, CARD.Y + LIFT)
	hand.BackgroundTransparency = 1
	hand.Parent = placement
	ui.hand = hand
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, -210, 1, 0)
	row.Parent = hand
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.Padding = UDim.new(0, Spacing.S)
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = row
	local template = heroTemplate()
	for index, class in ArenaConfig.HeroClasses do
		local holder = Instance.new("Frame")
		holder.Name = class.Id
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromOffset(CARD.X, CARD.Y)
		holder.LayoutOrder = index
		holder.Parent = row
		-- Cadre neutre : la rareté des héros n'existe pas encore (#10).
		local frame = UIKit.card(holder, { Size = CARD, Name = class.Name, Model = template })
		-- icône de classe en bas à gauche de l'illustration (le haut reçoit le badge « Équipé »)
		local chip = iconChip(frame, class.Id, 30)
		chip.AnchorPoint = Vector2.new(0, 1)
		chip.Position = UDim2.new(0, Spacing.XS, 0.66, 0)
		chip.ZIndex = 3
		local touch = Instance.new("TextButton")
		touch.Name = "Toucher"
		touch.BackgroundTransparency = 1
		touch.Text = ""
		touch.Size = UDim2.fromScale(1, 1)
		touch.ZIndex = 10
		touch.Parent = frame
		local scale = Instance.new("UIScale")
		scale.Parent = frame
		touch.MouseEnter:Connect(function()
			UIKit.tween(scale, UITheme.Animation.Hover, { Scale = UITheme.Animation.Scale.Hover })
		end)
		touch.MouseLeave:Connect(function()
			UIKit.tween(scale, UITheme.Animation.Hover, { Scale = 1 })
		end)
		touch.InputBegan:Connect(function(input: InputObject)
			if state.Phase == "Placement" and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
				drag = { classId = class.Id, fromSlot = nil, start = Vector2.new(input.Position.X, input.Position.Y), moving = false }
			end
		end)
		cards[class.Id] = { holder = holder, frame = frame, border = frame:FindFirstChildOfClass("UIStroke") :: UIStroke }
	end
	local side = Instance.new("Frame")
	side.Name = "Actions"
	side.BackgroundTransparency = 1
	side.AnchorPoint = Vector2.new(1, 1)
	side.Position = UDim2.fromScale(1, 1)
	side.Size = UDim2.new(0, 196, 0, CARD.Y)
	side.Parent = hand
	ui.count = UIKit.text(side, "", Typography.Size.Label)
	ui.count.Size = UDim2.new(1, 0, 0, 22)
	ui.fight = UIKit.button(side, {
		Text = "Combattre",
		Style = "Disabled",
		Size = Vector2.new(196, 52),
		OnClick = function()
			if #(state.Formation or {}) > 0 then
				selection = nil
				request("Fight")
			end
		end,
	})
	ui.fight.Holder.Position = UDim2.fromOffset(0, 26)
	local quit = UIKit.button(side, {
		Text = "Quitter",
		Style = "Secondary",
		Size = Vector2.new(196, 38),
		TextSize = Typography.Size.Label,
		OnClick = function()
			request("Leave")
		end,
	})
	quit.Holder.Position = UDim2.fromOffset(0, 26 + 52 + UITheme.Shadow.ButtonLip + Spacing.S)

	local hint = UIKit.text(placement, "", Typography.Size.Label)
	hint.Name = "Aide"
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -(Spacing.ScreenMargin + CARD.Y + LIFT + Spacing.M))
	hint.Size = UDim2.fromOffset(640, 24)
	ui.hint = hint

	local ghost = Instance.new("Frame")
	ghost.Name = "Fantome"
	ghost.AnchorPoint = Vector2.new(0.5, 0.5)
	ghost.Size = UDim2.fromOffset(56, 56)
	ghost.BackgroundTransparency = 1
	ghost.Visible = false
	ghost.ZIndex = 20
	ghost.Parent = placement
	ui.ghost = ghost

	-- Combat : pastille basse — vague, x1 / x2 (onglets, actif doré), quitter (rond « X »).
	local combat = Instance.new("Frame")
	combat.Name = "Combat"
	combat.BackgroundTransparency = 1
	combat.Size = UDim2.fromScale(1, 1)
	combat.Parent = screen
	ui.combat = combat
	local bar = UIKit.pill(combat, Vector2.new(330, 64))
	bar.Name = "BarreCombat"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -Spacing.ScreenMargin)
	local wave = UIKit.text(bar, "Vague 1", Typography.Size.Label, { Align = Enum.TextXAlignment.Left })
	wave.Position = UDim2.fromOffset(Spacing.XL, 0)
	wave.Size = UDim2.new(0, 120, 1, 0)
	ui.wave = wave
	local function speed(value: number)
		if demo then
			demo("SetSpeed", value)
			return
		end
		local remote = combatAction
		if remote then
			remote:InvokeServer("SetSpeed", value)
		end
	end
	local tabs = UIKit.tabs(bar, { Items = { "x1", "x2" }, Selected = 1, OnSelect = speed })
	tabs.Frame.AnchorPoint = Vector2.new(0, 0.5)
	tabs.Frame.Position = UDim2.new(0, 140, 0.5, 0)
	ui.speed = tabs
	-- "X" plutôt que "✕" : la police de l'interface n'a pas ce glyphe (carré vide).
	local stop = UIKit.roundButton(bar, {
		Text = "X",
		Name = "Quitter",
		OnClick = function()
			request("Leave")
		end,
	})
	stop.AnchorPoint = Vector2.new(1, 0.5)
	stop.Position = UDim2.new(1, -Spacing.M, 0.5, 0)

	-- Annonces brèves (vague, mini-boss) et message de fin.
	local announces = Instance.new("Folder")
	announces.Name = "Annonces"
	announces.Parent = screen
	ui.announces = announces

	local h = Instance.new("Highlight")
	h.FillColor = Colors.Selected
	h.OutlineColor = Colors.Selected
	h.FillTransparency = 0.6
	h.OutlineTransparency = 0.1
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Enabled = false
	h.Parent = screen
	highlight = h
end

-- Annonce (UIKit) rangée dans le dossier Annonces : l'écran reste affiché tant qu'elle est visible.
local function announce(text: string, color: Color3?, hold: number)
	local screen: ScreenGui? = ui.screen
	if not screen then
		return
	end
	screen.Enabled = true
	local label = UIKit.announce(screen, text, { Color = color, Hold = hold })
	label.Parent = ui.announces
	label.Destroying:Connect(function()
		task.defer(render)
	end)
end

------------------------------------------------------------------ entrées

local function setGhost(classId: string?)
	local ghost: Frame = ui.ghost
	for _, child in ghost:GetChildren() do
		child:Destroy()
	end
	if classId then
		iconChip(ghost, classId, 56)
	end
	ghost.Visible = classId ~= nil
end

local function endDrag(position: Vector2)
	local current = drag
	drag = nil
	setGhost(nil)
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
		setGhost(current.classId)
		render()
	end
	if current.moving then
		-- le fantôme suit le doigt ; l'écran est mis à l'échelle (UIScale), la position non
		local scale = (ui.screen :: ScreenGui):FindFirstChildOfClass("UIScale")
		local factor = if scale then scale.Scale else 1
		ui.ghost.Position = UDim2.fromOffset(position.X / factor, position.Y / factor)
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
		resultShown = false
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
		-- « Victoire ! » / « Défaite… » : déjà dit par l'écran de fin s'il est affiché
		if not resultShown then
			announce(text, nil, 3)
		end
	else
		message = newState.Message
	end
	render()
end

local function onCombatEvents(_combatId: number, events: { { [string]: any } })
	for _, event in events do
		if event.Type == "WaveStarted" then
			local waveText = if event.WaveCount > 1 then `Vague {event.Wave}/{event.WaveCount}` else "Vague 1"
			ui.wave.Text = waveText
			announce(waveText, nil, 1.6)
		elseif event.Type == "MiniBossStarted" then
			ui.wave.Text = "Mini-boss"
			AudioController.Play("MiniBoss")
			announce(`Mini-boss : {event.EnemyId}`, Colors.Torch, 2)
		elseif event.Type == "SpeedChanged" then
			ui.speed.Select(if event.Speed == 2 then 2 else 1)
		elseif event.Type == "CombatEnded" then
			-- Écran de fin : les récompenses viendront de RewardService (#9).
			resultShown = true
			local rewards = event.Rewards
			task.delay(RESULT_DELAY, function()
				RewardScreenController.Show({
					Result = event.Result,
					FirstClear = event.FirstClear,
					Rewards = if typeof(rewards) == "table" then rewards else nil,
				})
			end)
		end
	end
end

------------------------------------------------------------------ démonstration Studio

-- Remplace le serveur par des états factices, pour voir et manipuler l'interface sans ArenaService.
local function startDemo()
	refreshCases()
	local mock = {
		Phase = "Placement",
		Zone = 1,
		Stage = 1,
		Enemies = { { EnemyId = "Slime", Count = 2 }, { EnemyId = "Gobelin", Count = 1 }, { EnemyId = "Boss", Count = 1, MiniBoss = true } },
		Formation = { { Slot = 5, ClassId = "Paladin" } },
		MaxHeroes = ArenaConfig.MaxHeroes,
	}
	local function send()
		applyState(table.clone(mock))
	end
	demo = function(name: string, ...: any)
		local args = { ... }
		if name == "Assign" then
			local slot, classId = args[1], args[2]
			local kept = {}
			for _, entry in mock.Formation do
				if entry.Slot ~= slot and entry.ClassId ~= classId then
					table.insert(kept, entry)
				end
			end
			if #kept < mock.MaxHeroes then
				table.insert(kept, { Slot = slot, ClassId = classId })
				mock.Formation = kept
			end
			send()
		elseif name == "Clear" then
			local kept = {}
			for _, entry in mock.Formation do
				if entry.Slot ~= args[1] then
					table.insert(kept, entry)
				end
			end
			mock.Formation = kept
			send()
		elseif name == "SetSpeed" then
			onCombatEvents(0, { { Type = "SpeedChanged", Speed = args[1] } })
		elseif name == "Fight" then
			mock.Phase = "Combat"
			send()
			task.spawn(function()
				onCombatEvents(0, { { Type = "WaveStarted", Wave = 1, WaveCount = 2 } })
				task.wait(3)
				onCombatEvents(0, { { Type = "WaveStarted", Wave = 2, WaveCount = 2 } })
				task.wait(2.5)
				onCombatEvents(0, { { Type = "MiniBossStarted", EnemyId = "Boss" } })
				task.wait(3)
				if mock.Phase ~= "Combat" then
					return
				end
				onCombatEvents(0, { { Type = "CombatEnded", Result = "Victory" } })
				task.wait(1.7)
				applyState({ Phase = "Closed", Message = "Victoire !" })
				-- retour à la préparation après « Continuer » (ou 8 s)
				task.wait(8)
				RewardScreenController.Hide()
				mock.Phase = "Placement"
				send()
			end)
		elseif name == "Leave" then
			mock.Phase = if mock.Phase == "Combat" then "Placement" else "Closed"
			send()
			if mock.Phase == "Closed" then
				task.delay(3, function()
					mock.Phase = "Placement"
					send()
				end)
			end
		end
	end
	send()
end

function ArenaPrepController:Start()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if RunService:IsStudio() and not remotes and Workspace:GetAttribute("ApercuHudCombat") == true then
		build()
		UserInputService.InputBegan:Connect(onInputBegan)
		UserInputService.InputChanged:Connect(onInputChanged)
		UserInputService.InputEnded:Connect(onInputEnded)
		startDemo()
		return
	end
	remotes = ReplicatedStorage:WaitForChild("Remotes")
	local stateEvent = (remotes :: Instance):WaitForChild("ArenaState", 30)
	local remote = (remotes :: Instance):WaitForChild("ArenaAction", 30)
	if not stateEvent or not stateEvent:IsA("RemoteEvent") or not remote or not remote:IsA("RemoteFunction") then
		return -- prototype désactivé côté serveur
	end
	action = remote
	build()
	stateEvent.OnClientEvent:Connect(applyState)
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputChanged:Connect(onInputChanged)
	UserInputService.InputEnded:Connect(onInputEnded)
	local combatRemote = (remotes :: Instance):WaitForChild("CombatAction", 30)
	local combatEvents = (remotes :: Instance):WaitForChild("CombatEvent", 30)
	if combatRemote and combatRemote:IsA("RemoteFunction") and combatEvents and combatEvents:IsA("RemoteEvent") then
		combatAction = combatRemote
		combatEvents.OnClientEvent:Connect(onCombatEvents)
	end
end

return ArenaPrepController
