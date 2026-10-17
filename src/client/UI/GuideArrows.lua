--!strict
-- Flèches du tutoriel dans le monde (voir docs/TUTORIAL_GUIDANCE.md) : la même flèche dorée chunky que
-- la flèche UI (Icons « Fleche », contour Ink cuit), construite en pièces simples, sans asset externe.
--   GuideArrows.ground() -> Model : flèche couchée au sol ; GuideArrows.place(model, position, direction)
--     l'oriente vers `direction` (horizontale). setFade(model, t) : 0 = pleine, 1 = presque invisible.
--   GuideArrows.beacon(target, parent) -> Beacon : grosse flèche 3D qui rebondit au-dessus d'une cible
--     (Model ou BasePart), toujours tournée vers la caméra (on la lit de face, de loin).
--     beacon.stop() la retire.
-- Purement local et visuel : aucune collision, aucune requête, aucune ombre.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Icons = require(script.Parent.Icons)

local GuideArrows = {}

local GROUND_SCALE = 0.9 -- flèche au sol : environ 2,3 x 2,8 studs
-- La flèche d'icône pointe vers -Y dans le plan XY ; couchée, elle pointe vers -Z (LookVector) et sa
-- silhouette Ink (derrière, +Z) passe dessous.
local LAY = CFrame.Angles(math.rad(90), 0, 0)
local BEACON_SCALE = 2.2 -- flèche d'environ 5 x 7 studs : lisible de loin
local BEACON_HEIGHT = 4.5 -- studs entre le haut de la cible et le centre de la flèche
local BEACON_BOB = 0.6 -- studs
local BEACON_SPEED = 4 -- rad/s

export type Beacon = { stop: () -> () }

local function quiet(model: Model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
			part.CastShadow = false
			part:SetAttribute("Base", part.Transparency)
		end
	end
end

function GuideArrows.ground(): Model
	local model = Icons.model("Fleche")
	model.Name = "FlecheSol"
	model.WorldPivot = CFrame.new()
	model:ScaleTo(GROUND_SCALE)
	quiet(model)
	return model
end

function GuideArrows.place(model: Model, position: Vector3, direction: Vector3)
	local flat = direction * Vector3.new(1, 0, 1)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(0, 0, -1)
	end
	model:PivotTo(CFrame.lookAt(position, position + flat.Unit) * LAY)
end

function GuideArrows.setFade(model: Model, t: number)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local base = part:GetAttribute("Base")
			part.Transparency = (if typeof(base) == "number" then base else 0) + 0.7 * math.clamp(t, 0, 1)
		end
	end
end

local function topOf(target: Instance): CFrame
	if target:IsA("Model") then
		local cframe, size = target:GetBoundingBox()
		return CFrame.new(cframe.Position + Vector3.new(0, size.Y / 2, 0))
	elseif target:IsA("BasePart") then
		return CFrame.new(target.Position + Vector3.new(0, target.Size.Y / 2, 0))
	end
	return CFrame.new()
end

function GuideArrows.beacon(target: Instance, parent: Instance): Beacon
	local model = Icons.model("Fleche")
	model.Name = "BaliseGuidage"
	model:ScaleTo(BEACON_SCALE)
	quiet(model)
	model.Parent = parent
	local top = topOf(target).Position
	local started = os.clock()
	local function place()
		local wave = 0.5 + 0.5 * math.sin((os.clock() - started) * BEACON_SPEED)
		local position = top + Vector3.new(0, BEACON_HEIGHT + BEACON_BOB * wave, 0)
		-- face dessinée de l'icône (côté -Z) tournée vers la caméra, à l'horizontale : pointe toujours en bas
		local camera = Workspace.CurrentCamera
		local eye = if camera then camera.CFrame.Position else position + Vector3.new(0, 0, -10)
		local toward = (eye - position) * Vector3.new(1, 0, 1)
		if toward.Magnitude < 1e-3 then
			toward = Vector3.new(0, 0, -1)
		end
		model:PivotTo(CFrame.lookAt(position, position + toward.Unit))
	end
	place()
	local connection = RunService.RenderStepped:Connect(place)
	local stopped = false
	return {
		stop = function()
			if stopped then
				return
			end
			stopped = true
			connection:Disconnect()
			model:Destroy()
		end,
	}
end

return GuideArrows
