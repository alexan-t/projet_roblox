--!strict
-- Zones 2 à 6 (docs/ZONES.md § Assets Studio). À exécuter dans Studio EDIT (barre de commande ou MCP).
-- Assets uniquement, aucun Source de script. Répétable : reconstruit ses propres objets, ne touche à rien d'autre.
--   1. ReplicatedStorage.Assets.Combat.Ennemi_<EnemyId> : copies de combat statiques des monstres VALIDÉS
--      (Workspace, docs/ART_DIRECTION.md § 1), pivot tourné de 180° (l'avant du pivot = le visage), CouleurEffet.
--   2. ServerStorage.Assets.ZonesArene.Zone<n>_<Nom> : décor de chaque zone (désert, glace, forges, abysses, ciel), propre à chaque biome (lac, portique et repères SourcesEnnemis repris de la Zone 1 de
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
			Leaf = { hex("#E0D4B4"), hex("#F2ECDA") }, Water = { hex("#8CB4DC"), hex("#B4D2F0") }, Foam = { hex("#F0F6FA") },
			Sand = { hex("#E6E0D2"), hex("#F4F0E6") }, Stone = { hex("#A0A8B4"), hex("#C8CED8") }, Ruin = { hex("#E0DCD0"), hex("#F0ECE2") },
			Flower = { hex("#F5C542"), hex("#F5D778") }, Glow = { hex("#F5D778") },
		},
		Light = hex("#FFE08C"),
		Ground = { hex("#F2ECDA"), hex("#E8DEC4"), hex("#F8F4E8") }, -- nuages dorés au soleil (≠ glace bleutée de la zone 3)
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

-- Décors propres à chaque zone (aucune réutilisation du décor de la Zone 1, sauf le lac et le portique).
-- Coordonnées locales de l'arène (Y = hauteur au-dessus du sol du plot). Repères imposés par les sorties
-- d'ennemis de SourcesEnnemis (relevés dans Studio) : plateau 27 × 20 de 3 de haut en (21,9 ; -44,1) avec
-- sa rampe en (12,6 ; -30,2), porte (« Tente ») sur le plateau en (20,1 ; -47,4), sommet de tour à 13,5 en
-- (30,4 ; -49), sorties au sol (« Buisson ») en (21 ; -24), (-19 ; -24), (-23 ; 3). Lac (CoinSlimes) gardé à
-- l'ouest ; cases des héros (|x| < 13, z 5 à 33) et allée centrale (|x| < 9) dégagées.

local KEEP = { SourcesEnnemis = true, EntreeZone = true, CoinSlimes = true }
local LAKE = { Mare = true, MareCentre = true, Bord = true, Ruisseau = true, RuisseauJoint = true }

local function V(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end
local function rotY(a: number): CFrame
	return CFrame.Angles(0, a, 0)
end
local function ball(parent: Instance, name: string, size: Vector3, color: Color3, at: Vector3, rotation: CFrame?, material: Enum.Material?): Part
	local p = piece(parent, name, Enum.PartType.Block, size, color, at, rotation, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end
local function column(parent: Instance, name: string, h: number, d: number, color: Color3, at: Vector3, material: Enum.Material?): Part
	return piece(parent, name, Enum.PartType.Cylinder, V(h, d, d), color, at + V(0, h / 2, 0), FLAT, material)
end
local function light(part: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = color, range, brightness
	l.Parent = part
end

-- Points d'un rempart en U autour du fond de l'arène : deux flancs (x = ±58, z de +18 à -20) puis un arc
-- de fond (centre z -20, rayons 58 × 54). Renvoie { position, angle de la tangente }.
local function enclosure(step: number): { { at: Vector3, yaw: number, back: boolean } }
	local list = {}
	for z = 18, -20, -step do
		table.insert(list, { at = V(-58, 0, z), yaw = math.pi / 2, back = false })
		table.insert(list, { at = V(58, 0, z), yaw = math.pi / 2, back = false })
	end
	local count = math.floor(math.pi * 56 / step)
	for i = 1, count - 1 do
		local a = math.pi * i / count
		local x, z = -58 * math.cos(a), -20 - 54 * math.sin(a)
		table.insert(list, { at = V(x, 0, z), yaw = -a + math.pi / 2, back = math.abs(x) < 20 })
	end
	return list
end

-- Plateau + rampe + porte + tour : la même ossature imposée par les sorties, habillée par chaque biome.
type Kit = {
	Body: Color3, Top: Color3, Trim: Color3, Glow: Color3, Dark: Color3, Material: Enum.Material?,
}
local function frame(parent: Instance, kit: Kit, towerTop: (Instance, Vector3) -> ())
	-- plateau (le dessus à 3)
	piece(parent, "Plateau", Enum.PartType.Block, V(27, 3, 20), kit.Body, V(21.9, 1.5, -44.1), nil, kit.Material)
	piece(parent, "DessusPlateau", Enum.PartType.Block, V(27.6, 0.4, 20.6), kit.Top, V(21.9, 3.1, -44.1), nil, kit.Material)
	-- rampe : trois marches vers l'allée
	for i = 0, 2 do
		piece(parent, "Marche", Enum.PartType.Block, V(4.6, 3 - i, 2.4), kit.Top, V(12.6, (3 - i) / 2, -32.6 + i * 2.4), nil, kit.Material)
	end
	-- porte sur le plateau, ouverte vers l'allée (+z)
	for _, side in { -1, 1 } do
		piece(parent, "MontantPorte", Enum.PartType.Block, V(1.4, 6.5, 1.6), kit.Trim, V(20.1 + side * 2.8, 3 + 3.25, -48.6), nil, kit.Material)
	end
	piece(parent, "LintPorte", Enum.PartType.Block, V(7.4, 1.4, 1.8), kit.Trim, V(20.1, 3 + 7.2, -48.6), nil, kit.Material)
	piece(parent, "FondPorte", Enum.PartType.Block, V(4.4, 6.4, 0.4), kit.Dark, V(20.1, 3 + 3.2, -49.4), nil, Enum.Material.SmoothPlastic)
	local glow = piece(parent, "LueurPorte", Enum.PartType.Block, V(3.6, 0.3, 0.6), kit.Glow, V(20.1, 3 + 0.15, -48.9), nil, Enum.Material.Neon)
	light(glow, kit.Glow, 10, 1)
	-- tour : fût jusqu'à 12,9, plateforme à 13,5 (point de saut)
	column(parent, "Tour", 12.9, 5, kit.Body, V(30.4, 0, -49), kit.Material)
	piece(parent, "Balcon", Enum.PartType.Cylinder, V(0.6, 6.6, 6.6), kit.Top, V(30.4, 13.2, -49), FLAT, kit.Material)
	towerTop(parent, V(30.4, 13.5, -49))
end

local BUILD = {}

---------------------------------------------------------------- Zone 2 : temple ensablé du désert
BUILD[2] = function(m: Instance)
	local sand, stone, light2, gold, dark = hex("#D8B47C"), hex("#C49A64"), hex("#E6CCA0"), hex("#F5C542"), hex("#3A2A1E")
	local f = Instance.new("Folder")
	f.Name, f.Parent = "Temple", m
	-- rempart : colonnade de grès et murs écroulés, obélisques aux angles
	for i, p in enclosure(7) do
		local h = if p.back then 15 else 9 + (i % 3) * 2.5
		piece(f, "MurGres", Enum.PartType.Block, V(7.6, h, 3), if i % 2 == 0 then stone else sand, p.at + V(0, h / 2, 0), rotY(p.yaw))
		if i % 2 == 1 then
			column(f, "Colonne", h + 3, 2.2, light2, p.at + V(0, 0, 0) + (CFrame.Angles(0, p.yaw, 0).LookVector * -2.2))
			piece(f, "Chapiteau", Enum.PartType.Block, V(3, 0.8, 3), sand, p.at + V(0, h + 3.4, 0) + (CFrame.Angles(0, p.yaw, 0).LookVector * -2.2))
		end
	end
	-- pyramide à degrés au fond, coiffe dorée
	for i = 0, 5 do
		local w = 34 - i * 5.4
		piece(f, "Degre", Enum.PartType.Block, V(w, 3.2, w * 0.7), if i % 2 == 0 then sand else stone, V(-6, 1.6 + i * 3.2, -66))
	end
	local cap = piece(f, "CoiffeDoree", Enum.PartType.Block, V(3.2, 2.6, 2.4), gold, V(-6, 20.5, -66), nil, Enum.Material.Neon)
	light(cap, gold, 18, 1)
	-- obélisques le long de l'allée
	for _, x in { -14, 14 } do
		for _, z in { -12, -38 } do
			piece(f, "Obelisque", Enum.PartType.Block, V(1.8, 9, 1.8), stone, V(x, 4.5, z))
			piece(f, "Pointe", Enum.PartType.Wedge, V(1.8, 1.6, 1.8), gold, V(x, 9.8, z))
		end
	end
	-- tête de statue à demi ensevelie, côté est
	ball(f, "TeteStatue", V(9, 8, 8), light2, V(44, 2.5, -10))
	piece(f, "Coiffe", Enum.PartType.Block, V(10, 3, 7), stone, V(44, 7, -10))
	for _, side in { -1, 1 } do
		piece(f, "Oeil", Enum.PartType.Block, V(1.6, 0.8, 0.5), dark, V(44 + side * 2, 3.6, -6.1))
	end
	-- dunes
	for _, d in { { 36, -30, 14 }, { 46, 8, 12 }, { -46, -50, 16 }, { 40, -62, 14 } } do
		ball(f, "Dune", V(d[3], 3, d[3] * 0.7), sand, V(d[1], 0.4, d[2]), rotY(d[1]))
	end
	-- ossature des sorties : temple sur dais, porte du temple, obélisque-vigie
	frame(f, { Body = stone, Top = light2, Trim = sand, Glow = gold, Dark = dark }, function(parent, top)
		piece(parent, "Vigie", Enum.PartType.Block, V(3, 3, 3), sand, top + V(0, 1.5, 0))
		piece(parent, "PointeVigie", Enum.PartType.Wedge, V(3, 2.4, 3), gold, top + V(0, 4.2, 0))
	end)
	-- sorties au sol : blocs de statue brisée
	for _, at in { V(21, 0, -24), V(-19, 0, -24), V(-23, 0, 3) } do
		piece(f, "BlocBrise", Enum.PartType.Block, V(4.6, 3.4, 3.2), stone, at + V(-1.5, 1.7, -2.6), rotY(0.4))
		ball(f, "TasSable", V(6, 1.6, 4), sand, at + V(1.6, 0.2, -2.2))
	end
end

---------------------------------------------------------------- Zone 3 : donjon de glace
BUILD[3] = function(m: Instance)
	local ice, iceDark, snow, glow, deep = hex("#A8D2EE"), hex("#7CB0D8"), hex("#F0F6FA"), hex("#8CE0FF"), hex("#1E3C6E")
	local f = Instance.new("Folder")
	f.Name, f.Parent = "Donjon", m
	-- dallage de glace polie sous l'allée et le front ennemi (damier)
	for x = -12, 12, 6 do
		for z = -54, -6, 6 do
			piece(f, "DalleGlace", Enum.PartType.Block, V(6, 0.2, 6), if (x + z) % 12 == 0 then hex("#BFE0F5") else hex("#A5CDEB"),
				V(x, 0.1, z), nil, Enum.Material.Ice)
		end
	end
	-- remparts de glace crénelés, tours rondes, stalactites
	for i, p in enclosure(8) do
		local h = if p.back then 20 else 14
		local rot = rotY(p.yaw)
		piece(f, "MurGlace", Enum.PartType.Block, V(8.4, h, 3.4), if i % 2 == 0 then ice else iceDark, p.at + V(0, h / 2, 0), rot, Enum.Material.Ice)
		piece(f, "Neige", Enum.PartType.Block, V(8.6, 0.8, 3.8), snow, p.at + V(0, h + 0.4, 0), rot)
		for c = -1, 1, 2 do
			piece(f, "Creneau", Enum.PartType.Block, V(2.2, 2, 3.4), ice, p.at + (CFrame.Angles(0, p.yaw, 0).RightVector * c * 2.6) + V(0, h + 1.8, 0), rot, Enum.Material.Ice)
		end
		local inward = -(p.at * V(1, 0, 1)).Unit
		for s = -1, 1 do
			local len = 2 + (i + s) % 3
			piece(f, "Stalactite", Enum.PartType.Wedge, V(0.8, len, 0.8), glow, p.at + inward * 1.9 + (CFrame.Angles(0, p.yaw, 0).RightVector * s * 2.4)
				+ V(0, h - len / 2, 0), rot * CFrame.Angles(math.pi, 0, 0), Enum.Material.Ice)
		end
		if i % 5 == 0 then
			column(f, "TourGlace", h + 8, 7, iceDark, p.at, Enum.Material.Ice)
			ball(f, "DomeGlace", V(7.6, 5, 7.6), snow, p.at + V(0, h + 8, 0))
			local c = piece(f, "CristalTour", Enum.PartType.Block, V(1.4, 3.4, 1.4), glow, p.at + V(0, h + 11.8, 0), CFrame.Angles(0, 0.78, 0), Enum.Material.Neon)
			light(c, glow, 12, 0.8)
		end
	end
	-- trône du Roi sans Été au fond : grande porte de glace et cristal
	for _, side in { -1, 1 } do
		column(f, "PilierTrone", 22, 5, iceDark, V(side * 9, 0, -66), Enum.Material.Ice)
		local tip = piece(f, "PointePilier", Enum.PartType.Wedge, V(4, 5, 4), glow, V(side * 9, 24.5, -66), nil, Enum.Material.Ice)
		tip.Transparency = 0.1
	end
	piece(f, "ArcheTrone", Enum.PartType.Block, V(22, 3, 4), ice, V(0, 21, -66), nil, Enum.Material.Ice)
	piece(f, "FondTrone", Enum.PartType.Block, V(13, 19, 1), deep, V(0, 9.5, -67.5))
	local heart = piece(f, "CoeurDeGlace", Enum.PartType.Block, V(3, 6, 3), glow, V(0, 11, -66.8), CFrame.Angles(0, 0.78, 0), Enum.Material.Neon)
	light(heart, glow, 22, 1.4)
	piece(f, "Trone", Enum.PartType.Block, V(6, 5, 3), snow, V(0, 2.5, -65.5), nil, Enum.Material.Ice)
	-- piliers gelés le long de l'allée, braseros à flamme froide
	for _, x in { -14, 14 } do
		for _, z in { -10, -24, -38 } do
			column(f, "PilierGele", 8, 2.2, ice, V(x, 0, z), Enum.Material.Ice)
			local fl = piece(f, "FlammeFroide", Enum.PartType.Block, V(1.2, 1.6, 1.2), glow, V(x, 8.8, z), CFrame.Angles(0, 0.78, 0), Enum.Material.Neon)
			light(fl, glow, 9, 0.6)
		end
	end
	-- congères et cristaux côté est
	for _, d in { { 42, -8 }, { 46, 10 }, { 38, -64 }, { -44, -54 } } do
		ball(f, "Congere", V(10, 3, 7), snow, V(d[1], 0.4, d[2]), rotY(d[2]))
		spikes(f, V(d[1] + 3, 0, d[2] - 2), glow, Enum.Material.Ice, 1.4)
	end
	frame(f, { Body = iceDark, Top = ice, Trim = snow, Glow = glow, Dark = deep, Material = Enum.Material.Ice }, function(parent, top)
		ball(parent, "DomeVigie", V(5, 3.2, 5), snow, top + V(0, 0.6, 0))
		local c = piece(parent, "CristalVigie", Enum.PartType.Block, V(1.2, 3, 1.2), glow, top + V(0, 3.4, 0), CFrame.Angles(0, 0.78, 0), Enum.Material.Neon)
		light(c, glow, 10, 0.7)
	end)
	for _, at in { V(21, 0, -24), V(-19, 0, -24), V(-23, 0, 3) } do
		spikes(f, at + V(-1.5, 0, -2.4), glow, Enum.Material.Ice, 1.5)
		ball(f, "Congere", V(6, 2, 4), snow, at + V(1.6, 0.2, -2.2))
	end
end

---------------------------------------------------------------- Zone 4 : forteresse des forges
BUILD[4] = function(m: Instance)
	local basalt, basaltLight, iron, ember, dark = hex("#3A3432"), hex("#5A524C"), hex("#6E6E72"), hex("#F08C3C"), hex("#1C1614")
	local f = Instance.new("Folder")
	f.Name, f.Parent = "Forges", m
	-- murs de basalte cerclés de fer, rivets, cheminées
	for i, p in enclosure(8) do
		local h = if p.back then 18 else 12 + (i % 2) * 2
		local rot = rotY(p.yaw)
		piece(f, "MurBasalte", Enum.PartType.Block, V(8.4, h, 3.6), if i % 2 == 0 then basalt else basaltLight, p.at + V(0, h / 2, 0), rot)
		for _, y in { h * 0.3, h * 0.75 } do
			piece(f, "Cerclage", Enum.PartType.Block, V(8.6, 0.7, 3.9), iron, p.at + V(0, y, 0), rot, Enum.Material.DiamondPlate)
		end
		if i % 4 == 0 then
			chimney(f, p.at + V(0, h, 0), basalt, ember, 1.2)
		end
	end
	-- grand fourneau au fond : dôme, bouche rougeoyante, deux cheminées
	ball(f, "Fourneau", V(26, 20, 18), basaltLight, V(0, 6, -66))
	piece(f, "Socle", Enum.PartType.Block, V(28, 3, 16), basalt, V(0, 1.5, -64))
	local mouth = piece(f, "BoucheFourneau", Enum.PartType.Block, V(9, 6, 1), ember, V(0, 6, -57.4), nil, Enum.Material.Neon)
	light(mouth, ember, 26, 1.5)
	piece(f, "GrilleBouche", Enum.PartType.Block, V(10, 0.6, 1.4), iron, V(0, 9.2, -57.1), nil, Enum.Material.DiamondPlate)
	for _, side in { -1, 1 } do
		column(f, "GrandeCheminee", 26, 4, basalt, V(side * 9, 0, -70))
		local b = piece(f, "BraiseCheminee", Enum.PartType.Cylinder, V(0.3, 3, 3), ember, V(side * 9, 26.2, -70), FLAT, Enum.Material.Neon)
		light(b, ember, 10, 0.8)
	end
	-- rigoles de métal en fusion vers l'allée
	for _, x in { -11, 11 } do
		local g = piece(f, "Rigole", Enum.PartType.Block, V(1.6, 0.25, 42), ember, V(x, 0.15, -36), nil, Enum.Material.Neon)
		light(g, ember, 8, 0.4)
		for _, side in { -1, 1 } do
			piece(f, "BordRigole", Enum.PartType.Block, V(0.6, 0.6, 42), iron, V(x + side * 1.1, 0.3, -36), nil, Enum.Material.DiamondPlate)
		end
	end
	-- enclumes, lingots, chaînes
	for _, d in { { -22, -8 }, { 40, -10 }, { 44, 10 }, { -42, -52 } } do
		piece(f, "SocleEnclume", Enum.PartType.Block, V(2, 2, 2), basalt, V(d[1], 1, d[2]))
		piece(f, "Enclume", Enum.PartType.Block, V(3.6, 1.2, 1.6), iron, V(d[1], 2.6, d[2]), nil, Enum.Material.DiamondPlate)
		piece(f, "Bigorne", Enum.PartType.Wedge, V(1.6, 1, 1.6), iron, V(d[1] + 2.4, 2.6, d[2]), rotY(-math.pi / 2), Enum.Material.DiamondPlate)
		for k = 0, 2 do
			piece(f, "Lingot", Enum.PartType.Block, V(1.4, 0.6, 0.7), hex("#D2A04A"), V(d[1] - 2.6, 0.3 + k * 0.6, d[2] + 1.6), rotY(k * 0.3), Enum.Material.Metal)
		end
	end
	frame(f, { Body = basalt, Top = iron, Trim = basaltLight, Glow = ember, Dark = dark, Material = nil }, function(parent, top)
		local b = piece(parent, "Brasero", Enum.PartType.Cylinder, V(1, 3.6, 3.6), ember, top + V(0, 0.6, 0), FLAT, Enum.Material.Neon)
		light(b, ember, 12, 1)
	end)
	for _, at in { V(21, 0, -24), V(-19, 0, -24), V(-23, 0, 3) } do
		piece(f, "Chariot", Enum.PartType.Block, V(4.4, 2.4, 3), iron, at + V(-1.2, 1.6, -2.6), rotY(0.3), Enum.Material.DiamondPlate)
		ball(f, "Minerai", V(3.6, 2, 2.6), hex("#5A3A2A"), at + V(-1.2, 3, -2.6))
		ball(f, "Scories", V(5, 1.4, 3.6), basalt, at + V(1.8, 0.2, -1.8))
	end
end

---------------------------------------------------------------- Zone 5 : temple englouti des abysses
BUILD[5] = function(m: Instance)
	local rock, rockLight, coralA, coralB, algae, glow, wood = hex("#2E4256"), hex("#4E6A82"), hex("#C8644A"), hex("#E08C64"), hex("#2E7A64"), hex("#64DCDC"), hex("#4A3828")
	local f = Instance.new("Folder")
	f.Name, f.Parent = "Abysses", m
	-- récif : rochers arrondis couverts de coraux et d'algues
	for i, p in enclosure(7) do
		local h = if p.back then 16 else 10 + (i % 3) * 2
		-- amas de 3 roches de tailles différentes, basses et penchées (pas un bloc lisse)
		local right = CFrame.Angles(0, p.yaw, 0).RightVector
		for r = -1, 1 do
			local rh = h * (if r == 0 then 0.75 else 0.5) * (0.85 + ((i + r) % 3) * 0.15)
			ball(f, "Recif", V(5.5 + (i + r) % 3, rh, 5 + (i % 2) * 1.5), if (i + r) % 2 == 0 then rock else rockLight,
				p.at + right * r * 3 + V(0, rh * 0.35, 0), rotY(p.yaw + i + r) * CFrame.Angles(((i + r) % 3 - 1) * 0.25, 0, r * 0.2))
		end
		if i % 2 == 0 then coral(f, p.at + V(0, h * 0.55, 0), if i % 4 == 0 then coralA else coralB, 1.4) end
		if i % 3 == 0 then reeds(f, p.at + (-(p.at * V(1, 0, 1)).Unit * 3.5), algae, hex("#3C8C78")) end
	end
	-- épave au fond : coque, mât brisé
	piece(f, "Coque", Enum.PartType.Block, V(30, 7, 9), wood, V(-4, 3.5, -66), CFrame.Angles(0, 0.2, 0.12))
	piece(f, "Proue", Enum.PartType.Wedge, V(9, 7, 8), wood, V(13, 3.5, -62.5), CFrame.Angles(0, 0.2 - math.pi / 2, 0.12))
	piece(f, "Pont", Enum.PartType.Block, V(28, 0.6, 8), hex("#5E4632"), V(-4, 7.1, -66), CFrame.Angles(0, 0.2, 0.12))
	column(f, "Mat", 16, 1.2, wood, V(-6, 7, -66))
	piece(f, "VergueBrisee", Enum.PartType.Block, V(10, 0.8, 0.8), wood, V(-4, 18, -66), CFrame.Angles(0, 0.2, 0.5))
	-- arche de coquillage géant au milieu du fond
	for _, side in { -1, 1 } do
		ball(f, "Coquille", V(12, 16, 3), hex("#E6C8B4"), V(side * 26, 7, -52), rotY(side * 0.6))
	end
	local pearl = ball(f, "Perle", V(4, 4, 4), hex("#F0F6FA"), V(-26, 2, -50), nil, Enum.Material.Neon)
	light(pearl, glow, 12, 0.8)
	-- colonnes de bulles, anémones lumineuses
	for _, d in { { -14, -14 }, { 14, -14 }, { -14, -40 }, { 14, -40 }, { 42, -6 } } do
		for k = 0, 4 do
			local b = ball(f, "Bulle", V(1.2 - k * 0.15, 1.2 - k * 0.15, 1.2 - k * 0.15), hex("#B4DCF0"), V(d[1] + math.sin(k) * 0.4, 1 + k * 2.2, d[2]))
			b.Transparency = 0.45
		end
		local a = ball(f, "Anemone", V(2.4, 1.4, 2.4), glow, V(d[1], 0.5, d[2]), nil, Enum.Material.Neon)
		light(a, glow, 8, 0.5)
	end
	-- coffre au trésor et ancre côté est
	piece(f, "Coffre", Enum.PartType.Block, V(4, 2.4, 2.6), wood, V(44, 1.2, 8))
	piece(f, "Couvercle", Enum.PartType.Block, V(4.2, 0.8, 2.8), hex("#D2A04A"), V(44, 2.8, 7.4), CFrame.Angles(-0.5, 0, 0), Enum.Material.Metal)
	column(f, "Ancre", 7, 0.8, hex("#5A6470"), V(38, 0, -16), Enum.Material.Metal)
	piece(f, "BrasAncre", Enum.PartType.Block, V(4.6, 0.8, 0.8), hex("#5A6470"), V(38, 0.8, -16), nil, Enum.Material.Metal)
	frame(f, { Body = rock, Top = rockLight, Trim = hex("#6E8296"), Glow = glow, Dark = hex("#0E1A2A"), Material = nil }, function(parent, top)
		coral(parent, top, coralA, 1.1)
	end)
	for _, at in { V(21, 0, -24), V(-19, 0, -24), V(-23, 0, 3) } do
		reeds(f, at + V(-1.2, 0, -2.6), algae, hex("#3C8C78"))
		coral(f, at + V(1.8, 0, -2), coralB, 0.9)
	end
end

---------------------------------------------------------------- Zone 6 : sanctuaire des îles du ciel
BUILD[6] = function(m: Instance)
	local marble, marbleDark, gold, cloudC, sky = hex("#F4F0E6"), hex("#DCD6C8"), hex("#F5C542"), hex("#FFFFFF"), hex("#8CB4DC")
	local f = Instance.new("Folder")
	f.Name, f.Parent = "Sanctuaire", m
	-- banc de nuages et arches de marbre à liseré d'or
	for i, p in enclosure(8) do
		cloud(f, p.at + V(0, 1, 0), cloudC, 2.4)
		if i % 3 == 0 then
			local h = if p.back then 16 else 11
			local right = CFrame.Angles(0, p.yaw, 0).RightVector
			for _, s in { -1, 1 } do
				column(f, "ColonneMarbre", h, 1.8, marble, p.at + right * s * 3)
			end
			piece(f, "ArcheMarbre", Enum.PartType.Block, V(8.4, 1.4, 2), marbleDark, p.at + V(0, h + 0.7, 0), rotY(p.yaw))
			piece(f, "LisereOr", Enum.PartType.Block, V(8.6, 0.3, 2.2), gold, p.at + V(0, h + 1.55, 0), rotY(p.yaw), Enum.Material.Metal)
		end
	end
	-- sanctuaire rond au fond : colonnade, dôme d'or, orbe
	for k = 0, 7 do
		local a = k * math.pi / 4
		column(f, "ColonneSanctuaire", 14, 1.6, marble, V(math.cos(a) * 8, 2, -64 + math.sin(a) * 6))
	end
	piece(f, "SocleSanctuaire", Enum.PartType.Cylinder, V(2, 20, 20), marbleDark, V(0, 1, -64), FLAT)
	ball(f, "Dome", V(19, 9, 15), gold, V(0, 16.5, -64), nil, Enum.Material.Metal)
	local orb = ball(f, "Orbe", V(3.6, 3.6, 3.6), hex("#FFE08C"), V(0, 22.5, -64), nil, Enum.Material.Neon)
	light(orb, hex("#FFE08C"), 24, 1.2)
	-- statues ailées de part et d'autre de l'allée
	for _, x in { -15, 15 } do
		for _, z in { -14, -40 } do
			column(f, "Piedestal", 3, 3, marbleDark, V(x, 0, z))
			ball(f, "Statue", V(2, 4, 1.6), marble, V(x, 5, z))
			for _, s in { -1, 1 } do
				ball(f, "Aile", V(0.5, 3.4, 2.6), gold, V(x + s * 1.3, 5.6, z), CFrame.Angles(0, 0, s * 0.5), Enum.Material.Metal)
			end
		end
	end
	-- îlots de nuages posés et bannières côté est
	for _, d in { { 42, -8 }, { 46, 10 }, { 38, -62 }, { -44, -54 } } do
		cloud(f, V(d[1], 0, d[2]), cloudC, 1.8)
		column(f, "MatBanniere", 9, 0.4, gold, V(d[1] + 2, 0, d[2]), Enum.Material.Metal)
		piece(f, "Banniere", Enum.PartType.Block, V(0.15, 4, 2.4), sky, V(d[1] + 2, 6.4, d[2] + 1.3))
	end
	frame(f, { Body = marbleDark, Top = marble, Trim = gold, Glow = hex("#FFE08C"), Dark = sky, Material = nil }, function(parent, top)
		local o = ball(parent, "OrbeVigie", V(2.4, 2.4, 2.4), hex("#FFE08C"), top + V(0, 1.6, 0), nil, Enum.Material.Neon)
		light(o, hex("#FFE08C"), 10, 0.8)
	end)
	for _, at in { V(21, 0, -24), V(-19, 0, -24), V(-23, 0, 3) } do
		cloud(f, at + V(0, 0, -2.4), cloudC, 1.4)
	end
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
	model:SetAttribute("Note", "Décor propre à la zone (tools/studio-zones-assets.luau) ; repères SourcesEnnemis, portique et lac repris de la Zone 1")

	-- on ne garde que les repères de combat, le portique d'entrée et le lac
	for _, child in model:GetChildren() do
		if not KEEP[child.Name] then
			child:Destroy()
		elseif child.Name == "CoinSlimes" then
			child.Name = "Lac"
			for _, d in child:GetChildren() do
				if not LAKE[d.Name] then d:Destroy() end
			end
		end
	end
	-- couleurs du biome sur ce qui reste (portique, eau du lac), matière de l'eau
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and not d:IsDescendantOf(model.SourcesEnnemis) and d.Name ~= "Flamme" then
			local fam = family(d.Color, d.Material)
			local ramp = theme.Colors[fam]
			if ramp then d.Color = shade(d.Color, fam, ramp) end
			if theme.LavaWater and (fam == "Water" or fam == "Foam") then
				d.Material = Enum.Material.Neon
			elseif theme.IceWater and fam == "Water" then
				d.Material = Enum.Material.Ice
			end
		elseif d:IsA("PointLight") then
			d.Color = theme.Light
		elseif d:IsA("TextLabel") and d.Name == "TitreZone" then
			d.Text = `Zone {theme.Id}`
		end
	end
	-- sol de la zone (recouvre l'herbe du plot dans l'arène), puis le décor propre au biome
	local ground = Instance.new("Folder")
	ground.Name, ground.Parent = "SolZone", model
	groundOf(ground, theme.Ground)
	BUILD[theme.Id](model)
	model.WorldPivot = PIVOT
	for _, previous in templates:GetChildren() do
		if previous.Name == theme.Name or previous:GetAttribute("ZoneId") == theme.Id then previous:Destroy() end
	end
	-- copies d'un ancien décor de cette zone posées dans une arène ou rangées (ServerStorage.ZonesRangees_<plot>)
	for _, holder in { workspace, ServerStorage } do
		for _, d in holder:GetDescendants() do
			if d:IsA("Model") and d:GetAttribute("ZoneId") == theme.Id and d.Parent and d.Parent.Name == "Zones"
				or d:IsA("Model") and d:GetAttribute("ZoneId") == theme.Id and d.Parent and d.Parent.Name:match("^ZonesRangees_") then
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
