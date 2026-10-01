--!strict
-- Briques d'interface du design system (docs/UI_DESIGN_SYSTEM.md). Toutes les valeurs viennent
-- de UITheme : les Controllers composent ces briques au lieu de régler couleurs et tailles en dur.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)

local C = UITheme.Colors
local T = UITheme.Transparency

export type ButtonKind = "Primary" | "Secondary" | "Danger" | "Tab"
export type Button = {
	holder: Frame,
	face: TextButton,
	label: TextLabel,
	setEnabled: (enabled: boolean) -> (),
	setSelected: (selected: boolean) -> (),
}

local UIKit = {}

function UIKit.corner(parent: Instance, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
end

-- Contour Ink qui suit les coins arrondis (Border) ou entoure le texte (Contextual).
function UIKit.stroke(parent: Instance, thickness: number, color: Color3?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color or UITheme.Stroke.Color
	s.Thickness = thickness
	s.LineJoinMode = UITheme.Stroke.LineJoin
	s.ApplyStrokeMode = if parent:IsA("TextLabel") or parent:IsA("TextButton") then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function textStroke(size: number): number
	local strokes = UITheme.Typography.TextStroke
	return if size <= 18 then strokes.Small elseif size <= 32 then strokes.Medium else strokes.Large
end

-- Texte Fredoka One clair, contour Ink (lisible sur un fond transparent).
function UIKit.text(parent: Instance, content: string, size: number, color: Color3?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.FontFace = UITheme.Typography.Display
	label.TextSize = size
	label.TextColor3 = color or C.TextLight
	label.Text = content
	label.Size = UDim2.fromScale(1, 1)
	label.Parent = parent
	UIKit.stroke(label, textStroke(size))
	return label
end

-- Panneau semi-transparent (bois sombre), contour Ink.
function UIKit.panel(parent: Instance, transparency: number?, radius: UDim?, thickness: number?): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = C.WoodDeep
	frame.BackgroundTransparency = transparency or T.Panel
	frame.BorderSizePixel = 0
	frame.Parent = parent
	UIKit.corner(frame, radius or UITheme.Radius.Large)
	UIKit.stroke(frame, thickness or UITheme.Stroke.Thick)
	return frame
end

-- Pastille d'état (Disponible, Posé, Nouveau…).
function UIKit.badge(parent: Instance, content: string, color: Color3): Frame
	local size = UITheme.Typography.Size.Caption
	local badge = Instance.new("Frame")
	badge.BackgroundColor3 = color
	badge.BorderSizePixel = 0
	badge.AutomaticSize = Enum.AutomaticSize.X
	badge.Size = UDim2.fromOffset(0, size + 8)
	badge.Parent = parent
	UIKit.corner(badge, UITheme.Radius.Pill)
	UIKit.stroke(badge, UITheme.Stroke.Thin)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, UITheme.Spacing.S)
	padding.PaddingRight = UDim.new(0, UITheme.Spacing.S)
	padding.Parent = badge
	local label = UIKit.text(badge, content, size)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromScale(0, 1)
	return badge
end

local KINDS: { [string]: { top: Color3, bottom: Color3, lip: Color3 } } = {
	Primary = { top = C.GoldLight, bottom = C.GoldDeep, lip = C.WoodDark },
	Secondary = { top = C.WoodLight, bottom = C.Wood, lip = C.WoodDark },
	Danger = { top = C.Error, bottom = C.RoyalRed, lip = C.WoodDark },
	Tab = { top = C.WoodDeep, bottom = C.WoodDeep, lip = C.Ink },
}

-- Bouton « chunky » : une face posée sur une lèvre plus sombre ; la face s'enfonce au clic.
function UIKit.button(parent: Instance, content: string, kind: ButtonKind, size: UDim2, onClick: () -> ()): Button
	local style = KINDS[kind]
	local lipHeight = UITheme.Shadow.ButtonLip
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = size
	holder.Parent = parent

	local lip = Instance.new("Frame")
	lip.BackgroundColor3 = style.lip
	lip.BorderSizePixel = 0
	lip.Position = UDim2.fromOffset(0, lipHeight)
	lip.Size = UDim2.new(1, 0, 1, -lipHeight)
	lip.Parent = holder
	UIKit.corner(lip, UITheme.Radius.Medium)
	UIKit.stroke(lip, UITheme.Stroke.Regular)

	local face = Instance.new("TextButton")
	face.AutoButtonColor = false
	face.Text = ""
	face.BackgroundColor3 = Color3.new(1, 1, 1)
	face.BorderSizePixel = 0
	face.Size = UDim2.new(1, 0, 1, -lipHeight)
	face.Parent = holder
	UIKit.corner(face, UITheme.Radius.Medium)
	local faceStroke = UIKit.stroke(face, UITheme.Stroke.Regular)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(style.top, style.bottom)
	gradient.Parent = face
	local label = UIKit.text(face, content, UITheme.Typography.Size.Button)

	local enabled, selected = true, false
	local function paint()
		local top, bottom = style.top, style.bottom
		if not enabled then
			top, bottom = C.Disabled, C.StoneGrey
		elseif kind == "Tab" and selected then
			top, bottom = C.GoldLight, C.GoldDeep
		end
		gradient.Color = ColorSequence.new(top, bottom)
		face.BackgroundTransparency = if kind == "Tab" and not selected then T.PanelStrong else 0
		label.TextTransparency = if enabled then 0 else T.Disabled
		faceStroke.Color = if selected and kind ~= "Tab" then C.Selected else UITheme.Stroke.Color
		faceStroke.Thickness = if selected and kind ~= "Tab" then UITheme.Stroke.Thick else UITheme.Stroke.Regular
	end
	local function press(down: boolean)
		if not enabled then
			return
		end
		local offset = if down then lipHeight else 0
		TweenService:Create(face, UITheme.Animation.Press, { Position = UDim2.fromOffset(0, offset) }):Play()
	end
	face.MouseButton1Down:Connect(function()
		press(true)
	end)
	face.MouseButton1Up:Connect(function()
		press(false)
	end)
	face.MouseLeave:Connect(function()
		press(false)
	end)
	face.Activated:Connect(function()
		if enabled then
			onClick()
		end
	end)
	paint()
	return {
		holder = holder,
		face = face,
		label = label,
		setEnabled = function(value: boolean)
			enabled = value
			paint()
		end,
		setSelected = function(value: boolean)
			selected = value
			paint()
		end,
	}
end

-- Petit « pop » (gain, nouveau badge, prise en main).
function UIKit.pop(target: GuiObject)
	local scale = target:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = target
	scale.Scale = UITheme.Animation.Scale.Pop
	TweenService:Create(scale, UITheme.Animation.Open, { Scale = 1 }):Play()
end

return UIKit
