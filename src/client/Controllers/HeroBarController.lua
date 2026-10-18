--!strict
-- Hotbar (10 raccourcis, touches 1..9 puis 0) et Sacoche (onglets Héros, Équipement, Ressources ; seuls les
-- héros ont déjà des données côté serveur), côté client. L'ordre de la hotbar vient du serveur et n'est
-- jamais retrié ici.
-- Choisir un héros (raccourci, ou Sacoche > Placer) le met « en main » : le joueur le pose ensuite lui-même
-- sur une case de l'arène (ArenaPlacementController, sa pastille « en main » avec Annuler). Pendant un combat,
-- la hotbar reste visible mais ne modifie plus la formation.
-- Sacoche (maquette figée « Sacoche.dc.html », vue Views.SacocheView) : fenêtre CENTRÉE dans la zone libre
-- entre le HUD du haut (monnaies) et la hotbar ; le menu principal se masque tant qu'elle est ouverte
-- (MenuController). Elle s'ouvre seulement si aucun écran modal n'est ouvert (ScreenState) et se ferme dès
-- qu'un autre en ouvre un (Expédition, invocation, récompenses, Quêtes...) : jamais deux fenêtres à la fois.
--   Héros : carte → fiche ; UNE action principale : Placer (héros libre : en main, la Sacoche se ferme, le
--   monde reprend la priorité) ou Retirer de l'arène (héros posé : requête « Remove » d'ArenaService) ;
--   action raccourci secondaire : Ajouter (les raccourcis pulsent, « Choisis une case » : alternative au
--   drag, mobile compris) ou Retirer. Le drag carte → raccourci (HeroDrag) est conservé.
--   « Nouveau » : exemplaire apparu dans HeroesChanged pendant la session (vraies données), jusqu'à ce qu'il
--   soit vu ; il allume le « ! » du bouton Sac (HeroBarController.newChanged).
-- Tutoriel : le raccourci du héros à prendre (ArenaStore.guide.hotbar) s'entoure d'une lueur dorée qui respire,
-- cible « Hotbar.Guide » ; la Sacoche est la cible des guidages « Bag.* » (Bag.FirstHero, Bag.Place) et signale
-- son ouverture (drapeau « Bag »). API : HeroBarController.SetBag(open), HeroBarController.IsBagOpen(),
-- HeroBarController.bagChanged, HeroBarController.HasNew(), HeroBarController.newChanged.
-- Niveaux (#68) : « Nv. n » sur chaque raccourci et chaque carte (par exemplaire) ; XP, PV et ATK de la
-- fiche reçus du serveur (HeroesChanged), jamais calculés ici.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local HeroConfig = require(ReplicatedStorage.Shared.Config.HeroConfig)
local SacocheModel = require(ReplicatedStorage.Shared.Sacoche.SacocheModel)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local ArenaStore = require(script.Parent.Parent.Arena.ArenaStore)
local ScreenState = require(script.Parent.Parent.UI.ScreenState)
local PlacementState = require(script.Parent.Parent.Arena.PlacementState)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local Icons = require(script.Parent.Parent.UI.Icons)
local GuideTargets = require(script.Parent.Parent.UI.GuideTargets)
local SacocheView = require(script.Parent.Parent.UI.Views.SacocheView)

local Drag = require(script.Parent.Parent.UI.HeroDrag)

-- Portrait 3D du vrai modèle du héros (UIKit.portrait, design system § 7), ou nil s'il n'est pas répliqué.
local function heroPortrait(parent: Instance, heroId: string): ViewportFrame?
	local model = Icons.heroModel(heroId)
	return if model then UIKit.portrait(parent, model) else nil
end
local C = UITheme.Colors
local T = UITheme.Transparency
local S = UITheme.Spacing
local PACK = UITheme.Pack.Sacoche

local HeroBarController = {}
-- Sacoche ouverte / fermée (true / false) : le menu met son bouton Sac en « sélectionné » et se masque.
HeroBarController.bagChanged = Instance.new("BindableEvent")
-- Il y a (ou non) un héros nouveau pas encore vu : « ! » du bouton Sac.
HeroBarController.newChanged = Instance.new("BindableEvent")

local SLOT = 64 -- taille d'un raccourci (px), au-dessus de la zone tactile minimale
local KEYS = {
	Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five,
	Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine, Enum.KeyCode.Zero,
}

-- portrait : vrai modèle du héros (UIKit.portrait) ; à défaut, monogramme provisoire.
type SlotUI = { frame: TextButton, stroke: UIStroke, icon: TextLabel, placed: Frame, offset: number, level: TextLabel,
	portrait: ViewportFrame?, portraitHero: string?, guide: { frame: Frame, tween: Tween }?, pick: { frame: Frame, tweens: { Tween } }? }

local slots: { SlotUI } = {}
local ui: { [string]: any } = {}

-- état de la Sacoche (présentation ; aucune donnée de jeu)
local bag = {
	open = false,
	tab = "Heroes",
	chosen = nil :: string?, -- héros choisi dans la Sacoche
	filter = "all",
	query = "",
	search = false,
	picking = false, -- « Ajouter au raccourci » : choisir une case de la hotbar
	equip = 1, -- héros montré par la poupée d'équipement
}
-- « Nouveau » : exemplaires apparus après le premier chargement, pas encore vus.
local known: { [string]: boolean }? = nil
local fresh: { [string]: boolean } = {}

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

function HeroBarController.HasNew(): boolean
	return next(fresh) ~= nil
end

local render: () -> ()

------------------------------------------------------------------ hotbar

local function stopPicking()
	if bag.picking then
		bag.picking = false
		ArenaStore.notify()
	end
end

-- Choix d'une case pour le héros de la fiche : Assign (hors hotbar) ou Swap (déjà dans la hotbar).
local function assignTo(index: number)
	local id = bag.chosen
	bag.picking = false
	if not id then
		ArenaStore.notify()
		return
	end
	local origin = table.find(ArenaStore.hotbar, id)
	if origin then
		if origin ~= index then
			ArenaStore.hotbarAction("Swap", origin, index)
		end
	else
		ArenaStore.hotbarAction("Assign", id, index)
	end
	if slots[index] then
		UIKit.pop(slots[index].frame)
	end
	ArenaStore.notify()
end

local function selectSlot(index: number)
	if bag.picking then
		assignTo(index)
		return
	end
	if bag.open then
		-- Sacoche ouverte : le raccourci montre son héros dans la fiche (pas de prise en main)
		local id = ArenaStore.hotbar[index]
		if id and id ~= "" then
			bag.tab, bag.chosen = "Heroes", id
			fresh[id] = nil
			ArenaStore.notify()
		end
		return
	end
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
	GuideTargets.register("Hotbar.Bar", bar) -- le menu principal et la Sacoche s'arrêtent au-dessus
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
		-- niveau de l'exemplaire, discret en bas à droite (au-dessus du portrait)
		local level = UIKit.text(frame, "", UITheme.Typography.Size.Caption)
		level.Name = "Niveau"
		level.AnchorPoint = Vector2.new(1, 1)
		level.Position = UDim2.new(1, -4, 1, -2)
		level.Size = UDim2.fromOffset(40, 16)
		level.TextXAlignment = Enum.TextXAlignment.Right
		level.ZIndex = 3
		frame.Activated:Connect(function()
			if not Drag.suppressed() then selectSlot(index) end
		end)
		Drag.bind(frame, function() return { slot = index, id = ArenaStore.hotbar[index] } end)
		slots[index] = { frame = frame, stroke = stroke, icon = icon, placed = placed, offset = x, level = level }
	end

	-- « Choisis une case ↓ Annuler » : au-dessus de la hotbar pendant le choix d'un raccourci
	local pick = UIKit.panel(screen, T.HUD, UITheme.Radius.Pill, UITheme.Stroke.Regular)
	pick.Name = "ChoixCase"
	pick.AnchorPoint = Vector2.new(0.5, 1)
	pick.Position = UDim2.new(0.5, 0, 1, -(S.ScreenMargin + SLOT + 2 * S.M + S.M))
	pick.AutomaticSize = Enum.AutomaticSize.X
	pick.Size = UDim2.fromOffset(0, 52)
	pick.Visible = false
	pick.ZIndex = 8
	local pickStroke = pick:FindFirstChildOfClass("UIStroke")
	if pickStroke then pickStroke.Color = C.Selected end
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 16), UDim.new(0, 6)
	pad.Parent = pick
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Padding = UDim.new(0, 10)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = pick
	local label = UIKit.text(pick, "Choisis une case", PACK.Wide.PickSize)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromOffset(0, 24)
	label.LayoutOrder = 1
	local down = UIKit.text(pick, "↓", 22)
	down.AutomaticSize = Enum.AutomaticSize.X
	down.Size = UDim2.fromOffset(0, 24)
	down.LayoutOrder = 2
	local cancel = UIKit.button(pick, "Annuler", "Secondary", UDim2.fromOffset(110, 40), stopPicking)
	cancel.holder.LayoutOrder = 3
	cancel.label.TextSize = 16
	ui.pick = pick
end

-- Lueur dorée qui respire autour d'un raccourci (guidage du tutoriel) ; nil = aucune.
local function setGuided(slot: SlotUI, on: boolean)
	local current = slot.guide
	if (current ~= nil) == on then
		return
	end
	if current then
		current.tween:Cancel()
		current.frame:Destroy()
		slot.guide = nil
		GuideTargets.unregister("Hotbar.Guide", slot.frame)
		return
	end
	local glow = Instance.new("Frame")
	glow.Name = "Guide"
	glow.BackgroundColor3 = UITheme.World.Guide.Color
	glow.BackgroundTransparency = 1
	glow.Position = UDim2.fromOffset(-S.XS, -S.XS)
	glow.Size = UDim2.new(1, 2 * S.XS, 1, 2 * S.XS)
	glow.ZIndex = 5
	glow.Active = false
	glow.Parent = slot.frame
	UIKit.corner(glow, UITheme.Radius.Medium)
	local stroke = UIKit.stroke(glow, UITheme.Stroke.Thick)
	stroke.Color = UITheme.World.Guide.Color
	stroke.Transparency = UITheme.World.Guide.OutlineTo
	local tween = TweenService:Create(glow, UITheme.Animation.Pulse, { BackgroundTransparency = UITheme.World.Guide.FillTo })
	tween:Play()
	local strokeTween = TweenService:Create(stroke, UITheme.Animation.Pulse, { Transparency = 0 })
	strokeTween:Play()
	slot.guide = { frame = glow, tween = tween }
	glow.Destroying:Connect(function()
		strokeTween:Cancel()
	end)
	UIKit.pop(slot.frame)
	GuideTargets.register("Hotbar.Guide", slot.frame)
end

-- Pulsation dorée d'un raccourci pendant le choix d'une case (maquette : slotPulse).
local function setPicking(slot: SlotUI, on: boolean)
	local current = slot.pick
	if (current ~= nil) == on then
		return
	end
	if current then
		for _, t in current.tweens do t:Cancel() end
		current.frame:Destroy()
		slot.pick = nil
		return
	end
	local glow = Instance.new("Frame")
	glow.Name = "Choix"
	glow.BackgroundColor3 = C.GoldLight
	glow.BackgroundTransparency = 1
	glow.Position = UDim2.fromOffset(-S.XS, -S.XS)
	glow.Size = UDim2.new(1, 2 * S.XS, 1, 2 * S.XS)
	glow.ZIndex = 5
	glow.Active = false
	glow.Parent = slot.frame
	UIKit.corner(glow, UITheme.Radius.Medium)
	local stroke = UIKit.stroke(glow, UITheme.Stroke.Thick, C.GoldLight)
	stroke.Transparency = 0.6
	local info = TweenInfo.new(PACK.SlotPulse / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local a = TweenService:Create(glow, info, { BackgroundTransparency = 0.7 })
	local b = TweenService:Create(stroke, info, { Transparency = 0 })
	a:Play()
	b:Play()
	slot.pick = { frame = glow, tweens = { a, b } }
end

local function renderHotbar()
	local held = heldId()
	local placed = placedSet()
	local locked = ArenaStore.inCombat()
	for index, slot in slots do
		local id = ArenaStore.hotbar[index]
		local hero, info = ArenaStore.heroInfo(if id ~= "" then id else nil)
		local selected = id ~= "" and (id == held or (bag.open and id == bag.chosen))
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
		slot.stroke.Color = if selected or bag.picking then C.Selected else UITheme.Stroke.Color
		slot.stroke.Thickness = if selected then UITheme.Stroke.Thick else UITheme.Stroke.Regular
		slot.frame.Position = UDim2.fromOffset(slot.offset, if selected then S.M - 8 else S.M)
		slot.placed.Visible = info ~= nil and placed[id] == true
		slot.level.Text = if hero then `Nv. {hero.Level}` else ""
		slot.level.TextTransparency = if locked then T.Disabled else 0
		setGuided(slot, id ~= "" and id == ArenaStore.guide.hotbar and not held and not locked and not placed[id] and not bag.picking)
		setPicking(slot, bag.picking)
	end
	ui.pick.Visible = bag.picking
end

------------------------------------------------------------------ Sacoche

-- Zone libre où centrer la Sacoche : bas des monnaies (HUD du haut) → haut de la hotbar, en px écran.
local function placeBag()
	local screen = ui.bagScreen
	if not screen then
		return
	end
	local viewport = screen.AbsoluteSize
	if viewport.X <= 0 then
		return
	end
	-- AbsolutePosition est mesurée sous la barre de Roblox (même pour un écran IgnoreGuiInset) ; la Sacoche
	-- est placée dans un écran IgnoreGuiInset : on ajoute l'inset aux deux repères.
	local inset = GuiService:GetGuiInset().Y
	local top = 0
	for _, key in { "Gold", "Gems", "SummonTickets" } do
		local pill = GuideTargets.get(`Currency.{key}`)
		if pill then
			top = math.max(top, pill.AbsolutePosition.Y + pill.AbsoluteSize.Y + inset)
		end
	end
	local bar = ui.bar
	local bottom = if bar then bar.AbsolutePosition.Y + inset else viewport.Y
	SacocheView.Layout(viewport, top, bottom)
end

local function setBag(open: boolean)
	if bag.open == open then
		return
	end
	if open and not ScreenState.free() then
		return -- un autre écran modal est ouvert : jamais deux fenêtres à la fois
	end
	bag.open = open
	bag.picking = false
	if open then
		placeBag()
		SacocheView.Open()
		GuideTargets.open("Bag")
	else
		SacocheView.Close()
		GuideTargets.close("Bag")
	end
	HeroBarController.bagChanged:Fire(open)
	render()
end

function HeroBarController.SetBag(open: boolean)
	setBag(open)
end

function HeroBarController.IsBagOpen(): boolean
	return bag.open
end

local function context(): SacocheModel.Context
	return {
		Infos = HeroConfig.Heroes :: any,
		Placed = placedSet(),
		Hotbar = ArenaStore.hotbar,
		New = fresh,
		Selected = bag.chosen,
		Filter = bag.filter,
		Query = if bag.search then bag.query else "",
		InCombat = ArenaStore.inCombat(),
		Busy = ArenaStore.busy,
	}
end

-- Exemplaires apparus depuis le premier chargement (vraies données de HeroesChanged) : « Nouveau ».
local function trackNew()
	if not ArenaStore.heroesLoaded then
		return
	end
	local before = HeroBarController.HasNew()
	if not known then
		known = {}
		for id in ArenaStore.heroes do
			(known :: any)[id] = true
		end
	else
		local seen = known :: { [string]: boolean }
		for id in ArenaStore.heroes do
			if not seen[id] then
				seen[id] = true
				fresh[id] = true
			end
		end
	end
	for id in fresh do
		if not ArenaStore.heroes[id] then
			fresh[id] = nil
		end
	end
	if HeroBarController.HasNew() ~= before then
		HeroBarController.newChanged:Fire(HeroBarController.HasNew())
	end
end

local function sortedHeroes(): { SacocheModel.Card }
	return SacocheModel.cards(ArenaStore.heroes :: any, { Infos = HeroConfig.Heroes :: any, Placed = {}, Hotbar = ArenaStore.hotbar })
end

local function renderBag()
	if bag.chosen and not ArenaStore.heroes[bag.chosen] then
		bag.chosen = nil
		bag.picking = false
	end
	if not bag.open then
		return
	end
	local ctx = context()
	local hero = if bag.chosen then ArenaStore.heroes[bag.chosen] else nil
	local detail = if hero then SacocheModel.detail(hero :: any, HeroConfig.Heroes[hero.HeroId] :: any, ctx) else nil
	local all = sortedHeroes()
	local equipCard = all[math.clamp(bag.equip, 1, math.max(#all, 1))]
	local equipHero = equipCard and ArenaStore.heroes[equipCard.Id]
	local total = 0
	for _ in ArenaStore.heroes do total += 1 end
	SacocheView.Render({
		Tab = bag.tab,
		Cards = SacocheModel.cards(ArenaStore.heroes :: any, ctx),
		Detail = detail,
		Filter = bag.filter,
		Query = bag.query,
		SearchOpen = bag.search,
		HasNew = HeroBarController.HasNew(),
		Total = total,
		EquipHero = if equipCard and equipHero then { HeroId = equipCard.HeroId, Name = equipCard.Name, Level = equipHero.Level } else nil,
		Picking = bag.picking,
	})
end

-- Actions de la fiche : contrats existants (PlacementState, ArenaService « Remove », HotbarAction).
local function onPrimary(action: string)
	local id = bag.chosen
	if not id or ArenaStore.inCombat() or ArenaStore.busy then
		return
	end
	if action == "Place" then
		PlacementState.selectCollection(ArenaStore.placement, id, ArenaStore.formation())
		setBag(false) -- le monde redevient prioritaire : le joueur choisit sa dalle (pastille « en main »)
		ArenaStore.notify()
	elseif action == "Remove" then
		for slot, placed in ArenaStore.formation() do
			if placed == id then
				ArenaStore.request("Remove", slot)
				break
			end
		end
	end
end

local function onSecondary(action: string)
	local id = bag.chosen
	if not id or ArenaStore.busy then
		return
	end
	if action == "PickHotbar" then
		bag.picking = not bag.picking
		ArenaStore.notify()
	elseif action == "ClearHotbar" then
		local slot = table.find(ArenaStore.hotbar, id)
		if slot then
			ArenaStore.hotbarAction("Clear", slot)
		end
	end
end

local function mountBag()
	local screen = Instance.new("ScreenGui")
	screen.Name = "Sacoche"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.DisplayOrder = 3 -- au-dessus du HUD (2) ; le menu (3) est masqué tant qu'elle est ouverte
	ui.bagScreen = screen
	SacocheView.Mount(screen, {
		OnClose = function()
			setBag(false)
		end,
		OnTab = function(tab: string)
			bag.tab = tab
			bag.picking = false
			ArenaStore.notify()
		end,
		OnSelect = function(id: string)
			if Drag.suppressed() then
				return
			end
			bag.chosen = id
			bag.picking = false
			if fresh[id] then
				fresh[id] = nil
				HeroBarController.newChanged:Fire(HeroBarController.HasNew())
			end
			ArenaStore.notify()
		end,
		OnFilter = function(filter: string)
			bag.filter = filter
			ArenaStore.notify()
		end,
		OnQuery = function(query: string)
			bag.query = query
			ArenaStore.notify()
		end,
		OnSearch = function(open: boolean)
			bag.search = open
			bag.query = ""
			ArenaStore.notify()
		end,
		OnPrimary = onPrimary,
		OnSecondary = onSecondary,
		OnEquipHero = function(step: number)
			local count = #sortedHeroes()
			if count > 0 then
				bag.equip = (bag.equip - 1 + step) % count + 1
				ArenaStore.notify()
			end
		end,
		BindDrag = function(frame: GuiObject, id: string)
			Drag.bind(frame, function()
				bag.chosen = id
				return { id = id }
			end)
		end,
	})
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeBag)
end

------------------------------------------------------------------ démarrage

function render()
	trackNew()
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
	screen.DisplayOrder = 4 -- au-dessus de la Sacoche (3) : le fantôme du drag et les raccourcis restent visibles
	buildHotbar(screen)
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local frames = {}
	for index, slot in slots do frames[index] = slot.frame end
	Drag.start(screen, frames)
	mountBag()

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
	-- un écran modal s'ouvre (Quêtes, Expédition, invocation, récompenses...) : la Sacoche se ferme, jamais
	-- de fenêtre par-dessus elle
	ScreenState.changed.Event:Connect(function(current: string?)
		if current ~= nil then
			setBag(false)
		end
	end)
	-- le HUD du haut et la hotbar bougent (résolution, monnaies) : la Sacoche reste centrée entre eux
	task.spawn(function()
		while true do
			task.wait(0.5)
			if bag.open then placeBag() end
		end
	end)
	render()
	ArenaStore.start()
	-- Portraits : les modèles des héros arrivent par réplication (ReplicatedStorage.Assets.Heros,
	-- copiés par HeroService) ; les raccourcis et cartes sans portrait sont refaits à leur arrivée.
	task.spawn(function()
		local assets = ReplicatedStorage:WaitForChild("Assets", 30)
		local heroes = assets and assets:WaitForChild("Heros", 30)
		if not heroes then
			return
		end
		heroes.ChildAdded:Connect(render)
		render()
	end)
end

return HeroBarController
