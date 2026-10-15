--!strict
-- État de présentation d'un combat, côté client (voir docs/COMBAT_PRESENTATION.md). Module pur, testé
-- (tools/test-presentation.ps1) : aucune Instance, aucune autorité de jeu. Le serveur revérifie tout
-- (Ready : stage, équipe, plot, combat déjà actif) ; ce module empêche seulement les doublons visuels.
--
--   Idle ─arm─▶ WaitingForArenaEntry ─enterArena─▶ EnemyIntro ─introDone─▶ AwaitingDefense
--   AwaitingDefense ─defend─▶ (Ready en cours) ─ok─▶ Combat ─ended─▶ Reward ─rewardClosed─▶ Idle
--   cancel (Quitter, changement de stage, arène fermée) : Cleanup puis Idle, depuis n'importe où.
-- Chaque armement a une génération : une tâche d'intro d'une génération passée ne peut plus rien faire.

export type State = "Idle" | "WaitingForArenaEntry" | "EnemyIntro" | "AwaitingDefense" | "Combat" | "Reward" | "Cleanup"

export type Flow = {
	state: State,
	generation: number,
	stageKey: string?,
	pending: boolean, -- Ready envoyé, réponse attendue
	arm: (self: Flow, stageKey: string) -> boolean,
	enterArena: (self: Flow) -> number?,
	introDone: (self: Flow, generation: number) -> boolean,
	canDefend: (self: Flow, inArena: boolean, teamSize: number) -> boolean,
	defend: (self: Flow, inArena: boolean, teamSize: number) -> boolean,
	defendResult: (self: Flow, ok: boolean) -> (),
	combatStarted: (self: Flow) -> (),
	combatEnded: (self: Flow) -> (),
	rewardClosed: (self: Flow) -> (),
	cancel: (self: Flow) -> boolean,
	stageChanged: (self: Flow, stageKey: string?) -> boolean,
	current: (self: Flow, generation: number) -> boolean,
}

local PresentationFlow = {}

function PresentationFlow.new(): Flow
	local flow = { state = "Idle", generation = 0, stageKey = nil, pending = false } :: Flow

	-- « Lancer » (fenêtre des stages) : prépare la défense de ce stage. Sans effet si déjà armé pour ce
	-- stage (pas de double intro) ou pendant un combat.
	function flow:arm(stageKey: string): boolean
		if self.state == "Combat" or self.state == "Reward" then
			return false
		end
		if self.stageKey == stageKey and self.state ~= "Idle" and self.state ~= "Cleanup" then
			return false
		end
		self.generation += 1
		self.stageKey = stageKey
		self.pending = false
		self.state = "WaitingForArenaEntry"
		return true
	end

	-- Le joueur entre dans SON arène : l'intro démarre une seule fois. Renvoie sa génération.
	function flow:enterArena(): number?
		if self.state ~= "WaitingForArenaEntry" then
			return nil
		end
		self.state = "EnemyIntro"
		return self.generation
	end

	-- Fin de l'intro (tous les ennemis en place) : seulement si l'intro est encore celle en cours.
	function flow:introDone(generation: number): boolean
		if self.state ~= "EnemyIntro" or generation ~= self.generation then
			return false
		end
		self.state = "AwaitingDefense"
		return true
	end

	-- Le CTA « Défendre la base » n'existe qu'en AwaitingDefense, joueur dans son arène, 1 héros au moins.
	function flow:canDefend(inArena: boolean, teamSize: number): boolean
		return self.state == "AwaitingDefense" and not self.pending and inArena and teamSize >= 1
	end

	-- E / clic / toucher : un seul Ready à la fois.
	function flow:defend(inArena: boolean, teamSize: number): boolean
		if not self:canDefend(inArena, teamSize) then
			return false
		end
		self.pending = true
		return true
	end

	-- Réponse du serveur à Ready : refus → le CTA revient ; accord → combat.
	function flow:defendResult(ok: boolean)
		if not self.pending then
			return
		end
		self.pending = false
		if ok and self.state == "AwaitingDefense" then
			self.state = "Combat"
		end
	end

	-- Le serveur annonce un combat (phase Combat) : quel que soit le chemin, plus de CTA ni d'intro.
	function flow:combatStarted()
		self.pending = false
		self.state = "Combat"
	end

	function flow:combatEnded()
		if self.state == "Combat" then
			self.state = "Reward"
		end
	end

	-- Écran de fin fermé : tout est nettoyé, la défense suivante se relance depuis la pancarte.
	function flow:rewardClosed()
		if self.state == "Reward" or self.state == "Combat" then
			self.generation += 1
			self.stageKey = nil
			self.state = "Idle"
		end
	end

	-- Quitter / arène fermée : Cleanup (le contrôleur détruit intro, CTA, sac), puis Idle.
	function flow:cancel(): boolean
		if self.state == "Idle" then
			return false
		end
		self.state = "Cleanup"
		self.generation += 1
		self.pending = false
		self.stageKey = nil
		self.state = "Idle"
		return true
	end

	-- Le stage du serveur change pendant une présentation : l'ancienne intro est annulée.
	function flow:stageChanged(stageKey: string?): boolean
		if self.stageKey ~= nil and stageKey ~= self.stageKey and self.state ~= "Combat" and self.state ~= "Reward" then
			return self:cancel()
		end
		return false
	end

	function flow:current(generation: number): boolean
		return generation == self.generation
	end

	return flow
end

return PresentationFlow
