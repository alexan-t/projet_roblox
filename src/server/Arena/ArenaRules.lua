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

return ArenaRules
