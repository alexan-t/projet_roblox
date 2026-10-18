--!strict
-- Quêtes côté client — état du serveur uniquement (QuestService), voir docs/QUESTS.md.
--   • Suivi (HUD, QuestView) : au join, Remotes.GetActiveQuest → QuestView.Show ; Remotes.QuestChanged
--     (vue, terminée?) → mis à jour. Pendant un combat, son outro, l'écran de fin ou l'invocation, la mise
--     à jour attend que l'écran soit libre (l'annonce « Quête terminée ! » ne se perd pas derrière) ;
--   • quête réclamée automatiquement par le serveur (AutoClaim, tutoriel) : « terminée » arrive avec la
--     vue suivante → QuestView.Complete (annonce), puis la suivante, sans bouton ;
--   • panneau Quêtes (QuestPanelView, bouton Quêtes du menu ou « Récupérer » du suivi) : Remotes.GetQuestLog
--     (quêtes réclamées + active), relu à chaque changement. C'est la SEULE interface qui réclame :
--     « Récupérer » envoie Remotes.ClaimQuest(questId) — uniquement l'Id ; le serveur revérifie tout et
--     ajoute les récompenses de QuestConfig. Celles qu'il renvoie sont révélées (QuestRewardView : monnaies
--     du pack, monnaies 3D qui volent vers le HUD), puis le HUD des monnaies relit le serveur. Un ticket
--     gagné montre ensuite le portail. VFX ≠ économie : rien n'est ajouté par le client ;
--   • notification du bouton Quêtes (QuestController.attention) : récompense à récupérer (priorité absolue)
--     ou nouvelle quête activée pas encore vue dans le panneau (Shared.Quests.QuestLog.attention).
-- API : QuestController.OpenPanel() ; QuestController.attention (BindableEvent, on: boolean) ;
--   QuestController.HasAttention() ; QuestController.Claimable().

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QuestLog = require(ReplicatedStorage.Shared.Quests.QuestLog)
local ArenaStore = require(script.Parent.Parent.Arena.ArenaStore)
local ScreenState = require(script.Parent.Parent.UI.ScreenState)
local QuestPanelView = require(script.Parent.Parent.UI.Views.QuestPanelView)
local QuestView = require(script.Parent.Parent.UI.Views.QuestView)
local QuestRewardView = require(script.Parent.Parent.UI.Views.QuestRewardView)
local AudioController = require(script.Parent.AudioController)
local CurrencyController = require(script.Parent.CurrencyController)
local SummonController = require(script.Parent.SummonController)

local QuestController = {}

-- Bouton Quêtes : faut-il appeler le joueur ? (MenuController.SetAttention("Quest", on))
QuestController.attention = Instance.new("BindableEvent")

local PANEL = "Quests"
-- Écrans derrière lesquels une annonce de quête se perdrait : elle attend leur fermeture.
local HOLD_SCREENS = { Reward = true, Summon = true, QuestReward = true }

local claimRemote: RemoteFunction? = nil
local logRemote: RemoteFunction? = nil
local claiming = false -- « Récupérer » cliqué : réponse du serveur puis reveal ; la quête suivante attend
local animating = false -- QuestView.Complete en cours : les mises à jour suivantes attendent
-- Mises à jour reçues pendant un écran / un combat : la dernière vue, et les quêtes terminées entre-temps.
local pending: { view: any, finished: { any } }? = nil
local active: any = nil -- dernière vue de la quête active reçue du serveur (nil : aucune)
local seenId: string? = nil -- dernière quête active vue (join, ou panneau ouvert)
local attentionOn = false

------------------------------------------------------------------ notification

local lastClaimable = false
local function refreshAttention()
	local on = QuestLog.attention(active, seenId)
	local claimable = QuestController.Claimable()
	if on ~= attentionOn or claimable ~= lastClaimable then
		attentionOn, lastClaimable = on, claimable
		QuestController.attention:Fire(on)
	end
end

function QuestController.HasAttention(): boolean
	return attentionOn
end

-- Une quête attend « Récupérer », dans n'importe quelle ligne (vue du serveur).
function QuestController.Claimable(): boolean
	return active ~= nil and (QuestLog.state(active) == "Claimable" or (active.ClaimableCount or 0) > 0)
end

local function receiveActive(view: any)
	active = if typeof(view) == "table" then view else nil
	if seenId == nil and active then
		seenId = active.Id -- la quête du join compte comme vue (pas de notification au démarrage)
	end
	if QuestPanelView.IsOpen() and active then
		seenId = active.Id -- vue en direct dans le panneau
	end
	refreshAttention()
end

------------------------------------------------------------------ panneau

local function fetchLog(): any
	local remote = logRemote
	if not remote then
		return nil
	end
	local ok, log = pcall(remote.InvokeServer, remote)
	return if ok and typeof(log) == "table" and typeof(log.Quests) == "table" then log else nil
end

-- Révèle des récompenses déjà ajoutées par le serveur, puis le HUD se met à jour ; after() une fois
-- les monnaies arrivées. owned : le panneau Quêtes tient déjà l'écran (pas de ScreenState à ouvrir).
local function reveal(list: { any }, owned: boolean, after: (() -> ())?)
	local ticket = false
	for _, reward in list do
		if reward.Kind == "SummonTicket" then
			ticket = true
		end
	end
	local function finish()
		CurrencyController.Refresh(true)
		if after then
			after()
		end
		if ticket then
			SummonController.HintPortal() -- la suite naturelle : invoquer avec ce ticket
		end
	end
	if #list > 0 and (owned or ScreenState.open("QuestReward")) then
		QuestRewardView.Play(list, function()
			if not owned then
				ScreenState.close("QuestReward")
			end
			finish()
		end, function(name: string)
			AudioController.Play(name)
		end)
	else
		finish()
	end
end

local flush: () -> ()

local function claim(questId: string)
	local remote = claimRemote
	if claiming or not remote then
		return
	end
	claiming = true
	QuestPanelView.SetClaiming(questId, fetchLog())
	-- le client n'envoie QUE l'Id : progression, récompenses et état sont revérifiés par le serveur
	local ok, accepted, reason, rewards = pcall(remote.InvokeServer, remote, questId)
	if not ok or accepted ~= true then
		claiming = false
		ArenaStore.toast:Fire(if ok and typeof(reason) == "string" then reason else "Réclamation impossible, réessaie")
		QuestPanelView.SetClaiming(nil, fetchLog())
		flush()
		return
	end
	-- Succès : le serveur a déjà ajouté les récompenses ; le panneau montre « ✓ Récupéré » et la suite.
	QuestPanelView.SetClaiming(nil, fetchLog())
	reveal(if typeof(rewards) == "table" then rewards else {}, QuestPanelView.IsOpen(), function()
		claiming = false
		QuestPanelView.Update(fetchLog() or { Quests = {} })
		flush()
	end)
end

local function closePanel()
	ScreenState.close(PANEL)
end

-- Ouvre le panneau Quêtes (bouton du menu, « Récupérer » du suivi). Un seul écran modal à la fois.
function QuestController.OpenPanel()
	if QuestPanelView.IsOpen() or ArenaStore.awaitingResult or not ScreenState.open(PANEL) then
		return
	end
	local log = fetchLog()
	if not log then
		ScreenState.close(PANEL)
		ArenaStore.toast:Fire("Quêtes indisponibles, réessaie")
		return
	end
	if active then
		seenId = active.Id
	end
	refreshAttention()
	QuestPanelView.Show(log, { OnClaim = claim, OnClose = closePanel })
end

------------------------------------------------------------------ suivi (HUD)

local function show(view: any)
	if typeof(view) ~= "table" then
		QuestView.Hide()
		return
	end
	QuestView.Show(view, {
		-- quête AutoClaim : jamais de bouton ; sinon « Récupérer » ouvre le panneau (réclamation unique)
		OnClaim = if view.AutoClaim == true then nil else QuestController.OpenPanel,
	})
end

local function blocked(): boolean
	local screen = ScreenState.current()
	return animating or claiming or ArenaStore.inCombat() or ArenaStore.awaitingResult or (screen ~= nil and HOLD_SCREENS[screen] == true)
end

-- Quêtes terminées d'abord (une annonce chacune), puis la vue courante.
local function apply(view: any, finished: { any })
	local done = table.remove(finished, 1)
	if typeof(done) ~= "table" then
		show(view)
		return
	end
	animating = true
	QuestView.Complete(tostring(done.Title), if typeof(done.Target) == "number" then done.Target else 1, function()
		animating = false
		if typeof(done.Rewards) == "table" and #done.Rewards > 0 then
			reveal(done.Rewards, false)
		end
		local waiting = pending
		if waiting then
			-- une mise à jour plus récente est arrivée pendant l'annonce : elle passe en dernier
			for _, item in finished do
				table.insert(waiting.finished, item)
			end
			flush()
		else
			apply(view, finished)
		end
	end)
end

function flush()
	local waiting = pending
	if waiting and not blocked() then
		pending = nil
		apply(waiting.view, waiting.finished)
	end
end

local function receive(view: any, finished: any)
	receiveActive(view)
	local waiting = pending or { view = nil, finished = {} }
	waiting.view = view
	if typeof(finished) == "table" then
		table.insert(waiting.finished, finished)
	end
	pending = waiting
	-- panneau ouvert : il suit la progression en direct (hors réclamation en cours)
	if QuestPanelView.IsOpen() and not claiming then
		QuestPanelView.Update(fetchLog() or { Quests = {} })
	end
	flush()
end

function QuestController:Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local get = remotes:WaitForChild("GetActiveQuest", 30)
	local claimFn = remotes:WaitForChild("ClaimQuest", 30)
	local log = remotes:WaitForChild("GetQuestLog", 30)
	local changed = remotes:WaitForChild("QuestChanged", 30)
	if claimFn and claimFn:IsA("RemoteFunction") then
		claimRemote = claimFn
	end
	if log and log:IsA("RemoteFunction") then
		logRemote = log
	end
	if changed and changed:IsA("RemoteEvent") then
		changed.OnClientEvent:Connect(receive)
	end
	ScreenState.changed.Event:Connect(flush)
	ArenaStore.changed.Event:Connect(flush)
	if get and get:IsA("RemoteFunction") then
		local ok, view = pcall(get.InvokeServer, get)
		-- nil au join peut seulement vouloir dire « données pas encore chargées » : QuestChanged suivra.
		if ok and typeof(view) == "table" and pending == nil then
			receive(view, nil)
		end
	end
end

return QuestController
