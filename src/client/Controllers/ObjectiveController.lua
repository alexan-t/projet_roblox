--!strict
-- Paliers de progression (#120, voir docs/ZONES.md § Prochain objectif), présentation seulement.
-- Le serveur envoie le prochain objectif dans ArenaState.Objective (ArenaRules.objective) ; ce contrôleur
-- annonce UNE fois un palier franchi pendant la session (ExpeditionModel.milestone) :
--   • 1-5 Normal gagné : « Mode Élite débloqué ! » et la raison d'y jouer (ennemis plus forts, meilleur
--     équipement, stage Élite à lancer) ;
--   • dernier stage Élite gagné : « Zone n maîtrisée ! », améliorer son équipe en Élite.
-- Jamais au join ni au rejoin (l'objectif reçu en premier sert de référence) : la quête active, la pancarte
-- et la fenêtre Expédition (stage présélectionné) suffisent alors. L'annonce attend la fin du combat, de
-- l'écran de fin et de tout écran ouvert, puis laisse passer l'annonce de quête (« Quête terminée ! »).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ExpeditionModel = require(ReplicatedStorage.Shared.Expedition.ExpeditionModel)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local ArenaStore = require(script.Parent.Parent.Arena.ArenaStore)
local ScreenState = require(script.Parent.Parent.UI.ScreenState)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local ObjectiveController = {}

local GAP = 2.8 -- s laissées à l'annonce de quête qui suit l'écran de fin (« Quête terminée ! »)
local HOLD = 3.5 -- s de tenue de l'annonce
local Y = 150 -- sous l'annonce de quête (UIKit.announce, y = 120)

local known: ExpeditionModel.Objective? = nil
local received = false
local queued: ExpeditionModel.Milestone? = nil
local showing = false
local screen: ScreenGui? = nil

local function busy(): boolean
	return ArenaStore.inCombat() or ArenaStore.awaitingResult or not ScreenState.free()
end

local function show(milestone: ExpeditionModel.Milestone)
	local gui = screen
	if not gui or not gui.Parent then
		gui = UIKit.screen("AnnoncePalier", 30)
		screen = gui
	end
	assert(gui)
	UIKit.announce(gui, milestone.Title, { Color = UITheme.Colors.GoldLight, Hold = HOLD, Y = Y })
	-- Heading (24) : jamais sous 14 px réels, même à l'échelle minimale du téléphone (0,7)
	UIKit.announce(gui, milestone.Text, { Color = UITheme.Colors.TextLight, Size = UITheme.Typography.Size.Heading, Hold = HOLD,
		Y = Y + UITheme.Typography.Size.Title + 24 })
end

-- Attend un écran libre (et le passage de l'annonce de quête), puis annonce le dernier palier reçu.
local function flush()
	if showing or not queued then
		return
	end
	showing = true
	task.spawn(function()
		while busy() do
			task.wait(0.25)
		end
		task.wait(GAP)
		while busy() do
			task.wait(0.25)
		end
		local milestone = queued
		queued = nil
		showing = false
		if milestone then
			show(milestone)
		end
	end)
end

local function receive()
	local objective = ArenaStore.arena.Objective
	local current: ExpeditionModel.Objective? = if typeof(objective) == "table" then objective else nil
	if not received then
		-- premier état reçu (join) : référence, pas d'annonce
		received = current ~= nil
		known = current
		return
	end
	local milestone = ExpeditionModel.milestone(known, current)
	if current then
		known = current
	end
	if milestone then
		queued = milestone
		flush()
	end
end

function ObjectiveController:Start()
	ArenaStore.start()
	ArenaStore.changed.Event:Connect(receive)
	receive()
end

return ObjectiveController
