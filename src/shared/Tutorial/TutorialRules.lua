--!strict
-- Règles du guidage du tutoriel (voir docs/TUTORIAL_GUIDANCE.md). Module pur, partagé, sans Instance :
--   • le serveur (TutorialService) n'enregistre que des drapeaux connus ;
--   • le client (TutorialController) décide quelles étapes montrer et quelle flèche l'emporte.
-- Les données viennent de Shared.Config.TutorialConfig (passée en argument : testable avec une autre config).

local TutorialRules = {}

-- Priorités des sources d'une flèche UI : une seule flèche à la fois (pas de spam visuel).
--   FirstOpen : découverte d'une interface qui vient de s'ouvrir (le regard du joueur y est déjà) ;
--   Quest     : étape active de la quête (poser le héros, lancer le combat) ;
--   Nudge     : rappel « ouvre ce menu ».
local PRIORITY: { [string]: number } = { FirstOpen = 3, Quest = 2, Nudge = 1 }
TutorialRules.Priority = table.freeze(PRIORITY)

export type Candidate = { Source: string, Target: string, Text: string? }

local MAX_KEY = 32

function TutorialRules.isFlag(config: any, key: any): boolean
	if typeof(key) ~= "string" or #key == 0 or #key > MAX_KEY then
		return false
	end
	return table.find(config.Flags, key) ~= nil
end

-- Marque `key` vu dans `seen` (table Tutorial.Seen) ; true si c'est nouveau, false si refusé ou déjà vu.
function TutorialRules.mark(config: any, seen: { [string]: boolean }, key: any): boolean
	if not TutorialRules.isFlag(config, key) or seen[key] == true then
		return false
	end
	seen[key] = true
	return true
end

-- Copie des seuls drapeaux connus et vrais (vue envoyée au client, jamais la table sauvegardée).
function TutorialRules.view(config: any, seen: any): { [string]: boolean }
	local copy = {}
	if typeof(seen) == "table" then
		for _, key in config.Flags do
			if seen[key] == true then
				copy[key] = true
			end
		end
	end
	return copy
end

-- Étapes de première ouverture à montrer pour `key`, ou nil (déjà vu, inconnu, sans étape).
function TutorialRules.firstOpen(config: any, seen: { [string]: boolean }, key: string): { any }?
	if not TutorialRules.isFlag(config, key) or seen[key] == true then
		return nil
	end
	local entry = config.FirstOpen[key]
	if not entry or #entry.Steps == 0 then
		return nil
	end
	return entry.Steps
end

-- Guidage d'une partie d'interface (FirstOpen avec Screen) à lancer maintenant, ou nil : drapeau non vu,
-- interface `Screen` ouverte (isOpen(screen) -> boolean), condition vraie, au moins une étape. Ordre des
-- drapeaux de config.Flags (stable).
function TutorialRules.followUp(config: any, seen: { [string]: boolean }, conditions: { [string]: boolean }, isOpen: (string) -> boolean): string?
	for _, key in config.Flags do
		local entry = config.FirstOpen[key]
		if entry and entry.Screen and seen[key] ~= true and #entry.Steps > 0 and isOpen(entry.Screen)
			and (entry.Condition == nil or conditions[entry.Condition] == true) then
			return key
		end
	end
	return nil
end

-- Condition HasEquipment : au moins un héros possédé et un équipement du catalogue porté par personne
-- (entrées de la vue d'inventaire du serveur : { ItemId, EquippedBy? }). Sans héros ou sans objet libre :
-- false, le guidage ne bloque rien.
function TutorialRules.hasEquipment(heroCount: number, entries: any, items: { [string]: any }): boolean
	if heroCount < 1 or typeof(entries) ~= "table" then
		return false
	end
	for _, entry in entries do
		if typeof(entry) == "table" and items[entry.ItemId] ~= nil and (entry.EquippedBy == nil or entry.EquippedBy == "") then
			return true
		end
	end
	return false
end

-- Un équipement est confirmé uniquement lorsque la vue InventoryStore (générée par le serveur)
-- relie un ItemId valide à un HeroInstanceId. Un clic client ne suffit jamais.
function TutorialRules.hasEquipped(heroCount: number, entries: any, items: { [string]: any }): boolean
	if heroCount < 1 or typeof(entries) ~= "table" then
		return false
	end
	for _, entry in entries do
		if typeof(entry) == "table" and typeof(entry.ItemId) == "string" and items[entry.ItemId] ~= nil
			and typeof(entry.EquippedBy) == "string" and entry.EquippedBy ~= "" then
			return true
		end
	end
	return false
end

-- Guidages FirstOpen avec Done dont la condition de fin est vraie : leur drapeau s'enregistre maintenant,
-- jamais à leur début (Equipment : un objet porté, vu par le serveur ; un clic client ne suffit jamais).
function TutorialRules.done(config: any, seen: { [string]: boolean }, conditions: { [string]: boolean }): { string }
	local list: { string } = {}
	for _, key in config.Flags do
		local entry = config.FirstOpen[key]
		if entry and typeof(entry.Done) == "string" and seen[key] ~= true and conditions[entry.Done] == true then
			table.insert(list, key)
		end
	end
	return list
end

-- Étape où (re)prendre un guidage Done : la plus avancée dont la cible est affichée (exists(target) ->
-- boolean), nil si aucune. Rouvrir la Sacoche sur un objet déjà choisi reprend à « Équiper », pas au début.
function TutorialRules.resume(steps: { any }, exists: (string) -> boolean): number?
	for index = #steps, 1, -1 do
		if exists(steps[index].Target) then
			return index
		end
	end
	return nil
end

-- Rappels actifs : drapeau non vu ET condition vraie (conditions = { [nom]: boolean }).
function TutorialRules.nudges(config: any, seen: { [string]: boolean }, conditions: { [string]: boolean }): { Candidate }
	local list: { Candidate } = {}
	for _, nudge in config.Nudges do
		if seen[nudge.Flag] ~= true and conditions[nudge.Condition] == true then
			table.insert(list, { Source = "Nudge", Target = nudge.Target })
		end
	end
	return list
end

-- Badge « ! » d'une entrée du menu : drapeau non vu et condition (si présente) vraie ; avec `config`, aussi
-- un rappel actif marqué Badge qui vise cette entrée (« Menu.<Id> »).
function TutorialRules.badge(entry: any, seen: { [string]: boolean }, conditions: { [string]: boolean }, config: any?): boolean
	if config then
		for _, nudge in config.Nudges do
			if nudge.Badge == true and nudge.Target == `Menu.{entry.Id}` and seen[nudge.Flag] ~= true and conditions[nudge.Condition] == true then
				return true
			end
		end
	end
	if typeof(entry.Flag) ~= "string" or seen[entry.Flag] == true then
		return false
	end
	return entry.Badge == nil or conditions[entry.Badge] == true
end

-- Candidat de plus haute priorité dont la cible est disponible (available(target) -> boolean), ou nil.
-- À priorité égale, le premier de la liste l'emporte (ordre stable).
function TutorialRules.pick(candidates: { Candidate }, available: (string) -> boolean): Candidate?
	local best: Candidate? = nil
	local bestRank = -math.huge
	for _, candidate in candidates do
		local rank = PRIORITY[candidate.Source] or 0
		if rank > bestRank and available(candidate.Target) then
			best, bestRank = candidate, rank
		end
	end
	return best
end

-- Problèmes de la config (liste vide = valide) : drapeaux uniques, étapes et entrées bien formées.
function TutorialRules.problems(config: any): { string }
	local problems: { string } = {}
	local flags: { [string]: boolean } = {}
	for _, key in config.Flags do
		if typeof(key) ~= "string" or #key == 0 or #key > MAX_KEY then
			table.insert(problems, `drapeau invalide : {tostring(key)}`)
		elseif flags[key] then
			table.insert(problems, `drapeau en double : {key}`)
		end
		flags[key] = true
	end
	local function target(where: string, value: any)
		if typeof(value) ~= "string" or not string.match(value, "^%a+%.%a+$") then
			table.insert(problems, `{where} : cible invalide ({tostring(value)}), attendu « Zone.Element »`)
		end
	end
	for key, entry in config.FirstOpen do
		if not flags[key] then
			table.insert(problems, `FirstOpen.{key} : drapeau inconnu`)
		end
		if entry.Screen ~= nil and (not flags[entry.Screen] or entry.Screen == key or config.FirstOpen[entry.Screen] == nil) then
			table.insert(problems, `FirstOpen.{key} : Screen inconnu ({tostring(entry.Screen)})`)
		end
		if entry.Condition ~= nil and (entry.Screen == nil or typeof(entry.Condition) ~= "string") then
			table.insert(problems, `FirstOpen.{key} : Condition sans Screen`)
		end
		if entry.Done ~= nil and (typeof(entry.Done) ~= "string" or entry.Screen == nil) then
			table.insert(problems, `FirstOpen.{key} : Done sans Screen`)
		end
		local last = entry.Steps[#entry.Steps]
		if entry.Done ~= nil and last and last.Hold ~= true then
			table.insert(problems, `FirstOpen.{key} : Done, dernière étape sans Hold`)
		end
		for index, step in entry.Steps do
			target(`FirstOpen.{key}[{index}]`, step.Target)
			if step.Seconds ~= nil and (typeof(step.Seconds) ~= "number" or step.Seconds <= 0) then
				table.insert(problems, `FirstOpen.{key}[{index}] : Seconds doit être > 0`)
			end
			if step.Hold ~= nil and (step.Hold ~= true or step.Seconds ~= nil) then
				table.insert(problems, `FirstOpen.{key}[{index}] : Hold vaut true, sans Seconds`)
			end
		end
	end
	for index, nudge in config.Nudges do
		target(`Nudges[{index}]`, nudge.Target)
		if not flags[nudge.Flag] then
			table.insert(problems, `Nudges[{index}] : drapeau inconnu ({tostring(nudge.Flag)})`)
		end
	end
	local views = { Bag = true, Index = true, Stats = true, Quests = true, Soon = true }
	local ids: { [string]: boolean } = {}
	for index, entry in config.Menu.Entries do
		if typeof(entry.Id) ~= "string" or ids[entry.Id] then
			table.insert(problems, `Menu[{index}] : Id manquant ou en double`)
		end
		ids[entry.Id] = true
		if not views[entry.View] then
			table.insert(problems, `Menu[{index}] : View inconnue ({tostring(entry.View)})`)
		end
		if entry.View == "Soon" and typeof(entry.Soon) ~= "string" then
			table.insert(problems, `Menu[{index}] : texte Soon manquant`)
		end
		if entry.Flag ~= nil and not flags[entry.Flag] then
			table.insert(problems, `Menu[{index}] : drapeau inconnu ({tostring(entry.Flag)})`)
		end
	end
	return problems
end

return TutorialRules
