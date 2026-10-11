--!strict
-- Règles pures des héros possédés et de la hotbar (voir docs/HEROES.md).
-- Aucune API Roblox : testé par tools/test-heroes.ps1. Modifie directement la table PlayerData.

local HeroRules = {}

HeroRules.EMPTY = ""

local function validSlot(slot: any, size: number): boolean
	return typeof(slot) == "number" and slot >= 1 and slot <= size and slot % 1 == 0
end

-- Assign depuis la collection = remplacement ; Swap depuis la hotbar = échange.
-- Ne modifie jamais Heroes, uniquement ses raccourcis persistés.
function HeroRules.hotbarAction(data: any, size: number, action: any, first: any, second: any): (boolean, string?)
	if action == "Assign" then
		if not validSlot(second, size) then return false, "raccourci invalide" end
		if typeof(first) ~= "string" or not data.Heroes[first] then return false, "héros non possédé" end
		for slot = 1, size do
			if data.Hotbar[slot] == first then data.Hotbar[slot] = HeroRules.EMPTY end
		end
		data.Hotbar[second] = first
	elseif action == "Clear" then
		if not validSlot(first, size) then return false, "raccourci invalide" end
		data.Hotbar[first] = HeroRules.EMPTY
	elseif action == "Swap" then
		if not validSlot(first, size) or not validSlot(second, size) then return false, "raccourci invalide" end
		data.Hotbar[first], data.Hotbar[second] = data.Hotbar[second], data.Hotbar[first]
	else
		return false, "action inconnue"
	end
	return true, nil
end

-- Hotbar valide : exactement `size` cases, chacune "" ou un exemplaire possédé, sans doublon.
-- Renvoie true si la hotbar a dû être corrigée.
function HeroRules.normalizeHotbar(data: any, size: number): boolean
	local changed = typeof(data.Hotbar) ~= "table"
	local source = if changed then {} else data.Hotbar
	local hotbar: { string } = {}
	local seen: { [string]: boolean } = {}
	for index = 1, size do
		local id = source[index]
		if typeof(id) == "string" and id ~= HeroRules.EMPTY and data.Heroes[id] and not seen[id] then
			seen[id] = true
			hotbar[index] = id
		else
			changed = changed or id ~= HeroRules.EMPTY
			hotbar[index] = HeroRules.EMPTY
		end
	end
	if #source ~= size then
		changed = true
	end
	data.Hotbar = hotbar
	return changed
end

-- Ajoute un exemplaire, et le met dans la première case libre de la hotbar s'il y en a une.
-- Renvoie la case de hotbar utilisée, ou nil (hotbar pleine : le héros reste dans la collection).
function HeroRules.addHero(data: any, instanceId: string, heroId: string): number?
	data.Heroes[instanceId] = { HeroId = heroId, Level = 1 }
	for index, id in data.Hotbar do
		if id == instanceId then
			return index
		end
	end
	for index, id in data.Hotbar do
		if id == HeroRules.EMPTY then
			data.Hotbar[index] = instanceId
			return index
		end
	end
	return nil
end

-- Retire un exemplaire des données et de la hotbar.
function HeroRules.removeHero(data: any, instanceId: string): boolean
	if not data.Heroes[instanceId] then
		return false
	end
	data.Heroes[instanceId] = nil
	for index, id in data.Hotbar do
		if id == instanceId then
			data.Hotbar[index] = HeroRules.EMPTY
		end
	end
	return true
end

-- Vrai si le joueur possède au moins un exemplaire de ce HeroId.
function HeroRules.owns(data: any, heroId: string): boolean
	for _, hero in data.Heroes do
		if hero.HeroId == heroId then
			return true
		end
	end
	return false
end

-- Héros de départ : chaque HeroId de `starter` absent de la collection est ajouté une fois.
-- Un nouveau joueur reçoit donc exactement un exemplaire de chacun ; un joueur qui les possède
-- déjà ne reçoit rien. Renvoie le nombre d'exemplaires créés.
function HeroRules.grantStarter(data: any, starter: { string }, makeId: () -> string): number
	local granted = 0
	for _, heroId in starter do
		if not HeroRules.owns(data, heroId) then
			HeroRules.addHero(data, makeId(), heroId)
			granted += 1
		end
	end
	return granted
end

export type CombatHero = { HeroId: string, CombatProfile: string, CombatTemplate: string }

-- Exemplaire réellement possédé, activé (catalogue HeroConfig.Heroes) et dont le profil de combat
-- a des stats (CombatConfig.Heroes) : HeroId réel + profil et modèle de combat temporaires.
-- Sinon nil et la raison.
function HeroRules.combatHero(data: any, instanceId: any, catalog: { [string]: any }, profiles: { [string]: any }): (CombatHero?, string?)
	if typeof(instanceId) ~= "string" then
		return nil, "héros inconnu"
	end
	local hero = data.Heroes[instanceId]
	if not hero then
		return nil, "héros inconnu"
	end
	local info = if typeof(hero.HeroId) == "string" then catalog[hero.HeroId] else nil
	if not info or typeof(info.CombatProfile) ~= "string" or not profiles[info.CombatProfile]
		or typeof(info.CombatTemplate) ~= "string" then
		return nil, "héros non disponible au combat"
	end
	return { HeroId = hero.HeroId, CombatProfile = info.CombatProfile, CombatTemplate = info.CombatTemplate }, nil
end

-- Vue envoyée au client : exemplaires possédés (triés) et hotbar.
export type HeroView = { Id: string, HeroId: string, Level: number }

function HeroRules.view(data: any): { Heroes: { HeroView }, Hotbar: { string } }
	local heroes: { HeroView } = {}
	for id, hero in data.Heroes do
		table.insert(heroes, { Id = id, HeroId = hero.HeroId, Level = hero.Level })
	end
	table.sort(heroes, function(a: HeroView, b: HeroView): boolean
		return a.Id < b.Id
	end)
	return { Heroes = heroes, Hotbar = table.clone(data.Hotbar) }
end

return HeroRules
