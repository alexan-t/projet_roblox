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
		Id = 2, Name = "Zone2_RoyaumeDesSables", Nom = "Le Royaume des Sables",
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
		Id = 3, Name = "Zone3_RoyaumeGele", Nom = "Le Royaume Gelé",
		Colors = {
			Leaf = { hex("#9AB4C8"), hex("#D2E2EE") }, Water = { hex("#7CA8D2"), hex("#B4D2EB") }, Foam = { hex("#F0F6FA") },
			Sand = { hex("#DCE6F0"), hex("#F0F4F8") }, Stone = { hex("#6E7E8C"), hex("#9AAAB8") }, Ruin = { hex("#C8D4DE"), hex("#DCE4EC") },
			Flower = { hex("#8CB4DC"), hex("#64B4DC") }, Wood = { hex("#5A4A3C"), hex("#7A6650") }, Glow = { hex("#8CE0FF") },
		},
		IceWater = true,
		Light = hex("#8CE0FF"),
		Ground = { hex("#E4EDF5"), hex("#D5E2EE"), hex("#C7D7E6") },
		Remove = { SlimeDecor = true, Fleur = true },
		TreeScale = 1.2,
	},
	{
		Id = 4, Name = "Zone4_Forges", Nom = "Les Forges",
		Colors = {
			Leaf = { hex("#4A4440"), hex("#665E56") }, Water = { hex("#A8361A"), hex("#D2501E") }, Foam = { hex("#E0662A") },
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
		Id = 5, Name = "Zone5_Abysses", Nom = "La Cité Engloutie",
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
	-- fond : le cercle s'arrête vers z -54 alors que le rempart des décors descend jusqu'à z -74 ; nappe elliptique
	-- (même centre et rayons que le rempart), 0,015 stud sous le cercle pour éviter le z-fighting
	local back = piece(parent, "FondArriere", Enum.PartType.Block, Vector3.new(0.4, 118, 110), colors[1], Vector3.new(0, top - 0.215, -20), FLAT)
	local disc = Instance.new("SpecialMesh")
	disc.MeshType = Enum.MeshType.Cylinder
	disc.Parent = back
	local patches = { { -30, 26, 26 }, { 32, 30, 22 }, { -36, -26, 26 }, { 34, -30, 22 }, { -4, -44, 20 }, { 40, 4, 16 }, { -42, 6, 16 } }
	for index, p in patches do
		piece(parent, "Tache", Enum.PartType.Cylinder, Vector3.new(0.4, p[3], p[3]), colors[if index % 2 == 0 then 2 else 3],
			Vector3.new(p[1], top - 0.18, p[2]), FLAT)
	end
end

-- Zone de bataille (docs/ZONES.md § Règles de décor) : sol de couleur distincte au centre de l'arène, comme la
-- clairière de sable de la Zone 1 : large bande de l'entrée à la structure du boss, bouts arrondis, quelques
-- taches plus sombres. Couvre les cases des héros et FrontEnnemi ; 0,055 stud au-dessus du sol de zone.
local function battleground(parent: Instance, color: Color3, spot: Color3, back: number?)
	local top = GROUND_TOP - GROUND_Y + 0.055
	local zBack = back or -44
	local len = 30 - zBack
	piece(parent, "ZoneBataille", Enum.PartType.Block, Vector3.new(44, 0.2, len), color, Vector3.new(0, top - 0.1, (30 + zBack) / 2))
	piece(parent, "ZoneBatailleAvant", Enum.PartType.Cylinder, Vector3.new(0.2, 44, 44), color, Vector3.new(0, top - 0.1, 30), FLAT)
	piece(parent, "ZoneBatailleFond", Enum.PartType.Cylinder, Vector3.new(0.2, 40, 40), color, Vector3.new(0, top - 0.1, zBack), FLAT)
	for _, t in { { -9, 12, 6 }, { 7, 20, 5 }, { -4, -12, 4 }, { 10, -30, 5 }, { -12, -36, 4 }, { 3, 2, 3 } } do
		piece(parent, "TacheBataille", Enum.PartType.Cylinder, Vector3.new(0.2, t[3], t[3]), spot, Vector3.new(t[1], top - 0.08, t[2]), FLAT)
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

---------------------------------------------------------------- Zone 2 : le Royaume des Sables
-- Ce qui remplace la Zone 1 : falaises de grès (falaises vertes), canal ancien et oasis (rivière),
-- avant-poste du désert (camp gobelin). Signature : une énorme tête de statue qui sort du sable.

local function palm(parent: Instance, at: Vector3, h: number, lean: number, trunk: Color3, leaf: Color3)
	-- tronc en tronçons décalés (courbe), bagues sombres, couronne de 7 palmes tombantes
	local top = at
	for i = 0, 4 do
		local seg = at + V(lean * (i / 4) ^ 2 * h * 0.25, i * h / 5, 0)
		ball(parent, "Tronc", V(1.3 - i * 0.12, h / 5 + 0.6, 1.3 - i * 0.12), if i % 2 == 0 then trunk else trunk:Lerp(Color3.new(0, 0, 0), 0.15),
			seg + V(0, h / 10, 0))
		top = seg + V(0, h / 5, 0)
	end
	for i = 0, 6 do
		local a = i * math.pi * 2 / 7
		local dir = V(math.cos(a), 0, math.sin(a))
		ball(parent, "Palme", V(1.4, 0.35, 5.2), if i % 2 == 0 then leaf else leaf:Lerp(Color3.new(1, 1, 0.6), 0.15),
			top + dir * 2.2 + V(0, -0.5, 0), CFrame.Angles(0, -a + math.pi / 2, 0) * CFrame.Angles(0.45, 0, 0))
	end
	for i = 0, 2 do
		ball(parent, "Datte", V(0.6, 0.6, 0.6), hex("#8C4E28"), top + V(math.cos(i * 2.1) * 0.5, -0.4, math.sin(i * 2.1) * 0.5))
	end
end

local function amphora(parent: Instance, at: Vector3, k: number, color: Color3, tipped: boolean?)
	local body = if tipped then CFrame.Angles(0, at.X, 0) * CFrame.Angles(math.pi / 2.2, 0, 0) else CFrame.identity
	local lift = if tipped then 0.8 * k else 1 * k
	ball(parent, "Amphore", V(1.6, 2, 1.6) * k, color, at + V(0, lift, 0), body)
	local up = body.UpVector
	piece(parent, "Col", Enum.PartType.Cylinder, V(0.9, 0.7, 0.7) * k, color, at + V(0, lift, 0) + up * 1.3 * k, body * FLAT)
	piece(parent, "Levre", Enum.PartType.Cylinder, V(0.25, 1, 1) * k, color:Lerp(Color3.new(0, 0, 0), 0.2), at + V(0, lift, 0) + up * 1.75 * k,
		body * FLAT)
	piece(parent, "Bande", Enum.PartType.Cylinder, V(0.2, 1.62, 1.62) * k, hex("#3A2A1E"), at + V(0, lift, 0) + up * 0.3 * k, body * FLAT)
end

local function amphorae(parent: Instance, at: Vector3, color: Color3)
	amphora(parent, at, 1, color)
	amphora(parent, at + V(1.7, 0, 0.6), 0.75, color:Lerp(Color3.new(1, 1, 1), 0.1))
	amphora(parent, at + V(0.4, 0, 2), 0.85, color, true)
end

local function flag(parent: Instance, at: Vector3, h: number, wood: Color3, cloth: Color3, trim: Color3)
	column(parent, "Mat", h, 0.45, wood, at)
	ball(parent, "Pommeau", V(0.8, 0.8, 0.8), trim, at + V(0, h + 0.2, 0))
	piece(parent, "Vergue", Enum.PartType.Cylinder, V(3.4, 0.3, 0.3), wood, at + V(1.6, h - 0.4, 0))
	piece(parent, "Drapeau", Enum.PartType.Block, V(3.2, 2.4, 0.15), cloth, at + V(1.7, h - 1.8, 0))
	piece(parent, "Galon", Enum.PartType.Block, V(3.2, 0.35, 0.18), trim, at + V(1.7, h - 0.8, 0))
	-- bas déchiré : trois lambeaux de longueurs inégales
	for i, len in { 1.4, 0.6, 1.1 } do
		piece(parent, "Lambeau", Enum.PartType.Block, V(0.9, len, 0.15), cloth, at + V(0.6 + (i - 1) * 1.1, h - 3 - len / 2, 0),
			CFrame.Angles(0, 0, (i - 2) * 0.12))
	end
end

local function palisade(parent: Instance, from: Vector3, to: Vector3, wood: Color3)
	local dir = to - from
	local n = math.floor(dir.Magnitude / 1.1)
	local yaw = math.atan2(-dir.Z, dir.X)
	for i = 0, n do
		local at = from + dir * (i / n)
		local h = 3.4 + (i * 7 % 5) * 0.35
		local stake = column(parent, "Pieu", h, 0.9, if i % 2 == 0 then wood else wood:Lerp(Color3.new(1, 1, 1), 0.12), at)
		stake.CFrame *= CFrame.Angles((i % 3 - 1) * 0.05, 0, 0)
		ball(parent, "TetePieu", V(0.9, 0.9, 0.9), wood, at + V(0, h, 0))
	end
	for _, y in { 1.2, 2.6 } do
		piece(parent, "Liure", Enum.PartType.Block, V(dir.Magnitude + 0.6, 0.35, 0.3), wood:Lerp(Color3.new(0, 0, 0), 0.3),
			(from + to) / 2 + V(0, y, 0) + rotY(yaw):VectorToWorldSpace(V(0, 0, 0.55)), rotY(yaw))
	end
end

local function bones(parent: Instance, at: Vector3, yaw: number, bone: Color3, dark: Color3)
	local r = rotY(yaw)
	local function p(x: number, y: number, z: number): Vector3
		return at + r:VectorToWorldSpace(V(x, y, z))
	end
	ball(parent, "Colonne", V(0.7, 0.7, 6), bone, p(0, 0.3, 0), r)
	for i = 0, 4 do
		for _, side in { -1, 1 } do
			ball(parent, "Cote", V(0.45, 2.6 - math.abs(i - 2) * 0.35, 0.5), bone, p(side * 1, 1, -2 + i * 1),
				r * CFrame.Angles(0, 0, side * -0.55))
		end
	end
	ball(parent, "Crane", V(1.8, 1.4, 2.2), bone, p(0, 0.6, 4))
	for _, side in { -1, 1 } do
		ball(parent, "Orbite", V(0.5, 0.45, 0.3), dark, p(side * 0.45, 0.8, 5.05))
		ball(parent, "Corne", V(0.4, 0.4, 1.8), bone, p(side * 1, 1, 3.6), r * CFrame.Angles(-0.5, side * 0.6, 0))
	end
end

local function cliff(parent: Instance, at: Vector3, yaw: number, len: number, h: number, bands: { Color3 }, cap: Color3?)
	-- crête de grès le long du rempart : masses très chevauchées de hauteurs inégales, une strate claire
	-- continue à mi-hauteur et une table rocheuse continue au sommet, éboulis au pied côté arène
	local r = rotY(yaw)
	local n = math.max(2, math.floor(len / 6))
	for i = 0, n - 1 do
		local u = (i / (n - 1) - 0.5) * len * 0.8
		local hi = h * (0.8 + ((i * 5) % 4) * 0.08)
		local base = at + r:VectorToWorldSpace(V(u, 0, ((i % 2) - 0.5) * 1.4))
		ball(parent, "Roche", V(len / n * 2.4, hi * 1.3, 9 + (i % 3)), if i % 2 == 0 then bands[1] else bands[3], base + V(0, hi * 0.33, 0),
			r * CFrame.Angles(0, ((i % 3) - 1) * 0.12, ((i % 3) - 1) * 0.06))
		if i % 2 == 0 then
			ball(parent, "Eboulis", V(3.4, 2, 2.8), bands[3], base + r:VectorToWorldSpace(V(1.2, 0.4, 6)), r * rotY(i))
		end
		if cap then
			-- calotte (neige) posée sur le sommet de chaque masse : rien ne flotte
			ball(parent, "Calotte", V(len / n * 1.5, 2, 6.4 + (i % 3)), cap, base + V(0, hi * 0.33 + hi * 0.56, 0),
				r * CFrame.Angles(0, ((i % 3) - 1) * 0.12, ((i % 3) - 1) * 0.06))
		end
	end
	if not cap then
		ball(parent, "Strate", V(len * 0.9, 1.8, 10.8), bands[2], at + V(0, h * 0.45, 0), r)
		ball(parent, "Table", V(len * 0.6, 2.4, 7), bands[2], at + V(0, h * 0.82, 0), r)
	end
end

local function desertRealm(m: Instance, sand: Color3, stone: Color3, pale: Color3, gold: Color3, dark: Color3)
	local terracotta, wood, cloth, bone = hex("#B4643C"), hex("#9C8058"), hex("#A8452E"), hex("#E8DCC0")
	local bands = { hex("#B98A62"), hex("#D4AA80"), hex("#A87652") }


	-- signature : une énorme tête de statue qui sort du sable, côté est, tournée vers l'entrée
	local t = Instance.new("Folder")
	t.Name, t.Parent = "TeteColossale", m
	local H = V(42, 0, -10)
	-- némès (coiffe rayée) derrière le visage ; le visage regarde l'entrée (+z)
	ball(t, "Coiffe", V(26, 20, 18), stone, H + V(0, 10, -3))
	ball(t, "Visage", V(18, 22, 16), pale, H + V(0, 6, 0))
	for _, side in { -1, 1 } do
		piece(t, "Pan", Enum.PartType.Block, V(3.4, 14, 5), stone, H + V(side * 10.5, 6, 1))
		for y = 0, 4 do
			piece(t, "Rayure", Enum.PartType.Block, V(3.55, 0.7, 5.15), gold, H + V(side * 10.5, 0.6 + y * 2.6, 1))
		end
		piece(t, "Arcade", Enum.PartType.Block, V(4.6, 0.9, 1.6), pale:Lerp(Color3.new(0, 0, 0), 0.1), H + V(side * 3.6, 12.8, 5.8),
			CFrame.Angles(-0.25, 0, side * -0.12))
		ball(t, "Oeil", V(3.8, 1.5, 1.2), dark, H + V(side * 3.6, 11, 6.6))
		ball(t, "Levre", V(5, 1.2, 1.4), pale:Lerp(Color3.new(0, 0, 0), 0.08), H + V(0, 5.6 - (side + 1) * 0.55, 7.6))
	end
	ball(t, "Bandeau", V(22.6, 1.6, 15.8), gold, H + V(0, 15.2, -3)) -- anneau doré qui épouse la coiffe
	piece(t, "Uraeus", Enum.PartType.Wedge, V(1.6, 2.8, 1.8), gold, H + V(0, 17, 5.4), rotY(math.pi))
	piece(t, "Nez", Enum.PartType.Wedge, V(2.8, 4.4, 2.4), pale, H + V(0, 8.6, 8.4), rotY(math.pi))
	piece(t, "Fissure", Enum.PartType.Block, V(0.4, 7, 0.5), dark, H + V(-6, 9, 5.6), CFrame.Angles(0, 0.6, -0.35))
	for i, at in { V(-14, 1.2, 10), V(-17, 0.8, 6) } do
		piece(t, "MorceauTombe", Enum.PartType.Block, V(3.6, 3.6, 3.2) / i ^ 0.4, stone:Lerp(Color3.new(0, 0, 0), 0.08), H + at,
			CFrame.Angles(0.3 * i, 0.6 * i, 0.2))
	end
	ball(t, "Ensablement", V(34, 7, 26), sand, H + V(0, 0, 1))
	ball(t, "Ensablement", V(14, 6, 10), sand, H + V(-12, 0, 9), rotY(0.4))
	ball(t, "Ensablement", V(12, 5, 9), sand, H + V(12, 0, 7), rotY(-0.3))

	local c = Instance.new("Folder")
	c.Name, c.Parent = "FalaisesGres", m
	cliff(c, V(49, 0, -41), 1.94, 28, 15, bands)
	cliff(c, V(-47, 0, -41), 1.08, 26, 14, bands)
	cliff(c, V(-51, 0, -10), math.pi / 2, 12, 9, bands)

	-- oasis latérale autour des mares (lac de la Zone 1) et canal ancien, lit asséché vers la pyramide
	local o = Instance.new("Folder")
	o.Name, o.Parent = "Oasis", m
	local palmTrunk, palmLeaf = hex("#8C6A44"), hex("#6E9A3C")
	palm(o, V(-38, 0, 16), 9, 1, palmTrunk, palmLeaf)
	palm(o, V(-36, 0, 8), 7, -1, palmTrunk, palmLeaf)
	palm(o, V(-38, 0, -24), 8.5, 1, palmTrunk, palmLeaf)
	palm(o, V(-22, 0, -34), 7.5, -1, palmTrunk, palmLeaf)
	palm(o, V(-18, 0, 20), 6.5, 1, palmTrunk, palmLeaf)
	for _, at in { V(-22, 0, 6), V(-34, 0, -15), V(-25, 0, -26) } do
		reeds(o, at, hex("#7A8A44"), hex("#8C5A30"))
	end
	-- bassin de l'oasis sous la grande mare du lac (repère MareGrande inchangé), bordé de pierres rondes
	piece(o, "EauOasis", Enum.PartType.Cylinder, V(0.15, 15, 15), hex("#4E9E96"), V(-26, 0, 12), FLAT)
	for i = 0, 10 do
		local a = i * math.pi * 2 / 11
		ball(o, "PierreOasis", V(2.2, 1, 1.6), if i % 2 == 0 then stone else hex("#B4946A"), V(-26 + math.cos(a) * 7.9, 0.2, 12 + math.sin(a) * 7.9),
			rotY(-a))
	end
	-- canal : bordures de grès de part et d'autre du lit, puis lit asséché à demi rempli de sable
	for i = 0, 5 do
		local z = -34 - i * 3
		for _, side in { -1, 1 } do
			piece(o, "BordCanal", Enum.PartType.Block, V(1.2, 0.9, 2.8), if i % 2 == 0 then stone else bands[2], V(-29 + side * 2.2, 0.45, z),
				rotY((i % 2) * 0.05))
		end
		piece(o, "LitSec", Enum.PartType.Block, V(3.2, 0.12, 3), hex("#A88A5C"), V(-29, 0.08, z))
		if i % 2 == 1 then ball(o, "SableCanal", V(2.8, 0.9, 2.2), sand, V(-29 + (i % 3 - 1) * 0.5, 0.15, z)) end
	end
	amphorae(o, V(-40, 0, -2), terracotta)

	-- avant-poste du désert (à la place du camp gobelin), côté est de l'entrée
	local a = Instance.new("Folder")
	a.Name, a.Parent = "AvantPoste", m
	palisade(a, V(24, 0, 36), V(44, 0, 38), wood)
	palisade(a, V(46, 0, 34), V(48, 0, 16), wood)
	-- auvent de toile tendu sur quatre poteaux, bord déchiré
	for _, p in { V(30, 0, 22), V(38, 0, 22), V(30, 0, 30), V(38, 0, 30) } do
		column(a, "Poteau", 5, 0.6, wood, p)
	end
	piece(a, "Auvent", Enum.PartType.Block, V(9.6, 0.25, 9.6), cloth, V(34, 5.1, 26), CFrame.Angles(0.12, 0, 0))
	piece(a, "BandeAuvent", Enum.PartType.Block, V(9.6, 0.3, 1.2), gold, V(34, 5.05, 26.6), CFrame.Angles(0.12, 0, 0))
	for i = 0, 4 do
		piece(a, "Frange", Enum.PartType.Block, V(1.6, 0.6 + (i % 3) * 0.4, 0.15), cloth, V(30.4 + i * 1.9, 4.2 - (i % 3) * 0.2, 30.8))
	end
	ball(a, "Coussin", V(2.4, 0.8, 1.6), hex("#8C3A24"), V(33, 0.4, 25))
	amphorae(a, V(41, 0, 26), terracotta)
	amphorae(a, V(26, 0, 18), terracotta:Lerp(pale, 0.2))
	flag(a, V(24, 0, 34), 8, wood, cloth, gold)
	flag(a, V(46, 0, 18), 7, wood, cloth, gold)
	bones(a, V(42, 0, 10), 0.6, bone, dark)

	-- ossements, drapeaux et amphores dispersés, petits tas de sable
	local d = Instance.new("Folder")
	d.Name, d.Parent = "Vestiges", m
	bones(d, V(-44, 0, 30), -0.4, bone, dark)
	flag(d, V(-16, 0, -46), 9, wood, cloth, gold)
	flag(d, V(52, 0, -2), 6.5, wood, cloth, gold)
	amphorae(d, V(-15, 0, -40), terracotta)
	amphorae(d, V(15, 0, -58), terracotta:Lerp(pale, 0.2))
	for _, s in { { 18, 42, 4 }, { -20, 42, 3.5 }, { -46, 22, 3 }, { 30, 46, 3 }, { -14, -52, 4 }, { 20, -60, 3.5 }, { 16, 2, 2.6 } } do
		ball(d, "PetitTas", V(s[3], s[3] * 0.32, s[3] * 0.8), if #d:GetChildren() % 2 == 0 then sand else sand:Lerp(Color3.new(1, 1, 1), 0.08),
			V(s[1], 0.1, s[2]), rotY(s[1]))
	end
end

---------------------------------------------------------------- Zone 3 : le Royaume Gelé
-- Vallée glaciaire : couronne de rochers enneigés (falaises vertes), lac gelé et pont verglacé (rivière),
-- bosquet de sapins enneigés autour d'un cristal (camp de la Zone 1). Signature : un château prisonnier d'un
-- glacier, au fond. Valeurs contrastées (roche sombre, neige, glace du profond au clair), formes arrondies.

local function snowyPine(parent: Instance, at: Vector3, h: number, needle: Color3, snow: Color3)
	column(parent, "Tronc", h * 0.3, 0.9, hex("#5A4A3C"), at)
	for i = 0, 2 do
		local w = (4.4 - i * 1.2) * h / 9
		local y = h * (0.3 + i * 0.2)
		ball(parent, "Branches", V(w, h * 0.3, w), needle, at + V(0, y + h * 0.1, 0))
		ball(parent, "NeigeBranches", V(w * 0.8, h * 0.12, w * 0.8), snow, at + V(0, y + h * 0.22, 0))
	end
end

-- statue de chevalier prise dans une gangue de glace translucide, sur socle, tournée vers l'arène
local function frozenStatue(parent: Instance, at: Vector3, yaw: number, stoneC: Color3, ice: Color3, snow: Color3)
	local r = rotY(yaw)
	local function p(x: number, y: number, z: number): Vector3
		return at + r:VectorToWorldSpace(V(x, y, z))
	end
	piece(parent, "Socle", Enum.PartType.Block, V(3.6, 1.2, 3.6), stoneC:Lerp(Color3.new(0, 0, 0), 0.15), p(0, 0.6, 0), r)
	ball(parent, "Corps", V(2.6, 3.6, 2), stoneC, p(0, 3, 0), r)
	ball(parent, "Tete", V(1.6, 1.7, 1.6), stoneC, p(0, 5.4, 0.1), r)
	ball(parent, "Heaume", V(1.9, 1.1, 1.9), stoneC:Lerp(Color3.new(0, 0, 0), 0.1), p(0, 5.9, 0), r)
	ball(parent, "Bouclier", V(2, 2.6, 0.6), stoneC:Lerp(Color3.new(0, 0, 0), 0.08), p(-1.3, 3.2, 1), r * CFrame.Angles(0, -0.3, 0))
	column(parent, "Epee", 4.6, 0.35, stoneC, p(1.3, 1.4, 0.9))
	local shell = ball(parent, "Gangue", V(4.8, 7.6, 4), ice, p(0, 3.6, 0.2), r, Enum.Material.Ice)
	shell.Transparency = 0.45
	ball(parent, "NeigeGangue", V(3.6, 1, 3), snow, p(0, 7.3, 0.2), r)
end

-- ruine (colonne brisée et arc tombé) prisonnière d'un bloc de glace
local function frozenRuin(parent: Instance, at: Vector3, stoneC: Color3, ice: Color3, snow: Color3)
	column(parent, "ColonneRuine", 6, 1.8, stoneC, at)
	piece(parent, "Chapiteau", Enum.PartType.Block, V(2.6, 0.7, 2.6), stoneC, at + V(0, 6.3, 0))
	piece(parent, "Troncon", Enum.PartType.Cylinder, V(3, 1.6, 1.6), stoneC, at + V(2.6, 0.8, 1), CFrame.Angles(0, 0.5, 0))
	piece(parent, "ArcTombe", Enum.PartType.Block, V(5, 1.2, 1.4), stoneC:Lerp(Color3.new(0, 0, 0), 0.08), at + V(-1.8, 1.6, 1.6),
		CFrame.Angles(0, 0.3, 0.35))
	local shell = ball(parent, "Gangue", V(9, 8.4, 6.4), ice, at + V(0.2, 3, 0.8), rotY(0.4), Enum.Material.Ice)
	shell.Transparency = 0.45
	ball(parent, "NeigeGangue", V(6.4, 1.4, 4.4), snow, at + V(0.2, 7, 0.8), rotY(0.4))
end

local function coldLantern(parent: Instance, at: Vector3, iron: Color3, glow: Color3, snow: Color3)
	column(parent, "Poteau", 4.4, 0.4, iron, at)
	piece(parent, "Potence", Enum.PartType.Block, V(1.6, 0.3, 0.3), iron, at + V(0.6, 4.3, 0))
	piece(parent, "Cage", Enum.PartType.Block, V(1.1, 1.4, 1.1), iron, at + V(1.2, 3.4, 0))
	local core = ball(parent, "LueurFroide", V(0.8, 1, 0.8), glow, at + V(1.2, 3.4, 0), nil, Enum.Material.Neon)
	light(core, glow, 10, 0.7)
	ball(parent, "NeigeLanterne", V(1.3, 0.4, 1.3), snow, at + V(1.2, 4.25, 0))
end

-- Cristaux de glace : une aiguille principale et deux secondaires, ellipsoïdes inclinés (rien d'anguleux) ;
-- `glow` ajoute un cœur lumineux discret dans l'aiguille principale.
local function iceCrystal(parent: Instance, at: Vector3, h: number, color: Color3, glow: Color3?)
	for i, c in { { 0, 1, 0, 0 }, { 0.9, 0.62, 0.35, 0.5 }, { -0.8, 0.5, -0.3, 2.4 } } do
		local s = h * c[2]
		local spike = ball(parent, "Cristal", V(s * 0.22, s, s * 0.22), if i == 1 then color else color:Lerp(Color3.new(1, 1, 1), 0.25),
			at + V(c[1] * h * 0.12, s * 0.42, 0), rotY(c[4]) * CFrame.Angles(c[3], 0, c[3] * 0.6), Enum.Material.Ice)
		spike.Transparency = 0.1
	end
	if glow then
		local core = ball(parent, "CoeurCristal", V(h * 0.1, h * 0.35, h * 0.1), glow, at + V(0, h * 0.4, 0), nil, Enum.Material.Neon)
		light(core, glow, 10, 0.6)
	end
end

-- Blocs de glace arrondis (galets de glace épais), à demi enneigés
local function iceChunks(parent: Instance, at: Vector3, ice: Color3, snow: Color3)
	for i, b in { { 0, 0, 3.4, 0.3 }, { 2.8, 1, 2.4, -0.5 }, { -1.6, 2.2, 2, 0.9 } } do
		local k = b[3]
		local chunk = ball(parent, "BlocGlace", V(k * 1.1, k * 0.85, k), ice, at + V(b[1], k * 0.35, b[2]), rotY(b[4]) * CFrame.Angles(0.15 * i, 0, 0),
			Enum.Material.Ice)
		chunk.Transparency = 0.12
		ball(parent, "NeigeBloc", V(k * 0.8, k * 0.25, k * 0.7), snow, at + V(b[1], k * 0.7, b[2]), rotY(b[4]))
	end
end

-- Igloo : dôme de neige à joints de blocs (anneaux), tunnel d'entrée tourné vers l'arène
local function igloo(parent: Instance, at: Vector3, yaw: number, C: { [string]: Color3 }, scale: number?)
	local k = scale or 1
	local r = rotY(yaw)
	ball(parent, "Dome", V(9, 7, 9) * k, C.Snow, at + V(0, 0.6, 0) * k)
	for i = 1, 2 do
		ball(parent, "Joint", V(9.2 - i * 1.6, 0.4, 9.2 - i * 1.6) * k, C.SnowShade, at + V(0, 1 + i * 1.6, 0) * k)
	end
	ball(parent, "Tunnel", V(4, 4, 4.6) * k, C.Snow, at + r:VectorToWorldSpace(V(0, 0.6, 4.2) * k), r)
	ball(parent, "Entree", V(2.2, 2.6, 1) * k, C.Deep, at + r:VectorToWorldSpace(V(0, 1, 6.4) * k), r)
end

-- Mare gelée avec un trou de pêche, son tabouret et sa canne
local function frozenPond(parent: Instance, at: Vector3, d: number, C: { [string]: Color3 })
	piece(parent, "GlaceMare", Enum.PartType.Cylinder, V(0.15, d, d), C.Ice, at + V(0, 0.03, 0), FLAT, Enum.Material.Ice)
	for i = 0, 6 do
		local a = i * math.pi * 2 / 7
		ball(parent, "BordNeige", V(3, 1, 2), C.Snow, at + V(math.cos(a) * d * 0.52, 0.2, math.sin(a) * d * 0.52), rotY(-a))
	end
	piece(parent, "TrouPeche", Enum.PartType.Cylinder, V(0.16, 2.2, 2.2), C.Deep, at + V(2, 0.05, 1), FLAT)
	column(parent, "Tabouret", 1.2, 1.4, hex("#6A5A4C"), at + V(3.8, 0, 2.4))
	piece(parent, "Canne", Enum.PartType.Cylinder, V(4, 0.2, 0.2), hex("#6A5A4C"), at + V(3, 1.8, 1.6), CFrame.Angles(0, 0.6, 0.5))
end

-- Défenses de mammouth croisées en arche, à demi enneigées
local function mammothTusks(parent: Instance, at: Vector3, yaw: number, C: { [string]: Color3 })
	local r = rotY(yaw)
	local ivory = hex("#E8DCC0")
	for _, side in { -1, 1 } do
		for i = 0, 2 do
			ball(parent, "Defense", V(1.4 - i * 0.25, 4, 1.4 - i * 0.25), ivory,
				at + r:VectorToWorldSpace(V(side * (3.6 - i * 1.3), 1.6 + i * 3.2, 0)), r * CFrame.Angles(0, 0, side * (0.15 + i * 0.45)))
		end
	end
	ball(parent, "NeigeDefense", V(6, 1.6, 3), C.Snow, at + V(0, 0.4, 0), r)
end

-- Arbre mort givré : tronc sombre, branches nues blanchies de givre
local function frostTree(parent: Instance, at: Vector3, h: number, yaw: number, C: { [string]: Color3 })
	local bark = hex("#4A4A58")
	ball(parent, "Tronc", V(1.8, h, 1.8), bark, at + V(0, h * 0.45, 0), rotY(yaw) * CFrame.Angles(0, 0, 0.06))
	for _, br in { { 0.6, 0.7, 1.0 }, { 0.75, -0.8, 2.2 }, { 0.88, 0.5, 4.1 } } do
		local len = h * 0.45
		ball(parent, "Branche", V(0.8, len, 0.8), bark, at + V(0, h * br[1], 0) + rotY(yaw + br[3]):VectorToWorldSpace(V(0, 0, len * 0.3)),
			rotY(yaw + br[3]) * CFrame.Angles(br[2], 0, 0))
		ball(parent, "Givre", V(1.4, len * 0.7, 1.4), C.IceLight, at + V(0, h * br[1] + len * 0.18, 0) + rotY(yaw + br[3]):VectorToWorldSpace(V(0, 0, len * 0.42)),
			rotY(yaw + br[3]) * CFrame.Angles(br[2], 0, 0), Enum.Material.Ice)
	end
	ball(parent, "NeigePied", V(4, 1.4, 3.4), C.Snow, at + V(0, 0.2, 0), rotY(yaw))
end

-- Grande porte d'où sortent le boss et les ennemis (règle de décor n° 1) : fond sombre arrondi, deux montants,
-- linteau en ellipse, seuil lumineux. `kit` : Dark, Post, Lintel, Glow, et Material optionnel des montants.
local function bossGate(parent: Instance, z: number, w: number, h: number, kit: { [string]: any })
	piece(parent, "FondPorte", Enum.PartType.Block, V(w, h * 0.7, 0.6), kit.Dark, V(0, h * 0.35, z - 0.6))
	ball(parent, "ArcPorte", V(w, h * 0.5, 0.6), kit.Dark, V(0, h * 0.7, z - 0.6))
	for _, side in { -1, 1 } do
		column(parent, "MontantPorte", h + 1, 2.2, kit.Post, V(side * (w / 2 + 1), 0, z), kit.Material)
	end
	ball(parent, "Linteau", V(w + 5, 3, 3), kit.Lintel, V(0, h + 1, z), nil, kit.LintelMaterial)
	local seuil = ball(parent, "LueurSeuil", V(w * 0.85, 0.4, 1.6), kit.Glow, V(0, 0.2, z + 0.4), nil, Enum.Material.Neon)
	light(seuil, kit.Glow, 14, 0.9)
end

-- Repères de sortie des ennemis du décor : sans plateau, la rampe, la porte et les bords du plateau
-- deviennent la grande porte du château (les ennemis la franchissent puis rejoignent le front) ;
-- le sommet de la tour devient la corniche du donjon, d'où le boss saute.
local function moveMarkers(m: Instance, door: number?, top: Vector3?)
	local sources = m:FindFirstChild("SourcesEnnemis")
	if not sources then return end
	local function place(name: string, at: Vector3, steps: { Vector3 }?)
		local marker = sources:FindFirstChild(name)
		if not marker or not marker:IsA("BasePart") then return end
		local function put(part: BasePart, pos: Vector3)
			local world = PIVOT:PointToWorldSpace(Vector3.new(pos.X, 0, pos.Z))
			part.CFrame = CFrame.new(world.X, GROUND_Y + pos.Y, world.Z) * PIVOT.Rotation
		end
		put(marker, at)
		for i, step in steps or {} do
			local child = marker:FindFirstChild(`Etape{i}`)
			if child and child:IsA("BasePart") then put(child, step) end
		end
	end
	local z = door or -56
	place("Tente", V(0, 0, z), { V(0, 0, z + 10), V(0, 0, -36) })
	place("HautRampe", V(0, 0, z), { V(0, 0, z + 16) })
	place("BordPlateau1", V(-5, 0, z + 2))
	place("BordPlateau2", V(5, 0, z + 2))
	place("SommetTour", top or V(0, 26.8, -59.4))
end

local function glacialRealm(m: Instance, C: { [string]: Color3 })
	-- rempart : couronne de rochers sombres coiffés de neige, congères au pied côté arène, cristaux de glace
	local r = Instance.new("Folder")
	r.Name, r.Parent = "RempartGlaciaire", m
	for i, p in enclosure(6) do
		-- variation pseudo-aléatoire stable (0..1) : tailles, hauteurs et décalages différents d'un rocher à l'autre
		local k = (i * 37 % 11) / 10
		local h = if p.back then 15 + k * 6 else 8 + k * 6
		local rot = rotY(p.yaw + (k - 0.5) * 0.5)
		local inward = -(p.at * V(1, 0, 1)).Unit
		local at = p.at - inward * (k - 0.5) * 2.4
		ball(r, "Roche", V(11 + k * 4, h * 1.25, 8.5 + k * 2), if i % 3 == 0 then C.RockLight else C.Rock, at + V(0, h * 0.38, 0),
			rot * CFrame.Angles(0, 0, (k - 0.5) * 0.18))
		ball(r, "Calotte", V(7 + k * 3, 2.8 + k * 1.4, 5.6 + k * 1.4), C.Snow, at + V((k - 0.5) * 1.5, h * 0.38 + h * 0.56, 0), rot * CFrame.Angles(0, 0, (k - 0.5) * 0.25))
		if i % 2 == 0 then
			-- bloc plus petit au pied, côté arène, pour casser l'alignement
			ball(r, "Bloc", V(5 + k * 3, 4 + k * 3, 4.5), C.RockLight, at + inward * 5.2 + V(0, 1.4 + k, 0), rot * CFrame.Angles(0.1, 0, 0.2))
			ball(r, "NeigeBloc", V(4 + k * 2, 1.4, 3.4), C.Snow, at + inward * 5.2 + V(0, 3.2 + k * 2.4, 0), rot)
		end
		ball(r, "Congere", V(12, 2.6, 5.5), C.Snow, p.at + inward * 6.4 + V(0, 0.2, 0), rot)
		if i % 4 == 1 then
			iceCrystal(r, at + inward * 2 + V(0, h * 0.6, 0), 4 + h * 0.4, C.Ice)
		end
	end

	-- signature : château prisonnier d'un glacier, au fond ; vague de glace qui avale son pied, toits en bulbe
	local c = Instance.new("Folder")
	c.Name, c.Parent = "ChateauGlacier", m
	column(c, "Donjon", 26, 12, C.Stone, V(0, 0, -65))
	ball(c, "Corniche", V(13.4, 1.8, 13.4), C.Snow, V(0, 26, -65))
	-- toits en flèche : ellipsoïdes très étirés (ogive), pointe fine, neige au bas du toit
	ball(c, "Toit", V(12.4, 22, 12.4), C.Roof, V(0, 31, -65))
	ball(c, "Fleche", V(2, 9, 2), C.Roof, V(0, 44, -65))
	ball(c, "NeigeToit", V(13.2, 2, 13.2), C.Snow, V(0, 26.8, -65))
	for _, side in { -1, 1 } do
		column(c, "Tourelle", 19, 6.5, C.Stone, V(side * 10.5, 0, -60))
		ball(c, "ToitTourelle", V(7, 15, 7), C.Roof, V(side * 10.5, 22.5, -60))
		ball(c, "FlecheTourelle", V(1.2, 5, 1.2), C.Roof, V(side * 10.5, 30.5, -60))
		ball(c, "NeigeTourelle", V(7.6, 1.6, 7.6), C.Snow, V(side * 10.5, 19.6, -60))
	end
	local window = ball(c, "Fenetre", V(3, 4.4, 0.8), C.Glow, V(0, 20, -58.9), nil, Enum.Material.Neon)
	light(window, C.Glow, 22, 1.2)
	-- grande porte au pied du donjon : les ennemis et le boss de la zone en sortent (repères SourcesEnnemis)
	piece(c, "FondPorte", Enum.PartType.Block, V(7, 8, 0.6), C.Deep, V(0, 4, -58.6))
	ball(c, "ArcPorte", V(7, 5, 0.6), C.Deep, V(0, 8, -58.6))
	for _, side in { -1, 1 } do
		column(c, "MontantPorte", 9, 1.8, C.Stone:Lerp(Color3.new(0, 0, 0), 0.12), V(side * 4.3, 0, -58))
		ball(c, "GivreMontant", V(2.2, 1.4, 2.2), C.Snow, V(side * 4.3, 9.2, -58))
	end
	ball(c, "ArcGlace", V(11, 4.4, 2.4), C.IceLight, V(0, 10.4, -57.8), nil, Enum.Material.Ice)
	ball(c, "NeigeArc", V(9, 1.4, 2.2), C.Snow, V(0, 12.4, -57.8))
	local seuil = ball(c, "LueurSeuil", V(6, 0.4, 1.6), C.Glow, V(0, 0.2, -57.6), nil, Enum.Material.Neon)
	light(seuil, C.Glow, 12, 0.8)
	-- glacier : dalles de glace inclinées qui s'appuient contre le château (bleu profond au pied, clair en haut),
	-- hérissées de grands cristaux ; jamais sur le plateau des sorties (x > 8,4 et z > -54)
	for _, g in {
		{ -13, 8, -59, 22, 9, 7, 0.1, 0.55, C.IceDeep },
		{ 12, 7, -60, 20, 8, 7, -0.05, -0.5, C.IceDeep },
		{ -13, 5, -56, 10, 7, 6, 0.25, 0.1, C.Ice },
		{ 13, 4, -57, 10, 6, 6, 0.3, -0.15, C.Ice },
		{ -18, 14, -64, 16, 8, 8, 0, 0.9, C.Ice },
		{ 17, 12, -66, 14, 8, 8, 0, -0.85, C.Ice },
		{ -7, 16, -61, 10, 6, 6, 0.3, 0.4, C.IceLight },
		{ 8, 15, -62, 10, 6, 6, 0.3, -0.45, C.IceLight },
	} do
		local slab = ball(c, "Glacier", V(g[4], g[5], g[6]), g[9], V(g[1], g[2], g[3]), CFrame.Angles(g[7], 0, g[8]), Enum.Material.Ice)
		slab.Transparency = 0.08
	end
	for _, cr in { { -22, 0, -58, 10 }, { -12, 4, -56, 8 }, { -9, 0, -52, 11 }, { 10, 0, -52, 8 }, { 14, 3, -57, 9 }, { 22, 0, -62, 10 },
		{ -18, 16, -63, 8 }, { 17, 13, -66, 8 }, { -3, 19, -60, 7 } } do
		iceCrystal(c, V(cr[1], cr[2], cr[3]), cr[4], C.IceLight)
	end

	-- falaises glacées : roche sombre et calottes de neige, cascade gelée sur la falaise ouest
	local cl = Instance.new("Folder")
	cl.Name, cl.Parent = "FalaisesGlacees", m
	local bands = { C.Rock, C.RockLight, hex("#4A5E72") }
	cliff(cl, V(49, 0, -41), 1.94, 28, 15, bands, C.Snow)
	cliff(cl, V(-47, 0, -41), 1.08, 26, 14, bands, C.Snow)
	cliff(cl, V(-51, 0, -10), math.pi / 2, 12, 9, bands, C.Snow)
	local wr = rotY(1.08)
	local face = V(-47, 0, -41) + wr:VectorToWorldSpace(V(0, 0, 4.6))
	for i, d in { { 0, 4.6, 13, 2.2, 6.4 }, { -2, 1.6, 8, 1.4, 4 }, { 2.1, 1.4, 6, 1.2, 3 } } do
		local fall = ball(cl, "CascadeGelee", V(d[2], d[3], d[4]), C.IceLight,
			face + V(0, d[5], 0) + wr:VectorToWorldSpace(V(d[1], 0, 0.4 * (i - 1))), wr * CFrame.Angles(-0.12, 0, 0), Enum.Material.Ice)
		fall.Transparency = 0.15
	end
	local pool = ball(cl, "FlaqueGelee", V(8, 0.6, 6), C.Ice, face + wr:VectorToWorldSpace(V(0, 0, 4)) + V(0, 0.1, 0), wr, Enum.Material.Ice)
	pool.Transparency = 0.1

	-- lac gelé (mares de la Zone 1) : grande plaque de glace bordée de neige, pont verglacé sur le ruisseau sud
	local l = Instance.new("Folder")
	l.Name, l.Parent = "LacGele", m
	piece(l, "GlaceLac", Enum.PartType.Cylinder, V(0.15, 15, 15), C.Ice, V(-26, 0.07, 12), FLAT, Enum.Material.Ice)
	for i = 0, 10 do
		local a = i * math.pi * 2 / 11
		ball(l, "BordNeige", V(3, 1.2, 2), if i % 2 == 0 then C.Snow else C.SnowShade, V(-26 + math.cos(a) * 8, 0.2, 12 + math.sin(a) * 8), rotY(-a))
	end
	iceCrystal(l, V(-34, 0, 16), 5, C.Ice)
	iceCrystal(l, V(-20, 0, 5), 4, C.IceLight)
	for i = -1, 1 do
		local deck = piece(l, "Tablier", Enum.PartType.Block, V(2.6, 0.5, 3), C.Ice, V(-29.5 + i * 2.5, 0.9 - math.abs(i) * 0.35, -24.1),
			CFrame.Angles(0, 0, -i * 0.25), Enum.Material.Ice)
		deck.Transparency = 0.1
		for _, side in { -1, 1 } do
			ball(l, "NeigeRambarde", V(2.8, 0.7, 0.6), C.Snow, V(-29.5 + i * 2.5, 1.6 - math.abs(i) * 0.35, -24.1 + side * 1.4),
				CFrame.Angles(0, 0, -i * 0.25))
		end
	end
	coldLantern(l, V(-25, 0, -21.5), C.Iron, C.Glow, C.Snow)

	-- bosquet enneigé autour d'un grand cristal lumineux (à la place du camp de la Zone 1)
	local g = Instance.new("Folder")
	g.Name, g.Parent = "BosquetGivre", m
	for _, t in { { 28, 30, 11 }, { 38, 35, 9 }, { 47, 26, 13 }, { 45, 13, 10 }, { 29, 15, 8 }, { 52, 38, 9 },
		{ -34, 40, 10 }, { -44, 45, 8 }, { -49, 15, 9 } } do
		snowyPine(g, V(t[1], 0, t[2]), t[3], C.Pine, C.Snow)
	end
	ball(g, "Congere", V(14, 3.4, 10), C.Snow, V(36, 0.2, 21))
	iceCrystal(g, V(36, 1.6, 21), 15, C.Ice, C.Glow)
	iceCrystal(g, V(32, 1, 18.5), 7, C.IceLight)
	iceCrystal(g, V(40, 1, 23.5), 6, C.IceLight)

	-- allée : neige tassée (hors cases des héros), cristaux à la place des piliers, lanternes à l'entrée
	local a = Instance.new("Folder")
	a.Name, a.Parent = "AlleeGivre", m
	-- zone de bataille : neige damée bleutée, de l'entrée jusqu'à la grande porte du château
	battleground(a, C.Battle, C.BattleSpot, -44)
	for _, x in { -14, 14 } do
		for _, z in { -10, -24, -38 } do
			iceCrystal(a, V(x, 0, z), 6, C.Ice, if z == -24 then C.Glow else nil)
		end
	end
	for _, x in { -12, 12 } do
		coldLantern(a, V(x, 0, 44), C.Iron, C.Glow, C.Snow)
	end

	-- vestiges : statues et ruine prises dans la glace, blocs de glace arrondis, congères
	local v = Instance.new("Folder")
	v.Name, v.Parent = "VestigesGeles", m
	frozenStatue(v, V(40, 0, -24), -0.5, C.Stone, C.Ice, C.Snow)
	frozenStatue(v, V(-42, 0, -4), 0.6, C.Stone, C.Ice, C.Snow)
	frozenRuin(v, V(-44, 0, 30), C.Stone, C.Ice, C.Snow)
	for _, at in { V(-14, 0, -50), V(20, 0, -60), V(-24, 0, 44) } do
		iceChunks(v, at, C.Ice, C.Snow)
	end
	for _, d in { { 42, -8 }, { 38, -64 }, { -44, -54 }, { -38, 40 } } do
		ball(v, "Congere", V(10, 3, 7), C.Snow, V(d[1], 0.4, d[2]), rotY(d[2]))
	end
	for _, at in { V(21, 0, -24), V(-19, 0, -24), V(-23, 0, 3) } do
		iceCrystal(v, at + V(-1.5, 0, -2.4), 4.5, C.Ice)
		ball(v, "Congere", V(6, 2, 4), C.Snow, at + V(1.6, 0.2, -2.2))
	end

	-- plus de plateau (sortie de la Zone 1) : les ennemis sortent de la grande porte du château.
	-- À sa place et autour : igloos, mare gelée et trou de pêche, défenses de mammouth, arbres morts givrés.
	local b = Instance.new("Folder")
	b.Name, b.Parent = "VieGlaciaire", m
	igloo(b, V(26, 0, -44), 0.35, C)
	igloo(b, V(-36, 0, -34), -0.5, C, 0.75)
	frozenPond(b, V(30, 0, -16), 13, C)
	mammothTusks(b, V(-24, 0, -46), 0.2, C)
	for _, t in { { -20, -40, 11, 0.4 }, { 40, -38, 12, -0.6 }, { 46, -4, 10, 1.2 } } do
		frostTree(b, V(t[1], 0, t[2]), t[3], t[4], C)
	end
	for _, at in { V(16, 0, -50), V(34, 0, -52), V(-16, 0, -46) } do
		ball(b, "Congere", V(8, 2.4, 6), C.Snow, at + V(0, 0.2, 0), rotY(at.X))
	end
	-- petits cristaux au pied du rempart, côté arène
	for i, p in enclosure(6) do
		if i % 4 == 2 then
			iceCrystal(b, p.at - (p.at * V(1, 0, 1)).Unit * 9, 3 + (i % 3), C.IceLight)
		end
	end
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
	-- dunes (la tête de statue, les falaises et l'avant-poste occupent les anciens emplacements)
	for _, d in { { 36, -30, 14 }, { 40, -62, 14 }, { -50, 40, 12 } } do
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
	desertRealm(m, sand, stone, light2, gold, dark)
end

---------------------------------------------------------------- Zone 3 : vallée glaciaire du Royaume Gelé
BUILD[3] = function(m: Instance)
	moveMarkers(m)
	glacialRealm(m, {
		Snow = hex("#F2F7FB"), SnowShade = hex("#D6E3EE"), Rock = hex("#5E7488"), RockLight = hex("#8197AC"),
		IceDeep = hex("#4F9BD0"), Ice = hex("#8CC8EE"), IceLight = hex("#CDEBFA"), Glow = hex("#6FE3FF"),
		Roof = hex("#2E4E7E"), Stone = hex("#8A98A6"), Pine = hex("#2E5A44"), Iron = hex("#3E4A5A"), Deep = hex("#1E3C6E"),
		Battle = hex("#A7C5E0"), BattleSpot = hex("#93B4D4"),
	})
end

---------------------------------------------------------------- Zone 4 : forteresse des forges
-- Émetteur de particules d'un effet de la porte (Rate 0 : le client émet en rafale ; sinon flux continu).
local function emitter(part: BasePart, name: string, texture: string, color: Color3, rate: number, size: number, speed: number, life: number)
	local e = Instance.new("ParticleEmitter")
	e.Name, e.Texture, e.Color, e.Rate = name, texture, ColorSequence.new(color), rate
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.5), NumberSequenceKeypoint.new(1, size) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	e.Speed, e.Lifetime = NumberRange.new(speed * 0.6, speed), NumberRange.new(life * 0.7, life)
	e.SpreadAngle, e.EmissionDirection = Vector2.new(25, 25), Enum.NormalId.Top
	e.Parent = part
	return e
end

-- Porte-Fournaise (docs/ZONES.md § Porte du boss) : immense arche de métal intégrée au grand fourneau, deux
-- battants, intérieur rougeoyant, tuyaux et vapeur, chaînes à contrepoids, marteaux mécaniques, symboles forgés.
-- Modèle « PorteBoss » animé par le client à l'entrée du boss (src/client/Combat/BossGate.lua) :
--   Battants/<Battant> (pivot : pièce Charniere, attribut Sens), Chaines/<Chaine> (Poulie en haut),
--   Marteaux/<Marteau> (pivot : Axe, partie mobile : Bras), pièces à attribut Lueur (s'allument),
--   Effets.Foyer (émetteurs Fumee et Braises en rafale).
local function furnaceGate(parent: Instance, z: number, iron: Color3, basalt: Color3, ember: Color3, dark: Color3)
	local gate = Instance.new("Model")
	gate.Name, gate.Parent = "PorteBoss", parent
	gate:SetAttribute("Style", "Fournaise")
	local metal, rivet, rune = hex("#4A4A52"), hex("#8A8A90"), hex("#4E1C0C") -- rune : métal refroidi au repos
	local plate = Enum.Material.DiamondPlate
	local function folder(name: string): Folder
		local f = Instance.new("Folder")
		f.Name, f.Parent = name, gate
		return f
	end
	local function glow(p: BasePart, lit: string): BasePart
		p:SetAttribute("Lueur", true)
		p:SetAttribute("LueurAllumee", hex(lit))
		return p
	end
	-- intérieur de la fournaise (rouge sombre au repos, s'allume) et embrasure
	local inside = glow(piece(gate, "InterieurFournaise", Enum.PartType.Block, V(13, 13.6, 0.4), hex("#8A3414"), V(0, 6.8, z - 2.3), nil, Enum.Material.Neon), "#FF6A1A")
	light(inside, ember, 24, 0.6)
	for _, side in { -1, 1 } do
		piece(gate, "Embrasure", Enum.PartType.Block, V(0.8, 13.6, 2.4), dark, V(side * 6.9, 6.8, z - 1.2))
	end
	piece(gate, "VouteEmbrasure", Enum.PartType.Block, V(14.6, 0.8, 2.4), dark, V(0, 14, z - 1.2))
	glow(piece(gate, "LueurSeuil", Enum.PartType.Block, V(12, 0.3, 1.6), hex("#A0401A"), V(0, 0.15, z + 0.4), nil, Enum.Material.Neon), "#FF8A2A")
	-- arche : deux montants de métal riveté sur socle de basalte, linteau, couronne, sceau forgé
	for _, side in { -1, 1 } do
		piece(gate, "SocleMontant", Enum.PartType.Block, V(4.6, 2.4, 5.2), basalt, V(side * 8.2, 1.2, z))
		piece(gate, "Montant", Enum.PartType.Block, V(3.4, 14, 4.2), iron, V(side * 8.2, 9.4, z), nil, plate)
		for y = 4, 14, 2.5 do
			ball(gate, "Rivet", V(0.6, 0.6, 0.4), rivet, V(side * 8.2 + 1, y, z + 2.15), nil, Enum.Material.Metal)
			ball(gate, "Rivet", V(0.6, 0.6, 0.4), rivet, V(side * 8.2 - 1, y, z + 2.15), nil, Enum.Material.Metal)
		end
		glow(piece(gate, "Symbole", Enum.PartType.Block, V(0.4, 3.2, 0.2), rune, V(side * 8.2, 8, z + 2.2), nil, Enum.Material.Neon), "#FF8C2A")
		glow(piece(gate, "Symbole", Enum.PartType.Block, V(1.8, 0.4, 0.2), rune, V(side * 8.2, 9, z + 2.2), nil, Enum.Material.Neon), "#FF8C2A")
	end
	piece(gate, "Linteau", Enum.PartType.Block, V(20.4, 3.6, 4.6), iron, V(0, 15.6, z), nil, plate)
	piece(gate, "BandeLinteau", Enum.PartType.Block, V(20.6, 0.6, 4.8), metal, V(0, 14.2, z), nil, Enum.Material.Metal)
	ball(gate, "Couronne", V(20, 9, 3.6), basalt, V(0, 17.4, z - 0.6))
	for x = -9, 9, 3 do
		ball(gate, "Rivet", V(0.7, 0.7, 0.4), rivet, V(x, 16.6, z + 2.3), nil, Enum.Material.Metal)
	end
	glow(piece(gate, "Sceau", Enum.PartType.Cylinder, V(0.3, 3.4, 3.4), rune, V(0, 19, z + 1.2), rotY(math.pi / 2), Enum.Material.Neon), "#FF8C2A")
	piece(gate, "BagueSceau", Enum.PartType.Cylinder, V(0.25, 4.4, 4.4), metal, V(0, 19, z + 1.1), rotY(math.pi / 2), Enum.Material.Metal)
	-- deux battants de fer cerclé (s'ouvrent vers l'arène), symboles forgés au milieu
	local leaves = folder("Battants")
	for _, side in { -1, 1 } do
		local leaf = Instance.new("Model")
		leaf.Name, leaf.Parent = if side < 0 then "BattantGauche" else "BattantDroit", leaves
		leaf:SetAttribute("Sens", side) -- angle de rotation autour de la charnière (+ : vers l'arène pour le battant droit)
		local cx = side * 3.25
		piece(leaf, "Charniere", Enum.PartType.Block, V(0.9, 13.6, 1.1), metal, V(side * 6.5, 6.8, z + 0.1), nil, Enum.Material.Metal)
		piece(leaf, "Vantail", Enum.PartType.Block, V(6.4, 13.4, 0.8), metal, V(cx, 6.8, z), nil, plate)
		for _, y in { 2.4, 7, 11.6 } do
			piece(leaf, "Cerclage", Enum.PartType.Block, V(6.5, 0.8, 1), iron, V(cx, y, z), nil, Enum.Material.Metal)
			for k = -1, 1 do
				ball(leaf, "Rivet", V(0.5, 0.5, 0.4), rivet, V(cx + k * 2.2, y, z + 0.55), nil, Enum.Material.Metal)
			end
		end
		-- symbole forgé : losange gravé et son œil, petite marque en dessous (s'allument)
		for i = 0, 3 do
			local a = math.pi / 4 + i * math.pi / 2
			glow(piece(leaf, "Symbole", Enum.PartType.Block, V(2, 0.35, 0.2), rune, V(cx + math.cos(a) * 0.72, 9.3 + math.sin(a) * 0.72, z + 0.5),
				CFrame.Angles(0, 0, a + math.pi / 2), Enum.Material.Neon), "#FF8C2A")
		end
		glow(ball(leaf, "Symbole", V(0.6, 0.6, 0.2), rune, V(cx, 9.3, z + 0.5), nil, Enum.Material.Neon), "#FF8C2A")
		glow(piece(leaf, "Symbole", Enum.PartType.Block, V(1.6, 0.3, 0.2), rune, V(cx, 4.7, z + 0.5), nil, Enum.Material.Neon), "#FF8C2A")
		piece(leaf, "Anneau", Enum.PartType.Cylinder, V(0.3, 1.4, 1.4), rivet, V(cx - side * 2.2, 6.8, z + 0.6), rotY(math.pi / 2), Enum.Material.Metal)
	end
	-- chaînes à contrepoids devant les montants (elles se tendent : le contrepoids remonte)
	local chains = folder("Chaines")
	for _, side in { -1, 1 } do
		local chain = Instance.new("Model")
		chain.Name, chain.Parent = "Chaine", chains
		local x, cz = side * 8.2, z + 2.9
		piece(chain, "Poulie", Enum.PartType.Cylinder, V(0.8, 1.8, 1.8), metal, V(x, 15.4, cz), nil, Enum.Material.Metal)
		local k = 0
		for y = 14.6, 5.4, -0.8 do
			ball(chain, "Maillon", if k % 2 == 0 then V(0.35, 1, 0.6) else V(0.6, 1, 0.35), hex("#3A3A40"), V(x, y, cz), nil, Enum.Material.Metal)
			k += 1
		end
		piece(chain, "Contrepoids", Enum.PartType.Block, V(1.8, 2, 1.8), iron, V(x, 4.1, cz), nil, plate)
	end
	-- tuyaux de chaque côté : montée, coude, entrée dans le fourneau ; vapeur continue ; vanne
	for _, side in { -1, 1 } do
		local x = side * 10.9
		column(gate, "Tuyau", 13, 1.4, metal, V(x, 0, z + 0.5), Enum.Material.Metal)
		local elbow = ball(gate, "Coude", V(2, 2, 2), metal, V(x, 13, z + 0.5), nil, Enum.Material.Metal)
		piece(gate, "Tuyau", Enum.PartType.Cylinder, V(7, 1.4, 1.4), metal, V(x, 13, z - 3), rotY(math.pi / 2), Enum.Material.Metal)
		for _, y in { 3, 8 } do
			piece(gate, "Collier", Enum.PartType.Cylinder, V(0.4, 1.8, 1.8), iron, V(x, y, z + 0.5), FLAT, Enum.Material.Metal)
		end
		column(gate, "TuyauFin", 9, 0.9, iron, V(x + side * 1.1, 0, z - 1), Enum.Material.Metal)
		piece(gate, "Vanne", Enum.PartType.Cylinder, V(0.3, 1.8, 1.8), hex("#A0402A"), V(x + side * 1.1, 6, z - 0.3), rotY(math.pi / 2), Enum.Material.Metal)
		emitter(elbow, "Vapeur", "rbxasset://textures/particles/smoke_main.dds", hex("#E6E2DC"), 3, 4, 3, 2.5)
	end
	-- marteaux mécaniques : colonne, axe, bras levé et tête au-dessus d'une enclume (frappent à l'ouverture)
	local hammers = folder("Marteaux")
	for _, side in { -1, 1 } do
		local hammer = Instance.new("Model")
		hammer.Name, hammer.Parent = "Marteau", hammers
		local x, axisY = side * 13.6, 8
		piece(hammer, "SocleMarteau", Enum.PartType.Block, V(3, 1, 3), basalt, V(x, 0.5, z))
		column(hammer, "ColonneMarteau", 7.4, 1.2, iron, V(x, 0, z), Enum.Material.Metal)
		piece(hammer, "Axe", Enum.PartType.Block, V(2, 1.3, 1.3), metal, V(x, axisY, z), nil, Enum.Material.Metal)
		local arm = Instance.new("Model")
		arm.Name, arm.Parent = "Bras", hammer
		local raise = CFrame.Angles(-0.52, 0, 0)
		piece(arm, "Manche", Enum.PartType.Block, V(0.8, 0.8, 6.4), hex("#5A4232"), V(x, axisY, z) + raise:VectorToWorldSpace(V(0, 0, 3.2)), raise)
		piece(arm, "TeteMarteau", Enum.PartType.Block, V(3, 2.4, 2.4), iron, V(x, axisY, z) + raise:VectorToWorldSpace(V(0, 0, 6)), raise, plate)
		local anvil = V(x, 0, z + 5.8)
		piece(hammer, "PiedEnclume", Enum.PartType.Block, V(2.2, 4, 2.2), basalt, anvil + V(0, 2, 0))
		piece(hammer, "EnclumeMarteau", Enum.PartType.Block, V(3.4, 1.2, 2.2), iron, anvil + V(0, 4.6, 0), nil, plate)
	end
	-- foyer des effets d'ouverture (fumée et braises en rafale)
	local effects = folder("Effets")
	local hearth = piece(effects, "Foyer", Enum.PartType.Block, V(12, 1, 1.5), ember, V(0, 1, z - 0.5))
	hearth.Transparency = 1
	emitter(hearth, "Fumee", "rbxasset://textures/particles/smoke_main.dds", hex("#5A5450"), 0, 7, 6, 2.2)
	local sparks = emitter(hearth, "Braises", "rbxasset://textures/particles/sparkles_main.dds", hex("#FFA040"), 0, 0.6, 14, 1.4)
	sparks.LightEmission, sparks.SpreadAngle = 1, Vector2.new(50, 50)
	sparks.Acceleration = V(0, -8, 0)
	-- construite à l'échelle du boss (8,5 de haut), puis agrandie autour du pied de la porte : une arche immense
	local foot = PIVOT:PointToWorldSpace(Vector3.new(0, 0, z))
	gate.WorldPivot = CFrame.new(foot.X, GROUND_Y, foot.Z) * PIVOT.Rotation
	gate:ScaleTo(1.35)
	return gate
end

-- Citadelle-forge du fond (Zone 4) : couronne de hautes tours de basalte derrière le rempart (42 à 52 studs,
-- elle cache l'horizon et les plots voisins), meurtrières rougeoyantes, créneaux, bannières ; trois hautes
-- cheminées fumantes, un grand engrenage au-dessus de la porte, un creuset qui verse du métal en fusion.
-- Feu (Fire) posé sur une petite pièce invisible et droite : sur un cylindre couché (FLAT), il partirait de côté.
local function flame(parent: Instance, at: Vector3, size: number, heat: number, color: Color3)
	local carrier = piece(parent, "PorteFeu", Enum.PartType.Block, V(1, 1, 1), color, at)
	carrier.Transparency = 1
	local fire = Instance.new("Fire")
	fire.Size, fire.Heat, fire.Color, fire.SecondaryColor = size, heat, color, hex("#8A2A10")
	fire.Parent = carrier
end

local function forgeCitadel(f: Instance, C: { [string]: Color3 })
	local count = 11
	for i = 0, count - 1 do
		local a = 0.32 + (math.pi - 0.64) * i / (count - 1)
		local at = V(-66 * math.cos(a), 0, -20 - 63 * math.sin(a))
		local rot = rotY(-a + math.pi / 2)
		local inward = (V(0, 0, -20) - at).Unit
		local center = math.abs(at.X) < 16
		local h = if center then 52 else 42 + (i * 7 % 3) * 4
		piece(f, "TourCitadelle", Enum.PartType.Block, V(13, h, 9), if i % 2 == 0 then C.Basalt else C.BasaltLight, at + V(0, h / 2, 0), rot)
		for _, y in { h * 0.35, h * 0.7 } do
			piece(f, "CerclageCitadelle", Enum.PartType.Block, V(13.4, 1, 9.4), C.Iron, at + V(0, y, 0), rot, Enum.Material.DiamondPlate)
		end
		for k = -1, 1 do
			piece(f, "Creneau", Enum.PartType.Block, V(2.8, 3, 9.2), C.Basalt, at + rot:VectorToWorldSpace(V(k * 4.6, 0, 0)) + V(0, h + 1.5, 0), rot)
		end
		-- meurtrières rougeoyantes sur la face tournée vers l'arène
		for _, y in { h * 0.5, h * 0.82 } do
			for _, k in { -3, 3 } do
				local slit = piece(f, "Meurtriere", Enum.PartType.Block, V(1.3, 4.4, 0.3), C.Neon, at + inward * 4.6 + rot:VectorToWorldSpace(V(k, 0, 0)) + V(0, y, 0), rot,
					Enum.Material.Neon)
				if k > 0 and i % 2 == 0 and y > h * 0.6 then light(slit, C.Ember, 14, 0.8) end
			end
		end
		-- bannières de forge (tissu sombre, losange de braise)
		if i % 3 == 1 then
			local cloth = at + inward * 4.7 + V(0, h - 9, 0)
			piece(f, "Banniere", Enum.PartType.Block, V(5, 13, 0.3), C.Cloth, cloth, rot)
			piece(f, "BarreBanniere", Enum.PartType.Block, V(6.4, 0.5, 0.5), C.Iron, cloth + V(0, 6.7, 0) + inward * 0.2, rot, Enum.Material.Metal)
			piece(f, "EmblemeBanniere", Enum.PartType.Block, V(2.2, 2.2, 0.2), C.Neon, cloth + inward * 0.2 + V(0, 1.5, 0), rot * CFrame.Angles(0, 0, math.pi / 4),
				Enum.Material.Neon)
		end
	end
	-- trois hautes cheminées fumantes derrière la citadelle
	for _, s in { { -38, -79, 66, 8 }, { 38, -79, 66, 8 }, { 0, -90, 76, 10 } } do
		local at = V(s[1], 0, s[2])
		column(f, "HauteCheminee", s[3], s[4], C.Basalt, at)
		for y = 12, s[3] - 6, 14 do
			piece(f, "CerclageCheminee", Enum.PartType.Cylinder, V(1.2, s[4] + 0.8, s[4] + 0.8), C.Iron, at + V(0, y, 0), FLAT, Enum.Material.Metal)
		end
		local top = piece(f, "BoucheCheminee", Enum.PartType.Cylinder, V(0.4, s[4] - 1.4, s[4] - 1.4), C.Neon, at + V(0, s[3] + 0.1, 0), FLAT, Enum.Material.Neon)
		light(top, C.Ember, 30, 1.2)
		local smoke = emitter(top, "Fumee", "rbxasset://textures/particles/smoke_main.dds", hex("#2E2A28"), 5, 16, 7, 7)
		smoke.SpreadAngle = Vector2.new(12, 12)
		smoke.EmissionDirection = Enum.NormalId.Right -- cylindre couché (FLAT) : sa face Right regarde le ciel
		flame(f, at + V(0, s[3] + 1, 0), 12, 14, C.Ember)
	end
	-- grand engrenage au-dessus de la porte, et un plus petit engrené
	for _, g in { { 0, 41, -77, 18, 12 }, { 13.5, 51.5, -76.6, 10, 8 } } do
		local at, r = V(g[1], g[2], g[3]), g[4] / 2
		piece(f, "Engrenage", Enum.PartType.Cylinder, V(2, g[4], g[4]), C.Iron, at, rotY(math.pi / 2), Enum.Material.Metal)
		for t = 0, g[5] - 1 do
			local ang = t * 2 * math.pi / g[5]
			piece(f, "Dent", Enum.PartType.Block, V(2.2, 2.4, 2), C.Iron, at + V(math.cos(ang) * (r + 0.9), math.sin(ang) * (r + 0.9), 0),
				CFrame.Angles(0, 0, ang + math.pi / 2), Enum.Material.Metal)
		end
		for t = 0, 1 do
			piece(f, "Rayon", Enum.PartType.Block, V(g[4] - 2, 1.4, 2.3), C.BasaltLight, at, CFrame.Angles(0, 0, t * math.pi / 2), Enum.Material.Metal)
		end
		local hub = piece(f, "Moyeu", Enum.PartType.Cylinder, V(2.6, r * 0.6, r * 0.6), C.Neon, at, rotY(math.pi / 2), Enum.Material.Neon)
		light(hub, C.Ember, 16, 0.8)
	end
	-- creuset suspendu à une poutre ancrée dans la citadelle, qui verse du métal en fusion dans un moule
	local pot = V(17, 33, -66)
	piece(f, "PoutreCreuset", Enum.PartType.Block, V(1.8, 1.8, 13), C.Iron, V(pot.X, 41.6, -71.5), nil, Enum.Material.DiamondPlate)
	ball(f, "Creuset", V(7, 6, 7), C.Iron, pot, CFrame.Angles(0, 0, 0.55), Enum.Material.Metal)
	piece(f, "MetalCreuset", Enum.PartType.Cylinder, V(0.3, 5, 5), C.Neon, pot + V(-1.2, 2.2, 0), CFrame.Angles(0, 0, math.pi / 2 + 0.55), Enum.Material.Neon)
	for _, k in { -2.4, 2.4 } do
		for y = pot.Y + 3, 40.8, 1.6 do
			ball(f, "MaillonCreuset", V(0.5, 1.3, 0.8), C.Dark, V(pot.X + k, y, pot.Z), nil, Enum.Material.Metal)
		end
	end
	local stream = column(f, "Coulee", pot.Y - 3, 1.3, C.Neon, V(13.4, 3, -66), Enum.Material.Neon)
	light(stream, C.Ember, 18, 1)
	piece(f, "Moule", Enum.PartType.Block, V(5, 1, 4), C.Iron, V(13.4, 3.5, -66), nil, Enum.Material.DiamondPlate)
	piece(f, "MetalMoule", Enum.PartType.Block, V(4, 0.2, 3), C.Neon, V(13.4, 4.05, -66), nil, Enum.Material.Neon)
end

-- Poste de forge : foyer de basalte et ses braises (feu), hotte, enclume, soufflet, baquet de trempe.
local function forgeStation(f: Instance, at: Vector3, yaw: number, C: { [string]: Color3 })
	local r = rotY(yaw)
	local function p(v: Vector3): Vector3
		return at + r:VectorToWorldSpace(v)
	end
	piece(f, "Foyer", Enum.PartType.Block, V(5, 3, 4), C.Basalt, p(V(0, 1.5, 0)), r)
	local coals = piece(f, "BraisesFoyer", Enum.PartType.Block, V(4, 0.4, 3), C.Neon, p(V(0, 3.1, 0)), r, Enum.Material.Neon)
	light(coals, C.Ember, 12, 1)
	local fire = Instance.new("Fire")
	fire.Size, fire.Heat, fire.Color, fire.SecondaryColor = 4, 6, C.Ember, hex("#8A2A10")
	fire.Parent = coals
	piece(f, "HotteFoyer", Enum.PartType.Block, V(5.4, 1.6, 4.4), C.BasaltLight, p(V(0, 7.2, -0.3)), r)
	column(f, "TuyauHotte", 6, 1.4, C.Iron, p(V(0, 8, -0.6)), Enum.Material.Metal)
	for _, x in { -2.3, 2.3 } do
		piece(f, "PiedHotte", Enum.PartType.Block, V(0.6, 3.6, 0.6), C.Iron, p(V(x, 4.9, -1.8)), r, Enum.Material.Metal)
	end
	piece(f, "SocleEnclume", Enum.PartType.Block, V(2, 2, 2), C.Basalt, p(V(4.6, 1, 1.4)), r)
	piece(f, "Enclume", Enum.PartType.Block, V(3.6, 1.2, 1.6), C.Iron, p(V(4.6, 2.6, 1.4)), r, Enum.Material.DiamondPlate)
	piece(f, "Bigorne", Enum.PartType.Wedge, V(1.6, 1, 1.6), C.Iron, p(V(7, 2.6, 1.4)), r * rotY(-math.pi / 2), Enum.Material.DiamondPlate)
	ball(f, "Soufflet", V(2.6, 1.4, 3.6), C.Leather, p(V(-3.8, 1.2, 0.4)), r)
	piece(f, "BecSoufflet", Enum.PartType.Cylinder, V(1.6, 0.5, 0.5), C.Iron, p(V(-2.4, 1.5, 0.2)), r, Enum.Material.Metal)
	column(f, "Baquet", 1.8, 2.8, C.Wood, p(V(-1.4, 0, 3.4)))
	piece(f, "EauBaquet", Enum.PartType.Cylinder, V(0.2, 2.3, 2.3), hex("#3E5A6E"), p(V(-1.4, 1.8, 3.4)), FLAT)
	piece(f, "Pince", Enum.PartType.Block, V(0.3, 3, 0.3), C.Iron, p(V(-1, 2.6, 3.6)), r * CFrame.Angles(0.3, 0, 0.2), Enum.Material.Metal)
end

-- Râtelier d'armes forgées (épées et haches), adossé au rempart.
local function weaponRack(f: Instance, at: Vector3, yaw: number, C: { [string]: Color3 })
	local r = rotY(yaw)
	local function p(v: Vector3): Vector3
		return at + r:VectorToWorldSpace(v)
	end
	for _, x in { -3.4, 3.4 } do
		piece(f, "MontantRatelier", Enum.PartType.Block, V(0.6, 5, 0.6), C.Wood, p(V(x, 2.5, 0)), r)
	end
	piece(f, "BarreRatelier", Enum.PartType.Block, V(7.6, 0.5, 0.6), C.Wood, p(V(0, 4.6, 0)), r)
	piece(f, "BasRatelier", Enum.PartType.Block, V(7.6, 0.5, 1.4), C.Wood, p(V(0, 0.5, 0.4)), r)
	for k = -2, 2 do
		local x = k * 1.3
		if k % 2 == 0 then
			piece(f, "Lame", Enum.PartType.Block, V(0.5, 4, 0.15), C.Steel, p(V(x, 3, 0.5)), r * CFrame.Angles(-0.12, 0, 0), Enum.Material.Metal)
			piece(f, "Garde", Enum.PartType.Block, V(1.4, 0.25, 0.3), C.Gold, p(V(x, 5.1, 0.25)), r * CFrame.Angles(-0.12, 0, 0), Enum.Material.Metal)
		else
			piece(f, "Manche", Enum.PartType.Block, V(0.3, 4.6, 0.3), C.Wood, p(V(x, 2.8, 0.5)), r * CFrame.Angles(-0.12, 0, 0))
			piece(f, "Hache", Enum.PartType.Block, V(0.2, 1.4, 1.2), C.Steel, p(V(x, 4.6, 0.9)), r * CFrame.Angles(-0.12, 0, 0), Enum.Material.Metal)
		end
	end
end

-- Tonneaux et caisses de minerai empilés.
local function supplies(f: Instance, at: Vector3, yaw: number, C: { [string]: Color3 })
	local r = rotY(yaw)
	for _, o in { V(0, 0, 0), V(2.6, 0, 0.4), V(1.3, 2.4, 0.2) } do
		column(f, "Tonneau", 2.4, 2.2, C.Wood, at + r:VectorToWorldSpace(o))
		piece(f, "CerclageTonneau", Enum.PartType.Cylinder, V(0.3, 2.4, 2.4), C.Iron, at + r:VectorToWorldSpace(o + V(0, 1.6, 0)), FLAT, Enum.Material.Metal)
	end
	for i, o in { V(-3.4, 1.1, 0.6), V(-3.2, 3.3, 0.4), V(-5.6, 1.1, -0.6) } do
		piece(f, "Caisse", Enum.PartType.Block, V(2.2, 2.2, 2.2), C.WoodLight, at + r:VectorToWorldSpace(o), r * rotY(i * 0.3))
	end
	ball(f, "MineraiCaisse", V(1.8, 0.8, 1.8), hex("#5A3A2A"), at + r:VectorToWorldSpace(V(-3.2, 4.6, 0.4)))
end

-- Tas de minerai brut où luisent des éclats de braise.
local function orePile(f: Instance, at: Vector3, C: { [string]: Color3 })
	ball(f, "TasMinerai", V(7, 3, 6), hex("#4A3428"), at + V(0, 0.6, 0))
	ball(f, "TasMinerai", V(4, 2.4, 4), hex("#5A3A2A"), at + V(2, 1.6, 1))
	for i, o in { V(-1.5, 2, 0.8), V(1.2, 2.8, -0.6), V(2.6, 2.6, 1.8), V(-0.4, 1.6, -2) } do
		local shard = piece(f, "Eclat", Enum.PartType.Block, V(0.6, 1.4, 0.6), C.Neon, at + o, CFrame.Angles(0.4 * i, i, 0.3), Enum.Material.Neon)
		if i == 1 then light(shard, C.Ember, 8, 0.6) end
	end
end

-- Fissure de lave dans le sol : segments lumineux en zigzag, juste au-dessus du sol de zone.
local function lavaCrack(f: Instance, at: Vector3, yaw: number, C: { [string]: Color3 })
	local pos, dir = at, yaw
	for i = 1, 5 do
		local len = 3 + (i % 2) * 1.6
		local step = rotY(dir):VectorToWorldSpace(V(0, 0, len))
		local crack = piece(f, "FissureLave", Enum.PartType.Block, V(0.5, 0.12, len + 0.4), C.Neon, pos + step / 2 + V(0, GROUND_TOP - GROUND_Y + 0.07, 0), rotY(dir),
			Enum.Material.Neon)
		if i == 3 then light(crack, C.Ember, 8, 0.4) end
		pos += step
		dir += if i % 2 == 0 then 0.7 else -0.7
	end
end

-- Orgues basaltiques : faisceau de colonnes serrées sur deux rangs, plus hautes au centre, tons de basalte
-- chauds variés, sur un pied d'éboulis. Le long de la tangente `yaw` (adossé au rempart).
local function basaltColumns(f: Instance, at: Vector3, yaw: number, count: number, hmax: number, C: { [string]: Color3 })
	local r = rotY(yaw)
	local tones = { C.Rock, C.RockDark, C.RockLight }
	for i = 0, count - 1 do
		local u = (i - (count - 1) / 2) * 2.1
		local row = i % 2
		local profile = 1 - math.abs(u) / (count * 1.25)
		local h = hmax * (0.35 + 0.65 * profile) * (0.8 + ((i * 7) % 5) * 0.06) * (if row == 1 then 0.8 else 1)
		local d = 2.3 + ((i * 5) % 3) * 0.35
		local foot = at + r:VectorToWorldSpace(V(u, 0, row * 1.9 - 0.6))
		column(f, "OrgueBasalte", h, d, tones[(i * 2) % 3 + 1], foot)
		piece(f, "DessusOrgue", Enum.PartType.Cylinder, V(0.3, d + 0.1, d + 0.1), tones[(i * 2 + 2) % 3 + 1], foot + V(0, h + 0.1, 0),
			FLAT * CFrame.Angles(((i % 3) - 1) * 0.12, 0, 0))
	end
	for k = -1, 1 do
		ball(f, "EboulisOrgue", V(4.4, 1.8, 3.4), C.RockDark, at + r:VectorToWorldSpace(V(k * count * 0.8, 0.4, 2.6)), r * rotY(k))
	end
end

-- Roche : masses arrondies superposées et inclinées (formes gonflées de la DA), tons de basalte chauds,
-- une arête plus claire au sommet.
local function boulder(f: Instance, at: Vector3, size: number, k: number, C: { [string]: Color3 })
	local r = rotY(k * 1.7)
	ball(f, "Roche", V(3.4, 2.2, 2.8) * size, if k % 2 == 0 then C.Rock else C.RockDark, at + V(0, 0.7 * size, 0), r * CFrame.Angles(0.12, 0, 0.18))
	ball(f, "Roche", V(2.2, 1.7, 2) * size, C.RockDark, at + r:VectorToWorldSpace(V(1.5, 0.5, 0.7) * size), r * CFrame.Angles(-0.2, 0.6, 0.3))
	ball(f, "Roche", V(1.8, 1.1, 1.5) * size, C.RockLight, at + r:VectorToWorldSpace(V(-0.4, 1.55, -0.2) * size), r * CFrame.Angles(0.25, 0.3, -0.2))
end

-- Courant de lave : lit lumineux en segments (joints arrondis aux coudes), croûtes sombres qui flottent,
-- berges de blocs de basalte, braises qui montent. `points` : du haut (sous une cascade) vers l'aval.
local function lavaRiver(f: Instance, points: { Vector3 }, width: number, C: { [string]: Color3 })
	local y = GROUND_TOP - GROUND_Y + 0.12
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local d = b - a
		local len = d.Magnitude
		local yaw = math.atan2(d.X, d.Z)
		local r = rotY(yaw)
		local bed = piece(f, "CoulantLave", Enum.PartType.Block, V(width, 0.25, len + 0.6), C.Neon, (a + b) / 2 + V(0, y, 0), r, Enum.Material.Neon)
		if i % 2 == 1 then
			light(bed, C.Ember, 18, 0.9)
			local sparks = emitter(bed, "Braises", "rbxasset://textures/particles/sparkles_main.dds", hex("#FF8C2A"), 2, 0.5, 4, 1.6)
			sparks.LightEmission = 1
		end
		if i > 1 then
			piece(f, "CoudeLave", Enum.PartType.Cylinder, V(0.25, width, width), C.Neon, a + V(0, y, 0), FLAT, Enum.Material.Neon)
		end
		-- croûtes sombres sur la lave
		for k = 1, math.floor(len / 5) do
			local t = (k - 0.5) / math.floor(len / 5)
			ball(f, "CrouteLave", V(1.6, 0.25, 1.1), C.Crust, a:Lerp(b, t) + r:VectorToWorldSpace(V(((k + i) % 3 - 1) * width * 0.25, y + 0.14, 0)), r * rotY(k))
		end
		-- berges : blocs de basalte des deux côtés
		local steps = math.max(1, math.floor(len / 3.6))
		for k = 0, steps - 1 do
			local t = (k + 0.5) / steps
			for _, side in { -1, 1 } do
				local at = a:Lerp(b, t) + r:VectorToWorldSpace(V(side * (width / 2 + 0.9), 0, 0))
				boulder(f, at, 0.55 + ((k + i + side) % 3) * 0.15, (k * 3 + i) % 5, C)
			end
		end
	end
end

-- Haut-fourneau (Zone 4, flanc est) : tour de basalte cerclée de fer en trois étages (24 studs) sur socle,
-- meurtrières rougeoyantes, bannière, trou de coulée tourné vers l'arène qui verse dans une rigole ;
-- plateforme crénelée, cheminée qui fume et brûle (30 studs) ; potence de chargement et son seau de minerai.
local function blastFurnace(f: Instance, at: Vector3, C: { [string]: Color3 })
	local front = V(-1, 0, 0) -- vers l'arène
	local faceFront = rotY(math.atan2(front.X, front.Z))
	piece(f, "SocleHautFourneau", Enum.PartType.Block, V(12, 3, 12), C.Basalt, at + V(0, 1.5, 0))
	piece(f, "CerclageSocle", Enum.PartType.Block, V(12.4, 0.6, 12.4), C.Iron, at + V(0, 2.6, 0), nil, Enum.Material.DiamondPlate)
	for _, c in { V(-5.2, 0, -5.2), V(5.2, 0, -5.2), V(-5.2, 0, 5.2), V(5.2, 0, 5.2) } do
		piece(f, "PilierSocle", Enum.PartType.Block, V(2.4, 5, 2.4), C.BasaltLight, at + c + V(0, 2.5, 0))
	end
	local y = 3
	for i, s in { { 9.4, 8 }, { 8.2, 7 }, { 6.8, 6 } } do
		column(f, "CorpsHautFourneau", s[2], s[1], if i % 2 == 1 then C.Rock else C.RockDark, at + V(0, y, 0))
		piece(f, "CerclageHautFourneau", Enum.PartType.Cylinder, V(0.9, s[1] + 0.5, s[1] + 0.5), C.Iron, at + V(0, y + s[2] - 0.4, 0), FLAT, Enum.Material.Metal)
		y += s[2]
	end
	-- meurtrières en diagonale (étage du milieu), bannière sur la face avant
	for k = 0, 3 do
		local a = math.pi / 4 + k * math.pi / 2
		local dir = V(math.cos(a), 0, math.sin(a))
		local slit = piece(f, "MeurtriereFourneau", Enum.PartType.Block, V(1.1, 3.4, 0.3), C.Neon, at + dir * 4.05 + V(0, 14.5, 0),
			rotY(math.atan2(dir.X, dir.Z)), Enum.Material.Neon)
		if k == 1 then light(slit, C.Ember, 12, 0.7) end
	end
	piece(f, "BanniereFourneau", Enum.PartType.Block, V(3.4, 6.4, 0.25), C.Cloth, at + front * 4.2 + V(0, 14, 0), faceFront)
	piece(f, "EmblemeFourneau", Enum.PartType.Block, V(1.5, 1.5, 0.2), C.Neon, at + front * 4.35 + V(0, 14.8, 0), faceFront * CFrame.Angles(0, 0, math.pi / 4),
		Enum.Material.Neon)
	-- trou de coulée : bouche rougeoyante, bec de fer, filet de métal en fusion, rigole au sol
	piece(f, "ArcCoulee", Enum.PartType.Block, V(3.6, 3.4, 0.6), C.Dark, at + front * 4.75 + V(0, 4.9, 0), faceFront)
	local hole = piece(f, "TrouCoulee", Enum.PartType.Block, V(2.6, 2.4, 0.3), C.Neon, at + front * 5.1 + V(0, 4.7, 0), faceFront, Enum.Material.Neon)
	light(hole, C.Ember, 16, 1.2)
	piece(f, "BecCoulee", Enum.PartType.Block, V(1.4, 0.5, 2.6), C.Iron, at + front * 6.2 + V(0, 3.7, 0), faceFront * CFrame.Angles(0.25, 0, 0), Enum.Material.Metal)
	column(f, "FiletCoulee", 3.2, 0.6, C.Neon, at + front * 7.4 + V(0, 0.3, 0), Enum.Material.Neon)
	piece(f, "RigoleCoulee", Enum.PartType.Block, V(2.4, 0.7, 6), C.Iron, at + front * 8 + V(0, 0.35, 1.4), nil, Enum.Material.DiamondPlate)
	piece(f, "MetalRigole", Enum.PartType.Block, V(1.6, 0.2, 5.4), C.Neon, at + front * 8 + V(0, 0.75, 1.4), nil, Enum.Material.Neon)
	-- plateforme crénelée du gueulard, cheminée qui fume et brûle
	piece(f, "PlateformeGueulard", Enum.PartType.Cylinder, V(0.8, 10.4, 10.4), C.Iron, at + V(0, y + 0.4, 0), FLAT, Enum.Material.DiamondPlate)
	for k = 0, 7 do
		local a = k * math.pi / 4
		local dir = V(math.cos(a), 0, math.sin(a))
		piece(f, "CreneauGueulard", Enum.PartType.Block, V(1.8, 1.6, 0.8), C.Basalt, at + dir * 4.8 + V(0, y + 1.6, 0), rotY(math.atan2(dir.X, dir.Z)))
	end
	local chimneyTop = y + 0.8 + 6
	column(f, "ChemineeGueulard", 6, 3, C.Basalt, at + V(1, y + 0.8, 1))
	local mouth = piece(f, "BoucheGueulard", Enum.PartType.Cylinder, V(0.3, 2.4, 2.4), C.Neon, at + V(1, chimneyTop + 0.05, 1), FLAT, Enum.Material.Neon)
	light(mouth, C.Ember, 20, 1)
	local smoke = emitter(mouth, "Fumee", "rbxasset://textures/particles/smoke_main.dds", hex("#2E2A28"), 4, 9, 6, 5)
	smoke.EmissionDirection = Enum.NormalId.Right
	flame(f, at + V(1, chimneyTop + 0.8, 1), 6, 9, C.Ember)
	-- potence de chargement vers l'arène, chaîne et seau de minerai
	local armY = y + 3.2
	column(f, "MatPotence", 3.6, 0.7, C.Wood, at + front * 3.4 + V(0, y + 0.8, -2.6))
	piece(f, "BrasPotence", Enum.PartType.Block, V(7.6, 0.7, 0.7), C.Wood, at + front * 6.6 + V(0, armY + 0.6, -2.6))
	piece(f, "JambePotence", Enum.PartType.Block, V(0.5, 4.2, 0.5), C.Wood, at + front * 5 + V(0, armY - 1, -2.6), CFrame.Angles(0, 0, -0.8))
	local hookX = at + front * 9.8 + V(0, 0, -2.6)
	for cy = armY, armY - 7, -1.1 do
		ball(f, "MaillonPotence", V(0.4, 1, 0.6), C.Dark, hookX + V(0, cy, 0), nil, Enum.Material.Metal)
	end
	column(f, "SeauMinerai", 2, 2.6, C.Iron, hookX + V(0, armY - 9.6, 0), Enum.Material.Metal)
	ball(f, "MineraiSeau", V(2.2, 1, 2.2), hex("#5A3A2A"), hookX + V(0, armY - 7.5, 0))
end

-- Limite légère entre l'arène et l'avant du plot (portique, royaume) : muret bas de basalte, poteaux de fer
-- reliés par des chaînes pendantes, braseros, roches ; un passage au centre (|x| < 10), en face du portique,
-- encadré de deux piliers à brasero et bannière. Purement visuel (aucune collision).
local function frontBoundary(f: Instance, z: number, C: { [string]: Color3 })
	local function zAt(x: number): number
		return z - (math.abs(x) / 50) ^ 2 * 5 -- légère courbe vers l'arène aux extrémités
	end
	for _, side in { -1, 1 } do
		local posts = {}
		for x = 11, 50, 6.5 do
			table.insert(posts, V(side * x, 0, zAt(x)))
		end
		for i = 1, #posts - 1 do
			local a, b = posts[i], posts[i + 1]
			local d = b - a
			local r = rotY(math.atan2(d.X, d.Z))
			local mid = (a + b) / 2
			piece(f, "MuretLimite", Enum.PartType.Block, V(1.6, 1.2 + (i % 2) * 0.3, d.Magnitude + 0.3), if i % 2 == 0 then C.Basalt else C.BasaltLight, mid + V(0, 0.6, 0), r)
			piece(f, "ChaperonMuret", Enum.PartType.Block, V(1.8, 0.3, d.Magnitude + 0.3), C.Iron, mid + V(0, 1.35 + (i % 2) * 0.3, 0), r, Enum.Material.DiamondPlate)
			-- chaîne pendante entre deux poteaux
			for k = 1, 6 do
				local t = k / 7
				local sag = 4 * t * (1 - t) * 0.9
				ball(f, "ChaineLimite", if k % 2 == 0 then V(0.3, 0.6, 0.8) else V(0.6, 0.6, 0.3), C.Dark, a:Lerp(b, t) + V(0, 3.4 - sag, 0), r, Enum.Material.Metal)
			end
		end
		for i, p in posts do
			if i == 1 then
				-- pilier du passage : brasero et bannière tournée vers le portique
				piece(f, "PilierPassage", Enum.PartType.Block, V(2.6, 6, 2.6), C.BasaltLight, p + V(0, 3, 0))
				piece(f, "CerclagePilier", Enum.PartType.Block, V(2.9, 0.5, 2.9), C.Iron, p + V(0, 4.6, 0), nil, Enum.Material.DiamondPlate)
				piece(f, "BraseroPassage", Enum.PartType.Cylinder, V(1.2, 3, 3), C.Iron, p + V(0, 6.6, 0), FLAT, Enum.Material.Metal)
				local coals = piece(f, "BraisesPassage", Enum.PartType.Cylinder, V(0.3, 2.4, 2.4), C.Neon, p + V(0, 7.25, 0), FLAT, Enum.Material.Neon)
				light(coals, C.Ember, 16, 1)
				flame(f, p + V(0, 7.8, 0), 4, 7, C.Ember)
				piece(f, "BannierePassage", Enum.PartType.Block, V(2.2, 4.4, 0.2), C.Cloth, p + V(0, 2.8, 1.4))
				piece(f, "EmblemePassage", Enum.PartType.Block, V(1, 1, 0.2), C.Neon, p + V(0, 3.4, 1.55), CFrame.Angles(0, 0, math.pi / 4), Enum.Material.Neon)
			elseif i % 3 == 1 then
				-- petit brasero sur socle
				piece(f, "SocleBrasero", Enum.PartType.Block, V(1.8, 2.6, 1.8), C.Basalt, p + V(0, 1.3, 0))
				piece(f, "BraseroLimite", Enum.PartType.Cylinder, V(0.9, 2.2, 2.2), C.Iron, p + V(0, 3, 0), FLAT, Enum.Material.Metal)
				local coals = piece(f, "BraisesLimite", Enum.PartType.Cylinder, V(0.2, 1.8, 1.8), C.Neon, p + V(0, 3.5, 0), FLAT, Enum.Material.Neon)
				light(coals, C.Ember, 12, 0.8)
				flame(f, p + V(0, 3.9, 0), 2.5, 5, C.Ember)
			else
				column(f, "PoteauLimite", 3.6, 0.6, C.Iron, p, Enum.Material.Metal)
				ball(f, "TetePoteau", V(0.9, 0.9, 0.9), C.Neon, p + V(0, 3.7, 0), nil, Enum.Material.Neon)
			end
		end
		-- quelques roches le long de la limite, côté arène
		for k, x in { 22, 36, 47 } do
			boulder(f, V(side * x, 0, zAt(x) - 2.4), 0.8 + (k % 2) * 0.3, k + (if side > 0 then 2 else 0), C)
		end
	end
end

BUILD[4] = function(m: Instance)
	-- repères dans l'embrasure : le boss part de l'intérieur de la fournaise, la porte s'ouvre devant lui ;
	-- saut depuis le dessus du linteau (porte agrandie de 1,35)
	moveMarkers(m, -55.5, V(0, 23.6, -54))
	-- plus de lac (cercles de lave de la Zone 1) : un courant de lave le remplace ; ses repères de saut
	-- (SautMare) passent sur le courant
	local lake = m:FindFirstChild("Lac")
	if lake then lake:Destroy() end
	local sources = m:FindFirstChild("SourcesEnnemis")
	for name, pos in { MareFond = V(-36, 0, -44), MareMilieu = V(-35, 0, -16), MareGrande = V(-41, 0, 2) } do
		local marker = sources and sources:FindFirstChild(name)
		if marker and marker:IsA("BasePart") then
			local world = PIVOT:PointToWorldSpace(Vector3.new(pos.X, 0, pos.Z))
			marker.CFrame = CFrame.new(world.X, GROUND_Y, world.Z) * PIVOT.Rotation
		end
	end
	local basalt, basaltLight, iron, ember, dark = hex("#3A3432"), hex("#5A524C"), hex("#6E6E72"), hex("#F08C3C"), hex("#1C1614")
	-- Neon : teinte plus sombre que la lumière (le Neon s'éclaircit au rendu ; #F08C3C ressortait jaune)
	local C = {
		Basalt = basalt, BasaltLight = basaltLight, BasaltDark = hex("#2C2826"), Rock = hex("#5A4E48"), RockDark = hex("#453C38"), RockLight = hex("#76685E"), Crust = hex("#4A2418"), Iron = iron, Ember = ember, Dark = dark, Neon = hex("#D2501E"),
		Cloth = hex("#6A1E16"), Leather = hex("#6E4A32"), Wood = hex("#5E4232"), WoodLight = hex("#7A5A3E"), Steel = hex("#A8ACB4"), Gold = hex("#D2A04A"),
	}
	local f = Instance.new("Folder")
	f.Name, f.Parent = "Forges", m
	-- rempart de basalte cerclé de fer, de plus en plus haut vers le fond (14 à l'entrée, 34 au fond) ;
	-- contreforts à brasero sur les flancs
	for i, p in enclosure(8) do
		local t = math.clamp((18 - p.at.Z) / 92, 0, 1)
		local h = 14 + t * 20 + (i % 2) * 2
		local rot = rotY(p.yaw)
		piece(f, "MurBasalte", Enum.PartType.Block, V(8.4, h, 3.6), if i % 2 == 0 then basalt else basaltLight, p.at + V(0, h / 2, 0), rot)
		for _, y in { h * 0.3, h * 0.75 } do
			piece(f, "Cerclage", Enum.PartType.Block, V(8.6, 0.7, 3.9), iron, p.at + V(0, y, 0), rot, Enum.Material.DiamondPlate)
		end
		if i % 3 == 0 then
			local foot = p.at + ((V(0, 0, -20) - p.at) * V(1, 0, 1)).Unit * 2.6
			piece(f, "Contrefort", Enum.PartType.Block, V(3.4, h + 3, 3), basaltLight, foot + V(0, (h + 3) / 2, 0), rot)
			piece(f, "Brasero", Enum.PartType.Cylinder, V(1.4, 3.4, 3.4), iron, foot + V(0, h + 3.7, 0), FLAT, Enum.Material.Metal)
			local coals = piece(f, "BraisesBrasero", Enum.PartType.Cylinder, V(0.3, 2.8, 2.8), C.Neon, foot + V(0, h + 4.45, 0), FLAT, Enum.Material.Neon)
			light(coals, ember, 16, 1)
			flame(f, foot + V(0, h + 5, 0), 5, 8, ember)
		end
	end
	forgeCitadel(f, C)
	-- grand fourneau au fond : dôme, deux cheminées ; la Porte-Fournaise est encastrée devant
	ball(f, "Fourneau", V(26, 20, 18), basaltLight, V(0, 6, -66))
	piece(f, "Socle", Enum.PartType.Block, V(28, 3, 16), basalt, V(0, 1.5, -64))
	furnaceGate(f, -54, iron, basalt, ember, dark)
	for _, side in { -1, 1 } do
		column(f, "GrandeCheminee", 26, 4, basalt, V(side * 9, 0, -70))
		local b = piece(f, "BraiseCheminee", Enum.PartType.Cylinder, V(0.3, 3, 3), C.Neon, V(side * 9, 26.2, -70), FLAT, Enum.Material.Neon)
		light(b, ember, 10, 0.8)
		-- cascades de lave sur le rempart du fond, et leur bassin
		local h = 14 + math.clamp((18 + 68.3) / 92, 0, 1) * 20
		local fall = piece(f, "CascadeLave", Enum.PartType.Block, V(5, h, 0.6), C.Neon, V(side * 25.4, h / 2, -66.2), rotY(-side * 0.464), Enum.Material.Neon)
		light(fall, ember, 22, 1.2)
	end
	-- courants de lave : à l'ouest, de la cascade le long du flanc jusque sous le rempart ; à l'est, court,
	-- de la cascade vers l'angle du rempart
	lavaRiver(f, { V(-25, 0, -64.5), V(-31, 0, -56), V(-36, 0, -44), V(-38, 0, -30), V(-35, 0, -16), V(-38, 0, -2), V(-44, 0, 6),
		V(-51, 0, 10), V(-60, 0, 12) }, 4.6, C)
	lavaRiver(f, { V(25, 0, -64.5), V(32, 0, -61), V(40, 0, -63), V(48, 0, -66), V(56, 0, -68) }, 4, C)
	-- orgues basaltiques adossées au rempart des flancs, blocs de roche épars
	for _, o in { { -54.5, -26, 8, 15 }, { 54.5, -22, 8, 16 }, { -41, -53, 7, 17 } } do
		basaltColumns(f, V(o[1], 0, o[2]), if o[1] > 50 then -math.pi / 2 elseif o[1] < -50 then math.pi / 2 else 0.8, o[3], o[4], C)
	end
	for i, b in { { -46, 14 }, { -30, 24 }, { 30, 26 }, { 40, -28 }, { 50, -46 }, { -28, -40 }, { 36, 6 }, { -44, 30 } } do
		boulder(f, V(b[1], 0, b[2]), 1.2 + (i % 3) * 0.35, i, C)
	end
	-- rigoles de métal en fusion vers l'allée
	for _, x in { -11, 11 } do
		local g = piece(f, "Rigole", Enum.PartType.Block, V(1.6, 0.25, 42), C.Neon, V(x, 0.15, -36), nil, Enum.Material.Neon)
		light(g, ember, 8, 0.4)
		for _, side in { -1, 1 } do
			piece(f, "BordRigole", Enum.PartType.Block, V(0.6, 0.6, 42), iron, V(x + side * 1.1, 0.3, -36), nil, Enum.Material.DiamondPlate)
		end
	end
	-- ateliers des flancs (hors de la zone de bataille et du lac à l'ouest) : postes de forge, râteliers,
	-- réserves, minerai, fissures de lave
	forgeStation(f, V(44, 0, -14), -math.pi / 2, C)
	forgeStation(f, V(46, 0, 12), -math.pi / 2 - 0.3, C)
	forgeStation(f, V(-48, 0, -16), math.pi / 2, C)
	weaponRack(f, V(51, 0, -32), -math.pi / 2 - 0.35, C)
	weaponRack(f, V(-49, 0, -40), math.pi / 2 + 0.45, C)
	weaponRack(f, V(-51, 0, -4), math.pi / 2, C)
	supplies(f, V(46, 0, 26), -0.4, C)
	supplies(f, V(-44, 0, 26), 0.5, C)
	-- petite structure haute du flanc est, entre les deux postes de forge
	blastFurnace(f, V(48, 0, 1), C)
	-- limite légère avec l'avant du plot (portique, royaume)
	frontBoundary(f, 47, C)
	orePile(f, V(44, 0, -42), C)
	orePile(f, V(-47, 0, -27), C)
	for _, c in { { 34, 4, 0.4 }, { 30, -30, 2.2 }, { 36, 20, 2.8 } } do
		lavaCrack(f, V(c[1], 0, c[2]), c[3], C)
	end
	-- coin de l'ancien plateau : enclume géante, tas de charbon fumant, lingots
	piece(f, "SocleGrandeEnclume", Enum.PartType.Block, V(5, 3, 4), basalt, V(26, 1.5, -44))
	ball(f, "GrandeEnclume", V(9, 2.6, 3.6), iron, V(26, 4.2, -44), nil, Enum.Material.DiamondPlate)
	ball(f, "Marteau", V(1, 5, 1), hex("#5A4232"), V(29, 6.4, -43), CFrame.Angles(0, 0, 0.9))
	ball(f, "TeteMarteau", V(2.6, 1.6, 1.6), iron, V(31, 7.6, -43), nil, Enum.Material.DiamondPlate)
	ball(f, "TasCharbon", V(10, 4, 8), hex("#2A2422"), V(38, 0.6, -52))
	for i, e in { { 36, 2.4, -51 }, { 40, 2.8, -53 }, { 38, 3.4, -52 } } do
		local braise = ball(f, "Braise", V(1.2, 0.8, 1.2), C.Neon, V(e[1], e[2], e[3]), rotY(i), Enum.Material.Neon)
		if i == 2 then light(braise, ember, 10, 0.6) end
	end
	for k = 0, 4 do
		piece(f, "Lingot", Enum.PartType.Block, V(1.8, 0.7, 0.9), C.Gold, V(34 + (k % 2) * 1.2, 0.35 + math.floor(k / 2) * 0.7, -38), rotY(k * 0.25),
			Enum.Material.Metal)
	end
	battleground(f, hex("#8A7462"), hex("#6E5A4C"), -42)
	for _, at in { V(21, 0, -24), V(-19, 0, -24), V(-23, 0, 3) } do
		piece(f, "Chariot", Enum.PartType.Block, V(4.4, 2.4, 3), iron, at + V(-1.2, 1.6, -2.6), rotY(0.3), Enum.Material.DiamondPlate)
		ball(f, "Minerai", V(3.6, 2, 2.6), hex("#5A3A2A"), at + V(-1.2, 3, -2.6))
		ball(f, "Scories", V(5, 1.4, 3.6), basalt, at + V(1.8, 0.2, -1.8))
	end
end

---------------------------------------------------------------- Zone 5 : la Cité Engloutie
-- Une cité sous une bulle magique au fond de l'océan : on y marche normalement, et l'océan est visible tout
-- autour, derrière la barrière, sans jamais sortir de la délimitation du plot. Animé par DecorVivantController (tags) ; la protection se fissure au fil des
-- stages (attributs StageMin / StageMax) ; au stage 5, salle circulaire du boss et baie vitrée avec l'œil.
local CS = game:GetService("CollectionService")
local function tag(instance: Instance, name: string, attributes: { [string]: any }?): Instance
	CS:AddTag(instance, name)
	for key, value in attributes or {} do
		instance:SetAttribute(key, value)
	end
	return instance
end
local function group(parent: Instance, name: string, stageMin: number?, stageMax: number?): Model
	local g = Instance.new("Model")
	g.Name = name
	if stageMin then g:SetAttribute("StageMin", stageMin) end
	if stageMax then g:SetAttribute("StageMax", stageMax) end
	g.Parent = parent
	return g
end

BUILD[5] = function(m: Instance)
	local white, stoneBlue, deepBlue, gold = hex("#E8EEF2"), hex("#7CA6C8"), hex("#2E5A86"), hex("#E6C27A")
	local coralA, coralB, coralC = hex("#E07A64"), hex("#F0A07C"), hex("#C8648C")
	local barrierC, ocean, oceanFloor, glow = hex("#64C8E6"), hex("#0E2A4A"), hex("#1E3A4E"), hex("#7CF0F0")
	local f = Instance.new("Folder")
	f.Name, f.Parent = "CiteEngloutie", m

	-- le boss sort du temple en forme de coquille, au fond (repères SourcesEnnemis déplacés dessus)
	moveMarkers(m, -53, V(0, 24.5, -55))
	-- zone de bataille : rue ancienne de sable du fond, bordée de coraux
	battleground(f, hex("#B4A584"), hex("#9C8E70"), -43)
	local streets = group(f, "Rues")
	for _, x in { -24, 24 } do
		for z = -46, 22, 8 do
			local c = Instance.new("Model")
			c.Name, c.Parent = "CorailRue", streets
			coral(c, V(x, 0, z + (x > 0 and 3 or 0)), if z % 16 == 0 then coralA else coralC, 0.7)
			c.WorldPivot = PIVOT * CFrame.new(x, GROUND_Y - PIVOT.Position.Y, z)
			tag(c, "CorailOndule", { Amplitude = 5, Periode = 3 + (z % 3) })
		end
	end

	-- Tout reste dans la délimitation du plot (bordure : x ±59 sur les flancs, fond arrondi jusqu'à z -78) :
	-- barrière en U un peu en retrait (rayons 52 × 50), océan dans la bande entre la barrière et la bordure,
	-- mur d'eau profonde posé sur la bordure (rayons 57 × 55).
	local function ring(step: number, rx: number, rz: number): { { at: Vector3, yaw: number, side: number } }
		local list = {}
		for z = 18, -20, -step do
			table.insert(list, { at = V(-rx, 0, z), yaw = math.pi / 2, side = -1 })
			table.insert(list, { at = V(rx, 0, z), yaw = math.pi / 2, side = 1 })
		end
		local count = math.floor(math.pi * (rx + rz) / 2 / step)
		for i = 1, count - 1 do
			local a = math.pi * i / count
			local x, z = -rx * math.cos(a), -20 - rz * math.sin(a)
			table.insert(list, { at = V(x, 0, z), yaw = -a + math.pi / 2, side = 0 })
		end
		return list
	end
	local BARRIER = ring(7, 52, 50)

	-- barrière magique : grands pans de verre bleuté, liseré lumineux, qui ondulent
	local barrier = group(f, "Barriere")
	for i, p in BARRIER do
		local pane = piece(barrier, "PanBarriere", Enum.PartType.Block, V(7.4, 32, 0.4), barrierC, p.at + V(0, 16, 0), rotY(p.yaw), Enum.Material.Glass)
		pane.Transparency = 0.62
		tag(pane, "VagueBarriere", { Periode = 3.5 + (i % 4) * 0.4 })
		piece(barrier, "LisereBarriere", Enum.PartType.Block, V(7.6, 0.4, 0.6), glow, p.at + V(0, 0.3, 0), rotY(p.yaw), Enum.Material.Neon)
		if i % 3 == 0 then
			column(barrier, "PilierBarriere", 32, 1.2, white, p.at)
			local orb = ball(barrier, "OrbeBarriere", V(1.8, 1.8, 1.8), glow, p.at + V(0, 32.5, 0), nil, Enum.Material.Neon)
			if i % 6 == 0 then light(orb, glow, 14, 0.6) end
		end
	end

	-- l'océan derrière la barrière, jusqu'à la bordure : fond marin, algues, mur d'eau profonde éclairci en haut
	local oceanF = group(f, "Ocean")
	for i, p in ring(6, 57, 55) do
		piece(oceanF, "EauProfonde", Enum.PartType.Block, V(7.4, 70, 0.8), ocean, p.at + V(0, 35, 0), rotY(p.yaw))
		for k, band in { { 58, hex("#1E4A78"), 0.2 }, { 66, hex("#3C7AB4"), 0.35 } } do
			local s = piece(oceanF, "LumiereSurface", Enum.PartType.Block, V(7.5, 8, 0.9), band[2], p.at + V(0, band[1], 0), rotY(p.yaw))
			s.Transparency = band[3]
		end
	end
	for i, p in ring(6, 54.5, 52.5) do
		piece(oceanF, "FondMarin", Enum.PartType.Block, V(7.4, 0.3, 5.5), oceanFloor, p.at + V(0, 0.1, 0), rotY(p.yaw))
		if i % 2 == 0 then reeds(oceanF, p.at, hex("#1E5A5A"), hex("#3C8C78")) end
	end
	-- dans la bande d'eau : silhouettes fines (on les voit de face à travers la vitre)
	local shadowC = hex("#0A1A2C")
	local function swimmer(name: string, at: Vector3, alongZ: boolean, dist: number, period: number, wave: number): Model
		local mdl = Instance.new("Model")
		mdl.Name, mdl.Parent = name, oceanF
		mdl.WorldPivot = PIVOT * CFrame.new(at.X, GROUND_Y + at.Y - PIVOT.Position.Y, at.Z) * (if alongZ then CFrame.Angles(0, math.pi / 2, 0) else CFrame.identity)
		tag(mdl, "PoissonPasse", { Distance = dist, Periode = period, Ondulation = wave })
		return mdl
	end
	-- baleine le long du flanc est
	local whale = swimmer("Baleine", V(55, 30, -6), true, 34, 40, 0.6)
	ball(whale, "Corps", V(3.4, 8, 22), hex("#3A5470"), V(55, 30, -6))
	ball(whale, "Ventre", V(2.8, 4, 18), hex("#8CA6BC"), V(54.6, 27.5, -6))
	piece(whale, "Queue", Enum.PartType.Block, V(0.6, 7, 4), hex("#3A5470"), V(55, 31, -18.5))
	ball(whale, "Nageoire", V(0.6, 3, 6), hex("#3A5470"), V(54.8, 26.5, -2), CFrame.Angles(0.5, 0, 0))
	-- Léviathan, sombre et lointain, le long du flanc ouest
	local lev = swimmer("LeviathanLointain", V(-55, 44, -1), true, 16, 50, 2)
	for n = 0, 5 do -- corps centré sur le pivot : reste sur le flanc droit de la bordure
		local seg = ball(lev, "Anneau", V(2.4, 7 - n * 0.7, 5), shadowC, V(-55.5, 44 + math.sin(n * 0.8) * 3, -1 + 10 - n * 4))
		seg.Transparency = 0.3
	end
	-- bancs de poissons
	for k, d in { { -55, 14, -4, true }, { 55, 18, 6, true }, { -9, 16, -73, false }, { 4, 22, -73, false } } do
		local school = swimmer("BancPoissons", V(d[1], d[2], d[3]), d[4], if d[4] then 30 else 14, 12 + k * 3, 0.5)
		for n = 0, 7 do
			local off = if d[4] then V(0, (n // 4) * 1.4 + (n % 2) * 0.6, (n % 4) * 1.6) else V((n % 4) * 1.6, (n // 4) * 1.4 + (n % 2) * 0.6, 0)
			ball(school, "Poisson", if d[4] then V(0.7, 0.9, 2) else V(2, 0.9, 0.7), if n % 2 == 0 then hex("#F5C542") else hex("#8CD2E6"), V(d[1], d[2], d[3]) + off)
		end
	end
	-- méduses lumineuses dans la bande
	for k, d in { { -55, 22, -18 }, { 55, 26, -30 }, { -30, 30, -70 }, { 32, 24, -70 }, { 55, 16, 12 } } do
		local jelly = Instance.new("Model")
		jelly.Name, jelly.Parent = "Meduse", oceanF
		local bell = ball(jelly, "Ombrelle", V(3, 2, 3), hex("#C88CF0"), V(d[1], d[2], d[3]), nil, Enum.Material.Neon)
		bell.Transparency = 0.25
		light(bell, hex("#C88CF0"), 10, 0.5)
		for n = 0, 3 do
			local a = n * math.pi / 2
			local fil = piece(jelly, "Filament", Enum.PartType.Block, V(0.2, 3.4, 0.2), hex("#E6B4FF"), V(d[1] + math.cos(a) * 0.8, d[2] - 2.6, d[3] + math.sin(a) * 0.8), nil, Enum.Material.Neon)
			fil.Transparency = 0.4
		end
		jelly.WorldPivot = PIVOT * CFrame.new(d[1], GROUND_Y + d[2] - PIVOT.Position.Y, d[3])
		tag(jelly, "MeduseFlotte", { Amplitude = 2.5, Periode = 5 + k })
	end
	-- silhouette gigantesque collée au fond de l'eau, derrière le palais
	local giant = ball(oceanF, "SilhouetteGeante", V(26, 18, 1.5), shadowC, V(-22, 40, -72.5), CFrame.Angles(0, 0.35, 0.2))
	giant.Transparency = 0.45

	-- palais de pierre blanche et bleue, grandes fenêtres sur l'océan (stages 1 à 4)
	local palace = group(f, "Palais", nil, 4)
	piece(palace, "CorpsPalais", Enum.PartType.Block, V(44, 26, 6), white, V(0, 13, -63))
	for i = -3, 3 do
		if math.abs(i) >= 1 then -- le centre est caché par le temple du boss
			local win = piece(palace, "GrandeFenetre", Enum.PartType.Block, V(3.8, 12, 0.4), barrierC, V(i * 5.8, 14, -59.8), nil, Enum.Material.Glass)
			win.Transparency = 0.35
			piece(palace, "CadreFenetre", Enum.PartType.Block, V(4.4, 0.6, 0.8), gold, V(i * 5.8, 20.3, -59.8), nil, Enum.Material.Metal)
		end
		column(palace, "ColonnePalais", 26, 1.4, white, V(i * 5.8 + 2.9, 0, -59.4))
	end
	for _, x in { -19, 19 } do
		column(palace, "TourPalais", 36, 7, stoneBlue, V(x, 0, -62))
		ball(palace, "DomePalais", V(7.6, 7, 7.6), deepBlue, V(x, 36, -62))
	end
	ball(palace, "GrandDome", V(22, 14, 6), stoneBlue, V(0, 26, -63))

	-- statues de créatures marines le long de l'allée
	for k, d in { { -26, -6 }, { 26, -6 }, { -27, -36 }, { 27, -36 } } do
		local x, z = d[1], d[2]
		column(f, "Socle", 2.4, 3, white, V(x, 0, z))
		if k % 2 == 1 then -- poisson dressé
			ball(f, "StatuePoisson", V(2, 4.6, 2.4), stoneBlue, V(x, 5, z))
			piece(f, "QueueStatue", Enum.PartType.Wedge, V(0.6, 2.4, 2.6), stoneBlue, V(x, 8.2, z), CFrame.Angles(math.pi, 0, 0))
		else -- pieuvre
			ball(f, "StatuePieuvre", V(3.6, 3.4, 3.6), stoneBlue, V(x, 5.6, z))
			for n = 0, 5 do
				local a = n * math.pi / 3
				piece(f, "Tentacule", Enum.PartType.Block, V(0.6, 3, 0.6), stoneBlue, V(x + math.cos(a) * 1.4, 3.6, z + math.sin(a) * 1.4),
					CFrame.Angles(math.sin(a) * 0.5, 0, -math.cos(a) * 0.5))
			end
		end
	end

	-- fontaine qui coule vers le haut (côté est)
	local fx, fz = 40, -24
	piece(f, "Vasque", Enum.PartType.Cylinder, V(1.6, 9, 9), white, V(fx, 0.8, fz), FLAT)
	local basin = piece(f, "EauVasque", Enum.PartType.Cylinder, V(0.3, 7.6, 7.6), barrierC, V(fx, 1.5, fz), FLAT, Enum.Material.Glass)
	basin.Transparency = 0.3
	local jet = piece(f, "JetMontant", Enum.PartType.Cylinder, V(14, 1.4, 1.4), glow, V(fx, 8.5, fz), FLAT, Enum.Material.Neon)
	jet.Transparency = 0.45
	light(jet, glow, 12, 0.6)
	for n = 0, 5 do
		local b = ball(f, "BulleFontaine", V(0.9, 0.9, 0.9), hex("#C8F0FF"), V(fx + math.cos(n) * 1.4, 1.6, fz + math.sin(n) * 1.4))
		tag(b, "BulleMonte", { Hauteur = 15, Periode = 2.6 + n * 0.3 })
	end

	-- épave encastrée dans un bâtiment (côté est, au fond)
	piece(f, "Batiment", Enum.PartType.Block, V(12, 14, 10), white, V(34, 7, -46))
	piece(f, "ToitBatiment", Enum.PartType.Wedge, V(12, 4, 10), deepBlue, V(34, 16, -46))
	piece(f, "CoqueEpave", Enum.PartType.Block, V(16, 6, 6), hex("#4A3828"), V(29, 6, -41), CFrame.Angles(0, -0.5, 0.25))
	piece(f, "ProueEpave", Enum.PartType.Wedge, V(6, 6, 5), hex("#4A3828"), V(24.5, 5, -37.5), CFrame.Angles(0, -0.5 - math.pi / 2, 0.25))
	column(f, "MatEpave", 12, 0.8, hex("#4A3828"), V(30, 8, -42))

	-- coquillages géants transformés en maisons
	for k, d in { { 42, 6 }, { 42, -12 } } do
		ball(f, "MaisonCoquille", V(10, 8, 9), if k == 1 then hex("#F0D2C0") else hex("#E6C8D8"), V(d[1], 3, d[2]))
		for n = -2, 2 do
			piece(f, "Strie", Enum.PartType.Block, V(0.4, 7, 0.4), hex("#C8A090"), V(d[1] + n * 1.6, 4, d[2] + 4.2), CFrame.Angles(0, 0, n * 0.25))
		end
		local door = ball(f, "PorteRonde", V(2.6, 3.4, 0.6), deepBlue, V(d[1] - 4.6, 1.8, d[2]), rotY(math.pi / 2))
		door.Name = "PorteCoquille"
		local lamp = ball(f, "Lanterne", V(0.8, 0.8, 0.8), glow, V(d[1] - 4.6, 4.2, d[2] + 1.8), nil, Enum.Material.Neon)
		light(lamp, glow, 8, 0.5)
	end

	-- jardin de coraux dans une bulle magique (ouest, au fond)
	local gx, gz = -31, -48
	for n = 0, 6 do
		local a = n * 0.9
		local c = Instance.new("Model")
		c.Name, c.Parent = "JardinCorail", f
		local at = V(gx + math.cos(a) * 4, 0, gz + math.sin(a) * 4)
		coral(c, at, ({ coralA, coralB, coralC })[n % 3 + 1], 1 + (n % 2) * 0.3)
		c.WorldPivot = PIVOT * CFrame.new(at.X, GROUND_Y - PIVOT.Position.Y, at.Z)
		tag(c, "CorailOndule", { Amplitude = 7, Periode = 3 + n * 0.3 })
	end
	local bubble = ball(f, "BulleMagique", V(16, 13, 16), barrierC, V(gx, 4, gz), nil, Enum.Material.Glass)
	bubble.Transparency = 0.7
	tag(bubble, "VagueBarriere", { Periode = 5 })

	-- structure du boss : grand temple en forme de coquille, porte couverte de coraux, perle au sommet
	ball(f, "TempleCoquille", V(30, 26, 7), hex("#F4E6DC"), V(0, 11, -57.5))
	for n = -4, 4 do
		piece(f, "NervureTemple", Enum.PartType.Block, V(0.8, 24, 0.6), hex("#D2B4A4"), V(n * 2.6, 11, -54.2), CFrame.Angles(0, 0, n * 0.17))
	end
	ball(f, "CharniereTemple", V(10, 4, 5), hex("#D2B4A4"), V(0, 1.6, -55.5))
	bossGate(f, -53, 9, 12, { Dark = hex("#0E1A2A"), Post = white, Lintel = gold, LintelMaterial = Enum.Material.Metal, Glow = glow })
	for _, side in { -1, 1 } do
		coral(f, V(side * 6.5, 13, -53), if side < 0 then coralA else coralC, 1.2)
		reeds(f, V(side * 8, 0, -51), hex("#1E5A5A"), hex("#3C8C78"))
	end
	local crown = ball(f, "PerleTemple", V(3, 3, 3), hex("#F0F6FA"), V(0, 25, -56), nil, Enum.Material.Neon)
	light(crown, glow, 18, 0.9)
	-- énormes ancres
	for _, d in { { 34, 12, 0.3 }, { -45, -4, -0.4 } } do
		local iron = hex("#5A6470")
		piece(f, "VergeAncre", Enum.PartType.Block, V(1.2, 12, 1.2), iron, V(d[1], 5.4, d[2]), CFrame.Angles(0, 0, d[3]), Enum.Material.Metal)
		piece(f, "JasAncre", Enum.PartType.Block, V(7, 1, 1), iron, V(d[1] - math.sin(d[3]) * 5, 10.6, d[2]), CFrame.Angles(0, 0, d[3]), Enum.Material.Metal)
		piece(f, "BrasAncre", Enum.PartType.Block, V(8, 1.2, 1.2), iron, V(d[1], 0.8, d[2]), CFrame.Angles(0, 0, d[3] * 0.3), Enum.Material.Metal)
	end

	-- limite légère avec l'avant du plot : muret de pierre blanche et coraux, passage en face du portique
	for _, side in { -1, 1 } do
		for x = 12, 50, 6 do
			local z = 47 - (x / 50) ^ 2 * 5
			piece(f, "MuretLimite", Enum.PartType.Block, V(6.2, 1.1 + (x % 3) * 0.2, 1.4), if x % 12 == 0 then white else hex("#C8DCE8"),
				V(side * (x + 3), 0.55, z), rotY(side * (x / 50) * 0.2))
			if x % 12 == 0 then coral(f, V(side * (x + 3), 1.1, z), if x % 24 == 0 then coralA else coralB, 0.6) end
		end
		local lamp = ball(f, "LanternePassage", V(1.6, 1.6, 1.6), glow, V(side * 12, 4.4, 47), nil, Enum.Material.Neon)
		column(f, "PoteauPassage", 3.6, 0.8, white, V(side * 12, 0, 47))
		light(lamp, glow, 12, 0.7)
	end
	for _, at in { V(21, 0, -24), V(-19, 0, -24), V(-23, 0, 3) } do
		local c = Instance.new("Model")
		c.Name, c.Parent = "SortieCorail", f
		coral(c, at + V(-1.2, 0, -2.4), coralB, 1.1)
		reeds(c, at + V(1.6, 0, -2), hex("#1E5A5A"), hex("#3C8C78"))
		c.WorldPivot = PIVOT * CFrame.new(at.X, GROUND_Y - PIVOT.Position.Y, at.Z - 2)
		tag(c, "CorailOndule", { Amplitude = 4, Periode = 4 })
	end

	-- la protection se fissure : fuites (stage 2+), grosses fissures (4+), parties envahies par l'eau (5)
	local crackC = hex("#E6FAFF")
	local function crack(parent: Instance, at: Vector3, yaw: number, size: number)
		for n = 0, 4 do
			local a = (n - 2) * 0.55
			piece(parent, "Fissure", Enum.PartType.Block, V(0.25, size * (0.6 + (n % 2) * 0.5), 0.5), crackC, at + V(math.sin(a) * size * 0.25, (n - 2) * 0.4, 0),
				rotY(yaw) * CFrame.Angles(0, 0, a), Enum.Material.Neon)
		end
	end
	local function leak(parent: Instance, at: Vector3, height: number)
		local stream = piece(parent, "Filet", Enum.PartType.Block, V(0.5, height, 0.5), barrierC, at + V(0, height / 2, 0), nil, Enum.Material.Glass)
		stream.Transparency = 0.4
		for n = 0, 3 do
			local drop = ball(parent, "Goutte", V(0.5, 0.7, 0.5), hex("#C8F0FF"), at + V(0, height, 0))
			tag(drop, "GoutteTombe", { Hauteur = height, Periode = 1 + n * 0.25 })
		end
		ball(parent, "Flaque", V(5, 0.2, 4), barrierC, at + V(0, 0.15, 0))
	end
	local spots = BARRIER
	local leaks = group(f, "Fuites", 2)
	for _, k in { 5, 13, 22 } do
		local p = spots[k]
		if p then
			crack(leaks, p.at + V(0, 18, 0) + (-(p.at * V(1, 0, 1)).Unit) * 0.4, p.yaw, 3)
			leak(leaks, p.at + (-(p.at * V(1, 0, 1)).Unit) * 1.2, 16)
		end
	end
	local leaks3 = group(f, "FuitesPlus", 3)
	for _, k in { 9, 17, 26 } do
		local p = spots[k]
		if p then leak(leaks3, p.at + (-(p.at * V(1, 0, 1)).Unit) * 1.2, 20) end
	end
	local cracks = group(f, "GrossesFissures", 4)
	for k = 2, #spots, 4 do
		local p = spots[k]
		crack(cracks, p.at + V(0, 10 + (k % 3) * 6, 0) + (-(p.at * V(1, 0, 1)).Unit) * 0.4, p.yaw, 7)
	end
	for _, k in { 11, 20 } do
		local p = spots[k]
		if p then
			local jetIn = piece(cracks, "JetEntrant", Enum.PartType.Block, V(1.4, 1.4, 9), barrierC, p.at + V(0, 12, 0) + (-(p.at * V(1, 0, 1)).Unit) * 4.5,
				CFrame.lookAt(Vector3.zero, -(p.at * V(1, 0, 1)).Unit) * CFrame.Angles(-0.5, 0, 0), Enum.Material.Glass)
			jetIn.Transparency = 0.35
		end
	end
	local flooded = group(f, "Envahi", 5)
	for _, d in { { 36, -4, 20, 18 }, { -40, 2, 12, 20 } } do
		local water = piece(flooded, "EauEnvahie", Enum.PartType.Block, V(d[3], 7, d[4]), barrierC, V(d[1], 3.5, d[2]), nil, Enum.Material.Glass)
		water.Transparency = 0.55
		tag(water, "VagueBarriere", { Periode = 3 })
		for n = 0, 5 do
			local b = ball(flooded, "BulleEnvahie", V(0.8, 0.8, 0.8), hex("#C8F0FF"), V(d[1] + (n - 2.5) * 3, 0.6, d[2] + (n % 2) * 4 - 2))
			tag(b, "BulleMonte", { Hauteur = 7, Periode = 3 + n * 0.4 })
		end
	end

	-- stage 5 : immense salle circulaire, gigantesque baie vitrée sur l'océan, et ce qui passe derrière
	local hall = group(f, "SalleDuBoss", 5)
	for k = 0, 19 do
		local a = math.pi * (k / 19)
		local at = V(-50 * math.cos(a), 0, -18 - 46 * math.sin(a))
		if math.abs(at.X) > 22 or at.Z > -50 then
			column(hall, "ColonneSalle", 26, 2.4, white, at)
			piece(hall, "ChapiteauSalle", Enum.PartType.Block, V(3.4, 1, 3.4), gold, at + V(0, 26.4, 0), nil, Enum.Material.Metal)
		end
	end
	local bay = piece(hall, "BaieVitree", Enum.PartType.Block, V(40, 30, 0.6), barrierC, V(0, 22, -66), nil, Enum.Material.Glass)
	bay.Transparency = 0.5
	tag(bay, "VagueBarriere", { Periode = 6 })
	for _, x in { -20, -10, 0, 10, 20 } do
		piece(hall, "MeneauBaie", Enum.PartType.Block, V(1, 30, 1), white, V(x, 22, -65.6))
	end
	piece(hall, "LinteauBaie", Enum.PartType.Block, V(42, 2.4, 2), gold, V(0, 38, -65.6), nil, Enum.Material.Metal)
	piece(hall, "AppuiBaie", Enum.PartType.Block, V(42, 7, 2.4), white, V(0, 3.5, -65.6))
	-- séquence : silhouette qui passe, revient ; puis l'œil géant se colle contre la vitre
	local seq = Instance.new("Model")
	seq.Name, seq.Parent = "SequenceOeil", hall
	local sil = Instance.new("Model")
	sil.Name, sil.Parent = "Silhouette", seq
	for n = 0, 4 do -- corps centré sur le pivot : reste dans la bordure du fond en passant
		local s = ball(sil, "Corps", V(4.6, 9 - n * 1, 1.6), shadowC, V(6.8 - n * 3.4, 30 + math.sin(n) * 1.5, -73.5))
		s.Transparency = 0.2
	end
	sil.WorldPivot = PIVOT * CFrame.new(0, GROUND_Y + 30 - PIVOT.Position.Y, -73.5)
	local eye = Instance.new("Model")
	eye.Name, eye.Parent = "Oeil", seq
	ball(eye, "Paupiere", V(30, 24, 5), hex("#1E3A3A"), V(0, 26, -71.5))
	ball(eye, "Globe", V(22, 16, 3), hex("#E6E0B4"), V(0, 26, -69.6))
	local iris = ball(eye, "Iris", V(11, 11, 1.6), hex("#F5C542"), V(0, 26, -68.6), nil, Enum.Material.Neon)
	light(iris, hex("#F5C542"), 30, 1.2)
	piece(eye, "Pupille", Enum.PartType.Block, V(1.6, 9, 0.6), hex("#0A0A0A"), V(0, 26, -67.8))
	eye.WorldPivot = PIVOT * CFrame.new(0, GROUND_Y + 26 - PIVOT.Position.Y, -71.5)
	seq.WorldPivot = PIVOT * CFrame.new(0, GROUND_Y + 26 - PIVOT.Position.Y, -71.5)
	tag(seq, "SequenceOeil", { Periode = 40, Largeur = 12 })
end

---------------------------------------------------------------- Zone 6 : sanctuaire des îles du ciel
BUILD[6] = function(m: Instance)
	moveMarkers(m, -51, V(0, 21, -58))
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
	-- plus de plateau : le boss sort du portail doré du sanctuaire (rideau de lumière bleu ciel)
	bossGate(f, -53, 8, 12, { Dark = hex("#5E8CC0"), Post = marble, Lintel = gold, LintelMaterial = Enum.Material.Metal, Glow = hex("#FFE08C") })
	local veil = piece(f, "VoileLumiere", Enum.PartType.Block, V(7, 10, 0.3), hex("#BFE0FF"), V(0, 5, -53.2), nil, Enum.Material.Neon)
	veil.Transparency = 0.55
	for _, side in { -1, 1 } do
		cloud(f, V(side * 7, 0, -51.5), cloudC, 1.3)
	end
	-- coin de l'ancien plateau : îlot de nuages, cloche dorée sur son portique, lanternes d'or
	cloud(f, V(26, 0, -44), cloudC, 2.6)
	for _, side in { -1, 1 } do
		column(f, "PortiqueCloche", 9, 0.8, marble, V(26 + side * 3, 0, -46))
	end
	piece(f, "TraverseCloche", Enum.PartType.Block, V(7.4, 0.8, 0.9), gold, V(26, 9.2, -46), nil, Enum.Material.Metal)
	ball(f, "Cloche", V(3.4, 4, 3.4), gold, V(26, 7, -46), nil, Enum.Material.Metal)
	for _, at in { V(16, 0, -50), V(34, 0, -36) } do
		column(f, "MatLanterne", 6, 0.4, gold, at, Enum.Material.Metal)
		local orb = ball(f, "LanterneOr", V(1.4, 1.4, 1.4), hex("#FFE08C"), at + V(0, 6.6, 0), nil, Enum.Material.Neon)
		light(orb, hex("#FFE08C"), 9, 0.6)
	end
	battleground(f, hex("#BFD6EE"), hex("#A9C6E6"), -41)
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
	-- copies d'un ancien décor de cette zone posées dans une arène ou rangées (ServerStorage.ZonesRangees_<plot>) :
	-- retirées, sauf dans la vitrine de la zone (Workspace.PlotsZones, emplacement prévu) où le nouveau décor les remplace
	local showcase = workspace:FindFirstChild("PlotsZones")
	local showcaseArenas: { Model } = {}
	for _, holder in { workspace, ServerStorage } do
		for _, d in holder:GetDescendants() do
			if d:IsA("Model") and d:GetAttribute("ZoneId") == theme.Id and d.Parent and d.Parent.Name == "Zones"
				or d:IsA("Model") and d:GetAttribute("ZoneId") == theme.Id and d.Parent and d.Parent.Name:match("^ZonesRangees_") then
				local holderArena = d.Parent.Parent
				if showcase and d:IsDescendantOf(showcase) and holderArena and holderArena:IsA("Model") then
					table.insert(showcaseArenas, holderArena)
				end
				d:Destroy()
			end
		end
	end
	for _, showcaseArena in showcaseArenas do
		local copy = model:Clone()
		copy:PivotTo(showcaseArena:GetPivot())
		copy.Parent = showcaseArena:FindFirstChild("Zones")
	end
	model.Parent = templates
	task.wait() -- une zone par lot ; laisser Studio répondre entre les copies
end

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
print(`Zones 2 à 6 : {#ENEMIES} modèles de combat, {#THEMES} décors dans ServerStorage.Assets.ZonesArene`)
