--!strict
-- Règles pures de la préparation de combat (PROTOTYPE, voir docs/ARENA_PROTOTYPE.md).
-- Aucune API Roblox : testé par tools/test-arena.ps1.

export type Enemy = { EnemyId: string, MiniBoss: boolean }
export type EnemySummary = { EnemyId: string, Count: number, MiniBoss: boolean }
-- Formation des héros : case (1..9) -> classe.
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

-- Tire une case différente (1..cells) pour chaque ennemi. Nouveau tirage à chaque combat.
-- random : un Random Roblox (ou tout objet avec NextInteger(min, max) pour les tests).
function ArenaRules.randomLayout(enemies: { Enemy }, cells: number, random: any): ({ [number]: Enemy }?, string?)
	if #enemies > cells then
		return nil, `{#enemies} ennemis pour {cells} cases`
	end
	local free: { number } = {}
	for cell = 1, cells do
		table.insert(free, cell)
	end
	local layout: { [number]: Enemy } = {}
	for _, enemy in enemies do
		local pick = random:NextInteger(1, #free)
		layout[free[pick]] = enemy
		table.remove(free, pick)
	end
	return layout, nil
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

-- Attribue une classe à une case. Une seule unité par classe : si la classe est déjà posée
-- ailleurs, elle est déplacée ; si la case est occupée, son héros est remplacé.
-- La limite ne compte que les nouveaux héros. Modifie formation.
function ArenaRules.assign(formation: Formation, slot: any, classId: any, validClasses: { [string]: boolean }, maxHeroes: number): (boolean, string?)
	if not isSlot(slot) then
		return false, "case invalide"
	end
	if typeof(classId) ~= "string" or not validClasses[classId] then
		return false, "classe inconnue"
	end
	local previousSlot: number? = nil
	for other, placed in formation do
		if placed == classId then
			previousSlot = other
		end
	end
	if previousSlot == slot then
		return true, nil
	end
	if not previousSlot and not formation[slot] and count(formation) >= maxHeroes then
		return false, `{maxHeroes} héros maximum`
	end
	if previousSlot then
		formation[previousSlot] = nil
	end
	formation[slot] = classId
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

return ArenaRules
