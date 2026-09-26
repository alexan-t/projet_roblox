--!strict
-- Animations d'ambiance des zones de campagne (purement visuelles, côté client).
--   • Tag "SlimeSautille" (Model) : petit saut avec écrasement à l'appel et à la réception.
--       Attributs : SautHauteur (studs), SautPeriode (s).
--   • Tag "CristalFlotte" (BasePart ou Model) : flotte doucement et tourne sur lui-même.
--       Attributs : Amplitude (studs), Periode (s), Rotation (degrés/s).
--   • Tag "FlammeVacille" (BasePart) : la flamme change de taille par à-coups, sa PointLight suit.
--       Attributs : Intensite (0-1).
--   • Tag "DrapeauFlotte" (BasePart ou Model, ex. tissu + emblème qui bougent ensemble) :
--       oscille autour d'un point d'attache (repère du pivot du modèle).
--       Attributs : AncrageLocal (Vector3, point d'attache dans le repère de la pièce),
--       AxeLocal (Vector3, axe de rotation), Amplitude (degrés), Periode (s).
-- Tous les attributs sont optionnels (valeurs par défaut ci-dessous). Aucune logique gameplay ici.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DISTANCE_MAX = 250 -- au-delà, on n'anime pas

type Kind = "slime" | "cristal" | "flamme" | "drapeau"

type PartState = {
	part: BasePart,
	offset: CFrame, -- position relative au bas du modèle (slimes)
	size: Vector3,
}

type Entry = {
	instance: PVInstance,
	kind: Kind,
	base: CFrame,
	phase: number,
	parts: { PartState }, -- slimes
	body: BasePart?, -- slimes : pièce écrasée/étirée
	size: Vector3?, -- flammes
	light: PointLight?,
	lightBrightness: number,
}

local TAGS: { [string]: Kind } = {
	SlimeSautille = "slime",
	CristalFlotte = "cristal",
	FlammeVacille = "flamme",
	DrapeauFlotte = "drapeau",
}

local ZoneAmbientController = {}

local entries: { [Instance]: Entry } = {}
local count = 0

local function number(instance: Instance, name: string, default: number): number
	local value = instance:GetAttribute(name)
	return if typeof(value) == "number" then value else default
end

local function vector(instance: Instance, name: string, default: Vector3): Vector3
	local value = instance:GetAttribute(name)
	return if typeof(value) == "Vector3" then value else default
end

local function register(instance: Instance, kind: Kind)
	if entries[instance] or not instance:IsA("PVInstance") then
		return
	end
	if kind == "slime" and not instance:IsA("Model") then
		return
	end
	if kind == "flamme" and not instance:IsA("BasePart") then
		return
	end
	local pv = instance :: PVInstance
	count += 1
	local entry: Entry = {
		instance = pv,
		kind = kind,
		base = pv:GetPivot(),
		phase = (count * 0.618) % 1, -- décalage pour que rien ne bouge en même temps
		parts = {},
		body = nil,
		size = if pv:IsA("BasePart") then pv.Size else nil,
		light = pv:FindFirstChildWhichIsA("PointLight"),
		lightBrightness = 0,
	}
	if entry.light then
		entry.lightBrightness = entry.light.Brightness
	end
	if kind == "slime" then
		local model = pv :: Model
		local boxCF, boxSize = model:GetBoundingBox()
		-- repère au sol, au centre du slime, orienté comme le modèle
		local bottom = CFrame.new(boxCF.Position - Vector3.new(0, boxSize.Y / 2, 0)) * model:GetPivot().Rotation
		entry.base = bottom
		local biggest = 0
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				table.insert(entry.parts, { part = descendant, offset = bottom:ToObjectSpace(descendant.CFrame), size = descendant.Size })
				local volume = descendant.Size.X * descendant.Size.Y * descendant.Size.Z
				if volume > biggest then
					biggest = volume
					entry.body = descendant
				end
			end
		end
	end
	entries[instance] = entry
end

local function restore(entry: Entry)
	local inst = entry.instance
	if not inst.Parent then
		return
	end
	if entry.kind == "slime" then
		for _, state in entry.parts do
			state.part.Size = state.size
			state.part.CFrame = entry.base * state.offset
		end
	else
		inst:PivotTo(entry.base)
		if entry.size and inst:IsA("BasePart") then
			inst.Size = entry.size
		end
	end
	if entry.light then
		entry.light.Brightness = entry.lightBrightness
	end
end

local function unregister(instance: Instance)
	local entry = entries[instance]
	if entry then
		restore(entry)
		entries[instance] = nil
	end
end

-- Saut : écrasement (0 → 0.15), vol (0.15 → 0.6), réception écrasée (0.6 → 0.75), repos respirant.
local function slimePose(p: number): (number, number)
	if p < 0.15 then
		return 0, 0.16 * math.sin(p / 0.15 * math.pi)
	elseif p < 0.6 then
		local k = (p - 0.15) / 0.45
		return math.sin(k * math.pi), -0.1 * math.sin(k * math.pi)
	elseif p < 0.75 then
		return 0, 0.2 * math.sin((p - 0.6) / 0.15 * math.pi)
	end
	return 0, 0.03 * math.sin((p - 0.75) / 0.25 * math.pi * 2)
end

local function animate(entry: Entry, t: number)
	local inst = entry.instance
	if entry.kind == "slime" then
		local periode = math.max(number(inst, "SautPeriode", 1.8), 0.2)
		local hop, squash = slimePose((t / periode + entry.phase) % 1)
		local height = hop * number(inst, "SautHauteur", 0.8)
		local sy, sxz = 1 - squash, 1 + squash * 0.5
		for _, state in entry.parts do
			local o = state.offset
			local pos = Vector3.new(o.X * sxz, o.Y * sy + height, o.Z * sxz)
			state.part.CFrame = entry.base * CFrame.new(pos) * o.Rotation
			if state.part == entry.body then
				state.part.Size = Vector3.new(state.size.X * sxz, state.size.Y * sy, state.size.Z * sxz)
			end
		end
	elseif entry.kind == "cristal" then
		local periode = math.max(number(inst, "Periode", 2.4), 0.2)
		local offset = math.sin((t / periode + entry.phase) * math.pi * 2) * number(inst, "Amplitude", 0.25)
		local spin = math.rad(number(inst, "Rotation", 25)) * t
		inst:PivotTo(CFrame.new(0, offset, 0) * entry.base * CFrame.Angles(0, spin, 0))
	elseif entry.kind == "flamme" then
		local part = inst :: BasePart
		local intensite = number(inst, "Intensite", 0.18)
		local n = math.noise(t * 6, entry.phase * 10)
		local scale = 1 + n * intensite
		part.Size = (entry.size :: Vector3) * Vector3.new(1 - n * intensite * 0.4, scale, 1 - n * intensite * 0.4)
		part.CFrame = entry.base * CFrame.new(0, ((entry.size :: Vector3).Y * (scale - 1)) / 2, 0)
		if entry.light then
			entry.light.Brightness = entry.lightBrightness * (1 + n * 0.5)
		end
	else
		local periode = math.max(number(inst, "Periode", 2.2), 0.2)
		local angle = math.rad(number(inst, "Amplitude", 10)) * math.sin((t / periode + entry.phase) * math.pi * 2)
		local anchor = vector(inst, "AncrageLocal", Vector3.zero)
		local axis = vector(inst, "AxeLocal", Vector3.new(0, 1, 0))
		if axis.Magnitude < 1e-3 then
			axis = Vector3.new(0, 1, 0)
		end
		local pivot = entry.base * CFrame.new(anchor)
		inst:PivotTo(pivot * CFrame.fromAxisAngle(axis.Unit, angle) * CFrame.new(-anchor))
	end
end

function ZoneAmbientController:Init()
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

function ZoneAmbientController:Start()
	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local camPos = camera.CFrame.Position
		local t = os.clock()
		for instance, entry in entries do
			if not instance.Parent then
				entries[instance] = nil
			elseif (entry.base.Position - camPos).Magnitude <= DISTANCE_MAX then
				animate(entry, t)
			end
		end
	end)
end

return ZoneAmbientController
