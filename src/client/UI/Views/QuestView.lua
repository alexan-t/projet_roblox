--!strict
-- Suivi de la quête principale (HUD, en haut à gauche) — issue #19, docs/UI_DESIGN_SYSTEM.md § 6 Quêtes.
-- Présentation seulement : QuestService fournit la quête active (GetActiveQuest) et valide la
-- réclamation ; le contrôleur de #11 appelle cette vue.
--   Ligne = sous-panneau : icône parchemin, titre, barre Progress et compteur « 0/1 ».
--   Progression : la barre avance (Count) et le compteur fait un pop.
--   Terminée : annonce « Quête terminée ! », badge « Terminée » et bouton principal « Récupérer ».
-- API : QuestView.Show(quest, options?) ; QuestView.Hide().
--   quest = { Title: string, Progress: number, Target: number, Completed: boolean }
--   options = { OnClaim: (() -> ())? } (sans OnClaim, pas de bouton)

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local Icons = require(script.Parent.Parent.Icons)
local UIKit = require(script.Parent.Parent.UIKit)

local Colors = UITheme.Colors
local Typography = UITheme.Typography
local Spacing = UITheme.Spacing

local WIDTH = 340
local HEIGHT = 92
local HEIGHT_DONE = 150
local TOP = 72 -- sous la barre de Roblox (boutons du menu en haut à gauche) ; plus bas si le chat est là

export type Quest = { Title: string, Progress: number, Target: number, Completed: boolean }
export type Options = { OnClaim: (() -> ())? }

local QuestView = {}

type Refs = {
	screen: ScreenGui,
	panel: Frame,
	title: TextLabel,
	bar: UIKit.Bar,
	counter: TextLabel,
	badge: Frame?,
	claim: UIKit.Button?,
	quest: Quest?,
}

local refs: Refs? = nil

-- En haut à gauche, mais sous la fenêtre de chat Roblox et sa barre de saisie quand elles y sont
-- (sinon le chat recouvre le suivi et capte le clic sur « Récupérer »). Suit les changements de
-- taille du chat et de l'écran.
local function placeBelowChat(screen: ScreenGui, panel: Frame)
	local window = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
	local input = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
	local scale = screen:FindFirstChildOfClass("UIScale")
	local function update()
		local bottom = 0
		for _, config: any in { window, input } do
			if config and config.Enabled and config.AbsoluteSize.X > 0 then
				bottom = math.max(bottom, config.AbsolutePosition.Y + config.AbsoluteSize.Y)
			end
		end
		local inset = GuiService:GetGuiInset().Y
		local top = if bottom > 0 then bottom + inset + Spacing.S else TOP
		local s: number = if scale then scale.Scale else 1
		panel.Position = UDim2.fromOffset(Spacing.ScreenMargin, math.max(top, TOP * s) / s)
	end
	update()
	for _, config: any in { window, input } do
		if config then
			config:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
			config:GetPropertyChangedSignal("AbsolutePosition"):Connect(update)
			config:GetPropertyChangedSignal("Enabled"):Connect(update)
		end
	end
	if scale then
		scale:GetPropertyChangedSignal("Scale"):Connect(update)
	end
end

local function build(): Refs
	local screen = UIKit.screen("QueteHUD", 2)
	local panel = UIKit.subPanel(screen, UDim2.fromOffset(WIDTH, HEIGHT))
	panel.Name = "Quete"
	panel.Position = UDim2.fromOffset(Spacing.ScreenMargin, TOP)
	panel.BackgroundTransparency = UITheme.Transparency.HUD
	local icon = Instance.new("Frame")
	icon.Name = "Icone"
	icon.BackgroundTransparency = 1
	icon.Position = UDim2.fromOffset(Spacing.S, Spacing.S)
	icon.Size = UDim2.fromOffset(56, 56)
	icon.Parent = panel
	Icons.viewport(icon, "Parchemin")
	local caption = UIKit.text(panel, "Quête", Typography.Size.Caption, { Color = Colors.TextMuted, Align = Enum.TextXAlignment.Left })
	caption.Position = UDim2.fromOffset(72, Spacing.S)
	caption.Size = UDim2.new(1, -84, 0, 18)
	local title = UIKit.text(panel, "", Typography.Size.Label, { Align = Enum.TextXAlignment.Left })
	title.Name = "Titre"
	title.Position = UDim2.fromOffset(72, 26)
	title.Size = UDim2.new(1, -84, 0, 24)
	title.TextTruncate = Enum.TextTruncate.AtEnd
	local bar = UIKit.bar(panel, { Color = Colors.Progress, Size = UDim2.new(1, -140, 0, 12) })
	bar.Frame.Position = UDim2.fromOffset(72, 62)
	local counter = UIKit.text(panel, "", Typography.Size.Label, { Align = Enum.TextXAlignment.Right })
	counter.Name = "Compteur"
	counter.AnchorPoint = Vector2.new(1, 0)
	counter.Position = UDim2.new(1, -Spacing.M, 0, 54)
	counter.Size = UDim2.fromOffset(52, 26)
	placeBelowChat(screen, panel)
	UIKit.open(panel)
	return { screen = screen, panel = panel, title = title, bar = bar, counter = counter }
end

function QuestView.Show(quest: Quest, options: Options?)
	local opts: Options = options or {}
	local r = refs or build()
	refs = r
	local previous = r.quest
	local sameQuest = previous ~= nil and previous.Title == quest.Title
	r.quest = quest
	r.title.Text = quest.Title
	local target = math.max(quest.Target, 1)
	local progress = math.clamp(quest.Progress, 0, target)
	r.counter.Text = `{progress}/{target}`
	r.bar.Set(progress / target, sameQuest)
	if sameQuest and previous and quest.Progress > previous.Progress then
		UIKit.pop(r.counter)
	end

	local completed = quest.Completed
	r.panel.Size = UDim2.fromOffset(WIDTH, if completed and opts.OnClaim then HEIGHT_DONE else HEIGHT)
	r.bar.SetColor(if completed then Colors.Success else Colors.Progress)
	if completed and not r.badge then
		local badge = UIKit.edgeBadge(r.panel, "Terminée", Colors.Success)
		r.badge = badge
		UIKit.popIn(badge)
		if sameQuest then
			UIKit.announce(r.screen, "Quête terminée !", { Color = Colors.Success, Hold = 2 })
		end
	elseif not completed and r.badge then
		(r.badge :: Frame):Destroy()
		r.badge = nil
	end
	if r.claim then
		r.claim.holder:Destroy()
		r.claim = nil
	end
	if completed and opts.OnClaim then
		local onClaim = opts.OnClaim
		local claim = UIKit.button(r.panel, "Récupérer", "Primary", UDim2.fromOffset(WIDTH - 2 * Spacing.M, 44 + UITheme.Shadow.ButtonLip), function()
			onClaim()
		end)
		claim.holder.Position = UDim2.new(0, Spacing.M, 0, HEIGHT - Spacing.XS)
		UIKit.popIn(claim.holder, 0.1, 1.06)
		r.claim = claim
	end
end

function QuestView.Hide()
	local r = refs
	if not r then
		return
	end
	refs = nil
	UIKit.close(r.panel, nil, true, function()
		r.screen:Destroy()
	end)
end

return QuestView
