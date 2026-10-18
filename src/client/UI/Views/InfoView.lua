--!strict
-- Petite fenêtre d'information du menu (voir docs/TUTORIAL_GUIDANCE.md) : Statistiques, ou une entrée
-- « Bientôt disponible » (Boutique, Guilde) présentée proprement plutôt qu'un bouton mort.
-- Présentation seulement : MenuController fournit le contenu (valeurs du serveur pour les stats).
--   Fenêtre bois standard (UIKit.window), grosse icône 3D en tête, puis :
--     • Rows : une ligne par statistique (libellé à gauche, valeur dorée à droite) sur des sous-panneaux ;
--     • Message : bandeau « Bientôt disponible » et un court texte (Builder Sans).
-- API : InfoView.Show(data, options?) ; InfoView.Hide().
--   data = { Title: string, Icon: string, Rows: { { Label: string, Value: string } }?, Message: string? }
--   options = { OnClose: (() -> ())?, Guide: string? (drapeau signalé à l'ouverture, ex. "Stats") }

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local GuideTargets = require(script.Parent.Parent.GuideTargets)
local Icons = require(script.Parent.Parent.Icons)
local UIKit = require(script.Parent.Parent.UIKit)

local Colors = UITheme.Colors
local Typography = UITheme.Typography
local Spacing = UITheme.Spacing

local WIDTH = 480
local ICON = 96
local ROW = 44

export type Row = { Label: string, Value: string }
export type Data = { Title: string, Icon: string, Rows: { Row }?, Message: string? }
export type Options = { OnClose: (() -> ())?, Guide: string? }

local InfoView = {}

local current: { screen: ScreenGui, panel: Frame, veil: GuiObject, guide: string?, onClose: (() -> ())? }? = nil

function InfoView.Hide()
	local c = current
	if not c then
		return
	end
	current = nil
	if c.guide then
		GuideTargets.close(c.guide)
	end
	UIKit.close(c.panel, c.veil, true, function()
		c.screen:Destroy()
	end)
	if c.onClose then
		c.onClose()
	end
end

function InfoView.Show(data: Data, options: Options?)
	InfoView.Hide()
	local opts: Options = options or {}
	local rows = data.Rows or {}
	local height = ICON + Spacing.L + (if data.Message then 150 else #rows * (ROW + Spacing.S)) + 2 * Spacing.L
	local screen = UIKit.screen("InfoMenu", 10)
	local veil = UIKit.overlay(screen)
	veil.Activated:Connect(InfoView.Hide)
	local panel, content = UIKit.window(screen, { Size = Vector2.new(WIDTH, height), Title = data.Title, OnClose = InfoView.Hide })
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	current = { screen = screen, panel = panel, veil = veil, guide = opts.Guide, onClose = opts.OnClose }

	local icon = Instance.new("Frame")
	icon.Name = "Icone"
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.new(0.5, 0, 0, Spacing.S)
	icon.Size = UDim2.fromOffset(ICON, ICON)
	icon.Parent = content
	Icons.viewport(icon, data.Icon)
	UIKit.popIn(icon, 0.05)

	local top = ICON + Spacing.L
	if data.Message then
		local soon = UIKit.subPanel(content, UDim2.new(1, 0, 0, 130))
		soon.Name = "BientotDisponible"
		soon.Position = UDim2.fromOffset(0, top)
		local heading = UIKit.text(soon, "Bientôt disponible", Typography.Size.Heading, { Color = Colors.GoldLight })
		heading.Position = UDim2.fromOffset(0, Spacing.M)
		heading.Size = UDim2.new(1, 0, 0, 30)
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.FontFace = Typography.Body
		text.TextSize = Typography.Size.Body
		text.TextColor3 = Colors.TextMuted
		text.TextWrapped = true
		text.Text = data.Message
		text.Position = UDim2.fromOffset(Spacing.L, 50)
		text.Size = UDim2.new(1, -2 * Spacing.L, 0, 66)
		text.Parent = soon
	end
	for index, row in rows do
		local line = UIKit.subPanel(content, UDim2.new(1, 0, 0, ROW))
		line.Name = `Ligne{index}`
		line.Position = UDim2.fromOffset(0, top + (index - 1) * (ROW + Spacing.S))
		local label = UIKit.text(line, row.Label, Typography.Size.Label, { Align = Enum.TextXAlignment.Left })
		label.Position = UDim2.fromOffset(Spacing.L, 0)
		label.Size = UDim2.new(0.7, -Spacing.L, 1, 0)
		local value = UIKit.text(line, row.Value, Typography.Size.Heading, { Color = Colors.GoldLight, Align = Enum.TextXAlignment.Right })
		value.AnchorPoint = Vector2.new(1, 0)
		value.Position = UDim2.new(1, -Spacing.L, 0, 0)
		value.Size = UDim2.new(0.3, 0, 1, 0)
		UIKit.popIn(line, 0.05 + (index - 1) * 0.04)
	end
	UIKit.open(panel, veil)
	if opts.Guide then
		GuideTargets.open(opts.Guide)
	end
end

return InfoView
