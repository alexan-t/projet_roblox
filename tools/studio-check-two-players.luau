--!strict
-- À exécuter côté SERVEUR pendant un test Studio à deux clients (Test > Clients et serveurs > 2 joueurs),
-- quand les deux joueurs sont en combat en même temps. Lecture seule, ne modifie rien.
-- Vérifie : deux joueurs chargés, deux plots distincts, un seul décor par arène, des combats séparés
-- (aucun CombatId partagé, aucune unité d'un joueur dans le plot de l'autre). Voir docs/ZONES_QA.md § Reprise.
local Players = game:GetService("Players")

local problems: { string } = {}
local function check(ok: boolean, message: string)
	print(`{if ok then "OK  " else "KO  "} {message}`)
	if not ok then table.insert(problems, message) end
end

local players = Players:GetPlayers()
check(#players >= 2, `{#players} joueur(s) présent(s), 2 attendus`)

local lobby = workspace:FindFirstChild("Lobby")
local plots = lobby and lobby:FindFirstChild("Plots")
local seenPlots: { [Instance]: Player } = {}
local combatOwner: { [number]: Player } = {}
for _, player in players do
	local name = player.Name
	check(player:GetAttribute("DataLoaded") == true, `{name} : données chargées`)
	local plot: Instance? = nil
	for _, candidate in if plots then plots:GetChildren() else {} do
		if candidate:GetAttribute("OwnerUserId") == player.UserId then plot = candidate end
	end
	if not plot then
		check(false, `{name} : plot attribué`)
		continue
	end
	check(seenPlots[plot] == nil, `{name} : plot {plot.Name} non partagé`)
	seenPlots[plot] = player

	local arena = plot:FindFirstChild("Arene")
	local zones = arena and arena:FindFirstChild("Zones")
	local decors = if zones then zones:GetChildren() else {}
	local zoneId = decors[1] and decors[1]:GetAttribute("ZoneId")
	check(#decors == 1, `{name} : un seul décor dans l'arène (zone {zoneId}, {#decors} trouvé(s))`)

	local ids: { [number]: boolean } = {}
	local units = 0
	for _, model in plot:GetDescendants() do
		local id = model:GetAttribute("CombatId")
		if typeof(id) == "number" and model:GetAttribute("Alive") ~= false then
			ids[id] = true
			units += 1
		end
	end
	local list = {}
	for id in ids do
		table.insert(list, tostring(id))
		check(combatOwner[id] == nil, `{name} : combat {id} propre à ce joueur`)
		combatOwner[id] = player
	end
	check(#list == 1, `{name} : un combat en cours dans son plot ({#list} trouvé(s), {units} unités vivantes)`)
end

print(if #problems == 0 then "Deux joueurs : PASS" else `Deux joueurs : FIX ({#problems} problème(s))`)
return #problems
