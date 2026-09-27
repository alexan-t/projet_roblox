--!strict
-- PROTOTYPE de préparation de combat, côté client (voir docs/ARENA_PROTOTYPE.md).
-- Grande fenêtre ouverte par le prompt de l'arène :
--   • en haut, le camp ennemi (3x3) : "?" pendant la préparation, révélé une fois le combat lancé ;
--   • dessous, la formation du joueur (3x3, rang Avant côté ennemis) ;
--   • à droite, la collection de héros.
-- Au clic ou au toucher : choisir une case puis un héros (ou l'inverse) ; « Retirer » vide la case.
-- Le style reste provisoire (#11). Le client n'envoie que des demandes ; ArenaService décide tout.

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
		screen.Enabled = false
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
	ui.barText.Text = if placing then `Préparation du Stage {state.Zone}-{state.Stage}` else `Combat en cours — ennemis révélés`

	-- Camp ennemi : inconnu pendant la préparation.
	local revealed = {}
	for _, entry in state.EnemyLayout or {} do
		revealed[entry.Cell] = entry
	end
	for n, cell in ui.enemyCells do
		local entry = revealed[n]
		cell.Text = if entry then (if entry.MiniBoss then `★ {entry.EnemyId}` else entry.EnemyId) elseif placing then "?" else ""
		cell.BackgroundColor3 = if entry then COLORS.enemy else COLORS.cell
		cell.TextColor3 = if entry then COLORS.text else COLORS.muted
	end

	-- Formation du joueur.
	for n, cell in ui.heroCells do
		local classId = placed[n]
		cell.Text = if classId then classNames[classId] or classId elseif placing then "+" else ""
		cell.BackgroundColor3 = if classId then COLORS.hero else COLORS.cell
		cell.TextColor3 = if classId then COLORS.text else COLORS.muted
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
		hint = "Les ennemis ont pris position au hasard. Le combat réel arrive avec #8."
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
	bar.Size = UDim2.fromOffset(520, 56)
	bar.BackgroundColor3 = COLORS.panel
	bar.Parent = screen
	corner(bar, 12)
	stroke(bar, COLORS.gold, 1.5)
	ui.bar = bar
	ui.barText = text(bar, "", 15, true)
	ui.barText.Position = UDim2.fromOffset(14, 8)
	ui.barText.Size = UDim2.new(1, -270, 1, -16)
	ui.view = button(bar, "Voir le terrain", COLORS.cell, function()
		windowOpen = not windowOpen
		render()
	end)
	ui.view.Position = UDim2.new(1, -256, 0, 8)
	ui.view.Size = UDim2.fromOffset(120, 40)
	local barLeave = button(bar, "Quitter", COLORS.enemy, function()
		request("Leave")
	end)
	barLeave.Position = UDim2.new(1, -128, 0, 8)
	barLeave.Size = UDim2.fromOffset(116, 40)

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
	if ui.message then
		ui.message.Text = newState.Message or ""
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
end

return ArenaPrepController
