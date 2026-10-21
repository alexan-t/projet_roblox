--!strict
-- Royaumes miniatures, niveaux 4 à 8 (docs/KINGDOM.md § Vitrine des niveaux). À exécuter dans Studio EDIT
-- (barre de commande ou MCP). Assets uniquement, aucun script. Répétable : reconstruit les niveaux 4 à 8.
-- Chaque niveau part d'une copie du niveau précédent (le niveau 3 validé, modèles importés) posée sur son
-- socle de Workspace.VitrineRoyaumes, puis le fait grandir : même île, même entrée (portail vers -Z local),
-- même palette (bois, chaume, pierre, bleu royal et or du royaume, losange emblème).
--   4 · Village fortifié : tours de guet à l'entrée, moulin, une maison sur le terrain à bâtir.
--   5 · Bourg : rempart de pierre à l'avant et porte fortifiée, chapelle à la place de la tente, second étal.
--   6 · Ville fortifiée : enceinte de pierre complète, tours d'angle, tour de guet de pierre.
--   7 · Château : donjon crénelé à tourelles au fond, remparts plus hauts.
--   8 · Citadelle royale : donjon couronné d'or, tours plus hautes à flèches d'or, grands étendards.
-- Une étape ChangeHistoryService (Ctrl+Z).

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local recording = ChangeHistoryService:TryBeginRecording("Royaumes niveaux 4 à 8")
local vitrine = workspace:WaitForChild("VitrineRoyaumes")

local function hex(h: string): Color3
	return Color3.fromHex(h)
end

-- Palette relevée sur les niveaux 1 à 3 (modèles importés de la vitrine)
local C = {
	Wood = hex("#805230"), WoodDark = hex("#603C26"), WoodMid = hex("#684228"),
	Thatch = hex("#FACE46"), Plaster = hex("#F2E4C6"), PlasterShade = hex("#ECE0C4"),
	Stone = hex("#847A72"), StoneDark = hex("#767478"), StoneDeep = hex("#483E38"), StoneLight = hex("#A49A90"),
	Blue = hex("#3460B0"), BlueDark = hex("#284C8C"), Red = hex("#D6483C"), Gold = hex("#DEAA3C"), GoldLight = hex("#E8C66E"),
	Window = hex("#3E322C"), Green = hex("#5CA448"), Glow = hex("#FFD278"),
}

local V = Vector3.new
local function rotY(a: number): CFrame
	return CFrame.Angles(0, a, 0)
end

-- Repère courant : pivot du royaume (rotation comprise). Toutes les positions sont locales (Y = 0 : dessus de l'île).
local FRAME = CFrame.identity

local function part(parent: Instance, name: string, class: string, size: Vector3, color: Color3, cf: CFrame, material: Enum.Material?): BasePart
	local p = Instance.new(class) :: BasePart
	p.Name = name
	p.Size = size
	p.CFrame = FRAME * cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local function block(parent: Instance, name: string, size: Vector3, color: Color3, cf: CFrame, material: Enum.Material?): BasePart
	return part(parent, name, "Part", size, color, cf, material)
end
local function group(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name, m.Parent = name, parent
	return m
end

-- Toit en pyramide de quatre coins (base w × w, posée en `base`, hauteur h)
local function pyramid(parent: Instance, name: string, base: CFrame, w: number, h: number, color: Color3)
	for k = 0, 3 do
		part(parent, name, "CornerWedgePart", V(w / 2, h, w / 2), color, base * CFrame.new(0, h / 2, 0) * rotY(k * math.pi / 2) * CFrame.new(-w / 4, 0, w / 4))
	end
end

-- Toit à deux pans, faîte le long de X (base w × d, hauteur h)
local function gable(parent: Instance, name: string, base: CFrame, w: number, d: number, h: number, color: Color3)
	part(parent, name, "WedgePart", V(w, h, d / 2), color, base * CFrame.new(0, h / 2, d / 4))
	part(parent, name, "WedgePart", V(w, h, d / 2), color, base * CFrame.new(0, h / 2, -d / 4) * rotY(math.pi))
end

-- Losange de l'emblème (or), à plat sur une face
local function diamond(parent: Instance, cf: CFrame, s: number)
	block(parent, "Losange", V(s, s, 0.15), C.Gold, cf * CFrame.Angles(0, 0, math.pi / 4), Enum.Material.Metal)
end

-- Bannière bleue à losange d'or, sur un mât
local function banner(parent: Instance, foot: CFrame, h: number, s: number)
	block(parent, "MatBanniere", V(0.2, h, 0.2), C.WoodDark, foot * CFrame.new(0, h / 2, 0))
	block(parent, "Banniere", V(1.6 * s, 1.1 * s, 0.1), C.Blue, foot * CFrame.new(0.8 * s + 0.1, h - 0.6 * s, 0))
	diamond(parent, foot * CFrame.new(0.8 * s + 0.1, h - 0.6 * s, -0.08), 0.45 * s)
	block(parent, "Pommeau", V(0.35, 0.35, 0.35), C.Gold, foot * CFrame.new(0, h + 0.15, 0), Enum.Material.Metal)
end

-- Maison à colombages : murs crépis, poteaux et bande de bois, porte et fenêtres, toit à deux pans
local function house(parent: Instance, name: string, at: Vector3, yaw: number, w: number, d: number, h: number, roof: Color3, wall: Color3?)
	local m = group(parent, name)
	local base = CFrame.new(at) * rotY(yaw)
	block(m, "Soubassement", V(w + 0.3, 0.5, d + 0.3), C.Stone, base * CFrame.new(0, 0.25, 0))
	block(m, "Murs", V(w, h, d), wall or C.Plaster, base * CFrame.new(0, 0.5 + h / 2, 0))
	for _, x in { -w / 2, w / 2 } do
		for _, z in { -d / 2, d / 2 } do
			block(m, "Poteau", V(0.3, h, 0.3), C.WoodDark, base * CFrame.new(x, 0.5 + h / 2, z))
		end
	end
	block(m, "Sabliere", V(w + 0.15, 0.25, d + 0.15), C.WoodDark, base * CFrame.new(0, 0.5 + h * 0.55, 0))
	block(m, "Porte", V(1, 1.7, 0.15), C.WoodMid, base * CFrame.new(-w * 0.18, 0.5 + 0.85, -d / 2 - 0.05))
	for _, x in { w * 0.22 } do
		block(m, "Fenetre", V(0.8, 0.7, 0.12), C.Window, base * CFrame.new(x, 0.5 + h * 0.4, -d / 2 - 0.05))
		block(m, "Volet", V(0.25, 0.75, 0.14), C.Blue, base * CFrame.new(x - 0.55, 0.5 + h * 0.4, -d / 2 - 0.06))
	end
	gable(m, "Toit", base * CFrame.new(0, 0.5 + h, 0), w + 0.6, d + 0.6, math.min(w, d) * 0.55, roof)
	return m
end

-- Tour de pierre carrée : socle, fût, bandeau, meurtrières ; toit en pyramide (bleu, épi d'or) ou créneaux
local function stoneTower(parent: Instance, name: string, at: Vector3, w: number, h: number, roof: string, gold: boolean?): Model
	local m = group(parent, name)
	local base = CFrame.new(at)
	block(m, "SocleTour", V(w + 0.6, 0.8, w + 0.6), C.StoneDark, base * CFrame.new(0, 0.4, 0))
	block(m, "FutTour", V(w, h, w), C.Stone, base * CFrame.new(0, 0.8 + h / 2, 0))
	for k = 0, 3 do
		local face = rotY(k * math.pi / 2)
		block(m, "Meurtriere", V(0.35, 1, 0.1), C.Window, base * face * CFrame.new(0, 0.8 + h * 0.62, -w / 2 - 0.04))
		block(m, "PierreRelief", V(0.9, 0.45, 0.12), C.StoneLight, base * face * CFrame.new(w * 0.22, 0.8 + h * 0.3, -w / 2 - 0.05))
		block(m, "PierreRelief", V(0.7, 0.4, 0.12), C.StoneDark, base * face * CFrame.new(-w * 0.25, 0.8 + h * 0.8, -w / 2 - 0.05))
	end
	local top = 0.8 + h
	block(m, "Bandeau", V(w + 0.4, 0.5, w + 0.4), if gold then C.Gold else C.StoneDark, base * CFrame.new(0, top - 0.1, 0),
		if gold then Enum.Material.Metal else nil)
	if roof == "Pyramide" then
		pyramid(m, "ToitTour", base * CFrame.new(0, top + 0.15, 0), w + 0.9, w * 1.15, C.Blue)
		block(m, "Epi", V(0.25, 1.2, 0.25), C.Gold, base * CFrame.new(0, top + 0.15 + w * 1.15 + 0.5, 0), Enum.Material.Metal)
		if gold then
			banner(m, base * CFrame.new(0, top + 0.15 + w * 1.15 + 1.1, 0), 1.8, 0.8)
		end
	else
		local n = math.max(2, math.floor(w / 1.1))
		for k = 0, 3 do
			local face = rotY(k * math.pi / 2)
			for i = 0, n - 1 do
				local x = (i - (n - 1) / 2) * (w / n)
				block(m, "Creneau", V(0.6, 0.7, 0.5), C.Stone, base * face * CFrame.new(x, top + 0.5, -w / 2 + 0.25))
			end
		end
	end
	return m
end

-- Rempart de pierre entre deux points : mur, chemin de ronde, créneaux, quelques pierres en relief
local function wall(parent: Instance, a: Vector3, b: Vector3, h: number)
	local d = b - a
	local len = d.Magnitude
	local cf = CFrame.new((a + b) / 2) * rotY(math.atan2(d.X, d.Z))
	block(parent, "Mur", V(1.2, h, len + 0.4), C.Stone, cf * CFrame.new(0, h / 2, 0))
	block(parent, "ChemineRonde", V(1.3, 0.25, len + 0.4), C.StoneDark, cf * CFrame.new(0, h, 0))
	local n = math.max(1, math.floor(len / 1.5))
	for i = 0, n - 1 do
		block(parent, "Creneau", V(1.25, 0.6, 0.7), C.Stone, cf * CFrame.new(0, h + 0.4, (i - (n - 1) / 2) * (len / n)))
	end
	block(parent, "PierreRelief", V(0.12, 0.45, 0.9), C.StoneLight, cf * CFrame.new(-0.62, h * 0.4, len * 0.2))
	block(parent, "PierreRelief", V(0.12, 0.4, 0.7), C.StoneDark, cf * CFrame.new(-0.62, h * 0.7, -len * 0.25))
end

-- Arc d'enceinte de rayon R, d'un angle à l'autre (radians, repère local XZ), en segments
local function wallArc(parent: Instance, R: number, t0: number, t1: number, h: number)
	local steps = math.max(1, math.ceil(math.abs(t1 - t0) / 0.32))
	for i = 0, steps - 1 do
		local a0, a1 = t0 + (t1 - t0) * i / steps, t0 + (t1 - t0) * (i + 1) / steps
		wall(parent, V(R * math.cos(a0), 0, R * math.sin(a0)), V(R * math.cos(a1), 0, R * math.sin(a1)), h)
	end
end

-- Porte fortifiée de pierre (vers -Z) : deux tours, arc, herse, bannière au-dessus
local function gatehouse(parent: Instance, z: number, h: number, gold: boolean?): Model
	local m = group(parent, "PorteFortifiee")
	for _, x in { -3.4, 3.4 } do
		stoneTower(m, "TourPorte", V(x, 0, z), 2.6, h, "Pyramide", gold)
	end
	local base = CFrame.new(0, 0, z)
	block(m, "Arc", V(4.4, 1.4, 2.4), C.StoneDark, base * CFrame.new(0, h - 0.6, 0))
	block(m, "Creneaux", V(4.4, 0.6, 0.6), C.Stone, base * CFrame.new(0, h + 0.4, -0.9))
	block(m, "Ouverture", V(3.2, h - 1.3, 0.2), C.Window, base * CFrame.new(0, (h - 1.3) / 2, 0.6))
	for i = -1, 1 do
		block(m, "Herse", V(0.15, h - 1.5, 0.15), C.StoneDeep, base * CFrame.new(i * 0.8, (h - 1.3) / 2 + 0.6, -0.4), Enum.Material.Metal)
	end
	block(m, "BarreHerse", V(3, 0.15, 0.15), C.StoneDeep, base * CFrame.new(0, h - 2.2, -0.4), Enum.Material.Metal)
	block(m, "Tenture", V(1.8, 1.2, 0.1), C.Blue, base * CFrame.new(0, h - 0.6, -1.25))
	diamond(m, base * CFrame.new(0, h - 0.6, -1.32), 0.5)
	if gold then
		block(m, "FriseOr", V(4.6, 0.25, 2.5), C.Gold, base * CFrame.new(0, h + 0.05, 0), Enum.Material.Metal)
	end
	return m
end

-- Moulin : tour ronde de pierre et crépi, chapeau de chaume, quatre ailes tournées vers l'entrée (-Z)
local function windmill(parent: Instance, at: Vector3): Model
	local m = group(parent, "Moulin")
	local base = CFrame.new(at)
	local FLAT = CFrame.Angles(0, 0, math.pi / 2)
	part(m, "BaseMoulin", "Part", V(1.6, 3.8, 3.8), C.Stone, base * CFrame.new(0, 0.8, 0) * FLAT)
	part(m, "CorpsMoulin", "Part", V(4, 3.2, 3.2), C.Plaster, base * CFrame.new(0, 3.6, 0) * FLAT)
	for _, p in m:GetChildren() do
		(p :: Part).Shape = Enum.PartType.Cylinder
	end
	block(m, "Porte", V(0.9, 1.5, 0.15), C.WoodMid, base * CFrame.new(0, 2.2, -1.6))
	pyramid(m, "Chapeau", base * CFrame.new(0, 5.55, 0), 3.8, 2.4, C.Thatch)
	local hub = base * CFrame.new(0, 4.8, -2)
	block(m, "Moyeu", V(0.6, 0.6, 0.8), C.WoodDark, hub)
	for k = 0, 3 do
		local arm = hub * CFrame.Angles(0, 0, k * math.pi / 2 + 0.3)
		block(m, "Aile", V(0.2, 3.6, 0.15), C.Wood, arm * CFrame.new(0, 1.9, -0.3))
		block(m, "Toile", V(1.1, 2.8, 0.08), C.PlasterShade, arm * CFrame.new(0.65, 2.1, -0.32))
	end
	return m
end

-- Chapelle : nef de pierre à toit bleu, clocher carré à flèche bleue et losange d'or (porte vers -Z)
local function chapel(parent: Instance, at: Vector3, yaw: number): Model
	local m = house(parent, "Chapelle", at, yaw, 3.6, 5, 3.4, C.Blue, C.Stone)
	local base = CFrame.new(at) * rotY(yaw)
	local tower = stoneTower(m, "Clocher", (base * CFrame.new(0, 0, -2.4)).Position, 2.2, 6, "Pyramide")
	diamond(tower, base * CFrame.new(0, 5.2, -3.55), 0.7)
	local bell = block(m, "Cloche", V(0.7, 0.8, 0.7), C.Gold, base * CFrame.new(0, 5.2, -2.4), Enum.Material.Metal)
	bell.Shape = Enum.PartType.Ball
	return m
end

-- Donjon : grosse tour crénelée, quatre tourelles d'angle à toits bleus, porte, grande bannière, losange d'or
local function keep(parent: Instance, at: Vector3, w: number, h: number, crown: boolean): Model
	local m = stoneTower(parent, "Donjon", at, w, h, "Creneaux", crown)
	local base = CFrame.new(at)
	local top = 0.8 + h
	for _, c in { V(-1, 0, -1), V(1, 0, -1), V(-1, 0, 1), V(1, 0, 1) } do
		local p = c * (w / 2)
		stoneTower(m, "Tourelle", V(at.X + p.X, at.Y + top - 3, at.Z + p.Z), 1.8, 3.4, "Pyramide", crown)
	end
	block(m, "PorteDonjon", V(1.6, 2.6, 0.2), C.WoodMid, base * CFrame.new(0, 2.1, -w / 2 - 0.08))
	block(m, "ArcPorte", V(2.2, 0.5, 0.25), C.StoneDark, base * CFrame.new(0, 3.6, -w / 2 - 0.08))
	block(m, "TentureDonjon", V(2.4, 3.2, 0.1), C.Blue, base * CFrame.new(0, h * 0.62, -w / 2 - 0.1))
	diamond(m, base * CFrame.new(0, h * 0.62, -w / 2 - 0.18), 1)
	if crown then
		-- couronnement royal : étage supérieur, flèche bleue haute, épi et étendard d'or
		stoneTower(m, "EtageRoyal", V(at.X, at.Y + top, at.Z), w * 0.5, 4.5, "Pyramide", true)
		local glow = block(m, "CoeurRoyal", V(0.8, 0.8, 0.8), C.Glow, base * CFrame.new(0, top + 3.2, -w * 0.25 - 0.1), Enum.Material.Neon)
		local l = Instance.new("PointLight")
		l.Color, l.Range, l.Brightness = C.Glow, 10, 0.8
		l.Parent = glow
	else
		banner(m, base * CFrame.new(0, top, 0), 3, 1.2)
	end
	return m
end

------------------------------------------------------------------ outils de copie

local function levelModel(n: number): Model?
	local socle = vitrine:FindFirstChild(string.format("Socle_%02d", n))
	return socle and socle:FindFirstChild("Royaume_Niveau" .. n) :: Model?
end

-- Retire, dans les éléments nommés du royaume, ce qui tombe dans un disque (local XZ)
local function clear(root: Instance, center: Vector3, radius: number, names: { [string]: boolean })
	local pivot = FRAME
	for _, child in root:GetChildren() do
		if names[child.Name] then
			local pieces = if child:IsA("BasePart") then { child } else child:GetChildren()
			for _, p in pieces do
				local pos = if p:IsA("Model") then p:GetBoundingBox().Position elseif p:IsA("BasePart") then p.Position else nil
				if pos then
					local l = pivot:PointToObjectSpace(pos)
					if (V(l.X, 0, l.Z) - V(center.X, 0, center.Z)).Magnitude < radius then
						p:Destroy()
					end
				end
			end
			if #child:GetChildren() == 0 and not child:IsA("BasePart") then child:Destroy() end
		end
	end
end

-- Retire les morceaux d'un élément dont le centre est dans le demi-plan donné (local z < zMax)
local function clearWhere(root: Instance, name: string, keep: (Vector3) -> boolean)
	local child = root:FindFirstChild(name)
	if not child then return end
	for _, p in child:GetDescendants() do
		if p:IsA("BasePart") and p.Parent then
			local l = FRAME:PointToObjectSpace(p.Position)
			if not keep(l) then p:Destroy() end
		end
	end
end

-- Agrandit un modèle en gardant ses pieds au même endroit (ScaleTo agrandit autour du pivot)
local function scaleFromFoot(model: Model, k: number)
	local cf, size = model:GetBoundingBox()
	local foot = cf.Position - V(0, size.Y / 2, 0)
	model:ScaleTo(model:GetScale() * k)
	local cf2, size2 = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + (foot - (cf2.Position - V(0, size2.Y / 2, 0))))
end

local function cloneInto(model: Instance, name: string, from: Instance, at: Vector3, yaw: number, scale: number): Model?
	local src = from:FindFirstChild(name, true)
	if not src or not src:IsA("Model") then return nil end
	local copy = src:Clone()
	copy:ScaleTo(copy:GetScale() * scale)
	local cf, size = copy:GetBoundingBox()
	local foot = FRAME:PointToObjectSpace(cf.Position) - V(0, size.Y / 2, 0)
	copy:PivotTo(FRAME * CFrame.new(at) * rotY(yaw) * CFrame.new(-foot.X, -foot.Y, -foot.Z) * FRAME:Inverse() * copy:GetPivot())
	copy.Parent = model
	return copy
end

------------------------------------------------------------------ niveaux

local BUILD: { [number]: (root: Instance, from: Instance) -> () } = {}
local MUR_R = 14.6

-- 4 · Village fortifié
BUILD[4] = function(root, from)
	clear(root, V(5.2, 0, 9.7), 3, { terrain_a_batir = true, nature = true })
	house(root, "MaisonNeuve", V(5.4, 0, 10), 0, 4.2, 3.6, 3.2, C.Thatch)
	clear(root, V(-8.2, 0, 7.4), 3, { nature = true })
	windmill(root, V(-8.2, 0, 7.4))
	for _, x in { -4.6, 4.6 } do
		clear(root, V(x, 0, -14.4), 2.4, { palissade = true, nature = true })
		local t = cloneInto(root, "tour_de_guet", from, V(x, 0, -14.4), 0, 0.72)
		if t then t.Name = "TourEntree" end
	end
end

-- 5 · Bourg : rempart de pierre à l'avant (porte fortifiée), tours aux extrémités, chapelle, second étal
BUILD[5] = function(root, from)
	clearWhere(root, "palissade", function(l) return l.Z > -4.5 end)
	for _, d in root:GetChildren() do
		if d.Name == "TourEntree" or d.Name == "portail_entree" then d:Destroy() end
	end
	local rempart = group(root, "Rempart")
	local gap = math.asin(3.4 / MUR_R) + 0.12
	local tA, tB = math.pi + math.asin(4.5 / MUR_R), 2 * math.pi - math.asin(4.5 / MUR_R)
	wallArc(rempart, MUR_R, tA, 1.5 * math.pi - gap, 3.2)
	wallArc(rempart, MUR_R, 1.5 * math.pi + gap, tB, 3.2)
	gatehouse(root, -MUR_R, 5, false)
	for _, t in { tA, tB } do
		stoneTower(root, "TourRempart", V(MUR_R * math.cos(t), 0, MUR_R * math.sin(t)), 2.8, 5, "Pyramide")
	end
	clear(root, V(-5.3, 0, 2.4), 2.6, { tente = true, nature = true })
	chapel(root, V(-5.4, 0, 2.6), 0)
	clear(root, V(8.4, 0, -9.6), 2.4, { nature = true })
	local stall = cloneInto(root, "etal_marche", from, V(8.4, 0, -9.6), 0.5, 1)
	if stall then stall.Name = "EtalNeuf" end
end

-- 6 · Ville fortifiée : enceinte complète, tours d'angle et du fond, tour de guet de pierre
BUILD[6] = function(root, from)
	local pal = root:FindFirstChild("palissade")
	if pal then pal:Destroy() end
	local rempart = root:FindFirstChild("Rempart") or group(root, "Rempart")
	local tA, tB = math.pi + math.asin(4.5 / MUR_R), 2 * math.pi - math.asin(4.5 / MUR_R)
	wallArc(rempart, MUR_R, tB - 2 * math.pi, tA, 3.2)
	for _, t in { math.rad(60), math.rad(120) } do
		local at = V(MUR_R * math.cos(t), 0, MUR_R * math.sin(t))
		clear(root, at, 2.6, { nature = true })
		stoneTower(root, "TourRempart", at, 3, 6, "Pyramide")
	end
	local wood = root:FindFirstChild("tour_de_guet", true)
	local at = V(-5.2, 0, -9.9)
	if wood then wood:Destroy() end
	stoneTower(root, "TourGuetPierre", at, 3.2, 9, "Pyramide")
end

-- 7 · Château : donjon au fond, remparts et tours plus hauts
BUILD[7] = function(root, from)
	for _, d in root:GetChildren() do
		if d.Name == "maison_villageois" then d:Destroy() end
	end
	clear(root, V(-1.6, 0, 8.8), 4.6, { nature = true })
	keep(root, V(-1.6, 0, 8.8), 6, 11, false)
end

-- 8 · Citadelle royale : donjon couronné d'or, tours à flèches d'or et étendards, porte dorée
BUILD[8] = function(root, from)
	local old = root:FindFirstChild("Donjon")
	if old then old:Destroy() end
	keep(root, V(-1.6, 0, 8.8), 6.4, 13, true)
	local gate = root:FindFirstChild("PorteFortifiee")
	if gate then gate:Destroy() end
	gatehouse(root, -MUR_R, 6, true)
	for _, d in root:GetChildren() do
		if d.Name == "TourRempart" or d.Name == "TourGuetPierre" then
			local _, size = d:GetBoundingBox()
			local foot = FRAME:PointToObjectSpace(d:GetBoundingBox().Position) - V(0, size.Y / 2, 0)
			local w = if d.Name == "TourGuetPierre" then 3.2 else 3
			local h = if d.Name == "TourGuetPierre" then 11 else 7.5
			d:Destroy()
			stoneTower(root, d.Name, V(foot.X, 0, foot.Z), w, h, "Pyramide", true)
		end
	end
	local standard = root:FindFirstChild("etendard")
	if standard and standard:IsA("Model") then scaleFromFoot(standard, 1.4) end
end

------------------------------------------------------------------ construction

local built = {}
for n = 4, 8 do
	local socle = vitrine:FindFirstChild(string.format("Socle_%02d", n))
	local previous = levelModel(n - 1)
	assert(socle and previous, `socle {n} ou niveau {n - 1} introuvable`)
	local old = socle:FindFirstChild("Royaume_Niveau" .. n)
	if old then old:Destroy() end
	local model = previous:Clone()
	model.Name = "Royaume_Niveau" .. n
	model:SetAttribute("Niveau", n)
	-- même placement relatif au socle que le niveau précédent
	local prevSocle = previous.Parent :: Model
	local rel = (prevSocle:FindFirstChild("PointDePose") :: BasePart).CFrame:ToObjectSpace(previous:GetPivot())
	model:PivotTo((socle:FindFirstChild("PointDePose") :: BasePart).CFrame * rel)
	model.Parent = socle
	FRAME = model:GetPivot()
	local root = model:FindFirstChild("royaume_niveau_0" .. (n - 1)) or model
	root.Name = "royaume_niveau_0" .. n
	BUILD[n](root, levelModel(3) :: Instance)
	local count = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			count += 1
		end
	end
	table.insert(built, `niveau {n} : {count} pièces`)
	task.wait()
end

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
print(table.concat(built, " ; "))
return table.concat(built, " ; ")
