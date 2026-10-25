--!strict
-- Décor de zone de l'arène d'un plot (voir docs/ZONES.md § Décor des zones). Assets seulement, aucune règle.
-- Arene.Zones contient UN décor de zone (Folder ou Model, attribut ZoneId), celui du stage choisi : ses
-- repères SourcesEnnemis / FrontEnnemi servent à la mise en scène du client, qui prend le décor présent.
-- Les autres attendent dans ServerStorage (un dossier par arène). Un décor absent du plot est copié depuis
-- son gabarit ServerStorage.Assets.ZonesArene (Model, attribut ZoneId, pivot = repère de l'arène :
-- PivotTo(arena:GetPivot()) le pose aux mêmes positions relatives dans chaque plot).
-- Sans décor ni gabarit pour la zone demandée : rien ne change (l'arène garde son décor).

local ServerStorage = game:GetService("ServerStorage")

local TEMPLATES = "ZonesArene"
local STASH_PREFIX = "ZonesRangees_"

local ZoneDecor = {}

local stashes: { [Instance]: Folder } = {}

local function stashOf(arena: Instance): Folder
	local stash = stashes[arena]
	if stash and stash.Parent then
		return stash
	end
	local folder = Instance.new("Folder")
	folder.Name = STASH_PREFIX .. (if arena.Parent then arena.Parent.Name else arena.Name)
	folder.Parent = ServerStorage
	stashes[arena] = folder
	return folder
end

local function find(parent: Instance?, zone: number): Instance?
	for _, child in if parent then parent:GetChildren() else {} do
		if child:GetAttribute("ZoneId") == zone then
			return child
		end
	end
	return nil
end

-- Zone dont le décor est actuellement dans l'arène, ou nil.
function ZoneDecor.current(arena: Instance): number?
	local zones = arena:FindFirstChild("Zones")
	for _, child in if zones then zones:GetChildren() else {} do
		local id = child:GetAttribute("ZoneId")
		if typeof(id) == "number" then
			return id
		end
	end
	return nil
end

-- Met le décor de `zone` dans l'arène (et range les autres). Renvoie true si ce décor y est.
function ZoneDecor.apply(arena: Model, zone: number): boolean
	local zones = arena:FindFirstChild("Zones")
	if not zones then
		return false
	end
	if find(zones, zone) and #zones:GetChildren() == 1 then
		return true
	end
	local stash = stashOf(arena)
	local target = find(zones, zone) or find(stash, zone)
	if not target then
		local assets = ServerStorage:FindFirstChild("Assets")
		local template = find(assets and assets:FindFirstChild(TEMPLATES), zone)
		if not template or not template:IsA("Model") then
			return false
		end
		local copy = template:Clone()
		copy:PivotTo(arena:GetPivot())
		target = copy
	end
	for _, child in zones:GetChildren() do
		if child ~= target then
			child.Parent = stash
		end
	end
	(target :: Instance).Parent = zones
	return true
end

return ZoneDecor
