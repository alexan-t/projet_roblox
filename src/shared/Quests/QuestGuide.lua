--!strict
-- Guidage de quête (voir docs/QUESTS.md § Guidage). Module pur, partagé :
--   • le serveur (QuestService) n'accepte dans QuestConfig que des cibles connues (Guide.Target) ;
--   • le client (QuestGuideController) résout la cible dans le plot DU JOUEUR et décide quand montrer
--     le chemin lumineux. Aucune donnée de jeu ici, aucune Instance créée.
--
-- Une cible = un chemin d'enfants depuis le modèle du plot (jamais Workspace.PlotTravail, jamais un autre
-- plot) ; Focus = enfant de la cible vers lequel le chemin mène (sinon son pivot) ; Arrive = distance
-- (studs) à laquelle le chemin s'efface et l'interaction normale prend le relais. Aucune pancarte : la
-- cible elle-même pulse (WorldPulse).

export type Target = { Path: { string }, Focus: string?, Arrive: number }

local QuestGuide = {}

QuestGuide.Targets = table.freeze({
	-- Pancarte du stage, à l'entrée de l'arène (E : choisir un stage, lancer).
	StageSign = table.freeze({ Path = table.freeze({ "Arene", "PanneauStage" }), Focus = "Banniere", Arrive = 10 }),
	-- Portail d'invocation du plot.
	SummonPortal = table.freeze({ Path = table.freeze({ "PortailInvocation" }), Arrive = 12 }),
	-- Royaume du plot.
	Kingdom = table.freeze({ Path = table.freeze({ "Royaume" }), Arrive = 14 }),
	-- Dalles de placement des héros de l'arène.
	HeroPlacement = table.freeze({ Path = table.freeze({ "Arene", "Emplacements", "Heros" }), Arrive = 8 }),
} :: { [string]: Target })

function QuestGuide.isTarget(name: any): boolean
	return typeof(name) == "string" and QuestGuide.Targets[name] ~= nil
end

-- Cible résolue DANS le plot donné : (objet mis en évidence, partie visée par le chemin) ou nil.
-- plot doit être le plot du joueur local (PlotView.plot()) : on ne cherche jamais ailleurs.
function QuestGuide.resolve(plot: any, name: any): (any, any)
	if not plot or not QuestGuide.isTarget(name) then
		return nil, nil
	end
	local target = QuestGuide.Targets[name]
	local node = plot
	for _, child in target.Path do
		node = node:FindFirstChild(child)
		if not node then
			return nil, nil
		end
	end
	local focus = if target.Focus then node:FindFirstChild(target.Focus) else nil
	return node, focus or node
end

export type Context = {
	target: string?, -- GuideTarget de la quête active (nil : rien à guider)
	completed: boolean?, -- quête terminée (à réclamer) : plus de chemin
	combat: boolean, -- combat en cours
	presentation: string?, -- état de la mise en scène (EnemyIntro, AwaitingDefense...)
	screen: string?, -- écran modal ouvert (Reward, Summon, Stage...)
	distance: number?, -- distance joueur → cible (nil : inconnue, joueur absent)
}

-- "Hidden" : rien ; "Path" : chemin + cible ; "Near" : cible seulement (le joueur est arrivé).
function QuestGuide.mode(context: Context): string
	if not QuestGuide.isTarget(context.target) or context.completed then
		return "Hidden"
	end
	if context.combat or context.screen ~= nil then
		return "Hidden"
	end
	local presentation = context.presentation
	if presentation == "EnemyIntro" or presentation == "AwaitingDefense" or presentation == "Combat" or presentation == "Reward" then
		return "Hidden"
	end
	local distance = context.distance
	if not distance then
		return "Hidden"
	end
	if distance <= QuestGuide.Targets[context.target :: string].Arrive then
		return "Near"
	end
	return "Path"
end

-- Points régulièrement espacés le long d'une polyligne, à partir de `skip` studs du départ, au plus
-- `count` points (chevrons devant le joueur). Chaque point porte la direction du segment. Pur.
export type Mark = { position: Vector3, direction: Vector3 }
function QuestGuide.sample(points: { Vector3 }, spacing: number, skip: number, count: number): { Mark }
	local marks: { Mark } = {}
	local travelled = 0
	local nextAt = skip
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local segment = b - a
		local length = segment.Magnitude
		if length > 1e-3 then
			local direction = segment / length
			while nextAt <= travelled + length and #marks < count do
				table.insert(marks, { position = a + direction * (nextAt - travelled), direction = direction })
				nextAt += spacing
			end
		end
		travelled += length
		if #marks >= count then
			break
		end
	end
	return marks
end

return QuestGuide
