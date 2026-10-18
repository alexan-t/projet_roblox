--!strict
-- Menu principal (MenuView, icônes PNG de Shared.Config.MenuIconConfig) — voir docs/TUTORIAL_GUIDANCE.md.
-- Les entrées viennent de TutorialConfig.Menu.Entries ; chaque View est branchée sur ce qui existe :
--   Bag   : ouvre LA Sacoche (HeroBarController.SetBag), centrée : le menu se masque tant qu'elle est
--           ouverte et revient à sa fermeture ; « ! » quand un héros nouveau n'a pas encore été vu ;
--   Index : catalogue des héros (CollectionView, la vue « collection » du jeu) : héros possédés avec leur
--           vrai modèle et leur nombre, les autres « ??? » avec un cadenas (aucun spoil) ;
--   Stats : statistiques du joueur (InfoView), valeurs du serveur (Remotes.GetPlayerStats) ;
--   Quests: panneau Quêtes (QuestController.OpenPanel, QuestPanelView) ;
--   Soon  : fenêtre « Bientôt disponible » (Boutique, Guilde), sans faux contenu.
-- Un seul écran modal à la fois (ScreenState "Menu" / "Quests"). Le menu reste visible sous le voile de
-- ses propres fenêtres (bouton sélectionné, comme la maquette) et se cache pendant tout autre écran modal
-- (Expédition, invocation, récompenses...) ; il se place dans la bande libre entre le suivi de quête et
-- la hotbar (plus haut sur écran tactile : le joystick occupe le bas à gauche).
-- API de présentation (aucune logique de quête ici) :
--   MenuController.SetAttention(id, on)   -- « ! » du pack au coin du bouton (ex. quelque chose de nouveau)
--   MenuController.SetHighlighted(id, on) -- halo doré qui respire (ex. étape du tutoriel)
--   MenuController.GetButton(id) -> GuiObject? -- pour une flèche UI externe (aussi cible « Menu.<Id> »)
-- Les systèmes s'y branchent sans y mettre leur logique : « ! » de TutorialController.Badge (drapeaux non
-- vus) et de QuestController.attention (récompense à récupérer, nouvelle quête) ; halo sur le bouton visé
-- par la flèche UI (TutorialController.pointing).
-- Aperçu Studio (comme UIPreviewController) : attribut Workspace.ApercuMenu, ex. "Bag=attention,Index=halo"
-- (vide : tout revient à l'état normal). Studio uniquement.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local HeroConfig = require(ReplicatedStorage.Shared.Config.HeroConfig)
local MenuIconConfig = require(ReplicatedStorage.Shared.Config.MenuIconConfig)
local TutorialConfig = require(ReplicatedStorage.Shared.Config.TutorialConfig)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local ArenaStore = require(script.Parent.Parent.Arena.ArenaStore)
local GuideTargets = require(script.Parent.Parent.UI.GuideTargets)
local Icons = require(script.Parent.Parent.UI.Icons)
local ScreenState = require(script.Parent.Parent.UI.ScreenState)
local CollectionView = require(script.Parent.Parent.UI.Views.CollectionView)
local InfoView = require(script.Parent.Parent.UI.Views.InfoView)
local MenuView = require(script.Parent.Parent.UI.Views.MenuView)
local HeroBarController = require(script.Parent.HeroBarController)
local QuestController = require(script.Parent.QuestController)
local TutorialController = require(script.Parent.TutorialController)

local MenuController = {}

local SCREEN = "Menu"
local QUESTS = "Quests" -- écran du panneau Quêtes (QuestController)
local LAYOUT_EVERY = 0.5 -- s entre deux recalculs de la place libre (chat, quête terminée, écran redimensionné)
local DEFAULT_TOP = 150 -- px : haut du menu sans suivi de quête (sous la place de la quête)
local TOUCH_LIMIT = 0.62 -- écran tactile : le menu reste au-dessus de 62 % de la hauteur (joystick dessous)

local entries: { [string]: TutorialConfig.Entry } = {}
local openId: string? = nil -- entrée dont la fenêtre modale est ouverte
local statsRemote: RemoteFunction? = nil
-- Demandes externes (API) et du tutoriel, gardées séparément : l'une n'efface jamais l'autre.
local attention: { [string]: boolean } = {}
local highlighted: { [string]: boolean } = {}
local tutorialPointed: string? = nil
local questAttention = false -- QuestController.attention (bouton Quêtes)

------------------------------------------------------------------ états visuels

local function refreshSelected()
	local quests = ScreenState.current() == QUESTS
	MenuView.SetSelected(openId or (if quests then "Quest" elseif HeroBarController.IsBagOpen() then "Bag" else nil))
end

local function refreshAttention()
	for id, entry in entries do
		local quest = entry.View == "Quests" and questAttention
		local fresh = entry.View == "Bag" and HeroBarController.HasNew()
		MenuView.SetAttention(id, attention[id] == true or quest or fresh or TutorialController.Badge(entry))
	end
end

local function refreshHighlight()
	for id in entries do
		MenuView.SetHighlighted(id, highlighted[id] == true or tutorialPointed == `Menu.{id}`)
	end
end

function MenuController.SetAttention(id: string, on: boolean)
	if entries[id] == nil and MenuIconConfig.Buttons[id] == nil then
		return
	end
	attention[id] = if on then true else nil
	refreshAttention()
end

function MenuController.SetHighlighted(id: string, on: boolean)
	if entries[id] == nil then
		return
	end
	highlighted[id] = if on then true else nil
	refreshHighlight()
end

function MenuController.GetButton(id: string): GuiObject?
	return GuideTargets.get(`Menu.{id}`)
end

------------------------------------------------------------------ fenêtres

local function closed()
	openId = nil
	ScreenState.close(SCREEN)
	refreshSelected()
end

-- Ouvre l'écran modal du menu pour `id` ; false si un autre écran est déjà ouvert.
local function claim(id: string): boolean
	if ArenaStore.awaitingResult or not ScreenState.open(SCREEN) then
		return false
	end
	HeroBarController.SetBag(false)
	openId = id
	refreshSelected()
	return true
end

local function imageOf(id: string): string
	local config = MenuIconConfig.Buttons[id]
	return if config then config.Icon else ""
end

local function showIndex(entry: TutorialConfig.Entry)
	if not claim(entry.Id) then
		return
	end
	local owned: { [string]: number } = {}
	for _, hero in ArenaStore.heroes do
		owned[hero.HeroId] = (owned[hero.HeroId] or 0) + 1
	end
	local catalog: { { id: string, info: HeroConfig.HeroInfo } } = {}
	for heroId, info in HeroConfig.Heroes do
		table.insert(catalog, { id = heroId, info = info })
	end
	-- découverts d'abord (ordre du catalogue), puis les autres
	table.sort(catalog, function(a, b)
		local oa, ob = owned[a.id] ~= nil, owned[b.id] ~= nil
		if oa ~= ob then
			return oa
		end
		return a.info.Order < b.info.Order
	end)
	local list: { CollectionView.HeroEntry } = {}
	local found = 0
	for _, item in catalog do
		local count = owned[item.id]
		if count then
			found += 1
		end
		table.insert(list, {
			Name = item.info.Name,
			Model = if count then Icons.heroModel(item.id) else nil,
			Count = count,
			Locked = count == nil,
		})
	end
	CollectionView.Show(list, {
		Title = "Index des héros",
		Header = `{found} / {#catalog} découverts`,
		Guide = entry.Flag,
		OnClose = closed,
	})
end

local function showStats(entry: TutorialConfig.Entry)
	local remote = statsRemote
	if not remote or not claim(entry.Id) then
		return
	end
	local ok, stats = pcall(remote.InvokeServer, remote)
	if openId ~= entry.Id then
		return -- fermé entre-temps
	end
	if not ok or typeof(stats) ~= "table" then
		closed()
		ArenaStore.toast:Fire("Statistiques indisponibles, réessaie")
		return
	end
	InfoView.Show({
		Title = "Statistiques",
		Image = imageOf(entry.Id),
		Rows = {
			{ Label = "Héros possédés", Value = tostring(stats.Heroes) },
			{ Label = "Héros différents", Value = tostring(stats.UniqueHeroes) },
			{ Label = "Meilleur niveau", Value = `Nv. {stats.HighestLevel}` },
			{ Label = "Stages gagnés", Value = tostring(stats.StagesCleared) },
			{ Label = "Stages Élite gagnés", Value = tostring(stats.EliteCleared) },
			{ Label = "Invocations", Value = tostring(stats.Summons) },
			{ Label = "Niveau du royaume", Value = tostring(stats.KingdomLevel) },
		},
	}, { Guide = entry.Flag, OnClose = closed })
end

local function showSoon(entry: TutorialConfig.Entry)
	if not claim(entry.Id) then
		return
	end
	InfoView.Show({ Title = entry.Label, Image = imageOf(entry.Id), Message = entry.Soon }, { OnClose = closed })
end

local function select(id: string)
	local entry = entries[id]
	if not entry then
		return
	end
	if entry.View == "Bag" then
		if ScreenState.free() then
			HeroBarController.SetBag(not HeroBarController.IsBagOpen())
		end
	elseif entry.View == "Index" then
		showIndex(entry)
	elseif entry.View == "Stats" then
		task.spawn(showStats, entry)
	elseif entry.View == "Quests" then
		HeroBarController.SetBag(false)
		task.spawn(QuestController.OpenPanel)
	else
		showSoon(entry)
	end
end

------------------------------------------------------------------ placement et visibilité

-- Bande libre (px, sous la barre de Roblox) : sous le suivi de quête ET sous la fenêtre de chat de Roblox
-- (CoreGui, en haut à gauche : elle capte les clics, un bouton dessous ne répondrait pas), au-dessus de
-- la hotbar ; sur écran tactile, au-dessus de la zone du joystick.
local function chatBottom(): number
	local bottom = 0
	for _, config: any in { TextChatService:FindFirstChildOfClass("ChatWindowConfiguration"), TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration") } do
		if config and config.Enabled and config.AbsoluteSize.X > 0 then
			bottom = math.max(bottom, config.AbsolutePosition.Y + config.AbsoluteSize.Y)
		end
	end
	return bottom
end

local function layout()
	local camera = Workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else 1080
	local s = math.clamp(height / 1080, 0.7, 1.25)
	local gap = UITheme.Spacing.M * s
	local quest = GuideTargets.get("Quest.Panel")
	local top = if quest then quest.AbsolutePosition.Y + quest.AbsoluteSize.Y + gap else DEFAULT_TOP * s
	local chat = chatBottom()
	if chat > 0 then
		top = math.max(top, chat + gap)
	end
	local bar = GuideTargets.get("Hotbar.Bar")
	local bottom = if bar then bar.AbsolutePosition.Y - gap else height - gap
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		bottom = math.min(bottom, height * TOUCH_LIMIT)
	end
	MenuView.Fit(top, bottom)
end

local function refreshVisible()
	local current = ScreenState.current()
	-- caché pendant les autres écrans modaux et pendant la Sacoche (elle devient la priorité visuelle) ;
	-- visible (sous le voile) pendant ses propres fenêtres
	MenuView.SetVisible((current == nil and not HeroBarController.IsBagOpen()) or current == SCREEN or current == QUESTS)
	refreshSelected()
end

-- Aperçu Studio : l'attribut remplace les demandes externes (attention / halo) par celles qu'il liste.
local PREVIEW = "ApercuMenu"
local function preview()
	local value = Workspace:GetAttribute(PREVIEW)
	table.clear(attention)
	table.clear(highlighted)
	if typeof(value) == "string" then
		for id, state in value:gmatch("(%a+)=(%a+)") do
			if state == "attention" then
				attention[id] = true
			elseif state == "halo" then
				highlighted[id] = true
			end
		end
	end
	refreshAttention()
	refreshHighlight()
end

function MenuController:Start()
	local list: { MenuView.Entry } = {}
	for _, entry in TutorialConfig.Menu.Entries do
		entries[entry.Id] = entry
		table.insert(list, { Id = entry.Id, Label = entry.Label })
	end
	MenuView.Build(list, select)
	HeroBarController.bagChanged.Event:Connect(refreshVisible)
	HeroBarController.newChanged.Event:Connect(refreshAttention)
	TutorialController.changed.Event:Connect(refreshAttention)
	TutorialController.pointing.Event:Connect(function(target: string?)
		tutorialPointed = target
		refreshHighlight()
	end)
	ScreenState.changed.Event:Connect(refreshVisible)
	QuestController.attention.Event:Connect(function(on: boolean)
		questAttention = on
		refreshAttention()
	end)
	questAttention = QuestController.HasAttention()
	if RunService:IsStudio() then
		Workspace:GetAttributeChangedSignal(PREVIEW):Connect(preview)
	end
	refreshAttention()
	refreshVisible()
	layout()
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= LAYOUT_EVERY then
			elapsed = 0
			layout()
		end
	end)
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local stats = remotes:WaitForChild("GetPlayerStats", 30)
	if stats and stats:IsA("RemoteFunction") then
		statsRemote = stats
	end
end

return MenuController
