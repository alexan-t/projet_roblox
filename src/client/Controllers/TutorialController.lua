--!strict
-- Guidage UI du tutoriel (voir docs/TUTORIAL_GUIDANCE.md) : flèche UI unique (GuidePointer) vers une cible
-- logique (GuideTargets), décidée à partir des données de Shared.Config.TutorialConfig.
--   • Première ouverture (FirstOpen) : quand une interface signale son ouverture (GuideTargets.opened) et
--     que son drapeau n'est pas encore vu, ses étapes passent l'une après l'autre (clic sur la cible ou
--     durée écoulée). Le drapeau est enregistré dès le début (Remotes.MarkTutorialSeen) : jamais rejoué.
--   • Étape de quête active (Quest) : le raccourci du héros à poser (ArenaStore.guide.hotbar, « Hotbar.Guide »),
--     « Lancer » dans l'Expédition (ArenaStore.guide.expedition), « Invoquer » pendant l'invocation
--     tutorielle. Rejoué à chaque réouverture TANT QUE c'est l'étape active (c'est le tuto).
--   • Rappels (Nudges) : « ouvre ce menu », seulement sans écran ouvert et hors combat.
-- Une seule flèche à la fois : TutorialRules.pick (FirstOpen > Quest > Nudge). Rien pendant un combat,
-- son outro et l'écran de fin, sauf la découverte d'une fenêtre que le joueur vient lui-même d'ouvrir.
-- Badges « ! » du menu : TutorialController.Badge(entry), TutorialController.changed.
-- Le serveur ne garde que les drapeaux (TutorialService) ; les conditions viennent de ses vues
-- (héros possédés : ArenaStore ; stages gagnés : Remotes.GetPlayerStats).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TutorialConfig = require(ReplicatedStorage.Shared.Config.TutorialConfig)
local TutorialRules = require(ReplicatedStorage.Shared.Tutorial.TutorialRules)
local ArenaStore = require(script.Parent.Parent.Arena.ArenaStore)
local GuidePointer = require(script.Parent.Parent.UI.GuidePointer)
local GuideTargets = require(script.Parent.Parent.UI.GuideTargets)
local ScreenState = require(script.Parent.Parent.UI.ScreenState)
local QuestController = require(script.Parent.QuestController)

local TutorialController = {}

-- Drapeaux vus ou conditions changés (badges du menu).
TutorialController.changed = Instance.new("BindableEvent")
-- Cible de la flèche UI (nom GuideTargets, nil : aucune) : le menu met en avant le bouton visé
-- (MenuController.SetHighlighted), sans connaître la logique du tutoriel.
TutorialController.pointing = Instance.new("BindableEvent")
local pointed: string? = nil

local function point(id: string?)
	if pointed ~= id then
		pointed = id
		TutorialController.pointing:Fire(id)
	end
end

function TutorialController.Pointed(): string?
	return pointed
end

local REFRESH = 0.1 -- s entre deux décisions
local MISSING = 1 -- s d'attente d'une cible absente avant de sauter l'étape
local SEND_GAP = 0.3 -- s entre deux envois de drapeau (le serveur limite la cadence)

local seen: { [string]: boolean } = {}
local loaded = false
local conditions: { [string]: boolean } = { HasHero = false, SecondHero = false, FirstVictory = false, QuestClaimable = false }
local markRemote: RemoteEvent? = nil
local outbox: { string } = {}
local sending = false

type Sequence = { key: string, steps: { TutorialConfig.Step }, index: number, started: number, hud: boolean }
local sequence: Sequence? = nil
local pendingOpen: { [string]: boolean } = {} -- ouvertes avant le chargement des drapeaux

------------------------------------------------------------------ drapeaux

local function flush()
	if sending then
		return
	end
	sending = true
	task.spawn(function()
		while #outbox > 0 do
			local key = table.remove(outbox, 1)
			local remote = markRemote
			if remote and key then
				remote:FireServer(key)
			end
			task.wait(SEND_GAP)
		end
		sending = false
	end)
end

local function mark(key: string)
	if seen[key] then
		return
	end
	seen[key] = true
	table.insert(outbox, key)
	flush()
	TutorialController.changed:Fire()
end

function TutorialController.Seen(key: string): boolean
	return seen[key] == true
end

function TutorialController.Badge(entry: TutorialConfig.Entry): boolean
	return loaded and TutorialRules.badge(entry, seen, conditions)
end

------------------------------------------------------------------ première ouverture

local function startSequence(key: string)
	if not loaded then
		pendingOpen[key] = true
		return
	end
	if sequence then
		return -- une découverte à la fois ; l'autre interface sera découverte à sa prochaine ouverture
	end
	local steps = TutorialRules.firstOpen(TutorialConfig, seen, key)
	mark(key) -- vu dès maintenant : fermer puis rouvrir ne relance rien
	if not steps then
		return
	end
	local entry = TutorialConfig.FirstOpen[key]
	sequence = { key = key, steps = steps, index = 1, started = os.clock(), hud = entry ~= nil and entry.Hud == true }
end

local function nextStep()
	local current = sequence
	if not current then
		return
	end
	current.index += 1
	current.started = os.clock() + TutorialConfig.StepGap
	if current.index > #current.steps then
		sequence = nil
	end
	GuidePointer.hide()
end

------------------------------------------------------------------ décision

local function blocked(): boolean
	return ArenaStore.inCombat() or ArenaStore.awaitingResult
end

local function candidates(): { TutorialRules.Candidate }
	local list: { TutorialRules.Candidate } = {}
	local current = sequence
	if current then
		local step = current.steps[current.index]
		local waiting = current.hud and not ScreenState.free()
		if step and os.clock() >= current.started and not waiting then
			table.insert(list, { Source = "FirstOpen", Target = step.Target, Text = step.Text or GuideTargets.hint(step.Target) })
		end
	end
	if not blocked() then
		local guide = ArenaStore.guide
		if guide.hotbar and ScreenState.free() then
			table.insert(list, { Source = "Quest", Target = "Hotbar.Guide", Text = "Prends ton héros" })
		end
		if guide.expedition and GuideTargets.isOpen("Expedition") then
			table.insert(list, { Source = "Quest", Target = "Expedition.Launch", Text = "Lance le combat" })
		end
		if ScreenState.free() then
			for _, nudge in TutorialRules.nudges(TutorialConfig, seen, conditions) do
				table.insert(list, nudge)
			end
		end
	end
	-- invocation tutorielle (gratuite) : « Invoquer » tant qu'elle n'est pas faite, même rouverte
	if GuideTargets.isOpen("Summon") then
		table.insert(list, { Source = "Quest", Target = "Summon.Invoke", Text = "Invoque !" })
	end
	-- panneau Quêtes ouvert avec une récompense qui attend : « Récupérer » (cible absente sinon)
	if GuideTargets.isOpen("Quests") then
		table.insert(list, { Source = "Quest", Target = "Quests.Claim", Text = "Récupère !" })
	end
	return list
end

local function update()
	local current = sequence
	if current then
		local step = current.steps[current.index]
		local now = os.clock()
		if not GuideTargets.isOpen(current.key) and not current.hud then
			sequence = nil -- interface fermée : la découverte s'arrête (déjà marquée vue)
		elseif step and now >= current.started then
			local elapsed = now - current.started
			local target = GuideTargets.get(step.Target)
			if (not target and elapsed > MISSING) or elapsed > (step.Seconds or TutorialConfig.StepSeconds) then
				if not (current.hud and not ScreenState.free()) then
					nextStep()
				end
			end
		end
	end
	local chosen = TutorialRules.pick(candidates(), function(id: string): boolean
		return GuideTargets.get(id) ~= nil
	end)
	if not chosen then
		GuidePointer.hide()
		point(nil)
		return
	end
	local target = GuideTargets.get(chosen.Target)
	if not target then
		GuidePointer.hide()
		point(nil)
		return
	end
	point(chosen.Target)
	local fromSequence = chosen.Source == "FirstOpen"
	GuidePointer.show(target, {
		Text = chosen.Text,
		OnActivated = if fromSequence then nextStep else nil,
	})
end

------------------------------------------------------------------ conditions

local statsRemote: RemoteFunction? = nil

local function refreshHeroes()
	local count = 0
	for _ in ArenaStore.heroes do
		count += 1
	end
	local hasHero, second = count >= 1, count >= 2
	if hasHero ~= conditions.HasHero or second ~= conditions.SecondHero then
		conditions.HasHero, conditions.SecondHero = hasHero, second
		TutorialController.changed:Fire()
	end
end

local function refreshVictory()
	local remote = statsRemote
	if not remote or conditions.FirstVictory then
		return
	end
	task.spawn(function()
		local ok, stats = pcall(remote.InvokeServer, remote)
		if ok and typeof(stats) == "table" and typeof(stats.StagesCleared) == "number" and stats.StagesCleared >= 1 then
			conditions.FirstVictory = true
			TutorialController.changed:Fire()
		end
	end)
end

------------------------------------------------------------------ démarrage

function TutorialController:Start()
	GuideTargets.opened.Event:Connect(startSequence)
	-- récompense de quête à récupérer (vue du serveur, QuestController) : condition du rappel « Quêtes »
	local function questClaimable()
		local on = QuestController.Claimable()
		if on ~= conditions.QuestClaimable then
			conditions.QuestClaimable = on
			TutorialController.changed:Fire()
		end
	end
	QuestController.attention.Event:Connect(questClaimable)
	questClaimable()
	GuideTargets.closed.Event:Connect(function(key: string)
		pendingOpen[key] = nil
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= REFRESH then
			elapsed = 0
			update()
		end
	end)
	local wasCombat = false
	ArenaStore.changed.Event:Connect(function()
		refreshHeroes()
		local combat = ArenaStore.inCombat()
		if wasCombat and not combat then
			refreshVictory() -- un combat vient de finir : peut-être la première victoire
		end
		wasCombat = combat
	end)

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local markEvent = remotes:WaitForChild("MarkTutorialSeen", 30)
	if markEvent and markEvent:IsA("RemoteEvent") then
		markRemote = markEvent
	end
	local stats = remotes:WaitForChild("GetPlayerStats", 30)
	if stats and stats:IsA("RemoteFunction") then
		statsRemote = stats
	end
	local get = remotes:WaitForChild("GetTutorialSeen", 30)
	if not get or not get:IsA("RemoteFunction") then
		return
	end
	-- Les données peuvent arriver après le client : on relit jusqu'à les avoir.
	while not loaded do
		local ok, view = pcall(get.InvokeServer, get)
		if ok and typeof(view) == "table" then
			for key, value in view do
				if value == true and typeof(key) == "string" then
					seen[key] = true
				end
			end
			loaded = true
		else
			task.wait(1)
		end
	end
	refreshHeroes()
	refreshVictory()
	TutorialController.changed:Fire()
	for key in pendingOpen do
		if GuideTargets.isOpen(key) then
			startSequence(key)
		end
	end
	table.clear(pendingOpen)
end

return TutorialController
