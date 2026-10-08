--!strict
-- État client partagé entre la hotbar/sacoche (HeroBarController) et l'arène
-- (ArenaPlacementController) : héros possédés, hotbar, préparation vue par le serveur, héros en main.
-- Ce n'est qu'un reflet : le serveur (HeroService, ArenaService) reste seul juge.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HeroConfig = require(ReplicatedStorage.Shared.Config.HeroConfig)
local PlacementState = require(script.Parent.PlacementState)

export type HeroView = { Id: string, HeroId: string, Level: number }

local ArenaStore = {}

ArenaStore.heroes = {} :: { [string]: HeroView }
ArenaStore.hotbar = table.create(HeroConfig.HotbarSize, "") :: { string }
ArenaStore.arena = { Phase = "Closed", Formation = {}, MaxHeroes = 4 } :: { [string]: any }
ArenaStore.placement = PlacementState.new()
-- Déclenché à chaque changement d'état (rendu des contrôleurs).
ArenaStore.changed = Instance.new("BindableEvent")
-- Message bref à afficher (refus, résultat) : texte.
ArenaStore.toast = Instance.new("BindableEvent")

local actionRemote: RemoteFunction? = nil
local hotbarRemote: RemoteFunction? = nil
ArenaStore.busy = false
local started = false

function ArenaStore.notify()
	ArenaStore.changed:Fire()
end

-- Formation actuelle : case -> HeroInstanceId.
function ArenaStore.formation(): { [number]: string }
	local map = {}
	for _, entry in ArenaStore.arena.Formation or {} do
		map[entry.Slot] = entry.HeroInstanceId
	end
	return map
end

function ArenaStore.placedCount(): number
	return #(ArenaStore.arena.Formation or {})
end

function ArenaStore.inCombat(): boolean
	return ArenaStore.arena.Phase == "Combat"
end

function ArenaStore.heroInfo(instanceId: string?): (HeroView?, HeroConfig.HeroInfo?)
	local hero = if instanceId then ArenaStore.heroes[instanceId] else nil
	return hero, if hero then HeroConfig.Heroes[hero.HeroId] else nil
end

-- Envoie une demande à ArenaService. Sa réponse (état + refus éventuel) arrive par ArenaState.
function ArenaStore.request(action: string, ...: any): boolean
	local remote = actionRemote
	if not remote or ArenaStore.busy then return false end
	ArenaStore.busy = true
	local held = ArenaStore.placement.held
	local success, accepted, reason = pcall(remote.InvokeServer, remote, action, ...)
	ArenaStore.busy = false
	if success and accepted then
		PlacementState.accept(ArenaStore.placement, held, true)
	else
		ArenaStore.toast:Fire(if success then reason or "Action refusée" else "Connexion interrompue, réessaie")
	end
	ArenaStore.notify()
	return success and accepted == true
end

local function applyHeroes(view: any)
	if typeof(view) ~= "table" then
		return
	end
	table.clear(ArenaStore.heroes)
	for _, hero in view.Heroes do
		ArenaStore.heroes[hero.Id] = hero
	end
	ArenaStore.hotbar = view.Hotbar
	ArenaStore.notify()
end

function ArenaStore.hotbarAction(action: string, first: any, second: any): boolean
	local remote = hotbarRemote
	if not remote or ArenaStore.busy then return false end
	ArenaStore.busy = true
	local success, accepted, reason, view = pcall(remote.InvokeServer, remote, action, first, second)
	ArenaStore.busy = false
	if success and view then applyHeroes(view) end
	if not success or not accepted then
		ArenaStore.toast:Fire(if success then reason or "Action refusée" else "Connexion interrompue, réessaie")
	end
	ArenaStore.notify()
	return success and accepted == true
end

local function applyArena(state: { [string]: any })
	-- Un état plus ancien (réponse initiale arrivée en retard) ne remplace jamais un état plus récent.
	local current = ArenaStore.arena.Version
	if typeof(state) ~= "table" or (typeof(current) == "number" and typeof(state.Version) == "number" and state.Version < current) then
		return
	end
	ArenaStore.arena = state
	PlacementState.setLocked(ArenaStore.placement, state.Phase == "Combat")
	PlacementState.syncFormation(ArenaStore.placement, ArenaStore.formation())
	if typeof(state.Message) == "string" and state.Message ~= "" then
		ArenaStore.toast:Fire(state.Message)
	end
	ArenaStore.notify()
end

-- Branche les remotes (idempotent ; appelé par chaque contrôleur qui en a besoin).
function ArenaStore.start()
	if started then
		return
	end
	started = true
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local getHeroes = remotes:WaitForChild("GetHeroes", 30)
	local heroesChanged = remotes:WaitForChild("HeroesChanged", 30)
	if heroesChanged and heroesChanged:IsA("RemoteEvent") then
		heroesChanged.OnClientEvent:Connect(applyHeroes)
	end
	if getHeroes and getHeroes:IsA("RemoteFunction") then
		task.spawn(function()
			applyHeroes(getHeroes:InvokeServer())
		end)
	end
	local action = remotes:WaitForChild("ArenaAction", 30)
	local edit = remotes:WaitForChild("HotbarAction", 30)
	if edit and edit:IsA("RemoteFunction") then hotbarRemote = edit end
	local state = remotes:WaitForChild("ArenaState", 30)
	if action and action:IsA("RemoteFunction") then
		actionRemote = action
	end
	if state and state:IsA("RemoteEvent") then
		state.OnClientEvent:Connect(applyArena)
	end
	local getState = remotes:WaitForChild("GetArenaState", 30)
	if getState and getState:IsA("RemoteFunction") then applyArena(getState:InvokeServer()) end
end

return ArenaStore
