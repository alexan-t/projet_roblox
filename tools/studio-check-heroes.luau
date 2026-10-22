--!strict
-- À exécuter en mode Edit (barre de commande ou MCP execute_luau). Lecture seule, ne modifie rien.
-- Vérifie que les corrections du contrôle des héros (docs/HEROES_QA.md) sont toujours en place :
--   1. les poses de l'épée (ArmeDroite = short_sword_geom) de l'Écuyer dans les séquences de jeu,
--      l'aperçu Attente et RBX_ANIMSAVES valent celles d'AnimationKit (styles Epee et Rempart) ;
--   2. le marqueur Impact tombe à l'instant prévu (Ultime : ANIMATION_IMPACT d'UltimateEffectController) ;
--   3. l'objet tenu des héros corrigés (#25, #47, #58) et l'épée et le bouclier de l'Écuyer touchent
--      bien un bras, au Bestiaire et dans la copie de jeu ; le cristal de #25 est une sphère ;
--   4. chaque copie de jeu (ServerStorage.Assets.Heros) est identique au modèle du Bestiaire ;
--   5. chaque objet tenu a sa Prise sur le Poing de son bras, son manche traverse le poing et le
--      croise en travers (au moins 45° de l'avant-bras, mesuré sur le maillage).
-- Les brouillons Brise-Braise (socles 10 et 11, hors catalogue) sont signalés « connu », sans compter.
-- Renvoie le nombre de problèmes : 0 = PASS.
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local TOLERANCE_DEGRES = 0.5
local TOLERANCE_STUDS = 0.01

-- Poses de l'épée attendues : { temps, { rx, ry, rz } } (degrés), copiées d'AnimationKit (Kit.Attacks).
-- Les clés absentes ici n'ont pas de weaponRight : l'épée y reste neutre.
local EPEE = {
	Impact = 0.2,
	Keys = { { 0, { 0, 0, 0 } }, { 0.12, { 0, 0, 0 } }, { 0.2, { 0, -20, 30 } }, { 0.3, { 0, -40, 0 } }, { 0.6, { 0, 0, 0 } } },
}
local REMPART = {
	Impact = 0.3,
	Keys = { { 0, { 0, 0, 0 } }, { 0.15, { 50, -20, 0 } }, { 0.3, { -30, -60, 10 } }, { 0.5, { -30, -60, 10 } }, { 0.9, { 0, 0, 0 } } },
}
-- Héros corrigés : socle, modèle, objet tenu (chemin depuis le modèle), écart toléré (studs).
-- Une arme tenue au poing doit entrer dans le bras (écart 0). Le bouclier de l'Écuyer est tenu par sa
-- poignée, poing plaqué au dos : écart mesuré 0,14 stud, lu comme tenu sur les captures.
-- Passation du 22 octobre : bouclier de #15 recollé à l'avant-bras, lance de #67 et marteaux de #05 et
-- #24 glissés le long du manche pour qu'il traverse le poing (le talon s'arrêtait sur le dessus).
local TENUS = {
	{ "Socle_01", "EcuyerDuRempart", "short_sword.short_sword_geom", 0 },
	{ "Socle_01", "EcuyerDuRempart", "shield.shield_geom", 0.2 },
	{ "Socle_05", "BrisePierre", "hammer.hammer_geom", 0 },
	{ "Socle_15", "ChevalierDuLierre", "shield.shield", 0.2 },
	{ "Socle_24", "ForgeronRunique", "marteau.marteau_body.marteau_geom", 0 },
	{ "Socle_67", "AureonPorteurDeLaPremiereAube", "equipement.Lance", 0 },
	{ "Socle_25", "PretresseAuxLucioles", "baton_fleur.baton_fleur_geom", 0 },
	{ "Socle_47", "TisseurDeDestins", "quenouille.quenouille_geom", 0 },
	{ "Socle_58", "ReineDuFirmamentDore", "sceptre.sceptre_geom", 0 },
}
local BROUILLONS = { Socle_10 = true, Socle_11 = true }

local problems: { string } = {}
local function check(ok: boolean, message: string)
	print(`{if ok then "OK  " else "KO  "} {message}`)
	if not ok then table.insert(problems, message) end
end

local function find(root: Instance?, path: string): Instance?
	local node = root
	for name in string.gmatch(path, "[^%.]+") do
		node = node and node:FindFirstChild(name)
	end
	return node
end

-- 1 et 2. Séquences de l'Écuyer.
local function checkSequence(label: string, sequence: Instance?, expected: typeof(EPEE), extraLast: number?)
	if not (sequence and sequence:IsA("KeyframeSequence")) then
		check(false, `{label} : séquence introuvable`)
		return
	end
	local keyframes = sequence:GetKeyframes()
	table.sort(keyframes, function(a, b) return (a :: Keyframe).Time < (b :: Keyframe).Time end)
	local wanted = #expected.Keys + (if extraLast then 1 else 0)
	check(#keyframes == wanted, `{label} : {#keyframes} clés ({wanted} attendues)`)
	local impact: number? = nil
	for index, keyframe in keyframes do
		local time = (keyframe :: Keyframe).Time
		if keyframe:FindFirstChild("Impact") then impact = time end
		local entry = expected.Keys[index]
		local angles = if entry then entry[2] else { 0, 0, 0 }
		local pose = keyframe:FindFirstChild("short_sword_geom", true)
		if not (pose and pose:IsA("Pose")) then
			check(false, `{label} t={time} : pose de l'épée absente`)
			continue
		end
		local x, y, z = pose.CFrame:ToEulerAnglesXYZ()
		local got = { math.deg(x), math.deg(y), math.deg(z) }
		local ok = true
		for axis = 1, 3 do
			if math.abs(got[axis] - angles[axis]) > TOLERANCE_DEGRES then ok = false end
		end
		check(ok, string.format("%s t=%.2f : épée %.0f, %.0f, %.0f (attendu %d, %d, %d)", label, time,
			got[1], got[2], got[3], angles[1], angles[2], angles[3]))
	end
	check(impact ~= nil and math.abs(impact - expected.Impact) < 1e-3, `{label} : Impact à {impact} ({expected.Impact} attendu)`)
end

local animations = find(ReplicatedStorage, "Assets.Animations")
local saves = ServerStorage:FindFirstChild("RBX_ANIMSAVES")
checkSequence("Attaque (jeu)", find(animations, "EcuyerDuRempart.Attaque"), EPEE)
checkSequence("Ultime (jeu)", find(animations, "EcuyerDuRempart.Ultime"), REMPART)
-- L'aperçu Attente rejoue l'Attaque puis tient la pose neutre jusqu'à 1,4 s : une clé de plus.
checkSequence("Attente (aperçu)", find(animations, "Apercu_EcuyerDuRempart.Attente"), EPEE, 1.4)
checkSequence("Attaque (RBX_ANIMSAVES)", find(saves, "EcuyerDuRempart.Attaque"), EPEE)
checkSequence("Ultime (RBX_ANIMSAVES)", find(saves, "EcuyerDuRempart.Ultime"), REMPART)

-- 3. Objets tenus : la pièce doit entrer dans un bras (même test que la mesure de prise du rapport),
-- sinon l'écart le plus court entre bras et objet, mesuré par rayons depuis l'intérieur du bras.
local heros = find(workspace, "Bestiaire.Heros")
local copies = find(ServerStorage, "Assets.Heros")
local function include(part: BasePart): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { part }
	return params
end
local function gapToArm(arm: BasePart, held: BasePart): number
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = { held }
	if #workspace:GetPartsInPart(arm, overlap) > 0 then
		return 0
	end
	local toHeld, toArm = include(held), include(arm)
	local best = math.huge
	for i = -4, 4 do
		for j = -4, 4 do
			for k = -4, 4 do
				local origin = arm.CFrame:PointToWorldSpace(arm.Size * Vector3.new(i, j, k) / 8)
				local hit = workspace:Raycast(origin, held.Position - origin, toHeld)
				local surface = hit and workspace:Raycast(hit.Position, origin - hit.Position, toArm)
				if hit and surface then
					best = math.min(best, (surface.Position - hit.Position).Magnitude)
				end
			end
		end
	end
	return best
end
for _, entry in TENUS do
	local model = find(heros, `{entry[1]}.{entry[2]}`)
	local held = find(model, entry[3])
	if not (model and held and held:IsA("BasePart")) then
		check(false, `{entry[2]} : {entry[3]} introuvable au Bestiaire`)
		continue
	end
	local gap = math.huge
	for _, armPath in { "right_arm.right_arm_geom", "left_arm.left_arm_geom", "right_arm.right_arm", "left_arm.left_arm" } do
		local arm = find(model, armPath)
		if arm and arm:IsA("BasePart") then gap = math.min(gap, gapToArm(arm, held)) end
	end
	check(gap <= entry[4], string.format("%s : %s tenu par un bras (écart %.2f, toléré %.2f)", entry[2], held.Name, gap, entry[4]))
end
local cristaux = {
	{ "Bestiaire", find(heros, "Socle_25.PretresseAuxLucioles.baton_fleur.cristal_luciole") },
	{ "copie de jeu", find(copies, "PretresseAuxLucioles.baton_fleur.cristal_luciole") },
}
for _, entry in cristaux do
	local cristal = entry[2]
	check(cristal ~= nil and cristal:IsA("Part") and cristal.Shape == Enum.PartType.Ball,
		`Prêtresse aux Lucioles ({entry[1]}) : cristal en sphère`)
end

-- 4. Copies de jeu : mêmes pièces, mêmes tailles, mêmes positions par rapport au buste (les pivots
-- diffèrent : les copies ont le leur aux pieds).
local byName: { [string]: Model } = {}
for _, socle in if heros then heros:GetChildren() else {} do
	if BROUILLONS[socle.Name] then
		local model = socle:FindFirstChildWhichIsA("Model")
		if model then
			local bare, total = 0, 0
			for _, part in model:GetDescendants() do
				if part:IsA("MeshPart") then
					total += 1
					if part.TextureID == "" and not part:FindFirstChildWhichIsA("SurfaceAppearance") then bare += 1 end
				end
			end
			print(`CONNU {socle.Name} {model.Name} : {bare}/{total} pièces sans texture (brouillon hors catalogue)`)
		end
		continue
	end
	for _, model in socle:GetChildren() do
		if model:IsA("Model") then byName[model.Name] = model end
	end
end
local function relativeParts(model: Model): { [string]: BasePart }
	local parts = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then parts[part:GetFullName():sub(#model:GetFullName() + 2)] = part end
	end
	return parts
end
for _, copy in if copies then copies:GetChildren() else {} do
	if not copy:IsA("Model") then continue end
	local original = byName[copy.Name]
	if not original then
		check(false, `copie {copy.Name} : pas de modèle au Bestiaire`)
		continue
	end
	local a, b = relativeParts(original), relativeParts(copy)
	local reference: string? = nil
	for path in a do
		if b[path] and string.find(path, "^torso%.") and (reference == nil or path < reference) then reference = path end
	end
	if not reference then
		check(false, `copie {copy.Name} : pas de buste commun pour comparer`)
		continue
	end
	local pivotA, pivotB = a[reference].CFrame, b[reference].CFrame
	local diffs: { string } = {}
	for path, part in a do
		local other = b[path]
		if not other then
			table.insert(diffs, `{path} absent`)
			continue
		end
		local offsetA = pivotA:ToObjectSpace(part.CFrame)
		local offsetB = pivotB:ToObjectSpace(other.CFrame)
		local moved = (offsetA.Position - offsetB.Position).Magnitude > TOLERANCE_STUDS
			or offsetA.LookVector:Dot(offsetB.LookVector) < 0.9999
			or offsetA.UpVector:Dot(offsetB.UpVector) < 0.9999
		if moved or (part.Size - other.Size).Magnitude > TOLERANCE_STUDS then
			table.insert(diffs, `{path} différent`)
		end
	end
	for path in b do
		if not a[path] then table.insert(diffs, `{path} en trop`) end
	end
	check(#diffs == 0, `copie {copy.Name} identique au Bestiaire{if #diffs > 0 then " : " .. table.concat(diffs, ", ") else ""}`)
end

-- 5. Prises (docs/SKELETON.md § Prise) : chaque objet tenu porte une Prise superposée au Poing de son
-- bras (Skeleton.gripProblems), et son manche traverse le poing, sauf PriseLibre ou PriseControlee.
-- Le test « traverse » se fait par rayons : au Bestiaire seulement (les copies de jeu ne sont pas dans
-- le Workspace ; elles sont identiques au Bestiaire, contrôle 4).
local shared = ReplicatedStorage:FindFirstChild("Shared")
local Skeleton: any = shared and require(shared:WaitForChild("Animation"):WaitForChild("Skeleton"))
local SkeletonConfig: any = shared and require(shared:WaitForChild("Config"):WaitForChild("SkeletonConfig"))
local HAND_ARM = { ArmeGauche = "BrasGauche", ArmeDroite = "BrasDroit" }

-- La section des pièces `parts` coupe-t-elle le plan perpendiculaire à `axis` en `point` (0,7 stud) ?
local function crosses(parts: { BasePart }, point: Vector3, axis: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = parts
	local u = axis:Cross(if math.abs(axis.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis).Unit
	local v = axis:Cross(u).Unit
	for step = 0, 15 do
		local direction = u * math.cos(step * math.pi / 8) + v * math.sin(step * math.pi / 8)
		local hit = workspace:Raycast(point + direction * 1.5, -direction * 1.5, params)
		if hit and (hit.Position - point).Magnitude < 0.7 then
			return true
		end
	end
	return false
end

-- Sommets réels d'une MeshPart, dans le monde. Les rayons et GetPartsInPart touchent l'enveloppe de
-- collision (CollisionFidelity Default), qui bouche le creux du poing et arrondit l'avant-bras : seul
-- le maillage dit dans quel sens va le bras (#04 passait toutes les mesures par rayons).
local vertexCache: { [string]: { Vector3 } } = {}
local function meshVertices(part: BasePart): { Vector3 }
	if not part:IsA("MeshPart") or part.MeshId == "" then
		return {}
	end
	local cached = vertexCache[part.MeshId]
	if not cached then
		local found: { Vector3 } = {}
		local ok, mesh = pcall(function()
			return AssetService:CreateEditableMeshAsync(Content.fromUri(part.MeshId))
		end)
		if ok and mesh then
			for _, id in mesh:GetVertices() do
				table.insert(found, mesh:GetPosition(id))
			end
			mesh:Destroy()
		end
		vertexCache[part.MeshId] = found
		cached = found
	end
	local scale = part.Size / part.MeshSize
	local points = table.create(#cached)
	for i, point in cached do
		points[i] = part.CFrame:PointToWorldSpace(point * scale)
	end
	return points
end

-- Angle (degrés, 0 à 90) entre le manche `axis` et l'avant-bras : axe principal des sommets du bras à
-- moins de 1,2 stud du Poing. nil si le bras n'a pas de maillage lisible.
local function forearmCross(armParts: { BasePart }, poing: Vector3, axis: Vector3): number?
	local near: { Vector3 } = {}
	local mean = Vector3.zero
	for _, part in armParts do
		for _, point in meshVertices(part) do
			if (point - poing).Magnitude < 1.2 then
				table.insert(near, point)
				mean += point
			end
		end
	end
	if #near < 10 then
		return nil
	end
	mean /= #near
	local direction = Vector3.new(0.3, 1, 0.2).Unit
	for _ = 1, 40 do
		local sum = Vector3.zero
		for _, point in near do
			local d = point - mean
			sum += d * d:Dot(direction)
		end
		if sum.Magnitude < 1e-9 then
			break
		end
		direction = sum.Unit
	end
	return math.deg(math.acos(math.clamp(math.abs(direction:Dot(axis)), 0, 1)))
end

local function checkGrips(label: string, model: Model, inWorkspace: boolean)
	local GRIP = Skeleton.Grip
	local markers = model:FindFirstChild("ReperesPrise")
	local list: { BasePart } = {}
	local descriptors = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and not (markers and part:IsDescendantOf(markers)) then
			local node: Instance = part
			while node.Parent and node.Parent ~= model do
				node = node.Parent
			end
			table.insert(list, part)
			table.insert(descriptors, {
				Name = part.Name,
				Os = part:GetAttribute(Skeleton.BoneAttribute),
				Ancre = part:GetAttribute(Skeleton.AnchorAttribute),
				Groupe = if node ~= part and model == node.Parent then node.Name else nil,
			})
		end
	end
	local resolution = Skeleton.resolve(descriptors, SkeletonConfig.Models[model.Name])
	local poings: { [string]: Attachment } = {}
	local arms: { [string]: { BasePart } } = { ArmeGauche = {}, ArmeDroite = {} }
	for hand, armBone in HAND_ARM do
		for index, part in list do
			if resolution.targets[index] == armBone then
				table.insert(arms[hand], part)
				local found = part:FindFirstChild(GRIP.Hand)
				if found and found:IsA("Attachment") then
					poings[hand] = found
				end
			end
		end
	end
	local held: { [string]: { BasePart } } = { ArmeGauche = {}, ArmeDroite = {} }
	for index, part in list do
		local target = resolution.targets[index]
		if target == Skeleton.NearestHand then
			local best = math.huge
			for hand, poing in poings do
				local distance = (part.Position - poing.WorldPosition).Magnitude
				if distance < best then
					target, best = hand, distance
				end
			end
		end
		if held[target] then
			table.insert(held[target], part)
		end
	end
	for hand, parts in held do
		if #parts == 0 then
			continue
		end
		local prise: Attachment? = nil
		for _, part in parts do
			local found = part:FindFirstChild(GRIP.Weapon)
			if found and found:IsA("Attachment") then
				prise = found
			end
		end
		local poing = poings[hand]
		local measure: any = { Piece = if prise then (prise.Parent :: Instance).Name else parts[1].Name, HasPrise = prise ~= nil, HasPoing = poing ~= nil }
		if prise and poing then
			measure.Gap = (prise.WorldPosition - poing.WorldPosition).Magnitude
			measure.Angle = math.deg(math.acos(math.clamp(prise.WorldAxis:Dot(poing.WorldAxis), -1, 1)))
			measure.Free = prise:GetAttribute(GRIP.Free) == true
			measure.Checked = prise:GetAttribute(GRIP.Checked) == true
			measure.Cross = forearmCross(arms[hand], poing.WorldPosition, prise.WorldAxis)
			if inWorkspace then
				measure.Before = crosses(parts, prise.WorldPosition - prise.WorldAxis * GRIP.Through, prise.WorldAxis)
				measure.After = crosses(parts, prise.WorldPosition + prise.WorldAxis * GRIP.Through, prise.WorldAxis)
			end
		end
		local found = Skeleton.gripProblems(measure)
		check(#found == 0, `{label} {model.Name} {hand} : {if #found == 0 then measure.Piece .. " en main" else table.concat(found, " ; ")}`)
	end
end

if Skeleton and Skeleton.Grip then
	for _, socle in if heros then heros:GetChildren() else {} do
		local model = socle:FindFirstChildWhichIsA("Model")
		if model and not BROUILLONS[socle.Name] then
			checkGrips(`Prise {socle.Name}`, model, true)
		end
	end
	for _, copy in if copies then copies:GetChildren() else {} do
		if copy:IsA("Model") then
			checkGrips("Prise copie", copy, false)
		end
	end
else
	check(false, "ReplicatedStorage.Shared.Animation.Skeleton sans Grip : synchroniser Rojo")
end

print(if #problems == 0 then "PASS" else `FIX : {#problems} problème(s)`)
return #problems
