--!strict
-- Écriture de l'équipement V1 (#73), côté client : UN remote, Remotes.EquipmentAction (RemoteFunction),
-- validé par le serveur (EquipmentService) :
--   ("Equip", heroInstanceId, itemInstanceId)  ou  ("Unequip", heroInstanceId, slotType)
--   -> (true, { Slot, Replaced? })  |  (false, raison en français)
-- Le client n'envoie jamais d'ItemId, de rareté ni de stat (arguments : Shared.Sacoche.EquipmentModel.request).
-- Après un succès, le serveur pousse HeroesChanged (ArenaStore) ET InventoryChanged (InventoryStore) : les
-- vues se redessinent depuis ces vues-là, ce store ne garde que « en cours » et la dernière erreur.
-- Tolérant : sans remote (serveur plus ancien, démarrage lent), available reste false et les boutons sont
-- désactivés ; jamais d'erreur.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EquipmentModel = require(ReplicatedStorage.Shared.Sacoche.EquipmentModel)

local WAIT = 20 -- s d'attente du remote avant de renoncer (le reste du jeu n'attend pas)

local EquipmentStore = {}

EquipmentStore.available = false
EquipmentStore.busy = false
EquipmentStore.lastError = nil :: string?
-- Déclenché quand busy / lastError / available changent (rendu de la Sacoche).
EquipmentStore.changed = Instance.new("BindableEvent")

local remote: RemoteFunction? = nil
local started = false

-- Efface l'erreur affichée (nouvelle sélection, changement de héros).
function EquipmentStore.clearError()
	if EquipmentStore.lastError ~= nil then
		EquipmentStore.lastError = nil
		EquipmentStore.changed:Fire()
	end
end

-- Envoie UNE demande ; jamais deux à la fois. Renvoie true si le serveur l'a acceptée.
function EquipmentStore.request(action: string, heroInstanceId: string, target: string): boolean
	local r = remote
	if not r or EquipmentStore.busy then
		return false
	end
	if (action ~= "Equip" and action ~= "Unequip") or typeof(heroInstanceId) ~= "string" or typeof(target) ~= "string" then
		return false
	end
	EquipmentStore.busy = true
	EquipmentStore.lastError = nil
	EquipmentStore.changed:Fire()
	local success, accepted, reason = pcall(r.InvokeServer, r, action, heroInstanceId, target)
	EquipmentStore.busy = false
	if success and accepted == true then
		EquipmentStore.lastError = nil
	elseif success then
		EquipmentStore.lastError = EquipmentModel.reasonText(reason)
	else
		EquipmentStore.lastError = "Connexion interrompue, réessaie"
	end
	EquipmentStore.changed:Fire()
	return success and accepted == true
end

-- Cherche le remote (idempotent ; ne bloque jamais l'appelant).
function EquipmentStore.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("Remotes", WAIT)
		local found = remotes and remotes:WaitForChild("EquipmentAction", WAIT)
		if found and found:IsA("RemoteFunction") then
			remote = found
			EquipmentStore.available = true
			EquipmentStore.changed:Fire()
		end
	end)
end

return EquipmentStore
