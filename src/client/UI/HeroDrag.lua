--!strict
-- Une seule transaction souris/tactile ; les cartes restent à leur place jusqu'à la réponse.
local Input = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.Shared.Config.UITheme)
local UIKit = require(script.Parent.UIKit)
local Store = require(script.Parent.Parent.Arena.ArenaStore)
local Drag = {}
local active: any = nil
local suppressedUntil = 0
local targets: { [number]: GuiObject } = {}
local ghost: Frame
local label: TextLabel

local function point(input: InputObject): Vector2
	-- InputObject.Position et AbsolutePosition partagent le même espace GUI.
	return Vector2.new(input.Position.X, input.Position.Y)
end
local function at(position: Vector2): number?
	for index, frame in targets do
		local p, s = frame.AbsolutePosition, frame.AbsoluteSize
		if position.X >= p.X and position.Y >= p.Y and position.X <= p.X + s.X and position.Y <= p.Y + s.Y then return index end
	end
	return nil
end
local function resetStrokes()
	Store.notify()
end
function Drag.suppressed(): boolean return (active ~= nil and active.dragging) or os.clock() < suppressedUntil end
function Drag.bind(frame: GuiObject, source: () -> any)
	frame.InputBegan:Connect(function(input)
		if Store.busy or active or (input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch) then return end
		local value = source()
		if not value then return end
		active = { input = input, origin = point(input), source = value, frame = frame, dragging = false }
	end)
end
function Drag.start(screen: ScreenGui, frames: { [number]: GuiObject })
	targets = frames
	ghost = UIKit.panel(screen, Theme.Transparency.PanelStrong)
	ghost.Name, ghost.Size, ghost.Visible, ghost.ZIndex = "ApercuDrag", UDim2.fromOffset(120, 54), false, 30
	label = UIKit.text(ghost, "", Theme.Typography.Size.Label)
	label.ZIndex = 31
	Input.InputChanged:Connect(function(input)
		local drag = active
		if not drag then return end
		if input ~= drag.input and not (drag.input.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement) then return end
		local p = point(input)
		if (p - drag.origin).Magnitude >= 10 then drag.dragging = true end
		if not drag.dragging then return end
		ghost.Visible, ghost.Position = true, UDim2.fromOffset(p.X + 12, p.Y - 60)
		local _, info = Store.heroInfo(drag.source.id)
		label.Text = if info then info.Name else "Raccourci vide"
		resetStrokes()
		local target = at(p)
		for index, frame in targets do
			local stroke = frame:FindFirstChildOfClass("UIStroke")
			if stroke and (index == target or frame == drag.frame) then stroke.Color = Theme.Colors.Selected; stroke.Thickness = Theme.Stroke.Thick end
		end
		local stroke = drag.frame:FindFirstChildOfClass("UIStroke")
		if stroke then stroke.Color = Theme.Colors.Selected; stroke.Thickness = Theme.Stroke.Thick end
	end)
	Input.InputEnded:Connect(function(input)
		local drag = active
		if not drag or (input ~= drag.input and input.UserInputType ~= Enum.UserInputType.MouseButton1) then return end
		active = nil
		ghost.Visible = false
		if drag.dragging then
			suppressedUntil = os.clock() + 0.25
			local target = at(point(input))
			if target then
				if drag.source.slot then Store.hotbarAction("Swap", drag.source.slot, target)
				else Store.hotbarAction("Assign", drag.source.id, target) end
			end
		end
		resetStrokes()
	end)
end
return Drag
