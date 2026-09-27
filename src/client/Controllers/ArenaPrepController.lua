--!strict
-- PROTOTYPE de préparation de combat, côté client (voir docs/ARENA_PROTOTYPE.md).
-- Grande fenêtre ouverte par le prompt de l'arène :
--   • en haut, le camp ennemi (3x3) : "?" pendant la préparation, révélé une fois le combat lancé ;
--   • dessous, la formation du joueur (3x3, rang Avant côté ennemis) ;
--   • à droite, la collection de héros.
-- Au clic ou au toucher : choisir une case puis un héros (ou l'inverse) ; « Retirer » vide la case.
-- Pendant le combat : barre compacte (vague, x1/x2, héros avec PV/énergie et bouton Ultime),
-- alimentée par les événements de CombatService (Remotes.CombatEvent).
-- Le style reste provisoire (#11). Le client n'envoie que des demandes ; le serveur décide tout.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)

local ArenaPrepController = {}

-- Palette provisoire reprise de l'intro de combat (or, rouge) et de la bannière du royaume (bleu).
local COLORS = {
	shade = Color3.fromRGB(0, 0, 0),
	panel = Color3.fromRGB(24, 26, 34),
	cell = Color3.fromRGB(42, 46, 60),
	hero = Color3.fromRGB(52, 96, 176),
	enemy = Color3.fromRGB(150, 60, 50),
	gold = Color3.fromRGB(255, 205, 80),
	text = Color3.fromRGB(240, 240, 240),
	muted = Color3.fromRGB(150, 155, 170),
	disabled = Color3.fromRGB(70, 72, 80),
}
local ROWS = { "Avant", "Milieu", "Arrière" }

local classNames: { [string]: string } = {}
for _, class in ArenaConfig.HeroClasses do
	classNames[class.Id] = class.Name
end

local action: RemoteFunction? = nil
local combatAction: RemoteFunction? = nil
-- Vue locale du combat, reconstruite à partir des événements du serveur (jamais une autorité).
local combat: { [string]: any } = { units = {} }
local state: { [string]: any } = { Phase = "Closed" }
local selectedCell: number? = nil
local selectedHero: string? = nil
local windowOpen = false
local ui: { [string]: any } = {}

------------------------------------------------------------------ construction

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

local function text(parent: Instance, content: string, size: number, bold: boolean?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, size + 8)
	l.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	l.TextSize = size
	l.TextColor3 = COLORS.text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.Text = content
	l.Parent = parent
	return l
end

local function button(parent: Instance, content: string, color: Color3, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.BackgroundColor3 = color
	b.Font = Enum.Font.GothamBold
	b.TextSize = 16
	b.TextColor3 = COLORS.text
	b.TextWrapped = true
	b.Text = content
	b.Parent = parent
	corner(b, 8)
	b.Activated:Connect(onClick)
	return b
end

local function vertical(parent: Instance, padding: number)
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Vertical
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, padding)
	l.Parent = parent
end

-- Grille 3x3 carrée ; cellule n à la position (ligne, colonne) donnée par place(n).
local function grid(parent: Instance, name: string, place: (number) -> (number, number), onCell: ((number) -> ())?): { TextButton }
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0.41, 0)
	holder.Parent = parent
	local square = Instance.new("Frame")
	square.BackgroundTransparency = 1
	square.AnchorPoint = Vector2.new(0.5, 0.5)
	square.Position = UDim2.fromScale(0.5, 0.5)
	square.Size = UDim2.fromScale(1, 1)
	square.Parent = holder
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = square
	local cells: { TextButton } = {}
	for n = 1, 9 do
		local row, column = place(n)
		local cell = Instance.new("TextButton")
		cell.Name = `Case_{n}`
		cell.AutoButtonColor = onCell ~= nil
		cell.BackgroundColor3 = COLORS.cell
		cell.Position = UDim2.new(column / 3, 3, row / 3, 3)
		cell.Size = UDim2.new(1 / 3, -6, 1 / 3, -6)
		cell.Font = Enum.Font.GothamBold
		cell.TextScaled = true
		cell.TextColor3 = COLORS.text
		cell.Text = ""
		cell.Parent = square
		corner(cell, 8)
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft, padding.PaddingRight = UDim.new(0.08, 0), UDim.new(0.08, 0)
		padding.PaddingTop, padding.PaddingBottom = UDim.new(0.2, 0), UDim.new(0.2, 0)
		padding.Parent = cell
		stroke(cell, COLORS.gold, 0).Name = "Selection"
		if onCell then
			cell.Activated:Connect(function()
				onCell(n)
			end)
		end
		cells[n] = cell
	end
	return cells
end

------------------------------------------------------------------ logique

local function request(name: string, ...: any)
	local remote = action
	if not remote then
		return
	end
	local ok, reason = remote:InvokeServer(name, ...)
	if not ok and reason and ui.message then
		ui.message.Text = reason
	end
end

local function formation(): { [number]: string }
	local map = {}
	for _, entry in state.Formation or {} do
		map[entry.Slot] = entry.ClassId
	end
	return map
end

local function slotOf(classId: string): number?
	for slot, placed in formation() do
		if placed == classId then
			return slot
		end
	end
	return nil
end

local render: () -> ()

local function onHeroCell(n: number)
	if state.Phase ~= "Placement" then
		return
	end
	if selectedHero then
		local hero = selectedHero
		selectedHero, selectedCell = nil, nil
		request("Assign", n, hero)
	else
		selectedCell = if selectedCell == n then nil else n
		render()
	end
end

local function onHeroCard(classId: string)
	if state.Phase ~= "Placement" then
		return
	end
	if selectedCell then
		local cell = selectedCell
		selectedHero, selectedCell = nil, nil
		request("Assign", cell, classId)
	else
		selectedHero = if selectedHero == classId then nil else classId
		render()
	end
end

render = function()
	local screen: ScreenGui? = ui.screen
	if not screen then
		return
	end
	local phase = state.Phase
	if phase == "Closed" then
		screen.Enabled = ui.toast.Visible
		ui.shade.Visible, ui.window.Visible, ui.bar.Visible = false, false, false
		windowOpen = false
		selectedCell, selectedHero = nil, nil
		return
	end
	screen.Enabled = true
	local placing = phase == "Placement"
	ui.shade.Visible = windowOpen
	ui.window.Visible = windowOpen
	ui.bar.Visible = not windowOpen

	local placed = formation()
	local count = #(state.Formation or {})
	local max = state.MaxHeroes or ArenaConfig.MaxHeroes
	local enemies = {}
	for _, enemy in state.Enemies or {} do
		table.insert(enemies, if enemy.MiniBoss then `Mini-boss {enemy.EnemyId}` else `{enemy.EnemyId} ×{enemy.Count}`)
	end
	local enemyText = table.concat(enemies, "  ·  ")

	ui.title.Text = `Stage {state.Zone}-{state.Stage} — {if placing then "Préparation" else "Combat"}`
	ui.subtitle.Text = `Tu vas affronter : {enemyText}`
	-- Barre de combat : vague, vitesse, héros.
	local stageText = if combat.result == "Victory" then "Victoire !"
		elseif combat.result == "Defeat" then "Défaite…"
		elseif combat.miniBoss then "Mini-boss !"
		else `Vague {combat.wave or 0}/{combat.waveCount or 0}`
	ui.barText.Text = if placing then `Préparation du Stage {state.Zone}-{state.Stage}` else `Stage {state.Zone}-{state.Stage} — {stageText}`
	ui.speed1.BackgroundColor3 = if combat.speed == 1 then COLORS.gold else COLORS.cell
	ui.speed2.BackgroundColor3 = if combat.speed == 2 then COLORS.gold else COLORS.cell
	local heroes = {}
	for _, unit in combat.units do
		if unit.Team == "Ally" then
			table.insert(heroes, unit)
		end
	end
	table.sort(heroes, function(a, b)
		return a.UnitId < b.UnitId
	end)
	for index, chip in ui.chips do
		local unit = heroes[index]
		chip.frame.Visible = unit ~= nil and not placing
		if unit then
			local alive = unit.Alive ~= false
			chip.name.Text = `{classNames[unit.TypeId] or unit.TypeId}{if alive then "" else " (KO)"}`
			chip.health.Size = UDim2.fromScale(math.clamp(unit.Health / unit.MaxHealth, 0, 1), 1)
			chip.energy.Size = UDim2.fromScale(if unit.MaxEnergy > 0 then math.clamp(unit.Energy / unit.MaxEnergy, 0, 1) else 0, 1)
			local ready = alive and unit.MaxEnergy > 0 and unit.Energy >= unit.MaxEnergy and not combat.result
			chip.ultimate.BackgroundColor3 = if ready then COLORS.gold else COLORS.disabled
			chip.ultimate.TextColor3 = if ready then COLORS.panel else COLORS.muted
			chip.unitId = unit.UnitId
		end
	end

	-- Camp ennemi : inconnu pendant la préparation, unités réellement actives pendant le combat.
	local enemyAt, heroAt = {}, {}
	for _, unit in combat.units do
		if unit.Alive ~= false then
			if unit.Team == "Enemy" and unit.Cell then
				enemyAt[unit.Cell] = unit
			elseif unit.Team == "Ally" and unit.Slot then
				heroAt[unit.Slot] = unit
			end
		end
	end
	for n, cell in ui.enemyCells do
		local unit = if placing then nil else enemyAt[n]
		cell.Text = if unit then `{if unit.MiniBoss then "★ " else ""}{unit.TypeId}\n{math.ceil(unit.Health)}/{unit.MaxHealth}`
			elseif placing then "?"
			else ""
		cell.BackgroundColor3 = if unit then COLORS.enemy else COLORS.cell
		cell.TextColor3 = if unit then COLORS.text else COLORS.muted
	end

	-- Formation du joueur.
	for n, cell in ui.heroCells do
		local classId = placed[n]
		local unit = if placing then nil else heroAt[n]
		cell.Text = if unit then `{classNames[unit.TypeId]}\n{math.ceil(unit.Health)}/{unit.MaxHealth}`
			elseif classId and placing then classNames[classId] or classId
			elseif placing then "+"
			else ""
		local filled = unit ~= nil or (placing and classId ~= nil)
		cell.BackgroundColor3 = if filled then COLORS.hero else COLORS.cell
		cell.TextColor3 = if filled then COLORS.text else COLORS.muted
		cell.Selection.Thickness = if selectedCell == n then 3 else 0
	end

	-- Collection.
	ui.collectionTitle.Text = `Tes héros — {count}/{max} sur le terrain`
	for classId, card in ui.cards do
		local slot = slotOf(classId)
		local full = count >= max and not slot and not (selectedCell and placed[selectedCell])
		card.Text = `{classNames[classId]}\n{if slot then `Case {slot}` elseif full then "Terrain complet" else "Disponible"}`
		card.BackgroundColor3 = if slot then COLORS.hero elseif full then COLORS.disabled else COLORS.cell
		card.Selection.Thickness = if selectedHero == classId then 3 else 0
		card.Active = placing
	end

	-- Indications et actions.
	local hint
	if not placing then
		hint = "Combat automatique : les héros ciblent, avancent et attaquent seuls."
	elseif selectedCell then
		hint = if placed[selectedCell]
			then `Case {selectedCell} : choisis un autre héros pour le remplacer, ou retire-le.`
			else `Case {selectedCell} : choisis le héros à y placer.`
	elseif selectedHero then
		hint = `{classNames[selectedHero]} : touche une case de ta formation.`
	else
		hint = "Touche une case puis un héros (ou l'inverse). 4 héros maximum."
	end
	ui.hint.Text = hint
	ui.remove.Visible = placing and selectedCell ~= nil and placed[selectedCell] ~= nil
	ui.fight.Visible = placing
	ui.fight.Text = if count > 0 then `Combattre ({count})` else "Place au moins un héros"
	ui.fight.BackgroundColor3 = if count > 0 then COLORS.gold else COLORS.disabled
	ui.fight.TextColor3 = if count > 0 then COLORS.panel else COLORS.muted
	ui.close.Visible = not placing
	ui.view.Text = if windowOpen then "Masquer" else "Voir le terrain"
end

local function build(): ScreenGui
	local screen = Instance.new("ScreenGui")
	screen.Name = "PreparationCombat"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Enabled = false
	ui.screen = screen

	local shade = Instance.new("Frame")
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = COLORS.shade
	shade.BackgroundTransparency = 0.45
	shade.Parent = screen
	ui.shade = shade

	local window = Instance.new("Frame")
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = UDim2.fromScale(0.92, 0.9)
	window.BackgroundColor3 = COLORS.panel
	window.Parent = screen
	corner(window, 14)
	stroke(window, COLORS.gold, 1.5)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(1120, 800)
	limit.Parent = window
	local padding = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		(padding :: any)[side] = UDim.new(0, 16)
	end
	padding.Parent = window
	ui.window = window

	-- En-tête
	local header = Instance.new("Frame")
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 58)
	header.Parent = window
	vertical(header, 2)
	ui.title = text(header, "", 22, true)
	ui.subtitle = text(header, "", 15)
	ui.subtitle.TextColor3 = COLORS.gold

	-- Corps : terrain à gauche, collection à droite
	local body = Instance.new("Frame")
	body.BackgroundTransparency = 1
	body.Position = UDim2.new(0, 0, 0, 64)
	body.Size = UDim2.new(1, 0, 1, -64 - 64)
	body.Parent = window

	local field = Instance.new("Frame")
	field.BackgroundTransparency = 1
	field.Size = UDim2.new(0.55, -8, 1, 0)
	field.Parent = body
	vertical(field, 4)
	local enemyLabel = text(field, "Camp ennemi", 14, true)
	enemyLabel.TextColor3 = COLORS.muted
	-- Ligne 1 du camp ennemi = côté héros : affichée en bas, juste au-dessus du front.
	ui.enemyCells = grid(field, "Ennemis", function(n: number): (number, number)
		return 2 - (n - 1) // 3, (n - 1) % 3
	end, nil)
	local frontLabel = text(field, "━━━  front  ━━━", 13, true)
	frontLabel.TextXAlignment = Enum.TextXAlignment.Center
	frontLabel.TextColor3 = COLORS.gold
	ui.heroCells = grid(field, "Formation", function(n: number): (number, number)
		return (n - 1) // 3, (n - 1) % 3
	end, onHeroCell)
	local rowsLabel = text(field, `Ta formation (de haut en bas : {table.concat(ROWS, ", ")})`, 13)
	rowsLabel.TextColor3 = COLORS.muted

	local collection = Instance.new("Frame")
	collection.BackgroundTransparency = 1
	collection.Position = UDim2.new(0.55, 8, 0, 0)
	collection.Size = UDim2.new(0.45, -8, 1, 0)
	collection.Parent = body
	vertical(collection, 8)
	ui.collectionTitle = text(collection, "", 16, true)
	local cardsHolder = Instance.new("Frame")
	cardsHolder.BackgroundTransparency = 1
	cardsHolder.Size = UDim2.new(1, 0, 0.62, 0)
	cardsHolder.Parent = collection
	local cardsGrid = Instance.new("UIGridLayout")
	cardsGrid.CellSize = UDim2.new(0.5, -6, 1 / 3, -6)
	cardsGrid.CellPadding = UDim2.fromOffset(6, 6)
	cardsGrid.SortOrder = Enum.SortOrder.LayoutOrder
	cardsGrid.Parent = cardsHolder
	ui.cards = {}
	for index, class in ArenaConfig.HeroClasses do
		local card = button(cardsHolder, class.Name, COLORS.cell, function()
			onHeroCard(class.Id)
		end)
		card.LayoutOrder = index
		card.TextSize = 15
		stroke(card, COLORS.gold, 0).Name = "Selection"
		ui.cards[class.Id] = card
	end
	ui.hint = text(collection, "", 14)
	ui.hint.TextColor3 = COLORS.muted
	ui.hint.Size = UDim2.new(1, 0, 0, 44)
	ui.remove = button(collection, "Retirer de la case", COLORS.enemy, function()
		local cell = selectedCell
		selectedCell = nil
		if cell then
			request("Clear", cell)
		end
	end)
	ui.remove.Size = UDim2.new(1, 0, 0, 36)

	-- Pied : message, quitter, combattre
	local footer = Instance.new("Frame")
	footer.BackgroundTransparency = 1
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.fromScale(0, 1)
	footer.Size = UDim2.new(1, 0, 0, 52)
	footer.Parent = window
	ui.message = text(footer, "", 14)
	ui.message.Size = UDim2.new(0.4, 0, 1, 0)
	ui.message.TextColor3 = COLORS.gold
	local leave = button(footer, "Quitter", COLORS.cell, function()
		request("Leave")
	end)
	leave.AnchorPoint = Vector2.new(1, 0)
	leave.Position = UDim2.new(1, -220, 0, 6)
	leave.Size = UDim2.fromOffset(120, 44)
	ui.fight = button(footer, "", COLORS.gold, function()
		if #(state.Formation or {}) > 0 then
			request("Fight")
		end
	end)
	ui.fight.AnchorPoint = Vector2.new(1, 0)
	ui.fight.Position = UDim2.new(1, 0, 0, 6)
	ui.fight.Size = UDim2.fromOffset(210, 44)
	ui.close = button(footer, "Fermer", COLORS.cell, function()
		windowOpen = false
		render()
	end)
	ui.close.AnchorPoint = Vector2.new(1, 0)
	ui.close.Position = UDim2.new(1, 0, 0, 6)
	ui.close.Size = UDim2.fromOffset(210, 44)

	-- Barre compacte pendant le combat (fenêtre fermée)
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -16)
	bar.Size = UDim2.fromOffset(720, 150)
	bar.BackgroundColor3 = COLORS.panel
	bar.Parent = screen
	corner(bar, 12)
	stroke(bar, COLORS.gold, 1.5)
	ui.bar = bar
	ui.barText = text(bar, "", 16, true)
	ui.barText.Position = UDim2.fromOffset(14, 8)
	ui.barText.Size = UDim2.new(1, -430, 0, 32)
	local function barButton(label: string, x: number, width: number, color: Color3, onClick: () -> ()): TextButton
		local b = button(bar, label, color, onClick)
		b.Position = UDim2.new(1, x, 0, 8)
		b.Size = UDim2.fromOffset(width, 32)
		return b
	end
	local function speed(value: number)
		local remote = combatAction
		if remote then
			remote:InvokeServer("SetSpeed", value)
		end
	end
	ui.speed1 = barButton("x1", -410, 44, COLORS.cell, function()
		speed(1)
	end)
	ui.speed2 = barButton("x2", -360, 44, COLORS.cell, function()
		speed(2)
	end)
	ui.view = barButton("Voir le terrain", -306, 150, COLORS.cell, function()
		windowOpen = not windowOpen
		render()
	end)
	barButton("Quitter", -148, 136, COLORS.enemy, function()
		request("Leave")
	end)
	-- Une puce par héros : nom, PV, énergie, bouton Ultime (actif quand l'énergie est pleine).
	ui.chips = {}
	for index = 1, ArenaConfig.MaxHeroes do
		local chip = Instance.new("Frame")
		chip.BackgroundColor3 = COLORS.cell
		chip.Position = UDim2.new((index - 1) / ArenaConfig.MaxHeroes, 10, 0, 48)
		chip.Size = UDim2.new(1 / ArenaConfig.MaxHeroes, -14, 0, 92)
		chip.Parent = bar
		corner(chip, 8)
		local name = text(chip, "", 14, true)
		name.Position = UDim2.fromOffset(8, 2)
		name.Size = UDim2.new(1, -16, 0, 22)
		local function gauge(y: number, color: Color3): Frame
			local back = Instance.new("Frame")
			back.BackgroundColor3 = COLORS.shade
			back.Position = UDim2.new(0, 8, 0, y)
			back.Size = UDim2.new(1, -16, 0, 8)
			back.Parent = chip
			local fill = Instance.new("Frame")
			fill.BackgroundColor3 = color
			fill.BorderSizePixel = 0
			fill.Size = UDim2.fromScale(1, 1)
			fill.Parent = back
			return fill
		end
		local entry: { [string]: any } = { frame = chip, name = name }
		entry.health = gauge(28, Color3.fromRGB(90, 200, 90))
		entry.energy = gauge(40, COLORS.gold)
		entry.ultimate = button(chip, "Ultime", COLORS.disabled, function()
			local remote = combatAction
			if remote and entry.unitId then
				local ok, reason = remote:InvokeServer("UseUltimate", entry.unitId)
				if not ok and reason and ui.message then
					ui.message.Text = reason
				end
			end
		end)
		entry.ultimate.Position = UDim2.new(0, 8, 0, 54)
		entry.ultimate.Size = UDim2.new(1, -16, 0, 30)
		ui.chips[index] = entry
	end

	-- Message de fin (victoire, défaite, arène occupée), visible après la fermeture de la préparation.
	local toast = text(screen, "", 28, true)
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, 80)
	toast.Size = UDim2.fromOffset(700, 50)
	toast.TextXAlignment = Enum.TextXAlignment.Center
	toast.TextColor3 = COLORS.gold
	toast.TextStrokeTransparency = 0.3
	toast.Visible = false
	ui.toast = toast

	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return screen
end

local function applyState(newState: { [string]: any })
	local previous = state.Phase
	state = newState
	if newState.Phase == "Placement" then
		if previous ~= "Placement" then
			windowOpen = true
			selectedCell, selectedHero = nil, nil
			-- Restes visuels de l'intro de démonstration (client) posés sur les mêmes cases.
			for _, child in Workspace:GetChildren() do
				if child.Name == "IntroCombat" then
					child:Destroy()
				end
			end
		end
	elseif newState.Phase == "Combat" and previous == "Placement" then
		-- La fenêtre se ferme pour laisser voir l'arène ; « Voir le terrain » la rouvre.
		windowOpen = false
	end
	local view = newState.Combat
	if newState.Phase == "Combat" and view and combat.id ~= view.Id then
		combat = { id = view.Id, wave = view.Wave, waveCount = view.WaveCount, speed = view.Speed, units = {} }
		for _, unit in view.Units do
			combat.units[unit.UnitId] = unit
		end
	end
	if newState.Phase == "Closed" and newState.Message and newState.Message ~= "" then
		local message = newState.Message
		ui.toast.Text = message
		ui.toast.Visible = true
		task.delay(4, function()
			if ui.toast.Text == message then
				ui.toast.Visible = false
				render()
			end
		end)
	end
	if ui.message then
		ui.message.Text = newState.Message or ""
	end
	render()
end

-- Événements du serveur : met à jour la vue locale du combat (PV, énergie, vagues, résultat).
local function onCombatEvents(combatId: number, events: { { [string]: any } })
	if combat.id ~= combatId then
		combat = { id = combatId, units = {}, speed = 1 }
	end
	for _, event in events do
		local kind = event.Type
		if kind == "UnitSpawned" then
			combat.units[event.UnitId] = {
				UnitId = event.UnitId,
				Team = event.Team,
				TypeId = event.TypeId,
				Slot = event.Slot,
				Cell = event.Cell,
				MiniBoss = event.MiniBoss,
				Health = event.Health,
				MaxHealth = event.MaxHealth,
				Energy = event.Energy,
				MaxEnergy = event.MaxEnergy,
				Alive = true,
			}
		elseif kind == "Damage" then
			local unit = combat.units[event.TargetId]
			if unit then
				unit.Health = event.Health
			end
		elseif kind == "EnergyChanged" then
			local unit = combat.units[event.UnitId]
			if unit then
				unit.Energy = event.Energy
			end
		elseif kind == "UnitDied" then
			local unit = combat.units[event.UnitId]
			if unit then
				unit.Alive = false
			end
		elseif kind == "WaveStarted" then
			combat.wave, combat.waveCount, combat.miniBoss = event.Wave, event.WaveCount, false
		elseif kind == "MiniBossStarted" then
			combat.miniBoss = true
		elseif kind == "SpeedChanged" then
			combat.speed = event.Speed
		elseif kind == "CombatEnded" then
			combat.result = event.Result
		end
	end
	render()
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
	local combatRemote = remotes:WaitForChild("CombatAction", 30)
	local combatEvents = remotes:WaitForChild("CombatEvent", 30)
	if combatRemote and combatRemote:IsA("RemoteFunction") and combatEvents and combatEvents:IsA("RemoteEvent") then
		combatAction = combatRemote
		combatEvents.OnClientEvent:Connect(onCombatEvents)
	end
end

return ArenaPrepController
