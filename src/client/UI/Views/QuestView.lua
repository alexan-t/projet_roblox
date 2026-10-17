--!strict
-- Suivi de la quête principale (HUD, en haut à gauche) — issue #19, docs/UI_DESIGN_SYSTEM.md § 6 Quêtes.
-- Présentation seulement : QuestService fournit la quête active (GetActiveQuest) et valide la
-- réclamation ; le contrôleur de #11 appelle cette vue.
--   Ligne = sous-panneau : icône parchemin, titre, barre Progress et compteur « 0/1 ».
--   Progression : la barre avance (Count) et le compteur fait un pop.
--   Terminée : annonce « Quête terminée ! », badge « Terminée » et bouton principal « Récupérer ».
--   Récompense à récupérer : la fenêtre attire l'œil tant que le bouton est là (contour doré qui pulse,
--   rayons dorés derrière le parchemin qui se dandine, bouton qui respire, petit rebond régulier).
--   Quête réclamée automatiquement (AutoClaim, tutoriel) : Complete montre la quête terminée (barre pleine,
--   badge « Terminée », annonce « Quête terminée ! », petit rebond), puis la suivante arrive d'elle-même.
-- API : QuestView.Show(quest, options?) ; QuestView.Complete(title, target, after) ; QuestView.Hide().
--   quest = { Title: string, Progress: number, Target: number, Completed: boolean }
--   options = { OnClaim: (() -> ())? } (sans OnClaim, pas de bouton)
--   after : appelé quand l'annonce est passée (montrer la quête suivante, ou Hide).

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
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
local BOUNCE_EVERY = 3.5 -- s entre deux petits rebonds de la fenêtre quand une récompense attend
local COMPLETE_HOLD = 1.8 -- s pendant lesquels la quête terminée reste affichée avant la suivante

-- La récompense n'est jamais annoncée ici : elle reste une surprise, révélée à la réclamation (QuestRewardView).
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
	icon: Frame,
	attention: { tweens: { Tween }, rays: Frame?, token: number }?,
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
	return { screen = screen, panel = panel, title = title, bar = bar, counter = counter, icon = icon }
end

local attentionToken = 0

-- Arrête l'appel à l'attention (récompense récupérée, quête suivante, fenêtre fermée).
local function stopAttention(r: Refs)
	local attention = r.attention
	if not attention then
		return
	end
	r.attention = nil
	attentionToken += 1
	for _, tween in attention.tweens do
		tween:Cancel()
	end
	if attention.rays then
		attention.rays:Destroy()
	end
	local stroke = r.panel:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = Colors.Ink
		stroke.Thickness = UITheme.Stroke.Thin
	end
	r.icon.Rotation = 0
end

-- « Une récompense t'attend » : tout reste dans la fenêtre, rien ne cache le jeu.
local function startAttention(r: Refs, claim: UIKit.Button)
	stopAttention(r)
	attentionToken += 1
	local token = attentionToken
	local tweens: { Tween } = {}
	local function loop(instance: Instance, goal: { [string]: any })
		local tween = TweenService:Create(instance, UITheme.Animation.Pulse, goal)
		tween:Play()
		table.insert(tweens, tween)
	end
	local stroke = r.panel:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = Colors.Gold
		loop(stroke, { Color = Colors.GoldLight, Thickness = UITheme.Stroke.Thick })
	end
	-- rayons dorés derrière le parchemin, qui se dandine
	local rays = UIKit.rays(r.icon, 44, 10, Colors.GoldLight)
	rays.Position = UDim2.fromScale(0.5, 0.5)
	rays.ZIndex = 0
	loop(r.icon, { Rotation = 7 })
	r.icon.Rotation = -7
	-- le bouton respire (après son apparition)
	task.delay(UITheme.Animation.Toast.Time + 0.1, function()
		if token ~= attentionToken or not claim.holder.Parent then
			return
		end
		local scale = claim.holder:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
		scale.Parent = claim.holder
		loop(scale, { Scale = UITheme.Animation.Scale.Hover + 0.02 })
	end)
	-- petit rebond régulier de toute la fenêtre
	task.spawn(function()
		while token == attentionToken and r.panel.Parent do
			task.wait(BOUNCE_EVERY)
			if token == attentionToken and r.panel.Parent then
				UIKit.pop(r.panel)
			end
		end
	end)
	r.attention = { tweens = tweens, rays = rays, token = token }
end

function QuestView.Show(quest: Quest, options: Options?)
	local opts: Options = options or {}
	local r = refs or build()
	refs = r
	local previous = r.quest
	local sameQuest = previous ~= nil and previous.Title == quest.Title
	r.quest = quest
	r.title.Text = quest.Title
	if previous and not sameQuest then
		UIKit.pop(r.panel) -- nouvelle quête : la fenêtre rebondit pour la présenter
	end
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
		stopAttention(r)
		r.claim.holder:Destroy()
		r.claim = nil
	end
	if completed and opts.OnClaim then
		local onClaim = opts.OnClaim
		local claim: UIKit.Button
		local pressed = false
		claim = UIKit.button(r.panel, "Récupérer", "Primary", UDim2.fromOffset(WIDTH - 2 * Spacing.M, 44 + UITheme.Shadow.ButtonLip), function()
			if pressed then
				return -- un seul clic : le bouton est désactivé tout de suite (le serveur refuse de toute façon)
			end
			pressed = true
			stopAttention(r)
			UIKit.pop(claim.holder)
			claim.setEnabled(false)
			onClaim()
		end)
		claim.holder.Position = UDim2.new(0, Spacing.M, 0, HEIGHT - Spacing.XS)
		UIKit.popIn(claim.holder, 0.1, 1.06)
		r.claim = claim
		startAttention(r, claim)
	end
end

-- Quête réclamée par le serveur (AutoClaim) : terminée à l'écran, annonce, puis after() (quête suivante).
function QuestView.Complete(title: string, target: number, after: () -> ())
	local shown = if refs then refs.quest else nil
	local announced = shown ~= nil and shown.Title == title and not shown.Completed
	QuestView.Show({ Title = title, Progress = target, Target = target, Completed = true })
	local r = refs :: Refs
	if not announced then
		UIKit.announce(r.screen, "Quête terminée !", { Color = Colors.Success, Hold = 2 })
	end
	UIKit.pop(r.panel)
	task.delay(COMPLETE_HOLD, after)
end

function QuestView.Hide()
	local r = refs
	if not r then
		return
	end
	refs = nil
	stopAttention(r)
	UIKit.close(r.panel, nil, true, function()
		r.screen:Destroy()
	end)
end

return QuestView
