--!strict
-- État « héros en main » côté client, sans API Roblox : testé par tools/test-arena.ps1.
-- Prendre un héros (hotbar, collection ou héros déjà posé) le met en main ; toucher une case
-- produit une demande au serveur, qui décide. Aucun Tool Roblox : c'est un simple état.

export type Held = { instanceId: string, fromSlot: number? }
export type State = { held: Held?, locked: boolean }
export type Formation = { [number]: string } -- case -> HeroInstanceId (vue serveur)
export type Request = { Action: string, Slot: number, HeroInstanceId: string? }

local EMPTY = ""

local PlacementState = {}

function PlacementState.new(): State
	return { held = nil, locked = false }
end

local function slotOf(formation: Formation, instanceId: string): number?
	for slot, id in formation do
		if id == instanceId then
			return slot
		end
	end
	return nil
end

-- Prend un exemplaire en main. Reprendre celui qu'on tient déjà le repose (bascule).
local function hold(state: State, instanceId: string, formation: Formation): boolean
	if state.locked then
		return false
	end
	local held = state.held
	if held and held.instanceId == instanceId then
		state.held = nil
		return false
	end
	state.held = { instanceId = instanceId, fromSlot = slotOf(formation, instanceId) }
	return true
end

-- Touche 1..0 ou clic sur un raccourci. Raccourci vide : main vidée.
function PlacementState.selectHotbar(state: State, index: number, hotbar: { string }, formation: Formation): boolean
	local id = hotbar[index]
	if typeof(id) ~= "string" or id == EMPTY then
		state.held = nil
		return false
	end
	return hold(state, id, formation)
end

-- Collection > Placer : exactement le même mode que la hotbar.
function PlacementState.selectCollection(state: State, instanceId: string, formation: Formation): boolean
	if state.held and state.held.instanceId == instanceId then
		return true -- déjà en main : Placer ne la repose pas
	end
	return hold(state, instanceId, formation)
end

-- Clic sur une case (ou sur le héros qui s'y trouve). Renvoie la demande à envoyer, ou nil.
function PlacementState.clickCase(state: State, slot: number, formation: Formation): Request?
	if state.locked then
		return nil
	end
	local held = state.held
	if held then
		state.held = nil
		if held.fromSlot == slot then
			return nil -- reposé à sa place
		end
		return { Action = "Place", Slot = slot, HeroInstanceId = held.instanceId }
	end
	local placed = formation[slot]
	if placed then
		state.held = { instanceId = placed, fromSlot = slot } -- héros posé repris en main pour le déplacer
	end
	return nil
end

-- Retirer le héros tenu de l'arène (il reste dans la hotbar et la collection).
function PlacementState.removeHeld(state: State): Request?
	local held = state.held
	state.held = nil
	if state.locked or not held or not held.fromSlot then
		return nil
	end
	return { Action = "Remove", Slot = held.fromSlot }
end

function PlacementState.cancel(state: State)
	state.held = nil
end

-- Pendant le combat la formation est figée : plus rien en main.
function PlacementState.setLocked(state: State, locked: boolean)
	state.locked = locked
	if locked then
		state.held = nil
	end
end

-- Après une réponse du serveur : la case d'origine du héros tenu suit la formation réelle.
function PlacementState.syncFormation(state: State, formation: Formation)
	local held = state.held
	if held then
		held.fromSlot = slotOf(formation, held.instanceId)
	end
end

return PlacementState
