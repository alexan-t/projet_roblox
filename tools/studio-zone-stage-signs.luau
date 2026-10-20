--!strict
-- À exécuter en EDIT : installe les pancartes manquantes du sandbox, sans script ni remplacement.
-- L'interface et le prompt sont créés par ArenaPlacementController avec UITheme.
local history = game:GetService("ChangeHistoryService")
local theme = require(game.ReplicatedStorage.Shared.Config.UITheme)
local recording = history:TryBeginRecording("Pancartes Expédition des zones")
local changed = 0
for _, plot in workspace.Lobby.Plots:GetChildren() do
	local arena = plot:FindFirstChild("Arene")
	if not arena or not arena:IsA("Model") or arena:FindFirstChild("PanneauStage") then continue end
	local poses = arena:FindFirstChild("Emplacements")
	local marker = poses and poses:FindFirstChild("PointEtendard")
	if not marker or not marker:IsA("BasePart") then continue end
	local model = Instance.new("Model")
	model.Name = "PanneauStage"
	-- Repère existant, au bord de la préparation ; la face avant regarde les dalles.
	local facing = arena:GetPivot().Rotation
	local origin = CFrame.new(marker.Position) * facing * CFrame.new(14, 0, 0)
	local function part(name: string, size: Vector3, offset: Vector3, color: Color3)
		local p = Instance.new("Part")
		p.Name, p.Size, p.CFrame = name, size, origin * CFrame.new(offset)
		p.Color, p.Material = color, Enum.Material.SmoothPlastic
		p.Anchored, p.CanCollide, p.CanTouch = true, false, false
		p.Parent = model
	end
	part("Banniere", Vector3.new(12, 7, 0.5), Vector3.new(0, 4, 0), theme.Colors.WoodDeep)
	for _, x in { -5, 5 } do
		part("Poteau", Vector3.new(0.7, 9, 0.7), Vector3.new(x, 1, 0.4), theme.Colors.Wood)
	end
	model.WorldPivot = origin
	model.Parent = arena
	changed += 1
end
if recording then history:FinishRecording(recording, Enum.FinishRecordingOperation.Commit) end
return changed
