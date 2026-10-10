--!strict
-- Préparation de combat dans l'arène du plot du joueur, côté client (voir docs/ARENA_PROTOTYPE.md).
--   • E = interaction avec le monde : un seul ProximityPrompt local, sur la dalle valide la plus
--     proche du personnage. Héros en main → « Placer » / « Remplacer » ; main vide près d'un héros
--     posé → « Reprendre » (il revient dans les mains). Mobile : toucher le prompt.
--   • Pancarte du stage, à l'entrée de l'arène (Arene.PanneauStage, bannière) : affichage seul (stage
--     choisi, ennemis agrégés, équipe x/4). SurfaceGui locale, sur la pancarte de SON arène.
--     E près de la pancarte : fenêtre des stages (ExpeditionView) → choisir un stage (SelectStage),
--     « Préparer l'équipe » (dalles mises en évidence) ou « Lancer » (Ready, 1 à 4 héros posés).
--   • Combat : pastille légère (vague, x1/x2, X) ; PV et énergie sont dans le monde
--     (CombatViewController). Les ultimes sont automatiques.
-- Le client n'envoie que des intentions (Place / Remove / SelectStage / Ready) ; ArenaService valide tout.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local ArenaStore = require(script.Parent.Parent.Arena.ArenaStore)
local PlacementState = require(script.Parent.Parent.Arena.PlacementState)
local PlotView = require(script.Parent.Parent.Arena.PlotView)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local AudioController = require(script.Parent.AudioController)
local RewardScreenController = require(script.Parent.RewardScreenController)
local ExpeditionView = require(script.Parent.Parent.UI.Views.ExpeditionView)

local C = UITheme.Colors
local T = UITheme.Transparency
local S = UITheme.Spacing
local SIZE = UITheme.Typography.Size

local ArenaPlacementController = {}

local TAG_CASE = "CaseHeros"
local GRID_HIDDEN = UITheme.World.GridHidden -- dalles hors préparation presque invisibles
local ABOVE_HOTBAR = 112 -- hauteur réservée à la hotbar (px)
local PROMPT_REFRESH = 0.1 -- secondes entre deux recherches de la dalle la plus proche
local PANEL_WIDTH = 264
local PANEL_HEIGHT = 300 -- pancarte : même proportion que la bannière de Arene.PanneauStage
local SIGN_NAME = ArenaConfig.SignName
local SIGN_BOARD = ArenaConfig.SignBoard
local RESULT_DELAY = 1.2 -- s après CombatEnded : la dernière unité a fini de se dissoudre

type CaseState = "Empty" | "Hover" | "ValidTarget" | "Occupied" | "Selected" | "Invalid"

local caseModels: { [number]: Instance } = {}
local casePoses: { [number]: BasePart } = {}
local caseHighlights: { [number]: Highlight } = {}
local gridModifier: number? = nil
local ui: { [string]: any } = {}
local speedRemote: RemoteFunction? = nil
local arenaRoot: Instance? = nil
local prompt: ProximityPrompt? = nil
local promptInfo: PlacementState.Prompt? = nil
local signPrompt: ProximityPrompt? = nil -- E près de la pancarte : fenêtre des stages
local prepMode = false -- « Préparer l'équipe » : dalles mises en évidence
local render: () -> () -- défini plus bas (rendu complet : panneau, statut, dalles)

------------------------------------------------------------------ arène du plot

local function refreshCases()
	local root = PlotView.arena()
	local known = 0
	for _ in caseModels do
		known += 1
	end
	-- Liste figée seulement une fois les 9 dalles répliquées (elles peuvent arriver après le plot).
	if root == arenaRoot and known >= 9 then
		return
	end
	for _, highlight in caseHighlights do
		highlight:Destroy()
	end
	table.clear(caseHighlights)
	table.clear(caseModels)
	table.clear(casePoses)
	gridModifier = nil
	arenaRoot = root
	if not root then
		return
	end
	for _, case in CollectionService:GetTagged(TAG_CASE) do
		local slot = case:GetAttribute("Slot")
		local pose = case:FindFirstChild("PointDePose", true)
		if case:IsDescendantOf(root) and typeof(slot) == "number" and pose and pose:IsA("BasePart") then
			caseModels[slot] = case
			casePoses[slot] = pose
			if ui.screen then
				local highlight = Instance.new("Highlight")
				highlight.Name = `Case{slot}`
				highlight.Adornee = case
				highlight.DepthMode = Enum.HighlightDepthMode.Occluded
				highlight.Enabled = false
				highlight.Parent = ui.screen
				caseHighlights[slot] = highlight
			end
		end
	end
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

-- Styles des états de dalle : UITheme.World.Case (Vide = aucune surbrillance).
local CASE_STYLE: { [string]: { Fill: Color3, FillT: number, Outline: Color3, OutlineT: number }? } = UITheme.World.Case :: any

-- Le personnage est-il dans SON arène ? (cercle autour des dalles + marge, indépendant de la rotation)
local arenaCenter: Vector3? = nil
local arenaRadius = 0
local inArena = false

local measuredCount = 0
local function measureArena()
	local sum, count = Vector3.zero, 0
	for _, pose in casePoses do
		sum += pose.Position
		count += 1
	end
	measuredCount = count
	if count == 0 then
		arenaCenter = nil
		return
	end
	local center = sum / count
	local radius = 0
	for _, pose in casePoses do
		radius = math.max(radius, ((pose.Position - center) * Vector3.new(1, 0, 1)).Magnitude)
	end
	arenaCenter, arenaRadius = center, radius + ArenaConfig.ZoneMargin -- même zone que le serveur
end

local function playerInArena(): boolean
	local center = arenaCenter
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not center or not root or not root:IsA("BasePart") then
		return false
	end
	return ((root.Position - center) * Vector3.new(1, 0, 1)).Magnitude <= arenaRadius
end

-- Lumière de placement : héros en main + joueur dans son arène + préparation (jamais en combat).
local function placementLit(): boolean
	return ArenaStore.placement.held ~= nil and inArena and not ArenaStore.inCombat() and ArenaStore.arena.Available ~= false
end

local function caseState(slot: number, formation: { [number]: string }, full: boolean): CaseState
	local held = ArenaStore.placement.held
	local active = promptInfo ~= nil and promptInfo.Slot == slot
	if not held or not placementLit() then
		-- Aucune lumière de placement ; seul « Préparer l'équipe » montre les dalles volontairement.
		return if prepMode and not held then (if formation[slot] then "Occupied" else "ValidTarget") else "Empty"
	end
	if formation[slot] == held.instanceId then
		return "Selected"
	end
	local valid = formation[slot] ~= nil or not full
	if active then
		return if valid then "Hover" else "Invalid"
	end
	if not valid then
		return "Empty"
	end
	return if formation[slot] then "Occupied" else "ValidTarget"
end

local function renderCases()
	local phase = ArenaStore.arena.Phase
	-- Dalles à leur apparence normale hors combat ; discrètes pendant le combat.
	setGrid(if phase == "Combat" then GRID_HIDDEN else 0)
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

------------------------------------------------------------------ prompt E (une seule dalle active)

local function heroName(instanceId: string): string
	local _, info = ArenaStore.heroInfo(instanceId)
	return if info then info.Name else "héros"
end

local function hidePrompt()
	promptInfo = nil
	if prompt then
		prompt.Enabled = false
		prompt.Parent = nil
	end
end

-- Dalle valide la plus proche du personnage, dans la portée du prompt.
local function updatePrompt()
	local p = prompt
	if not p then
		return
	end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	-- Entrée / sortie de l'arène : les lumières de placement s'allument / s'éteignent.
	local nowInArena = playerInArena()
	if nowInArena ~= inArena then
		inArena = nowInArena
		render() -- lumières de placement et la pancarte suivent la zone
	end
	if not root or not root:IsA("BasePart") or ArenaStore.inCombat() or ArenaStore.arena.Available == false then
		hidePrompt()
		return
	end
	local formation = ArenaStore.formation()
	local best: PlacementState.Prompt? = nil
	local bestDistance = ArenaConfig.PromptDistance
	for slot, pose in casePoses do
		local d = ((pose.Position - root.Position) * Vector3.new(1, 0, 1)).Magnitude
		if d <= bestDistance then
			local candidate = PlacementState.promptFor(ArenaStore.placement, slot, formation)
			if candidate then
				best, bestDistance = candidate, d
			end
		end
	end
	local previous = promptInfo
	promptInfo = best
	if not best then
		hidePrompt()
	else
		p.ActionText = `{best.Label} {heroName(best.HeroInstanceId)}`
		p.ObjectText = `Dalle {best.Slot}`
		p.Enabled = not ArenaStore.busy
		p.Parent = casePoses[best.Slot]
	end
	if (previous and previous.Slot) ~= (best and best.Slot) or (previous and previous.Label) ~= (best and best.Label) then
		renderCases()
	end
end

local function onPromptTriggered()
	local info = promptInfo
	if not info or ArenaStore.busy then
		return
	end
	if info.Action == "Place" then
		-- Le héros reste dans les mains tant que le serveur n'a pas accepté (refus : il y reste).
		ArenaStore.request("Place", info.Slot, info.HeroInstanceId)
	elseif ArenaStore.request("Remove", info.Slot) then
		PlacementState.takeBack(ArenaStore.placement, info.HeroInstanceId) -- « Reprendre » : retour dans les mains
		ArenaStore.notify()
	end
	updatePrompt()
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

local function line(parent: Instance, text: string, size: number, y: number, height: number): TextLabel
	local label = UIKit.text(parent, text, size)
	label.Position = UDim2.fromOffset(S.L, y)
	label.Size = UDim2.new(1, -2 * S.L, 0, height)
	label.TextXAlignment = Enum.TextXAlignment.Left
	return label
end

-- Pancarte du stage : le panneau remplit la bannière de Arene.PanneauStage (SurfaceGui de taille fixe,
-- même proportion que la bannière : 5,6 x 6,4 studs). Affichage seul : les actions sont dans la
-- fenêtre des stages (E près de la pancarte).
local function buildPanel(sign: SurfaceGui)
	local panel = UIKit.panel(sign, T.Panel)
	panel.Name = "PanneauArene"
	panel.Position = UDim2.fromOffset(0, 0)
	panel.Size = UDim2.fromScale(1, 1)
	ui.panel = panel
	ui.stage = line(panel, "", SIZE.Title, S.M, 36)
	line(panel, "Ennemis", SIZE.Label, 56, 22).TextColor3 = C.TextMuted
	local enemies = Instance.new("Frame")
	enemies.BackgroundTransparency = 1
	enemies.Position = UDim2.fromOffset(0, 80)
	enemies.Size = UDim2.new(1, 0, 0, 90)
	enemies.Parent = panel
	ui.enemies = enemies
	line(panel, "Équipe", SIZE.Label, 176, 22).TextColor3 = C.TextMuted
	ui.team = line(panel, "", SIZE.Heading, 198, 30)
	-- Consigne en pied de pancarte : « E · Choisir un stage », ou « Combat en cours ».
	local hint = UIKit.panel(panel, T.HUD, UITheme.Radius.Pill, UITheme.Stroke.Regular)
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -S.L)
	hint.Size = UDim2.new(1, -2 * S.L, 0, S.TouchTarget)
	local hintText = UIKit.text(hint, "", SIZE.Label)
	hintText.Size = UDim2.fromScale(1, 1)
	ui.hint = hintText
end

local function renderEnemies()
	local frame: Frame = ui.enemies
	frame:ClearAllChildren()
	local y = 0
	for _, enemy in ArenaStore.arena.Enemies or {} do
		local text = if enemy.MiniBoss then `Mini-boss : {enemy.EnemyId}` else `{enemy.EnemyId} ×{enemy.Count}`
		local label = line(frame, text, SIZE.Label, y, 24)
		label.TextColor3 = if enemy.MiniBoss then C.Gold else C.TextLight
		y += 28
	end
end

-- Fenêtre des stages (E près de la pancarte) : stages réels de StageConfig vus par le serveur
-- (débloqué / verrouillé / terminé), zone du stage choisi. Le serveur revérifie chaque action.
local function openStageMenu()
	local state = ArenaStore.arena
	if ArenaStore.inCombat() or state.Available == false then
		return
	end
	local zone = state.Zone or ArenaConfig.Zone
	local stages = {}
	for _, entry in state.Stages or {} do
		if entry.Zone == zone then
			table.insert(stages, { Stage = entry.Stage, Unlocked = entry.Status == "Unlocked", Cleared = entry.Cleared,
				Waves = entry.Waves, Enemies = entry.Enemies })
		end
	end
	if #stages == 0 then
		showToast("Aucun stage disponible")
		return
	end
	-- Nom de la zone : attribut « Nom » du modèle de zone de l'arène (ZoneId), sinon « Zone n ».
	local title = `Zone {zone}`
	local arenaModel = PlotView.arena()
	local zones = arenaModel and arenaModel:FindFirstChild("Zones")
	for _, model in if zones then zones:GetChildren() else {} do
		local name = model:GetAttribute("Nom")
		if model:GetAttribute("ZoneId") == zone and typeof(name) == "string" then
			title = `Zone {zone} · {name}`
		end
	end
	ExpeditionView.Show({ Zone = zone, Title = title, Stages = stages }, {
		Selected = state.Stage,
		Team = { Placed = ArenaStore.placedCount(), Max = state.MaxHeroes or ArenaConfig.MaxHeroes },
		OnSelect = function(z: number, stage: number)
			if z ~= ArenaStore.arena.Zone or stage ~= ArenaStore.arena.Stage then
				ArenaStore.request("SelectStage", z, stage)
			end
		end,
		OnPrepare = function()
			prepMode = true
			showToast("Prends un héros (1 à 0), approche-toi d'une dalle : E")
			ArenaStore.notify()
		end,
		OnLaunch = function(z: number, stage: number)
			if (z ~= ArenaStore.arena.Zone or stage ~= ArenaStore.arena.Stage)
				and not ArenaStore.request("SelectStage", z, stage)
			then
				return
			end
			PlacementState.cancel(ArenaStore.placement) -- plus rien en main : la formation se verrouille
			prepMode = false
			ArenaStore.request("Ready")
		end,
	})
end

local function build()
	local screen = Instance.new("ScreenGui")
	screen.Name = "PlacementArene"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ui.screen = screen

	-- Statut du héros en main, juste au-dessus de la hotbar.
	local status = pill(screen, T.HUD)
	status.Size = UDim2.fromOffset(560, 52)
	ui.status = status
	local statusText = UIKit.text(status, "", SIZE.Label)
	statusText.Position = UDim2.fromOffset(S.L, 0)
	statusText.Size = UDim2.new(1, -2 * S.L - 112, 1, 0)
	statusText.TextXAlignment = Enum.TextXAlignment.Left
	ui.statusText = statusText
	local cancel = UIKit.button(status, "Annuler", "Secondary", UDim2.fromOffset(104, 40), function()
		PlacementState.cancel(ArenaStore.placement)
		ArenaStore.notify()
	end)
	cancel.holder.AnchorPoint = Vector2.new(1, 0.5)
	cancel.holder.Position = UDim2.new(1, -S.S, 0.5, 0)
	cancel.label.TextSize = SIZE.Label

	local sign = Instance.new("SurfaceGui")
	sign.Name = "PancarteStage"
	sign.ResetOnSpawn = false
	sign.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	sign.CanvasSize = Vector2.new(PANEL_WIDTH, PANEL_HEIGHT)
	sign.Face = Enum.NormalId.Front -- la face avant de la bannière regarde la zone de préparation
	sign.LightInfluence = 0
	sign.MaxDistance = UITheme.World.CombatDistance
	sign.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sign.Enabled = false -- tant que la pancarte de son arène n'est pas connue
	ui.sign = sign
	buildPanel(sign)
	sign.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- Combat : vague, x1 / x2, quitter.
	local combat = pill(screen, T.HUD)
	combat.Size = UDim2.fromOffset(340, 56)
	combat.Visible = false
	ui.combat = combat
	local wave = UIKit.text(combat, "Vague", SIZE.Label)
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
	x1.label.TextSize = SIZE.Label
	local x2 = UIKit.button(combat, "x2", "Tab", UDim2.fromOffset(56, 40 + UITheme.Shadow.ButtonLip), function()
		speed(2)
	end)
	x2.holder.Position = UDim2.fromOffset(202, 4)
	x2.label.TextSize = SIZE.Label
	ui.x1, ui.x2 = x1, x2
	local quit = UIKit.button(combat, "X", "Danger", UDim2.fromOffset(44, 40 + UITheme.Shadow.ButtonLip), function()
		ArenaStore.request("Leave")
	end)
	quit.holder.Position = UDim2.fromOffset(282, 4)

	-- Annonce de vague / mini-boss, résultat, messages brefs.
	local banner = UIKit.text(screen, "", SIZE.Title)
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 70)
	banner.Size = UDim2.fromOffset(500, 44)
	banner.TextColor3 = C.Gold
	banner.Visible = false
	ui.banner = banner
	local result = UIKit.text(screen, "", SIZE.Hero)
	result.AnchorPoint = Vector2.new(0.5, 0.5)
	result.Position = UDim2.fromScale(0.5, 0.32)
	result.Size = UDim2.fromOffset(600, 80)
	result.Visible = false
	ui.result = result
	local toast = UIKit.panel(screen, T.Tooltip, UITheme.Radius.Pill, UITheme.Stroke.Regular)
	toast.BackgroundColor3 = C.Cream
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, 24)
	toast.Size = UDim2.fromOffset(520, 46)
	toast.Visible = false
	ui.toast = toast
	local toastText = Instance.new("TextLabel")
	toastText.BackgroundTransparency = 1
	toastText.FontFace = UITheme.Typography.Display
	toastText.TextSize = SIZE.Label
	toastText.TextColor3 = C.InkSoft
	toastText.Size = UDim2.fromScale(1, 1)
	toastText.Parent = toast
	ui.toastText = toastText

	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

function render()
	local held = ArenaStore.placement.held
	local state = ArenaStore.arena
	local phase = state.Phase
	local count = ArenaStore.placedCount()
	local max = state.MaxHeroes or ArenaConfig.MaxHeroes
	local inCombat = phase == "Combat"
	ui.combat.Visible = inCombat
	-- Pancarte de SON arène (pas celle d'un autre plot) ; pendant le combat elle garde les infos.
	local arenaModel = PlotView.arena()
	local signModel = arenaModel and arenaModel:FindFirstChild(SIGN_NAME)
	local board = signModel and signModel:FindFirstChild(SIGN_BOARD)
	local signBoard = if board and board:IsA("BasePart") then board else nil
	ui.sign.Adornee = signBoard
	ui.sign.Enabled = signBoard ~= nil and state.Available ~= false
	ui.stage.Text = `Stage {state.Zone or "?"}-{state.Stage or "?"}`
	ui.team.Text = `{count} / {max}`
	ui.hint.Text = if inCombat then "Combat en cours" else "E · Choisir un stage"
	renderEnemies()
	local sp = signPrompt
	if sp then
		sp.ObjectText = `Stage {state.Zone or "?"}-{state.Stage or "?"}`
		sp.Parent = signBoard
		sp.Enabled = signBoard ~= nil and not inCombat and state.Available ~= false
	end
	if inCombat then
		ExpeditionView.Hide()
	end
	if held and not inCombat then
		ui.statusText.Text = `{heroName(held.instanceId)} en main · approche-toi d'une dalle : E`
		ui.status.Visible = true
	else
		ui.status.Visible = false
	end
	renderCases()
end

------------------------------------------------------------------ entrées et événements

local function onInputBegan(input: InputObject, processed: boolean)
	if not processed and input.KeyCode == Enum.KeyCode.Escape and ArenaStore.placement.held then
		PlacementState.cancel(ArenaStore.placement)
		ArenaStore.notify()
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
			AudioController.Play("MiniBoss")
			ui.banner.Text = `★ {event.EnemyId}`
			flash(ui.banner, 2.5)
		elseif event.Type == "SpeedChanged" then
			ui.x1.setSelected(event.Speed == 1)
			ui.x2.setSelected(event.Speed == 2)
		elseif event.Type == "CombatEnded" then
			-- Écran de fin (#17, #19) une fois la dernière unité dissoute. Un seul CombatEnded par
			-- combat, envoyé par le serveur après l'attribution : FirstClear et Rewards sont les
			-- récompenses de RewardService (#9), déjà sauvegardées. L'écran ne fait que les montrer.
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

function ArenaPlacementController:Start()
	build()
	refreshCases()
	measureArena()
	local p = Instance.new("ProximityPrompt")
	p.Name = "PlacementHeros"
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.HoldDuration = 0
	p.MaxActivationDistance = ArenaConfig.PromptDistance + 2
	p.RequiresLineOfSight = false
	p.Enabled = false
	p.Triggered:Connect(onPromptTriggered)
	prompt = p
	local s = Instance.new("ProximityPrompt")
	s.Name = "ChoixStage"
	s.ActionText = "Choisir un stage"
	s.KeyboardKeyCode = Enum.KeyCode.E
	s.HoldDuration = 0
	s.MaxActivationDistance = ArenaConfig.SignDistance - 2 -- le serveur vérifie SignDistance (marge réseau)
	s.RequiresLineOfSight = false
	s.Enabled = false
	s.Triggered:Connect(openStageMenu)
	signPrompt = s

	ArenaStore.changed.Event:Connect(function()
		if ArenaStore.inCombat() then
			prepMode = false
		end
		render()
		updatePrompt()
	end)
	ArenaStore.toast.Event:Connect(showToast)
	UserInputService.InputBegan:Connect(onInputBegan)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= PROMPT_REFRESH then
			elapsed = 0
			updatePrompt()
		end
	end)
	-- Le plot peut être attribué après le démarrage (chargement des données).
	task.spawn(function()
		while true do
			task.wait(1)
			local before = arenaRoot
			refreshCases()
			-- Les dalles peuvent se répliquer après le plot : mesurer tant que ce n'est pas fait.
			local count = 0
			for _ in casePoses do
				count += 1
			end
			if arenaRoot ~= before or arenaCenter == nil or count ~= measuredCount then
				measureArena()
				render()
			end
		end
	end)
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
