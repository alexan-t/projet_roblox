--!strict
-- Règles pures de la préparation de combat (formation et roster annoncé) (PROTOTYPE, voir docs/ARENA_PROTOTYPE.md).
-- Aucune API Roblox : testé par tools/test-arena.ps1.

export type Enemy = { EnemyId: string, MiniBoss: boolean }
export type EnemySummary = { EnemyId: string, Count: number, MiniBoss: boolean }
-- Formation des héros : case (1..9) -> identifiant d'exemplaire (PlayerData.Heroes).
export type Formation = { [number]: string }

local ArenaRules = {}

ArenaRules.GRID_CELLS = 9

-- Ennemis du stage dans l'ordre (vagues, puis mini-boss), un élément par unité.
function ArenaRules.expandEnemies(stage: any): { Enemy }
	local enemies: { Enemy } = {}
	for _, wave in stage.Waves do
		for _, group in wave.Enemies do
			for _ = 1, group.Count do
				table.insert(enemies, { EnemyId = group.EnemyId, MiniBoss = false })
			end
		end
	end
	if stage.MiniBoss then
		table.insert(enemies, { EnemyId = stage.MiniBoss.EnemyId, MiniBoss = true })
	end
	return enemies
end

-- Ce que le joueur sait pendant la préparation : quels ennemis et combien, jamais leur position.
function ArenaRules.summarize(stage: any): { EnemySummary }
	local summary: { EnemySummary } = {}
	local index: { [string]: EnemySummary } = {}
	for _, enemy in ArenaRules.expandEnemies(stage) do
		local key = `{enemy.EnemyId}|{enemy.MiniBoss}`
		local entry = index[key]
		if entry then
			entry.Count += 1
		else
			entry = { EnemyId = enemy.EnemyId, Count = 1, MiniBoss = enemy.MiniBoss }
			index[key] = entry
			table.insert(summary, entry)
		end
	end
	return summary
end

local function count(formation: Formation): number
	local n = 0
	for _ in formation do
		n += 1
	end
	return n
end

local function isSlot(slot: any): boolean
	return typeof(slot) == "number" and slot >= 1 and slot <= ArenaRules.GRID_CELLS and slot % 1 == 0
end
ArenaRules.isSlot = isSlot

-- Case où un exemplaire est posé, ou nil.
function ArenaRules.slotOf(formation: Formation, instanceId: string): number?
	for slot, placed in formation do
		if placed == instanceId then
			return slot
		end
	end
	return nil
end

-- Pose un exemplaire (déjà vérifié par l'appelant) sur une case. Un exemplaire n'est posé qu'une
-- fois : s'il l'est déjà ailleurs, il est déplacé ; si la case est occupée, son héros est remplacé.
-- La limite ne compte que les nouveaux héros. Modifie formation.
function ArenaRules.assign(formation: Formation, slot: any, instanceId: any, maxHeroes: number): (boolean, string?)
	if not isSlot(slot) then
		return false, "case invalide"
	end
	if typeof(instanceId) ~= "string" or instanceId == "" then
		return false, "héros inconnu"
	end
	local previousSlot = ArenaRules.slotOf(formation, instanceId)
	if previousSlot == slot then
		return true, nil
	end
	if not previousSlot and not formation[slot] and count(formation) >= maxHeroes then
		return false, `{maxHeroes} héros maximum`
	end
	if previousSlot then
		formation[previousSlot] = nil
	end
	formation[slot] = instanceId
	return true, nil
end

-- Vide une case (sans effet si elle est déjà vide).
function ArenaRules.clear(formation: Formation, slot: any): (boolean, string?)
	if not isSlot(slot) then
		return false, "case invalide"
	end
	formation[slot] = nil
	return true, nil
end

function ArenaRules.count(formation: Formation): number
	return count(formation)
end

-- Positions au sol (x, z) : la hauteur ne compte pas.
export type Point = { x: number, z: number }
export type Zone = { center: Point, radius: number }

local function flatDistance(a: Point, b: Point): number
	local dx, dz = a.x - b.x, a.z - b.z
	return math.sqrt(dx * dx + dz * dz)
end

-- Zone de préparation d'une arène : cercle autour de ses dalles, plus une marge.
function ArenaRules.zone(poses: { [number]: Point }, margin: number): Zone?
	local sx, sz, n = 0, 0, 0
	for _, p in poses do
		sx += p.x
		sz += p.z
		n += 1
	end
	if n == 0 then
		return nil
	end
	local center = { x = sx / n, z = sz / n }
	local radius = 0
	for _, p in poses do
		radius = math.max(radius, flatDistance(p, center))
	end
	return { center = center, radius = radius + margin }
end

-- Le joueur peut-il agir sur SON arène ? Il doit être dans sa zone de préparation et, pour une
-- dalle précise, à portée de cette dalle. (L'arène visée est toujours celle de son propre plot.)
function ArenaRules.canInteract(position: Point?, zone: Zone?, pose: Point?, reach: number): (boolean, string?)
	if not position or not zone then
		return false, "Approche-toi de ton arène"
	end
	if flatDistance(position, zone.center) > zone.radius then
		return false, "Approche-toi de ton arène"
	end
	if pose and flatDistance(position, pose) > reach then
		return false, "Approche-toi de la dalle"
	end
	return true, nil
end

-- Sélection du stage (pancarte, fenêtre Expédition). stages = ZoneService:ListStages (zone puis stage,
-- avec Status et Cleared) ; aucune donnée sauvegardée : la sélection se déduit de la progression.
export type StageEntry = { Zone: number, Stage: number, Status: string, Cleared: boolean }

-- Stage proposé sans choix du joueur : le premier stage débloqué pas encore terminé, sinon le dernier
-- stage débloqué (tout est terminé), sinon nil (aucun stage jouable).
function ArenaRules.defaultStage(stages: { StageEntry }): (number?, number?)
	local last: StageEntry? = nil
	for _, entry in stages do
		if entry.Status == "Unlocked" then
			if not entry.Cleared then
				return entry.Zone, entry.Stage
			end
			last = entry
		end
	end
	if last then
		return last.Zone, last.Stage
	end
	return nil, nil
end

-- Après une victoire sur (zone, stage) : le stage suivant de la liste s'il est débloqué (1-1 → 1-2 …),
-- sinon le même (dernier stage : pas de 1-6). Ne lance jamais rien : seulement le stage sélectionné.
function ArenaRules.nextStage(stages: { StageEntry }, zone: number, stage: number): (number, number)
	for index, entry in stages do
		if entry.Zone == zone and entry.Stage == stage then
			local following = stages[index + 1]
			if following and following.Status == "Unlocked" then
				return following.Zone, following.Stage
			end
			break
		end
	end
	return zone, stage
end

-- Prochain objectif du joueur (#120, voir docs/ZONES.md § Prochain objectif). normal / elite = listes de
-- ListStages (zone puis stage) avec Loot = true si le stage a une table de loot (LootConfig) : un stage sans
-- butin (Zone 2 tant que #115 n'est pas livrée) n'est jamais proposé, mais reste jouable s'il est choisi.
--   "Normal"   : premier stage Normal débloqué, non terminé, avec butin ;
--   "EliteNew" : sinon premier stage Élite débloqué, non terminé, avec butin, aucun stage Élite encore gagné
--                (l'Élite vient d'être débloquée) ;
--   "Elite"    : même chose, avec au moins un stage Élite déjà gagné ;
--   "Farm"     : tout ce qui a du butin est terminé : le dernier stage Élite terminé avec butin (meilleure
--                source), sinon le dernier stage Normal terminé avec butin. Rien d'inédit n'est promis.
-- nil : aucun stage avec butin n'est débloqué (config de loot absente) ; l'appelant garde defaultStage.
export type ObjectiveEntry = StageEntry & { Loot: boolean? }
export type Objective = { Kind: string, Mode: string, Zone: number, Stage: number }

function ArenaRules.objective(normal: { ObjectiveEntry }, elite: { ObjectiveEntry }): Objective?
	for _, entry in normal do
		if entry.Status == "Unlocked" and not entry.Cleared and entry.Loot then
			return { Kind = "Normal", Mode = "Normal", Zone = entry.Zone, Stage = entry.Stage }
		end
	end
	local started = false
	for _, entry in elite do
		if entry.Cleared then
			started = true
		end
	end
	for _, entry in elite do
		if entry.Status == "Unlocked" and not entry.Cleared and entry.Loot then
			return { Kind = if started then "Elite" else "EliteNew", Mode = "Elite", Zone = entry.Zone, Stage = entry.Stage }
		end
	end
	local function farm(list: { ObjectiveEntry }, mode: string): Objective?
		for index = #list, 1, -1 do
			local entry = list[index]
			if entry.Status == "Unlocked" and entry.Cleared and entry.Loot then
				return { Kind = "Farm", Mode = mode, Zone = entry.Zone, Stage = entry.Stage }
			end
		end
		return nil
	end
	return farm(elite, "Elite") or farm(normal, "Normal")
end

-- Stage sélectionné après une victoire sur (mode, zone, stage) : le prochain objectif s'il reste un stage à
-- gagner (jamais un stage déjà terminé quand un objectif existe, jamais une zone sans butin) ; tout est
-- terminé (Farm) : le même stage, pour le rejouer. Sans objectif (pas de loot) : nextStage dans le même mode.
function ArenaRules.afterVictory(normal: { ObjectiveEntry }, elite: { ObjectiveEntry }, mode: string, zone: number, stage: number): (string, number, number)
	local objective = ArenaRules.objective(normal, elite)
	if objective and objective.Kind ~= "Farm" then
		return objective.Mode, objective.Zone, objective.Stage
	end
	if objective then
		return mode, zone, stage
	end
	local nextZone, nextStage = ArenaRules.nextStage(if mode == "Elite" then elite else normal, zone, stage)
	return mode, nextZone, nextStage
end

return ArenaRules
