--!strict
-- Zones 2 à 6 (docs/ZONES.md § Assets Studio). À exécuter dans Studio EDIT (barre de commande ou MCP).
-- Assets uniquement, aucun Source de script. Répétable : reconstruit ses propres objets, ne touche à rien d'autre.
--   1. ReplicatedStorage.Assets.Combat.Ennemi_<EnemyId> : copies de combat statiques des monstres VALIDÉS
--      (Workspace, docs/ART_DIRECTION.md § 1), pivot tourné de 180° (l'avant du pivot = le visage), CouleurEffet.
--   2. ServerStorage.Assets.ZonesArene.Zone<n>_<Nom> : décor de chaque zone (désert, glace, forges, abysses, ciel), dérivé du décor de la Zone 1 de
--      l'arène de Plot_1 (même plan, mêmes repères SourcesEnnemis / FrontEnnemi), WorldPivot = pivot de l'arène :
--      ZoneDecor le pose dans l'arène de n'importe quel plot avec PivotTo(arena:GetPivot()).
-- Une étape ChangeHistoryService (Ctrl+Z).

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local recording = ChangeHistoryService:TryBeginRecording("Zones 2 à 6 : assets")

------------------------------------------------------------------ 1. modèles de combat

local ENEMIES = {
	-- Certains sandboxes n'ont que les mannequins. Préserver les versions articulées si présentes.
	{ Id = "Slime", Source = "Slime_Eau", Color = "#76CCF6", OnlyIfMissing = true },
	{ Id = "Gobelin", Source = "GobLanceT_A", Color = "#8C8C8C", OnlyIfMissing = true },
	{ Id = "RoiOrc", Source = "RoiOrc", Color = "#8C8C8C", OnlyIfMissing = true },
	{ Id = "SlimePlante", Source = "Slime_Plante", Color = "#64B464" },
	{ Id = "SlimeChampignon", Source = "Slime_Champignon", Color = "#DCB48C" },
	{ Id = "SlimeLave", Source = "Slime_Lave", Color = "#F08C3C" },
	{ Id = "GobelinDague", Source = "GobDagueT_B", Color = "#8C8C8C" },
	{ Id = "Treant", Source = "Treant_Masque", Color = "#8C643C" },
	{ Id = "TreantArbre", Source = "Treant_Arbre", Color = "#8CDC64" },
	{ Id = "KingSlime", Source = "KingSlime", Color = "#64B4DC" },
	{ Id = "KingTreant", Source = "KingTreant", Color = "#8C643C" },
	-- Zones 2 à 6, version B (faune des fiches automation/briefs) : modèles du Bestiaire (Workspace)
	{ Id = "VaseDesSables", Source = "VaseDesSables", Color = "#DCB48C" },
	{ Id = "ChacalParchemin", Source = "ChacalParchemin", Color = "#B4B48C" },
	{ Id = "ScarabeeForgeSoleil", Source = "ScarabeeForgeSoleil", Color = "#F5C542" },
	{ Id = "MangeDune", Source = "MangeDune", Color = "#8C643C" },
	{ Id = "GardienSansVisage", Source = "GardienSansVisage", Color = "#B4B48C" },
	{ Id = "ColosseEnseveli", Source = "ColosseEnseveli", Color = "#DCB48C" },
	{ Id = "Givrelot", Source = "Givrelot", Color = "#8CB4DC" },
	{ Id = "CrocDeGlacier", Source = "CrocDeGlacier", Color = "#64B4DC" },
	{ Id = "ArmureGelee", Source = "ArmureGelee", Color = "#8CB4DC" },
	{ Id = "BonhommeRoyal", Source = "BonhommeRoyal", Color = "#DCDCDC" },
	{ Id = "MammouthCristallin", Source = "MammouthCristallin", Color = "#64B4DC" },
	{ Id = "RoiSansEte", Source = "RoiSansEte", Color = "#8CB4DC" },
	{ Id = "ChevalierRivete", Source = "ChevalierRivete", Color = "#8C8C8C" },
	{ Id = "GolemCloche", Source = "GolemCloche", Color = "#B48C3C" },
	{ Id = "FourneauAmbulant", Source = "FourneauAmbulant", Color = "#F08C3C" },
	{ Id = "Martelet", Source = "Martelet", Color = "#8C8C8C" },
	{ Id = "Chaine", Source = "Chaine", Color = "#646464" },
	{ Id = "MaitreDesForges", Source = "MaitreDesForges", Color = "#F08C3C" },
	{ Id = "MeduseCouronnee", Source = "MeduseCouronnee", Color = "#64B4DC" },
	{ Id = "MureneMiroir", Source = "MureneMiroir", Color = "#648CDC" },
	{ Id = "CoffreBernard", Source = "CoffreBernard", Color = "#B48C3C" },
	{ Id = "ChevalierNoye", Source = "ChevalierNoye", Color = "#64B4A0" },
	{ Id = "CrabeCathedrale", Source = "CrabeCathedrale", Color = "#B4643C" },
	{ Id = "Leviathan", Source = "Leviathan", Color = "#648CDC" },
	{ Id = "GargouilleAilee", Source = "GargouilleAilee", Color = "#8C8C8C" },
	{ Id = "MiniColosseCeleste", Source = "MiniColosseCeleste", Color = "#F5C542" },
	{ Id = "MoutonNuage", Source = "MoutonNuage", Color = "#DCDCEB" },
	{ Id = "PoissonDuCiel", Source = "PoissonDuCiel", Color = "#8CB4DC" },
	{ Id = "BecTonnerre", Source = "BecTonnerre", Color = "#F5C542" },
	{ Id = "GardienCeleste", Source = "GardienCeleste", Color = "#F5C542" },
}

local combat = ReplicatedStorage.Assets.Combat
for _, entry in ENEMIES do
	if entry.OnlyIfMissing and combat:FindFirstChild(`Ennemi_{entry.Id}`) then continue end
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
	model:SetAttribute("EnemyId", if entry.Id == "RoiOrc" then "Boss" else entry.Id)
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
-- Version B (docs/ZONES.md) : désert, glace, forges, abysses, ciel — le biome de la faune des fiches.
local THEMES = {
	{
		Id = 2, Name = "Zone2_DesertDesRuines", Nom = "Le Désert des Ruines",
		Colors = {
			Leaf = { hex("#8C7A44"), hex("#B49A5A") }, Water = { hex("#3E8C8C"), hex("#64B4A0") }, Foam = { hex("#E8D2A0") },
			Sand = { hex("#C8A064"), hex("#E0C080") }, Stone = { hex("#8C6E4E"), hex("#B4946A") }, Ruin = { hex("#D2B48C"), hex("#E6CCA0") },
			Flower = { hex("#B4643C"), hex("#DC8C3C") }, Wood = { hex("#6E5032"), hex("#8C6A44") }, Glow = { hex("#F5C542") },
		},
		Light = hex("#FFC864"),
		Ground = { hex("#D2B078"), hex("#C8A46A"), hex("#B8945C") },
		-- pas de forêt dans le désert : les arbres deviennent des colonnes de grès brisées (Replace)
		Remove = { SlimeDecor = true, Buisson = true, Fleur = true },
		Replace = { Arbre = true, Sapin = true },
		ReplaceWith = "Pillar",
		TreeScale = 1,
	},
	{
		Id = 3, Name = "Zone3_TerresGelees", Nom = "Les Terres Gelées",
		Colors = {
			Leaf = { hex("#9AB4C8"), hex("#D2E2EE") }, Water = { hex("#7CA8D2"), hex("#B4D2EB") }, Foam = { hex("#F0F6FA") },
			Sand = { hex("#DCE6F0"), hex("#F0F4F8") }, Stone = { hex("#6E7E8C"), hex("#9AAAB8") }, Ruin = { hex("#C8D4DE"), hex("#DCE4EC") },
			Flower = { hex("#8CB4DC"), hex("#64B4DC") }, Wood = { hex("#5A4A3C"), hex("#7A6650") }, Glow = { hex("#8CE0FF") },
		},
		IceWater = true,
		Light = hex("#8CE0FF"),
		Ground = { hex("#E6EEF4"), hex("#DCE6EE"), hex("#CCD8E2") },
		Remove = { SlimeDecor = true, Fleur = true },
		TreeScale = 1.2,
	},
	{
		Id = 4, Name = "Zone4_Forges", Nom = "Les Forges",
		Colors = {
			Leaf = { hex("#4A4440"), hex("#665E56") }, Water = { hex("#C8461E"), hex("#F08C3C") }, Foam = { hex("#F5C542") },
			Sand = { hex("#5A5048"), hex("#6E6258") }, Stone = { hex("#3E3A38"), hex("#6A625C") }, Ruin = { hex("#7E766E"), hex("#8E867E") },
			Flower = { hex("#B4461E"), hex("#E07028") }, Glow = { hex("#F08C3C") }, Wood = { hex("#3C2A22"), hex("#5E4232") },
		},
		LavaWater = true,
		Light = hex("#FF8C28"),
		Ground = { hex("#4E4642"), hex("#5A504A"), hex("#443C38") },
		-- pas de végétation près des forges : les arbres deviennent des cheminées de fer (Replace)
		Remove = { SlimeDecor = true, Buisson = true, Fleur = true },
		Replace = { Arbre = true, Sapin = true },
		ReplaceWith = "Chimney",
		TreeScale = 1,
	},
	{
		Id = 5, Name = "Zone5_Abysses", Nom = "Les Abysses",
		Colors = {
			Leaf = { hex("#1E5A5A"), hex("#3C8C78") }, Water = { hex("#1E3C6E"), hex("#3C6EA0") }, Foam = { hex("#8CB4DC") },
			Sand = { hex("#8C8064"), hex("#A0947A") }, Stone = { hex("#3C4A5A"), hex("#5E7082") }, Ruin = { hex("#6E8296"), hex("#8296AA") },
			Flower = { hex("#C8644A"), hex("#E08C64") }, Wood = { hex("#4A3C32"), hex("#5E4E40") }, Glow = { hex("#64DCDC") },
		},
		Light = hex("#64DCDC"),
		Ground = { hex("#5A6E7A"), hex("#4E6270"), hex("#465866") },
		-- fond marin : les arbres deviennent des bouquets de corail (Replace)
		Remove = { SlimeDecor = true, Fleur = true },
		Replace = { Arbre = true, Sapin = true },
		ReplaceWith = "Coral",
		TreeScale = 1,
	},
	{
		Id = 6, Name = "Zone6_IlesDuCiel", Nom = "Les Îles du Ciel",
		Colors = {
			Leaf = { hex("#6EA050"), hex("#94C46E") }, Water = { hex("#8CB4DC"), hex("#B4D2F0") }, Foam = { hex("#F0F6FA") },
			Sand = { hex("#E6E0D2"), hex("#F4F0E6") }, Stone = { hex("#A0A8B4"), hex("#C8CED8") }, Ruin = { hex("#E0DCD0"), hex("#F0ECE2") },
			Flower = { hex("#F5C542"), hex("#F5D778") }, Glow = { hex("#F5D778") },
		},
		Light = hex("#FFE08C"),
		Ground = { hex("#A8D48C"), hex("#B8DC9C"), hex("#98C87C") },
		-- au-dessus des nuages : les sapins deviennent de gros nuages posés (Replace), les arbres ronds restent
		Remove = { SlimeDecor = true },
		Replace = { Sapin = true },
		ReplaceWith = "Cloud",
		TreeScale = 1,
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
		local rock = piece(parent, "Pointe", Enum.PartType.Block, Vector3.new(0.9, h, 0.9) * Vector3.new(k, 1, k), color, offset + at + Vector3.new(0, h / 2 - 0.2, 0),
			CFrame.Angles(0.18 * (i - 1), i * 0.7, 0.15), material)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = rock -- ellipsoïde plein : une Part Ball seule impose un diamètre uniforme
	end
end

-- Colonne de grès brisée (désert) : fût, bague, tronçon tombé à côté.
local function pillar(parent: Instance, at: Vector3, color: Color3, scale: number?)
	local k = scale or 1
	local h = (3.2 + math.abs(at.X + at.Z) % 3) * k
	piece(parent, "Colonne", Enum.PartType.Cylinder, Vector3.new(h, 1.5 * k, 1.5 * k), color, at + Vector3.new(0, h / 2, 0), FLAT)
	piece(parent, "Bague", Enum.PartType.Cylinder, Vector3.new(0.4, 1.9 * k, 1.9 * k), color:Lerp(Color3.new(0, 0, 0), 0.12),
		at + Vector3.new(0, h, 0), FLAT)
	piece(parent, "Troncon", Enum.PartType.Cylinder, Vector3.new(1.6 * k, 1.4 * k, 1.4 * k), color,
		at + Vector3.new(1.4 * k, 0.7 * k, 0.8 * k), CFrame.Angles(0, 0.6, 0))
end

-- Cheminée de forge : fût de fer cerclé, bouche rougeoyante.
local function chimney(parent: Instance, at: Vector3, iron: Color3, ember: Color3, scale: number?)
	local k = scale or 1
	local h = 5 * k
	piece(parent, "Cheminee", Enum.PartType.Cylinder, Vector3.new(h, 1.6 * k, 1.6 * k), iron, at + Vector3.new(0, h / 2, 0), FLAT)
	piece(parent, "Cerclage", Enum.PartType.Cylinder, Vector3.new(0.35, 1.9 * k, 1.9 * k), iron:Lerp(Color3.new(0, 0, 0), 0.25),
		at + Vector3.new(0, h * 0.4, 0), FLAT)
	piece(parent, "Braise", Enum.PartType.Cylinder, Vector3.new(0.2, 1.2 * k, 1.2 * k), ember, at + Vector3.new(0, h + 0.05, 0), FLAT,
		Enum.Material.Neon)
end

-- Bouquet de corail : branches arrondies inclinées.
local function coral(parent: Instance, at: Vector3, color: Color3, scale: number?)
	local k = scale or 1
	for i = 0, 4 do
		local h = (1.6 + (i % 3) * 0.8) * k
		local angle = i * 1.25
		local branch = piece(parent, "Corail", Enum.PartType.Block, Vector3.new(0.6 * k, h, 0.6 * k), color,
			at + Vector3.new(math.cos(angle) * 0.6 * k, h / 2 - 0.1, math.sin(angle) * 0.6 * k),
			CFrame.Angles(math.cos(angle) * 0.35, 0, math.sin(angle) * 0.35))
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = branch
	end
end

-- Nuage posé (îles du ciel) : boules aplaties serrées, au ras du sol (rien ne flotte).
local function cloud(parent: Instance, at: Vector3, color: Color3, scale: number?)
	local k = scale or 1
	for i = 0, 3 do
		local d = (2.6 - (i % 2) * 0.8) * k
		local puff = piece(parent, "Nuage", Enum.PartType.Ball, Vector3.one * d, color,
			at + Vector3.new((i - 1.5) * 1.1 * k, d * 0.3, (i % 2) * 0.7 * k))
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = Vector3.new(1, 0.6, 1)
		mesh.Parent = puff
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
		-- Désert des Ruines : colonnes brisées, dunes de grès, petites oasis
		for index, p in all do
			if index % 3 == 1 then pillar(parent, p, hex("#C8A87E"))
			elseif index % 3 == 2 then spikes(parent, p, hex("#D2B078"), nil, 1.4)
			else pool(parent, p, 3.5, hex("#3E8C8C"), hex("#B4946A")) end
		end
	elseif id == 3 then
		-- Terres Gelées : sapins enneigés, cristaux de glace, mares gelées
		for index, p in all do
			if index % 3 == 1 then cloneProp(parent, pine, p, 1, index)
			elseif index % 3 == 2 then spikes(parent, p, hex("#8CE0FF"), Enum.Material.Ice, 1.2)
			else pool(parent, p, 4, hex("#B4D2EB"), hex("#DCE6F0"), Enum.Material.Ice) end
		end
	elseif id == 4 then
		-- Forges : cheminées, bassins de métal en fusion, rochers
		for index, p in all do
			if index % 3 == 1 then chimney(parent, p, hex("#4A4440"), hex("#F08C3C"))
			elseif index % 3 == 2 then pool(parent, p, 3.5, hex("#E0641E"), hex("#3E3A38"))
			else cloneProp(parent, rock, p, 1.1, index) end
		end
	elseif id == 5 then
		-- Abysses : coraux, algues, rochers
		for index, p in all do
			if index % 3 == 1 then coral(parent, p, hex("#C8644A"))
			elseif index % 3 == 2 then reeds(parent, p, hex("#1E5A5A"), hex("#3C8C78"))
			else cloneProp(parent, rock, p, 1.1, index) end
		end
	elseif id == 6 then
		-- Îles du Ciel : nuages posés, colonnes claires, arbres
		for index, p in all do
			if index % 3 == 1 then cloud(parent, p, hex("#F0F6FA"), 1.6)
			elseif index % 3 == 2 then pillar(parent, p, hex("#E0DCD0"), 0.9)
			else cloneProp(parent, tree, p, 0.9, index) end
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
				d.Material = Enum.Material.SmoothPlastic
			elseif theme.IceWater and fam == "Water" then
				d.Material = Enum.Material.Ice
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
		if theme.ReplaceWith == "Pillar" then
			pillar(extra, at, hex("#C8A87E"), 1.5)
		elseif theme.ReplaceWith == "Chimney" then
			chimney(extra, at, hex("#4A4440"), hex("#F08C3C"), 1.4)
		elseif theme.ReplaceWith == "Cloud" then
			cloud(extra, at, hex("#F0F6FA"), 2.2)
		elseif theme.ReplaceWith == "Coral" then
			coral(extra, at, if index % 2 == 0 then hex("#C8644A") else hex("#E08C64"), 1.8)
		else
			spikes(extra, at, if index % 4 == 0 then hex("#E07028") else hex("#5A4C48"), if index % 4 == 0 then Enum.Material.Neon else nil, 1.8)
		end
	end
	model.WorldPivot = PIVOT
	for _, previous in templates:GetChildren() do
		if previous.Name == theme.Name or previous:GetAttribute("ZoneId") == theme.Id then previous:Destroy() end
	end
	-- copies d'un ancien décor de cette zone posées dans une arène ou rangées (ServerStorage.ZonesRangees_<plot>)
	for _, holder in { workspace, ServerStorage } do
		for _, d in holder:GetDescendants() do
			if d:IsA("Model") and d:GetAttribute("ZoneId") == theme.Id and not d:IsDescendantOf(templates) then
				d:Destroy()
			end
		end
	end
	model.Parent = templates
	task.wait() -- une zone par lot ; laisser Studio répondre entre les copies
end

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
print(`Zones 2 à 6 : {#ENEMIES} modèles de combat, {#THEMES} décors dans ServerStorage.Assets.ZonesArene`)
