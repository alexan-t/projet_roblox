--!strict
-- Reflet client de l'inventaire (équipements + ressources) — issue #72. Lecture seule : le serveur
-- (InventoryService) reste seul juge ; aucun remote d'écriture ici (équiper / retirer : EquipmentStore, #73).
-- Patron ArenaStore :
--   - RemoteFunction Remotes.GetInventory à l'init -> vue ;
--   - RemoteEvent Remotes.InventoryChanged -> même vue, poussée après chaque mutation.
-- Tolérant : si les remotes sont absents (serveur plus ancien, démarrage lent), le store reste « non chargé »
-- (loaded = false) ; les vues affichent alors « Inventaire indisponible », jamais un faux inventaire vide.
-- « Nouveau » : instances d'équipement apparues APRÈS le premier chargement, jusqu'à ce que le joueur les ait
-- vues dans la Sacoche (markSeen).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryModel = require(ReplicatedStorage.Shared.Sacoche.InventoryModel)

local WAIT = 20 -- s d'attente de chaque remote avant de renoncer (le reste du jeu n'attend pas)
local RETRY = 1 -- s entre deux lectures de l'inventaire tant que le serveur n'a pas les données

local InventoryStore = {}

InventoryStore.view = nil :: InventoryModel.View?
InventoryStore.loaded = false
-- Incrémenté à chaque vue reçue : les vues s'en servent pour savoir s'il faut se redessiner.
InventoryStore.revision = 0
-- InstanceId d'équipement apparus depuis le premier chargement et pas encore vus.
InventoryStore.fresh = {} :: { [string]: boolean }
-- Déclenché à chaque changement (rendu des contrôleurs).
InventoryStore.changed = Instance.new("BindableEvent")

local started = false
local known: { [string]: boolean }? = nil
local pushes = 0 -- vues reçues par évènement : une réponse initiale plus ancienne ne les écrase jamais

local function apply(raw: any)
	local view = InventoryModel.sanitize(raw)
	if not view then
		return
	end
	local seen = known
	if seen == nil then
		-- premier chargement : tout ce qui est déjà possédé est connu, rien n'est « nouveau »
		seen = {}
		known = seen
		for _, entry in view.Equipment do
			(seen :: { [string]: boolean })[entry.InstanceId] = true
		end
	else
		for _, entry in view.Equipment do
			if not seen[entry.InstanceId] then
				seen[entry.InstanceId] = true
				InventoryStore.fresh[entry.InstanceId] = true
			end
		end
	end
	local owned: { [string]: boolean } = {}
	for _, entry in view.Equipment do
		owned[entry.InstanceId] = true
	end
	for id in InventoryStore.fresh do
		if not owned[id] then
			InventoryStore.fresh[id] = nil
		end
	end
	InventoryStore.view = view
	InventoryStore.loaded = true
	InventoryStore.revision += 1
	InventoryStore.changed:Fire()
end

function InventoryStore.hasNew(): boolean
	return next(InventoryStore.fresh) ~= nil
end

-- Le joueur a vu l'onglet Équipement : plus rien n'est « Nouveau ».
function InventoryStore.markSeen()
	if next(InventoryStore.fresh) == nil then
		return
	end
	table.clear(InventoryStore.fresh)
	InventoryStore.changed:Fire()
end

-- Branche les remotes (idempotent ; ne bloque jamais l'appelant).
function InventoryStore.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("Remotes", WAIT)
		if not remotes then
			return
		end
		local changedRemote = remotes:WaitForChild("InventoryChanged", WAIT)
		if changedRemote and changedRemote:IsA("RemoteEvent") then
			changedRemote.OnClientEvent:Connect(function(view: any)
				pushes += 1
				apply(view)
			end)
		end
		local getRemote = remotes:WaitForChild("GetInventory", WAIT)
		if getRemote and getRemote:IsA("RemoteFunction") then
			-- Le profil peut arriver après le client (reconnexion) : le serveur répond nil tant qu'il n'est pas
			-- chargé. On relit jusqu'à une vue (ou une vue poussée entre-temps), sinon la Sacoche resterait
			-- « indisponible » et le premier équipement sans guidage.
			while not InventoryStore.loaded do
				local before = pushes
				local ok, view = pcall(getRemote.InvokeServer, getRemote)
				if ok and pushes == before then
					apply(view)
				end
				if not InventoryStore.loaded then
					task.wait(RETRY)
				end
			end
		end
	end)
end

return InventoryStore
