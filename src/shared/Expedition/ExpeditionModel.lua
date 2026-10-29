--!strict
-- Logique d'affichage de la fenêtre Expédition (voir docs/ZONES.md § Fenêtre Expédition). Module pur,
-- sans Instance, testé (tools/test-expedition.ps1). Il ne lit QUE les vues envoyées par le serveur
-- (ArenaService : Stages / EliteStages, StagePreview) : aucun chiffre de gameplay ici.
--   nodes(stages, mode, eliteUnlocked)  -> état des 5 cartes du rail (Disponible, Terminé, Verrouillé, Élite,
--                                          Boss, Boss · Terminé) ;
--   cleared(stages)                     -> stages terminés (« Bats le Roi Orc en Normal · 3/5 ») ;
--   track(nodes)                        -> remplissage de la barre de progression (0..1) ;
--   launch(stage, mode, eliteUnlocked, placed, wide) -> bouton « Lancer » : actif ? sous-texte ou raison ;
--   team(placed, max)                   -> pied de fenêtre « Équipe X/4 » et indice ;
--   rewards(stage)                      -> blocs « Première victoire » et « À chaque victoire » réels ;
--   chance(value)                       -> « 30 % », « 0,5 % », « Garanti » (chance d'un butin, 0..1) ;
--   equipment(stage, names)             -> lignes « Équipement » du butin (#120) : garanti à la 1re victoire,
--                                          puis chance par victoire et part de chaque rareté (LootConfig réelle) ;
--   milestone(previous, objective)      -> annonce « Mode Élite débloqué ! » / « Zone n maîtrisée ! » (#120) ;
--   eliteNote(objective, zone)          -> sous-titre de l'onglet Élite (fin de contenu ou raison de jouer) ;
--   device(width, height)               -> "pc" | "tablet" | "phone" (dispositions de la maquette).

export type Reward = { Kind: string, Amount: number }
export type Stage = {
	Zone: number,
	Stage: number,
	Status: string?, -- "Unlocked" | "Locked" | "Unavailable"
	Cleared: boolean?,
	Boss: string?,
	HeroXP: number?,
	FirstClearRewards: { Reward }?,
	RepeatRewards: { Reward }?,
	PotentialDrops: { any }?,
	-- Équipement (#120, StagePreview.Equipment) : chance par victoire, par rareté, garanti au premier clear.
	Equipment: { Chance: number, Rarities: { { Rarity: string, Chance: number } }, FirstClear: { { Rarity: string, Chance: number } }? }?,
}
-- Prochain objectif envoyé par le serveur (ArenaState.Objective, ArenaRules.objective).
export type Objective = { Kind: string, Mode: string, Zone: number, Stage: number }
export type Node = { Stage: number, State: string, Boss: boolean, Badge: string, BadgeKind: string, Label: string }

local ExpeditionModel = {}

local function suffix(mode: string): string
	return if mode == "Elite" then "E" else ""
end

function ExpeditionModel.label(stage: Stage, mode: string, wide: boolean): string
	return `{if wide then "Stage " else ""}{stage.Zone}-{stage.Stage}{suffix(mode)}`
end

-- Titre du détail : « Stage 1-5 · Boss », « Stage 1-3E ».
function ExpeditionModel.title(stage: Stage, mode: string): string
	return ExpeditionModel.label(stage, mode, true) .. (if stage.Boss then " · Boss" else "")
end

function ExpeditionModel.isOpen(stage: Stage, mode: string, eliteUnlocked: boolean): boolean
	if mode == "Elite" and not eliteUnlocked then
		return false
	end
	return stage.Status == "Unlocked"
end

function ExpeditionModel.nodes(stages: { Stage }, mode: string, eliteUnlocked: boolean): { Node }
	local list: { Node } = {}
	for _, stage in stages do
		local open = ExpeditionModel.isOpen(stage, mode, eliteUnlocked)
		local cleared = stage.Cleared == true and not (mode == "Elite" and not eliteUnlocked)
		local state = if cleared then "Done" elseif open then "Open" else "Locked"
		local boss = stage.Boss ~= nil
		local badge, kind
		if boss then
			badge, kind = (if cleared then "Boss · Terminé" else "Boss"), "Boss"
		elseif cleared then
			badge, kind = "Terminé", "Done"
		elseif open then
			badge, kind = (if mode == "Elite" then "Élite" else "Disponible"), (if mode == "Elite" then "Elite" else "Open")
		else
			badge, kind = "Verrouillé", "Locked"
		end
		table.insert(list, { Stage = stage.Stage, State = state, Boss = boss, Badge = badge, BadgeKind = kind, Label = ExpeditionModel.label(stage, mode, true) })
	end
	return list
end

function ExpeditionModel.cleared(stages: { Stage }): number
	local count = 0
	for _, stage in stages do
		if stage.Cleared then
			count += 1
		end
	end
	return count
end

-- Barre derrière le rail : jusqu'au dernier stage terminé (0 si l'Élite est verrouillée).
function ExpeditionModel.track(nodes: { Node }): number
	if #nodes <= 1 then
		return 0
	end
	local done = 0
	for _, node in nodes do
		if node.State == "Done" then
			done += 1
		end
	end
	return math.clamp(done / (#nodes - 1), 0, 1)
end

-- Stage proposé à l'ouverture : celui déjà choisi s'il existe, sinon le premier ouvert non terminé,
-- sinon le dernier ouvert, sinon le premier.
function ExpeditionModel.default(stages: { Stage }, mode: string, eliteUnlocked: boolean, preferred: number?): Stage?
	local first, lastOpen, firstNew = stages[1], nil, nil
	for _, stage in stages do
		if stage.Stage == preferred then
			return stage
		end
		if ExpeditionModel.isOpen(stage, mode, eliteUnlocked) then
			lastOpen = stage
			if not stage.Cleared and not firstNew then
				firstNew = stage
			end
		end
	end
	return firstNew or lastOpen or first
end

export type Launch = { Enabled: boolean, Sub: string }

-- « Lancer » : actif seulement si le stage est ouvert, l'Élite débloquée (en Élite) et au moins un héros
-- posé ; sinon le sous-texte dit pourquoi. Le serveur revérifie tout (ArenaService).
function ExpeditionModel.launch(stage: Stage?, mode: string, eliteUnlocked: boolean, placed: number): Launch
	if not stage then
		return { Enabled = false, Sub = "Aucun stage" }
	end
	if mode == "Elite" and not eliteUnlocked then
		return { Enabled = false, Sub = "Élite verrouillée" }
	end
	if stage.Status ~= "Unlocked" then
		if stage.Stage == 1 and stage.Zone > 1 and mode == "Normal" then
			return { Enabled = false, Sub = `Termine la zone {stage.Zone - 1}` }
		end
		return { Enabled = false, Sub = `Termine {stage.Zone}-{stage.Stage - 1}{suffix(mode)}` }
	end
	if placed < 1 then
		return { Enabled = false, Sub = "Pose un héros" }
	end
	return { Enabled = true, Sub = `Stage {stage.Zone}-{stage.Stage}{if mode == "Elite" then " · ÉLITE" else ""}` }
end

export type Team = { Ready: boolean, Full: boolean, Hint: string }

function ExpeditionModel.team(placed: number, max: number): Team
	if placed <= 0 then
		return { Ready = false, Full = false, Hint = "Place au moins un héros sur les dalles" }
	end
	if placed >= max then
		return { Ready = true, Full = true, Hint = "Équipe complète" }
	end
	local free = max - placed
	return { Ready = true, Full = false, Hint = `Prêt · {free} place{if free > 1 then "s" else ""} libre{if free > 1 then "s" else ""}` }
end

export type Rewards = {
	FirstClear: { Reward },
	FirstClearDone: boolean, -- déjà obtenue : affichée comme obtenue, jamais comme récupérable à nouveau
	Repeat: { Reward },
	RepeatTitle: string,
	HeroXP: number,
}

-- Récompenses réelles du stage. Première victoire = FirstClearRewards SEULEMENT (RewardRules) ; ensuite
-- RepeatRewards à chaque victoire ; l'XP est gagnée par CHAQUE héros posé, à chaque victoire.
function ExpeditionModel.rewards(stage: Stage, wide: boolean): Rewards
	local done = stage.Cleared == true
	return {
		FirstClear = stage.FirstClearRewards or {},
		FirstClearDone = done,
		Repeat = stage.RepeatRewards or {},
		RepeatTitle = if not wide then "Rejouer" elseif done then "À chaque victoire" else "Ensuite, à chaque victoire",
		HeroXP = stage.HeroXP or 0,
	}
end

-- Chance d'un butin (0..1) en texte français : « 30 % », « 6 % », « 0,5 % », « Garanti ». Arrondi au
-- dixième de pourcent seulement pour l'affichage (la valeur vient telle quelle de la config serveur).
function ExpeditionModel.chance(value: number): string
	if value >= 1 then
		return "Garanti"
	end
	local percent = math.floor(value * 1000 + 0.5) / 10
	if percent % 1 == 0 then
		return `{math.floor(percent)} %`
	end
	return (string.format("%.1f %%", percent):gsub("%.", ","))
end

-- Chance : texte de la pastille ; Value : la probabilité (0..1, 1 = garanti), pour sa couleur.
export type EquipmentLine = { Label: string, Chance: string, Value: number, Detail: string, Guaranteed: boolean }

-- « Rare 19,2 % · Épique 11,2 % · Légendaire 1,6 % » ; names : Id de rareté → libellé (RarityConfig).
local function rarityText(list: { { Rarity: string, Chance: number } }, names: { [string]: string }?): string
	local parts: { string } = {}
	for _, entry in list do
		local name = if names and names[entry.Rarity] then names[entry.Rarity] else entry.Rarity
		table.insert(parts, `{name} {ExpeditionModel.chance(entry.Chance)}`)
	end
	return table.concat(parts, " · ")
end

-- Lignes « Équipement » du butin possible, en tête de liste (#120). Uniquement les valeurs du serveur
-- (StagePreview.Equipment, lu dans LootConfig) : aucun pourcentage ici. Une chance PAR VICTOIRE (jamais par
-- ennemi). L'équipement garanti de la première victoire n'est montré que tant qu'elle reste à gagner.
function ExpeditionModel.equipment(stage: Stage, names: { [string]: string }?): { EquipmentLine }
	local lines: { EquipmentLine } = {}
	local equipment = stage.Equipment
	if not equipment then
		return lines
	end
	if equipment.FirstClear and #equipment.FirstClear > 0 and not stage.Cleared then
		table.insert(lines, { Label = "Équipement · 1re victoire", Chance = "Garanti", Value = 1, Detail = rarityText(equipment.FirstClear, names), Guaranteed = true })
	end
	if equipment.Chance > 0 then
		table.insert(lines, { Label = "Équipement aléatoire", Chance = ExpeditionModel.chance(equipment.Chance), Value = equipment.Chance,
			Detail = rarityText(equipment.Rarities, names), Guaranteed = false })
	end
	return lines
end

export type Milestone = { Title: string, Text: string }

-- Annonce d'un palier franchi pendant la session (jamais au join : previous = nil). L'Élite vient de
-- s'ouvrir (objectif Normal → EliteNew) ; ou tout le butin est gagné (Élite → Farm Élite).
function ExpeditionModel.milestone(previous: Objective?, objective: Objective?): Milestone?
	if not previous or not objective or previous.Kind == objective.Kind then
		return nil
	end
	if previous.Kind == "Normal" and objective.Kind == "EliteNew" then
		return { Title = "Mode Élite débloqué !", Text = `Ennemis plus forts, meilleur équipement : lance {objective.Zone}-{objective.Stage} en Élite` }
	end
	if (previous.Kind == "EliteNew" or previous.Kind == "Elite") and objective.Kind == "Farm" and objective.Mode == "Elite" then
		return { Title = `Zone {objective.Zone} maîtrisée !`, Text = "Améliore ton équipe en Élite en attendant les prochaines zones" }
	end
	return nil
end

-- Sous-titre de l'onglet Élite : fin de contenu de la zone (tout est gagné), sinon la raison d'y jouer.
function ExpeditionModel.eliteNote(objective: Objective?, zone: number): string
	if objective and objective.Kind == "Farm" and objective.Mode == "Elite" and objective.Zone == zone then
		return `Zone {zone} maîtrisée ! Améliore ton équipe en attendant les prochaines zones`
	end
	return "Ennemis plus coriaces, meilleur équipement"
end

-- Disposition de la maquette selon la taille de l'écran (px) : téléphone en paysage (hauteur < 520),
-- tablette (largeur < 1300 ou format proche du 4/3), sinon PC.
function ExpeditionModel.device(width: number, height: number): string
	if height < 520 then
		return "phone"
	end
	if width < 1300 or width / math.max(height, 1) < 1.5 then
		return "tablet"
	end
	return "pc"
end

return ExpeditionModel
