--!strict
-- Hotbar (10 raccourcis, touches 1..9 puis 0) et sacoche (onglets Héros, Équipement, Ressources ;
-- seuls les héros ont déjà des données), côté client. L'ordre de la hotbar vient du serveur et
-- n'est jamais retrié ici.
-- Choisir un héros (raccourci, ou sacoche > Placer) le met « en main » : le joueur le pose
-- ensuite lui-même sur une case de l'arène (ArenaPlacementController). Pendant un combat, la
-- hotbar reste visible mais ne modifie plus la formation.
-- Style : design system (UITheme via UIKit) ; légère, transparente, la map reste visible.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local HeroConfig = require(ReplicatedStorage.Shared.Config.HeroConfig)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local ArenaStore = require(script.Parent.Parent.Arena.ArenaStore)
local PlacementState = require(script.Parent.Parent.Arena.PlacementState)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local Icons = require(script.Parent.Parent.UI.Icons)

local Drag = require(script.Parent.Parent.UI.HeroDrag)

-- Portrait 3D du vrai modèle du héros (UIKit.portrait, design system § 7), ou nil s'il n'est pas répliqué.
local function heroPortrait(parent: Instance, heroId: string): ViewportFrame?
	local model = Icons.heroModel(heroId)
	return if model then UIKit.portrait(parent, model) else nil
end
local C = UITheme.Colors
local T = UITheme.Transparency
local S = UITheme.Spacing

local HeroBarController = {}

local SLOT = 64 -- taille d'un raccourci (px), au-dessus de la zone tactile minimale
local KEYS = {
	Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five,
	Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine, Enum.KeyCode.Zero,
}

-- portrait : vrai modèle du héros (UIKit.portrait) ; à défaut, monogramme provisoire.
type SlotUI = { frame: TextButton, stroke: UIStroke, icon: TextLabel, placed: Frame, offset: number,
	portrait: ViewportFrame?, portraitHero: string? }
type CardUI = { frame: TextButton, stroke: UIStroke, placed: Frame, shortcut: TextLabel, portrait: boolean }

-- Onglets de la sacoche. Équipement et Ressources n'ont pas encore de données.
local TABS = {
	{ Id = "Heroes", Label = "Héros" },
	{ Id = "Equipment", Label = "Équipement", Soon = "Les équipements arriveront dans une prochaine version." },
	{ Id = "Resources", Label = "Ressources", Soon = "Les ressources arriveront dans une prochaine version." },
}
local currentTab = "Heroes"

local slots: { SlotUI } = {}
local cards: { [string]: CardUI } = {}
local ui: { [string]: any } = {}
local chosen: string? = nil -- héros choisi dans la sacoche (avant Placer)

local function placedSet(): { [string]: boolean }
	local set = {}
	for _, id in ArenaStore.formation() do
		set[id] = true
	end
	return set
end

local function heldId(): string?
	local held = ArenaStore.placement.held
	return if held then held.instanceId else nil
end

------------------------------------------------------------------ hotbar

local function selectSlot(index: number)
	if ArenaStore.inCombat() or ArenaStore.busy then
		return
	end
	PlacementState.selectHotbar(ArenaStore.placement, index, ArenaStore.hotbar, ArenaStore.formation())
	local slot = slots[index]
	if slot and heldId() then
		UIKit.pop(slot.frame)
	end
	ArenaStore.notify()
end

local function buildHotbar(screen: ScreenGui)
	local count = HeroConfig.HotbarSize
	local width = count * SLOT + (count - 1) * S.S + 2 * S.M
	local bar = UIKit.panel(screen, T.HUD, UITheme.Radius.Large, UITheme.Stroke.Regular)
	bar.Name = "Hotbar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -S.ScreenMargin)
	bar.Size = UDim2.fromOffset(width, SLOT + 2 * S.M)
	ui.bar = bar
	for index = 1, count do
		local frame = Instance.new("TextButton")
		frame.Name = `Raccourci{index}`
		frame.AutoButtonColor = false
		frame.Text = ""
		frame.BackgroundColor3 = C.Cream
		frame.BorderSizePixel = 0
		local x = S.M + (index - 1) * (SLOT + S.S)
		frame.Position = UDim2.fromOffset(x, S.M)
		frame.Size = UDim2.fromOffset(SLOT, SLOT)
		frame.Parent = bar
		UIKit.corner(frame, UITheme.Radius.Medium)
		local stroke = UIKit.stroke(frame, UITheme.Stroke.Regular)
		local icon = UIKit.text(frame, "", UITheme.Typography.Size.Icon)
		local key = UIKit.text(frame, tostring(index % 10), UITheme.Typography.Size.Caption)
		key.Position = UDim2.fromOffset(5, 2)
		key.Size = UDim2.fromOffset(14, 16)
		key.TextXAlignment = Enum.TextXAlignment.Left
		-- Pastille dorée : héros posé sur l'arène.
		local placed = Instance.new("Frame")
		placed.AnchorPoint = Vector2.new(1, 0)
		placed.Position = UDim2.new(1, -4, 0, 4)
		placed.Size = UDim2.fromOffset(12, 12)
		placed.BackgroundColor3 = C.Selected
		placed.Parent = frame
		UIKit.corner(placed, UITheme.Radius.Pill)
		UIKit.stroke(placed, UITheme.Stroke.Thin)
		frame.Activated:Connect(function()
			if not Drag.suppressed() then selectSlot(index) end
		end)
		Drag.bind(frame, function() return { slot = index, id = ArenaStore.hotbar[index] } end)
		slots[index] = { frame = frame, stroke = stroke, icon = icon, placed = placed, offset = x }
	end
end

local function renderHotbar()
	local held = heldId()
	local placed = placedSet()
	local locked = ArenaStore.inCombat()
	for index, slot in slots do
		local id = ArenaStore.hotbar[index]
		local hero, info = ArenaStore.heroInfo(if id ~= "" then id else nil)
		local selected = id ~= "" and id == held
		local heroId = if hero and info then hero.HeroId else nil
		if slot.portraitHero ~= heroId or (heroId and not slot.portrait) then
			if slot.portrait then slot.portrait:Destroy() end
			slot.portrait = if heroId then heroPortrait(slot.frame, heroId) else nil
			slot.portraitHero = heroId
			local portrait = slot.portrait
			if portrait then
				portrait.ZIndex = 0 -- sous le numéro de touche et la pastille « posé »
				portrait.Position = UDim2.fromOffset(3, 3)
				portrait.Size = UDim2.new(1, -6, 1, -6)
			end
		end
		local portrait = slot.portrait
		slot.icon.Text = if info and not portrait then info.PlaceholderIcon else ""
		if portrait then portrait.ImageTransparency = if locked then T.Disabled else 0 end
		slot.frame.BackgroundTransparency = if info then T.Slot else T.Empty
		slot.frame.BackgroundColor3 = if info then C.Cream else C.WoodDeep
		slot.icon.TextTransparency = if locked then T.Disabled else 0
		slot.stroke.Color = if selected then C.Selected else UITheme.Stroke.Color
		slot.stroke.Thickness = if selected then UITheme.Stroke.Thick else UITheme.Stroke.Regular
		slot.frame.Position = UDim2.fromOffset(slot.offset, if selected then S.M - 8 else S.M)
		slot.placed.Visible = info ~= nil and placed[id] == true
	end
end

------------------------------------------------------------------ sacoche

local function setBag(open: boolean)
	ui.bag.Visible = open
	if open then
		UIKit.pop(ui.bag)
	end
end

local function buildBag(screen: ScreenGui)
	-- Bouton sacoche, à gauche de la hotbar (libellé texte en attendant l'icône dessinée).
	local toggle = UIKit.button(screen, "Sac", "Secondary", UDim2.fromOffset(SLOT, SLOT + UITheme.Shadow.ButtonLip), function()
		setBag(not ui.bag.Visible)
	end)
	toggle.holder.Name = "BoutonSacoche"
	toggle.holder.AnchorPoint = Vector2.new(1, 1)
	toggle.holder.Position = UDim2.new(0.5, -(ui.bar.Size.X.Offset / 2) - S.M, 1, -S.ScreenMargin - S.M)
	toggle.label.TextSize = UITheme.Typography.Size.Label

	-- Panneau à gauche, transparent : la map reste visible.
	local bag = UIKit.panel(screen, T.Panel)
	bag.Name = "Sacoche"
	bag.AnchorPoint = Vector2.new(0, 0.5)
	bag.Position = UDim2.new(0, S.ScreenMargin, 0.5, -40)
	bag.Size = UDim2.fromOffset(372, 620)
	bag.Visible = false
	ui.bag = bag
	local scale = Instance.new("UIScale")
	scale.Parent = bag
	local function resize()
		scale.Scale = math.min(1, math.max(0.5, (screen.AbsoluteSize.Y - 130) / 620))
	end
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	task.defer(resize)

	local title = Instance.new("Frame")
	title.BackgroundColor3 = C.Wood
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0)
	title.Size = UDim2.fromOffset(190, 44)
	title.Parent = bag
	UIKit.corner(title, UITheme.Radius.Medium)
	UIKit.stroke(title, UITheme.Stroke.Thick)
	UIKit.text(title, "Sacoche", UITheme.Typography.Size.Title)

	local close = UIKit.button(bag, "X", "Danger", UDim2.fromOffset(44, 44 + UITheme.Shadow.ButtonLip), function()
		setBag(false)
	end)
	close.holder.AnchorPoint = Vector2.new(0.5, 0.5)
	close.holder.Position = UDim2.new(1, -6, 0, 0)

	-- Onglets. Seul Héros a des données ; Équipement et Ressources sont des emplacements prévus.
	ui.tabs = {}
	local tabWidth = (bag.Size.X.Offset - 2 * S.L - 2 * S.S) / #TABS
	for index, tabInfo in TABS do
		local tab = UIKit.button(bag, tabInfo.Label, "Tab", UDim2.fromOffset(tabWidth, 40 + UITheme.Shadow.ButtonLip), function()
			currentTab = tabInfo.Id
			ArenaStore.notify()
		end)
		tab.holder.Name = `Onglet{tabInfo.Id}`
		tab.holder.Position = UDim2.fromOffset(S.L + (index - 1) * (tabWidth + S.S), 36)
		tab.label.TextSize = UITheme.Typography.Size.Label
		ui.tabs[tabInfo.Id] = tab
	end

	-- Contenu provisoire des onglets sans données (texte long : sur un sous-panneau renforcé).
	local soon = Instance.new("Frame")
	soon.Name = "BientotDisponible"
	soon.BackgroundColor3 = C.WoodDeep
	soon.BackgroundTransparency = T.PanelStrong
	soon.Position = UDim2.fromOffset(S.L, 100)
	soon.Size = UDim2.new(1, -2 * S.L, 0, 120)
	soon.Visible = false
	soon.Parent = bag
	UIKit.corner(soon, UITheme.Radius.Medium)
	UIKit.stroke(soon, UITheme.Stroke.Regular)
	local soonTitle = UIKit.text(soon, "Bientôt disponible", UITheme.Typography.Size.Heading)
	soonTitle.Position = UDim2.fromOffset(0, S.M)
	soonTitle.Size = UDim2.new(1, 0, 0, 32)
	local soonText = Instance.new("TextLabel")
	soonText.BackgroundTransparency = 1
	soonText.FontFace = UITheme.Typography.Body
	soonText.TextSize = UITheme.Typography.Size.Body
	soonText.TextColor3 = C.TextMuted
	soonText.TextWrapped = true
	soonText.Position = UDim2.fromOffset(S.L, 52)
	soonText.Size = UDim2.new(1, -2 * S.L, 0, 56)
	soonText.Parent = soon
	ui.soon = soon
	ui.soonText = soonText

	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(S.L, 92)
	list.Size = UDim2.new(1, -2 * S.L, 1, -92 - 232)
	list.ScrollBarThickness = UITheme.Stroke.ScrollBar
	list.ScrollBarImageColor3 = C.Cream
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = bag
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(100, 132) -- portrait, nom sur deux lignes, raccourci
	grid.CellPadding = UDim2.fromOffset(S.M, S.L)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = list
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, S.M) -- place pour les badges à cheval sur le bord
	padding.PaddingLeft = UDim.new(0, 4)
	padding.Parent = list
	ui.list = list

	local place = UIKit.button(bag, "Placer", "Primary", UDim2.new(1, -2 * S.L, 0, 56 + UITheme.Shadow.ButtonLip), function()
		local id = chosen
		if id and not ArenaStore.inCombat() then
			PlacementState.selectCollection(ArenaStore.placement, id, ArenaStore.formation())
			setBag(false) -- le joueur choisit maintenant sa case dans le monde
			ArenaStore.notify()
		end
	end)
	place.holder.AnchorPoint = Vector2.new(0, 1)
	place.holder.Position = UDim2.new(0, S.L, 1, -168)
	ui.place = place
	local chooser = UIKit.panel(bag, T.PanelStrong)
	chooser.Name = "ChoixRaccourci"
	chooser.Position = UDim2.new(0, S.L, 1, -76)
	chooser.Size = UDim2.new(1, -2 * S.L, 0, 60)
	chooser.Visible = false
	ui.chooser = chooser
	ui.chooseMode = "Assign"
	for index = 1, 10 do
		local pick = UIKit.button(chooser, tostring(index % 10), "Tab", UDim2.fromOffset(30, 44), function()
			if not chosen then return end
			local origin = table.find(ArenaStore.hotbar, chosen)
			if ui.chooseMode == "Swap" and origin then ArenaStore.hotbarAction("Swap", origin, index)
			else ArenaStore.hotbarAction("Assign", chosen, index) end
			chooser.Visible = false
		end)
		pick.holder.Name = `Choisir{index}`
		pick.holder.Position = UDim2.fromOffset(5 + (index - 1) * 32, 8)
		pick.label.TextSize = 16
	end
	local assign = UIKit.button(bag, "Placer dans le raccourci", "Secondary", UDim2.new(1, -2 * S.L, 0, 44), function()
		ui.chooseMode = "Assign"
		chooser.Visible = not chooser.Visible
	end)
	assign.holder.Name, assign.holder.Position = "AssignerRaccourci", UDim2.new(0, S.L, 1, -160)
	assign.label.TextSize = 18
	ui.assign = assign
	local clear = UIKit.button(bag, "Retirer du raccourci", "Secondary", UDim2.fromOffset(218, 44), function()
		local slot = chosen and table.find(ArenaStore.hotbar, chosen)
		if slot then ArenaStore.hotbarAction("Clear", slot) end
	end)
	clear.holder.Name, clear.holder.Position = "RetirerRaccourci", UDim2.new(0, S.L, 1, -112)
	clear.label.TextSize = 16
	ui.clear = clear
	local swap = UIKit.button(bag, "Échanger", "Secondary", UDim2.fromOffset(108, 44), function()
		ui.chooseMode = "Swap"
		chooser.Visible = not chooser.Visible
	end)
	swap.holder.Position = UDim2.new(0, S.L + 226, 1, -112)
	swap.label.TextSize = 16
	ui.swap = swap
end

local function card(hero: ArenaStore.HeroView): CardUI
	local existing = cards[hero.Id]
	if existing then
		return existing
	end
	local info = HeroConfig.Heroes[hero.HeroId]
	local frame = Instance.new("TextButton")
	frame.Name = hero.Id
	frame.AutoButtonColor = false
	frame.Text = ""
	frame.BackgroundColor3 = C.Cream
	frame.BackgroundTransparency = T.PanelStrong
	frame.LayoutOrder = if info then info.Order else 99
	frame.Parent = ui.list
	UIKit.corner(frame, UITheme.Radius.Medium)
	local stroke = UIKit.stroke(frame, UITheme.Stroke.Regular)
	local art = Instance.new("Frame")
	art.BackgroundColor3 = C.Sand
	art.BackgroundTransparency = T.Art
	art.Position = UDim2.fromOffset(8, 8)
	art.Size = UDim2.new(1, -16, 0, 66)
	art.Parent = frame
	UIKit.corner(art, UITheme.Radius.Small)
	local portrait = heroPortrait(art, hero.HeroId)
	if not portrait then
		UIKit.text(art, if info then info.PlaceholderIcon else "?", UITheme.Typography.Size.IconLarge)
	end
	local name = UIKit.text(frame, if info then info.Name else hero.HeroId, UITheme.Typography.Size.Label)
	-- Vrais noms de héros (« Tireuse des Faubourgs ») : deux lignes dans la carte, réduits si besoin.
	name.Position = UDim2.fromOffset(4, 76)
	name.Size = UDim2.new(1, -8, 0, 34)
	name.TextWrapped = true
	name.TextScaled = true
	local fit = Instance.new("UITextSizeConstraint")
	fit.MaxTextSize = UITheme.Typography.Size.Label
	fit.Parent = name
	local placed = UIKit.badge(frame, "Posé", C.Gold)
	placed.AnchorPoint = Vector2.new(0.5, 0.5)
	placed.Position = UDim2.fromScale(0.5, 0)
	frame.Activated:Connect(function()
		if Drag.suppressed() then return end
		chosen = hero.Id
		ArenaStore.notify()
	end)
	local shortcut = UIKit.text(frame, "", 13)
	shortcut.Position = UDim2.new(0, 0, 1, -18)
	shortcut.Size = UDim2.new(1, 0, 0, 18)
	Drag.bind(frame, function() return { id = hero.Id } end)
	local entry = { frame = frame, stroke = stroke, placed = placed, shortcut = shortcut, portrait = portrait ~= nil }
	cards[hero.Id] = entry
	return entry
end

local function renderBag()
	if not ui.list then
		return
	end
	local placed = placedSet()
	for id, entry in cards do
		if not ArenaStore.heroes[id] then
			entry.frame:Destroy()
			cards[id] = nil
		end
	end
	if chosen and not ArenaStore.heroes[chosen] then
		chosen = nil
	end
	for id, hero in ArenaStore.heroes do
		local entry = card(hero)
		local selected = id == chosen
		entry.stroke.Color = if selected then C.Selected else UITheme.Stroke.Color
		entry.stroke.Thickness = if selected then UITheme.Stroke.Thick else UITheme.Stroke.Regular
		entry.placed.Visible = placed[id] == true
		local slot = table.find(ArenaStore.hotbar, id)
		entry.shortcut.Text = if slot then `Raccourci {slot % 10}` else "Collection"
	end
	ui.place.setEnabled(chosen ~= nil and not ArenaStore.inCombat())
	local heroes = currentTab == "Heroes"
	ui.assign.setEnabled(chosen ~= nil and not ArenaStore.busy)
	local assigned = chosen ~= nil and table.find(ArenaStore.hotbar, chosen) ~= nil
	ui.clear.setEnabled(assigned and not ArenaStore.busy)
	ui.swap.setEnabled(assigned and not ArenaStore.busy)
	ui.assign.holder.Visible, ui.clear.holder.Visible, ui.swap.holder.Visible = heroes, heroes, heroes
	if not heroes or not chosen then ui.chooser.Visible = false end
	for id, tab in ui.tabs do
		tab.setSelected(id == currentTab)
	end
	ui.list.Visible = heroes
	ui.place.holder.Visible = heroes
	ui.soon.Visible = not heroes
	for _, tabInfo in TABS do
		if tabInfo.Id == currentTab and tabInfo.Soon then
			ui.soonText.Text = tabInfo.Soon
		end
	end
end

------------------------------------------------------------------ démarrage

local function render()
	renderHotbar()
	renderBag()
end

function HeroBarController:Start()
	-- Les touches 1..0 servent à la hotbar des héros, pas au sac d'outils Roblox.
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	local screen = Instance.new("ScreenGui")
	screen.Name = "HotbarHeros"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	buildHotbar(screen)
	buildBag(screen)
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local frames = {}
	for index, slot in slots do frames[index] = slot.frame end
	Drag.start(screen, frames)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		local index = table.find(KEYS, input.KeyCode)
		if index then
			selectSlot(index)
		end
	end)
	ArenaStore.changed.Event:Connect(render)
	render()
	ArenaStore.start()
	-- Portraits : les modèles des héros arrivent par réplication (ReplicatedStorage.Assets.Heros,
	-- copiés par HeroService) ; les cartes créées avec un monogramme sont refaites à leur arrivée.
	task.spawn(function()
		local assets = ReplicatedStorage:WaitForChild("Assets", 30)
		local heroes = assets and assets:WaitForChild("Heros", 30)
		if not heroes then
			return
		end
		local function refresh()
			for id, entry in cards do
				if not entry.portrait then
					entry.frame:Destroy()
					cards[id] = nil
				end
			end
			render()
		end
		heroes.ChildAdded:Connect(refresh)
		refresh()
	end)
end

return HeroBarController
