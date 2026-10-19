-- Zones 2 à 6 (docs/ZONES.md § Assets Studio). À exécuter dans Studio EDIT (barre de commande ou MCP).
-- Assets uniquement, aucun Source de script. Répétable : reconstruit ses propres objets, ne touche à rien d'autre.
--   1. ReplicatedStorage.Assets.Combat.Ennemi_<EnemyId> : copies de combat statiques des monstres VALIDÉS
--      (Workspace, docs/ART_DIRECTION.md § 1), pivot tourné de 180° (l'avant du pivot = le visage), CouleurEffet.
--   2. ServerStorage.Assets.ZonesArene.Zone<n>_<Nom> : décor de chaque zone, dérivé du décor de la Zone 1 de
--      l'arène de Plot_1 (même plan, mêmes repères SourcesEnnemis / FrontEnnemi), WorldPivot = pivot de l'arène :
--      ZoneDecor le pose dans l'arène de n'importe quel plot avec PivotTo(arena:GetPivot()).
-- Une étape ChangeHistoryService (Ctrl+Z).

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local recording = ChangeHistoryService:TryBeginRecording("Zones 2 à 6 : assets")

------------------------------------------------------------------ 1. modèles de combat

local ENEMIES = {
	{ Id = "SlimePlante", Source = "Slime_Plante", Color = "#64B464" },
	{ Id = "SlimeChampignon", Source = "Slime_Champignon", Color = "#DCB48C" },
	{ Id = "SlimeLave", Source = "Slime_Lave", Color = "#F08C3C" },
	{ Id = "GobelinDague", Source = "GobDagueT_B", Color = "#8C8C8C" },
	{ Id = "Treant", Source = "Treant_Masque", Color = "#8C643C" },
	{ Id = "TreantArbre", Source = "Treant_Arbre", Color = "#8CDC64" },
	{ Id = "KingSlime", Source = "KingSlime", Color = "#64B4DC" },
	{ Id = "KingTreant", Source = "KingTreant", Color = "#8C643C" },
}

local combat = ReplicatedStorage.Assets.Combat
for _, entry in ENEMIES do
	local source = workspace:FindFirstChild(entry.Source)
	assert(source and source:IsA("Model"), `monstre validé introuvable : Workspace.{entry.Source}`)
	local old = combat:FindFirstChild(`Ennemi_{entry.Id}`)
	if old then old:Destroy() end
	local model = source:Clone()
	model.Name = `Ennemi_{entry.Id}`
	for _, d in model:GetDescendants() do
		if d:IsA("BaseScript") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanTouch, d.CanQuery = true, false, false, false
		end
	end
	-- Bestiaire : les modèles regardent vers +Z du pivot ; en combat, l'avant du pivot doit être le visage.
	local pivot = model:GetPivot()
	model.WorldPivot = CFrame.new(pivot.Position) * pivot.Rotation * CFrame.Angles(0, math.pi, 0)
	model:PivotTo(CFrame.new(0, 50, 0))
	model:SetAttribute("CouleurEffet", Color3.fromHex(entry.Color))
	model:SetAttribute("EnemyId", entry.Id)
	model:SetAttribute("Source", `Workspace.{entry.Source}`)
	model.Parent = combat
end

------------------------------------------------------------------ 2. décors de zone

local arena = workspace.Lobby.Plots.Plot_1.Arene
local base = arena.Zones:FindFirstChild("Zone1_PlaineDuRoyaume")
	or ServerStorage:FindFirstChild("ZonesRangees_Plot_1") and ServerStorage.ZonesRangees_Plot_1:FindFirstChild("Zone1_PlaineDuRoyaume")
assert(base, "décor Zone1_PlaineDuRoyaume introuvable")
local PIVOT = arena:GetPivot()
local GROUND_TOP = 3.635 -- entre l'herbe du plot (3,60) et les chemins (3,69) / la clairière (3,74)

local assets = ServerStorage:FindFirstChild("Assets") or Instance.new("Folder")
assets.Name, assets.Parent = "Assets", ServerStorage
local templates = assets:FindFirstChild("ZonesArene") or Instance.new("Folder")
templates.Name, templates.Parent = "ZonesArene", assets
templates:ClearAllChildren()

local function hex(h: string): Color3
	return Color3.fromHex(h)
end

-- Famille d'une teinte de la Zone 1 (palette relevée : herbe, eau, sable, pierre, bois, fleurs, lueur).
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

-- Plage de luminosité d'une famille dans la Zone 1 (pour garder les nuances : sombre → clair).
local RANGE = { Leaf = { 0.55, 0.76 }, Water = { 0.6, 1 }, Sand = { 0.82, 0.92 }, Stone = { 0.3, 0.68 }, Wood = { 0.4, 0.74 },
	Ruin = { 0.8, 0.88 }, Flower = { 0.9, 1 }, Glow = { 0.9, 0.92 }, Foam = { 0.95, 1 }, Cloth = { 0.7, 0.75 } }

local function shade(c: Color3, fam: string, ramp: { Color3 }): Color3
	local _, _, v = c:ToHSV()
	local range = RANGE[fam]
	local t = math.clamp((v - range[1]) / math.max(range[2] - range[1], 0.01), 0, 1)
	if #ramp == 1 then return ramp[1] end
	return ramp[1]:Lerp(ramp[2], t)
end

-- Thèmes : rampes (sombre, clair) par famille ; familles absentes = inchangées.
local THEMES = {
	{
		Id = 2, Name = "Zone2_MareAuxSlimes", Nom = "La Mare aux Slimes",
		Colors = {
			Leaf = { hex("#4E7A3E"), hex("#7FA85A") }, Water = { hex("#3E8C7E"), hex("#7CC8B4") }, Foam = { hex("#D8F0E4") },
			Sand = { hex("#8C7452"), hex("#A68C64") }, Flower = { hex("#C8A0DC"), hex("#DCB48C") }, Glow = { hex("#7CF0A0") },
		},
		Light = hex("#7CF0A0"),
		Ground = { hex("#5E7A44"), hex("#6E8A4C"), hex("#4E6A3C") },
		Remove = {},
		TreeScale = 1,
	},
	{
		Id = 3, Name = "Zone3_ForetDesTreants", Nom = "La Forêt des Tréants",
		Colors = {
			Leaf = { hex("#2E6428"), hex("#5A9640") }, Sand = { hex("#7A5A3A"), hex("#8C6A44") }, Flower = { hex("#8CDC64"), hex("#B4E07C") },
			Water = { hex("#3C86C8"), hex("#6CB4E4") },
		},
		Light = hex("#48E8E8"),
		Ground = { hex("#3E6E30"), hex("#4A7A36"), hex("#34602A") },
		Remove = { SlimeDecor = true },
		TreeScale = 1.45,
	},
	{
		Id = 4, Name = "Zone4_CampDeLaHorde", Nom = "Le Camp de la Horde",
		Colors = {
			Leaf = { hex("#64643C"), hex("#A09A50") }, Sand = { hex("#A07850"), hex("#B48A5A") }, Flower = { hex("#B41414"), hex("#8C3C3C") },
			Water = { hex("#6E5E40"), hex("#9A8A64") }, Foam = { hex("#C8B890") }, Glow = { hex("#E07028") },
		},
		Light = hex("#FF8C28"),
		Ground = { hex("#8A7A4A"), hex("#9C8A58"), hex("#7A6A40") },
		Remove = { SlimeDecor = true },
		TreeScale = 1,
	},
	{
		Id = 5, Name = "Zone5_GrottesDeLave", Nom = "Les Grottes de Lave",
		Colors = {
			Leaf = { hex("#4A4040"), hex("#665A54") }, Water = { hex("#A8300E"), hex("#E0641E") }, Foam = { hex("#F09A3C") },
			Sand = { hex("#5E5250"), hex("#746660") }, Stone = { hex("#3E3634"), hex("#6A5E5A") }, Ruin = { hex("#7E7470"), hex("#8E847E") },
			Flower = { hex("#C8461E"), hex("#E0701E") }, Glow = { hex("#E07028") }, Wood = { hex("#3C2A22"), hex("#5E4232") },
		},
		LavaWater = true,
		Light = hex("#FF8C28"),
		Ground = { hex("#4E4442"), hex("#5A4C48"), hex("#443A38") },
		-- pas de végétation dans les grottes : les arbres deviennent des pointes de basalte (Replace)
		Remove = { SlimeDecor = true, Buisson = true, Fleur = true },
		Replace = { Arbre = true, Sapin = true },
		TreeScale = 1,
	},
	{
		Id = 6, Name = "Zone6_BoisAncien", Nom = "Le Bois Ancien",
		Colors = {
			Leaf = { hex("#24482A"), hex("#4A7A3A") }, Sand = { hex("#6A5A3A"), hex("#7C6A46") }, Flower = { hex("#64B4DC"), hex("#8CB4DC") },
			Water = { hex("#2E6E7A"), hex("#5AA0AE") }, Stone = { hex("#4E5A4A"), hex("#7A8270") }, Ruin = { hex("#8A9078"), hex("#9EA48A") },
		},
		Light = hex("#48E8E8"),
		Ground = { hex("#2E4E2A"), hex("#3A5E32"), hex("#284426") },
		Remove = { SlimeDecor = true },
		TreeScale = 1.8,
	},
}

-- Pièce décorative ancrée, sans collision, posée en coordonnées locales de l'arène (Y = 0 : sol du plot, 3,60).
local GROUND_Y = 3.6
local function piece(parent: Instance, name: string, shape: Enum.PartType, size: Vector3, color: Color3, localPos: Vector3,
	rotation: CFrame?, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	local world = PIVOT:PointToWorldSpace(Vector3.new(localPos.X, 0, localPos.Z))
	part.CFrame = CFrame.new(world.X, GROUND_Y + localPos.Y, world.Z) * PIVOT.Rotation * (rotation or CFrame.identity)
	part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
	part.Material = material or Enum.Material.SmoothPlastic
	part.Color = color
	part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local FLAT = CFrame.Angles(0, 0, math.pi / 2) -- cylindre couché sur le sol (axe vertical)

-- Sol de la zone : même forme que Sol.Herbe du plot (cercle arrière de 112 + rectangle) jusqu'au porche
-- (z local 50), 0,035 stud au-dessus de l'herbe, sous les chemins et la clairière de la Zone 1.
local function groundOf(parent: Instance, colors: { Color3 })
	local top = GROUND_TOP - GROUND_Y
	piece(parent, "Fond", Enum.PartType.Cylinder, Vector3.new(0.4, 112, 112), colors[1], Vector3.new(0.1, top - 0.2, 2.3), FLAT)
	piece(parent, "FondAvant", Enum.PartType.Block, Vector3.new(112, 0.4, 47.7), colors[1], Vector3.new(0.1, top - 0.2, 26.15))
	local patches = { { -30, 26, 26 }, { 32, 30, 22 }, { -36, -26, 26 }, { 34, -30, 22 }, { -4, -44, 20 }, { 40, 4, 16 }, { -42, 6, 16 } }
	for index, p in patches do
		piece(parent, "Tache", Enum.PartType.Cylinder, Vector3.new(0.4, p[3], p[3]), colors[if index % 2 == 0 then 2 else 3],
			Vector3.new(p[1], top - 0.18, p[2]), FLAT)
	end
end

-- Accessoires de zone (formes rondes et gonflées, comme le décor de la Zone 1).
local function mushroom(parent: Instance, at: Vector3, height: number, cap: Color3, stem: Color3, glow: boolean?)
	piece(parent, "Pied", Enum.PartType.Cylinder, Vector3.new(height, height * 0.32, height * 0.32), stem, at + Vector3.new(0, height / 2, 0), FLAT)
	local hat = piece(parent, "Chapeau", Enum.PartType.Ball, Vector3.one * height * 0.95, cap, at + Vector3.new(0, height, 0), nil,
		if glow then Enum.Material.Neon else nil)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1, 0.55, 1)
	mesh.Parent = hat
end

local function reeds(parent: Instance, at: Vector3, color: Color3, tip: Color3)
	for i = 0, 4 do
		local angle = i * 1.3
		local offset = Vector3.new(math.cos(angle) * 0.9, 0, math.sin(angle) * 0.9)
		local h = 3.2 + (i % 3) * 0.7
		piece(parent, "Roseau", Enum.PartType.Cylinder, Vector3.new(h, 0.28, 0.28), color, at + offset + Vector3.new(0, h / 2, 0),
			FLAT * CFrame.Angles((i - 2) * 0.06, 0, 0))
		piece(parent, "Massette", Enum.PartType.Cylinder, Vector3.new(0.8, 0.45, 0.45), tip, at + offset + Vector3.new(0, h + 0.2, 0), FLAT)
	end
end

local function pool(parent: Instance, at: Vector3, diameter: number, water: Color3, rim: Color3, material: Enum.Material?)
	piece(parent, "Bord", Enum.PartType.Cylinder, Vector3.new(0.5, diameter + 1.6, diameter + 1.6), rim, at + Vector3.new(0, 0.1, 0), FLAT)
	piece(parent, "Mare", Enum.PartType.Cylinder, Vector3.new(0.5, diameter, diameter), water, at + Vector3.new(0, 0.2, 0), FLAT, material)
end

local function spikes(parent: Instance, at: Vector3, color: Color3, material: Enum.Material?, scale: number?)
	local k = scale or 1
	for i = 0, 2 do
		local h = (2.4 + i * 1.1) * k
		local offset = Vector3.new(math.cos(i * 2.1) * 0.9, 0, math.sin(i * 2.1) * 0.9) * k
		piece(parent, "Pointe", Enum.PartType.Block, Vector3.new(0.9, h, 0.9) * Vector3.new(k, 1, k), color, offset + at + Vector3.new(0, h / 2 - 0.2, 0),
			CFrame.Angles(0.18 * (i - 1), i * 0.7, 0.15), material)
	end
end

local function cloneProp(parent: Instance, source: Instance?, at: Vector3, scale: number, turn: number)
	if not source or not source:IsA("Model") then return end
	local copy = source:Clone()
	copy:ScaleTo(copy:GetScale() * scale)
	local cf, size = copy:GetBoundingBox()
	local world = PIVOT:PointToWorldSpace(Vector3.new(at.X, 0, at.Z))
	local delta = Vector3.new(world.X - cf.Position.X, GROUND_Y + at.Y - (cf.Position.Y - size.Y / 2), world.Z - cf.Position.Z)
	copy:PivotTo((copy:GetPivot() + delta) * CFrame.Angles(0, turn, 0))
	copy.Parent = parent
end

-- Emplacements libres du décor de la Zone 1 (coordonnées locales de l'arène, relevés dans Studio : hors
-- chemins, hors cases héros et front ennemi, hors accessoires ; l'allée d'entrée |x| < 9 reste dégagée).
local SPOTS = {
	Left = { Vector3.new(-48, 0, 34), Vector3.new(-42, 0, 28), Vector3.new(-36, 0, 34), Vector3.new(-30, 0, 28), Vector3.new(-24, 0, 34),
		Vector3.new(-18, 0, 30), Vector3.new(-42, 0, -8) },
	Right = { Vector3.new(24, 0, 34), Vector3.new(30, 0, 28), Vector3.new(36, 0, 34), Vector3.new(42, 0, 28), Vector3.new(48, 0, 40),
		Vector3.new(42, 0, 40), Vector3.new(42, 0, -14) },
	Back = { Vector3.new(12, 0, -38) },
}

local function props(parent: Instance, base: Instance, id: number)
	local veg = base:FindFirstChild("Vegetation")
	local tree = veg and veg:FindFirstChild("Arbre")
	local pine = veg and veg:FindFirstChild("Sapin")
	local camp = base:FindFirstChild("CampGobelin")
	local rocks = base:FindFirstChild("Rochers")
	local rock = rocks and rocks:FindFirstChild("Rocher")
	local all = {}
	for _, list in { SPOTS.Left, SPOTS.Right, SPOTS.Back } do
		for _, p in list do table.insert(all, p) end
	end
	if id == 2 then
		-- Mare aux Slimes : mares, roseaux, champignons
		for index, p in all do
			if index % 3 == 1 then pool(parent, p, 4.5, hex("#4E9C8C"), hex("#7E7064"))
			elseif index % 3 == 2 then reeds(parent, p, hex("#5E7A3A"), hex("#6C442A"))
			else mushroom(parent, p, 2.2, hex("#C8A0DC"), hex("#ECE0C8")) end
		end
	elseif id == 3 then
		-- Forêt des Tréants : arbres serrés, champignons à la lisière
		for index, p in all do
			if index % 2 == 1 then cloneProp(parent, tree, p, 1, index) else cloneProp(parent, pine, p, 0.9, index) end
		end
		for index, p in SPOTS.Left do
			mushroom(parent, p + Vector3.new(3, 0, -2.5), 1.4, hex("#B41414"), hex("#ECE0C8"))
		end
	elseif id == 4 then
		-- Camp de la Horde : tentes, palissades, tonneaux
		local tent = camp and camp:FindFirstChild("TenteGobeline")
		local fence = camp and camp:FindFirstChild("Palissade")
		for index, p in all do
			if index % 3 == 1 then cloneProp(parent, tent, p, 0.8, index * 0.9)
			elseif index % 3 == 2 then cloneProp(parent, fence, p, 0.8, index * 1.7)
			else cloneProp(parent, rock, p, 1.2, index) end
		end
	elseif id == 5 then
		-- Grottes de Lave : mares de lave, pointes de basalte, cristaux de braise
		for index, p in all do
			if index % 3 == 1 then pool(parent, p, 4, hex("#C8461E"), hex("#3E3634"), Enum.Material.Neon)
			elseif index % 3 == 2 then spikes(parent, p, hex("#5A4C48"), nil, 1.3)
			else spikes(parent, p, hex("#E07028"), Enum.Material.Neon) end
		end
	elseif id == 6 then
		-- Bois Ancien : très grands arbres, champignons lumineux
		for index, p in all do
			if index % 2 == 1 then cloneProp(parent, tree, p, 1.1, index) else mushroom(parent, p, 2.6, hex("#64B4DC"), hex("#DCD2B4"), true) end
		end
	end
end

local function bottomOf(model: Model): number
	local cf, size = model:GetBoundingBox()
	return cf.Position.Y - size.Y / 2
end

for _, theme in THEMES do
	local folder = base:Clone()
	local model = Instance.new("Model")
	model.Name = theme.Name
	for _, child in folder:GetChildren() do child.Parent = model end
	folder:Destroy()
	for key, value in base:GetAttributes() do model:SetAttribute(key, value) end
	model:SetAttribute("ZoneId", theme.Id)
	model:SetAttribute("Nom", theme.Nom)
	model:SetAttribute("Note", "Décor généré par tools/studio-zones-assets.luau depuis Zone1_PlaineDuRoyaume")

	-- retraits (ex. slimes de décor de la Zone 1 hors de la Mare aux Slimes) et remplacements
	local replaced: { Vector3 } = {}
	for _, d in model:GetDescendants() do
		if theme.Replace and theme.Replace[d.Name] and d:IsA("Model") and d.Parent then
			local cf, size = d:GetBoundingBox()
			local at = PIVOT:PointToObjectSpace(cf.Position)
			table.insert(replaced, Vector3.new(at.X, cf.Position.Y - size.Y / 2 - GROUND_Y, at.Z))
			d:Destroy()
		elseif theme.Remove[d.Name] and d.Parent then
			d:Destroy()
		end
	end
	-- arbres plus grands dans les forêts (pied recalé au sol)
	if theme.TreeScale ~= 1 then
		for _, d in model:GetDescendants() do
			if d:IsA("Model") and (d.Name == "Arbre" or d.Name == "Sapin") and not d:IsDescendantOf(model.Rempart) then
				local bottom = bottomOf(d)
				d:ScaleTo(d:GetScale() * theme.TreeScale)
				d:PivotTo(d:GetPivot() + Vector3.new(0, bottom - bottomOf(d), 0))
			end
		end
	end
	-- couleurs par famille, matière de l'eau, lumières
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and not d:IsDescendantOf(model.SourcesEnnemis) and d.Name ~= "Flamme" then
			local fam = family(d.Color, d.Material)
			local ramp = theme.Colors[fam]
			if ramp then d.Color = shade(d.Color, fam, ramp) end
			if theme.LavaWater and (fam == "Water" or fam == "Foam") then
				d.Material = Enum.Material.Neon
			end
		elseif d:IsA("PointLight") then
			d.Color = theme.Light
		elseif d:IsA("TextLabel") and d.Name == "TitreZone" then
			d.Text = `Zone {theme.Id}`
		end
	end
	if theme.LavaWater then
		-- lueur de la lave : quelques lumières orangées dans la rivière et les mares
		for _, name in { "Bassin", "MareCentre" } do
			for _, d in model:GetDescendants() do
				if d.Name == name and d:IsA("BasePart") then
					local light = Instance.new("PointLight")
					light.Color, light.Range, light.Brightness = hex("#FF8C28"), 14, 1.2
					light.Parent = d
				end
			end
		end
	end
	-- sol de la zone : recouvre l'herbe du plot dans l'arène (taches peintes de 3 nuances)
	local ground = Instance.new("Folder")
	ground.Name, ground.Parent = "SolZone", model
	groundOf(ground, theme.Ground)
	local extra = Instance.new("Folder")
	extra.Name, extra.Parent = "DecorZone", model
	props(extra, model, theme.Id)
	for index, at in replaced do
		spikes(extra, at, if index % 4 == 0 then hex("#E07028") else hex("#5A4C48"), if index % 4 == 0 then Enum.Material.Neon else nil, 1.8)
	end
	model.WorldPivot = PIVOT
	model.Parent = templates
end

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
print(`Zones 2 à 6 : {#ENEMIES} modèles de combat, {#THEMES} décors dans ServerStorage.Assets.ZonesArene`)
