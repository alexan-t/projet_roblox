--!strict
-- Interface d'invocation et reveal du héros obtenu — docs/UI_DESIGN_SYSTEM.md § 6, docs/SUMMON.md.
-- Présentation seulement : HeroService décide du tirage, de la rareté et débite le ticket ;
-- SummonController ouvre cette vue au portail. L'effet 3D au portail est SummonEffectController.
--   Interface (avec bannières) : fenêtre « Invocation » ; à gauche un onglet par bannière ; au centre
--   la bannière choisie (nom, accroche, héros mis en avant en cartes 3D avec leur rareté) ; en bas
--   « Tickets : 3 », bouton « Taux » (chances par rareté) et bouton principal « Invoquer » (désactivé
--   sans ticket, avec une aide pour en gagner).
--   Sans bannière (aperçu) : gros ticket 3D, compteur, coût, « Invoquer ».
--   Reveal : voile, rayons de la couleur de la rareté, la carte du héros se retourne (largeur 0 →
--   pleine), portrait 3D en pied, nom, rareté (libellé + repère de forme), badge « Nouveau » (premier exemplaire), « Continuer ».
-- API : SummonView.Show(data, options) ; SummonView.Reveal(hero, options) ; SummonView.Hide().
--   Reveal cède la main le temps du retournement (≈ 0,3 s) : l'appeler dans un task.spawn au besoin.
--   data = { Tickets, Cost?, Banners?: { { Id, Name, Subtitle?, Featured: { { Name, Rarity, Model? } } } },
--            Rates?: { { Id, Name, Percent } }, Selected?: string (Id de bannière),
--            Free?: boolean (invocation tutorielle : « Invocation gratuite ! », bouton « Invoquer · Gratuit »
--            actif sans ticket et qui respire ; le serveur décide toujours du héros),
--            Starter?: { Name, Rarity, Model? } (invocation tutorielle : bannière spéciale « Premier héros »
--            sélectionnée avec ce héros, vraies bannières visibles mais grisées et non cliquables, « Taux »
--            masqué : il n'y a aucun tirage. Présentation seule, venue de GetSummonState) }
--   options (Show) = { OnSummon: ((bannerId: string?) -> ())?, OnClose: (() -> ())? }
--   hero = { Name: string, Model: Model?, ClassId: string?, New: boolean?, Rarity: string? }
--   options (Reveal) = { OnContinue: (() -> ())? }

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local Icons = require(script.Parent.Parent.Icons)
local RarityStyle = require(script.Parent.Parent.RarityStyle)
local UIKit = require(script.Parent.Parent.UIKit)
local AudioController = require(script.Parent.Parent.Parent.Controllers.AudioController)

local Colors = UITheme.Colors
local Typography = UITheme.Typography
local Spacing = UITheme.Spacing
local Animation = UITheme.Animation

local WINDOW = Vector2.new(440, 340)
local WINDOW_BANNERS = Vector2.new(920, 540)
local TAB_WIDTH = 210
local FEATURED_CARD = Vector2.new(184, 250)
local REVEAL_CARD = Vector2.new(260, 340)
local FLIP = 0.3 -- s : la carte se retourne

export type FeaturedHero = { Name: string, Rarity: string, Model: Model? }
export type BannerView = { Id: string, Name: string, Subtitle: string?, Featured: { FeaturedHero } }
export type Rate = { Id: string, Name: string, Percent: string }
export type StarterHero = { Name: string, Rarity: string, Model: Model? }
export type Data = { Tickets: number, Cost: number?, Banners: { BannerView }?, Rates: { Rate }?, Selected: string?, Free: boolean?, Starter: StarterHero? }
export type ShowOptions = { OnSummon: ((bannerId: string?) -> ())?, OnClose: (() -> ())? }
export type Hero = { Name: string, Model: Model?, ClassId: string?, New: boolean?, Rarity: string? }
export type RevealOptions = { OnContinue: (() -> ())? }

local SummonView = {}

local current: { screen: ScreenGui, panel: GuiObject, veil: GuiObject }? = nil

function SummonView.Hide()
	local c = current
	if not c then
		return
	end
	current = nil
	UIKit.close(c.panel, c.veil, true, function()
		c.screen:Destroy()
	end)
end

local function costText(cost: number): string
	return if cost > 1 then `{cost} tickets` else "1 ticket"
end

-- Carte d'un héros mis en avant : portrait en pied, nom, contour et badge de sa rareté.
local function featuredCard(parent: Instance, hero: FeaturedHero, order: number): Frame
	local card = UIKit.card(parent, { Size = FEATURED_CARD, Name = hero.Name })
	card.LayoutOrder = order
	local border = card:FindFirstChildOfClass("UIStroke")
	if border then
		border.Thickness = UITheme.Stroke.Thick
		RarityStyle.paint(border, hero.Rarity)
	end
	local art = card:FindFirstChild("Illustration") :: Frame
	art.Size = UDim2.new(1, -2 * Spacing.S, 0.72, -Spacing.S)
	if hero.Model then
		UIKit.portrait(art, hero.Model, true)
	end
	local name = card:FindFirstChild("Nom") :: TextLabel?
	if name then
		name.Position = UDim2.new(0, Spacing.XS, 0.72, Spacing.XS)
		name.Size = UDim2.new(1, -2 * Spacing.XS, 0.28, -Spacing.S)
	end
	RarityStyle.edgeBadge(card, hero.Rarity)
	return card
end

-- Liste des chances par rareté, en deux colonnes, par-dessus la bannière.
local function ratesPanel(parent: Instance, rates: { Rate }): Frame
	local panel = UIKit.subPanel(parent, UDim2.fromScale(1, 1))
	panel.Name = "Taux"
	panel.ZIndex = 8
	panel.BackgroundTransparency = UITheme.Transparency.Tooltip -- presque opaque : la bannière ne se lit pas au travers
	local title = UIKit.text(panel, "Chances par rareté", Typography.Size.Heading, { Align = Enum.TextXAlignment.Left })
	title.Position = UDim2.fromOffset(Spacing.L, Spacing.M)
	title.Size = UDim2.new(1, -2 * Spacing.L, 0, 30)
	title.ZIndex = 9
	local half = math.ceil(#rates / 2)
	for i, rate in rates do
		local column = if i <= half then 0 else 1
		local row = if i <= half then i - 1 else i - half - 1
		local line = Instance.new("Frame")
		line.BackgroundTransparency = 1
		line.Position = UDim2.new(column * 0.5, Spacing.L, 0, 56 + row * 44)
		line.Size = UDim2.new(0.5, -2 * Spacing.L, 0, 36)
		line.ZIndex = 9
		line.Parent = panel
		-- pastille couleur + forme : la rareté se lit aussi sans distinguer les couleurs
		local chip = RarityStyle.chip(line, rate.Id, Typography.Size.Caption)
		chip.AnchorPoint = Vector2.new(0, 0.5)
		chip.Position = UDim2.fromScale(0, 0.5)
		chip.ZIndex = 9
		local nameX = chip.Size.X.Offset + Spacing.S
		local name = UIKit.text(line, rate.Name, Typography.Size.Label, { Align = Enum.TextXAlignment.Left })
		name.Position = UDim2.fromOffset(nameX, 0)
		name.Size = UDim2.new(0.75, -nameX, 1, 0) -- la pastille élargie laisse la place à « Transcendant »
		name.ZIndex = 9
		local value = UIKit.text(line, rate.Percent, Typography.Size.Label, { Align = Enum.TextXAlignment.Right })
		value.Position = UDim2.fromScale(0.75, 0)
		value.Size = UDim2.fromScale(0.25, 1)
		value.ZIndex = 9
	end
	local note = UIKit.text(panel, "Les héros mis en avant sortent une fois sur deux dans leur rareté", Typography.Size.Caption, { Color = Colors.TextMuted })
	note.AnchorPoint = Vector2.new(0.5, 1)
	note.Position = UDim2.new(0.5, 0, 1, -Spacing.M)
	note.Size = UDim2.new(1, -2 * Spacing.L, 0, 20)
	note.ZIndex = 9
	return panel
end

-- Invocation tutorielle : le bouton principal respire tant que la fenêtre est ouverte.
local function breathe(button: UIKit.Button)
	task.delay(UITheme.Animation.Open.Time + 0.1, function()
		while button.holder.Parent do
			UIKit.pop(button.holder)
			task.wait(1.6)
		end
	end)
end

local function showBanners(content: Frame, data: Data, opts: ShowOptions, cost: number, enough: boolean)
	local free = data.Free == true
	local banners = data.Banners :: { BannerView }
	local selected = banners[1]
	for _, banner in banners do
		if banner.Id == data.Selected then
			selected = banner
		end
	end
	-- Invocation tutorielle : une bannière spéciale, seule sélectionnable, avec le héros de départ.
	local starter = data.Starter
	local starterBanner: BannerView? = if starter then {
		Id = "PremierHeros",
		Name = "Premier héros",
		Subtitle = "Ton premier défenseur rejoint ton royaume.",
		Featured = { { Name = starter.Name, Rarity = starter.Rarity, Model = starter.Model } },
	} else nil
	if starterBanner then
		selected = starterBanner
	end

	-- onglets
	local tabs = Instance.new("Frame")
	tabs.Name = "Bannieres"
	tabs.BackgroundTransparency = 1
	tabs.Size = UDim2.new(0, TAB_WIDTH, 1, -(56 + UITheme.Shadow.ButtonLip + Spacing.L))
	tabs.Parent = content
	local tabList = Instance.new("UIListLayout")
	tabList.Padding = UDim.new(0, Spacing.S)
	tabList.SortOrder = Enum.SortOrder.LayoutOrder
	tabList.Parent = tabs

	-- bannière choisie
	local stage = Instance.new("Frame")
	stage.Name = "Banniere"
	stage.BackgroundTransparency = 1
	stage.Position = UDim2.fromOffset(TAB_WIDTH + Spacing.L, 0)
	stage.Size = UDim2.new(1, -(TAB_WIDTH + Spacing.L), 1, -(56 + UITheme.Shadow.ButtonLip + Spacing.L))
	stage.Parent = content

	local rates: Frame? = nil
	local function render(banner: BannerView)
		selected = banner
		stage:ClearAllChildren()
		rates = nil
		local back = UIKit.subPanel(stage, UDim2.fromScale(1, 1))
		back.Name = "Fond"
		local title = UIKit.text(back, banner.Name, Typography.Size.Title, { Color = Colors.GoldLight, Align = Enum.TextXAlignment.Left })
		title.Position = UDim2.fromOffset(Spacing.L, Spacing.M)
		title.Size = UDim2.new(1, -2 * Spacing.L, 0, 38)
		if banner.Subtitle then
			local subtitle = UIKit.text(back, banner.Subtitle, Typography.Size.Label, { Color = Colors.TextMuted, Align = Enum.TextXAlignment.Left })
			subtitle.Position = UDim2.fromOffset(Spacing.L, 52)
			subtitle.Size = UDim2.new(1, -2 * Spacing.L, 0, 22)
		end
		local row = Instance.new("Frame")
		row.Name = "MisEnAvant"
		row.BackgroundTransparency = 1
		row.AnchorPoint = Vector2.new(0.5, 1)
		row.Position = UDim2.new(0.5, 0, 1, -Spacing.L)
		row.Size = UDim2.new(1, -2 * Spacing.L, 0, FEATURED_CARD.Y + Spacing.L)
		row.Parent = back
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.VerticalAlignment = Enum.VerticalAlignment.Bottom
		list.Padding = UDim.new(0, Spacing.L)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = row
		for index, hero in banner.Featured do
			local card = featuredCard(row, hero, index)
			UIKit.popIn(card, 0.05 + (index - 1) * 0.06)
		end
	end

	local tabButtons: { [string]: UIKit.Button } = {}
	if starterBanner then
		local special = UIKit.button(tabs, starterBanner.Name, "Tab", UDim2.new(1, 0, 0, 56 + UITheme.Shadow.ButtonLip), function() end)
		special.holder.LayoutOrder = 0
		special.label.TextSize = Typography.Size.Label
		special.setSelected(true)
		local locked = UIKit.text(tabs, "Disponible après ton premier héros", Typography.Size.Caption, { Color = Colors.TextMuted })
		locked.Name = "Verrouillees"
		locked.LayoutOrder = 1
		locked.Size = UDim2.new(1, 0, 0, 18)
		locked.TextWrapped = true
	end
	for index, banner in banners do
		local tab = UIKit.button(tabs, banner.Name, "Tab", UDim2.new(1, 0, 0, 56 + UITheme.Shadow.ButtonLip), function()
			if starterBanner then
				return -- invocation tutorielle : les vraies bannières ne sont pas encore disponibles
			end
			if selected ~= banner then
				render(banner)
				for id, button in tabButtons do
					button.setSelected(id == banner.Id)
				end
			end
		end)
		tab.holder.LayoutOrder = index + 1
		tab.label.TextSize = Typography.Size.Label
		tab.label.TextWrapped = true
		tab.setSelected(banner == selected)
		if starterBanner then
			tab.setEnabled(false) -- grisée, sans effet au clic
		end
		tabButtons[banner.Id] = tab
	end
	render(selected)

	-- barre du bas : tickets, taux, invoquer
	local bottom = Instance.new("Frame")
	bottom.Name = "Actions"
	bottom.BackgroundTransparency = 1
	bottom.AnchorPoint = Vector2.new(0, 1)
	bottom.Position = UDim2.fromScale(0, 1)
	bottom.Size = UDim2.new(1, 0, 0, 56 + UITheme.Shadow.ButtonLip)
	bottom.Parent = content
	local ticket = Instance.new("Frame")
	ticket.BackgroundTransparency = 1
	ticket.Size = UDim2.fromOffset(64, 56)
	ticket.Parent = bottom
	Icons.viewport(ticket, "Ticket")
	local count = UIKit.text(bottom, if free then "Invocation gratuite !" else `Tickets : {data.Tickets}`, Typography.Size.Heading,
		{ Color = if free then Colors.Success elseif enough then Colors.TextLight else Colors.Warning, Align = Enum.TextXAlignment.Left })
	count.Position = UDim2.fromOffset(72, 0)
	count.Size = UDim2.fromOffset(260, 32)
	local hint = UIKit.text(bottom, if free then "Ton premier héros t'attend" elseif enough then `Coût : {costText(cost)}` else "Gagne des tickets en combattant",
		Typography.Size.Caption, { Color = Colors.TextMuted, Align = Enum.TextXAlignment.Left })
	hint.Position = UDim2.fromOffset(72, 32)
	hint.Size = UDim2.fromOffset(260, 22)

	local summon = UIKit.button(bottom, if free then "Invoquer · Gratuit" else "Invoquer", "Primary", UDim2.fromOffset(240, 56 + UITheme.Shadow.ButtonLip), function()
		if enough and opts.OnSummon then
			local onSummon = opts.OnSummon
			local bannerId = selected.Id
			SummonView.Hide()
			onSummon(bannerId)
		end
	end)
	summon.setEnabled(enough and opts.OnSummon ~= nil)
	summon.holder.AnchorPoint = Vector2.new(1, 0)
	summon.holder.Position = UDim2.fromScale(1, 0)
	if free then
		breathe(summon)
	end
	if data.Rates and not starterBanner then -- aucun tirage pendant l'invocation tutorielle : pas de taux
		local rateList = data.Rates
		local toggle: UIKit.Button
		toggle = UIKit.button(bottom, "Taux", "Secondary", UDim2.fromOffset(120, 56 + UITheme.Shadow.ButtonLip), function()
			local open = rates
			if open then
				open:Destroy()
				rates = nil
			else
				local panel = ratesPanel(stage, rateList)
				UIKit.popIn(panel, 0, 1.03)
				rates = panel
			end
			toggle.setSelected(rates ~= nil)
		end)
		toggle.holder.AnchorPoint = Vector2.new(1, 0)
		toggle.holder.Position = UDim2.new(1, -(240 + Spacing.L), 0, 0)
	end
end

local function showSimple(content: Frame, data: Data, opts: ShowOptions, cost: number, enough: boolean)
	local ticket = Instance.new("Frame")
	ticket.Name = "Ticket"
	ticket.BackgroundTransparency = 1
	ticket.AnchorPoint = Vector2.new(0.5, 0)
	ticket.Position = UDim2.new(0.5, 0, 0, Spacing.S)
	ticket.Size = UDim2.fromOffset(120, 100)
	ticket.Parent = content
	Icons.viewport(ticket, "Ticket")

	local free = data.Free == true
	local count = UIKit.text(content, if free then "Invocation gratuite !" else `Tickets : {data.Tickets}`, Typography.Size.Heading,
		{ Color = if free then Colors.Success elseif enough then Colors.TextLight else Colors.Warning })
	count.Position = UDim2.fromOffset(0, 112)
	count.Size = UDim2.new(1, 0, 0, 30)
	local price = UIKit.text(content, if free then "Ton premier héros t'attend" else `Coût : {costText(cost)}`, Typography.Size.Label, { Color = Colors.TextMuted })
	price.Position = UDim2.fromOffset(0, 144)
	price.Size = UDim2.new(1, 0, 0, 22)

	local summon = UIKit.button(content, if free then "Invoquer · Gratuit" else "Invoquer", "Primary", UDim2.fromOffset(240, 56 + UITheme.Shadow.ButtonLip), function()
		if enough and opts.OnSummon then
			local onSummon = opts.OnSummon
			SummonView.Hide()
			onSummon(nil)
		end
	end)
	summon.setEnabled(enough and opts.OnSummon ~= nil)
	summon.holder.AnchorPoint = Vector2.new(0.5, 1)
	summon.holder.Position = UDim2.new(0.5, 0, 1, -(if enough then 0 else 26))
	if free then
		breathe(summon)
	end
	if not enough then
		local hint = UIKit.text(content, "Gagne des tickets en combattant", Typography.Size.Caption, { Color = Colors.TextMuted })
		hint.AnchorPoint = Vector2.new(0.5, 1)
		hint.Position = UDim2.fromScale(0.5, 1)
		hint.Size = UDim2.new(1, 0, 0, 20)
	end
end

function SummonView.Show(data: Data, options: ShowOptions?)
	SummonView.Hide()
	local opts: ShowOptions = options or {}
	local cost = data.Cost or 1
	local enough = data.Free == true or data.Tickets >= cost
	local withBanners = data.Banners ~= nil and #(data.Banners :: { BannerView }) > 0
	local screen = UIKit.screen("Invocation", 10)
	local veil = UIKit.overlay(screen)
	local function close()
		SummonView.Hide()
		if opts.OnClose then
			opts.OnClose()
		end
	end
	veil.Activated:Connect(close)
	local panel, content = UIKit.window(screen, { Size = if withBanners then WINDOW_BANNERS else WINDOW, Title = "Invocation", OnClose = close })
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	current = { screen = screen, panel = panel, veil = veil }
	if withBanners then
		showBanners(content, data, opts, cost, enough)
	else
		showSimple(content, data, opts, cost, enough)
	end
	UIKit.open(panel, veil)
end

-- Reveal : à afficher quand l'effet 3D du portail a révélé le héros.
function SummonView.Reveal(hero: Hero, options: RevealOptions?)
	SummonView.Hide()
	local opts: RevealOptions = options or {}
	local rarityColor = RarityStyle.color(hero.Rarity)
	local screen = UIKit.screen("Revelation", 12)
	local veil = UIKit.overlay(screen)
	local root = Instance.new("Frame")
	root.Name = "Contenu"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(REVEAL_CARD.X + 200, REVEAL_CARD.Y + 200)
	root.Parent = screen
	current = { screen = screen, panel = root, veil = veil }
	UIKit.open(root, veil)
	AudioController.Play("Revelation", { Delay = FLIP / 2 }) -- la face apparaît (#18)

	local center = UDim2.new(0.5, 0, 0, REVEAL_CARD.Y / 2 + Spacing.L)
	local rays = UIKit.rays(root, REVEAL_CARD.Y * 0.85, nil, if hero.Rarity then rarityColor else nil)
	rays.Position = center
	UIKit.popIn(rays, 0.05, 1)

	-- la carte se retourne : sa largeur passe de 0 à pleine, dos bois puis face crème
	local holder = Instance.new("Frame")
	holder.Name = "Carte"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = center
	holder.Size = UDim2.fromOffset(0, REVEAL_CARD.Y)
	holder.ClipsDescendants = false
	holder.Parent = root
	local back = Instance.new("Frame")
	back.Name = "Dos"
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Colors.Wood
	back.Parent = holder
	UIKit.corner(back, UITheme.Radius.Medium)
	UIKit.stroke(back, UITheme.Stroke.Thick)
	local half = TweenInfo.new(FLIP / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	UIKit.tween(holder, half, { Size = UDim2.fromOffset(REVEAL_CARD.X, REVEAL_CARD.Y) }).Completed:Wait()
	UIKit.tween(holder, half, { Size = UDim2.fromOffset(0, REVEAL_CARD.Y) }).Completed:Wait()
	back:Destroy()
	local card = UIKit.card(holder, { Size = REVEAL_CARD, Selected = true })
	card.Size = UDim2.fromScale(1, 1)
	if hero.Rarity then
		local border = card:FindFirstChildOfClass("UIStroke")
		if border then
			RarityStyle.paint(border, hero.Rarity)
		end
	end
	local art = card:FindFirstChild("Illustration") :: Frame
	art.Size = UDim2.new(1, -2 * Spacing.S, 0.78, -Spacing.S)
	if hero.Model then
		UIKit.portrait(art, hero.Model, true)
	end
	if hero.ClassId then
		local chip = Instance.new("Frame")
		chip.BackgroundColor3 = Colors.Cream
		chip.AnchorPoint = Vector2.new(0, 1)
		chip.Position = UDim2.new(0, Spacing.S, 0.78, 0)
		chip.Size = UDim2.fromOffset(44, 44)
		chip.ZIndex = 3
		chip.Parent = card
		UIKit.corner(chip, UITheme.Radius.Pill)
		UIKit.stroke(chip, UITheme.Stroke.Thin)
		Icons.viewport(chip, hero.ClassId)
	end
	if hero.Rarity then
		-- repère de rareté (forme) en face de la classe : le contour coloré ne suffit pas seul
		local rarityChip = RarityStyle.chip(card, hero.Rarity, Typography.Size.Label)
		rarityChip.AnchorPoint = Vector2.new(1, 1)
		rarityChip.Position = UDim2.new(1, -Spacing.S, 0.78, 0)
		rarityChip.ZIndex = 3
	end
	local name = UIKit.text(card, hero.Name, Typography.Size.Heading, { Color = Colors.InkSoft, Stroke = false })
	name.Position = UDim2.new(0, Spacing.S, 0.78, Spacing.XS)
	name.Size = UDim2.new(1, -2 * Spacing.S, 0.22, -Spacing.S)
	name.TextWrapped = true
	UIKit.tween(holder, TweenInfo.new(FLIP / 2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(REVEAL_CARD.X, REVEAL_CARD.Y) })
	if hero.New ~= false then
		local badge = UIKit.edgeBadge(card, "Nouveau", Colors.RoyalRed)
		badge.Size = UDim2.fromOffset(120, 30)
		UIKit.popIn(badge, FLIP / 2 + 0.1)
	end

	local title = UIKit.text(root, if hero.New == false then "Héros obtenu !" else "Nouveau héros !", Typography.Size.Title, { Color = Colors.GoldLight })
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.5, 0, 0, REVEAL_CARD.Y + Spacing.XL + Spacing.S)
	title.Size = UDim2.new(1, 0, 0, 40)
	UIKit.popIn(title, FLIP / 2)
	if hero.Rarity then
		local rarity = UIKit.text(root, RarityStyle.name(hero.Rarity), Typography.Size.Heading, { Color = rarityColor })
		rarity.AnchorPoint = Vector2.new(0.5, 0)
		rarity.Position = UDim2.new(0.5, 0, 0, REVEAL_CARD.Y + Spacing.XL + 48)
		rarity.Size = UDim2.new(1, 0, 0, 30)
		RarityStyle.paint(rarity, hero.Rarity)
		UIKit.popIn(rarity, FLIP / 2 + 0.08)
	end

	local continue = UIKit.button(root, "Continuer", "Primary", UDim2.fromOffset(220, 56 + UITheme.Shadow.ButtonLip), function()
		SummonView.Hide()
		if opts.OnContinue then
			task.delay(Animation.Close.Time, opts.OnContinue)
		end
	end)
	continue.holder.AnchorPoint = Vector2.new(0.5, 1)
	continue.holder.Position = UDim2.fromScale(0.5, 1)
	UIKit.popIn(continue.holder, FLIP / 2 + 0.25, 1.06)
end

return SummonView
