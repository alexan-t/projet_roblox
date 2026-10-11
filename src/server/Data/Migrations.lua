--!strict
-- Migrations des données joueur entre versions.
-- Pour changer la structure :
--   1. incrémenter CURRENT_VERSION ;
--   2. ajouter STEPS[<ancienne version>] = function(data) ... end qui transforme les données en place ;
--   3. mettre à jour PlayerDataTypes et DefaultPlayerData.
-- Les nouvelles clés simples n'ont pas besoin de migration : Profile:Reconcile() les ajoute.
-- Une migration sert pour renommer, déplacer ou convertir une donnée existante.
-- Une étape est historique : elle ne lit aucune config du jeu (qui peut changer après coup).

local Migrations = {}

Migrations.CURRENT_VERSION = 2

-- v1 -> v2 (issue #10) : les héros Alpha étaient des classes de combat temporaires. En v2, HeroId
-- est l'identifiant réel du héros. Valeurs figées à la date de la migration.
local LEGACY_HERO_IDS = { Archer = true, Epeiste = true, Barbare = true, Paladin = true, Magicien = true, Tireur = true }
local V2_STARTER = "ecuyer_du_rempart"
local V2_STARTER_FROM = "Epeiste" -- exemplaire legacy réutilisé en priorité pour le starter

local function v1ToV2(data: { [string]: any })
	local heroes: { [string]: any } = if typeof(data.Heroes) == "table" then (data.Heroes :: any) else {}
	data.Heroes = heroes
	local legacy: { string } = {}
	local hasStarter = false
	for id, hero in heroes do
		local heroId = if typeof(hero) == "table" then hero.HeroId else nil
		if heroId == V2_STARTER then
			hasStarter = true
		elseif typeof(heroId) == "string" and LEGACY_HERO_IDS[heroId] then
			table.insert(legacy, id)
		end
	end
	table.sort(legacy) -- ordre déterministe
	if not hasStarter and #legacy > 0 then
		-- Réutiliser un exemplaire existant (son identifiant, sa place en hotbar) plutôt que d'en créer un.
		local chosen = legacy[1]
		for _, id in legacy do
			if heroes[id].HeroId == V2_STARTER_FROM then
				chosen = id
				break
			end
		end
		heroes[chosen].HeroId = V2_STARTER
	end
	for _, id in legacy do
		local hero = heroes[id]
		if hero and LEGACY_HERO_IDS[hero.HeroId] then
			heroes[id] = nil
		end
	end
	-- Raccourcis : une case vers un exemplaire disparu devient vide (même longueur, pas de trou).
	if typeof(data.Hotbar) == "table" then
		local hotbar: { string } = {}
		for index = 1, #data.Hotbar do
			local id = data.Hotbar[index]
			hotbar[index] = if typeof(id) == "string" and heroes[id] then id else ""
		end
		data.Hotbar = hotbar
	end
	-- Équipe : liste compacte des exemplaires encore possédés.
	if typeof(data.Team) == "table" then
		local team: { string } = {}
		for _, id in data.Team do
			if typeof(id) == "string" and heroes[id] then
				table.insert(team, id)
			end
		end
		data.Team = team
	end
end

local STEPS: { [number]: (data: { [string]: any }) -> () } = {
	[1] = v1ToV2,
}

-- Lecture seule pour les tests (rejouer une étape).
Migrations.steps = table.freeze(table.clone(STEPS))

export type Result = "Ok" | "TooNew" | "MissingStep"

-- Amène data à CURRENT_VERSION. Si le résultat n'est pas "Ok", data n'a pas été modifié :
--   "TooNew"      : données d'une version plus récente du jeu (serveur pas encore mis à jour) ;
--   "MissingStep" : une étape de migration manque dans STEPS.
function Migrations.run(data: { [string]: any }): Result
	local version = if typeof(data.DataVersion) == "number" then data.DataVersion else 1
	if version > Migrations.CURRENT_VERSION then
		return "TooNew"
	end
	for v = version, Migrations.CURRENT_VERSION - 1 do
		if not STEPS[v] then
			return "MissingStep"
		end
	end
	for v = version, Migrations.CURRENT_VERSION - 1 do
		STEPS[v](data)
	end
	data.DataVersion = Migrations.CURRENT_VERSION
	return "Ok"
end

return Migrations
