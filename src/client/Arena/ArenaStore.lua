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
function ArenaStore.request(action: string, ...: any)
	local remote = actionRemote
	if remote then
		remote:InvokeServer(action, ...)
	end
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

local function applyArena(state: { [string]: any })
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
	local state = remotes:WaitForChild("ArenaState", 30)
	if action and action:IsA("RemoteFunction") then
		actionRemote = action
	end
	if state and state:IsA("RemoteEvent") then
		state.OnClientEvent:Connect(applyArena)
	end
end

return ArenaStore
