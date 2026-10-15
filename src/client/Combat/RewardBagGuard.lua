--!strict
-- Garde du sac de récompenses (voir docs/COMBAT_PRESENTATION.md). Module pur, testé. Le sac est un
-- retour VISUEL : il ne décide d'aucune récompense (RewardService, côté serveur, a déjà tout attribué).
-- Exactement un sac par combat gagné, à la position de mort du DERNIER ennemi ; jamais sur défaite ;
-- pas de doublon si les événements arrivent en rafale ou en plusieurs lots.

export type Guard = {
	lastDeath: { [number]: Vector3 },
	dropped: { [number]: boolean },
	observe: (self: Guard, combatId: number, events: { { [string]: any } }, positionOf: (unitId: number) -> Vector3?) -> Vector3?,
}

local RewardBagGuard = {}

function RewardBagGuard.new(): Guard
	local guard = { lastDeath = {}, dropped = {} } :: Guard

	-- Lit un lot d'événements du combat combatId. Renvoie la position du sac une seule fois, quand le
	-- combat se termine par une victoire et qu'un ennemi est mort dans ce combat.
	function guard:observe(combatId: number, events: { { [string]: any } }, positionOf: (unitId: number) -> Vector3?): Vector3?
		local drop: Vector3? = nil
		for _, event in events do
			if event.Type == "UnitDied" and event.Team == "Enemy" then
				local position = positionOf(event.UnitId)
				if position then
					self.lastDeath[combatId] = position
				end
			elseif event.Type == "CombatEnded" then
				local position = self.lastDeath[combatId]
				if event.Result == "Victory" and position and not self.dropped[combatId] then
					self.dropped[combatId] = true
					drop = position
				end
				self.lastDeath[combatId] = nil
			end
		end
		return drop
	end

	return guard
end

return RewardBagGuard
