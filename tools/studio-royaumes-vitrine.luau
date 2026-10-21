--!strict
-- Royaumes miniatures, niveaux 4 à 20 (docs/KINGDOM.md § Vitrine des niveaux). À exécuter dans Studio EDIT
-- (barre de commande ou MCP). Assets uniquement, aucun script. Répétable : reconstruit les niveaux FIRST à LAST.
-- Chaque niveau part d'une copie du niveau précédent (le niveau 3 validé, modèles importés) posée sur son
-- socle de Workspace.VitrineRoyaumes, puis le fait grandir : même île, même entrée (portail vers -Z local),
-- même palette (bois, chaume, pierre, bleu royal et or du royaume, losange emblème).
--   4 · Village fortifié : tours de guet à l'entrée, moulin, une maison sur le terrain à bâtir.
--   5 · Bourg : rempart de pierre à l'avant et porte fortifiée, chapelle à la place de la tente, second étal.
--   6 · Ville fortifiée : enceinte de pierre complète, tours d'angle, tour de guet de pierre.
--   7 · Château : donjon crénelé à tourelles au fond, remparts plus hauts.
--   8 · Citadelle royale : donjon couronné d'or, tours plus hautes à flèches d'or, grands étendards.
--   9 · Cité royale : île élargie, tours latérales, grande salle du palais, piliers royaux à brasero à l'entrée.
--  10 · Capitale : douves et pont, cathédrale à rosace (à la place de la chapelle, du moulin et de l'atelier).
--  11 · Royaume radieux : tour des mages à cristal flottant, statue d'or du roi sur la place, lanternes flottantes.
--  12 · Palais du roi : palais à dôme d'or à la place du donjon, chemin de ronde doré, grand emblème de la porte.
--  13 · Cité haute : passerelles du palais aux tours du fond, jardins suspendus sur le rempart, fontaine royale.
--  14 · Empire du roi : chevaliers gardiens géants sur le rempart près de la porte, couronne d'or flottante.
--  15 · Royaume des cascades : cascades du rempart dans les douves, tentures sur le rempart, arche fleurie.
--  16 · Îles célestes : trois îlots flottants à tours dorées enchaînés au royaume.
--  17 · Arcanes : cœur de cristal géant au-dessus de la couronne, faisceaux, cercle de runes sur la place.
--  18 · Âge d'or : arc de triomphe d'or sur le pont (statue du roi au sommet), tours coiffées d'or.
--  19 · Royaume ailé : immenses ailes d'or derrière le palais, auréole.
--  20 · Royaume légendaire : citadelle céleste au-dessus du royaume, colonne de lumière, étoiles.
-- Une étape ChangeHistoryService (Ctrl+Z).

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local FIRST, LAST = 15, 20 -- niveaux reconstruits (chacun part du précédent, déjà posé)
local recording = ChangeHistoryService:TryBeginRecording(`Royaumes niveaux {FIRST} à {LAST}`)
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

-- Anneau de segments (anneaux flottants, couronnes) : n blocs posés sur un cercle horizontal
local function ring(parent: Instance, name: string, center: Vector3, r: number, n: number, size: Vector3, color: Color3, material: Enum.Material?)
	for i = 0, n - 1 do
		local a = i * 2 * math.pi / n
		block(parent, name, size, color, CFrame.new(center + V(math.cos(a) * r, 0, math.sin(a) * r)) * rotY(-a), material)
	end
end

-- Élargit l'île (tapis d'herbe, couche de terre, rochers) dans le plan, sans changer sa hauteur
local function widenIsland(root: Instance, k: number)
	local ile = root:FindFirstChild("ile")
	if not ile then return end
	for _, d in ile:GetDescendants() do
		if d:IsA("BasePart") then
			local l = FRAME:ToObjectSpace(d.CFrame)
			d.Size = V(d.Size.X * k, d.Size.Y, d.Size.Z * k)
			d.CFrame = FRAME * (CFrame.new(l.X * k, l.Y, l.Z * k) * l.Rotation)
		end
	end
end

-- Pilier royal : colonne de pierre, bandeau d'or, brasero allumé
local function royalPillar(parent: Instance, at: Vector3)
	local m = group(parent, "PilierRoyal")
	local base = CFrame.new(at)
	block(m, "SoclePilier", V(1.6, 0.6, 1.6), C.StoneDark, base * CFrame.new(0, 0.3, 0))
	block(m, "Pilier", V(1.1, 3.6, 1.1), C.Stone, base * CFrame.new(0, 2.4, 0))
	block(m, "BandeauPilier", V(1.3, 0.3, 1.3), C.Gold, base * CFrame.new(0, 3.6, 0), Enum.Material.Metal)
	block(m, "Vasque", V(1.6, 0.5, 1.6), C.Gold, base * CFrame.new(0, 4.45, 0), Enum.Material.Metal)
	local coals = block(m, "Braises", V(1.2, 0.2, 1.2), C.Glow, base * CFrame.new(0, 4.75, 0), Enum.Material.Neon)
	local fire = Instance.new("Fire")
	fire.Size, fire.Heat, fire.Color, fire.SecondaryColor = 2, 4, hex("#F08C3C"), hex("#8A2A10")
	fire.Parent = coals
end

-- Statue d'or du roi : socle de pierre cerclé d'or, robe, buste, tête couronnée, épée levée
local function kingStatue(parent: Instance, at: Vector3)
	local m = group(parent, "StatueDuRoi")
	local base = CFrame.new(at)
	block(m, "SocleStatue", V(3, 1, 3), C.Stone, base * CFrame.new(0, 0.5, 0))
	block(m, "BandeSocle", V(3.2, 0.25, 3.2), C.Gold, base * CFrame.new(0, 1, 0), Enum.Material.Metal)
	block(m, "Robe", V(1.6, 2.2, 1.1), C.Gold, base * CFrame.new(0, 2.2, 0), Enum.Material.Metal)
	block(m, "Buste", V(1.3, 1.1, 0.9), C.Gold, base * CFrame.new(0, 3.85, 0), Enum.Material.Metal)
	local head = block(m, "Tete", V(0.9, 0.9, 0.9), C.Gold, base * CFrame.new(0, 4.85, 0), Enum.Material.Metal)
	head.Shape = Enum.PartType.Ball
	for k = 0, 3 do
		block(m, "Couronne", V(0.25, 0.45, 0.25), C.GoldLight, base * rotY(k * math.pi / 2) * CFrame.new(0.35, 5.4, 0.35), Enum.Material.Metal)
	end
	block(m, "Bras", V(0.35, 1.3, 0.35), C.Gold, base * CFrame.new(0.85, 4.3, -0.1) * CFrame.Angles(0, 0, -0.5), Enum.Material.Metal)
	block(m, "Epee", V(0.18, 2.2, 0.1), C.StoneLight, base * CFrame.new(1.3, 5.6, -0.1), Enum.Material.Metal)
	block(m, "Garde", V(0.7, 0.15, 0.15), C.GoldLight, base * CFrame.new(1.3, 4.55, -0.1), Enum.Material.Metal)
	diamond(m, base * CFrame.new(0, 3.85, -0.48), 0.45)
end

-- Tour des mages : tour de pierre cerclée d'or, sommet ouvert, cristal flottant entouré de deux anneaux d'or
local function arcaneTower(parent: Instance, at: Vector3)
	local m = stoneTower(parent, "TourDesMages", at, 3.2, 12, "Creneaux", true)
	local top = 0.8 + 12
	local crystal = block(m, "CristalFlottant", V(1.3, 2.6, 1.3), hex("#7FD0FF"), CFrame.new(at + V(0, top + 3.2, 0)) * CFrame.Angles(0, math.pi / 4, 0),
		Enum.Material.Neon)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = crystal
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = hex("#7FD0FF"), 14, 1
	l.Parent = crystal
	ring(m, "AnneauArcane", at + V(0, top + 2.6, 0), 1.8, 10, V(0.25, 0.2, 1.1), C.Gold, Enum.Material.Metal)
	ring(m, "AnneauArcane", at + V(0, top + 3.9, 0), 1.4, 8, V(0.25, 0.2, 1.1), C.GoldLight, Enum.Material.Metal)
end

-- Cathédrale : nef de pierre à toit bleu et faîtage d'or, haute tour-clocher à flèche dorée, rosace lumineuse
local function cathedral(parent: Instance, at: Vector3, w: number, d: number)
	local m = house(parent, "Cathedrale", at, 0, w, d, 4.6, C.Blue, C.Stone)
	local base = CFrame.new(at)
	block(m, "FaitageOr", V(w + 0.6, 0.3, 0.3), C.Gold, base * CFrame.new(0, 0.5 + 4.6 + math.min(w, d) * 0.55, 0), Enum.Material.Metal)
	local towerAt = (base * CFrame.new(0, 0, -d / 2 - 1.2)).Position
	stoneTower(m, "Clocher", towerAt, 2.8, 9.5, "Pyramide", true)
	local rose = block(m, "Rosace", V(1.6, 1.6, 0.15), C.Glow, CFrame.new(towerAt + V(0, 6.2, -1.48)), Enum.Material.Neon)
	rose.Shape = Enum.PartType.Cylinder
	rose.CFrame = FRAME * CFrame.new(towerAt + V(0, 6.2, -1.48)) * rotY(math.pi / 2)
	rose.Size = V(0.15, 1.6, 1.6)
	diamond(m, CFrame.new(towerAt + V(0, 3.4, -1.48)), 0.8)
	for _, x in { -1, 1 } do
		block(m, "Contrefort", V(0.6, 3.6, 0.9), C.StoneDark, base * CFrame.new(x * (w / 2 + 0.3), 2.3, d * 0.15))
	end
end

-- Palais du roi : grand corps de pierre à bandeaux d'or, étage, dôme d'or, flèche et étendard, tourelles dorées
local function palace(parent: Instance, at: Vector3)
	local m = stoneTower(parent, "Palais", at, 7.2, 9, "Creneaux", true)
	local base = CFrame.new(at)
	local top = 0.8 + 9
	for _, c in { V(-1, 0, -1), V(1, 0, -1), V(-1, 0, 1), V(1, 0, 1) } do
		local p = c * 3.6
		local t = group(m, "TourelleDoree")
		local tb = CFrame.new(at + V(p.X, top - 3, p.Z))
		block(t, "FutTourelle", V(1.9, 3.6, 1.9), C.Stone, tb * CFrame.new(0, 1.8, 0))
		block(t, "BandeauTourelle", V(2.2, 0.35, 2.2), C.Gold, tb * CFrame.new(0, 3.6, 0), Enum.Material.Metal)
		pyramid(t, "ToitDore", tb * CFrame.new(0, 3.75, 0), 2.6, 2.6, C.Gold)
	end
	local hall = stoneTower(m, "EtagePalais", at + V(0, top, 0), 4.8, 4.5, "Creneaux", true)
	hall.Name = "EtagePalais"
	local dome = block(m, "DomeOr", V(4.6, 4, 4.6), C.Gold, base * CFrame.new(0, top + 0.8 + 4.5 + 1.2, 0), Enum.Material.Metal)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = dome
	block(m, "Fleche", V(0.35, 3.2, 0.35), C.GoldLight, base * CFrame.new(0, top + 0.8 + 4.5 + 4.6, 0), Enum.Material.Metal)
	banner(m, base * CFrame.new(0, top + 0.8 + 4.5 + 6.2, 0), 2.6, 1.3)
	block(m, "PortePalais", V(2, 3.2, 0.2), C.WoodMid, base * CFrame.new(0, 2.4, -3.68))
	block(m, "ArcPalais", V(2.8, 0.6, 0.3), C.Gold, base * CFrame.new(0, 4.2, -3.7), Enum.Material.Metal)
	block(m, "TenturePalais", V(2.8, 3.4, 0.1), C.Blue, base * CFrame.new(0, 6.6, -3.7))
	diamond(m, base * CFrame.new(0, 6.6, -3.78), 1.2)
	local heart = block(m, "CoeurRoyal", V(0.9, 0.9, 0.9), C.Glow, base * CFrame.new(0, top + 0.8 + 2.6, -2.45), Enum.Material.Neon)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = C.Glow, 12, 0.9
	l.Parent = heart
end

local function destroyNamed(root: Instance, names: { [string]: boolean })
	for _, d in root:GetChildren() do
		if names[d.Name] then d:Destroy() end
	end
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

-- 9 · Cité royale : île élargie, tours latérales, grande salle du palais, piliers royaux à l'entrée
BUILD[9] = function(root, from)
	widenIsland(root, 1.1)
	for _, x in { -1, 1 } do
		local at = V(x * MUR_R, 0, 0)
		clear(root, at, 2.6, { nature = true })
		stoneTower(root, "TourRempart", at, 3, 7.5, "Pyramide", true)
	end
	destroyNamed(root, { MaisonNeuve = true })
	local hall = house(root, "GrandeSalle", V(4.4, 0, 9.8), 0, 5, 4, 4.2, C.Blue, C.Stone)
	block(hall, "FaitageOr", V(5.6, 0.3, 0.3), C.Gold, CFrame.new(4.4, 0.5 + 4.2 + 4 * 0.55, 9.8), Enum.Material.Metal)
	for _, x in { -2.9, 2.9 } do
		royalPillar(root, V(x, 0, -16.9))
	end
end

-- 10 · Capitale : douves et pont devant la porte, cathédrale à rosace
BUILD[10] = function(root, from)
	local moat = group(root, "Douves")
	local gap = math.asin(3.6 / 16.8) -- passage du pont, entre les piliers royaux
	local steps = 40
	for i = 0, steps - 1 do
		local a0 = i * 2 * math.pi / steps
		local a1 = (i + 1) * 2 * math.pi / steps
		local mid = (a0 + a1) / 2
		if math.abs(mid - 1.5 * math.pi) > gap + 0.08 then
			local pa, pb = V(16.8 * math.cos(a0), 0, 16.8 * math.sin(a0)), V(16.8 * math.cos(a1), 0, 16.8 * math.sin(a1))
			local d = pb - pa
			block(moat, "Eau", V(1.5, 0.12, d.Magnitude + 0.3), hex("#5AA8DC"), CFrame.new((pa + pb) / 2 + V(0, 0.08, 0)) * rotY(math.atan2(d.X, d.Z)))
		end
	end
	local bridge = group(root, "Pont")
	block(bridge, "Tablier", V(3.4, 0.35, 2.6), C.Wood, CFrame.new(0, 0.2, -16.8))
	for _, x in { -1.6, 1.6 } do
		block(bridge, "Garde", V(0.2, 0.6, 2.6), C.WoodDark, CFrame.new(x, 0.6, -16.8))
	end
	destroyNamed(root, { Chapelle = true, Moulin = true, atelier_bucheron = true })
	clear(root, V(-7, 0, 3), 3.6, { nature = true })
	cathedral(root, V(-7, 0, 3.2), 4.4, 5.6)
end

-- 11 · Royaume radieux : tour des mages, statue d'or du roi sur la place, lanternes flottantes
BUILD[11] = function(root, from)
	destroyNamed(root, { TourGuetPierre = true, feu_de_camp = true })
	arcaneTower(root, V(-5.2, 0, -9.9))
	kingStatue(root, V(0.2, 0, -2.6))
	local lanterns = group(root, "LanternesFlottantes")
	for i = 0, 7 do
		local a = i * math.pi / 4 + 0.3
		local lantern = block(lanterns, "Lanterne", V(0.6, 0.8, 0.6), C.Glow, CFrame.new(math.cos(a) * 10, 15 + (i % 3) * 1.4, math.sin(a) * 10),
			Enum.Material.Neon)
		if i % 3 == 0 then
			local l = Instance.new("PointLight")
			l.Color, l.Range, l.Brightness = C.Glow, 8, 0.6
			l.Parent = lantern
		end
	end
end

-- 12 · Palais du roi : palais à dôme d'or, chemin de ronde doré, grand emblème sur la porte
BUILD[12] = function(root, from)
	destroyNamed(root, { Donjon = true })
	clear(root, V(-1.6, 0, 8.8), 4.4, { reserves = true })
	palace(root, V(-1.6, 0, 8.8))
	local wallFolder = root:FindFirstChild("Rempart")
	for _, d in (if wallFolder then wallFolder:GetChildren() else {}) do
		if d:IsA("BasePart") and d.Name == "ChemineRonde" then
			d.Color, d.Material = C.Gold, Enum.Material.Metal
		end
	end
	local gate = root:FindFirstChild("PorteFortifiee")
	if gate then
		block(gate, "Fronton", V(3, 2.8, 0.4), C.Stone, CFrame.new(0, 7.7, -MUR_R - 1))
		block(gate, "CadreFronton", V(3.3, 0.3, 0.45), C.Gold, CFrame.new(0, 9.15, -MUR_R - 1), Enum.Material.Metal)
		diamond(gate, CFrame.new(0, 7.7, -MUR_R - 1.25), 1.6)
	end
end

-- Passerelle de pierre entre deux points en hauteur : tablier, garde-corps dorés, arc de soutien
local function skybridge(parent: Instance, a: Vector3, b: Vector3)
	local m = group(parent, "Passerelle")
	local d = b - a
	local len = V(d.X, 0, d.Z).Magnitude
	local cf = CFrame.new((a + b) / 2) * rotY(math.atan2(d.X, d.Z))
	block(m, "Tablier", V(1.6, 0.5, len), C.Stone, cf)
	for _, x in { -0.75, 0.75 } do
		block(m, "GardeCorps", V(0.15, 0.6, len), C.Gold, cf * CFrame.new(x, 0.55, 0), Enum.Material.Metal)
	end
	block(m, "Arc", V(1.2, 0.9, len * 0.7), C.StoneDark, cf * CFrame.new(0, -0.7, 0))
end

-- Fontaine royale : bassin de pierre cerclé d'or, eau, colonne d'or et gerbe
local function fountain(parent: Instance, at: Vector3)
	local m = group(parent, "FontaineRoyale")
	local base = CFrame.new(at)
	local FLAT = CFrame.Angles(0, 0, math.pi / 2)
	local basin = block(m, "Bassin", V(0.8, 3.4, 3.4), C.Stone, base * CFrame.new(0, 0.4, 0) * FLAT)
	basin.Shape = Enum.PartType.Cylinder
	local water = block(m, "Eau", V(0.1, 2.8, 2.8), hex("#5AA8DC"), base * CFrame.new(0, 0.82, 0) * FLAT)
	water.Shape = Enum.PartType.Cylinder
	ring(m, "Margelle", at + V(0, 0.85, 0), 1.65, 12, V(0.25, 0.15, 0.95), C.Gold, Enum.Material.Metal)
	block(m, "ColonneFontaine", V(0.5, 1.8, 0.5), C.Gold, base * CFrame.new(0, 1.7, 0), Enum.Material.Metal)
	local spray = block(m, "Gerbe", V(1.1, 0.9, 1.1), hex("#9FD8FF"), base * CFrame.new(0, 2.8, 0), Enum.Material.Neon)
	spray.Shape = Enum.PartType.Ball
	spray.Transparency = 0.25
end

-- Jardins suspendus : buissons et fleurs posés sur le chemin de ronde de l'arc du fond
local function hangingGardens(parent: Instance, h: number)
	local m = group(parent, "JardinsSuspendus")
	for i = 0, 10 do
		local t = math.rad(35 + i * 11)
		local at = V(MUR_R * math.cos(t), h + 0.6, MUR_R * math.sin(t))
		local bush = block(m, "Buisson", V(1.1, 0.9, 1.1), if i % 2 == 0 then C.Green else hex("#408E4A"), CFrame.new(at))
		bush.Shape = Enum.PartType.Ball
		if i % 3 == 1 then
			local flower = block(m, "Fleur", V(0.35, 0.35, 0.35), if i % 2 == 0 then hex("#EC78A0") else C.Glow, CFrame.new(at + V(0.2, 0.45, 0)))
			flower.Shape = Enum.PartType.Ball
		end
	end
end

-- Chevalier gardien géant : socle, armure de pierre, cape bleue, bouclier au losange d'or, épée d'or plantée
local function guardian(parent: Instance, at: Vector3, yaw: number)
	local m = group(parent, "Gardien")
	local base = CFrame.new(at) * rotY(yaw)
	block(m, "SocleGardien", V(2, 0.6, 2), C.StoneDark, base * CFrame.new(0, 0.3, 0))
	block(m, "Jambes", V(1.3, 1.8, 0.8), C.Stone, base * CFrame.new(0, 1.5, 0))
	block(m, "Torse", V(1.7, 1.8, 1), C.StoneLight, base * CFrame.new(0, 3.3, 0))
	block(m, "Cape", V(1.8, 3, 0.2), C.Blue, base * CFrame.new(0, 2.8, 0.6))
	for _, s in { -1, 1 } do
		block(m, "Epauliere", V(0.8, 0.5, 1.1), C.Gold, base * CFrame.new(s * 1, 4.1, 0), Enum.Material.Metal)
	end
	local head = block(m, "Heaume", V(0.9, 1, 0.9), C.StoneLight, base * CFrame.new(0, 4.75, 0))
	head.Shape = Enum.PartType.Ball
	block(m, "Cimier", V(0.2, 0.6, 0.8), C.Gold, base * CFrame.new(0, 5.35, 0), Enum.Material.Metal)
	block(m, "Bouclier", V(1.2, 1.6, 0.2), C.Blue, base * CFrame.new(-1.05, 3, -0.45))
	diamond(m, base * CFrame.new(-1.05, 3, -0.57), 0.6)
	block(m, "Epee", V(0.25, 3, 0.12), C.Gold, base * CFrame.new(0.95, 2.2, -0.5), Enum.Material.Metal)
	block(m, "GardeEpee", V(0.9, 0.18, 0.18), C.Gold, base * CFrame.new(0.95, 3.75, -0.5), Enum.Material.Metal)
end

-- 13 · Cité haute : passerelles du palais aux tours du fond, jardins suspendus, fontaine royale
BUILD[13] = function(root, from)
	-- sous le bandeau des tours du fond (fût de 7,5) et au-dessus du toit de la grande salle
	for _, x in { -1, 1 } do
		local towerAt = V(x * 7.3, 0, 12.6)
		skybridge(root, V(-1.6 + x * 3.6, 7.4, 9.6), V(towerAt.X - x * 1.5, 7.4, towerAt.Z - 0.6))
	end
	hangingGardens(root, 3.2)
	fountain(root, V(-0.2, 0, -8.6))
end

-- 14 · Empire du roi : chevaliers gardiens sur le rempart de part et d'autre de la porte, couronne d'or
-- flottante autour de la flèche du palais
BUILD[14] = function(root, from)
	for _, s in { -1, 1 } do
		local t = 1.5 * math.pi + s * 0.55
		local at = V(MUR_R * math.cos(t), 3.45, MUR_R * math.sin(t))
		guardian(root, at, s * 0.55)
	end
	local crown = group(root, "CouronneCeleste")
	local center = V(-1.6, 25.5, 8.8)
	ring(crown, "Anneau", center, 4.2, 16, V(0.3, 0.5, 1.8), C.Gold, Enum.Material.Metal)
	for i = 0, 7 do
		local a = i * math.pi / 4
		local spike = block(crown, "Fleuron", V(0.4, 1.2, 0.4), C.GoldLight, CFrame.new(center + V(math.cos(a) * 4.2, 0.8, math.sin(a) * 4.2)), Enum.Material.Metal)
		if i % 2 == 0 then
			local gem = block(crown, "Joyau", V(0.5, 0.5, 0.5), hex("#7FD0FF"), CFrame.new(center + V(math.cos(a) * 4.2, 1.6, math.sin(a) * 4.2)), Enum.Material.Neon)
			gem.Shape = Enum.PartType.Ball
		end
		spike.Name = "Fleuron"
	end
	local glow = block(crown, "Lumiere", V(0.6, 0.6, 0.6), C.Glow, CFrame.new(center), Enum.Material.Neon)
	glow.Transparency = 1
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = C.Glow, 16, 1
	l.Parent = glow
end

------------------------------------------------------------------ niveaux 15 à 20 : l'île ne peut plus s'élargir
-- (socle de 38, île de 35) : le royaume grandit vers le haut et s'enrichit, toujours dans la même palette.

local WATER = hex("#5AA8DC")

-- Cascade : l'eau des jardins du rempart déborde par-dessus le chemin de ronde et tombe dans les douves
local function waterfall(parent: Instance, angle: number, width: number)
	local m = group(parent, "Cascade")
	local out = V(math.cos(angle), 0, math.sin(angle))
	local yaw = math.atan2(out.X, out.Z)
	local frame = CFrame.new(out * (MUR_R + 1.15) + V(0, 1.75, 0)) * rotY(yaw) -- Z local : vers l'extérieur
	block(m, "Deversoir", V(width + 0.5, 0.35, 1.2), C.StoneLight, CFrame.new(out * (MUR_R + 0.4) + V(0, 3.45, 0)) * rotY(yaw))
	local sheet = block(m, "Chute", V(width, 3.6, 0.3), WATER, frame * CFrame.Angles(0.28, 0, 0), Enum.Material.Glass)
	sheet.Transparency = 0.12
	for k = -1, 1 do
		local streak = block(m, "Filet", V(0.18, 3.4, 0.08), hex("#C8ECFF"), frame * CFrame.Angles(0.28, 0, 0) * CFrame.new(k * width * 0.3, 0, 0.18), Enum.Material.Neon)
		streak.Transparency = 0.3
	end
	for k = -2, 2 do
		local foam = block(m, "Ecume", V(1.1, 0.6, 1.1), hex("#E6F6FF"), CFrame.new(out * 16.6 + V(0, 0.25, 0)) * rotY(yaw) * CFrame.new(k * width * 0.22, 0, 0))
		foam.Shape = Enum.PartType.Ball
	end
end

-- Bannière tombante sur la face extérieure du rempart : longue tenture bleue, bordure et losange d'or
local function wallBanner(parent: Instance, angle: number, h: number)
	local m = group(parent, "TentureRempart")
	local out = V(math.cos(angle), 0, math.sin(angle))
	local cf = CFrame.new(out * (MUR_R + 0.68) + V(0, h - 1.6, 0)) * rotY(math.atan2(out.X, out.Z))
	block(m, "Tenture", V(1.4, 3, 0.1), C.Blue, cf)
	block(m, "Bordure", V(1.5, 0.2, 0.12), C.Gold, cf * CFrame.new(0, 1.45, 0), Enum.Material.Metal)
	part(m, "Pointe", "WedgePart", V(1.4, 0.7, 0.1), C.Blue, cf * CFrame.new(0, -1.85, 0) * CFrame.Angles(math.pi, 0, 0))
	diamond(m, cf * CFrame.new(0, 0.3, 0.08), 0.6)
end

-- Arche fleurie sur l'allée : deux poteaux, arc de verdure, fleurs
local function flowerArch(parent: Instance, z: number)
	local m = group(parent, "ArcheFleurie")
	for _, x in { -1.9, 1.9 } do
		block(m, "Poteau", V(0.3, 3.2, 0.3), C.WoodDark, CFrame.new(x, 1.6, z))
	end
	for i = 0, 6 do
		local a = math.pi * i / 6
		local leaf = block(m, "Verdure", V(0.9, 0.9, 0.9), if i % 2 == 0 then C.Green else hex("#408E4A"), CFrame.new(-1.9 * math.cos(a), 3.2 + 1.3 * math.sin(a), z))
		leaf.Shape = Enum.PartType.Ball
		if i % 2 == 1 then
			local f = block(m, "Fleur", V(0.4, 0.4, 0.4), if i == 3 then C.Glow else hex("#EC78A0"), CFrame.new(-1.9 * math.cos(a), 3.2 + 1.3 * math.sin(a), z - 0.45))
			f.Shape = Enum.PartType.Ball
		end
	end
end

-- Îlot flottant : roche en cône renversé, herbe, petite tour à toit bleu, chaîne d'or vers le royaume
local function floatingIslet(parent: Instance, at: Vector3, r: number, anchor: Vector3)
	local m = group(parent, "IlotFlottant")
	local grass = block(m, "HerbeIlot", V(0.5, r * 2, r * 2), C.Green, CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2))
	grass.Shape = Enum.PartType.Cylinder
	for k = 0, 3 do
		local rock = block(m, "Roche", V(r * (1.8 - k * 0.4), 1.3, r * (1.8 - k * 0.4)), if k % 2 == 0 then C.Stone else C.StoneDark,
			CFrame.new(at - V(0, 0.9 + k * 1.1, 0)) * rotY(k * 0.5))
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = rock
	end
	stoneTower(m, "TourIlot", at + V(0, 0.25, 0), r * 0.7, r * 1.4, "Pyramide", true)
	local d = anchor - at
	local steps = math.floor(d.Magnitude / 0.8)
	for i = 1, steps - 1 do
		local p = at + d * (i / steps) - V(0, math.sin(math.pi * i / steps) * 1.2, 0)
		block(m, "Maillon", if i % 2 == 0 then V(0.18, 0.5, 0.35) else V(0.35, 0.5, 0.18), C.Gold, CFrame.lookAt(p, p + d), Enum.Material.Metal)
	end
end

-- Faisceau de lumière (colonne lumineuse) d'un point à un autre
local function beam(parent: Instance, a: Vector3, b: Vector3, w: number, color: Color3)
	local d = b - a
	local p = block(parent, "Faisceau", V(w, w, d.Magnitude), color, CFrame.lookAt((a + b) / 2, b), Enum.Material.Neon)
	p.Transparency = 0.45
	return p
end

-- 15 · Royaume des cascades : l'eau des jardins déborde du rempart en cascades dans les douves, tentures,
-- arche fleurie à l'entrée de la place
BUILD[15] = function(root, from)
	local falls = group(root, "Cascades")
	for _, a in { 1.5 * math.pi - 0.75, 1.5 * math.pi + 0.75, 0.52, math.pi - 0.52 } do -- entre les tours du rempart
		waterfall(falls, a, 2.6)
	end
	local banners = group(root, "Tentures")
	for _, a in { 1.5 * math.pi - 0.42, 1.5 * math.pi + 0.42, 1.5 * math.pi - 1.05, 1.5 * math.pi + 1.05 } do
		wallBanner(banners, a, 3.2)
	end
	flowerArch(root, -11.4)
end

-- 16 · Royaume des îles célestes : trois îlots flottants à tours dorées, enchaînés aux tours du royaume
BUILD[16] = function(root, from)
	local islets = group(root, "IlesCelestes")
	floatingIslet(islets, V(-13, 15, 2), 2.6, V(-MUR_R, 9, 0))
	floatingIslet(islets, V(13, 17, 3), 2.6, V(MUR_R, 9, 0))
	floatingIslet(islets, V(0, 19, 17), 3, V(-1.6, 15.5, 12.4))
end

-- 17 · Royaume des arcanes : cœur de cristal géant au-dessus de la couronne, faisceaux vers les îlots et
-- la tour des mages, cercle de runes lumineuses sur la place
BUILD[17] = function(root, from)
	local arcane = group(root, "Arcanes")
	local heartAt = V(-1.6, 31, 8.8)
	local heart = block(arcane, "CoeurDeCristal", V(2.6, 4.6, 2.6), hex("#7FD0FF"), CFrame.new(heartAt) * rotY(math.pi / 4), Enum.Material.Neon)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = heart
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = hex("#7FD0FF"), 22, 1.2
	l.Parent = heart
	for k, r in { 2.4, 3.2 } do
		ring(arcane, "AnneauCristal", heartAt + V(0, (k - 1.5) * 1.6, 0), r, 12, V(0.25, 0.2, 1.3), if k == 1 then C.Gold else C.GoldLight, Enum.Material.Metal)
	end
	for _, p in { V(-13, 18, 2), V(13, 20, 3), V(0, 23, 17), V(-5.2, 16, -9.9) } do
		beam(arcane, heartAt, p, 0.3, hex("#9FE0FF"))
	end
	for i = 0, 11 do
		local a = i * math.pi / 6
		local rune = block(arcane, "Rune", V(0.7, 0.08, 0.7), hex("#7FD0FF"), CFrame.new(0.2 + math.cos(a) * 3.4, 0.06, -2.6 + math.sin(a) * 3.4) * rotY(a + math.pi / 4),
			Enum.Material.Neon)
		rune.Transparency = 0.2
	end
end

-- 18 · Âge d'or : arc de triomphe d'or sur le pont (à la place des piliers royaux), tours du rempart coiffées d'or
BUILD[18] = function(root, from)
	destroyNamed(root, { PilierRoyal = true })
	local arch = group(root, "ArcDeTriomphe")
	local z = -16.9
	for _, x in { -3.4, 3.4 } do
		block(arch, "PileArc", V(2, 7, 2.2), C.Stone, CFrame.new(x, 3.5, z))
		block(arch, "BandeauPile", V(2.2, 0.35, 2.4), C.Gold, CFrame.new(x, 6.9, z), Enum.Material.Metal)
		block(arch, "Colonne", V(0.5, 6, 0.5), C.Gold, CFrame.new(x + (if x < 0 then 1.05 else -1.05), 3.3, z - 1.2), Enum.Material.Metal)
	end
	block(arch, "Attique", V(9, 2.4, 2.4), C.Stone, CFrame.new(0, 8.3, z))
	block(arch, "FriseArc", V(9.2, 0.35, 2.6), C.Gold, CFrame.new(0, 9.6, z), Enum.Material.Metal)
	block(arch, "TentureArc", V(3, 1.8, 0.1), C.Blue, CFrame.new(0, 8.3, z - 1.25))
	diamond(arch, CFrame.new(0, 8.3, z - 1.32), 1)
	kingStatue(arch, V(0, 9.8, z))
	for _, d in root:GetChildren() do
		if d.Name == "TourRempart" then
			for _, p in d:GetDescendants() do
				if p:IsA("BasePart") and p.Name == "ToitTour" then p.Color, p.Material = C.Gold, Enum.Material.Metal end
			end
		end
	end
end

-- 19 · Royaume ailé : immenses ailes d'or déployées derrière le palais, auréole dorée
BUILD[19] = function(root, from)
	local wings = group(root, "AilesRoyales")
	local center = V(-1.6, 17, 13.2)
	for _, s in { -1, 1 } do
		for k = 0, 8 do -- os de l'aile : arc qui part du palais et s'élève vers l'extérieur
			local x = 2 + k * 1.5
			local y = k * 1.35 - k * k * 0.07
			block(wings, "ArcAile", V(1.7, 0.6, 0.5), C.Gold, CFrame.new(center + V(s * x, y, 0)) * CFrame.Angles(0, 0, s * (0.75 - k * 0.09)), Enum.Material.Metal)
			-- plumes pendantes sous l'arc, plus longues au milieu de l'aile
			local len = 3 + math.sin(math.pi * (k + 1) / 10) * 5
			block(wings, "Plume", V(1.25, len, 0.3), if k % 2 == 0 then C.Gold else C.GoldLight,
				CFrame.new(center + V(s * x, y, 0.1)) * CFrame.Angles(0, 0, s * (0.25 + k * 0.05)) * CFrame.new(0, -len / 2, 0), Enum.Material.Metal)
		end
		for k = 0, 3 do -- petites plumes de couverture au-dessus de l'arc
			block(wings, "PlumeCourte", V(0.9, 2.2, 0.25), C.GoldLight,
				CFrame.new(center + V(s * (3 + k * 2.4), 1.6 + k * 1.8 - k * k * 0.12, -0.2)) * CFrame.Angles(0, 0, -s * 0.5), Enum.Material.Metal)
		end
	end
	local halo = center + V(0, 12, 0.6) -- auréole verticale, face à l'entrée
	for i = 0, 17 do
		local a = i * math.pi * 2 / 18
		block(wings, "Aureole", V(1.4, 0.6, 0.3), C.Glow, CFrame.new(halo + V(math.cos(a) * 4, math.sin(a) * 4, 0)) * CFrame.Angles(0, 0, a + math.pi / 2), Enum.Material.Neon)
	end
end

-- 20 · Royaume légendaire : citadelle céleste flottant au-dessus du royaume, reliée par une colonne de lumière
BUILD[20] = function(root, from)
	local sky = group(root, "CitadelleCeleste")
	local at = V(-1.6, 40, 8.8)
	for k = 0, 4 do -- roche flottante en cône renversé
		local rock = block(sky, "RocheCeleste", V(9 - k * 1.7, 1.6, 9 - k * 1.7), if k % 2 == 0 then C.Stone else C.StoneDark,
			CFrame.new(at - V(0, 0.8 + k * 1.4, 0)) * rotY(k * 0.4))
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = rock
	end
	local grass = block(sky, "HerbeCeleste", V(0.5, 9, 9), C.Green, CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2))
	grass.Shape = Enum.PartType.Cylinder
	stoneTower(sky, "SanctuaireCeleste", at + V(0, 0.25, 0), 3.6, 4, "Creneaux", true)
	for _, c in { V(-1, 0, -1), V(1, 0, -1), V(-1, 0, 1), V(1, 0, 1) } do
		stoneTower(sky, "TourelleCeleste", at + c * 3 + V(0, 0.25, 0), 1.4, 3.4, "Pyramide", true)
	end
	local dome = block(sky, "DomeCeleste", V(3.4, 3, 3.4), C.Gold, CFrame.new(at + V(0, 6.4, 0)), Enum.Material.Metal)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = dome
	banner(sky, CFrame.new(at + V(0, 7.8, 0)), 3, 1.2)
	local column = beam(sky, V(-1.6, 27, 8.8), at - V(0, 7, 0), 1.6, C.Glow)
	column.Transparency = 0.55
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = C.Glow, 20, 1
	l.Parent = column
	for i = 0, 9 do -- étoiles autour de la citadelle
		local a = i * math.pi / 5
		local star = block(sky, "Etoile", V(0.5, 0.5, 0.5), C.GoldLight, CFrame.new(at + V(math.cos(a) * 7, 2 + (i % 3) * 1.5, math.sin(a) * 7)) * CFrame.Angles(0.6, a, 0.6),
			Enum.Material.Neon)
		star.Name = "Etoile"
	end
end

local built = {}
for n = FIRST, LAST do
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
	local root = model:FindFirstChild(string.format("royaume_niveau_%02d", n - 1)) or model
	root.Name = string.format("royaume_niveau_%02d", n)
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
