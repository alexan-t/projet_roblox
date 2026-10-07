--!strict
-- Moteur de combat pur (voir docs/COMBAT.md). Aucune API Roblox : testé par tools/test-combat.ps1.
-- L'état est une table ; le moteur avance par pas fixes (step) et produit des événements.
-- Tout est déterministe : les unités agissent dans l'ordre de leur UnitId, les égalités de
-- ciblage sont tranchées par UnitId, et le seul hasard (cases des ennemis) vient de l'objet
-- Random fourni.
-- Aucune action joueur pendant le combat : l'ultime d'un héros part automatiquement quand sa
-- jauge est pleine et qu'il a une cible.

export type Vec = { x: number, z: number }
export type Stats = {
	MaxHealth: number,
	AttackDamage: number,
	AttackInterval: number,
	AttackRange: number,
	MoveSpeed: number,
	EnergyPerAttack: number?,
	MaxEnergy: number?,
	UltimateDamage: number?,
}
export type Team = "Ally" | "Enemy"
export type Unit = {
	UnitId: number,
	Team: Team,
	TypeId: string,
	Health: number,
	MaxHealth: number,
	Energy: number,
	MaxEnergy: number,
	TargetId: number?,
	Position: Vec,
	Alive: boolean,
	Slot: number?,
	Cell: number?,
	MiniBoss: boolean,
	stats: Stats,
	nextAttackAt: number,
	moving: boolean,
}
export type Event = { [string]: any }
export type Result = "Victory" | "Defeat"
export type Options = {
	Stage: any, -- { Waves = { { Enemies = { { EnemyId, Count } } } }, MiniBoss = { EnemyId }? }
	Heroes: { [string]: Stats },
	Enemies: { [string]: Stats },
	UltimateRadius: number,
	Allies: { { TypeId: string, Slot: number, Position: Vec } },
	EnemyCells: { [number]: Vec },
	Random: any, -- objet avec NextInteger(min, max) (Random Roblox en jeu)
	TickRate: number,
	MaxFrameTime: number,
}
export type State = {
	time: number,
	accumulator: number,
	fixedDt: number,
	maxFrameTime: number,
	units: { Unit },
	byId: { [number]: Unit },
	nextUnitId: number,
	events: { Event },
	moved: { [number]: boolean },
	waves: { any },
	waveIndex: number,
	miniBoss: any?,
	miniBossStarted: boolean,
	result: Result?,
	options: Options,
}

local CombatEngine = {}

local EPSILON = 1e-9
-- Nombre maximal de pas simulés par frame, par unité de vitesse (x2 = deux fois plus).
local MAX_STEPS_PER_SPEED = 10

local function distance(a: Vec, b: Vec): number
	local dx, dz = a.x - b.x, a.z - b.z
	return math.sqrt(dx * dx + dz * dz)
end

local function emit(state: State, event: Event)
	table.insert(state.events, event)
end

local function spawnUnit(state: State, team: Team, typeId: string, stats: Stats, position: Vec, slot: number?, cell: number?, miniBoss: boolean)
	state.nextUnitId += 1
	local maxEnergy = if team == "Ally" then stats.MaxEnergy or 0 else 0
	local unit: Unit = {
		UnitId = state.nextUnitId,
		Team = team,
		TypeId = typeId,
		Health = stats.MaxHealth,
		MaxHealth = stats.MaxHealth,
		Energy = 0,
		MaxEnergy = maxEnergy,
		TargetId = nil,
		Position = { x = position.x, z = position.z },
		Alive = true,
		Slot = slot,
		Cell = cell,
		MiniBoss = miniBoss,
		stats = stats,
		nextAttackAt = 0,
		moving = false,
	}
	table.insert(state.units, unit)
	state.byId[unit.UnitId] = unit
	emit(state, {
		Type = "UnitSpawned",
		UnitId = unit.UnitId,
		Team = team,
		TypeId = typeId,
		Slot = slot,
		Cell = cell,
		MiniBoss = miniBoss,
		X = unit.Position.x,
		Z = unit.Position.z,
		Health = unit.Health,
		MaxHealth = unit.MaxHealth,
		Energy = 0,
		MaxEnergy = maxEnergy,
	})
end

-- Place des ennemis sur des cases tirées au hasard, toutes différentes.
local function spawnEnemies(state: State, entries: { { EnemyId: string, MiniBoss: boolean } })
	local free: { number } = {}
	for cell in state.options.EnemyCells do
		table.insert(free, cell)
	end
	table.sort(free)
	for _, entry in entries do
		local pick = state.options.Random:NextInteger(1, #free)
		local cell = free[pick]
		table.remove(free, pick)
		local stats = state.options.Enemies[entry.EnemyId]
		spawnUnit(state, "Enemy", entry.EnemyId, stats, state.options.EnemyCells[cell], nil, cell, entry.MiniBoss)
	end
end

local function finish(state: State, result: Result)
	if state.result then
		return
	end
	state.result = result
	emit(state, { Type = "CombatEnded", Result = result })
end

-- Vague suivante, puis mini-boss, puis victoire.
local function startNext(state: State)
	if state.waveIndex < #state.waves then
		state.waveIndex += 1
		emit(state, { Type = "WaveStarted", Wave = state.waveIndex, WaveCount = #state.waves })
		local entries = {}
		for _, group in state.waves[state.waveIndex].Enemies do
			for _ = 1, group.Count do
				table.insert(entries, { EnemyId = group.EnemyId, MiniBoss = false })
			end
		end
		spawnEnemies(state, entries)
	elseif state.miniBoss and not state.miniBossStarted then
		state.miniBossStarted = true
		emit(state, { Type = "MiniBossStarted", EnemyId = state.miniBoss.EnemyId })
		spawnEnemies(state, { { EnemyId = state.miniBoss.EnemyId, MiniBoss = true } })
	else
		finish(state, "Victory")
	end
end

local function aliveCount(state: State, team: Team): number
	local n = 0
	for _, unit in state.units do
		if unit.Alive and unit.Team == team then
			n += 1
		end
	end
	return n
end

-- Ennemi vivant le plus proche ; à distance égale, le plus petit UnitId.
local function nearest(state: State, unit: Unit, from: Vec?): Unit?
	local origin = from or unit.Position
	local best: Unit? = nil
	local bestDistance = math.huge
	for _, other in state.units do
		if other.Alive and other.Health > 0 and other.Team ~= unit.Team then
			local d = distance(origin, other.Position)
			if d < bestDistance - EPSILON or (math.abs(d - bestDistance) <= EPSILON and best and other.UnitId < best.UnitId) then
				best, bestDistance = other, d
			end
		end
	end
	return best
end

local function damage(state: State, target: Unit, amount: number, sourceId: number): number
	if not target.Alive or target.Health <= 0 or amount <= 0 then
		return 0
	end
	local applied = math.min(target.Health, amount)
	target.Health = math.max(0, target.Health - amount)
	emit(state, { Type = "Damage", TargetId = target.UnitId, SourceId = sourceId, Amount = applied, Health = target.Health })
	return applied
end

local function gainEnergy(state: State, unit: Unit, amount: number)
	if unit.MaxEnergy <= 0 or amount <= 0 or unit.Energy >= unit.MaxEnergy then
		return
	end
	unit.Energy = math.min(unit.MaxEnergy, unit.Energy + amount)
	emit(state, { Type = "EnergyChanged", UnitId = unit.UnitId, Energy = unit.Energy, MaxEnergy = unit.MaxEnergy })
end

-- Morts traitées une seule fois, dans l'ordre des UnitId.
local function resolveDeaths(state: State)
	for _, unit in state.units do
		if unit.Alive and unit.Health <= 0 then
			unit.Alive = false
			unit.moving = false
			unit.TargetId = nil
			emit(state, { Type = "UnitDied", UnitId = unit.UnitId, Team = unit.Team, TypeId = unit.TypeId })
		end
	end
end

local function progress(state: State)
	if state.result then
		return
	end
	if aliveCount(state, "Ally") == 0 then
		finish(state, "Defeat")
	elseif aliveCount(state, "Enemy") == 0 then
		startNext(state)
	end
end

local function alive(unit: Unit?): boolean
	return unit ~= nil and unit.Alive and unit.Health > 0
end

-- Ultime générique, automatique : dégâts de zone autour de la cible, énergie remise à 0.
local function castUltimate(state: State, unit: Unit, target: Unit)
	unit.Energy = 0
	emit(state, { Type = "EnergyChanged", UnitId = unit.UnitId, Energy = 0, MaxEnergy = unit.MaxEnergy })
	local center = target.Position
	local hits: { number } = {}
	for _, other in state.units do
		if alive(other) and other.Team ~= unit.Team and distance(center, other.Position) <= state.options.UltimateRadius + EPSILON then
			table.insert(hits, other.UnitId)
		end
	end
	emit(state, { Type = "UltimateUsed", UnitId = unit.UnitId, TargetId = target.UnitId, Hits = hits })
	for _, id in hits do
		damage(state, state.byId[id], unit.stats.UltimateDamage or 0, unit.UnitId)
	end
end

-- Jauge pleine + cible vivante : l'ultime part tout seul (une fois par remplissage).
-- Sans cible (fin de vague), la jauge reste pleine jusqu'à la prochaine cible.
local function tryUltimate(state: State, unit: Unit): boolean
	if unit.MaxEnergy <= 0 or unit.Energy < unit.MaxEnergy then
		return false
	end
	local current = if unit.TargetId then state.byId[unit.TargetId] else nil
	local target = if current and alive(current) then current else nearest(state, unit)
	if not target then
		return false
	end
	if target.UnitId ~= unit.TargetId then
		unit.TargetId = target.UnitId
		emit(state, { Type = "TargetChanged", UnitId = unit.UnitId, TargetId = target.UnitId })
	end
	castUltimate(state, unit, target)
	return true
end

local function act(state: State, unit: Unit, dt: number)
	-- Jauge restée pleine faute de cible : l'ultime part dès qu'une cible existe, à la place d'une action.
	if tryUltimate(state, unit) then
		unit.moving = false
		return
	end
	local target = if unit.TargetId then state.byId[unit.TargetId] else nil
	if not target or not target.Alive or target.Health <= 0 then
		target = nearest(state, unit)
		local id = if target then target.UnitId else nil
		if id ~= unit.TargetId then
			unit.TargetId = id
			emit(state, { Type = "TargetChanged", UnitId = unit.UnitId, TargetId = id })
		end
	end
	if not target then
		unit.moving = false
		return
	end
	local stats = unit.stats
	local d = distance(unit.Position, target.Position)
	if d > stats.AttackRange + EPSILON then
		if stats.MoveSpeed <= 0 then
			unit.moving = false
			return
		end
		if not unit.moving then
			unit.moving = true
			emit(state, { Type = "MoveStarted", UnitId = unit.UnitId, TargetId = target.UnitId })
		end
		-- Avance en ligne droite, sans dépasser la portée d'attaque.
		local advance = math.min(stats.MoveSpeed * dt, d - stats.AttackRange)
		unit.Position = {
			x = unit.Position.x + (target.Position.x - unit.Position.x) / d * advance,
			z = unit.Position.z + (target.Position.z - unit.Position.z) / d * advance,
		}
		state.moved[unit.UnitId] = true
		return
	end
	unit.moving = false
	if state.time + EPSILON >= unit.nextAttackAt then
		unit.nextAttackAt = state.time + stats.AttackInterval
		emit(state, { Type = "Attack", UnitId = unit.UnitId, TargetId = target.UnitId })
		damage(state, target, stats.AttackDamage, unit.UnitId)
		gainEnergy(state, unit, stats.EnergyPerAttack or 0)
		tryUltimate(state, unit)
	end
end

function CombatEngine.new(options: Options): State
	local state: State = {
		time = 0,
		accumulator = 0,
		fixedDt = 1 / options.TickRate,
		maxFrameTime = options.MaxFrameTime,
		units = {},
		byId = {},
		nextUnitId = 0,
		events = {},
		moved = {},
		waves = options.Stage.Waves,
		waveIndex = 0,
		miniBoss = options.Stage.MiniBoss,
		miniBossStarted = false,
		result = nil,
		options = options,
	}
	emit(state, { Type = "CombatStarted" })
	local allies = table.clone(options.Allies)
	table.sort(allies, function(a: { Slot: number }, b: { Slot: number }): boolean
		return a.Slot < b.Slot
	end)
	for _, ally in allies do
		spawnUnit(state, "Ally", ally.TypeId, options.Heroes[ally.TypeId], ally.Position, ally.Slot, nil, false)
	end
	startNext(state)
	return state
end

-- Un pas fixe de simulation.
function CombatEngine.step(state: State, dt: number)
	if state.result then
		return
	end
	state.time += dt
	for _, unit in state.units do
		if unit.Alive and unit.Health > 0 then
			act(state, unit, dt)
		end
	end
	resolveDeaths(state)
	progress(state)
end

-- Temps réel écoulé -> pas fixes. speed (1 ou 2) multiplie le temps simulé, jamais les stats.
-- Un dt énorme (lag) est plafonné ; le retard au-delà de la limite de pas est abandonné.
function CombatEngine.advance(state: State, dt: number, speed: number): number
	if state.result then
		return 0
	end
	state.accumulator += math.clamp(dt, 0, state.maxFrameTime) * speed
	local steps = 0
	local limit = MAX_STEPS_PER_SPEED * speed
	while state.accumulator >= state.fixedDt - EPSILON and not state.result do
		if steps >= limit then
			state.accumulator = 0
			break
		end
		CombatEngine.step(state, state.fixedDt)
		state.accumulator -= state.fixedDt
		steps += 1
	end
	return steps
end

-- Événements produits depuis le dernier appel (dans l'ordre), et unités déplacées.
function CombatEngine.drain(state: State): ({ Event }, { [number]: boolean })
	local events, moved = state.events, state.moved
	state.events, state.moved = {}, {}
	return events, moved
end

return CombatEngine
