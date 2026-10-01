--!strict
-- Hotbar (10 raccourcis, touches 1..9 puis 0) et sacoche (collection de héros), côté client.
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

local C = UITheme.Colors
local T = UITheme.Transparency
local S = UITheme.Spacing

local HeroBarController = {}

local SLOT = 64 -- taille d'un raccourci (px), au-dessus de la zone tactile minimale
local KEYS = {
	Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five,
	Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine, Enum.KeyCode.Zero,
}

type SlotUI = { frame: TextButton, stroke: UIStroke, icon: TextLabel, placed: Frame, offset: number }
type CardUI = { frame: TextButton, stroke: UIStroke, placed: Frame }

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
	if ArenaStore.inCombat() then
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
		local icon = UIKit.text(frame, "", 30)
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
			selectSlot(index)
		end)
		slots[index] = { frame = frame, stroke = stroke, icon = icon, placed = placed, offset = x }
	end
end

local function renderHotbar()
	local held = heldId()
	local placed = placedSet()
	local locked = ArenaStore.inCombat()
	for index, slot in slots do
		local id = ArenaStore.hotbar[index]
		local _, info = ArenaStore.heroInfo(if id ~= "" then id else nil)
		local selected = id ~= "" and id == held
		slot.icon.Text = if info then info.Icon else ""
		slot.frame.BackgroundTransparency = if info then T.PanelStrong + 0.2 else 0.85
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
	-- Bouton sacoche, à gauche de la hotbar.
	local toggle = UIKit.button(screen, "🎒", "Secondary", UDim2.fromOffset(SLOT, SLOT + UITheme.Shadow.ButtonLip), function()
		setBag(not ui.bag.Visible)
	end)
	toggle.holder.Name = "BoutonSacoche"
	toggle.holder.AnchorPoint = Vector2.new(1, 1)
	toggle.holder.Position = UDim2.new(0.5, -(ui.bar.Size.X.Offset / 2) - S.M, 1, -S.ScreenMargin - S.M)
	toggle.label.TextSize = 30

	-- Panneau à gauche, transparent : la map reste visible.
	local bag = UIKit.panel(screen, T.Panel)
	bag.Name = "Sacoche"
	bag.AnchorPoint = Vector2.new(0, 0.5)
	bag.Position = UDim2.new(0, S.ScreenMargin, 0.5, -40)
	bag.Size = UDim2.fromOffset(372, 470)
	bag.Visible = false
	ui.bag = bag

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

	local tab = UIKit.button(bag, "Héros", "Tab", UDim2.fromOffset(110, 40 + UITheme.Shadow.ButtonLip), function() end)
	tab.holder.Position = UDim2.fromOffset(S.L, 36)
	tab.setSelected(true)
	tab.label.TextSize = UITheme.Typography.Size.Label

	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(S.L, 92)
	list.Size = UDim2.new(1, -2 * S.L, 1, -92 - 84)
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = C.Cream
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = bag
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(100, 118)
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
	place.holder.Position = UDim2.new(0, S.L, 1, -S.L)
	ui.place = place
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
	art.BackgroundTransparency = 0.35
	art.Position = UDim2.fromOffset(8, 8)
	art.Size = UDim2.new(1, -16, 0, 66)
	art.Parent = frame
	UIKit.corner(art, UITheme.Radius.Small)
	UIKit.text(art, if info then info.Icon else "?", 40)
	local name = UIKit.text(frame, if info then info.Name else hero.HeroId, UITheme.Typography.Size.Label)
	name.Position = UDim2.fromOffset(0, 78)
	name.Size = UDim2.new(1, 0, 0, 30)
	local placed = UIKit.badge(frame, "Posé", C.Gold)
	placed.AnchorPoint = Vector2.new(0.5, 0.5)
	placed.Position = UDim2.fromScale(0.5, 0)
	frame.Activated:Connect(function()
		chosen = hero.Id
		ArenaStore.notify()
	end)
	local entry = { frame = frame, stroke = stroke, placed = placed }
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
	end
	ui.place.setEnabled(chosen ~= nil and not ArenaStore.inCombat())
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
end

return HeroBarController
