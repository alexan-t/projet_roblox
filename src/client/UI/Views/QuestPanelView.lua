--!strict
-- Panneau Quêtes — reproduit la fenêtre de la maquette « Quêtes HUD » (pack validé), docs/QUESTS.md.
-- Présentation seulement : le contenu vient de QuestService (GetQuestLog), les règles d'affichage de
-- Shared.Quests.QuestLog ; « Récupérer » appelle OnClaim(questId) et rien d'autre (le serveur revérifie
-- tout et décide des récompenses). Mesures : UITheme.Pack.Quest.
--   Voile sombre → fenêtre bois (WoodDeep) qui s'ouvre (0,9 → 1) ; en tête, plaque bois avec l'icône
--   Quête du pack et « Quêtes », bouton X rouge royal au coin ; une ligne de résumé.
--   Une carte par LIGNE de quêtes (QuestService regroupe : Défense, Collection de héros…), avec son palier
--   courant ; à récupérer, puis en cours, puis lignes terminées :
--     ligne et palier (« Défense du domaine · Palier 3/5 »), titre (+ pastille « Terminée »), description,
--     barre de progression + compteur X/Y, récompenses
--     (tuile sable, icône _small du pack, « ×n ») et l'état :
--       en cours     : barre partielle Progress, bouton gris « En cours » ;
--       à récupérer  : barre pleine Success, carte dorée, bouton « Récupérer » doré qui pulse doucement ;
--       récupérée    : « ✓ Récupéré » vert, carte estompée.
--   « Récupérer » est la cible de guidage « Quests.Claim » ; la fenêtre signale l'interface « Quests ».
-- API : QuestPanelView.Show(log, options) ; QuestPanelView.Update(log) ; QuestPanelView.SetClaiming(id?) ;
--   QuestPanelView.Hide() ; QuestPanelView.IsOpen().
--   log = { Quests: { { Id, Title, Description?, Progress, Target, Completed, Claimed, AutoClaim, Rewards } } }
--   options = { OnClaim: (questId: string) -> (), OnClose: (() -> ())? }

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CurrencyVisualConfig = require(ReplicatedStorage.Shared.Config.CurrencyVisualConfig)
local MenuIconConfig = require(ReplicatedStorage.Shared.Config.MenuIconConfig)
local QuestLog = require(ReplicatedStorage.Shared.Quests.QuestLog)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local GuideTargets = require(script.Parent.Parent.GuideTargets)
local UIKit = require(script.Parent.Parent.UIKit)

local Colors = UITheme.Colors
local Spacing = UITheme.Spacing
local Typography = UITheme.Typography
local PACK = UITheme.Pack.Quest

local CLAIM_PULSE = TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true) -- 1,1 s aller-retour
local ROW_GAP = 12
local MAX_HEIGHT = 190 -- px laissés autour de la liste (en-tête, marges), comme la maquette

export type Reward = { Kind: string, Amount: number }
export type Entry = {
	Id: string,
	Title: string,
	LineTitle: string?,
	Tier: number?,
	Tiers: number?,
	Description: string?,
	Progress: number,
	Target: number,
	Completed: boolean,
	Claimed: boolean,
	AutoClaim: boolean?,
	Rewards: { Reward },
}
export type Log = { Quests: { Entry } }
export type Options = { OnClaim: (questId: string) -> (), OnClose: (() -> ())? }

local QuestPanelView = {}

type Current = {
	screen: ScreenGui,
	panel: Frame,
	veil: GuiObject,
	list: ScrollingFrame,
	summary: TextLabel,
	options: Options,
	claiming: string?,
	tweens: { Tween },
}
local current: Current? = nil

local function stopTweens(c: Current)
	for _, tween in c.tweens do
		tween:Cancel()
	end
	table.clear(c.tweens)
end

-- Bouton d'état d'une carte : « Récupérer » (doré, pulse), « En cours » (gris), « ✓ Récupéré » (vert).
local function stateButton(c: Current, parent: Instance, entry: Entry, state: string): GuiObject
	local size = PACK.Button
	if state == "Claimable" then
		local busy = c.claiming ~= nil
		local claim = UIKit.button(parent, if c.claiming == entry.Id then "…" else "Récupérer", "Primary", UDim2.fromOffset(size.X, size.Y + UITheme.Shadow.ButtonLip), function()
			if current ~= c or c.claiming ~= nil then
				return -- un seul clic ; le serveur refuse de toute façon un double claim
			end
			c.options.OnClaim(entry.Id)
		end)
		claim.holder.Name = "Recuperer"
		claim.label.TextSize = 19
		claim.setEnabled(not busy)
		if not busy then
			-- pulse doux + lueur dorée (maquette : scale 1,05 et halo)
			local scale = Instance.new("UIScale")
			scale.Parent = claim.holder
			local tween = TweenService:Create(scale, CLAIM_PULSE, { Scale = 1.05 })
			tween:Play()
			table.insert(c.tweens, tween)
			local glow = UIKit.stroke(claim.face, UITheme.Stroke.Thick, Colors.GoldLight)
			glow.Name = "Lueur"
			glow.Transparency = 1
			local shine = TweenService:Create(glow, CLAIM_PULSE, { Transparency = 0.35 })
			shine:Play()
			table.insert(c.tweens, shine)
		end
		GuideTargets.register("Quests.Claim", claim.holder, "Récupère !")
		return claim.holder
	elseif state == "InProgress" then
		local holder = Instance.new("Frame")
		holder.Name = "EnCours"
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromOffset(size.X, size.Y + UITheme.Shadow.ButtonLip)
		holder.Parent = parent
		local lip = Instance.new("Frame")
		lip.BackgroundColor3 = Colors.DisabledLip
		lip.Position = UDim2.fromOffset(0, UITheme.Shadow.ButtonLip)
		lip.Size = UDim2.fromOffset(size.X, size.Y)
		lip.Parent = holder
		UIKit.corner(lip, UITheme.Radius.Medium)
		UIKit.stroke(lip, UITheme.Stroke.Regular)
		local face = Instance.new("Frame")
		face.BackgroundColor3 = Color3.new(1, 1, 1)
		face.Size = UDim2.fromOffset(size.X, size.Y)
		face.Parent = holder
		UIKit.corner(face, UITheme.Radius.Medium)
		UIKit.stroke(face, UITheme.Stroke.Regular)
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 90
		gradient.Color = ColorSequence.new(Colors.Disabled, Colors.StoneGrey)
		gradient.Parent = face
		local label = UIKit.text(face, "En cours", 17, { Stroke = false })
		label.TextTransparency = UITheme.Transparency.Disabled
		return holder
	end
	local done = UIKit.text(parent, "✓ Récupéré", 17, { Color = Colors.Success })
	done.Name = "Recupere"
	done.Size = UDim2.fromOffset(size.X, size.Y)
	return done
end

local function rewardTile(parent: Instance, reward: Reward, order: number)
	local visual = CurrencyVisualConfig.visual(reward.Kind)
	local tile = Instance.new("Frame")
	tile.Name = reward.Kind
	tile.LayoutOrder = order
	tile.Size = UDim2.fromOffset(PACK.Tile, PACK.Tile)
	tile.BackgroundColor3 = Colors.Sand
	tile.BackgroundTransparency = PACK.TileFill
	tile.Parent = parent
	UIKit.corner(tile, UITheme.Radius.Medium)
	UIKit.stroke(tile, UITheme.Stroke.Regular)
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icone"
	icon.BackgroundTransparency = 1
	icon.Image = if visual then visual.Small else ""
	icon.ScaleType = Enum.ScaleType.Fit
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromOffset(PACK.TileIcon, PACK.TileIcon)
	icon.Parent = tile
	local amount = UIKit.text(tile, `×{reward.Amount}`, Typography.Size.Caption)
	amount.Name = "Quantite"
	amount.AnchorPoint = Vector2.new(1, 1)
	amount.Position = UDim2.new(1, 6, 1, 8)
	amount.Size = UDim2.fromOffset(PACK.Tile, 18)
	amount.TextXAlignment = Enum.TextXAlignment.Right
	amount.ZIndex = 3
end

local function card(c: Current, entry: Entry, order: number)
	local state = QuestLog.state(entry)
	local claimable = state == "Claimable"
	local row = Instance.new("Frame")
	row.Name = entry.Id
	row.LayoutOrder = order
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.Size = UDim2.new(1, 0, 0, 96)
	row.BackgroundColor3 = if claimable then Colors.SandGold else Colors.Ink
	row.BackgroundTransparency = if claimable then PACK.RowClaimableFill else PACK.RowFill
	row.Parent = c.list
	UIKit.corner(row, UITheme.Radius.Medium)
	UIKit.stroke(row, UITheme.Stroke.Regular, if claimable then Colors.Selected else UITheme.Stroke.Color)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 14)
	pad.PaddingBottom = UDim.new(0, 14)
	pad.PaddingLeft = UDim.new(0, Spacing.L)
	pad.PaddingRight = UDim.new(0, Spacing.L)
	pad.Parent = row

	-- colonne de droite : récompenses + état
	local side = Instance.new("Frame")
	side.Name = "Etat"
	side.BackgroundTransparency = 1
	side.AnchorPoint = Vector2.new(1, 0.5)
	side.Position = UDim2.fromScale(1, 0.5)
	side.Size = UDim2.fromOffset(PACK.Button.X, PACK.Tile + Spacing.S + PACK.Button.Y + UITheme.Shadow.ButtonLip)
	side.Parent = row
	local rewards = Instance.new("Frame")
	rewards.Name = "Recompenses"
	rewards.BackgroundTransparency = 1
	rewards.Size = UDim2.new(1, 0, 0, PACK.Tile)
	rewards.Parent = side
	local rewardLayout = Instance.new("UIListLayout")
	rewardLayout.FillDirection = Enum.FillDirection.Horizontal
	rewardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rewardLayout.Padding = UDim.new(0, 6)
	rewardLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rewardLayout.Parent = rewards
	for index, reward in entry.Rewards do
		rewardTile(rewards, reward, index)
	end
	local button = stateButton(c, side, entry, state)
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, 0, 1, 0)
	if #entry.Rewards == 0 then
		side.Size = UDim2.fromOffset(PACK.Button.X, PACK.Button.Y + UITheme.Shadow.ButtonLip)
	end

	-- colonne de gauche : titre, description, progression
	local info = Instance.new("Frame")
	info.Name = "Infos"
	info.BackgroundTransparency = 1
	info.AutomaticSize = Enum.AutomaticSize.Y
	info.Size = UDim2.new(1, -(PACK.Button.X + Spacing.L), 0, 0)
	info.Parent = row
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = info
	if entry.LineTitle then
		-- ligne de quêtes et palier : la carte « s'incrémente » d'un palier à l'autre
		local tier = Instance.new("TextLabel")
		tier.Name = "Palier"
		tier.LayoutOrder = 0
		tier.BackgroundTransparency = 1
		tier.FontFace = Typography.Display
		tier.TextSize = Typography.Size.Caption
		tier.TextColor3 = if claimable then Colors.GoldLight else Colors.TextMuted
		tier.TextXAlignment = Enum.TextXAlignment.Left
		tier.Size = UDim2.new(1, 0, 0, 16)
		tier.Text = if entry.Tier and entry.Tiers then `{entry.LineTitle}  ·  Palier {entry.Tier}/{entry.Tiers}` else entry.LineTitle
		tier.Parent = info
	end
	local head = Instance.new("Frame")
	head.Name = "Entete"
	head.BackgroundTransparency = 1
	head.LayoutOrder = 1
	head.Size = UDim2.new(1, 0, 0, 26)
	head.Parent = info
	-- titre puis pastille « Terminée », alignés en ligne (le titre garde sa largeur réelle)
	local headLayout = Instance.new("UIListLayout")
	headLayout.FillDirection = Enum.FillDirection.Horizontal
	headLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	headLayout.Padding = UDim.new(0, Spacing.S)
	headLayout.SortOrder = Enum.SortOrder.LayoutOrder
	headLayout.Parent = head
	local title = UIKit.text(head, entry.Title, 19, { Align = Enum.TextXAlignment.Left })
	title.Name = "Titre"
	title.LayoutOrder = 1
	title.AutomaticSize = Enum.AutomaticSize.X
	title.Size = UDim2.fromScale(0, 1)
	if claimable then
		local tag = Instance.new("Frame")
		tag.Name = "Terminee"
		tag.LayoutOrder = 2
		tag.AutomaticSize = Enum.AutomaticSize.X
		tag.BackgroundColor3 = Colors.Success
		tag.Size = UDim2.fromOffset(0, 20)
		tag.Parent = head
		UIKit.corner(tag, UITheme.Radius.Pill)
		UIKit.stroke(tag, UITheme.Stroke.Thin)
		local tagPad = Instance.new("UIPadding")
		tagPad.PaddingLeft = UDim.new(0, 9)
		tagPad.PaddingRight = UDim.new(0, 9)
		tagPad.Parent = tag
		local tagText = UIKit.text(tag, "Terminée", 12)
		tagText.AutomaticSize = Enum.AutomaticSize.X
		tagText.Size = UDim2.fromScale(0, 1)
	end
	if entry.Description then
		local desc = Instance.new("TextLabel")
		desc.Name = "Description"
		desc.LayoutOrder = 2
		desc.BackgroundTransparency = 1
		desc.FontFace = Typography.Body
		desc.TextSize = 15
		desc.TextColor3 = Colors.TextMuted
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextWrapped = true
		desc.AutomaticSize = Enum.AutomaticSize.Y
		desc.Size = UDim2.new(1, 0, 0, 18)
		desc.Text = entry.Description
		desc.Parent = info
	end
	local progress = Instance.new("Frame")
	progress.Name = "Progression"
	progress.LayoutOrder = 3
	progress.BackgroundTransparency = 1
	progress.Size = UDim2.new(1, 0, 0, 20)
	progress.Parent = info
	local bar = UIKit.bar(progress, { Color = if entry.Completed then Colors.Success else Colors.Progress, Size = UDim2.new(1, -52, 0, 14) })
	bar.Frame.AnchorPoint = Vector2.new(0, 0.5)
	bar.Frame.Position = UDim2.fromScale(0, 0.5)
	bar.Frame.BackgroundTransparency = PACK.Track
	bar.Set(QuestLog.ratio(entry))
	local counter = UIKit.text(progress, `{math.min(entry.Progress, entry.Target)}/{entry.Target}`, 16, { Align = Enum.TextXAlignment.Right })
	counter.Name = "Compteur"
	counter.AnchorPoint = Vector2.new(1, 0)
	counter.Position = UDim2.fromScale(1, 0)
	counter.Size = UDim2.new(0, 46, 1, 0)

	if state == "Claimed" then
		-- récupérée : plus calme (contenu estompé, comme opacity .55 de la maquette)
		for _, object in row:GetDescendants() do
			if object:IsA("TextLabel") then
				object.TextTransparency = math.max(object.TextTransparency, PACK.ClaimedFade)
			elseif object:IsA("ImageLabel") then
				object.ImageTransparency = PACK.ClaimedFade
			elseif object:IsA("Frame") and object.BackgroundTransparency < 1 then
				object.BackgroundTransparency = 1 - (1 - object.BackgroundTransparency) * (1 - PACK.ClaimedFade)
			end
		end
		row.BackgroundTransparency = 1 - (1 - PACK.RowFill) * (1 - PACK.ClaimedFade)
	end
end

local function render(c: Current, log: Log)
	stopTweens(c)
	for _, child in c.list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	GuideTargets.unregister("Quests.Claim")
	local quests = log.Quests or {}
	c.summary.Text = QuestLog.summary(quests :: any)
	for order, entry in QuestLog.sorted(quests :: any) do
		card(c, entry :: any, order)
	end
end

function QuestPanelView.Show(log: Log, options: Options)
	QuestPanelView.Hide()
	local screen = UIKit.screen("PanneauQuetes", 10)
	local veil = UIKit.overlay(screen)
	local panel = Instance.new("Frame")
	panel.Name = "Panneau"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.new(0.5, 0, 0.5, 24)
	-- maquette : min(600 px, largeur de l'écran - 32 px)
	panel.Size = UDim2.new(1, -2 * Spacing.L, 0, 240) -- hauteur recalculée selon la liste (fit)
	panel.BackgroundColor3 = Colors.WoodDeep
	panel.BackgroundTransparency = PACK.Fill
	panel.Parent = screen
	UIKit.corner(panel, UITheme.Radius.Large)
	UIKit.stroke(panel, UITheme.Stroke.Thick)
	local width = Instance.new("UISizeConstraint")
	width.MaxSize = Vector2.new(PACK.Width, math.huge)
	width.Parent = panel
	-- contenu (résumé, liste) dans son propre cadre : la plaque de titre et le X restent hors du flux
	local content = Instance.new("Frame")
	content.Name = "Contenu"
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromScale(1, 1)
	content.Parent = panel
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, PACK.PaddingTop)
	pad.PaddingBottom = UDim.new(0, PACK.Padding.Y)
	pad.PaddingLeft = UDim.new(0, PACK.Padding.X)
	pad.PaddingRight = UDim.new(0, PACK.Padding.X)
	pad.Parent = content
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, ROW_GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = content

	-- plaque de titre (icône Quête du pack + « Quêtes ») à cheval sur le bord haut
	local plate = Instance.new("Frame")
	plate.Name = "Titre"
	plate.AnchorPoint = Vector2.new(0.5, 0)
	plate.Position = UDim2.new(0.5, 0, 0, -26)
	plate.AutomaticSize = Enum.AutomaticSize.X
	plate.Size = UDim2.fromOffset(0, 48)
	plate.BackgroundColor3 = Colors.Wood
	plate.ZIndex = 5
	plate.Parent = panel
	UIKit.corner(plate, UITheme.Radius.Medium)
	UIKit.stroke(plate, UITheme.Stroke.Thick)
	local plateLayout = Instance.new("UIListLayout")
	plateLayout.FillDirection = Enum.FillDirection.Horizontal
	plateLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	plateLayout.Padding = UDim.new(0, Spacing.S)
	plateLayout.Parent = plate
	local platePad = Instance.new("UIPadding")
	platePad.PaddingLeft = UDim.new(0, 14)
	platePad.PaddingRight = UDim.new(0, 26)
	platePad.Parent = plate
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icone"
	icon.BackgroundTransparency = 1
	icon.Image = MenuIconConfig.Buttons.Quest.Icon
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Size = UDim2.fromOffset(40, 40)
	icon.ZIndex = 6
	icon.Parent = plate
	local heading = UIKit.text(plate, "Quêtes", 28)
	heading.AutomaticSize = Enum.AutomaticSize.X
	heading.Size = UDim2.fromOffset(0, 40)
	heading.ZIndex = 6

	local close = UIKit.roundButton(panel, { Text = "X", Name = "Fermer", OnClick = function()
		QuestPanelView.Hide()
		if options.OnClose then
			options.OnClose()
		end
	end })
	close.AnchorPoint = Vector2.new(0.5, 0.5)
	close.Position = UDim2.new(1, -4, 0, 4)
	close.ZIndex = 6

	local summary = Instance.new("TextLabel")
	summary.Name = "Resume"
	summary.LayoutOrder = 1
	summary.BackgroundTransparency = 1
	summary.FontFace = Typography.Body
	summary.TextSize = 14
	summary.TextColor3 = Colors.TextMuted
	summary.Size = UDim2.new(1, 0, 0, 18)
	summary.Parent = content

	local list = Instance.new("ScrollingFrame")
	list.Name = "Liste"
	list.LayoutOrder = 2
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollBarThickness = UITheme.Stroke.ScrollBar
	list.ScrollBarImageColor3 = Colors.WoodLight
	list.Size = UDim2.new(1, 0, 0, 0)
	list.Parent = content
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, ROW_GAP)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = list
	local listPad = Instance.new("UIPadding")
	listPad.PaddingTop = UDim.new(0, 4)
	listPad.PaddingBottom = UDim.new(0, 8)
	listPad.PaddingLeft = UDim.new(0, 4)
	listPad.PaddingRight = UDim.new(0, 4)
	listPad.Parent = list
	-- Hauteurs explicites (les tailles automatiques imbriquées avec une liste défilante ne remontent pas) :
	-- la liste prend la hauteur de ses cartes, au plus la hauteur de l'écran moins l'en-tête (maquette :
	-- max-height 100vh - 190 px), puis elle défile ; la fenêtre suit.
	local scale = screen:FindFirstChildOfClass("UIScale")
	local function fit()
		local s = if scale then scale.Scale else 1
		local contentHeight = listLayout.AbsoluteContentSize.Y / s + 12 -- marges internes de la liste
		local maxHeight = math.max(160, screen.AbsoluteSize.Y / s - MAX_HEIGHT - 60)
		local listHeight = math.min(contentHeight, maxHeight)
		list.Size = UDim2.new(1, 0, 0, listHeight)
		panel.Size = UDim2.new(1, -2 * Spacing.L, 0, PACK.PaddingTop + 18 + ROW_GAP + listHeight + PACK.Padding.Y)
	end
	listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit)
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)

	local c: Current = { screen = screen, panel = panel, veil = veil, list = list, summary = summary, options = options, claiming = nil, tweens = {} }
	current = c
	veil.Activated:Connect(function()
		if c.claiming then
			return
		end
		QuestPanelView.Hide()
		if options.OnClose then
			options.OnClose()
		end
	end)
	render(c, log)
	fit()
	UIKit.open(panel, veil)
	GuideTargets.open("Quests")
end

-- Nouveau journal (claim, progression) : les cartes sont refaites, la fenêtre reste ouverte.
function QuestPanelView.Update(log: Log)
	local c = current
	if c then
		render(c, log)
	end
end

-- Réclamation en cours (id) ou terminée (nil) : les boutons « Récupérer » attendent la réponse.
function QuestPanelView.SetClaiming(id: string?, log: Log?)
	local c = current
	if not c then
		return
	end
	c.claiming = id
	if log then
		render(c, log)
	end
end

function QuestPanelView.IsOpen(): boolean
	return current ~= nil
end

function QuestPanelView.Hide()
	local c = current
	if not c then
		return
	end
	current = nil
	stopTweens(c)
	GuideTargets.unregister("Quests.Claim")
	GuideTargets.close("Quests")
	UIKit.close(c.panel, c.veil, true, function()
		c.screen:Destroy()
	end)
end

return QuestPanelView
