--!strict
-- Fenêtre Expédition : choix du stage d'une zone — issue #19, docs/UI_DESIGN_SYSTEM.md § 6.
-- Présentation seulement : ZoneService dit quels stages sont accessibles, ArenaService valide le choix
-- (SelectStage) et le lancement (Ready) ; ArenaPlacementController l'ouvre depuis la pancarte de l'arène (E).
--   Fenêtre bois avec bandeau « Expédition », voile derrière, ouverture 0,9 → 1.
--   Une carte par stage : icône épées croisées (ou cadenas), « Stage 1-1 », badge d'état :
--   « Disponible » (Success), « Terminé » (Gold), « Verrouillé » (StoneGrey, carte estompée) ; stage de
--   boss de zone (X-5) : pastille « Boss » (RoyalRed) sur l'illustration.
--   Le stage choisi a le contour Selected ; dessous, ses ennemis ; bouton principal « Lancer ».
-- API : ExpeditionView.Show(data, options) ; ExpeditionView.Hide().
--   data = { Zone: number, Title: string?, Stages: { { Stage: number, Unlocked: boolean, Cleared: boolean?,
--            Waves: number?, Enemies: { { EnemyId: string, Count: number, MiniBoss: boolean? } }? } } }
--   options = { OnLaunch: ((zone: number, stage: number) -> ())?, OnClose: (() -> ())?,
--               Selected: number? (stage choisi à l'ouverture), OnSelect: ((zone, stage) -> ())? (choix d'un
--               stage débloqué), Team: { Placed: number, Max: number }? (« Lancer » exige 1 héros posé),
--               OnPrepare: (() -> ())? (bouton secondaire « Préparer l'équipe »),
--               Guide: boolean? (tutoriel : « Lancer » fait un petit rebond une fois si l'équipe est prête,
--               sinon « Préparer l'équipe » rebondit doucement tant que la fenêtre est ouverte) }

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local Icons = require(script.Parent.Parent.Icons)
local UIKit = require(script.Parent.Parent.UIKit)
local GuideTargets = require(script.Parent.Parent.GuideTargets)

local Colors = UITheme.Colors
local Typography = UITheme.Typography
local Spacing = UITheme.Spacing

local WINDOW = Vector2.new(760, 430)
local CARD = Vector2.new(124, 150)

export type Enemy = { EnemyId: string, Count: number, MiniBoss: boolean? }
export type Stage = { Stage: number, Unlocked: boolean, Cleared: boolean?, Waves: number?, Enemies: { Enemy }? }
-- EliteStages (#69) : cartes du Mode Élite (sa propre progression) ; EliteUnlocked : 1-5 Normal terminé ;
-- Mode : mode du stage choisi ("Normal" par défaut). Sans EliteStages, pas de sélecteur.
export type Data = { Zone: number, Title: string?, Stages: { Stage }, EliteStages: { Stage }?, EliteUnlocked: boolean?, Mode: string? }
export type Team = { Placed: number, Max: number }
export type Options = {
	OnLaunch: ((zone: number, stage: number, mode: string) -> ())?,
	OnClose: (() -> ())?,
	Selected: number?,
	OnSelect: ((zone: number, stage: number, mode: string) -> ())?,
	Team: Team?,
	OnPrepare: (() -> ())?,
	Guide: boolean?,
}

local ExpeditionView = {}

local current: { screen: ScreenGui, panel: Frame, veil: GuiObject }? = nil

local function stageCard(parent: Instance, zone: number, stage: Stage, elite: boolean?): (Frame, UIStroke, TextButton)
	local frame = Instance.new("Frame")
	frame.Name = `Stage_{stage.Stage}`
	frame.Size = UDim2.fromOffset(CARD.X, CARD.Y)
	frame.BackgroundColor3 = Colors.Cream
	frame.BackgroundTransparency = if stage.Unlocked then UITheme.Transparency.PanelStrong else 0.6
	frame.LayoutOrder = stage.Stage
	frame.Parent = parent
	UIKit.corner(frame, UITheme.Radius.Medium)
	local border = UIKit.stroke(frame, UITheme.Stroke.Regular)
	local art = Instance.new("Frame")
	art.BackgroundColor3 = Colors.Sand
	art.BackgroundTransparency = UITheme.Transparency.PanelStrong
	art.Position = UDim2.fromOffset(Spacing.S, Spacing.S + 6)
	art.Size = UDim2.new(1, -2 * Spacing.S, 0.62, 0)
	art.Parent = frame
	UIKit.corner(art, UITheme.Radius.Small)
	local icon = Icons.viewport(art, if stage.Unlocked then "Combat" else "Cadenas")
	icon.Size = UDim2.fromScale(0.85, 0.85)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	if not stage.Unlocked then
		icon.ImageTransparency = 0.3
	end
	local name = UIKit.text(frame, `Stage {zone}-{stage.Stage}`, Typography.Size.Label, { Color = Colors.InkSoft, Stroke = false })
	name.Position = UDim2.new(0, 0, 0.62, Spacing.S + 6)
	name.Size = UDim2.new(1, 0, 0, 26)
	if not stage.Unlocked then
		name.TextTransparency = UITheme.Transparency.Disabled
		UIKit.edgeBadge(frame, "Verrouillé", Colors.StoneGrey)
	elseif stage.Cleared then
		UIKit.edgeBadge(frame, "Terminé", Colors.Gold)
	else
		UIKit.edgeBadge(frame, "Disponible", Colors.Success)
	end
	-- Stage de boss de zone (X-5) : petite pastille « Boss » au coin de l'illustration.
	local boss = false
	for _, enemy in stage.Enemies or {} do
		boss = boss or enemy.MiniBoss == true
	end
	if elite then
		-- Mode Élite : pastille au coin haut de l'illustration (jamais confondu avec la carte Normale)
		local tag = UIKit.badge(art, "Élite", Colors.RoyalRed)
		tag.Name = "Elite"
		tag.Position = UDim2.fromOffset(Spacing.XS, Spacing.XS)
		tag.ZIndex = 4
	end
	if boss then
		local mark = UIKit.badge(art, "Boss", Colors.RoyalRed)
		mark.Name = "Boss"
		mark.AnchorPoint = Vector2.new(1, 1)
		mark.Position = UDim2.new(1, -Spacing.XS, 1, -Spacing.XS)
		mark.ZIndex = 4
	end
	local touch = Instance.new("TextButton")
	touch.BackgroundTransparency = 1
	touch.Text = ""
	touch.Size = UDim2.fromScale(1, 1)
	touch.ZIndex = 10
	touch.Parent = frame
	return frame, border, touch
end

local function describe(stage: Stage): string
	local parts = {}
	for _, enemy in stage.Enemies or {} do
		local name = ArenaConfig.EnemyNames[enemy.EnemyId] or enemy.EnemyId
		table.insert(parts, if enemy.MiniBoss then `Boss : {name}` else `{name} ×{enemy.Count}`)
	end
	local waves = stage.Waves
	local prefix = if waves then (if waves > 1 then `{waves} vagues` else "1 vague") else ""
	if #parts == 0 then
		return prefix
	end
	return (if prefix ~= "" then prefix .. "  ·  " else "") .. table.concat(parts, "  ·  ")
end

function ExpeditionView.Show(data: Data, options: Options?)
	ExpeditionView.Hide()
	local opts: Options = options or {}
	local screen = UIKit.screen("Expedition", 10)
	local veil = UIKit.overlay(screen)
	local function close()
		ExpeditionView.Hide()
		if opts.OnClose then
			opts.OnClose()
		end
	end
	veil.Activated:Connect(close)
	local panel, content = UIKit.window(screen, { Size = WINDOW, Title = "Expédition", OnClose = close })
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	current = { screen = screen, panel = panel, veil = veil }

	local zoneTitle = UIKit.text(content, data.Title or `Zone {data.Zone}`, Typography.Size.Heading, { Align = Enum.TextXAlignment.Left })
	zoneTitle.Position = UDim2.fromOffset(Spacing.S, Spacing.S)
	zoneTitle.Size = UDim2.new(1, 0, 0, 30)

	local row = Instance.new("Frame")
	row.Name = "Stages"
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(0, 60)
	row.Size = UDim2.new(1, 0, 0, CARD.Y + 16)
	row.Parent = content
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.Padding = UDim.new(0, Spacing.L)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = row

	local detail = UIKit.subPanel(content, UDim2.new(1, 0, 0, 52))
	detail.Name = "Detail"
	detail.Position = UDim2.fromOffset(0, 60 + CARD.Y + 32)
	local detailText = UIKit.text(detail, "", Typography.Size.Label, { Align = Enum.TextXAlignment.Left })
	detailText.Position = UDim2.fromOffset(Spacing.L, 0)
	detailText.Size = UDim2.new(1, -2 * Spacing.L, 1, 0)
	detailText.TextTruncate = Enum.TextTruncate.AtEnd

	local selected: Stage? = nil
	local mode: string = if data.Mode == "Elite" and data.EliteStages then "Elite" else "Normal"
	local launch = UIKit.button(content, "Lancer", "Primary", UDim2.fromOffset(220, 56 + UITheme.Shadow.ButtonLip), function()
		local stage = selected
		if stage and stage.Unlocked and opts.OnLaunch then
			local onLaunch = opts.OnLaunch
			local launchMode = mode
			ExpeditionView.Hide()
			onLaunch(data.Zone, stage.Stage, launchMode)
		end
	end)
	launch.holder.AnchorPoint = Vector2.new(0.5, 1)
	launch.holder.Position = UDim2.new(0.5, 0, 1, 0)
	launch.setEnabled(false)
	GuideTargets.register("Expedition.Launch", launch.holder)
	local onPrepare = opts.OnPrepare
	local prepareButton: UIKit.Button? = nil
	if onPrepare then
		-- Deux actions côte à côte : préparer (secondaire) à gauche, lancer (principale) à droite.
		launch.holder.Position = UDim2.new(0.5, Spacing.S + 110, 1, 0)
		local prepare = UIKit.button(content, "Préparer l'équipe", "Secondary", UDim2.fromOffset(220, 56 + UITheme.Shadow.ButtonLip), function()
			ExpeditionView.Hide()
			onPrepare()
		end)
		prepare.holder.AnchorPoint = Vector2.new(0.5, 1)
		prepare.holder.Position = UDim2.new(0.5, -Spacing.S - 110, 1, 0)
		prepareButton = prepare
		GuideTargets.register("Expedition.Prepare", prepare.holder)
	end
	local team = opts.Team
	local teamReady = team == nil or team.Placed >= 1
	-- guidage : l'action possible maintenant (lancer si l'équipe est prête, sinon la préparer)
	if teamReady or not prepareButton then
		GuideTargets.register("Expedition.Next", launch.holder, "Lance le combat")
	else
		GuideTargets.register("Expedition.Next", (prepareButton :: UIKit.Button).holder, "Pose un héros d'abord")
	end

	-- Mode affiché (Normal / Élite, #69) : ses cartes, avec SA progression ; changer de mode reconstruit
	-- les cartes, la sélection et le détail. Le mode choisi est toujours visible (onglet, titre, badges).
	local borders: { [number]: UIStroke } = {}
	local function stagesOf(m: string): { Stage }
		return if m == "Elite" then data.EliteStages or {} else data.Stages
	end
	local function select(stage: Stage)
		selected = stage
		for number, border in borders do
			local on = number == stage.Stage
			border.Color = if on then Colors.Selected else UITheme.Stroke.Color
			border.Thickness = if on then UITheme.Stroke.Thick else UITheme.Stroke.Regular
		end
		local text: string = if stage.Unlocked then describe(stage)
			elseif mode == "Elite" and not data.EliteUnlocked then `Termine {data.Zone}-5 pour débloquer l'Élite`
			else "Termine le stage précédent pour débloquer celui-ci"
		if stage.Unlocked and team then
			text = `Équipe {team.Placed}/{team.Max}  ·  ` .. (if teamReady then text else "Place au moins un héros sur les dalles")
		end
		if mode == "Elite" and stage.Unlocked then
			text = "Élite  ·  " .. text
		end
		detailText.Text = text
		launch.setEnabled(stage.Unlocked and teamReady and opts.OnLaunch ~= nil)
	end
	local default: Stage? = nil
	local tabs: { [string]: UIKit.Button } = {}
	local function showMode(m: string, preferred: number?)
		mode = m
		for _, child in row:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		table.clear(borders)
		selected = nil
		local list = stagesOf(m)
		local frames: { [Stage]: Frame } = {}
		for index, stage in list do
			local frame, border, touch = stageCard(row, data.Zone, stage, m == "Elite")
			borders[stage.Stage] = border
			frames[stage] = frame
			UIKit.popIn(frame, 0.05 + (index - 1) * 0.05) -- cascade de 0,05 s par carte
			touch.Activated:Connect(function()
				if selected == stage then
					return
				end
				select(stage)
				if stage.Unlocked and opts.OnSelect then
					opts.OnSelect(data.Zone, stage.Stage, m)
				end
			end)
		end
		-- par défaut : le stage déjà choisi, sinon le premier stage disponible non terminé, sinon le premier
		default = list[1]
		for _, stage in list do
			if stage.Unlocked and not stage.Cleared then
				default = stage
				break
			end
		end
		for _, stage in list do
			if stage.Stage == preferred then
				default = stage
			end
		end
		zoneTitle.Text = (data.Title or `Zone {data.Zone}`) .. (if m == "Elite" then "  ·  Élite" else "")
		zoneTitle.TextColor3 = if m == "Elite" then Colors.RoyalRed else Colors.TextLight
		for id, tab in tabs do
			tab.setSelected(id == m)
		end
		local first = default
		if first and frames[first] then
			GuideTargets.register("Expedition.Stage", frames[first]) -- guidage : le stage proposé
		end
		if first then
			select(first)
		else
			launch.setEnabled(false)
			detailText.Text = `Termine {data.Zone}-5 pour débloquer l'Élite`
		end
	end
	-- Sélecteur léger NORMAL / ÉLITE en haut à droite (l'Élite verrouillée reste consultable).
	if data.EliteStages then
		for index, info in { { Id = "Normal", Label = "Normal" }, { Id = "Elite", Label = if data.EliteUnlocked then "Élite" else "Élite · verrouillé" } } do
			local tab = UIKit.button(content, info.Label, "Tab", UDim2.fromOffset(if index == 1 then 110 else 190, 36 + UITheme.Shadow.ButtonLip), function()
				if mode ~= info.Id then
					showMode(info.Id, nil)
				end
			end)
			tab.holder.Name = `Mode_{info.Id}`
			tab.holder.AnchorPoint = Vector2.new(1, 0)
			tab.holder.Position = if index == 1 then UDim2.new(1, -(190 + Spacing.S), 0, Spacing.XS) else UDim2.new(1, 0, 0, Spacing.XS)
			tab.label.TextSize = Typography.Size.Label
			tabs[info.Id] = tab
		end
	end
	showMode(mode, opts.Selected)
	UIKit.open(panel, veil)
	GuideTargets.open("Expedition")
	-- Tutoriel : la hiérarchie visuelle montre l'étape suivante, sans texte ni flèche.
	if opts.Guide and default and default.Unlocked then
		local window = current
		task.delay(UITheme.Animation.Open.Time + 0.1, function()
			if current ~= window then
				return
			end
			if teamReady then
				UIKit.pop(launch.holder) -- une fois
				return
			end
			local prepare = prepareButton
			while prepare and current == window and prepare.holder.Parent do
				UIKit.pop(prepare.holder)
				task.wait(2)
			end
		end)
	end
end

function ExpeditionView.Hide()
	local c = current
	if not c then
		return
	end
	current = nil
	GuideTargets.close("Expedition")
	UIKit.close(c.panel, c.veil, true, function()
		c.screen:Destroy()
	end)
end

return ExpeditionView
