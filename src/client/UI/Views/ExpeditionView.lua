--!strict
-- Fenêtre Expédition : choix du stage d'une zone — issue #19, docs/UI_DESIGN_SYSTEM.md § 6.
-- Présentation seulement : ZoneService dit quels stages sont accessibles et valide le lancement
-- (RequestStartStage) ; le contrôleur de #11 appelle cette vue.
--   Fenêtre bois avec bandeau « Expédition », voile derrière, ouverture 0,9 → 1.
--   Une carte par stage : icône épées croisées (ou cadenas), « Stage 1-1 », badge d'état :
--   « Disponible » (Success), « Terminé » (Gold), « Verrouillé » (StoneGrey, carte estompée).
--   Le stage choisi a le contour Selected ; dessous, ses ennemis ; bouton principal « Lancer ».
-- API : ExpeditionView.Show(data, options) ; ExpeditionView.Hide().
--   data = { Zone: number, Title: string?, Stages: { { Stage: number, Unlocked: boolean, Cleared: boolean?,
--            Waves: number?, Enemies: { { EnemyId: string, Count: number, MiniBoss: boolean? } }? } } }
--   options = { OnLaunch: ((zone: number, stage: number) -> ())?, OnClose: (() -> ())? }

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local Icons = require(script.Parent.Parent.Icons)
local UIKit = require(script.Parent.Parent.UIKit)

local Colors = UITheme.Colors
local Typography = UITheme.Typography
local Spacing = UITheme.Spacing

local WINDOW = Vector2.new(760, 430)
local CARD = Vector2.new(124, 150)

export type Enemy = { EnemyId: string, Count: number, MiniBoss: boolean? }
export type Stage = { Stage: number, Unlocked: boolean, Cleared: boolean?, Waves: number?, Enemies: { Enemy }? }
export type Data = { Zone: number, Title: string?, Stages: { Stage } }
export type Options = { OnLaunch: ((zone: number, stage: number) -> ())?, OnClose: (() -> ())? }

local ExpeditionView = {}

local current: { screen: ScreenGui, panel: Frame, veil: GuiObject }? = nil

local function stageCard(parent: Instance, zone: number, stage: Stage): (Frame, UIStroke, TextButton)
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
		UIKit.badge(frame, "Verrouillé", Colors.StoneGrey)
	elseif stage.Cleared then
		UIKit.badge(frame, "Terminé", Colors.Gold)
	else
		UIKit.badge(frame, "Disponible", Colors.Success)
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
		table.insert(parts, if enemy.MiniBoss then `Mini-boss {enemy.EnemyId}` else `{enemy.EnemyId} ×{enemy.Count}`)
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
	local panel, content = UIKit.panel(screen, { Size = WINDOW, Title = "Expédition", OnClose = close })
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

	local launch = UIKit.button(content, { Text = "Lancer", Style = "Disabled", Size = Vector2.new(220, 56) })
	launch.Holder.AnchorPoint = Vector2.new(0.5, 1)
	launch.Holder.Position = UDim2.new(0.5, 0, 1, 0)

	local borders: { [number]: UIStroke } = {}
	local selected: Stage? = nil
	local function select(stage: Stage)
		selected = stage
		for number, border in borders do
			local on = number == stage.Stage
			border.Color = if on then Colors.Selected else UITheme.Stroke.Color
			border.Thickness = if on then UITheme.Stroke.Thick else UITheme.Stroke.Regular
		end
		detailText.Text = if stage.Unlocked then describe(stage) else "Termine le stage précédent pour débloquer celui-ci"
		launch.SetStyle(if stage.Unlocked and opts.OnLaunch then "Primary" else "Disabled")
	end
	for index, stage in data.Stages do
		local frame, border, touch = stageCard(row, data.Zone, stage)
		borders[stage.Stage] = border
		UIKit.popIn(frame, 0.05 + (index - 1) * 0.05) -- cascade de 0,05 s par carte
		touch.Activated:Connect(function()
			select(stage)
		end)
	end
	launch.Face.Activated:Connect(function()
		local stage = selected
		if stage and stage.Unlocked and opts.OnLaunch then
			local onLaunch = opts.OnLaunch
			ExpeditionView.Hide()
			onLaunch(data.Zone, stage.Stage)
		end
	end)
	-- par défaut : le premier stage disponible non terminé, sinon le premier
	local default = data.Stages[1]
	for _, stage in data.Stages do
		if stage.Unlocked and not stage.Cleared then
			default = stage
			break
		end
	end
	if default then
		select(default)
	end
	UIKit.open(panel, veil)
end

function ExpeditionView.Hide()
	local c = current
	if not c then
		return
	end
	current = nil
	UIKit.close(c.panel, c.veil, true, function()
		c.screen:Destroy()
	end)
end

return ExpeditionView
