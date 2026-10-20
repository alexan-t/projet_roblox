-- À exécuter une fois dans Studio EDIT (barre de commande). Assets uniquement, aucun Source de script.
-- Agrandit les parcelles pour les combats (docs/PLOTS.md § Agrandissement) : plus longues côté
-- ennemis, un peu plus larges au bord. Héros, pancarte, porche, royaume et portail ne bougent pas.
-- Répétable : une parcelle déjà agrandie (attribut AgrandiCombat) est ignorée. Une étape Ctrl+Z.
-- APPLIQUER = false : mesure et vérifie (voisins, forêt, limites) sans rien modifier.
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ServerStorage = game:GetService("ServerStorage")

local APPLIQUER = true
local VERSION = 1
local LONGUEUR = 20 -- studs ajoutés entre les dalles des héros et le front ennemi
local ELARGISSEMENT = 5 -- studs ajoutés de chaque côté, au bord de la parcelle
local AXE_FIXE = 30 -- à moins de cette distance de l'axe, rien ne s'écarte (dalles, front, porche)
local BANDE_BORD = 44 -- au-delà : rempart, bordure, arbres du bord, recopiés dans la longueur ajoutée
local GRAND_MODELE = 24 -- un modèle plus petit qui chevauche la coupe bouge d'un bloc
local MARGE_FORET = 8
local ECART_MIN_VOISINS = 4
local ENTIERS = { Royaume = true, PortailInvocation = true, PanneauProprietaire = true, PanneauStage = true }
local IGNORES = { Emplacements = true, Runtime = true }

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z).Unit
end

local function extents(frame: CFrame, cf: CFrame, size: Vector3): (Vector3, Vector3)
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, sx in { -0.5, 0.5 } do
		for _, sy in { -0.5, 0.5 } do
			for _, sz in { -0.5, 0.5 } do
				local p = frame:PointToObjectSpace(cf:PointToWorldSpace(size * Vector3.new(sx, sy, sz)))
				lo, hi = lo:Min(p), hi:Max(p)
			end
		end
	end
	return lo, hi
end

local function closestAxis(cf: CFrame, dir: Vector3): (number, number)
	local best, score = 1, 0
	for i, axis in { cf.XVector, cf.YVector, cf.ZVector } do
		local s = math.abs(axis:Dot(dir))
		if s > score then best, score = i, s end
	end
	return best, score
end

local function withAxis(v: Vector3, i: number, value: number): Vector3
	return Vector3.new(i == 1 and value or v.X, i == 2 and value or v.Y, i == 3 and value or v.Z)
end

local function axisValue(v: Vector3, i: number): number
	return if i == 1 then v.X elseif i == 2 then v.Y else v.Z
end

-- Mesure une parcelle : repère du front ennemi (+Z vers les héros), axe du sol en « stade ».
local function survey(plot: Model)
	local arena = plot:FindFirstChild("Arene")
	local zones = arena and arena:FindFirstChild("Zones")
	local front
	for _, d in (zones and zones:GetDescendants() or {}) do
		if d.Name == "FrontEnnemi" and d:IsA("BasePart") then front = d end
	end
	assert(front, `{plot:GetFullName()} : FrontEnnemi absent`)
	local frame = CFrame.fromMatrix(front.Position, flat(front.CFrame.XVector), Vector3.yAxis)
	assert(plot:FindFirstChild("Sol"), `{plot:GetFullName()} : dossier Sol absent`)
	local layers = {}
	for _, d in plot.Sol:GetDescendants() do
		local a, c, b = d:FindFirstChild("BoutArriere"), d:FindFirstChild("Centre"), d:FindFirstChild("BoutAvant")
		if a and c and b then
			assert(a:IsA("Part") and b:IsA("Part") and c:IsA("Part"), `{d:GetFullName()} : pièces du sol attendues en Part`)
			assert(a.Shape == Enum.PartType.Cylinder and b.Shape == Enum.PartType.Cylinder, `{d:GetFullName()} : bouts non cylindriques`)
			table.insert(layers, {
				arriere = a, centre = c, avant = b,
				zA = frame:PointToObjectSpace(a.Position).Z, zB = frame:PointToObjectSpace(b.Position).Z,
				r = math.min(a.Size.Y, a.Size.Z) / 2,
			})
		end
	end
	assert(#layers > 0, `{plot:GetFullName()} : sol en stade introuvable (BoutArriere/Centre/BoutAvant)`)
	table.sort(layers, function(x, y) return x.r > y.r end)
	local ref = layers[1]
	local poses = {}
	for _, d in arena.Emplacements:GetDescendants() do
		if d.Name == "PointDePose" then table.insert(poses, frame:PointToObjectSpace(d.Position).Z) end
	end
	assert(#poses > 0 and math.min(table.unpack(poses)) > ref.zA + 5, `{plot:GetFullName()} : dalles trop près de la coupe`)
	local info = {
		plot = plot, arena = arena, front = front, frame = frame, layers = layers,
		zA = ref.zA, zB = ref.zB, r = ref.r, sx = frame:PointToObjectSpace(ref.arriere.Position).X,
		heroZ = math.min(table.unpack(poses)),
	}
	info.k = (ref.r + ELARGISSEMENT - AXE_FIXE) / (ref.r - AXE_FIXE)
	function info.map(d: number): number
		return if d <= AXE_FIXE then d else AXE_FIXE + (d - AXE_FIXE) * info.k
	end
	info.r2 = info.map(ref.r)
	-- Bout côté ennemis : écarté autour de son centre puis reculé. Ailleurs : écarté en X seulement.
	function info.point(l: Vector3): Vector3
		local x, z = l.X - info.sx, l.Z
		if z < info.zA then
			local d = math.sqrt(x * x + (z - info.zA) ^ 2)
			local s = if d > 1e-3 then info.map(d) / d else 1
			return Vector3.new(info.sx + x * s, l.Y, info.zA + (z - info.zA) * s - LONGUEUR)
		end
		return Vector3.new(info.sx + math.sign(x) * info.map(math.abs(x)), l.Y, z)
	end
	-- Axe du nouveau stade (le bout côté royaume garde sa pointe).
	info.a2 = info.zA - LONGUEUR
	info.b2 = info.zB - (info.r2 - info.r)
	return info
end

-- Recense ce qui bouge, sans rien modifier.
local function plan(info)
	local handled, units, stretched = {}, {}, {}
	for _, layer in info.layers do
		handled[layer.arriere], handled[layer.centre], handled[layer.avant] = true, true, true
	end
	local frame, zA = info.frame, info.zA
	local function walk(container: Instance)
		for _, child in container:GetChildren() do
			if handled[child] or (container == info.arena and IGNORES[child.Name]) then continue end
			if child:IsA("Folder") then
				walk(child)
			elseif child:IsA("Model") then
				local cf, size = child:GetBoundingBox()
				local lo, hi = extents(frame, cf, size)
				local crosses = lo.Z < zA and hi.Z > zA
				if child == info.arena or (crosses and not ENTIERS[child.Name] and math.max(hi.X - lo.X, hi.Z - lo.Z) >= GRAND_MODELE) then
					walk(child)
				else
					table.insert(units, { inst = child, center = frame:PointToObjectSpace(cf.Position) })
				end
			elseif child:IsA("BasePart") then
				local lo, hi = extents(frame, child.CFrame, child.Size)
				local center = frame:PointToObjectSpace(child.Position)
				local axis, score = closestAxis(child.CFrame, frame.ZVector)
				if lo.Z < zA and hi.Z > zA and child:IsA("Part") and child.Shape == Enum.PartType.Block
					and math.abs(center.X - info.sx) < BANDE_BORD and score > 0.9 then
					table.insert(stretched, { inst = child, center = center, axis = axis, grow = LONGUEUR / score })
				else
					table.insert(units, { inst = child, center = center })
				end
				walk(child)
			end
		end
	end
	walk(info.plot)
	local copies = {}
	for _, unit in units do
		local x, z = unit.center.X - info.sx, unit.center.Z
		if z >= zA and z < zA + LONGUEUR and math.abs(x) >= BANDE_BORD and not unit.inst.Parent:IsA("BasePart")
			and not unit.inst:FindFirstAncestor("SourcesEnnemis") then
			table.insert(copies, unit)
		end
	end
	return units, stretched, copies
end

local function apply(info, units, stretched, copies)
	local frame = info.frame
	local function delta(l: Vector3): Vector3
		return frame:VectorToWorldSpace(info.point(l) - l)
	end
	for _, unit in units do
		local d = delta(unit.center)
		if d.Magnitude < 1e-4 then continue end
		if unit.inst:IsA("Model") then unit.inst:PivotTo(unit.inst:GetPivot() + d) else unit.inst.CFrame += d end
	end
	for _, s in stretched do
		local part, c = s.inst, s.center
		local target = Vector3.new(info.sx + math.sign(c.X - info.sx) * info.map(math.abs(c.X - info.sx)), c.Y, c.Z - LONGUEUR / 2)
		local rotation = part.CFrame.Rotation
		part.Size = withAxis(part.Size, s.axis, axisValue(part.Size, s.axis) + s.grow)
		part.CFrame = CFrame.new(frame:PointToWorldSpace(target)) * rotation
	end
	local back = frame:VectorToWorldSpace(Vector3.new(0, 0, -LONGUEUR))
	for _, unit in copies do
		local copy = unit.inst:Clone()
		copy:SetAttribute("CopieAgrandissement", true)
		if copy:IsA("Model") then
			copy:PivotTo(copy:GetPivot() + back)
		else
			copy.CFrame += back
			for _, d in copy:GetDescendants() do
				if d:IsA("BasePart") then d.CFrame += back end
			end
		end
		copy.Parent = unit.inst.Parent
	end
	for _, layer in info.layers do
		local r2 = info.map(layer.r)
		local zB2 = layer.zB - (r2 - layer.r)
		for _, p in { { layer.arriere, layer.zA - LONGUEUR }, { layer.avant, zB2 } } do
			local part, z = p[1], p[2]
			local l = frame:PointToObjectSpace(part.Position)
			local rotation = part.CFrame.Rotation
			part.Size = Vector3.new(part.Size.X, r2 * 2, r2 * 2)
			part.CFrame = CFrame.new(frame:PointToWorldSpace(Vector3.new(l.X, l.Y, z))) * rotation
		end
		local centre = layer.centre
		local l = frame:PointToObjectSpace(centre.Position)
		local rotation = centre.CFrame.Rotation
		local wAxis = closestAxis(centre.CFrame, frame.XVector)
		local lAxis = closestAxis(centre.CFrame, frame.ZVector)
		local zLow = layer.zA - LONGUEUR
		local size = withAxis(centre.Size, wAxis, info.map(axisValue(centre.Size, wAxis) / 2) * 2)
		centre.Size = withAxis(size, lAxis, zB2 - zLow)
		centre.CFrame = CFrame.new(frame:PointToWorldSpace(Vector3.new(l.X, l.Y, (zLow + zB2) / 2))) * rotation
	end
	info.plot:SetAttribute("AgrandiCombat", VERSION)
	info.plot:SetAttribute("AgrandiLongueur", LONGUEUR)
	info.plot:SetAttribute("AgrandiLargeur", ELARGISSEMENT)
end

-- Distance au sol en stade (axe [a, b] en Z du repère, rayon r), dans le plan horizontal.
local function stadiumDistance(info, world: Vector3, a: number, b: number, r: number): number
	local l = info.frame:PointToObjectSpace(world)
	local cz = math.clamp(l.Z, a, b)
	return math.sqrt((l.X - info.sx) ^ 2 + (l.Z - cz) ^ 2) - r
end

local function segment(info): (Vector3, Vector3)
	return info.frame:PointToWorldSpace(Vector3.new(info.sx, 0, info.a2)), info.frame:PointToWorldSpace(Vector3.new(info.sx, 0, info.b2))
end

local function neighbourGap(a, b): number
	local a0, a1 = segment(a)
	local best = math.huge
	for i = 0, 60 do
		local p = a0:Lerp(a1, i / 60)
		best = math.min(best, stadiumDistance(b, p, b.a2, b.b2, b.r2))
	end
	return best - a.r2
end

-- Parcelles à traiter.
local targets = {}
if workspace:FindFirstChild("PlotTravail") then table.insert(targets, workspace.PlotTravail) end
local lobbyPlots = workspace:FindFirstChild("Lobby") and workspace.Lobby:FindFirstChild("Plots")
for _, plot in (lobbyPlots and lobbyPlots:GetChildren() or {}) do
	if plot:IsA("Model") and plot:FindFirstChild("Arene") then table.insert(targets, plot) end
end

local infos, report = {}, {}
for _, plot in targets do
	if plot:GetAttribute("AgrandiCombat") == VERSION then
		table.insert(report, `{plot.Name} : déjà agrandie, ignorée`)
		continue
	end
	local info = survey(plot)
	info.units, info.stretched, info.copies = plan(info)
	table.insert(infos, info)
end

-- Voisins : les sols agrandis ne doivent pas se toucher.
local lobbyInfos = {}
for _, info in infos do
	if info.plot.Parent == lobbyPlots then table.insert(lobbyInfos, info) end
end
local minGap = math.huge
for i, a in lobbyInfos do
	for j = i + 1, #lobbyInfos do
		minGap = math.min(minGap, neighbourGap(a, lobbyInfos[j]))
	end
end
if #lobbyInfos > 1 then
	table.insert(report, `écart minimal entre sols voisins après agrandissement : {math.floor(minGap * 10) / 10} studs`)
	assert(minGap >= ECART_MIN_VOISINS, "Parcelles voisines trop proches : rien n'a été modifié")
end

-- Forêt de bordure et limites dans la nouvelle emprise.
local forest = workspace:FindFirstChild("Lobby") and workspace.Lobby:FindFirstChild("Monde")
local trees, walls = {}, {}
if forest then
	local function inside(world: Vector3, margin: number, old: boolean): boolean
		for _, info in lobbyInfos do
			local a, b, r = info.a2, info.b2, info.r2
			if old then a, b, r = info.zA, info.zB, info.r end
			if stadiumDistance(info, world, a, b, r) < margin then return true end
		end
		return false
	end
	local foret = forest:FindFirstChild("ForetBordure")
	for _, tree in (foret and foret:GetDescendants() or {}) do
		if not (tree:IsA("Model") or (tree:IsA("BasePart") and tree.Parent:IsA("Folder"))) or tree.Parent:IsA("Model") then continue end
		local pos = if tree:IsA("Model") then tree:GetBoundingBox().Position else tree.Position
		if inside(pos, MARGE_FORET, false) and not inside(pos, MARGE_FORET, true) then table.insert(trees, tree) end
	end
	local limites = forest:FindFirstChild("Limites")
	for _, wall in (limites and limites:GetDescendants() or {}) do
		if wall:IsA("BasePart") and inside(wall.Position, math.max(wall.Size.X, wall.Size.Z) / 2, false) then table.insert(walls, wall:GetFullName()) end
	end
end

for _, info in infos do
	local welded = 0
	for _, unit in info.units do
		if unit.inst:IsA("BasePart") and #unit.inst:GetJoints() > 0 then welded += 1 end
	end
	if welded > 0 then warn(`{info.plot.Name} : {welded} pièces libres soudées, à vérifier après coup`) end
	table.insert(report, `{info.plot.Name} : {#info.units} éléments, {#info.stretched} étirés, {#info.copies} recopiés au bord ; `
		.. `écart héros-front {math.floor(info.heroZ)} -> {math.floor(info.heroZ + LONGUEUR)} studs ; `
		.. `sol {math.floor(info.r * 2)} x {math.floor(info.zB - info.zA + info.r * 2)} -> {math.floor(info.r2 * 2)} x {math.floor(info.b2 - info.a2 + info.r2 * 2)} studs`)
end
table.insert(report, `forêt : {#trees} arbres dans la nouvelle emprise, archivés ; limites dans l'emprise : {#walls}`)
if #walls > 0 then warn("Limites dans l'emprise :", table.concat(walls, ", ")) end

if APPLIQUER and #infos > 0 then
	local recording = ChangeHistoryService:TryBeginRecording("Agrandir les parcelles pour les combats")
	assert(recording, "Un autre enregistrement Studio est en cours : réessayer")
	local ok, err = pcall(function()
		local archive = ServerStorage:FindFirstChild("Archive_Plots") or Instance.new("Folder")
		archive.Name, archive.Parent = "Archive_Plots", ServerStorage
		local travail = workspace:FindFirstChild("PlotTravail")
		if travail and not travail:GetAttribute("AgrandiCombat") and not archive:FindFirstChild("PlotTravail_avant_agrandissement") then
			local copy = travail:Clone()
			copy.Name, copy.Parent = "PlotTravail_avant_agrandissement", archive
		end
		if #trees > 0 then
			local folder = archive:FindFirstChild("ForetBordure_plots_agrandis") or Instance.new("Folder")
			folder.Name, folder.Parent = "ForetBordure_plots_agrandis", archive
			for _, tree in trees do tree.Parent = folder end
		end
		for _, info in infos do apply(info, info.units, info.stretched, info.copies) end
	end)
	ChangeHistoryService:FinishRecording(recording, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
	assert(ok, err)
else
	table.insert(report, "APPLIQUER = false : aucune modification")
end
print(table.concat(report, "\n"))
return report
