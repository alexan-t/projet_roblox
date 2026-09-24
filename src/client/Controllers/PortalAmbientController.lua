--!strict
-- Animation d'ambiance du portail d'invocation (purement visuelle, côté client).
--   • Tag "CaillouOrbite" : le modèle tourne en cercle autour de l'anneau, dans le plan et le sens de la
--     spirale (axe du modèle tagué "PortailVortex"), en roulant sur lui-même et avec une légère respiration.
--     Il s'efface quand il passe plus bas que AnimOrbiteFonduBas sous le centre (derrière le socle).
--     Sans vortex dans le portail : repli sur une orbite autour de l'axe vertical du portail.
--   • Tag "CristalLevite" : le modèle monte/descend doucement et tourne sur lui-même.
--   • Tag "PortailVortex" : le modèle (bras de la spirale) tourne autour de l'axe avant de son pivot.
--   • Tag "PortailVoile" : la pièce (surface du portail) pulse doucement vers le blanc.
-- Les réglages sont lus sur le modèle portail parent (premier ancêtre qui porte l'attribut "AnimOrbiteVitesse").
-- Aucune logique gameplay ici : ne rien ajouter qui touche aux invocations ou aux récompenses.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TAG_ORBITE = "CaillouOrbite"
local TAG_LEVITATION = "CristalLevite"
local TAG_VORTEX = "PortailVortex"
local TAG_VOILE = "PortailVoile"
local DISTANCE_MAX = 300 -- au-delà, on n'anime pas (économise le client quand il y a 8 plots)
local RATIO_SUR_POTEAU = 0.4 -- les cristaux posés sur une coupe lévitent moins

local DEFAUTS = {
	AnimOrbiteVitesse = 18, -- degrés / seconde (même signe que AnimVortexVitesse = même sens)
	AnimOrbiteOndulation = 0.4, -- studs
	AnimOrbiteFonduBas = math.huge, -- studs sous le centre de l'anneau où la pierre s'efface
	AnimLevitationAmplitude = 0.35, -- studs
	AnimLevitationPeriode = 2.6, -- secondes
	AnimCristalRotation = 30, -- degrés / seconde
	AnimVortexVitesse = 45, -- degrés / seconde (négatif = sens inverse)
	AnimVoilePulsation = 0.18, -- 0 = pas de battement, 1 = va jusqu'au blanc
	AnimVoilePeriode = 2.2, -- secondes
}

type Kind = "orbite" | "levitation" | "vortex" | "voile"

type FadePart = {
	part: BasePart,
	transparency: number,
}

type Entry = {
	model: PVInstance,
	kind: Kind,
	base: CFrame,
	baseColor: Color3?,
	center: Vector3,
	phase: number,
	settings: Instance,
	surPoteau: boolean,
	axis: CFrame?, -- orbite : pivot du vortex (Z = axe de rotation)
	fadeParts: { FadePart },
}

local PortalAmbientController = {}

local entries: { [PVInstance]: Entry } = {}
local count = 0

local function findSettings(model: Instance): Instance?
	local node = model.Parent
	while node and node ~= Workspace do
		if node:GetAttribute("AnimOrbiteVitesse") ~= nil then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function setting(source: Instance, name: string): number
	local value = source:GetAttribute(name)
	if typeof(value) == "number" then
		return value
	end
	return (DEFAUTS :: any)[name]
end

local function register(instance: Instance, kind: Kind)
	local expected = if kind == "voile" then "BasePart" else "Model"
	if not instance:IsA(expected) or entries[instance :: PVInstance] then
		return
	end
	local pv = instance :: PVInstance
	local settings = findSettings(pv)
	if not settings then
		return
	end
	local center = if settings:IsA("Model") then settings:GetPivot().Position else pv:GetPivot().Position
	local axis: CFrame? = nil
	local fadeParts: { FadePart } = {}
	if kind == "orbite" then
		for _, descendant in settings:GetDescendants() do
			if descendant:IsA("Model") and CollectionService:HasTag(descendant, TAG_VORTEX) then
				axis = descendant:GetPivot()
				break
			end
		end
		for _, descendant in pv:GetDescendants() do
			if descendant:IsA("BasePart") then
				table.insert(fadeParts, { part = descendant, transparency = descendant.Transparency })
			end
		end
	end
	count += 1
	entries[pv] = {
		model = pv,
		kind = kind,
		base = pv:GetPivot(),
		baseColor = if pv:IsA("BasePart") then pv.Color else nil,
		center = center,
		phase = count * 1.7, -- décalage pour que les objets ne bougent pas en même temps
		settings = settings,
		surPoteau = instance:GetAttribute("SurPoteau") == true,
		axis = axis,
		fadeParts = fadeParts,
	}
end

local function setFade(entry: Entry, alpha: number)
	for _, fp in entry.fadeParts do
		fp.part.Transparency = fp.transparency + (1 - fp.transparency) * alpha
	end
end

local function unregister(instance: Instance)
	local entry = entries[instance :: PVInstance]
	if entry then
		-- remettre l'objet à sa place (et sa couleur) d'origine
		if entry.model.Parent then
			entry.model:PivotTo(entry.base)
			if entry.baseColor and entry.model:IsA("BasePart") then
				entry.model.Color = entry.baseColor
			end
			setFade(entry, 0)
		end
		entries[instance :: PVInstance] = nil
	end
end

local function animate(entry: Entry, t: number)
	local s = entry.settings
	if entry.kind == "orbite" then
		local angle = math.rad(setting(s, "AnimOrbiteVitesse")) * t
		local bob = math.sin(t * 1.3 + entry.phase) * setting(s, "AnimOrbiteOndulation")
		local axis = entry.axis
		if axis then
			-- rotation autour de l'axe Z du vortex (même convention que la spirale)
			local rotation = axis * CFrame.Angles(0, 0, angle) * axis:Inverse()
			local localPos = axis:PointToObjectSpace(entry.base.Position)
			local radial = Vector3.new(localPos.X, localPos.Y, 0)
			local breathe = if radial.Magnitude > 0 then axis:VectorToWorldSpace(radial.Unit * bob) else Vector3.zero
			local tumble = CFrame.Angles(t * 0.5 + entry.phase, t * 0.35, 0)
			local cf = rotation * (entry.base + breathe) * tumble
			entry.model:PivotTo(cf)
			-- effacer la pierre quand elle passe derrière le socle
			local depth = -axis:PointToObjectSpace(cf.Position).Y - setting(s, "AnimOrbiteFonduBas")
			setFade(entry, math.clamp(depth, 0, 1))
		else
			local rotation = CFrame.new(entry.center) * CFrame.Angles(0, angle, 0) * CFrame.new(-entry.center)
			entry.model:PivotTo(rotation * entry.base + Vector3.new(0, bob, 0))
		end
	elseif entry.kind == "vortex" then
		-- le pivot du modèle regarde vers l'avant du portail : on tourne autour de son axe Z
		local angle = math.rad(setting(s, "AnimVortexVitesse")) * t
		entry.model:PivotTo(entry.base * CFrame.Angles(0, 0, angle))
	elseif entry.kind == "voile" then
		local periode = math.max(setting(s, "AnimVoilePeriode"), 0.1)
		local pulse = (math.sin((t / periode) * math.pi * 2) + 1) / 2
		local part = entry.model :: BasePart
		part.Color = (entry.baseColor :: Color3):Lerp(Color3.new(1, 1, 1), pulse * setting(s, "AnimVoilePulsation"))
	else
		local periode = math.max(setting(s, "AnimLevitationPeriode"), 0.1)
		local amplitude = setting(s, "AnimLevitationAmplitude") * (if entry.surPoteau then RATIO_SUR_POTEAU else 1)
		local offset = math.sin((t / periode) * math.pi * 2 + entry.phase) * amplitude
		local spin = math.rad(setting(s, "AnimCristalRotation")) * t
		entry.model:PivotTo(entry.base * CFrame.Angles(0, spin, 0) + Vector3.new(0, offset, 0))
	end
end

local TAGS: { [string]: Kind } = {
	[TAG_ORBITE] = "orbite",
	[TAG_LEVITATION] = "levitation",
	[TAG_VORTEX] = "vortex",
	[TAG_VOILE] = "voile",
}

function PortalAmbientController:Init()
	for tag, kind in TAGS do
		for _, instance in CollectionService:GetTagged(tag) do
			register(instance, kind)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
			register(instance, kind)
		end)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(unregister)
	end
end

function PortalAmbientController:Start()
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
			elseif (entry.center - camPos).Magnitude <= DISTANCE_MAX then
				animate(entry, t)
			end
		end
	end)
end

return PortalAmbientController
