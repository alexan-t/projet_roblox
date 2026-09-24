--!strict
-- Animation d'ambiance du royaume miniature (purement visuelle, côté client).
--   • Tag "FumeeCheminee" : Model dont le pivot est posé en haut de la cheminée et dont les enfants
--     BasePart sont les bouffées. Chaque bouffée monte en boucle, grossit, se balance et s'efface.
--     Réglages lus sur le Model : AnimFumeeDuree, AnimFumeeHauteur, AnimFumeeDerive, AnimFumeeGrossissement.
-- Aucune logique gameplay ici.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TAG_FUMEE = "FumeeCheminee"
local DISTANCE_MAX = 300 -- au-delà, on n'anime pas
local FONDU_ENTREE = 0.15 -- part du cycle pendant laquelle la bouffée apparaît

local DEFAUTS = {
	AnimFumeeDuree = 4, -- secondes pour un cycle complet d'une bouffée
	AnimFumeeHauteur = 4.5, -- studs parcourus au-dessus de la cheminée
	AnimFumeeDerive = 0.6, -- balancement latéral (studs)
	AnimFumeeGrossissement = 2.2, -- taille finale / taille de départ
}

type Puff = {
	part: BasePart,
	baseCFrame: CFrame,
	baseSize: Vector3,
	baseTransparency: number,
}

type Entry = {
	model: Model,
	origin: Vector3,
	startSize: Vector3,
	puffs: { Puff },
}

local KingdomAmbientController = {}

local entries: { [Model]: Entry } = {}

local function setting(source: Instance, name: string): number
	local value = source:GetAttribute(name)
	if typeof(value) == "number" then
		return value
	end
	return (DEFAUTS :: any)[name]
end

local function register(instance: Instance)
	if not instance:IsA("Model") or entries[instance] then
		return
	end
	local puffs: { Puff } = {}
	for _, child in instance:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(puffs, {
				part = child,
				baseCFrame = child.CFrame,
				baseSize = child.Size,
				baseTransparency = child.Transparency,
			})
		end
	end
	if #puffs == 0 then
		return
	end
	-- la plus petite bouffée donne la taille de départ
	table.sort(puffs, function(a: Puff, b: Puff): boolean
		return a.baseSize.Magnitude < b.baseSize.Magnitude
	end)
	entries[instance] = {
		model = instance,
		origin = instance:GetPivot().Position,
		startSize = puffs[1].baseSize,
		puffs = puffs,
	}
end

local function unregister(instance: Instance)
	local entry = entries[instance :: Model]
	if entry then
		for _, puff in entry.puffs do
			if puff.part.Parent then
				puff.part.CFrame = puff.baseCFrame
				puff.part.Size = puff.baseSize
				puff.part.Transparency = puff.baseTransparency
			end
		end
		entries[instance :: Model] = nil
	end
end

local function animate(entry: Entry, t: number)
	local m = entry.model
	local duree = math.max(setting(m, "AnimFumeeDuree"), 0.1)
	local hauteur = setting(m, "AnimFumeeHauteur")
	local derive = setting(m, "AnimFumeeDerive")
	local grossissement = setting(m, "AnimFumeeGrossissement")
	local n = #entry.puffs
	for i, puff in entry.puffs do
		-- chaque bouffée est décalée dans le cycle pour former une colonne continue
		local p = (t / duree + (i - 1) / n) % 1
		local sway = math.sin(p * math.pi * 2 + i) * derive * p
		local position = entry.origin + Vector3.new(sway, 0.3 + p * hauteur, sway * 0.5)
		local fade = if p < FONDU_ENTREE then 1 - p / FONDU_ENTREE else ((p - FONDU_ENTREE) / (1 - FONDU_ENTREE)) ^ 1.5
		puff.part.Size = entry.startSize * (1 + (grossissement - 1) * p)
		puff.part.CFrame = CFrame.new(position) * CFrame.Angles(0, p * 2 + i, 0)
		puff.part.Transparency = puff.baseTransparency + (1 - puff.baseTransparency) * fade
	end
end

function KingdomAmbientController:Init()
	for _, instance in CollectionService:GetTagged(TAG_FUMEE) do
		register(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG_FUMEE):Connect(register)
	CollectionService:GetInstanceRemovedSignal(TAG_FUMEE):Connect(unregister)
end

function KingdomAmbientController:Start()
	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local camPos = camera.CFrame.Position
		local t = os.clock()
		for model, entry in entries do
			if not model.Parent then
				entries[model] = nil
			elseif (entry.origin - camPos).Magnitude <= DISTANCE_MAX then
				animate(entry, t)
			end
		end
	end)
end

return KingdomAmbientController
