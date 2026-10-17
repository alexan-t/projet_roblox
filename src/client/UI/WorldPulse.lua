--!strict
-- Cible « vivante » du tutoriel (voir docs/UI_DESIGN_SYSTEM.md § Guidage) : portail, pancarte du stage,
-- dalle à utiliser. Le même langage visuel partout, sans pancarte ni gros contour permanent, valeurs de
-- UITheme.World.Guide : léger voile doré qui respire (Highlight, aucun contour au creux du battement),
-- lumière douce qui pulse et quelques étincelles autour de la cible. Purement local et visuel.
-- API :
--   local pulse = WorldPulse.start(target, focus?) -- target : Model / BasePart mis en valeur ;
--                                                 -- focus : partie autour de laquelle briller (défaut : target)
--   pulse.setNear(near)          -- joueur arrivé : battement plus marqué
--   pulse.setHighlight(visible)  -- voile coupé (ex. la dalle a déjà sa lumière de placement), lumière gardée
--   pulse.stop()                 -- tout est retiré

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)

local GUIDE = UITheme.World.Guide

export type Pulse = {
	setNear: (near: boolean) -> (),
	setHighlight: (visible: boolean) -> (),
	stop: () -> (),
}

type Entry = { highlight: Highlight, light: PointLight, near: boolean, phase: number }

local WorldPulse = {}

local active: { [Entry]: boolean } = {}
local connection: RBXScriptConnection? = nil
local folder: Folder? = nil

local function container(): Folder
	local existing = folder
	if existing and existing.Parent then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "CiblesTutoriel"
	created.Parent = Workspace
	folder = created
	return created
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function step()
	local now = os.clock()
	for entry in active do
		local wave = 0.5 + 0.5 * math.sin((now - entry.phase) * 2 * math.pi / GUIDE.Period)
		if entry.near then
			wave = GUIDE.Near + (1 - GUIDE.Near) * wave
		end
		entry.highlight.FillTransparency = lerp(GUIDE.FillFrom, GUIDE.FillTo, wave)
		entry.highlight.OutlineTransparency = lerp(GUIDE.OutlineFrom, GUIDE.OutlineTo, wave)
		entry.light.Brightness = lerp(GUIDE.LightFrom, GUIDE.LightTo, wave)
	end
end

local function bounds(target: Instance): (CFrame, Vector3)
	if target:IsA("Model") then
		return target:GetBoundingBox()
	elseif target:IsA("BasePart") then
		return target.CFrame, target.Size
	end
	return CFrame.new(), Vector3.one
end

function WorldPulse.start(target: Instance, focus: Instance?): Pulse
	local parent = container()
	local glow = Instance.new("Highlight")
	glow.Name = "Pulse_" .. target.Name
	glow.Adornee = target
	glow.FillColor = GUIDE.Color
	glow.OutlineColor = GUIDE.Color
	glow.FillTransparency = GUIDE.FillFrom
	glow.OutlineTransparency = GUIDE.OutlineFrom
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Parent = parent

	-- Volume invisible autour de la cible (ou de son focus) : porte la lumière et les étincelles.
	local center, size = bounds(focus or target)
	local anchor = Instance.new("Part")
	anchor.Name = "Lueur_" .. target.Name
	anchor.Anchored = true
	anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = false, false, false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(math.max(size.X, 1), math.max(size.Y, 1), math.max(size.Z, 1))
	anchor.CFrame = center
	anchor.Parent = parent
	local light = Instance.new("PointLight")
	light.Color = GUIDE.Color
	light.Range = GUIDE.LightRange
	light.Brightness = GUIDE.LightFrom
	light.Shadows = false
	light.Parent = anchor
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "Etincelles"
	sparkles.Color = ColorSequence.new(GUIDE.Color)
	sparkles.LightEmission = 1
	sparkles.Rate = GUIDE.Sparkles
	sparkles.Lifetime = NumberRange.new(1, 1.6)
	sparkles.Speed = NumberRange.new(0.4, 1)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Acceleration = Vector3.new(0, 0.6, 0)
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, GUIDE.SparkleSize),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkles.Transparency = NumberSequence.new(0.2)
	sparkles.EmissionDirection = Enum.NormalId.Top
	sparkles.Shape = Enum.ParticleEmitterShape.Box
	sparkles.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	sparkles.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	sparkles.Parent = anchor

	local entry: Entry = { highlight = glow, light = light, near = false, phase = os.clock() }
	active[entry] = true
	if not connection then
		connection = RunService.Heartbeat:Connect(step)
	end
	local stopped = false
	return {
		setNear = function(near: boolean)
			entry.near = near
		end,
		setHighlight = function(visible: boolean)
			glow.Enabled = visible
		end,
		stop = function()
			if stopped then
				return
			end
			stopped = true
			active[entry] = nil
			glow:Destroy()
			anchor:Destroy()
			if next(active) == nil and connection then
				connection:Disconnect()
				connection = nil
			end
		end,
	}
end

return WorldPulse
