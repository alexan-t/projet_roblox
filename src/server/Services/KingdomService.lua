--!strict
-- Royaume miniature du joueur (voir docs/KINGDOM.md).
-- Clone tel quel le modèle d'état qui correspond à Kingdom.VisualState, le pose sur le repère
-- du plot, puis pose un modèle par héros possédé sur les repères de ce modèle.
-- Aucun réglage artistique ici. Tout est synchrone : le plot, le Runtime et les données
-- sont relus à chaque Refresh et aucune attente ne peut les rendre obsolètes en cours de route.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Log = require(ReplicatedStorage.Shared.Utils.Log)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local KingdomConfig = require(script.Parent.Parent.Config.KingdomConfig)

local SCOPE = "KingdomService"
local KINGDOM_NAME = "Kingdom"
local HEROES_NAME = "Heroes"
local HERO_INSTANCE_ATTRIBUTE = "HeroInstanceId"

type WantedHero = { heroId: string, marker: BasePart }

local KingdomService = {}

-- Royaume cloné -> modèle d'état source. Clés faibles : rien ne survit au Runtime détruit.
local sources: { [Instance]: Model } = setmetatable({}, { __mode = "k" }) :: any

local function resolve(root: Instance, path: { string }): Instance?
	local node: Instance? = root
	for _, name in path do
		node = if node then node:FindFirstChild(name) else nil
	end
	return node
end

local function pathText(path: { string }): string
	return table.concat(path, ".")
end

-- Le seul modèle du dossier qui porte attribute = value, sinon la raison de l'échec.
local function findAsset(folder: Instance?, attribute: string, value: any): (Model?, string)
	if not folder then
		return nil, "dossier d'assets introuvable"
	end
	local found: Model? = nil
	for _, child in folder:GetChildren() do
		if child:GetAttribute(attribute) == value then
			if not child:IsA("Model") then
				return nil, `{child:GetFullName()} n'est pas un Model`
			end
			if found then
				return nil, `plusieurs modèles avec {attribute} = {value}`
			end
			found = child
		end
	end
	if not found then
		return nil, `aucun modèle avec {attribute} = {value} dans {folder:GetFullName()}`
	end
	return found, ""
end

-- Position du repère et orientation horizontale seulement : un repère couché
-- (disque, cylindre) ne fait pas basculer le modèle posé dessus.
local function placement(marker: BasePart): CFrame
	local look = marker.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		return CFrame.new(marker.Position)
	end
	return CFrame.lookAt(marker.Position, marker.Position + flat.Unit)
end

local function markerIndex(marker: BasePart): number?
	return tonumber(string.match(marker.Name, "%d+$"))
end

-- Repères de héros du royaume, triés par numéro final (Heros_2 avant Heros_10).
local function heroMarkers(kingdom: Model): { BasePart }
	local markers: { BasePart } = {}
	local folder = resolve(kingdom, KingdomConfig.HeroMarkers)
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(markers, child)
			end
		end
	end
	table.sort(markers, function(a: BasePart, b: BasePart): boolean
		local ia, ib = markerIndex(a), markerIndex(b)
		if ia and ib and ia ~= ib then
			return ia < ib
		end
		return a.Name < b.Name
	end)
	return markers
end

-- Renvoie false si au moins un héros possédé n'a pas pu être affiché (repère ou asset manquant).
-- Les héros valides restent affichés dans tous les cas.
local function syncHeroes(player: Player, heroes: { [string]: PlayerDataTypes.Hero }, runtime: Folder, kingdom: Model): boolean
	local folder = runtime:FindFirstChild(HEROES_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = HEROES_NAME
		folder.Parent = runtime
	end
	assert(folder)

	-- Ordre stable : un même héros garde son repère d'un Refresh à l'autre.
	local ids: { string } = {}
	for id in heroes do
		table.insert(ids, id)
	end
	table.sort(ids)
	local markers = heroMarkers(kingdom)
	local complete = #ids <= #markers
	if not complete then
		Log.warn(SCOPE, `{#ids - #markers} héros de {player.Name} sans repère dans le royaume ({pathText(KingdomConfig.HeroMarkers)})`)
	end
	local wanted: { [string]: WantedHero } = {}
	for index = 1, math.min(#ids, #markers) do
		local id = ids[index]
		wanted[id] = { heroId = heroes[id].HeroId, marker = markers[index] }
	end

	local kept: { [string]: Model } = {}
	for _, child in folder:GetChildren() do
		local id = child:GetAttribute(HERO_INSTANCE_ATTRIBUTE)
		local want = if typeof(id) == "string" then wanted[id] else nil
		if want and child:IsA("Model") and child:GetAttribute("HeroId") == want.heroId and not kept[id :: string] then
			kept[id :: string] = child
		else
			child:Destroy()
		end
	end

	local heroesFolder = resolve(ServerStorage, KingdomConfig.HeroesFolder)
	for id, want in wanted do
		local model = kept[id]
		if not model then
			local asset, problem = findAsset(heroesFolder, "HeroId", want.heroId)
			local clone = if asset then asset:Clone() else nil
			if not clone then
				Log.warn(SCOPE, `Héros {want.heroId} de {player.Name} non affiché : {if asset then "asset non clonable" else problem}`)
				complete = false
				continue
			end
			clone:SetAttribute(HERO_INSTANCE_ATTRIBUTE, id)
			model = clone
		end
		assert(model)
		model:PivotTo(placement(want.marker))
		model.Parent = folder
	end
	return complete
end

function KingdomService:Start()
	-- PlotService rejoue les attributions existantes et ne notifie qu'une attribution encore valide.
	PlotService:OnPlotAssigned(function(player: Player)
		KingdomService:Refresh(player)
	end)
end

-- Reconstruit l'affichage du royaume et des héros à partir de PlayerData.
-- À appeler après toute modification de Kingdom ou de Heroes (futur HeroService #10 compris).
-- Renvoie true seulement si le royaume ET tous les héros possédés sont affichés conformément aux données.
-- false : une partie n'a pas pu l'être (données, plot, asset ou repère manquant). Rien de valide n'est
-- retiré pour autant : un royaume déjà affiché et les héros valides restent en place.
function KingdomService:Refresh(player: Player): boolean
	local plot = PlotService:GetPlot(player)
	local runtime = PlotService:GetRuntime(player)
	local data = DataService:GetData(player)
	if not plot or not runtime or not data then
		return false
	end

	local state = data.Kingdom.VisualState
	if typeof(state) ~= "number" or state < 1 or state % 1 ~= 0 then
		Log.warn(SCOPE, `VisualState invalide pour {player.Name} : {state}`)
		return false
	end
	local asset, problem = findAsset(resolve(ServerStorage, KingdomConfig.StatesFolder), "VisualState", state)
	if not asset then
		Log.warn(SCOPE, `Royaume {state} de {player.Name} non affiché : {problem}`)
		return false
	end
	local anchor = resolve(plot, KingdomConfig.PlotAnchor)
	if not anchor or not anchor:IsA("BasePart") then
		Log.warn(SCOPE, `Repère {pathText(KingdomConfig.PlotAnchor)} introuvable dans {plot:GetFullName()}`)
		return false
	end

	local current = runtime:FindFirstChild(KINGDOM_NAME)
	local kingdom: Model
	if current and current:IsA("Model") and sources[current] == asset then
		kingdom = current
	else
		-- Créer le remplaçant avant de retirer l'ancien : un échec laisse l'état précédent en place.
		local clone = asset:Clone()
		if not clone then
			Log.warn(SCOPE, `Royaume {state} non clonable : {asset:GetFullName()} (Archivable)`)
			return false
		end
		clone.Name = KINGDOM_NAME
		clone:PivotTo(placement(anchor))
		clone.Parent = runtime
		sources[clone] = asset
		if current then
			current:Destroy()
		end
		kingdom = clone
		Log.debug(SCOPE, `Royaume {state} affiché pour {player.Name}`)
	end

	return syncHeroes(player, data.Heroes, runtime, kingdom)
end

-- Royaume affiché pour le joueur, ou nil sans attribution valide.
function KingdomService:GetKingdom(player: Player): Model?
	local runtime = PlotService:GetRuntime(player)
	local kingdom = if runtime then runtime:FindFirstChild(KINGDOM_NAME) else nil
	return if kingdom and kingdom:IsA("Model") then kingdom else nil
end

return KingdomService
