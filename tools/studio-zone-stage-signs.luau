--!strict
-- À exécuter en EDIT : installe les pancartes manquantes du sandbox et replace les existantes, sans script.
-- Emplacement : bord droit de la zone de préparation (hors du centre de l'arène, libre dans les six décors),
-- face avant tournée vers les cases des héros. L'interface et le prompt sont créés par ArenaPlacementController
-- avec UITheme ; ils suivent la bannière où qu'elle soit.
local history = game:GetService("ChangeHistoryService")
local theme = require(game.ReplicatedStorage.Shared.Config.UITheme)
local recording = history:TryBeginRecording("Pancartes Expédition des zones")
local changed = 0
local plots = workspace.Lobby.Plots:GetChildren()
local showcase = workspace:FindFirstChild("PlotsZones")
for _, plot in if showcase then showcase:GetChildren() else {} do table.insert(plots, plot) end
for _, plot in plots do
	local arena = plot:FindFirstChild("Arene")
	if not arena or not arena:IsA("Model") then continue end
	local poses = arena:FindFirstChild("Emplacements")
	local marker = poses and poses:FindFirstChild("PointEtendard")
	if not marker or not marker:IsA("BasePart") then continue end
	-- Repère existant : à droite des cases (x +20), à mi-profondeur de la préparation ; face avant vers les cases.
	local facing = arena:GetPivot().Rotation
	local origin = CFrame.new(marker.Position) * facing * CFrame.new(20, 0, 18.7) * CFrame.Angles(0, math.pi / 2, 0)
	local existing = arena:FindFirstChild("PanneauStage")
	if existing and existing:IsA("Model") then
		existing:PivotTo(origin)
		changed += 1
		continue
	end
	local model = Instance.new("Model")
	model.Name = "PanneauStage"
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
