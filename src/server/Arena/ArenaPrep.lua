--!strict
-- Préparation de chaque arène personnelle, sans API Roblox (voir docs/ARENA_PROTOTYPE.md) : testé par
-- tools/test-arena.ps1. ArenaService s'occupe du monde (modèles, prompt, remotes) et lui passe
-- ses dépendances (ZoneService, HeroService, CombatService).
--
-- Flow : le joueur pose ses héros sur les dalles de SON arène (Place / Remove, via E près d'une
-- dalle). Le premier héros posé lance la session de stage. Le bouton Prêt (Ready) démarre le
-- combat. Retirer le dernier héros annule la session de stage.

local ArenaRules = require(script.Parent.ArenaRules)

export type Phase = "Placement" | "Combat"
export type Prep = {
	player: any,
	sessionId: number,
	phase: Phase,
	formation: ArenaRules.Formation,
	combatId: number?,
}
export type Deps = {
	maxHeroes: number,
	name: (player: any) -> string,
	-- Session de stage : lancement, validité, annulation (ZoneService).
	startStage: (player: any) -> (number?, string?),
	sessionAlive: (player: any, sessionId: number) -> boolean,
	cancelStage: (player: any) -> (),
	-- HeroId d'un exemplaire possédé et utilisable au combat (HeroService).
	heroOf: (player: any, instanceId: any) -> (string?, string?),
	-- Combat (CombatService) : formation case -> HeroId.
	startCombat: (player: any, sessionId: number, classes: { [number]: string }) -> (number?, string?),
	cancelCombat: (player: any) -> (),
}
export type Manager = {
	preps: { [any]: Prep },
	place: (self: Manager, player: any, slot: any, instanceId: any) -> (boolean, string?),
	remove: (self: Manager, player: any, slot: any) -> (boolean, string?),
	ready: (self: Manager, player: any) -> (boolean, string?),
	leave: (self: Manager, player: any) -> boolean,
	combatEnded: (self: Manager, player: any, combatId: number) -> boolean,
	release: (self: Manager, player: any) -> boolean,
	check: (self: Manager, player: any) -> boolean,
}

local ArenaPrep = {}

function ArenaPrep.new(deps: Deps): Manager
	local manager = {} :: Manager
	manager.preps = {}

	local function drop(prep: Prep, cancelStage: boolean)
		if manager.preps[prep.player] == prep then
			manager.preps[prep.player] = nil
			if cancelStage then
				deps.cancelStage(prep.player)
			end
		end
	end

	-- Préparation encore valable ? (session de stage perdue : on libère l'arène)
	local function live(player: any): Prep?
		local prep = manager.preps[player]
		if prep and not deps.sessionAlive(prep.player, prep.sessionId) then
			drop(prep, false)
			return nil
		end
		return manager.preps[player]
	end


	function manager:place(player: any, slot: any, instanceId: any): (boolean, string?)
		local prep = live(player)
		if prep and prep.phase ~= "Placement" then
			return false, "combat déjà lancé"
		end
		if not ArenaRules.isSlot(slot) then
			return false, "case invalide"
		end
		local heroId, reason = deps.heroOf(player, instanceId)
		if not heroId then
			return false, reason or "héros inconnu"
		end
		if not prep then
			-- Premier héros posé : la préparation prépare son arène et lance la session de stage.
			local sessionId, why = deps.startStage(player)
			if not sessionId then
				return false, why or "stage indisponible"
			end
			local created: Prep = { player = player, sessionId = sessionId, phase = "Placement", formation = {}, combatId = nil }
			manager.preps[player] = created
			prep = created
		end
		local target = prep :: Prep
		local ok, why = ArenaRules.assign(target.formation, slot, instanceId, deps.maxHeroes)
		if not ok and ArenaRules.count(target.formation) == 0 then
			drop(target, true)
		end
		return ok, why
	end

	function manager:remove(player: any, slot: any): (boolean, string?)
		local prep = live(player)
		if not prep or prep.player ~= player then
			return false, "aucun héros posé"
		end
		if prep.phase ~= "Placement" then
			return false, "combat déjà lancé"
		end
		if not ArenaRules.isSlot(slot) or not prep.formation[slot] then
			return false, "case vide"
		end
		ArenaRules.clear(prep.formation, slot)
		if ArenaRules.count(prep.formation) == 0 then
			drop(prep, true) -- plus aucun héros : l'arène est libre, la session de stage annulée
		end
		return true, nil
	end

	-- Bouton Prêt : la formation est verrouillée et le combat démarre (1 à 4 héros).
	function manager:ready(player: any): (boolean, string?)
		local prep = live(player)
		if not prep then
			return false, "Place au moins un héros"
		end
		if prep.phase ~= "Placement" then
			return false, "combat déjà lancé"
		end
		local count = ArenaRules.count(prep.formation)
		if count == 0 then
			return false, "Place au moins un héros"
		end
		if count > deps.maxHeroes then
			return false, `{deps.maxHeroes} héros maximum`
		end
		local classes: { [number]: string } = {}
		for slot, instanceId in prep.formation do
			local heroId, reason = deps.heroOf(player, instanceId)
			if not heroId then
				return false, reason or "héros inconnu"
			end
			classes[slot] = heroId
		end
		local combatId, reason = deps.startCombat(player, prep.sessionId, classes)
		if not combatId then
			return false, reason
		end
		prep.phase = "Combat"
		prep.combatId = combatId
		return true, nil
	end

	-- Quitter (bouton X) : combat arrêté sans résultat, session de stage annulée.
	function manager:leave(player: any): boolean
		local prep = manager.preps[player]
		if not prep or prep.player ~= player then
			return false
		end
		deps.cancelCombat(player)
		drop(prep, true)
		return true
	end

	-- Fin du combat : ZoneService a déjà reçu le résultat ; l'arène est libérée.
	function manager:combatEnded(player: any, combatId: number): boolean
		local prep = manager.preps[player]
		if not prep or prep.player ~= player or prep.combatId ~= combatId then
			return false
		end
		drop(prep, false)
		return true
	end

	-- Départ du joueur : l'arène est libérée (ZoneService gère sa propre session).
	function manager:release(player: any): boolean
		local prep = manager.preps[player]
		if not prep or prep.player ~= player then
			return false
		end
		drop(prep, false)
		return true
	end

	-- Vérification périodique : true si la préparation a été libérée (session de stage perdue).
	function manager:check(player: any): boolean
		local before = manager.preps[player]
		return before ~= nil and live(player) == nil
	end

	return manager
end

return ArenaPrep
