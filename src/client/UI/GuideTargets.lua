--!strict
-- Cibles logiques de l'interface pour le guidage du tutoriel (voir docs/TUTORIAL_GUIDANCE.md).
-- Chaque vue enregistre ELLE-MÊME ses éléments importants sous un nom stable (« Zone.Element ») ; le
-- guidage (TutorialController, GuidePointer) ne connaît que ces noms : jamais de coordonnées, jamais de
-- chemin dans PlayerGui. Un élément détruit est oublié automatiquement.
-- Les vues signalent aussi leur ouverture / fermeture (opened / closed) : le guidage de première
-- ouverture s'y branche sans que la vue dépende d'un contrôleur.
-- API :
--   GuideTargets.register(id, gui, hint?) -- remplace l'ancienne cible du même nom ; hint : légende proposée
--                                    par la vue quand l'étape n'en donne pas (ex. l'action possible)
--   GuideTargets.hint(id) -> string?
--   GuideTargets.unregister(id, gui?) -- oublie la cible (seulement si c'est encore `gui`, s'il est donné)
--   GuideTargets.get(id) -> GuiObject? -- seulement si elle est affichée (ancêtres visibles, écran actif)
--   GuideTargets.open(key) / GuideTargets.close(key) -- interface ouverte / fermée (drapeau TutorialConfig)
--   GuideTargets.changed, GuideTargets.opened (key), GuideTargets.closed (key) : BindableEvent

local GuideTargets = {}

local targets: { [string]: GuiObject } = {}
local hints: { [string]: string } = {}
local openScreens: { [string]: boolean } = {}

GuideTargets.changed = Instance.new("BindableEvent")
GuideTargets.opened = Instance.new("BindableEvent")
GuideTargets.closed = Instance.new("BindableEvent")

function GuideTargets.register(id: string, gui: GuiObject, hint: string?)
	if hint then
		hints[id] = hint
	else
		hints[id] = nil
	end
	if targets[id] == gui then
		return
	end
	targets[id] = gui
	gui.Destroying:Once(function()
		if targets[id] == gui then
			targets[id] = nil
			GuideTargets.changed:Fire()
		end
	end)
	GuideTargets.changed:Fire()
end

function GuideTargets.unregister(id: string, gui: GuiObject?)
	if targets[id] ~= nil and (gui == nil or targets[id] == gui) then
		targets[id] = nil
		GuideTargets.changed:Fire()
	end
end

-- Affichée : dans un ScreenGui actif, elle et tous ses ancêtres GuiObject visibles.
local function shown(gui: GuiObject): boolean
	local node: Instance? = gui
	while node do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		elseif node:IsA("LayerCollector") then
			return node.Enabled and node:IsDescendantOf(game)
		end
		node = node.Parent
	end
	return false
end

function GuideTargets.hint(id: string): string?
	return if targets[id] then hints[id] else nil
end

function GuideTargets.get(id: string): GuiObject?
	local gui = targets[id]
	return if gui and shown(gui) then gui else nil
end

function GuideTargets.open(key: string)
	openScreens[key] = true
	GuideTargets.opened:Fire(key)
end

function GuideTargets.close(key: string)
	if openScreens[key] then
		openScreens[key] = nil
		GuideTargets.closed:Fire(key)
	end
end

function GuideTargets.isOpen(key: string): boolean
	return openScreens[key] == true
end

return GuideTargets
