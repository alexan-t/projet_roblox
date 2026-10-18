--!strict
-- Monnaies 3D en feedback (voir docs/UI_DESIGN_SYSTEM.md § Monnaies) — purement visuel, côté client.
-- VFX ≠ économie : le serveur a DÉJÀ attribué la monnaie quand on appelle ce module ; un modèle qui vole
-- vers le HUD ne donne jamais rien, il montre seulement où la récompense est rangée.
-- Modèles : ReplicatedStorage.Assets.Currencies.<Model> (Studio, reproduits d'après « Monnaies 3D.html » :
-- Gold = pièce crénelée à la couronne, Gems = cristal taillé, SummonTicket = ticket au portail cyan),
-- choisis par CurrencyVisualConfig. Sans modèle (place sans l'asset) : l'icône PNG Normal vole à la place.
-- Chaque modèle est rendu dans un petit ViewportFrame (lumière douce d'en haut à gauche) :
--   Gold tourne sur Y (la tranche crénelée et la couronne accrochent la lumière), Gems tourne lentement
--   et flotte, SummonTicket fait des flips (le portail est sur les deux faces).
-- API :
--   CurrencyFx.SpawnCurrencyReward(kind, origin, destination?, options?) -> number (s avant la dernière arrivée)
--     kind        : Gold / Gems / SummonTicket (ou clé de PlayerData.Currencies) ;
--     origin      : Vector2 (px, sous la barre de Roblox), Vector3 (point du monde) ou GuiObject (son centre) ;
--     destination : GuiObject (ex. CurrencyView.IconOf(kind)) ; nil : les modèles jaillissent et s'effacent ;
--     options     : { Count: number? (1..8), Delay: number?, OnArrive: ((index: number) -> ())? }
--   CurrencyFx.Preview(kind, parent) -> ViewportFrame : le modèle qui tourne sur place (reveal, aperçu).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CurrencyVisualConfig = require(ReplicatedStorage.Shared.Config.CurrencyVisualConfig)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)

export type Options = { Count: number?, Delay: number?, OnArrive: ((index: number) -> ())? }

local CurrencyFx = {}

local SIZE = 76 -- px d'un modèle en vol (écran de 1080 px)
local BURST = 70 -- px : les modèles jaillissent autour de l'origine avant de partir
local BURST_TIME = 0.28 -- s
local FLY_TIME = 0.62 -- s
local STAGGER = 0.07 -- s entre deux modèles
local ARC = 120 -- px : hauteur de la courbe de vol
local FADE_TIME = 0.35 -- s : sans destination, le modèle s'efface
local MAX_COUNT = 8
local CAMERA_DISTANCE = 4.6

type Flyer = {
	frame: ViewportFrame,
	model: Model?,
	kind: string,
	start: Vector2,
	burst: Vector2,
	finish: Vector2?,
	born: number,
	index: number,
	onArrive: ((index: number) -> ())?,
	arrived: boolean,
}

local screen: ScreenGui? = nil
local flyers: { Flyer } = {}
local spinning: { [ViewportFrame]: { model: Model, kind: string, born: number } } = {}
local connection: RBXScriptConnection? = nil

local function scale(): number
	local camera = Workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else 1080
	return math.clamp(height / 1080, 0.7, 1.25)
end

local function layer(): ScreenGui
	local existing = screen
	if existing and existing.Parent then
		return existing
	end
	local s = Instance.new("ScreenGui")
	s.Name = "MonnaiesEnVol"
	s.ResetOnSpawn = false
	s.IgnoreGuiInset = false -- mêmes coordonnées qu'AbsolutePosition
	s.DisplayOrder = 60 -- au-dessus du reveal (55) et de la flèche du tutoriel (50)
	s.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	s.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	screen = s
	return s
end

local function template(kind: string): Model?
	local visual = CurrencyVisualConfig.visual(kind)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Currencies")
	local model = if visual and folder then folder:FindFirstChild(visual.Model) else nil
	return if model and model:IsA("Model") then model else nil
end

-- Pose propre à chaque monnaie à l'instant t (s depuis l'apparition) : rotation, flip, respiration.
local function pose(kind: string, t: number): CFrame
	local visual = CurrencyVisualConfig.visual(kind)
	local id = if visual then visual.Model else ""
	if id == "Gold" then
		return CFrame.Angles(0, t * 5.5, 0) -- pièce qui tourne (pluie de pièces)
	elseif id == "Gems" then
		return CFrame.new(0, 0.08 * math.sin(t * 3), 0) * CFrame.Angles(0.18, t * 1.8, 0) -- rotation lente, flotte
	else
		return CFrame.Angles(t * 4.2, 0, math.rad(-6)) -- ticket qui fait des flips
	end
end

-- ViewportFrame avec une copie du modèle (ou l'icône PNG si l'asset manque).
local function viewport(kind: string, parent: Instance, size: number): (ViewportFrame, Model?)
	local frame = Instance.new("ViewportFrame")
	frame.Name = "Monnaie_" .. kind
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromOffset(size, size)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Ambient = UITheme.Colors.Cream
	frame.LightColor = Color3.new(1, 1, 1)
	frame.LightDirection = Vector3.new(-1, -1, -1) -- d'en haut à gauche, vers la caméra
	frame.Parent = parent
	local source = template(kind)
	local model: Model? = nil
	if source then
		local copy = source:Clone()
		copy:PivotTo(CFrame.new())
		copy.Parent = frame
		model = copy
		local camera = Instance.new("Camera")
		camera.FieldOfView = 30
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, CAMERA_DISTANCE), Vector3.zero)
		camera.Parent = frame
		frame.CurrentCamera = camera
	else
		local visual = CurrencyVisualConfig.visual(kind)
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Size = UDim2.fromScale(1, 1)
		image.Image = if visual then visual.Normal else ""
		image.ScaleType = Enum.ScaleType.Fit
		image.Parent = frame
	end
	return frame, model
end

local function center(object: GuiObject): Vector2
	return object.AbsolutePosition + object.AbsoluteSize / 2
end

local function toScreen(origin: any): Vector2
	if typeof(origin) == "Vector2" then
		return origin
	elseif typeof(origin) == "Vector3" then
		local camera = Workspace.CurrentCamera
		if camera then
			local point = camera:WorldToViewportPoint(origin)
			local inset = GuiService:GetGuiInset()
			return Vector2.new(point.X, point.Y) - inset
		end
	elseif typeof(origin) == "Instance" and origin:IsA("GuiObject") then
		return center(origin)
	end
	local camera = Workspace.CurrentCamera
	return if camera then camera.ViewportSize / 2 else Vector2.new(960, 540)
end

local function bezier(a: Vector2, control: Vector2, b: Vector2, t: number): Vector2
	local u = 1 - t
	return a * (u * u) + control * (2 * u * t) + b * (t * t)
end

local function ease(t: number): number
	return t * t * (3 - 2 * t)
end

local function step()
	local now = os.clock()
	local s = scale()
	for index = #flyers, 1, -1 do
		local flyer = flyers[index]
		local t = now - flyer.born
		local frame = flyer.frame
		if t < 0 then
			frame.Visible = false
			continue
		end
		frame.Visible = true
		local model = flyer.model
		if model then
			model:PivotTo(pose(flyer.kind, t))
		end
		local position: Vector2
		local size = SIZE * s
		if t < BURST_TIME then
			local k = ease(t / BURST_TIME)
			position = flyer.start:Lerp(flyer.burst, k)
			size *= 0.4 + 0.6 * k
		else
			local finish = flyer.finish
			local fly = (t - BURST_TIME) / (if finish then FLY_TIME else FADE_TIME)
			if fly >= 1 then
				if finish and not flyer.arrived then
					flyer.arrived = true
					local onArrive = flyer.onArrive
					if onArrive then
						task.spawn(onArrive, flyer.index)
					end
				end
				frame:Destroy()
				table.remove(flyers, index)
				continue
			end
			if finish then
				local k = ease(fly)
				local control = (flyer.burst + finish) / 2 - Vector2.new(0, ARC * s)
				position = bezier(flyer.burst, control, finish, k)
				size *= 1 - 0.45 * k
			else
				position = flyer.burst + Vector2.new(0, -30 * s * fly)
				frame.ImageTransparency = fly
			end
		end
		frame.Position = UDim2.fromOffset(position.X, position.Y)
		frame.Size = UDim2.fromOffset(size, size)
	end
	for frame, info in spinning do
		if not frame.Parent then
			spinning[frame] = nil
		else
			info.model:PivotTo(pose(info.kind, now - info.born))
		end
	end
	if #flyers == 0 and next(spinning) == nil and connection then
		connection:Disconnect()
		connection = nil
	end
end

local function run()
	if not connection then
		connection = RunService.RenderStepped:Connect(step)
	end
end

function CurrencyFx.SpawnCurrencyReward(kind: string, origin: any, destination: GuiObject?, options: Options?): number
	local opts: Options = options or {}
	local count = math.clamp(math.floor(opts.Count or 1), 1, MAX_COUNT)
	local delay = opts.Delay or 0
	local start = toScreen(origin)
	local finish = if destination and destination.Parent then center(destination) else nil
	local random = Random.new()
	local s = scale()
	local parent = layer()
	local now = os.clock()
	for index = 1, count do
		local frame, model = viewport(kind, parent, SIZE * s)
		frame.Visible = false
		local angle = random:NextNumber(0, 2 * math.pi)
		local distance = random:NextNumber(0.4, 1) * BURST * s
		table.insert(flyers, {
			frame = frame,
			model = model,
			kind = kind,
			start = start,
			burst = start + Vector2.new(math.cos(angle), math.sin(angle)) * distance,
			finish = finish,
			born = now + delay + (index - 1) * STAGGER,
			index = index,
			onArrive = opts.OnArrive,
			arrived = false,
		})
	end
	run()
	return delay + (count - 1) * STAGGER + BURST_TIME + (if finish then FLY_TIME else FADE_TIME)
end

-- Modèle qui tourne sur place dans `parent` (rempli) ; s'arrête quand le cadre est détruit.
function CurrencyFx.Preview(kind: string, parent: GuiObject): ViewportFrame
	local frame, model = viewport(kind, parent, 0)
	frame.AnchorPoint = Vector2.zero
	frame.Size = UDim2.fromScale(1, 1)
	if model then
		spinning[frame] = { model = model, kind = kind, born = os.clock() }
		run()
	end
	return frame
end

return CurrencyFx
