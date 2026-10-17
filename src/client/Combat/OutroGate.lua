--!strict
-- Outro d'un combat, côté client (voir docs/COMBAT_PRESENTATION.md). Module pur, testé
-- (tools/test-presentation.ps1). Le serveur a déjà attribué et sauvegardé les récompenses au moment du
-- CombatEnded : on ne ralentit que leur PRÉSENTATION.
--   schedule : déroulé de l'outro (sac après la mort complète du dernier ennemi, rebond, respiration,
--              annonce « VICTOIRE ! », fin) à partir du déroulé de cette mort ;
--   gate     : l'écran de récompenses attend « outro terminée » (CombatOutroFinished) ; un délai de
--              sécurité l'ouvre quoi qu'il arrive ; une seule ouverture par combat.

export type Death = { bagAt: number?, completeAt: number? } -- instants (horloge) du dernier ennemi
export type OutroConfig = { BagBounce: number, Breather: number, VictoryHold: number, DefeatHold: number, Safety: number }
export type Schedule = {
	bagAt: number?, -- sac (victoire seulement)
	victoryAt: number?, -- annonce « VICTOIRE ! » (victoire seulement)
	finishAt: number, -- outro terminée : l'écran de récompenses peut s'ouvrir
}

export type Gate = {
	pending: { [number]: { payload: any, since: number } },
	finished: { [number]: boolean },
	shown: { [number]: boolean },
	ended: (self: Gate, combatId: number, payload: any, now: number) -> any?,
	outroFinished: (self: Gate, combatId: number) -> any?,
	expired: (self: Gate, now: number, safety: number) -> { { combatId: number, payload: any } },
	clear: (self: Gate) -> (),
}

local OutroGate = {}

-- Déroulé de l'outro. now = arrivée du CombatEnded ; death = déroulé de la mort du dernier ennemi.
function OutroGate.schedule(victory: boolean, death: Death?, now: number, config: OutroConfig): Schedule
	if not victory then
		local after = math.max(now, death and death.completeAt or now)
		return { bagAt = nil, victoryAt = nil, finishAt = after + config.DefeatHold }
	end
	local bagAt = math.max(now, death and death.bagAt or now)
	local victoryAt = bagAt + config.BagBounce + config.Breather
	return { bagAt = bagAt, victoryAt = victoryAt, finishAt = victoryAt + config.VictoryHold }
end

function OutroGate.new(): Gate
	local gate = { pending = {}, finished = {}, shown = {} } :: Gate

	-- CombatEnded reçu : données gardées. Renvoie le payload si l'outro était déjà finie (ordre inversé).
	function gate:ended(combatId: number, payload: any, now: number): any?
		if self.shown[combatId] then
			return nil
		end
		if self.finished[combatId] then
			self.shown[combatId] = true
			self.finished[combatId] = nil
			return payload
		end
		self.pending[combatId] = { payload = payload, since = now }
		return nil
	end

	-- Outro terminée : renvoie le payload à montrer (une seule fois), sinon s'en souvient.
	function gate:outroFinished(combatId: number): any?
		if self.shown[combatId] then
			return nil
		end
		local entry = self.pending[combatId]
		if not entry then
			self.finished[combatId] = true
			return nil
		end
		self.pending[combatId] = nil
		self.shown[combatId] = true
		return entry.payload
	end

	-- Sécurité : combats dont l'outro n'a pas répondu à temps ; ouverts une fois, jamais deux.
	function gate:expired(now: number, safety: number): { { combatId: number, payload: any } }
		local due = {}
		for combatId, entry in self.pending do
			if now - entry.since >= safety then
				table.insert(due, { combatId = combatId, payload = entry.payload })
			end
		end
		for _, item in due do
			self.pending[item.combatId] = nil
			self.shown[item.combatId] = true
		end
		return due
	end

	function gate:clear()
		table.clear(self.pending)
		table.clear(self.finished)
	end

	return gate
end

return OutroGate
