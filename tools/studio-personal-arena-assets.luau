-- À exécuter une fois dans Studio EDIT. Assets uniquement, aucun Source de script.
-- Répétable : ne remplace aucun objet existant. Conserve la sandbox comme référence.
local collection = game:GetService("CollectionService")
local source = workspace.PlotTravail.Arene.Emplacements.Heros
local changed = {}
for _, plot in workspace.Lobby.Plots:GetChildren() do
	local arena = plot:FindFirstChild("Arene")
	if not arena or not arena:IsA("Model") or arena:FindFirstChild("Emplacements") then continue end
	local pivot = arena:GetPivot()
	local base = CFrame.new(pivot.Position.X, 3.7, pivot.Position.Z) * pivot.Rotation
	local emplacements = Instance.new("Folder")
	emplacements.Name = "Emplacements"
	local heroes = Instance.new("Folder")
	heroes.Name, heroes.Parent = "Heros", emplacements
	for slot = 1, 9 do
		local template
		for _, case in source:GetChildren() do if case:GetAttribute("Slot") == slot then template = case end end
		assert(template, `Case source {slot} absente`)
		local case = template:Clone()
		local pose = case.PointDePose
		local target = base * CFrame.new(((slot - 1) % 3 - 1) * 8, 0.5, 6 + ((slot - 1) // 3) * 8)
		local delta = target * pose.CFrame:Inverse()
		for _, part in case:GetDescendants() do
			if part:IsA("BasePart") then part.CFrame = delta * part.CFrame; part.Anchored = true end
		end
		collection:AddTag(case, "CaseHeros")
		case.Parent = heroes
	end
	local marker = Instance.new("Part")
	marker.Name, marker.Size, marker.CFrame = "PointEtendard", Vector3.one, base * CFrame.new(0, 2, 28)
	marker.Anchored, marker.CanCollide, marker.Transparency = true, false, 1
	marker.Parent = emplacements
	local zones = arena:FindFirstChild("Zones") or Instance.new("Folder")
	zones.Name, zones.Parent = "Zones", arena
	local zone = Instance.new("Folder")
	zone.Name, zone.Parent = "Zone1", zones
	zone:SetAttribute("ZoneId", 1)
	local sources = Instance.new("Folder")
	sources.Name, sources.Parent = "SourcesEnnemis", zone
	local front = Instance.new("Part")
	front.Name, front.Size, front.CFrame = "FrontEnnemi", Vector3.new(24, 0.2, 24), base * CFrame.new(0, 0, -14)
	front.Anchored, front.CanCollide, front.CanQuery, front.Transparency = true, false, false, 1
	front.Parent = sources
	emplacements.Parent = arena
	table.insert(changed, plot.Name)
end
local assets = game.ReplicatedStorage.Assets.Combat
local classes = { "Archer", "Epeiste", "Barbare", "Paladin", "Magicien", "Tireur" }
for index, class in classes do
	if assets:FindFirstChild(`Heros_{class}`) then continue end
	local model = assets.MannequinHeros:Clone()
	model.Name = `Heros_{class}`
	model:SetAttribute("HeroClass", class)
	model:SetAttribute("ProvisionalAsset", true)
	local head = model:FindFirstChild("Head", true) or model.PrimaryPart
	local tag = Instance.new("BillboardGui")
	tag.Name, tag.Adornee, tag.Size = "ClasseProvisoire", head, UDim2.fromOffset(120, 26)
	tag.StudsOffset, tag.AlwaysOnTop, tag.MaxDistance = Vector3.new(0, 2, 0), false, 90
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency, label.Text = UDim2.fromScale(1, 1), 0.2, class
	label.BackgroundColor3 = Color3.fromHSV((index - 1) / 6, 0.45, 0.65)
	label.TextColor3, label.TextSize = Color3.new(1, 1, 1), 16
	label.Font = Enum.Font.FredokaOne
	label.Parent, tag.Parent = tag, model
	model.Parent = assets
end
return changed
