--!strict
-- Animation d'ambiance du portail d'invocation (purement visuelle, côté client).
--   • Tag "CaillouOrbite" : le modèle tourne autour de l'axe vertical du portail, avec une légère ondulation.
--   • Tag "CristalLevite" : le modèle monte/descend doucement et tourne sur lui-même.
-- Les réglages sont lus sur le modèle portail parent (premier ancêtre qui porte l'attribut "AnimOrbiteVitesse").
-- Aucune logique gameplay ici : ne rien ajouter qui touche aux invocations ou aux récompenses.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TAG_ORBITE = "CaillouOrbite"
local TAG_LEVITATION = "CristalLevite"
local DISTANCE_MAX = 300 -- au-delà, on n'anime pas (économise le client quand il y a 8 plots)
local RATIO_SUR_POTEAU = 0.4 -- les cristaux posés sur une coupe lévitent moins

local DEFAUTS = {
	AnimOrbiteVitesse = 18, -- degrés / seconde
	AnimOrbiteOndulation = 0.4, -- studs
	AnimLevitationAmplitude = 0.35, -- studs
	AnimLevitationPeriode = 2.6, -- secondes
	AnimCristalRotation = 30, -- degrés / seconde
}

type Entry = {
	model: Model,
	kind: "orbite" | "levitation",
	base: CFrame,
	center: Vector3,
	phase: number,
	settings: Instance,
	surPoteau: boolean,
}

local PortalAmbientController = {}

local entries: { [Model]: Entry } = {}
local count = 0

local function findSettings(model: Model): Instance?
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

local function register(instance: Instance, kind: "orbite" | "levitation")
	if not instance:IsA("Model") or entries[instance] then
		return
	end
	local settings = findSettings(instance)
	if not settings then
		return
	end
	local center = if settings:IsA("Model") then settings:GetPivot().Position else instance:GetPivot().Position
	count += 1
	entries[instance] = {
		model = instance,
		kind = kind,
		base = instance:GetPivot(),
		center = center,
		phase = count * 1.7, -- décalage pour que les objets ne bougent pas en même temps
		settings = settings,
		surPoteau = instance:GetAttribute("SurPoteau") == true,
	}
end

local function unregister(instance: Instance)
	local entry = entries[instance :: Model]
	if entry then
		-- remettre l'objet à sa place d'origine
		if entry.model.Parent then
			entry.model:PivotTo(entry.base)
		end
		entries[instance :: Model] = nil
	end
end

local function animate(entry: Entry, t: number)
	local s = entry.settings
	if entry.kind == "orbite" then
		local angle = math.rad(setting(s, "AnimOrbiteVitesse")) * t
		local bob = math.sin(t * 1.3 + entry.phase) * setting(s, "AnimOrbiteOndulation")
		local rotation = CFrame.new(entry.center) * CFrame.Angles(0, angle, 0) * CFrame.new(-entry.center)
		entry.model:PivotTo(rotation * entry.base + Vector3.new(0, bob, 0))
	else
		local periode = math.max(setting(s, "AnimLevitationPeriode"), 0.1)
		local amplitude = setting(s, "AnimLevitationAmplitude") * (if entry.surPoteau then RATIO_SUR_POTEAU else 1)
		local offset = math.sin((t / periode) * math.pi * 2 + entry.phase) * amplitude
		local spin = math.rad(setting(s, "AnimCristalRotation")) * t
		entry.model:PivotTo(entry.base * CFrame.Angles(0, spin, 0) + Vector3.new(0, offset, 0))
	end
end

function PortalAmbientController:Init()
	for _, instance in CollectionService:GetTagged(TAG_ORBITE) do
		register(instance, "orbite")
	end
	for _, instance in CollectionService:GetTagged(TAG_LEVITATION) do
		register(instance, "levitation")
	end
	CollectionService:GetInstanceAddedSignal(TAG_ORBITE):Connect(function(instance)
		register(instance, "orbite")
	end)
	CollectionService:GetInstanceAddedSignal(TAG_LEVITATION):Connect(function(instance)
		register(instance, "levitation")
	end)
	CollectionService:GetInstanceRemovedSignal(TAG_ORBITE):Connect(unregister)
	CollectionService:GetInstanceRemovedSignal(TAG_LEVITATION):Connect(unregister)
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
