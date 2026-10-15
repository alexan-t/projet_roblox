--!strict
-- Suivi de la quête active (HUD) — QuestView, état du serveur uniquement (QuestService).
--   • au join : Remotes.GetActiveQuest → QuestView.Show ;
--   • Remotes.QuestChanged (activation, progression, réclamation) → QuestView mis à jour ;
--     pendant l'écran de fin de combat, la mise à jour attend « Continuer » (l'annonce « Quête
--     terminée ! » ne se perd pas derrière l'écran) ;
--   • « Récupérer » : Remotes.ClaimQuest(questId), le serveur revérifie tout et ajoute les récompenses de
--     la quête (QuestConfig.Rewards) ; celles qu'il renvoie sont révélées (QuestRewardView : « QUÊTE
--     ACCOMPLIE ! », cartes qui éclatent, vol vers le HUD), puis le HUD des monnaies relit le serveur.
--     Un ticket gagné montre ensuite le portail. Plus de quête (vue nil) : QuestView.Hide().

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaStore = require(script.Parent.Parent.Arena.ArenaStore)
local ScreenState = require(script.Parent.Parent.UI.ScreenState)
local QuestView = require(script.Parent.Parent.UI.Views.QuestView)
local QuestRewardView = require(script.Parent.Parent.UI.Views.QuestRewardView)
local AudioController = require(script.Parent.AudioController)
local CurrencyController = require(script.Parent.CurrencyController)
local SummonController = require(script.Parent.SummonController)

local QuestController = {}

local claimRemote: RemoteFunction? = nil
local claiming = false
local pending: { view: any }? = nil -- mise à jour reçue pendant l'écran de fin

local function apply(view: any)
	if typeof(view) ~= "table" then
		QuestView.Hide()
		return
	end
	local questId = view.Id
	QuestView.Show(view, {
		OnClaim = function()
			local remote = claimRemote
			if claiming or not remote then
				return
			end
			claiming = true
			local ok, accepted, reason, rewards = pcall(remote.InvokeServer, remote, questId)
			claiming = false
			if not ok or accepted ~= true then
				ArenaStore.toast:Fire(if ok and typeof(reason) == "string" then reason else "Réclamation impossible, réessaie")
				return
			end
			-- Récompenses déjà ajoutées par le serveur : on les révèle, puis le HUD se met à jour.
			local list = if typeof(rewards) == "table" then rewards else {}
			local ticket = false
			for _, reward in list do
				if reward.Kind == "SummonTicket" then
					ticket = true
				end
			end
			if #list > 0 and ScreenState.open("QuestReward") then
				QuestRewardView.Play(list, function()
					ScreenState.close("QuestReward")
					CurrencyController.Refresh(true)
					if ticket then
						SummonController.HintPortal() -- la suite naturelle : invoquer avec ce ticket
					end
				end, function(name: string)
					AudioController.Play(name)
				end)
			else
				CurrencyController.Refresh(true)
			end
			-- Succès : QuestChanged apporte la quête suivante (ou nil : la vue se ferme).
		end,
	})
end

local function receive(view: any)
	if ScreenState.current() == "Reward" then
		pending = { view = view }
	else
		apply(view)
	end
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
	ScreenState.changed.Event:Connect(function(current: string?)
		local waiting = pending
		if waiting and current ~= "Reward" then
			pending = nil
			apply(waiting.view)
		end
	end)
	if get and get:IsA("RemoteFunction") then
		local ok, view = pcall(get.InvokeServer, get)
		-- nil au join peut seulement vouloir dire « données pas encore chargées » : QuestChanged suivra.
		if ok and typeof(view) == "table" then
			receive(view)
		end
	end
end

return QuestController
