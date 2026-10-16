--!strict
-- Suivi de la quête active (HUD) — QuestView, état du serveur uniquement (QuestService).
--   • au join : Remotes.GetActiveQuest → QuestView.Show ;
--   • Remotes.QuestChanged (vue, terminée?) (activation, progression, réclamation) → QuestView mis à
--     jour. Pendant un combat, son outro, l'écran de fin ou l'invocation, la mise à jour attend que
--     l'écran soit libre (l'annonce « Quête terminée ! » ne se perd pas derrière) ;
--   • quête réclamée automatiquement par le serveur (AutoClaim, tutoriel) : « terminée » arrive avec la
--     vue suivante → QuestView.Complete (quête terminée, annonce), puis la suivante, sans bouton ;
--   • « Récupérer » (quêtes sans AutoClaim) : Remotes.ClaimQuest(questId), le serveur revérifie tout et
--     ajoute les récompenses de la quête (QuestConfig.Rewards) ; celles qu'il renvoie sont révélées
--     (QuestRewardView : « QUÊTE ACCOMPLIE ! », cartes qui éclatent, vol vers le HUD), puis le HUD des
--     monnaies relit le serveur. Un ticket gagné montre ensuite le portail. La quête suivante (déjà
--     envoyée par le serveur) n'apparaît qu'une fois le reveal fermé. Plus de quête (vue nil) :
--     QuestView.Hide().

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaStore = require(script.Parent.Parent.Arena.ArenaStore)
local ScreenState = require(script.Parent.Parent.UI.ScreenState)
local QuestView = require(script.Parent.Parent.UI.Views.QuestView)
local QuestRewardView = require(script.Parent.Parent.UI.Views.QuestRewardView)
local AudioController = require(script.Parent.AudioController)
local CurrencyController = require(script.Parent.CurrencyController)
local SummonController = require(script.Parent.SummonController)

local QuestController = {}

-- Écrans derrière lesquels une annonce de quête se perdrait : elle attend leur fermeture.
local HOLD_SCREENS = { Reward = true, Summon = true, QuestReward = true }

local claimRemote: RemoteFunction? = nil
local claiming = false -- « Récupérer » cliqué : réponse du serveur puis reveal ; la quête suivante attend
local animating = false -- QuestView.Complete en cours : les mises à jour suivantes attendent
-- Mises à jour reçues pendant un écran / un combat : la dernière vue, et les quêtes terminées entre-temps.
local pending: { view: any, finished: { any } }? = nil

-- Révèle des récompenses déjà ajoutées par le serveur, puis le HUD se met à jour ; after() une fois
-- le reveal fermé (cartes arrivées dans le HUD).
local function reveal(list: { any }, after: (() -> ())?)
	local ticket = false
	for _, reward in list do
		if reward.Kind == "SummonTicket" then
			ticket = true
		end
	end
	if #list > 0 and ScreenState.open("QuestReward") then
		QuestRewardView.Play(list, function()
			CurrencyController.Refresh(true)
			if after then
				after()
			end
			ScreenState.close("QuestReward")
			if ticket then
				SummonController.HintPortal() -- la suite naturelle : invoquer avec ce ticket
			end
		end, function(name: string)
			AudioController.Play(name)
		end)
	else
		CurrencyController.Refresh(true)
		if after then
			after()
		end
	end
end

local flush: () -> ()

local function show(view: any)
	if typeof(view) ~= "table" then
		QuestView.Hide()
		return
	end
	local questId = view.Id
	QuestView.Show(view, {
		-- quête AutoClaim : jamais de bouton, le serveur la réclame dès qu'elle est terminée
		OnClaim = if view.AutoClaim == true then nil else function()
			local remote = claimRemote
			if claiming or not remote then
				return
			end
			claiming = true
			local ok, accepted, reason, rewards = pcall(remote.InvokeServer, remote, questId)
			if not ok or accepted ~= true then
				claiming = false
				ArenaStore.toast:Fire(if ok and typeof(reason) == "string" then reason else "Réclamation impossible, réessaie")
				show(view) -- bouton de nouveau disponible
				flush()
				return
			end
			-- Succès : la quête suivante (QuestChanged, déjà reçue) attend la fin du reveal.
			reveal(if typeof(rewards) == "table" then rewards else {}, function()
				claiming = false
				flush()
			end)
		end,
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
			reveal(done.Rewards)
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
	local waiting = pending or { view = nil, finished = {} }
	waiting.view = view
	if typeof(finished) == "table" then
		table.insert(waiting.finished, finished)
	end
	pending = waiting
	flush()
end

function QuestController:Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local get = remotes:WaitForChild("GetActiveQuest", 30)
	local claim = remotes:WaitForChild("ClaimQuest", 30)
	local changed = remotes:WaitForChild("QuestChanged", 30)
	if claim and claim:IsA("RemoteFunction") then
		claimRemote = claim
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
