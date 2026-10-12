--!strict
-- Écran modal ouvert côté client (un seul à la fois) : évite les superpositions incohérentes
-- (fenêtre des stages + invocation, écran de fin pendant une invocation…). Pas de framework :
-- un nom d'écran, open / close, et un signal pour réactiver les prompts quand tout est fermé.
--   "Stage"  : fenêtre des stages (pancarte de l'arène) ;
--   "Summon" : invocation (fenêtre, cinématique, carte du héros) ;
--   "Reward" : écran de fin de combat.

local ScreenState = {}

local current: string? = nil
ScreenState.changed = Instance.new("BindableEvent")

-- Ouvre l'écran `name` si aucun autre n'est ouvert. Renvoie true si `name` est (ou était) l'écran ouvert.
function ScreenState.open(name: string): boolean
	if current ~= nil and current ~= name then
		return false
	end
	if current ~= name then
		current = name
		ScreenState.changed:Fire(current)
	end
	return true
end

function ScreenState.close(name: string)
	if current == name then
		current = nil
		ScreenState.changed:Fire(nil)
	end
end

function ScreenState.current(): string?
	return current
end

function ScreenState.free(): boolean
	return current == nil
end

-- Attend que plus aucun écran ne soit ouvert, puis ouvre `name` (ex. l'écran de fin d'un combat
-- terminé pendant une invocation : il s'affiche après la carte du héros).
function ScreenState.waitAndOpen(name: string)
	while not ScreenState.open(name) do
		ScreenState.changed.Event:Wait()
	end
end

return ScreenState
