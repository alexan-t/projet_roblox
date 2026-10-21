--!strict
-- Vitrine visitable des zones 2 à 6 (docs/ZONES.md § Vitrine visitable). Studio EDIT (barre de commande ou MCP).
-- Assets uniquement, aucun Source de script. À lancer APRÈS tools/studio-zones-assets.luau (décors et modèles).
-- Reconstruit Workspace.PlotsZones à chaque lancement :
--   1. cinq copies du plot de référence (Lobby.Plots.Plot_1) alignées au sud du Lobby, entrée vers le Lobby ;
--   2. tout le terrain prend le biome de sa zone : arène (décor ZonesArene), pelouse, royaume, bordure,
--      végétation remplacée par les accessoires du biome, sol de biome sous le terrain (plus de baseplate vert) ;
--   3. une limite du biome sépare l'avant (royaume, portail) de l'arène de combat, ouverte au portique ;
--   4. les monstres de la zone exposés devant le front ennemi ; chemin de dalles et passage dans le mur sud.
-- Rien n'est un point d'accès au gameplay : les combats se lancent depuis l'arène du plot du joueur.
-- Une étape ChangeHistoryService (Ctrl+Z).

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local function hex(h: string): Color3
	return Color3.fromHex(h)
end

-- Mêmes rampes que tools/studio-zones-assets.luau (familles de teintes de la Zone 1 → biome).
local ZONES = {
	{
		Id = 2, Nom = "Le Désert des Ruines", X = 120,
		Monsters = { "VaseDesSables", "ChacalParchemin", "ScarabeeForgeSoleil", "MangeDune", "GardienSansVisage" }, Boss = "ColosseEnseveli",
		Colors = {
			Leaf = { hex("#8C7A44"), hex("#B49A5A") }, Water = { hex("#3E8C8C"), hex("#64B4A0") }, Foam = { hex("#E8D2A0") },
			Sand = { hex("#C8A064"), hex("#E0C080") }, Stone = { hex("#8C6E4E"), hex("#B4946A") }, Ruin = { hex("#D2B48C"), hex("#E6CCA0") },
			Flower = { hex("#B4643C"), hex("#DC8C3C") }, Wood = { hex("#6E5032"), hex("#8C6A44") },
		},
		Ground = hex("#C8A46A"),
		Plants = { Arbre = "Pillar", Sapin = "Spikes", Buisson = "Remove", Touffe = "Remove", Mousse = "Remove" },
		Border = "Sandstone",
	},
	{
		Id = 3, Nom = "Les Terres Gelées", X = 310,
		Monsters = { "Givrelot", "CrocDeGlacier", "ArmureGelee", "BonhommeRoyal", "MammouthCristallin" }, Boss = "RoiSansEte",
		Colors = {
			Leaf = { hex("#9AB4C8"), hex("#D2E2EE") }, Water = { hex("#7CA8D2"), hex("#B4D2EB") }, Foam = { hex("#F0F6FA") },
			Sand = { hex("#DCE6F0"), hex("#F0F4F8") }, Stone = { hex("#6E7E8C"), hex("#9AAAB8") }, Ruin = { hex("#C8D4DE"), hex("#DCE4EC") },
			Flower = { hex("#8CB4DC"), hex("#64B4DC") }, Wood = { hex("#5A4A3C"), hex("#7A6650") },
		},
		Ground = hex("#DCE6EE"),
		Plants = { Buisson = "Remove", Touffe = "Remove" },
		Border = "Ice",
	},
	{
		Id = 4, Nom = "Les Forges", X = 500,
		Monsters = { "ChevalierRivete", "GolemCloche", "FourneauAmbulant", "Martelet", "Chaine" }, Boss = "MaitreDesForges",
		Colors = {
			Leaf = { hex("#4A4440"), hex("#665E56") }, Water = { hex("#C8461E"), hex("#F08C3C") }, Foam = { hex("#F5C542") },
			Sand = { hex("#5A5048"), hex("#6E6258") }, Stone = { hex("#3E3A38"), hex("#6A625C") }, Ruin = { hex("#7E766E"), hex("#8E867E") },
			Flower = { hex("#B4461E"), hex("#E07028") }, Wood = { hex("#3C2A22"), hex("#5E4232") },
		},
		Ground = hex("#4E4642"),
		Plants = { Arbre = "Chimney", Sapin = "Spikes", Buisson = "Remove", Touffe = "Remove", Mousse = "Remove" },
		Border = "Iron",
	},
	{
		Id = 5, Nom = "Les Abysses", X = 690,
		Monsters = { "MeduseCouronnee", "MureneMiroir", "CoffreBernard", "ChevalierNoye", "CrabeCathedrale" }, Boss = "Leviathan",
		Colors = {
			Leaf = { hex("#1E5A5A"), hex("#3C8C78") }, Water = { hex("#1E3C6E"), hex("#3C6EA0") }, Foam = { hex("#8CB4DC") },
			Sand = { hex("#8C8064"), hex("#A0947A") }, Stone = { hex("#3C4A5A"), hex("#5E7082") }, Ruin = { hex("#6E8296"), hex("#8296AA") },
			Flower = { hex("#C8644A"), hex("#E08C64") }, Wood = { hex("#4A3C32"), hex("#5E4E40") },
		},
		Ground = hex("#4E6270"),
		Plants = { Arbre = "Coral", Sapin = "Kelp", Buisson = "Remove" },
		Border = "Reef",
	},
	{
		Id = 6, Nom = "Les Îles du Ciel", X = 880,
		Monsters = { "GargouilleAilee", "MiniColosseCeleste", "MoutonNuage", "PoissonDuCiel", "BecTonnerre" }, Boss = "GardienCeleste",
		Colors = {
			Leaf = { hex("#E0D4B4"), hex("#F2ECDA") }, Water = { hex("#8CB4DC"), hex("#B4D2F0") }, Foam = { hex("#F0F6FA") },
			Sand = { hex("#E6E0D2"), hex("#F4F0E6") }, Stone = { hex("#A0A8B4"), hex("#C8CED8") }, Ruin = { hex("#E0DCD0"), hex("#F0ECE2") },
			Flower = { hex("#F5C542"), hex("#F5D778") },
		},
		Ground = hex("#EDE4CC"),
		Plants = { Sapin = "Cloud", Buisson = "Cloud", Touffe = "Remove", Mousse = "Remove" },
		Border = "Cloud",
	},
}
local LINE_Z = -360 -- au sud du Lobby (mur sud ≈ z 4), au nord du Bestiaire (z ≈ -498)
local PASSAGE_X = 331 -- face à la PlaceCentrale

-- Famille d'une teinte (copie de studio-zones-assets.luau).
local function family(c: Color3, material: Enum.Material): string
	local h, s, v = c:ToHSV()
	if material == Enum.Material.Neon then return "Glow" end
	if s < 0.25 and v > 0.7 then return if v > 0.93 then "Foam" else "Ruin" end
	if s < 0.32 then return "Stone" end
	if h >= 0.18 and h <= 0.45 then return "Leaf" end
	if h >= 0.5 and h <= 0.7 then return "Water" end
	if h < 0.13 and s > 0.6 and v > 0.9 then return "Fire" end
	if (h <= 0.06 or h >= 0.97) and s > 0.5 and v < 0.85 then return "Cloth" end
	if h >= 0.85 then return "Flower" end
	if h >= 0.09 and h <= 0.17 and v >= 0.78 then return "Sand" end
	return "Wood"
end
local RANGE = { Leaf = { 0.55, 0.76 }, Water = { 0.6, 1 }, Sand = { 0.82, 0.92 }, Stone = { 0.3, 0.68 }, Wood = { 0.4, 0.74 },
	Ruin = { 0.8, 0.88 }, Flower = { 0.9, 1 }, Foam = { 0.95, 1 } }
local function shade(c: Color3, fam: string, ramp: { Color3 }): Color3
	local _, _, v = c:ToHSV()
	local range = RANGE[fam] or { 0, 1 }
	local t = math.clamp((v - range[1]) / math.max(range[2] - range[1], 0.01), 0, 1)
	return if #ramp == 1 then ramp[1] else ramp[1]:Lerp(ramp[2], t)
end

local recording = ChangeHistoryService:TryBeginRecording("Zones 2 à 6 : vitrine visitable")

------------------------------------------------------------------ outils de pose

local holder: Instance = workspace
local function piece(parent: Instance, name: string, shape: Enum.PartType, size: Vector3, color: Color3, cf: CFrame,
	material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name, part.Shape, part.Size, part.CFrame, part.Color = name, shape, size, cf, color
	part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end
local function ellipsoid(part: Part, scale: Vector3?)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = scale or Vector3.one
	mesh.Parent = part
end
local FLAT = CFrame.Angles(0, 0, math.pi / 2) -- cylindre debout

-- Hauteur du sol sous (x, z), en ignorant `ignore`.
local function groundAt(x: number, z: number, ignore: { Instance }): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -160, 0), params)
	return if hit then hit.Position.Y else 0
end

local BIOME = {} -- accessoires posés sur un point au sol (Vector3 = pied)
function BIOME.Pillar(parent: Instance, at: Vector3, color: Color3, k: number)
	local h = (3.4 + math.abs(at.X + at.Z) % 3) * k
	piece(parent, "Colonne", Enum.PartType.Cylinder, Vector3.new(h, 1.5 * k, 1.5 * k), color, CFrame.new(at + Vector3.new(0, h / 2, 0)) * FLAT)
	piece(parent, "Bague", Enum.PartType.Cylinder, Vector3.new(0.4, 1.9 * k, 1.9 * k), color:Lerp(Color3.new(), 0.12),
		CFrame.new(at + Vector3.new(0, h, 0)) * FLAT)
end
function BIOME.Spikes(parent: Instance, at: Vector3, color: Color3, k: number, material: Enum.Material?)
	for i = 0, 2 do
		local h = (2.4 + i * 1.1) * k
		local offset = Vector3.new(math.cos(i * 2.1) * 0.9, 0, math.sin(i * 2.1) * 0.9) * k
		ellipsoid(piece(parent, "Pointe", Enum.PartType.Block, Vector3.new(0.9 * k, h, 0.9 * k), color,
			CFrame.new(at + offset + Vector3.new(0, h / 2 - 0.2, 0)) * CFrame.Angles(0.18 * (i - 1), i * 0.7, 0.15), material))
	end
end
function BIOME.Chimney(parent: Instance, at: Vector3, color: Color3, k: number)
	local h = 5 * k
	piece(parent, "Cheminee", Enum.PartType.Cylinder, Vector3.new(h, 1.6 * k, 1.6 * k), color, CFrame.new(at + Vector3.new(0, h / 2, 0)) * FLAT)
	piece(parent, "Cerclage", Enum.PartType.Cylinder, Vector3.new(0.35, 1.9 * k, 1.9 * k), color:Lerp(Color3.new(), 0.25),
		CFrame.new(at + Vector3.new(0, h * 0.4, 0)) * FLAT)
	piece(parent, "Braise", Enum.PartType.Cylinder, Vector3.new(0.2, 1.2 * k, 1.2 * k), hex("#F08C3C"),
		CFrame.new(at + Vector3.new(0, h + 0.05, 0)) * FLAT, Enum.Material.Neon)
end
function BIOME.Coral(parent: Instance, at: Vector3, color: Color3, k: number)
	for i = 0, 4 do
		local h = (1.6 + (i % 3) * 0.8) * k
		local a = i * 1.25
		ellipsoid(piece(parent, "Corail", Enum.PartType.Block, Vector3.new(0.6 * k, h, 0.6 * k), color,
			CFrame.new(at + Vector3.new(math.cos(a) * 0.6 * k, h / 2 - 0.1, math.sin(a) * 0.6 * k)) * CFrame.Angles(math.cos(a) * 0.35, 0, math.sin(a) * 0.35)))
	end
end
function BIOME.Kelp(parent: Instance, at: Vector3, color: Color3, k: number)
	for i = 0, 4 do
		local a = i * 1.3
		local h = (3.2 + (i % 3) * 0.7) * k
		piece(parent, "Algue", Enum.PartType.Cylinder, Vector3.new(h, 0.35 * k, 0.35 * k), color,
			CFrame.new(at + Vector3.new(math.cos(a) * 0.9, h / 2, math.sin(a) * 0.9)) * FLAT * CFrame.Angles((i - 2) * 0.08, 0, 0))
	end
end
function BIOME.Cloud(parent: Instance, at: Vector3, color: Color3, k: number)
	for i = 0, 3 do
		local d = (2.6 - (i % 2) * 0.8) * k
		ellipsoid(piece(parent, "Nuage", Enum.PartType.Ball, Vector3.one * d, color,
			CFrame.new(at + Vector3.new((i - 1.5) * 1.1 * k, d * 0.3, (i % 2) * 0.7 * k))), Vector3.new(1, 0.6, 1))
	end
end

-- Couleur de chaque accessoire de biome (pris dans la rampe du thème).
local function propColor(zone: any, kind: string): Color3
	if kind == "Pillar" then return zone.Colors.Ruin[1] end
	if kind == "Spikes" then return zone.Colors.Stone[2] end
	if kind == "Chimney" then return zone.Colors.Stone[1] end
	if kind == "Coral" then return zone.Colors.Flower[1] end
	if kind == "Kelp" then return zone.Colors.Leaf[2] end
	return zone.Colors.Foam[1] -- Cloud
end

------------------------------------------------------------------ limite avant / arène

-- Segments de x0 à x1 sur la ligne z, ouverts sur |x - gateX| < gap.
local function border(parent: Instance, zone: any, x0: number, x1: number, z: number, gateX: number, ignore: { Instance })
	local step, gap = 6, 9
	local index = 0
	for x = x0 + step / 2, x1 - step / 2, step do
		if math.abs(x - gateX) < gap then continue end
		index += 1
		local y = groundAt(x, z, ignore)
		local at = Vector3.new(x, y, z)
		local style = zone.Border
		if style == "Sandstone" then
			piece(parent, "Muret", Enum.PartType.Block, Vector3.new(step, 2.4, 1.6), zone.Colors.Ruin[1], CFrame.new(at + Vector3.new(0, 1.2, 0)))
			if index % 4 == 1 then BIOME.Pillar(parent, at, zone.Colors.Ruin[2], 0.8) end
		elseif style == "Ice" then
			piece(parent, "BlocGlace", Enum.PartType.Block, Vector3.new(step, 2.6, 1.6), zone.Colors.Water[2],
				CFrame.new(at + Vector3.new(0, 1.3, 0)) * CFrame.Angles(0, (index % 3 - 1) * 0.06, 0), Enum.Material.Ice)
			if index % 4 == 1 then BIOME.Spikes(parent, at, hex("#8CE0FF"), 0.9, Enum.Material.Ice) end
		elseif style == "Iron" then
			piece(parent, "Poteau", Enum.PartType.Cylinder, Vector3.new(3.2, 0.6, 0.6), zone.Colors.Stone[1], CFrame.new(at + Vector3.new(-step / 2, 1.6, 0)) * FLAT)
			for _, h in { 1.1, 2.4 } do
				piece(parent, "Lisse", Enum.PartType.Block, Vector3.new(step, 0.3, 0.3), zone.Colors.Stone[2], CFrame.new(at + Vector3.new(0, h, 0)))
			end
			if index % 4 == 1 then
				piece(parent, "Brasero", Enum.PartType.Cylinder, Vector3.new(0.5, 1.4, 1.4), hex("#F08C3C"),
					CFrame.new(at + Vector3.new(-step / 2, 3.4, 0)) * FLAT, Enum.Material.Neon)
			end
		elseif style == "Reef" then
			ellipsoid(piece(parent, "Recif", Enum.PartType.Block, Vector3.new(step + 0.6, 2.2, 2.2), zone.Colors.Stone[2],
				CFrame.new(at + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, index * 0.4, 0)))
			if index % 3 == 1 then BIOME.Coral(parent, at + Vector3.new(0, 1.2, 0), zone.Colors.Flower[2], 0.9) end
		else -- Cloud
			BIOME.Cloud(parent, at, zone.Colors.Foam[1], 1.3)
			if index % 4 == 1 then
				piece(parent, "PoteauDore", Enum.PartType.Cylinder, Vector3.new(3, 0.5, 0.5), hex("#F5C542"), CFrame.new(at + Vector3.new(0, 1.5, 0)) * FLAT)
			end
		end
	end
	-- deux repères plus hauts de part et d'autre du portique
	for _, side in { -1, 1 } do
		local x = gateX + side * (gap + 1)
		local at = Vector3.new(x, groundAt(x, z, ignore), z)
		local kind = if zone.Border == "Iron" then "Chimney" elseif zone.Border == "Reef" then "Coral" elseif zone.Border == "Cloud" then "Pillar"
			elseif zone.Border == "Ice" then "Spikes" else "Pillar"
		local color = if kind == "Pillar" and zone.Border == "Cloud" then hex("#F5C542") else propColor(zone, kind)
		BIOME[kind](parent, at, color, 1.3)
	end
end

------------------------------------------------------------------ construction

local folder = workspace:FindFirstChild("PlotsZones") or Instance.new("Folder")
folder.Name, folder.Parent = "PlotsZones", workspace
folder:ClearAllChildren()
holder = folder

local source = workspace.Lobby.Plots.Plot_1
local templates = ServerStorage.Assets.ZonesArene
local combat = ReplicatedStorage.Assets.Combat
local floors = Instance.new("Folder")
floors.Name, floors.Parent = "SolsBiomes", folder

for _, zone in ZONES do
	local plot = source:Clone()
	plot.Name = `Plot_Zone{zone.Id}`
	for key in plot:GetAttributes() do plot:SetAttribute(key, nil) end
	plot:SetAttribute("ZoneId", zone.Id)
	plot:SetAttribute("OwnerUserId", 0)
	plot:SetAttribute("Note", "Vitrine visitable (tools/studio-zones-vitrine.luau) : les combats se lancent depuis l'arène du plot du joueur.")
	for _, name in { "Apercu_Issue35", "PortailInvocation", "PointApparition" } do
		local child = plot:FindFirstChild(name)
		if child then child:Destroy() end
	end
	-- le plot de référence a son avant (pelouse, royaume) vers +Z local : le tourner vers le Lobby (+Z monde)
	local pivot = source:GetPivot()
	local center = workspace.Lobby.PlaceCentrale:GetBoundingBox().Position
	local front = pivot:VectorToObjectSpace(((center - pivot.Position) * Vector3.new(1, 0, 1)).Unit)
	local yaw = math.atan2(front.X, front.Z)
	plot:PivotTo(CFrame.new(zone.X, pivot.Position.Y, LINE_Z) * CFrame.Angles(0, -yaw, 0))
	plot.Parent = folder

	-- arène : décor de la zone
	local arena = plot:FindFirstChild("Arene") :: Model
	local zonesFolder = arena:FindFirstChild("Zones") or Instance.new("Folder")
	zonesFolder.Name, zonesFolder.Parent = "Zones", arena
	zonesFolder:ClearAllChildren()
	local template: Model? = nil
	for _, t in templates:GetChildren() do
		if t:GetAttribute("ZoneId") == zone.Id and t:IsA("Model") then template = t end
	end
	assert(template, `décor de la zone {zone.Id} introuvable : lancer tools/studio-zones-assets.luau`)
	local decor = template:Clone()
	decor:PivotTo(arena:GetPivot())
	decor.Parent = zonesFolder

	-- tout le reste du terrain prend la palette du biome
	for _, d in plot:GetDescendants() do
		if d:IsA("BasePart") and not d:IsDescendantOf(zonesFolder) and not d:IsDescendantOf(arena:FindFirstChild("Emplacements") or zonesFolder) then
			local fam = family(d.Color, d.Material)
			local ramp = zone.Colors[fam]
			if ramp then d.Color = shade(d.Color, fam, ramp) end
		end
	end
	for _, d in plot.PanneauProprietaire:GetDescendants() do
		if d:IsA("TextLabel") then d.Text = zone.Nom end
	end

	-- végétation de la pelouse : accessoires du biome
	local nature = plot:FindFirstChild("Nature")
	local props = Instance.new("Folder")
	props.Name, props.Parent = "DecorBiome", plot
	if nature then
		for _, item in nature:GetChildren() do
			local kind = zone.Plants[item.Name]
			if not kind then continue end
			local cf, size
			if item:IsA("Model") then cf, size = item:GetBoundingBox() elseif item:IsA("BasePart") then cf, size = item.CFrame, item.Size end
			if not cf then continue end
			local foot = Vector3.new(cf.Position.X, cf.Position.Y - size.Y / 2, cf.Position.Z)
			item:Destroy()
			if kind ~= "Remove" then
				local k = if item.Name == "Arbre" then 1.3 elseif item.Name == "Sapin" then 1.1 else 0.8
				BIOME[kind](props, foot, propColor(zone, kind), k)
			end
		end
	end

	-- sol de biome sous le terrain (remplace le vert du baseplate)
	local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
	for _, d in plot:GetDescendants() do
		if d:IsA("BasePart") and d.Position.Y < 12 then
			x0, x1 = math.min(x0, d.Position.X - d.Size.X / 2), math.max(x1, d.Position.X + d.Size.X / 2)
			z0, z1 = math.min(z0, d.Position.Z - d.Size.Z / 2), math.max(z1, d.Position.Z + d.Size.Z / 2)
		end
	end
	local floor = piece(floors, `Sol_Zone{zone.Id}`, Enum.PartType.Block, Vector3.new(188, 0.1, (z1 - z0) + 40), zone.Ground,
		CFrame.new(zone.X, 0.05, (z0 + z1) / 2 - 8))
	floor.CanCollide, floor.CanQuery = true, true

	-- limite entre l'avant (royaume, portail) et l'arène, ouverte au portique EntreeZone
	local entry = decor:FindFirstChild("EntreeZone")
	local gateX, gateZ = zone.X, LINE_Z + 23
	if entry then
		local gx0, gx1, gz = math.huge, -math.huge, -math.huge
		for _, d in entry:GetDescendants() do
			if d:IsA("BasePart") then
				gx0, gx1 = math.min(gx0, d.Position.X), math.max(gx1, d.Position.X)
				gz = math.max(gz, d.Position.Z + d.Size.Z / 2)
			end
		end
		gateX, gateZ = (gx0 + gx1) / 2, gz + 1.5
	end
	local ax0, ax1 = math.huge, -math.huge
	for _, d in decor:GetDescendants() do
		if d:IsA("BasePart") and math.abs(d.Position.Z - gateZ) < 12 and d.Position.Y < 15 then
			ax0, ax1 = math.min(ax0, d.Position.X - d.Size.X / 2), math.max(ax1, d.Position.X + d.Size.X / 2)
		end
	end
	if ax0 == math.huge then ax0, ax1 = zone.X - 62, zone.X + 62 end
	local limit = Instance.new("Folder")
	limit.Name, limit.Parent = "LimiteArene", plot
	border(limit, zone, ax0, ax1, gateZ, gateX, { limit, props })

	-- monstres de la zone devant le front ennemi
	local show = Instance.new("Model")
	show.Name, show.Parent = "MonstresDeLaZone", plot
	local sources = decor:FindFirstChild("SourcesEnnemis")
	local frontPart = sources and sources:FindFirstChild("FrontEnnemi", true)
	local frontCf = if frontPart and frontPart:IsA("BasePart") then frontPart.CFrame
		elseif frontPart and frontPart:IsA("PVInstance") then frontPart:GetPivot() else arena:GetPivot()
	local toHeroes = (Vector3.new(gateX, 0, gateZ) - frontCf.Position) * Vector3.new(1, 0, 1)
	toHeroes = if toHeroes.Magnitude > 1 then toHeroes.Unit else Vector3.zAxis
	local side = toHeroes:Cross(Vector3.yAxis)
	local list = table.clone(zone.Monsters)
	table.insert(list, zone.Boss)
	for index, id in list do
		local source = combat:FindFirstChild(`Ennemi_{id}`) :: Model?
		assert(source, `Ennemi_{id} introuvable : lancer tools/studio-zones-assets.luau`)
		local model = source:Clone()
		local at = frontCf.Position + side * ((index - 3.5) * 9) - toHeroes * (if id == zone.Boss then 8 else 0)
		model:PivotTo(CFrame.lookAt(at, at + toHeroes))
		model.Parent = show
		local cf, size = model:GetBoundingBox()
		local y = groundAt(cf.Position.X, cf.Position.Z, { show })
		model:PivotTo(model:GetPivot() + Vector3.new(0, y - (cf.Position.Y - size.Y / 2), 0))
	end
	task.wait()
end

------------------------------------------------------------------ chemin et passage dans le mur sud du Lobby

local archive = ServerStorage:FindFirstChild("Archive_PassageZones") or Instance.new("Folder")
archive.Name, archive.Parent = "Archive_PassageZones", ServerStorage
local monde = workspace.Lobby:FindFirstChild("Monde")
for _, name in { "Limites", "ForetBordure" } do
	local group = monde and monde:FindFirstChild(name)
	for _, item in if group then group:GetChildren() else {} do
		local ok, cf = pcall(function() return (item :: any):GetPivot() end)
		if ok and cf.Position.Z < 45 and cf.Position.Z > -40 and math.abs(cf.Position.X - PASSAGE_X) < 46 then
			item.Parent = archive
		end
	end
end
local sample = workspace.Lobby.RouteTitans:FindFirstChild("Dalle") :: BasePart
local path = Instance.new("Folder")
path.Name, path.Parent = "CheminZones", folder
local function tile(x: number, z: number)
	local t = sample:Clone()
	t.Size = Vector3.new(12, 0.4, 12)
	t.CFrame = CFrame.new(x, groundAt(x, z, { path }) + 0.2, z)
	t.Anchored, t.CanCollide = true, true
	t.Parent = path
end
for z = 30, LINE_Z + 122, -12 do tile(PASSAGE_X, z) end
for x = ZONES[1].X, ZONES[#ZONES].X, 12 do
	if math.abs(x - PASSAGE_X) > 6 then tile(x, LINE_Z + 110) end
end

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
print(`Vitrine des zones : {#ZONES} terrains dans Workspace.PlotsZones`)
