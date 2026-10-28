--!strict
-- AnimationKit : outil d'atelier Studio (mode Edit) pour animer un héros ou un monstre (voir docs/ANIMATION_TOOLS.md).
-- Ce n'est PAS du code de jeu : il n'est pas synchronisé par Rojo et ne tourne jamais en partie.
-- Il modifie des assets Studio (modèles, KeyframeSequence), comme le ferait un artiste à la main.
--
-- Utilisation (barre de commande de Studio, ou execute_luau via le MCP) :
--   1. coller ce fichier en entier puis Entrée : il définit _G.AnimationKit ;
--   2. lancer par exemple :
--      _G.AnimationKit.prepare({
--        Source = workspace.Bestiaire.Heros.Socle_01.EcuyerDuRempart,
--        Set = "EcuyerDuRempart",          -- dossier ReplicatedStorage.Assets.Animations.<Set>
--        Profile = "Leger",                -- "Leger" (héros, petit monstre) ou "Lourd" (tréant, colosse)
--      })
--   Le modèle source n'est jamais modifié : une copie est animée dans Workspace.AtelierAnimation,
--   posée à côté du SpawnLocation et animée en boucle au prochain Play (MonsterAnimationController).
--
-- Squelette commun (docs/SKELETON.md) : Kit.rig pose des os invisibles aux noms communs (Buste, Tete,
-- BrasGauche...) et y accroche les pièces du modèle. Les animations générées sont nommées d'après ces
-- os : une même animation (jeu commun Squelette_Leger, Squelette_Lourd...) joue sur tous les modèles.
-- Les os, les fiches de modèles et la recherche des animations sont du code de jeu synchronisé par
-- Rojo (ReplicatedStorage.Shared) : ce fichier les lit, il ne les recopie pas.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local shared = ReplicatedStorage:FindFirstChild("Shared")
assert(shared and shared:FindFirstChild("Animation"), "ReplicatedStorage.Shared.Animation introuvable : lancer la synchronisation Rojo (rojo serve) avant AnimationKit")
local Skeleton = require(shared.Animation.Skeleton) :: any
local AnimationSets = require(shared.Animation.AnimationSets) :: any
local SkeletonConfig = require(shared.Config.SkeletonConfig) :: any

local Kit = {}

local ATELIER = "AtelierAnimation"
-- Anciennes séquences retirées d'un jeu propre par Kit.share : jamais lues par le jeu (ServerStorage),
-- gardées pour comparer ou revenir en arrière.
local ARCHIVE = "AnimationKitArchive"
local PREVIEW_TAG = "ApercuAnimation"
local KEYS_PER_CYCLE = 16
local BONE_SIZE = 0.2

-- Profils de marche : chiffres en degrés (rotations), studs (hauteurs) et secondes (Cycle).
-- Les « Lag » retardent un mouvement (en radians de phase) pour éviter que tout bouge en même temps.
Kit.Profiles = {
	-- Écuyer du Rempart : pas militaire, buste penché, arme tenue basse.
	Leger = {
		Cycle = 0.6, Stride = 28, Lean = 6, LeanPulse = 1.2,
		Yaw = 5, Roll = -2.5, RollLag = 0, BobBase = 0.03, Bob = 0.09, BobLag = 0.3,
		ArmForward = 0, ArmSwingRight = 12, ArmSwingLeft = 7, ArmLag = 0.35, ArmSpread = 0, ArmSpreadPulse = 0, ArmSpreadLag = 0,
		HeadNod = 3, HeadNodPulse = 1.5, HeadNodLag = 0.6, HeadYaw = 4, HeadRoll = 1.5, HeadLag = 0.4,
	},
	-- Tréant masqué : démarche lourde, rebond retardé, longs bras qui traînent.
	Lourd = {
		Cycle = 1.2, Stride = 22, Lean = 8, LeanPulse = 2,
		Yaw = 7, Roll = 5, RollLag = 0.3, BobBase = -0.05, Bob = 0.16, BobLag = 0.4,
		ArmForward = 6, ArmSwingRight = 18, ArmSwingLeft = 18, ArmLag = 0.6, ArmSpread = 5, ArmSpreadPulse = 2, ArmSpreadLag = 0.8,
		HeadNod = 7, HeadNodPulse = 2, HeadNodLag = 0.9, HeadYaw = 6, HeadRoll = -3, HeadLag = 0.5,
	},
}

-- Boîte d'une pièce exprimée dans un repère (min, max).
local function bounds(part: BasePart, frame: CFrame): (Vector3, Vector3)
	local mn, mx = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local p = frame:PointToObjectSpace(part.CFrame:PointToWorldSpace(Vector3.new(sx, sy, sz) * part.Size / 2))
				mn, mx = mn:Min(p), mx:Max(p)
			end
		end
	end
	return mn, mx
end

-- Os invisible du squelette commun (pas une pièce du modèle).
local function isBone(part: Instance): boolean
	return part.Parent ~= nil and part.Parent.Name == Skeleton.Folder and Skeleton.bone(part.Name) ~= nil
end

local function lowestPoint(model: Model): number
	local y = math.huge
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= Skeleton.Root and not isBone(part) then
			local mn = bounds(part, CFrame.identity)
			y = math.min(y, mn.Y)
		end
	end
	return y
end

-- Pièces visibles du modèle (ni racine, ni os, ni repères de prise affichés par Kit.showGrips).
local function modelPieces(model: Model): { BasePart }
	local list: { BasePart } = {}
	local markers = model:FindFirstChild("ReperesPrise")
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= Skeleton.Root and not isBone(part)
			and not (markers and part:IsDescendantOf(markers)) then
			table.insert(list, part)
		end
	end
	return list
end

-- Fiche de branchement : options.Map (clé de SkeletonConfig.Models ou table { Membres, Pieces }),
-- complétée par les anciennes options Parts ({ [rôle] = pièce }) et Held ({ [pièce] = mode }).
local function mapFor(options: { [string]: any }?): { Membres: { [string]: string }, Pieces: { [string]: string } }
	local membres: { [string]: string } = {}
	local pieces: { [string]: string } = {}
	local entry = options and options.Map
	if typeof(entry) == "string" then
		local found = SkeletonConfig.Models[entry]
		assert(found, `fiche {entry} absente de SkeletonConfig.Models`)
		entry = found
	end
	if typeof(entry) == "table" then
		for bone, name in entry.Membres or {} do
			membres[bone] = name
		end
		for name, target in entry.Pieces or {} do
			pieces[name] = target
		end
	end
	for key, name in (options and options.Parts) or {} do
		local bone = Skeleton.resolveBone(key)
		assert(bone, `Parts : os inconnu « {key} » (os : Buste, Tete, BrasGauche, BrasDroit, JambeGauche, JambeDroite)`)
		membres[bone.Name] = name
	end
	for name, target in (options and options.Held) or {} do
		pieces[name] = target
	end
	return { Membres = membres, Pieces = pieces }
end

-- Associe chaque pièce à un os (Skeleton.resolve) ; s'arrête si un membre n'a pas de pièce.
-- Sans options.Map, la fiche est celle du nom du modèle (SkeletonConfig.Models[model.Name]).
-- armsOnly : seuls le buste et les bras sont exigés (prises d'un modèle sans jambes, #68).
local function resolvePieces(model: Model, options: { [string]: any }?, armsOnly: boolean?): ({ BasePart }, any)
	local entryName = model:GetAttribute("Modele") or model.Name -- Kit.copy garde le nom de la source
	if not (options and options.Map) and SkeletonConfig.Models[entryName] then
		options = table.clone(options or {})
		;(options :: any).Map = entryName
	end
	local list = modelPieces(model)
	local descriptors = {}
	for _, part in list do
		-- Groupe : enfant direct du modèle qui contient la pièce (baton_fleur, halo_lames, equipement...).
		local node: Instance = part
		while node.Parent and node.Parent ~= model do
			node = node.Parent
		end
		table.insert(descriptors, {
			Name = part.Name,
			Os = part:GetAttribute(Skeleton.BoneAttribute),
			Ancre = part:GetAttribute(Skeleton.AnchorAttribute),
			Groupe = if node ~= part and node.Parent == model then node.Name else nil,
		})
	end
	local resolution = Skeleton.resolve(descriptors, mapFor(options))
	for _, message in resolution.warnings do
		warn(`[AnimationKit] {model.Name} : {message}`)
	end
	local missing = resolution.missing
	if armsOnly then
		missing = {}
		for _, bone in resolution.missing do
			if bone == "Buste" or bone == "BrasGauche" or bone == "BrasDroit" then
				table.insert(missing, bone)
			end
		end
	end
	assert(#missing == 0, `{model.Name} : aucune pièce pour {table.concat(missing, ", ")} ; `
		.. "la désigner dans SkeletonConfig (Membres) ou par Parts, voir docs/SKELETON.md")
	return list, resolution
end

-- Montre, sans rien modifier, quelle pièce irait sur quel os (pour brancher un nouveau modèle).
-- Les cibles MainProche / BrasProche sont tranchées par la géométrie au moment du rig.
function Kit.inspect(model: Model, options: { [string]: any }?): string
	local list, resolution = resolvePieces(model, options)
	local lines: { string } = {}
	for index, part in list do
		local target = resolution.targets[index]
		local anchor = resolution.anchors[target] == index
		table.insert(lines, `{part.Name} -> {target}{if anchor then " (forme du membre)" else ""}`)
	end
	table.sort(lines)
	print(`[AnimationKit] {model.Name} :\n  {table.concat(lines, "\n  ")}`)
	return table.concat(lines, "\n")
end

-- ── Prise des objets tenus (docs/SKELETON.md § Prise) ──────────────────────────────────────────────
-- Attachment Poing sur le bras (centre du poing) et Prise sur l'objet tenu (point du manche serré),
-- mêmes axes : X = manche vers la tête de l'arme, Y = côté du tranchant. Les mesures se font par
-- rayons : le modèle doit être dans le Workspace.
local GRIP = Skeleton.Grip
local HAND_ARM = { ArmeGauche = "BrasGauche", ArmeDroite = "BrasDroit" }
-- Kit.grip recentre seul un manche jusqu'à cette distance du poing mesuré (studs).
local AUTO_RECENTER = 0.9

local function only(parts: { BasePart }): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = parts
	return params
end

-- Points de surface d'une pièce : rayons tirés d'une sphère autour d'elle vers son centre.
local function surfacePoints(part: BasePart, count: number?): { Vector3 }
	local n = count or 400
	local params = only({ part })
	local center, radius = part.Position, part.Size.Magnitude
	local points: { Vector3 } = {}
	for i = 1, n do
		local y = 1 - (i - 0.5) * 2 / n
		local ring = math.sqrt(1 - y * y)
		local angle = i * 2.399963
		local direction = Vector3.new(math.cos(angle) * ring, y, math.sin(angle) * ring)
		local hit = workspace:Raycast(center + direction * radius, -direction * radius * 2, params)
		if hit then
			table.insert(points, hit.Position)
		end
	end
	return points
end

-- Centre du poing mesuré sur la pièce du bras : bout du bras le plus loin de l'épaule (point de la
-- surface le plus proche du buste), puis centre du volume du bras dans une boule de 0,5 stud autour
-- de ce bout, recentrée quatre fois (sondes GetPartsInPart). Le centre des seuls points de surface
-- tombait dans le poignet (#05 Brise-Pierre).
local function fistCenter(arm: BasePart, torso: BasePart): Vector3
	local points = surfacePoints(arm)
	assert(#points > 0, `{arm.Name} : aucun point de surface (pièce hors du Workspace ?)`)
	-- Épaule : point du bras le plus proche du haut du buste (le centre du buste prenait le coude
	-- d'un bras plié, #28).
	local mn, mx = bounds(torso, CFrame.identity)
	local shoulderLevel = Vector3.new((mn.X + mx.X) / 2, mn.Y + (mx.Y - mn.Y) * 0.85, (mn.Z + mx.Z) / 2)
	local shoulder, best = points[1], math.huge
	for _, point in points do
		local distance = (point - shoulderLevel).Magnitude
		if distance < best then
			shoulder, best = point, distance
		end
	end
	local tip, far = points[1], -1
	for _, point in points do
		local distance = (point - shoulder).Magnitude
		if distance > far then
			tip, far = point, distance
		end
	end
	local probe = Instance.new("Part")
	probe.Shape = Enum.PartType.Ball
	probe.Size = Vector3.one * 0.06
	probe.Anchored, probe.CanCollide, probe.Transparency = true, false, 1
	probe.Parent = workspace
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = { arm }
	local center = tip
	for _ = 1, 4 do
		local sum, count = Vector3.zero, 0
		for x = -0.5, 0.5, 0.06 do
			for y = -0.5, 0.5, 0.06 do
				for z = -0.5, 0.5, 0.06 do
					local offset = Vector3.new(x, y, z)
					if offset.Magnitude <= 0.5 then
						probe.Position = center + offset
						if #workspace:GetPartsInPart(probe, overlap) > 0 then
							sum += probe.Position
							count += 1
						end
					end
				end
			end
		end
		if count == 0 then
			break
		end
		center = sum / count
	end
	probe:Destroy()
	return center
end

-- Axes d'une pièce rangés du plus long au plus court (vecteurs du monde, demi-longueurs).
local function axesOf(part: BasePart): { { axis: Vector3, half: number } }
	local cf = part.CFrame
	local axes = {
		{ axis = cf.RightVector, half = part.Size.X / 2 },
		{ axis = cf.UpVector, half = part.Size.Y / 2 },
		{ axis = cf.LookVector, half = part.Size.Z / 2 },
	}
	table.sort(axes, function(a, b)
		return a.half > b.half
	end)
	return axes
end

-- Axe principal d'une pièce, mesuré sur sa surface (analyse en composantes principales) : suit la
-- lame ou le manche même quand la boîte de la pièce est penchée (anneau de l'épée-clé #57).
-- Renvoie le centre des points, l'axe, et les bornes des points le long de l'axe.
local function principalAxis(part: BasePart): (Vector3, Vector3, number, number)
	local points = surfacePoints(part, 600)
	if #points < 10 then
		local axes = axesOf(part)
		return part.Position, axes[1].axis, -axes[1].half, axes[1].half
	end
	local mean = Vector3.zero
	for _, point in points do
		mean += point
	end
	mean /= #points
	local xx, xy, xz, yy, yz, zz = 0, 0, 0, 0, 0, 0
	for _, point in points do
		local d = point - mean
		xx += d.X * d.X
		xy += d.X * d.Y
		xz += d.X * d.Z
		yy += d.Y * d.Y
		yz += d.Y * d.Z
		zz += d.Z * d.Z
	end
	local axis = axesOf(part)[1].axis
	for _ = 1, 50 do
		local v = Vector3.new(xx * axis.X + xy * axis.Y + xz * axis.Z, xy * axis.X + yy * axis.Y + yz * axis.Z, xz * axis.X + yz * axis.Y + zz * axis.Z)
		if v.Magnitude < 1e-9 then
			break
		end
		axis = v.Unit
	end
	local low, high = math.huge, -math.huge
	for _, point in points do
		local t = (point - mean):Dot(axis)
		low, high = math.min(low, t), math.max(high, t)
	end
	return mean, axis, low, high
end

-- Centre de la section des pièces `parts` dans le plan perpendiculaire à `axis` passant par `point`
-- (rayons tirés vers le point, rayon max 0,7 stud). nil si rien n'est coupé.
local function sectionCenter(parts: { BasePart }, point: Vector3, axis: Vector3): Vector3?
	local params = only(parts)
	local u = axis:Cross(if math.abs(axis.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis).Unit
	local v = axis:Cross(u).Unit
	local sum, count = Vector3.zero, 0
	for step = 0, 15 do
		local angle = step * math.pi / 8
		local direction = u * math.cos(angle) + v * math.sin(angle)
		local hit = workspace:Raycast(point + direction * 1.5, -direction * 1.5, params)
		if hit and (hit.Position - point).Magnitude < 0.7 then
			sum += hit.Position
			count += 1
		end
	end
	return if count > 0 then sum / count else nil
end

local function attachmentIn(parts: { BasePart }, name: string): Attachment?
	for _, part in parts do
		local found = part:FindFirstChild(name)
		if found and found:IsA("Attachment") then
			return found
		end
	end
	return nil
end

export type HandGrip = {
	hand: string, -- ArmeGauche / ArmeDroite
	arm: BasePart, -- pièce qui donne la forme du bras
	armParts: { BasePart }, -- toutes les pièces portées par ce bras (poing séparé compris)
	held: { BasePart }, -- objets tenus par cette main
	fist: Vector3, -- centre du poing mesuré
	poing: Attachment?,
	prise: Attachment?,
}

-- Objets tenus regroupés par main. MainProche : la main dont le poing mesuré est le plus proche.
local function handGrips(model: Model, options: { [string]: any }?): { HandGrip }
	local list, resolution = resolvePieces(model, options, true)
	local torso = list[resolution.anchors.Buste]
	local grips: { [string]: HandGrip } = {}
	for hand, armBone in HAND_ARM do
		local index = resolution.anchors[armBone]
		if index then
			local armParts: { BasePart } = {}
			for i, part in list do
				if resolution.targets[i] == armBone then
					table.insert(armParts, part)
				end
			end
			grips[hand] = { hand = hand, arm = list[index], armParts = armParts, held = {}, fist = fistCenter(list[index], torso) }
		end
	end
	for index, part in list do
		local target = resolution.targets[index]
		if target == Skeleton.NearestHand then
			local best = math.huge
			for hand, grip in grips do
				local distance = (part.Position - grip.fist).Magnitude
				if distance < best then
					target, best = hand, distance
				end
			end
		end
		local grip = grips[target]
		if grip then
			table.insert(grip.held, part)
		end
	end
	local result: { HandGrip } = {}
	for _, hand in { "ArmeDroite", "ArmeGauche" } do
		local grip = grips[hand]
		if grip and #grip.held > 0 then
			grip.poing = attachmentIn(grip.armParts, GRIP.Hand)
			grip.prise = attachmentIn(grip.held, GRIP.Weapon)
			table.insert(result, grip)
		end
	end
	return result
end

-- Superpose la Prise au Poing : tous les objets de la main bougent ensemble (décors d'arme compris).
local function snapGrip(grip: HandGrip): number
	if not (grip.poing and grip.prise) then
		return 0
	end
	local delta = grip.poing.WorldCFrame * grip.prise.WorldCFrame:Inverse()
	for _, part in grip.held do
		part.CFrame = delta * part.CFrame
	end
	return delta.Position.Magnitude
end

-- Pose Prise et Poing d'après la prise actuelle (à faire une fois, sur un modèle dont les armes
-- ont été contrôlées en capture). Pièce principale : celle dont l'axe long passe le plus près du
-- poing ; Prise = centre de son manche au droit du poing ; Poing = même repère, sur le bras.
-- Une main qui a déjà Prise et Poing est seulement recollée (Prise ramenée sur le Poing).
-- options : comme Kit.rig (Map, Held...). Renvoie une ligne de compte rendu par main.
function Kit.grip(model: Model, options: { [string]: any }?): { string }
	local report: { string } = {}
	for _, grip in handGrips(model, options) do
		if not grip.prise then
			local main, mainAxis, mainCenter, bestDistance, bestT = grip.held[1], Vector3.xAxis, Vector3.zero, math.huge, 0
			local mainLow, mainHigh = 0, 0
			for _, part in grip.held do
				local center, axis, low, high = principalAxis(part)
				local t = math.clamp((grip.fist - center):Dot(axis), low, high)
				local distance = (center + axis * t - grip.fist).Magnitude
				if distance < bestDistance then
					main, mainAxis, mainCenter, bestDistance, bestT = part, axis, center, distance, t
					mainLow, mainHigh = low, high
				end
			end
			local axes = axesOf(main)
			-- Objet sans manche (Skeleton.Grip.FreeWords) ou plat : la Prise est le centre du poing
			-- mesuré (l'objet ne bouge pas), sans test « traverse » (PriseLibre).
			local lower = string.lower(main.Name .. " " .. ((main.Parent :: Instance).Name))
			-- Plat = mince ET presque aussi large que long (écu) ; une lame est mince mais allongée.
			local flat = axes[3].half < axes[2].half * 0.35 and axes[2].half > axes[1].half * 0.5
			for _, word in GRIP.FreeWords do
				if string.find(lower, word, 1, true) then
					flat = true
				end
			end
			local point = if flat then grip.fist else mainCenter + mainAxis * bestT
			if not flat then
				point = sectionCenter({ main }, point, mainAxis) or point
			end
			-- Vers la tête de l'arme : le bout le plus éloigné du poing.
			local axis = if bestT - mainLow > mainHigh - bestT then -mainAxis else mainAxis
			local secondary = axes[2].axis - axis * axes[2].axis:Dot(axis)
			if secondary.Magnitude < 0.3 then
				secondary = axes[3].axis - axis * axes[3].axis:Dot(axis)
			end
			secondary = secondary.Unit
			local frame = CFrame.fromMatrix(point, axis, secondary)
			local prise = Instance.new("Attachment")
			prise.Name = GRIP.Weapon
			prise.CFrame = main.CFrame:ToObjectSpace(frame)
			if flat then
				prise:SetAttribute(GRIP.Free, true)
			end
			prise.Parent = main
			grip.prise = prise
		end
		local prise = grip.prise :: Attachment
		if not grip.poing then
			-- Poing au centre du poing mesuré, axes de la Prise : le manche est recollé au centre.
			-- Au-delà de AUTO_RECENTER, la mesure est douteuse (bras levé, gantelet) : rien ne bouge,
			-- le Poing reste sur la Prise et Kit.checkGrips signale l'écart (vérifier en capture).
			local gap = (grip.fist - prise.WorldPosition).Magnitude
			local center = if gap <= AUTO_RECENTER then grip.fist else prise.WorldPosition
			local poing = Instance.new("Attachment")
			poing.Name = GRIP.Hand
			poing.CFrame = grip.arm.CFrame:ToObjectSpace(prise.WorldCFrame - prise.WorldPosition + center)
			poing.Parent = grip.arm
			grip.poing = poing
			local moved = snapGrip(grip)
			table.insert(report, if gap <= AUTO_RECENTER
				then string.format("%s : Prise sur %s, recentrée de %.2f stud dans le poing", grip.hand, (prise.Parent :: Instance).Name, moved)
				else string.format("%s : Prise sur %s laissée en place, poing mesuré à %.2f stud (À VÉRIFIER EN CAPTURE)", grip.hand, (prise.Parent :: Instance).Name, gap))
		else
			table.insert(report, string.format("%s : %s recollé au Poing (déplacé de %.2f stud)", grip.hand,
				(prise.Parent :: Instance).Name, snapGrip(grip)))
		end
	end
	for _, line in report do
		print(`[AnimationKit] {model.Name} : {line}`)
	end
	return report
end

-- Mesure les prises d'un modèle (Skeleton.GripMeasure) et renvoie les défauts (liste vide = PASS).
function Kit.checkGrips(model: Model, options: { [string]: any }?): { string }
	local problems: { string } = {}
	for _, grip in handGrips(model, options) do
		local measure: any = { Piece = grip.held[1].Name, HasPrise = grip.prise ~= nil, HasPoing = grip.poing ~= nil }
		if grip.prise and grip.poing then
			local prise, poing = grip.prise :: Attachment, grip.poing :: Attachment
			measure.Piece = (prise.Parent :: Instance).Name
			measure.Gap = (prise.WorldPosition - poing.WorldPosition).Magnitude
			measure.Angle = math.deg(math.acos(math.clamp(prise.WorldAxis:Dot(poing.WorldAxis), -1, 1)))
			measure.Offset = (poing.WorldPosition - grip.fist).Magnitude
			measure.Free = prise:GetAttribute(GRIP.Free) == true
			measure.Checked = prise:GetAttribute(GRIP.Checked) == true
			local axis = prise.WorldAxis
			measure.Before = sectionCenter(grip.held, prise.WorldPosition - axis * GRIP.Through, axis) ~= nil
			measure.After = sectionCenter(grip.held, prise.WorldPosition + axis * GRIP.Through, axis) ~= nil
		end
		for _, problem in Skeleton.gripProblems(measure) do
			table.insert(problems, `{grip.hand} {problem}`)
		end
	end
	return problems
end

local function gripOfHand(model: Model, hand: string, options: { [string]: any }?): HandGrip
	for _, grip in handGrips(model, options) do
		if grip.hand == hand then
			assert(grip.prise and grip.poing, `{model.Name} {hand} : lancer Kit.grip d'abord`)
			return grip
		end
	end
	error(`{model.Name} : aucun objet tenu par {hand}`)
end

-- Réoriente l'objet tenu par `hand` : le manche passe par le Poing dans la direction `direction`
-- (vecteur du monde, vers la tête de l'arme), roulis = `secondary` si donné. Le Poing prend le même
-- axe : c'est la direction du trou du poing, vérifiée en capture. Option `slide` : fait glisser
-- la Prise le long du manche (studs, + vers la tête) avant de recoller.
function Kit.aim(model: Model, hand: string, direction: Vector3, secondary: Vector3?, slide: number?, options: { [string]: any }?): ()
	local grip = gripOfHand(model, hand, options)
	local prise, poing = grip.prise :: Attachment, grip.poing :: Attachment
	if slide and slide ~= 0 then
		prise.CFrame = prise.CFrame * CFrame.new(slide, 0, 0)
	end
	local axis = direction.Unit
	local side = secondary or prise.WorldSecondaryAxis
	side = (side - axis * side:Dot(axis))
	if side.Magnitude < 1e-3 then
		side = axis:Cross(Vector3.yAxis)
	end
	local target = CFrame.fromMatrix(poing.WorldPosition, axis, side.Unit)
	poing.WorldCFrame = target
	snapGrip(grip)
end

-- Repère visible du Poing (et de la Prise) pour le contrôle en capture : tige verte le long de l'axe
-- (vers la tête de l'arme), boule rouge au centre. Dossier « ReperesPrise » du modèle, à retirer
-- après la capture (Kit.hideGrips).
function Kit.showGrips(model: Model, options: { [string]: any }?): ()
	Kit.hideGrips(model)
	local folder = Instance.new("Folder")
	folder.Name = "ReperesPrise"
	folder.Parent = model
	local function piece(name: string, size: Vector3, frame: CFrame, color: Color3, shape: Enum.PartType)
		local part = Instance.new("Part")
		part.Name, part.Size, part.CFrame, part.Color, part.Shape = name, size, frame, color, shape
		part.Material = Enum.Material.Neon
		part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
		part.Parent = folder
	end
	for _, grip in handGrips(model, options) do
		if grip.poing then
			local frame = (grip.poing :: Attachment).WorldCFrame
			piece("Axe_" .. grip.hand, Vector3.new(1.6, 0.06, 0.06), frame * CFrame.new(0.8, 0, 0), Color3.fromRGB(40, 220, 60), Enum.PartType.Block)
			piece("Centre_" .. grip.hand, Vector3.one * 0.16, frame, Color3.fromRGB(230, 40, 40), Enum.PartType.Ball)
		end
		-- Centre du poing mesuré (violet) : doit tomber dans le poing ; sinon la mesure est fausse.
		piece("Mesure_" .. grip.hand, Vector3.one * 0.12, CFrame.new(grip.fist), Color3.fromRGB(220, 40, 220), Enum.PartType.Ball)
	end
end

function Kit.hideGrips(model: Model): ()
	local old = model:FindFirstChild("ReperesPrise")
	if old then
		old:Destroy()
	end
end

-- Pose le squelette commun (docs/SKELETON.md) sur un modèle de pièces séparées (format IA : <membre>_geom).
-- Repère racine : X = droite du personnage (du bras gauche vers le bras droit), -Z = avant.
-- Crée HumanoidRootPart, puis un os invisible par os commun (dossier « Os » : Buste, Tete, BrasGauche,
-- BrasDroit, JambeGauche, JambeDroite, ArmeGauche, ArmeDroite) relié à son parent par l'articulation
-- habituelle (Racine, Cou, EpauleGauche...). Chaque pièce visible est accrochée à un os et reçoit
-- l'attribut Os (et OsAncre pour la pièce qui donne la forme du membre) : un nouveau rig les relit.
-- options.Map = clé de SkeletonConfig.Models (ou table { Membres, Pieces }) : « cette pièce = tel os ».
-- Anciennes options toujours acceptées :
--   options.Parts = { [rôle ou os] = nomDePièce } (ex. { head = "body_geom" } pour le Roi Orc) ;
--   options.Held = { [nomDePièce] = mode } : "left" / "right" (ArmeGauche / ArmeDroite),
--     "nearest" (bras le plus proche), "torso" (Buste), ou directement un nom d'os.
function Kit.rig(model: Model, options: { [string]: any }?): ()
	assert(not model:FindFirstChild(Skeleton.Root), `{model.Name} a déjà un squelette (Kit.unrig d'abord)`)
	-- Prise : chaque objet tenu est recollé à son Poing avant tout, et sa main est celle du Poing.
	local grips = handGrips(model, options)
	local handOf: { [BasePart]: string } = {}
	for _, grip in grips do
		snapGrip(grip)
		for _, part in grip.held do
			handOf[part] = grip.hand
		end
	end
	local list, resolution = resolvePieces(model, options)
	local parts: { [string]: BasePart } = {}
	for boneName, index in resolution.anchors do
		parts[boneName] = list[index]
	end
	local torso, leftArm, rightArm = parts.Buste, parts.BrasGauche, parts.BrasDroit
	local right = ((rightArm.Position - leftArm.Position) * Vector3.new(1, 0, 1)).Unit
	local look = Vector3.yAxis:Cross(right)
	local center = model:GetBoundingBox().Position
	local origin = Vector3.new(center.X, torso.Position.Y, center.Z)
	local basis = CFrame.lookAt(origin, origin + look)

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.CFrame = basis
	root.Transparency = 1
	root.CanCollide, root.CanTouch, root.CanQuery = false, false, false
	root.Anchored = true
	root.Parent = model
	model.PrimaryPart = root

	local function joint(name: string, part0: BasePart, part1: BasePart, point: Vector3)
		local world = basis * CFrame.new(point)
		local motor = Instance.new("Motor6D")
		motor.Name = name
		motor.Part0, motor.Part1 = part0, part1
		motor.C0 = part0.CFrame:ToObjectSpace(world)
		motor.C1 = part1.CFrame:ToObjectSpace(world)
		motor.Parent = part0
	end
	local function middle(part: BasePart): Vector3
		local mn, mx = bounds(part, basis)
		return (mn + mx) / 2
	end
	-- Pivot d'un membre : en haut de la pièce, au centre ; inset = descente sous le haut (studs).
	local function top(part: BasePart, inset: number): Vector3
		local mn, mx = bounds(part, basis)
		return Vector3.new((mn.X + mx.X) / 2, mx.Y - inset, (mn.Z + mx.Z) / 2)
	end
	local function hand(part: BasePart): Vector3
		local mn, mx = bounds(part, basis)
		return Vector3.new((mn.X + mx.X) / 2, mn.Y + 0.4, (mn.Z + mx.Z) / 2)
	end

	-- Épaule : près du bord intérieur du bras (côté buste). Au milieu du bras, le haut du bras
	-- sortait du buste dès qu'il s'écartait et laissait voir l'intérieur du mesh.
	local function shoulder(part: BasePart, inset: number): Vector3
		local mn, mx = bounds(part, basis)
		local center = (mn.X + mx.X) / 2
		local inner = if center > 0 then mn.X else mx.X
		return Vector3.new(inner + (center - inner) * 0.4, mx.Y - inset, (mn.Z + mx.Z) / 2)
	end

	-- Pivots des os, dans le repère racine (mêmes pivots que l'ancien squelette par pièces).
	local armInset = math.clamp(leftArm.Size.Y * 0.15, 0.3, 0.8)
	local legInset = math.clamp(parts.JambeGauche.Size.Y * 0.1, 0.2, 0.5)
	local hmn, hmx = bounds(parts.Tete, basis)
	local pivots: { [string]: Vector3 } = {
		Buste = middle(torso),
		Tete = Vector3.new((hmn.X + hmx.X) / 2, hmn.Y + 0.2, (hmn.Z + hmx.Z) / 2),
		BrasGauche = shoulder(leftArm, armInset),
		BrasDroit = shoulder(rightArm, armInset),
		JambeGauche = top(parts.JambeGauche, legInset),
		JambeDroite = top(parts.JambeDroite, legInset),
		ArmeGauche = hand(leftArm),
		ArmeDroite = hand(rightArm),
	}
	-- Avec un Poing, l'os de l'arme pivote au centre du poing : une arme tournée par une animation
	-- (weaponRight, weaponLeft) reste dans la main.
	for _, grip in grips do
		if grip.poing then
			pivots[grip.hand] = basis:PointToObjectSpace((grip.poing :: Attachment).WorldPosition)
		end
	end
	local boneFolder = Instance.new("Folder")
	boneFolder.Name = Skeleton.Folder
	boneFolder.Parent = model
	local bones: { [string]: BasePart } = { [Skeleton.Root] = root }
	for _, bone in Skeleton.Bones do
		local pivot = pivots[bone.Name]
		assert(pivot, `pivot de l'os {bone.Name} non défini dans Kit.rig`)
		local part = Instance.new("Part")
		part.Name = bone.Name
		part.Size = Vector3.one * BONE_SIZE
		part.CFrame = basis * CFrame.new(pivot)
		part.Transparency = 1
		part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
		part.CastShadow = false
		part.Massless = true
		part.Parent = boneFolder
		joint(bone.Joint, bones[bone.Parent], part, pivot)
		bones[bone.Name] = part
	end

	-- Pièces visibles : accrochées à leur os. MainProche / BrasProche : côté le plus proche.
	local function nearer(part: BasePart, leftName: string, rightName: string): string
		local left, right = bones[leftName].Position, bones[rightName].Position
		return if (part.Position - left).Magnitude < (part.Position - right).Magnitude then leftName else rightName
	end
	local summary: { string } = {}
	for index, part in list do
		local target = resolution.targets[index]
		if target == Skeleton.NearestHand then
			target = handOf[part] or nearer(part, "ArmeGauche", "ArmeDroite")
		elseif target == Skeleton.NearestArm then
			target = nearer(part, "BrasGauche", "BrasDroit")
		end
		local bonePart = bones[target]
		assert(bonePart, `{part.Name} : os inconnu {target}`)
		local anchor = resolution.anchors[target] == index
		local base = string.gsub(part.Name, "_geom$", "")
		local prefix = if target == "ArmeGauche" or target == "ArmeDroite" then "Tenu_" else "Fixe_"
		joint(prefix .. base, bonePart, part, pivots[target])
		part:SetAttribute(Skeleton.BoneAttribute, target)
		part:SetAttribute(Skeleton.AnchorAttribute, if anchor then true else nil)
		if not anchor then
			table.insert(summary, `{part.Name} -> {target}`)
		end
	end

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part ~= root then
			part.Anchored = false
			part.CanCollide = false
		end
	end
	model:SetAttribute("Squelette", Skeleton.Name)
	for _, old in model:GetChildren() do
		if old:IsA("AnimationController") then
			old:Destroy() -- un seul AnimationController par modèle
		end
	end
	local controller = Instance.new("AnimationController")
	controller.Parent = model
	Instance.new("Animator").Parent = controller
	table.sort(summary)
	print(`[AnimationKit] {model.Name} : {table.concat(summary, " ; ")} (corriger dans SkeletonConfig, par l'attribut Os ou Held)`)
end

-- Couvercles de bras : certains modèles IA (Roi Orc) ont des bras en coque, ouverts sur toute leur
-- face intérieure (côté buste). Au repos, le buste cache l'ouverture ; dès que le bras s'écarte, on
-- voit l'intérieur, noir. Un ellipsoïde couleur peau, porté par le bras, ferme cette face. Il reste
-- dans l'aisselle au repos (pris pour de la peau). Proportions par défaut relevées sur le Roi Orc,
-- en fraction de la boîte du bras : à contrôler pour chaque modèle avec color = rouge vif (bras seul
-- vu du buste : plus de noir ; modèle entier au repos, de face, de dos et de dessus : rien ne dépasse).
--   options.Inset  : enfoncement depuis le bord intérieur du bras (studs, 0,75)
--   options.Height : hauteur du centre, en fraction de la hauteur du bras depuis le bas (0,71)
--   options.Size   : taille en fraction (épaisseur en studs, hauteur, profondeur) : (0,8 ; 0,5 ; 0,81)
function Kit.closeArms(model: Model, color: Color3, options: { Inset: number?, Height: number?, Size: Vector3? }?): ()
	local root = model.PrimaryPart
	assert(root, `{model.Name} n'a pas de squelette (lancer Kit.rig)`)
	local basis = root.CFrame
	local inset = options and options.Inset or 0.75
	local heightFraction = options and options.Height or 0.71
	local size = options and options.Size or Vector3.new(0.8, 0.5, 0.81)
	for _, motor in model:GetDescendants() do
		if motor:IsA("Motor6D") and (motor.Name == "EpauleGauche" or motor.Name == "EpauleDroite") and motor.Part1 then
			local arm = motor.Part1 :: BasePart
			local boneName: string? = nil
			if isBone(arm) then
				-- Squelette commun : l'articulation tient l'os ; le couvercle suit la pièce du bras.
				boneName = arm.Name
				local piece: BasePart? = nil
				for _, part in modelPieces(model) do
					if part:GetAttribute(Skeleton.BoneAttribute) == boneName and part:GetAttribute(Skeleton.AnchorAttribute) == true then
						piece = part
						break
					end
				end
				assert(piece, `{model.Name} : pièce du membre {boneName} introuvable (attribut OsAncre)`)
				arm = piece
			end
			local name = "Couvercle_" .. motor.Name
			local old = arm.Parent and arm.Parent:FindFirstChild(name)
			if old then
				-- Toute articulation qui le tenait part avec lui (Porte_ d'un closeArms précédent, ou
				-- Fixe_ d'un Kit.rig qui l'avait pris pour une pièce du buste) : pas de Motor6D orphelin.
				for _, motor in model:GetDescendants() do
					if motor:IsA("Motor6D") and motor.Part1 == old then
						motor:Destroy()
					end
				end
				old:Destroy()
			end
			local oldLink = arm:FindFirstChild("Porte_" .. name)
			if oldLink then
				oldLink:Destroy() -- sinon un Motor6D sans Part1 s'accumule à chaque réexécution
			end
			local mn, mx = bounds(arm, basis)
			local right = (mn.X + mx.X) / 2 > 0
			local x = if right then mn.X + inset else mx.X - inset
			local y = mn.Y + (mx.Y - mn.Y) * heightFraction
			local z = (mn.Z + mx.Z) / 2
			local cover = Instance.new("Part")
			cover.Name = name
			cover.Size = Vector3.new(size.X, (mx.Y - mn.Y) * size.Y, (mx.Z - mn.Z) * size.Z)
			cover.Material = Enum.Material.SmoothPlastic
			cover.Color = color
			cover.CastShadow = false
			cover.CanCollide, cover.CanTouch, cover.CanQuery = false, false, false
			cover.Anchored = false
			cover.CFrame = basis * CFrame.new(x, y, z)
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = cover
			cover.Parent = arm.Parent
			if boneName then
				cover:SetAttribute(Skeleton.BoneAttribute, boneName) -- un nouveau rig le remet sur ce bras
			end
			local link = Instance.new("Motor6D")
			link.Name = "Porte_" .. name
			link.Part0, link.Part1 = arm, cover
			link.C0 = arm.CFrame:ToObjectSpace(cover.CFrame)
			link.C1 = CFrame.identity
			link.Parent = arm
		end
	end
end

-- Retire le squelette posé par Kit.rig (modèle en pose de repos, mode Edit) pour le reposer
-- après une correction de l'outil ou de sa fiche. Les attributs Os / OsAncre des pièces sont gardés
-- (le prochain rig les relit). Les animations ne dépendent que des noms d'os : elles restent valables.
-- Un modèle de l'ancien squelette (Pose nommées d'après ses pièces) passe ainsi au squelette commun :
-- Kit.unrig, Kit.rig, puis régénérer ses séquences (Kit.walk, Kit.attack...).
function Kit.unrig(model: Model): ()
	for _, item in model:GetDescendants() do
		if item:IsA("Motor6D") or item:IsA("AnimationController") then
			item:Destroy()
		end
	end
	for _, name in { Skeleton.Root, Skeleton.Folder } do
		local item = model:FindFirstChild(name)
		if item then
			item:Destroy()
		end
	end
	model:SetAttribute("Squelette", nil)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
end

-- Arbre des articulations du modèle : partName -> { enfants }, depuis la racine, et nom de pièce -> os.
-- Squelette commun : seuls les os entrent dans l'arbre (les Pose portent les noms communs, la séquence
-- vaut pour tout modèle qui a ce squelette). Ancien squelette : Pose nommées d'après les pièces.
local function poseTree(model: Model): (string, { [string]: { string } }, { [string]: any })
	local common = model:GetAttribute("Squelette") == Skeleton.Name
	local children: { [string]: { string } } = {}
	local byPart: { [string]: any } = {}
	local partOf: { [string]: string } = {}
	for _, motor in model:GetDescendants() do
		if motor:IsA("Motor6D") and motor.Part0 and motor.Part1 then
			local part1 = motor.Part1 :: BasePart
			if common and not isBone(part1) then
				continue
			end
			local parent = (motor.Part0 :: BasePart).Name
			children[parent] = children[parent] or {}
			table.insert(children[parent], part1.Name)
			local bone = Skeleton.boneOfJoint(motor.Name)
			if bone then
				byPart[part1.Name] = bone
				partOf[bone.Name] = part1.Name
			end
		end
	end
	-- Ancien squelette : arme = première pièce tenue (articulation Tenu_*) par chaque main.
	if not common then
		for _, motor in model:GetDescendants() do
			if motor:IsA("Motor6D") and string.sub(motor.Name, 1, 5) == "Tenu_" and motor.Part0 and motor.Part1 then
				local holder = (motor.Part0 :: BasePart).Name
				local bone = if holder == partOf.BrasDroit then Skeleton.bone("ArmeDroite")
					elseif holder == partOf.BrasGauche then Skeleton.bone("ArmeGauche") else nil
				if bone and not partOf[bone.Name] then
					byPart[(motor.Part1 :: BasePart).Name] = bone
					partOf[bone.Name] = (motor.Part1 :: BasePart).Name
				end
			end
		end
	end
	local root = model.PrimaryPart
	assert(root, `{model.Name} n'a pas de squelette (lancer Kit.rig)`)
	return root.Name, children, byPart
end

-- Une séquence générée sur le squelette commun porte l'attribut Squelette : elle vaut pour tout
-- modèle qui a ce squelette et peut entrer dans un jeu commun (Kit.share).
local function markSkeleton(model: Model, sequence: KeyframeSequence)
	if model:GetAttribute("Squelette") == Skeleton.Name then
		sequence:SetAttribute("Squelette", Skeleton.Name)
	end
end

-- Valeur d'une pose pour un os : clé de rôle (torso, weaponRight) ou nom d'os (Buste, ArmeDroite).
local function poseValue(poses: { [string]: { number } }, bone: any): { number }?
	if not bone then
		return nil
	end
	return poses[bone.Role] or poses[bone.Name]
end

-- Valeurs de la marche à la phase phi (0..2π) : { [rôle] = { rx, ry, rz, y } }.
-- Courbes continues (sinus) : pas d'arrêt aux clés, contrairement à un easing Cubic InOut.
function Kit.walkPose(profile: { [string]: number }, phi: number): { [string]: { number } }
	local p = profile
	local s, sin, cos = math.sin(phi), math.sin, math.cos
	local arm = sin(phi - p.ArmLag)
	local spread = p.ArmSpread + p.ArmSpreadPulse * cos(2 * phi - p.ArmSpreadLag)
	return {
		torso = { -p.Lean - p.LeanPulse * cos(2 * phi), p.Yaw * s, p.Roll * sin(phi - p.RollLag), p.BobBase + p.Bob * cos(2 * phi - p.BobLag) },
		rightLeg = { p.Lean + p.Stride * s, 0, 0 },
		leftLeg = { p.Lean - p.Stride * s, 0, 0 },
		rightArm = { p.ArmForward - p.ArmSwingRight * arm, 0, spread },
		leftArm = { p.ArmForward + p.ArmSwingLeft * arm, 0, -spread },
		head = { p.HeadNod + p.HeadNodPulse * cos(2 * phi - p.HeadNodLag), -p.HeadYaw * sin(phi - p.HeadLag), p.HeadRoll * sin(phi - p.HeadLag) },
	}
end

-- Crée la KeyframeSequence « Marche » d'un modèle riggé. profile : nom de Kit.Profiles ou table complète.
function Kit.walk(model: Model, profile: any): KeyframeSequence
	local p = if typeof(profile) == "string" then Kit.Profiles[profile] else profile
	assert(p, `profil de marche inconnu : {profile}`)
	local rootName, children, byPart = poseTree(model)
	local sequence = Instance.new("KeyframeSequence")
	sequence.Name = "Marche"
	sequence.Loop = true
	sequence.Priority = Enum.AnimationPriority.Movement
	markSkeleton(model, sequence)
	for i = 0, KEYS_PER_CYCLE do
		local values = Kit.walkPose(p, 2 * math.pi * i / KEYS_PER_CYCLE)
		local keyframe = Instance.new("Keyframe")
		keyframe.Time = p.Cycle * i / KEYS_PER_CYCLE
		local function add(parent: Instance, partName: string)
			local pose = Instance.new("Pose")
			pose.Name = partName
			local v = poseValue(values, byPart[partName])
			if v then
				pose.CFrame = CFrame.new(0, v[4] or 0, 0) * CFrame.Angles(math.rad(v[1]), math.rad(v[2]), math.rad(v[3]))
			end
			pose.EasingStyle = Enum.PoseEasingStyle.Linear
			pose.Parent = parent
			for _, child in children[partName] or {} do
				add(pose, child)
			end
		end
		add(keyframe, rootName)
		keyframe.Parent = sequence
	end
	return sequence
end

-- Attaques de base : poses clés par rôle { rx, ry, rz, y } (degrés, studs), dans le repère racine
-- (+rx = membre vers l'avant, +ry = buste vers la gauche, +rz = bras droit vers l'extérieur).
-- Le combat lance l'animation, les dégâts et la réaction de la cible à la même image (événement
-- Attack) : le coup doit donc tomber tôt. Impact = instant du coup, posé en KeyframeMarker « Impact ».
-- Easing d'une clé = façon d'aller vers la clé suivante (In = accélère vers le coup).
Kit.Attacks = {
	-- Écuyer : coup d'épée en diagonale, bouclier gardé devant, petit pas en avant.
	-- weaponRight à l'impact et après : sans lui, la lame finissait à l'horizontale, dans le
	-- bouclier. Valeurs mesurées sur l'Écuyer : la diagonale finit vers le bas à gauche, devant lui,
	-- sans qu'aucun point de la lame n'entre dans le bouclier, le buste ou les jambes.
	Epee = {
		Length = 0.6, Impact = 0.2,
		Keys = {
			{ Time = 0, Easing = "Out", Poses = {} },
			{ Time = 0.12, Easing = "In", Poses = {
				torso = { 4, -28, 0, 0.05 },
				rightArm = { 75, -20, 30 }, leftArm = { 35, 0, -10 },
				rightLeg = { -4, 28, 0 }, leftLeg = { 10, 28, 0 },
				head = { -2, 22, 0 },
			} },
			{ Time = 0.2, Easing = "Out", Poses = {
				torso = { -14, 30, 0, -0.18 },
				rightArm = { 25, 0, -30 }, weaponRight = { 0, -20, 30 },
				leftArm = { 25, 0, -6 },
				rightLeg = { -6, -30, 0 }, leftLeg = { 30, -30, 0 },
				head = { 8, -25, 0 },
			} },
			{ Time = 0.3, Easing = "InOut", Poses = {
				torso = { -16, 36, 0, -0.2 },
				rightArm = { 12, 0, -36 }, weaponRight = { 0, -40, 0 },
				leftArm = { 22, 0, -6 },
				rightLeg = { -6, -36, 0 }, leftLeg = { 32, -36, 0 },
				head = { 9, -30, 0 },
			} },
			{ Time = 0.6, Easing = "InOut", Poses = {} },
		},
	},
	-- Tréant : gros revers de la main droite, armé en arrière avec le buste tourné, balayé devant
	-- lui à travers le corps ; le bras gauche part en contrepoids, petit pas lourd.
	Griffe = {
		Length = 1.0, Impact = 0.35,
		Keys = {
			{ Time = 0, Easing = "Out", Poses = {} },
			{ Time = 0.25, Easing = "In", Poses = {
				torso = { 6, -45, 4, 0.05 },
				rightArm = { -45, 0, 50 }, leftArm = { 25, 0, -15 },
				rightLeg = { -12, 45, 0 }, leftLeg = { 6, 45, 0 },
				head = { -4, 32, 0 },
			} },
			{ Time = 0.35, Easing = "Out", Poses = {
				torso = { -16, 30, -4, -0.2 },
				rightArm = { 75, 0, -25 }, leftArm = { -20, 0, -20 },
				rightLeg = { 4, -30, 0 }, leftLeg = { 30, -30, 0 },
				head = { 8, -22, 0 },
			} },
			{ Time = 0.5, Easing = "InOut", Poses = {
				torso = { -18, 38, -5, -0.22 },
				rightArm = { 70, 0, -30 }, leftArm = { -22, 0, -20 },
				rightLeg = { 4, -38, 0 }, leftLeg = { 30, -38, 0 },
				head = { 9, -28, 0 },
			} },
			{ Time = 1.0, Easing = "InOut", Poses = {} },
		},
	},
	-- Ultime « Charge du Rempart » (Écuyer) : ramassé derrière le bouclier, épée tirée en arrière,
	-- puis grand estoc en se fendant. L'onde dorée (UltimateEffectController) part à l'impact :
	-- garder Impact égal à ANIMATION_IMPACT de ce contrôleur.
	-- weaponRight : sans lui, le bras levé à 80° pointait la lame vers le haut et la gauche à
	-- l'impact (pointe à 25 % vers l'avant). Valeurs mesurées sur l'Écuyer : pointe à ~98 % vers
	-- l'avant à l'armé (hanche) et pendant l'estoc.
	Rempart = {
		Length = 0.9, Impact = 0.3,
		Keys = {
			{ Time = 0, Easing = "Out", Poses = {} },
			{ Time = 0.15, Easing = "In", Poses = {
				torso = { 10, -20, 0, -0.25 },
				rightArm = { -30, 0, 25 }, weaponRight = { 50, -20, 0 },
				leftArm = { 50, 0, -5 },
				rightLeg = { -25, 20, 0 }, leftLeg = { 15, 20, 0 },
				head = { -5, 15, 0 },
			} },
			{ Time = 0.3, Easing = "Out", Poses = {
				torso = { -18, 25, 0, -0.1 },
				rightArm = { 80, 0, -10 }, weaponRight = { -30, -60, 10 },
				leftArm = { -15, 0, -25 },
				rightLeg = { -10, -25, 0 }, leftLeg = { 38, -25, 0 },
				head = { 10, -20, 0 },
			} },
			{ Time = 0.5, Easing = "InOut", Poses = {
				torso = { -20, 28, 0, -0.12 },
				rightArm = { 78, 0, -12 }, weaponRight = { -30, -60, 10 },
				leftArm = { -18, 0, -25 },
				rightLeg = { -10, -28, 0 }, leftLeg = { 40, -28, 0 },
				head = { 11, -22, 0 },
			} },
			{ Time = 0.9, Easing = "InOut", Poses = {} },
		},
	},
	-- Roi Orc « Fendoir du Roi » : armé lent, lance-hache levée au-dessus de l'épaule en se cambrant,
	-- court temps suspendu, puis abattue devant lui en plongeant (la lame mord le sol), rebond lourd.
	-- C'est le BRAS qui lève et abat l'arme (75-85° à l'armé, 40° à l'impact) ; l'arme ne bascule
	-- que de 50-55° dans la main pour rester dans l'axe de l'avant-bras (weaponRight : +rx relève la
	-- pointe, rz présente les lames). Le bras du Roi Orc est une coque ouverte côté buste : poser
	-- Kit.closeArms sur le modèle avant d'utiliser ce style, sinon l'intérieur noir se voit.
	-- À l'impact, AttackEffectController joue l'effet « Seisme » (attribut EffetAttaque du modèle).
	Fendoir = {
		Length = 1.4, Impact = 0.7,
		Keys = {
			{ Time = 0, Easing = "Out", Poses = {} },
			{ Time = 0.45, Easing = "Out", Poses = {
				torso = { 14, -15, 0, 0.35 },
				rightArm = { 75, 0, 15 }, weaponRight = { 50, -10, 30 },
				leftArm = { 30, 0, -8 },
				rightLeg = { -20, 15, 0 }, leftLeg = { 0, 15, 0 },
				head = { -8, 20, 0 },
			} },
			{ Time = 0.55, Easing = "In", Poses = {
				torso = { 16, -18, 0, 0.4 },
				rightArm = { 85, 0, 18 }, weaponRight = { 55, -12, 30 },
				leftArm = { 32, 0, -8 },
				rightLeg = { -22, 18, 0 }, leftLeg = { -2, 18, 0 },
				head = { -9, 22, 0 },
			} },
			{ Time = 0.7, Easing = "Out", Poses = {
				torso = { -24, 20, 0, 0.2 },
				rightArm = { 40, 0, -10 }, weaponRight = { -40, 0, 0 },
				leftArm = { -10, 0, -25 },
				rightLeg = { 10, -20, 0 }, leftLeg = { 40, -20, 0 },
				head = { 12, -15, 0 },
			} },
			{ Time = 0.85, Easing = "InOut", Poses = {
				torso = { -20, 18, 0, 0.2 },
				rightArm = { 35, 0, -10 }, weaponRight = { -35, 0, 0 },
				leftArm = { -8, 0, -22 },
				rightLeg = { 8, -18, 0 }, leftLeg = { 36, -18, 0 },
				head = { 10, -14, 0 },
			} },
			{ Time = 1.4, Easing = "InOut", Poses = {} },
		},
	},
	-- Attaques de base des héros par famille d'arme (docs/ANIMATION_TOOLS.md § Attaques des héros).
	-- Une séquence par style, rangée dans le jeu partagé Attaque_<Style> : elle vaut pour tout héros du
	-- squelette commun dont l'arme est orientée au repos comme le dit ANIMATION_TOOLS.md § Prise.
	-- Angles d'arme mesurés sur l'atelier (racine : -Z = avant) : +rx du bras avance la main mais
	-- penche vers l'arrière une arme tenue debout ; +rx de l'arme (weaponRight) la penche aussi vers
	-- l'arrière, et fait passer vers l'avant une arme tenue tête en bas. Inclinaison finale d'une arme
	-- debout ≈ rx bras + rx arme (négatif = vers l'avant).
	-- Masse / marteau à une main (tête en bas au repos) : levé derrière la tête, abattu devant (#44).
	Masse = {
		Length = 0.65, Impact = 0.25,
		Keys = {
			{ Time = 0, Easing = "Out", Poses = {} },
			{ Time = 0.15, Easing = "In", Poses = {
				torso = { 10, -20, 0, 0.05 },
				rightArm = { 80, 0, 20 }, weaponRight = { 95, 0, 0 },
				leftArm = { 20, 0, -15 },
				rightLeg = { -4, 20, 0 }, leftLeg = { 8, 20, 0 },
				head = { -6, 15, 0 },
			} },
			{ Time = 0.25, Easing = "Out", Poses = {
				torso = { -16, 25, 0, -0.15 },
				rightArm = { 30, 0, -15 }, weaponRight = { 15, 0, 0 },
				leftArm = { -10, 0, -20 },
				rightLeg = { -6, -25, 0 }, leftLeg = { 28, -25, 0 },
				head = { 8, -20, 0 },
			} },
			{ Time = 0.35, Easing = "InOut", Poses = {
				torso = { -14, 22, 0, -0.13 },
				rightArm = { 28, 0, -15 }, weaponRight = { 12, 0, 0 },
				leftArm = { -8, 0, -18 },
				rightLeg = { -6, -22, 0 }, leftLeg = { 26, -22, 0 },
				head = { 7, -18, 0 },
			} },
			{ Time = 0.65, Easing = "InOut", Poses = {} },
		},
	},
	-- Arme d'hast tenue debout (lance, hallebarde, trident) : abaissée pointe devant en reculant la
	-- main, puis estoc bras tendu (#18).
	Estoc = {
		Length = 0.6, Impact = 0.25,
		Keys = {
			{ Time = 0, Easing = "Out", Poses = {} },
			{ Time = 0.15, Easing = "In", Poses = {
				torso = { 6, -20, 0, 0.05 },
				rightArm = { 15, 0, 10 }, weaponRight = { -105, 0, 0 },
				leftArm = { 35, 0, -10 },
				rightLeg = { -4, 20, 0 }, leftLeg = { 8, 20, 0 },
				head = { -2, 15, 0 },
			} },
			{ Time = 0.25, Easing = "Out", Poses = {
				torso = { -10, 25, 0, -0.1 },
				rightArm = { 55, 0, -5 }, weaponRight = { -140, 0, 0 },
				leftArm = { 30, 0, -10 },
				rightLeg = { -6, -25, 0 }, leftLeg = { 25, -25, 0 },
				head = { 6, -20, 0 },
			} },
			{ Time = 0.35, Easing = "InOut", Poses = {
				torso = { -8, 22, 0, -0.08 },
				rightArm = { 50, 0, -5 }, weaponRight = { -136, 0, 0 },
				leftArm = { 30, 0, -10 },
				rightLeg = { -6, -22, 0 }, leftLeg = { 22, -22, 0 },
				head = { 5, -18, 0 },
			} },
			{ Time = 0.6, Easing = "InOut", Poses = {} },
		},
	},
	-- Bâton de mage tenu debout : ramené contre l'épaule, puis tête du bâton pointée vers la cible,
	-- main libre poussée en avant (#16).
	Sort = {
		Length = 0.7, Impact = 0.3,
		Keys = {
			{ Time = 0, Easing = "Out", Poses = {} },
			{ Time = 0.15, Easing = "In", Poses = {
				torso = { 8, -15, 0, 0.05 },
				rightArm = { 40, 0, 15 }, weaponRight = { -20, 0, 0 },
				leftArm = { 35, 0, -25 },
				rightLeg = { -4, 15, 0 }, leftLeg = { 6, 15, 0 },
				head = { -4, 10, 0 },
			} },
			{ Time = 0.3, Easing = "Out", Poses = {
				torso = { -10, 15, 0, -0.05 },
				rightArm = { 65, 0, -5 }, weaponRight = { -105, 0, 0 },
				leftArm = { 70, 0, -10 },
				rightLeg = { -4, -15, 0 }, leftLeg = { 18, -15, 0 },
				head = { 6, -12, 0 },
			} },
			{ Time = 0.42, Easing = "InOut", Poses = {
				torso = { -9, 14, 0, -0.05 },
				rightArm = { 62, 0, -5 }, weaponRight = { -102, 0, 0 },
				leftArm = { 66, 0, -10 },
				rightLeg = { -4, -14, 0 }, leftLeg = { 16, -14, 0 },
				head = { 5, -11, 0 },
			} },
			{ Time = 0.7, Easing = "InOut", Poses = {} },
		},
	},
	-- Arc tenu debout dans la main droite : bras d'arc tendu vers la cible, main gauche qui tire la
	-- corde jusqu'à l'épaule, lâcher à l'impact (#14). Le buste tourne vers la gauche ; rz du bras
	-- d'arc le ramène face à la cible.
	Tir = {
		Length = 0.8, Impact = 0.45,
		Keys = {
			{ Time = 0, Easing = "Out", Poses = {} },
			{ Time = 0.25, Easing = "InOut", Poses = {
				torso = { 0, 33, 0, 0 },
				rightArm = { 85, 0, 23 }, weaponRight = { -85, 0, 0 },
				leftArm = { 70, 0, 70 },
				rightLeg = { 0, -33, 0 }, leftLeg = { 10, -33, 0 },
				head = { 0, -28, 0 },
			} },
			{ Time = 0.4, Easing = "In", Poses = {
				torso = { 0, 35, 0, 0 },
				rightArm = { 85, 0, 25 }, weaponRight = { -85, 0, 0 },
				leftArm = { 70, 0, 75 },
				rightLeg = { 0, -35, 0 }, leftLeg = { 10, -35, 0 },
				head = { 0, -30, 0 },
			} },
			{ Time = 0.45, Easing = "Out", Poses = {
				torso = { -3, 35, 0, 0 },
				rightArm = { 84, 0, 25 }, weaponRight = { -84, 0, 0 },
				leftArm = { 60, 0, 20 },
				rightLeg = { 0, -35, 0 }, leftLeg = { 10, -35, 0 },
				head = { 0, -30, 0 },
			} },
			{ Time = 0.55, Easing = "InOut", Poses = {
				torso = { -2, 32, 0, 0 },
				rightArm = { 80, 0, 22 }, weaponRight = { -80, 0, 0 },
				leftArm = { 55, 0, 15 },
				rightLeg = { 0, -32, 0 }, leftLeg = { 9, -32, 0 },
				head = { 0, -27, 0 },
			} },
			{ Time = 0.8, Easing = "InOut", Poses = {} },
		},
	},
	-- Mains nues (#20, moine) : ses bras sont modelés levés, poings en garde ; c'est le buste qui
	-- porte le coup (fente avant, poings projetés devant lui). Un bras tourné de +rx enverrait le
	-- poing vers l'arrière.
	Poing = {
		Length = 0.5, Impact = 0.2,
		Keys = {
			{ Time = 0, Easing = "Out", Poses = {} },
			{ Time = 0.1, Easing = "In", Poses = {
				torso = { 10, -25, 0, -0.05 },
				rightArm = { 25, 0, 10 }, leftArm = { -10, 0, -5 },
				rightLeg = { -10, 25, 0 }, leftLeg = { 6, 25, 0 },
				head = { -8, 20, 0 },
			} },
			{ Time = 0.2, Easing = "Out", Poses = {
				torso = { -28, 35, 0, -0.3 },
				rightArm = { -20, 0, -5 }, leftArm = { 15, 0, 5 },
				rightLeg = { -6, -35, 0 }, leftLeg = { 34, -35, 0 },
				head = { 18, -30, 0 },
			} },
			{ Time = 0.3, Easing = "InOut", Poses = {
				torso = { -24, 32, 0, -0.26 },
				rightArm = { -16, 0, -5 }, leftArm = { 12, 0, 5 },
				rightLeg = { -6, -32, 0 }, leftLeg = { 30, -32, 0 },
				head = { 15, -27, 0 },
			} },
			{ Time = 0.5, Easing = "InOut", Poses = {} },
		},
	},
	-- Ultimes des Communs (docs/ultimes/ULTIMES.md, 23/10/2026). Effet visuel : attribut EffetUltime du
	-- modèle de combat, joué par UltimateEffectController à l'Impact de la séquence.
	-- 01 Écuyer « Rempart Fermé » : ramassé derrière le bouclier, pas en avant, bouclier planté à la
	-- verticale devant lui, épée ramenée en arrière ; le choc en forme d'écu part à l'impact.
	RempartFerme = {
		Length = 0.7, Impact = 0.3,
		Keys = {
			{ Time = 0, Easing = "Out", Poses = {} },
			{ Time = 0.12, Easing = "In", Poses = {
				torso = { 6, 0, 0, -0.15 },
				leftArm = { 55, 0, 10 }, weaponLeft = { -10, 0, 0 },
				rightArm = { -15, 0, 20 },
				leftLeg = { -6, 0, 0 }, rightLeg = { 6, 0, 0 },
				head = { -4, 0, 0 },
			} },
			{ Time = 0.3, Easing = "Out", Poses = {
				torso = { -14, 0, 0, -0.35 },
				leftArm = { 38, 0, 5 }, weaponLeft = { -20, 0, 0 },
				rightArm = { -25, 0, 25 },
				leftLeg = { 38, 0, 0 }, rightLeg = { -12, 0, 0 },
				head = { 10, 0, 0 },
			} },
			{ Time = 0.45, Easing = "InOut", Poses = {
				torso = { -12, 0, 0, -0.32 },
				leftArm = { 36, 0, 5 }, weaponLeft = { -18, 0, 0 },
				rightArm = { -22, 0, 22 },
				leftLeg = { 36, 0, 0 }, rightLeg = { -11, 0, 0 },
				head = { 9, 0, 0 },
			} },
			{ Time = 0.7, Easing = "InOut", Poses = {} },
		},
	},
	-- 02 Tireuse « Le Dernier Carreau » : position de tir basse (jambes d'une pièce : pas de vrai genou
	-- à terre ; buste descendu, jambe avant levée, jambe arrière tirée en arrière, rien sous le sol),
	-- arbalète épaulée, recul au tir. Arme visée par Kit.aimedAttack (Kit.AttackAims.DernierCarreau).
	DernierCarreau = {
		Length = 0.8, Impact = 0.45,
		Keys = {
			{ Time = 0, Easing = "Out", Poses = {} },
			{ Time = 0.2, Easing = "InOut", Poses = {
				torso = { 0, 28, 0, -0.55 },
				rightArm = { 82, 0, 14 }, leftArm = { 75, 0, 22 },
				leftLeg = { 66, -28, 0 }, rightLeg = { -56, -28, 0 },
				head = { 0, -23, 0 },
			} },
			{ Time = 0.4, Easing = "In", Poses = {
				torso = { 0, 30, 0, -0.6 },
				rightArm = { 85, 0, 15 }, leftArm = { 80, 0, 28 },
				leftLeg = { 70, -30, 0 }, rightLeg = { -60, -30, 0 },
				head = { 0, -25, 0 },
			} },
			{ Time = 0.45, Easing = "Out", Poses = {
				torso = { -6, 30, 0, -0.6 },
				rightArm = { 92, 0, 15 }, leftArm = { 86, 0, 25 },
				leftLeg = { 70, -30, 0 }, rightLeg = { -60, -30, 0 },
				head = { -3, -25, 0 },
			} },
			{ Time = 0.6, Easing = "InOut", Poses = {
				torso = { -2, 29, 0, -0.58 },
				rightArm = { 86, 0, 15 }, leftArm = { 80, 0, 25 },
				leftLeg = { 68, -29, 0 }, rightLeg = { -58, -29, 0 },
				head = { 0, -24, 0 },
			} },
			{ Time = 0.8, Easing = "InOut", Poses = {} },
		},
	},
	-- Ultimes des Peu communs (23/10/2026). Armes visées par Kit.aimedAttack (Kit.AttackAims).
	-- 03 Lancier « Haie de Lances » : lance pivotée à l'horizontale, puis trois estocs en éventail
	-- (gauche, centre, droite ; 0,3 / 0,45 / 0,6 s), le buste suit chaque estoc.
	HaieDeLances = {
		Length = 0.85, Impact = 0.3,
		Keys = {
			{ Time = 0, Easing = "Out", Poses = {} },
			{ Time = 0.14, Easing = "In", Poses = {
				torso = { 4, -15, 0, -0.1 },
				rightArm = { 30, 0, 15 },
				leftArm = { 35, 0, -10 },
				rightLeg = { -4, 15, 0 },
				leftLeg = { 8, 15, 0 },
				head = { 0, 12, 0 },
			} },
			{ Time = 0.3, Easing = "Out", Poses = {
				torso = { -10, 40, 0, -0.12 },
				rightArm = { 60, 0, -5 },
				leftArm = { 30, 0, -10 },
				rightLeg = { -6, -40, 0 },
				leftLeg = { 25, -40, 0 },
				head = { 6, -32, 0 },
			} },
			{ Time = 0.38, Easing = "InOut", Poses = {
				torso = { -4, 30, 0, -0.1 },
				rightArm = { 30, 0, 5 },
				leftArm = { 30, 0, -10 },
				rightLeg = { -6, -30, 0 },
				leftLeg = { 20, -30, 0 },
				head = { 4, -25, 0 },
			} },
			{ Time = 0.45, Easing = "Out", Poses = {
				torso = { -10, 25, 0, -0.12 },
				rightArm = { 60, 0, -5 },
				leftArm = { 30, 0, -10 },
				rightLeg = { -6, -25, 0 },
				leftLeg = { 25, -25, 0 },
				head = { 6, -20, 0 },
			} },
			{ Time = 0.53, Easing = "InOut", Poses = {
				torso = { -4, 15, 0, -0.1 },
				rightArm = { 30, 0, 5 },
				leftArm = { 30, 0, -10 },
				rightLeg = { -6, -15, 0 },
				leftLeg = { 20, -15, 0 },
				head = { 4, -12, 0 },
			} },
			{ Time = 0.6, Easing = "Out", Poses = {
				torso = { -10, 8, 0, -0.12 },
				rightArm = { 60, 0, -5 },
				leftArm = { 30, 0, -10 },
				rightLeg = { -6, -8, 0 },
				leftLeg = { 25, -8, 0 },
				head = { 6, -5, 0 },
			} },
			{ Time = 0.85, Easing = "InOut", Poses = {} },
		},
	},
	-- 04 Pyromancien « Braise Indocile » : gemme levée (elle tousse trois braises), bâton ramené en
	-- arrière, puis propulsé vers la cible (la braise rebondit sur une seconde cible).
	BraiseIndocile = {
		Length = 0.85, Impact = 0.45,
		Keys = {
			{ Time = 0, Easing = "Out", Poses = {} },
			{ Time = 0.15, Easing = "InOut", Poses = {
				torso = { 6, -10, 0, -0.14 },
				rightArm = { 45, 0, 5 },
				leftArm = { 20, 0, -15 },
				rightLeg = { -3, 10, 0 },
				leftLeg = { 4, 10, 0 },
				head = { -8, 8, 0 },
			} },
			{ Time = 0.3, Easing = "In", Poses = {
				torso = { 10, -25, 0, -0.17 },
				rightArm = { 25, 0, 20 },
				leftArm = { 35, 0, -20 },
				rightLeg = { -6, 25, 0 },
				leftLeg = { 8, 25, 0 },
				head = { -6, 20, 0 },
			} },
			{ Time = 0.45, Easing = "Out", Poses = {
				torso = { -12, 20, 0, -0.08 },
				rightArm = { 70, 0, -5 },
				leftArm = { 50, 0, -15 },
				rightLeg = { -6, -20, 0 },
				leftLeg = { 22, -20, 0 },
				head = { 8, -16, 0 },
			} },
			{ Time = 0.6, Easing = "InOut", Poses = {
				torso = { -10, 18, 0, -0.07 },
				rightArm = { 66, 0, -5 },
				leftArm = { 46, 0, -15 },
				rightLeg = { -6, -18, 0 },
				leftLeg = { 20, -18, 0 },
				head = { 7, -14, 0 },
			} },
			{ Time = 0.85, Easing = "InOut", Poses = {} },
		},
	},
	-- 05 Brise-Pierre « Fendaille de Carrière » : masse ramenée derrière la tête à deux mains, tenue,
	-- puis coup massif : la tête de la masse mord le sol (0,1 stud), d'où part la fissure.
	FendailleDeCarriere = {
		Length = 0.9, Impact = 0.42,
		Keys = {
			{ Time = 0, Easing = "Out", Poses = {} },
			{ Time = 0.25, Easing = "Out", Poses = {
				torso = { 14, -12, 0, -0.3 },
				rightArm = { 80, 0, 15 },
				leftArm = { 70, 0, -10 },
				rightLeg = { -14, 12, 0 },
				leftLeg = { 2, 12, 0 },
				head = { -10, 10, 0 },
			} },
			{ Time = 0.32, Easing = "In", Poses = {
				torso = { 16, -14, 0, -0.33 },
				rightArm = { 82, 0, 16 },
				leftArm = { 72, 0, -10 },
				rightLeg = { -15, 14, 0 },
				leftLeg = { 2, 14, 0 },
				head = { -11, 11, 0 },
			} },
			{ Time = 0.42, Easing = "Out", Poses = {
				torso = { -26, 12, 0, -0.35 },
				rightArm = { 65, 0, -12 },
				leftArm = { 60, 0, -8 },
				rightLeg = { -8, -12, 0 },
				leftLeg = { 34, -12, 0 },
				head = { 12, -10, 0 },
			} },
			{ Time = 0.58, Easing = "InOut", Poses = {
				torso = { -24, 10, 0, -0.33 },
				rightArm = { 63, 0, -12 },
				leftArm = { 58, 0, -8 },
				rightLeg = { -8, -10, 0 },
				leftLeg = { 32, -10, 0 },
				head = { 11, -9, 0 },
			} },
			{ Time = 0.9, Easing = "InOut", Poses = {} },
		},
	},
	-- 06 Guetteuse « Cor des Cimes » : la main libre monte à la bouche (le modèle n'a pas de cor :
	-- l'appel est dit par l'effet), tête levée, puis le tir de Tir ; flèche lâchée à 0,62 s.
	CorDesCimes = {
		Length = 0.95, Impact = 0.62,
		Keys = {
			{ Time = 0, Easing = "Out", Poses = {} },
			{ Time = 0.15, Easing = "InOut", Poses = {
				torso = { -6, 0, 0, 0.05 },
				leftArm = { 120, 0, 40 },
				rightArm = { 10, 0, 10 },
				head = { -14, 0, 0 },
			} },
			{ Time = 0.3, Easing = "InOut", Poses = {
				torso = { -8, 0, 0, 0.05 },
				leftArm = { 122, 0, 42 },
				rightArm = { 10, 0, 10 },
				head = { -16, 0, 0 },
			} },
			{ Time = 0.45, Easing = "InOut", Poses = {
				torso = { 0, 33, 0, 0 },
				rightArm = { 85, 0, 23 },
				leftArm = { 70, 0, 70 },
				rightLeg = { 0, -33, 0 },
				leftLeg = { 10, -33, 0 },
				head = { 0, -28, 0 },
			} },
			{ Time = 0.58, Easing = "In", Poses = {
				torso = { 0, 35, 0, 0 },
				rightArm = { 85, 0, 25 },
				leftArm = { 70, 0, 75 },
				rightLeg = { 0, -35, 0 },
				leftLeg = { 10, -35, 0 },
				head = { 0, -30, 0 },
			} },
			{ Time = 0.62, Easing = "Out", Poses = {
				torso = { -3, 35, 0, 0 },
				rightArm = { 84, 0, 25 },
				leftArm = { 60, 0, 20 },
				rightLeg = { 0, -35, 0 },
				leftLeg = { 10, -35, 0 },
				head = { 0, -30, 0 },
			} },
			{ Time = 0.72, Easing = "InOut", Poses = {
				torso = { -2, 32, 0, 0 },
				rightArm = { 80, 0, 22 },
				leftArm = { 55, 0, 15 },
				rightLeg = { 0, -32, 0 },
				leftLeg = { 9, -32, 0 },
				head = { 0, -27, 0 },
			} },
			{ Time = 0.95, Easing = "InOut", Poses = {} },
		},
	},
	-- Variante : les deux bras levés puis abattus au sol, buste plié, rebond lourd.
	Ecrasement = {
		Length = 1.0, Impact = 0.32,
		Keys = {
			{ Time = 0, Easing = "Out", Poses = {} },
			{ Time = 0.22, Easing = "In", Poses = {
				torso = { 14, 0, 0, 0.1 },
				rightArm = { 125, 0, 22 }, leftArm = { 125, 0, -22 },
				rightLeg = { -14, 0, 0 }, leftLeg = { -14, 0, 0 },
				head = { -12, 0, 0 },
			} },
			{ Time = 0.32, Easing = "Out", Poses = {
				torso = { -26, 0, 0, -0.4 },
				rightArm = { 62, 0, 6 }, leftArm = { 62, 0, -6 },
				rightLeg = { 26, 0, 0 }, leftLeg = { 26, 0, 0 },
				head = { 12, 0, 0 },
			} },
			{ Time = 0.45, Easing = "InOut", Poses = {
				torso = { -22, 0, 0, -0.32 },
				rightArm = { 54, 0, 8 }, leftArm = { 54, 0, -8 },
				rightLeg = { 22, 0, 0 }, leftLeg = { 22, 0, 0 },
				head = { 9, 0, 0 },
			} },
			{ Time = 1.0, Easing = "InOut", Poses = {} },
		},
	},
}

local EASING_DIRECTIONS = {
	In = Enum.PoseEasingDirection.In,
	Out = Enum.PoseEasingDirection.Out,
	InOut = Enum.PoseEasingDirection.InOut,
}

-- Crée une animation à poses clés (non bouclée, priorité Action) : style = nom de Kit.Attacks ou table.
function Kit.keyed(model: Model, name: string, style: any): KeyframeSequence
	local s = if typeof(style) == "string" then Kit.Attacks[style] else style
	assert(s, `style inconnu : {style}`)
	local rootName, children, byPart = poseTree(model)
	local sequence = Instance.new("KeyframeSequence")
	sequence.Name = name
	sequence.Loop = false
	sequence.Priority = Enum.AnimationPriority.Action
	sequence:SetAttribute("Impact", s.Impact)
	markSkeleton(model, sequence)
	for _, key in s.Keys do
		local keyframe = Instance.new("Keyframe")
		keyframe.Time = key.Time
		local function add(parent: Instance, partName: string)
			local pose = Instance.new("Pose")
			pose.Name = partName
			local v = poseValue(key.Poses, byPart[partName])
			if v then
				pose.CFrame = CFrame.new(0, v[4] or 0, 0) * CFrame.Angles(math.rad(v[1]), math.rad(v[2]), math.rad(v[3]))
			end
			pose.EasingStyle = Enum.PoseEasingStyle.Cubic
			pose.EasingDirection = EASING_DIRECTIONS[key.Easing] or Enum.PoseEasingDirection.InOut
			pose.Parent = parent
			for _, child in children[partName] or {} do
				add(pose, child)
			end
		end
		add(keyframe, rootName)
		if math.abs(key.Time - s.Impact) < 1e-6 then
			local marker = Instance.new("KeyframeMarker")
			marker.Name = "Impact"
			marker.Parent = keyframe
		end
		keyframe.Parent = sequence
	end
	return sequence
end

-- Arbalète (#02) : mêmes poses que Tir ; seule la visée de l'arme change (Kit.AttackAims).
Kit.Attacks.Arbalete = Kit.Attacks.Tir

-- Direction visée par le manche de l'arme (vers sa tête) aux clés des styles de héros, dans le repère
-- de la racine (-Z = avant, +Y = haut, +X = droite du héros). « rest » : garder l'orientation du repos
-- par rapport à la racine (arc tenu debout). Kit.aimedAttack recalcule weaponRight (weaponLeft) pour
-- chaque héros : les armes ne sont pas tenues pareil au repos (debout, tête en bas, en travers), un
-- angle d'arme commun les envoyait dans toutes les directions.
Kit.AttackAims = {
	Epee = { [0.12] = Vector3.new(0.45, 0.7, 0.55), [0.2] = Vector3.new(-0.55, -0.35, -0.75), [0.3] = Vector3.new(-0.6, -0.65, -0.45) },
	Masse = { [0.15] = Vector3.new(0.15, 0.7, 0.7), [0.25] = Vector3.new(0, -0.45, -0.9), [0.35] = Vector3.new(0, -0.55, -0.85) },
	Estoc = { [0.15] = Vector3.new(0, -0.15, -1), [0.25] = Vector3.new(0, 0.02, -1), [0.35] = Vector3.new(0, 0, -1) },
	Sort = { [0.15] = Vector3.new(0.1, 0.95, 0.3), [0.3] = Vector3.new(0, 0.55, -0.85), [0.42] = Vector3.new(0, 0.6, -0.8) },
	Tir = { [0.25] = "rest", [0.4] = "rest", [0.45] = "rest", [0.55] = "rest" },
	Arbalete = { [0.25] = Vector3.new(0, 0, -1), [0.4] = Vector3.new(0, 0, -1), [0.45] = Vector3.new(0, 0.15, -1), [0.55] = Vector3.new(0, 0.05, -1) },
	DernierCarreau = { [0.2] = Vector3.new(0, 0, -1), [0.4] = Vector3.new(0, 0.02, -1), [0.45] = Vector3.new(0, 0.2, -1), [0.6] = Vector3.new(0, 0.06, -1) },
	HaieDeLances = { [0.14] = Vector3.new(-0.2, 0, -1), [0.3] = Vector3.new(-0.4, 0.02, -1), [0.38] = Vector3.new(-0.25, 0, -1), [0.45] = Vector3.new(0, 0.02, -1), [0.53] = Vector3.new(0.15, 0, -1), [0.6] = Vector3.new(0.4, 0.02, -1) },
	BraiseIndocile = { [0.15] = Vector3.new(0, 1, -0.35), [0.3] = Vector3.new(0.25, 0.8, 0.55), [0.45] = Vector3.new(0, 0.3, -1), [0.6] = Vector3.new(0, 0.35, -1) },
	FendailleDeCarriere = { [0.25] = Vector3.new(0.1, 0.6, 0.8), [0.32] = Vector3.new(0.1, 0.55, 0.85), [0.42] = Vector3.new(0, -0.6, -1), [0.58] = Vector3.new(0, -0.62, -1) },
	CorDesCimes = { [0.45] = "rest", [0.58] = "rest", [0.62] = "rest", [0.72] = "rest" },
}

local AIM_JOINTS = { torso = "Racine", head = "Cou", leftArm = "EpauleGauche", rightArm = "EpauleDroite",
	leftLeg = "HancheGauche", rightLeg = "HancheDroite" }

-- Style d'attaque d'un héros riggé, arme visée : poses du style (Kit.Attacks.<style>, suffixe _G =
-- main gauche, Kit.mirror), plus la rotation de l'os d'arme qui amène le manche de sa Prise sur la
-- direction de Kit.AttackAims à chaque clé. options.Flip : la Prise du modèle pointe vers le talon de
-- l'arme (#55, champignon) ; options.Free : accepter une Prise libre (bâton tenu par l'anse, #41, #51,
-- #65). Le modèle est remis au repos après la mesure.
function Kit.aimedAttack(model: Model, styleName: string, options: { Flip: boolean?, Free: boolean? }?): any
	local opts = options or {}
	local left = string.sub(styleName, -2) == "_G"
	local base = if left then string.sub(styleName, 1, -3) else styleName
	assert(Kit.Attacks[base], `style inconnu : {styleName}`)
	local style = if left then Kit.mirror(Kit.Attacks[base]) else Kit.Attacks[base]
	local aims = Kit.AttackAims[base]
	local hand = model:FindFirstChild(if left then "MainGauche" else "MainDroite", true) :: Motor6D?
	if not (aims and hand) then
		return style
	end
	local prise: Attachment? = nil
	for _, joint in model:GetDescendants() do
		if joint:IsA("Motor6D") and joint.Part0 == hand.Part1 and joint.Part1 then
			local found = (joint.Part1 :: BasePart):FindFirstChild(GRIP.Weapon)
			if found and found:IsA("Attachment") and (opts.Free or found:GetAttribute(GRIP.Free) ~= true) then
				prise = found
			end
		end
	end
	if not prise then
		return style
	end
	local root = (model.PrimaryPart :: BasePart).CFrame
	local function handFrame(): CFrame
		return (hand.Part0 :: BasePart).CFrame * hand.C0
	end
	local axis = prise.WorldAxis * (if opts.Flip then -1 else 1)
	local restInRoot = root:VectorToObjectSpace(axis)
	local inHand = handFrame():VectorToObjectSpace(axis)
	local role = if left then "weaponLeft" else "weaponRight"
	local keys = {}
	for _, key in style.Keys do
		local poses = table.clone(key.Poses)
		local target: any = nil
		for time, direction in aims do
			if math.abs(time - key.Time) < 1e-6 then
				target = direction
			end
		end
		if target then
			-- pose de la clé sans l'arme, mesure du repère de la main, rotation de l'arme
			local saved: { [Motor6D]: CFrame } = {}
			for poseRole, v in poses do
				local motor = AIM_JOINTS[poseRole] and model:FindFirstChild(AIM_JOINTS[poseRole], true) :: Motor6D?
				if motor then
					saved[motor] = motor.C0
					motor.C0 = motor.C0 * CFrame.new(0, v[4] or 0, 0) * CFrame.Angles(math.rad(v[1]), math.rad(v[2]), math.rad(v[3]))
				end
			end
			local want = if target == "rest" then restInRoot else ((if left then target * Vector3.new(-1, 1, 1) else target) :: Vector3).Unit
			local goal = handFrame():VectorToObjectSpace(root:VectorToWorldSpace(want))
			for motor, c0 in saved do
				motor.C0 = c0
			end
			local cross = inHand:Cross(goal)
			local angle = math.acos(math.clamp(inHand:Dot(goal), -1, 1))
			local rotation = if cross.Magnitude < 1e-5 then CFrame.identity else CFrame.fromAxisAngle(cross.Unit, angle)
			local rx, ry, rz = rotation:ToEulerAnglesXYZ()
			poses[role] = { math.deg(rx), math.deg(ry), math.deg(rz) }
		end
		table.insert(keys, { Time = key.Time, Easing = key.Easing, Poses = poses })
	end
	return { Length = style.Length, Impact = style.Impact, Keys = keys }
end

-- Style en miroir gauche / droite (héros qui tient son arme de la main gauche) : bras, jambes et
-- armes échangés, ry et rz opposés. Kit.Attacks.<Style>_G est créé à la demande.
function Kit.mirror(style: any): any
	local swap = { leftArm = "rightArm", rightArm = "leftArm", leftLeg = "rightLeg", rightLeg = "leftLeg",
		weaponLeft = "weaponRight", weaponRight = "weaponLeft" }
	local keys = {}
	for _, key in style.Keys do
		local poses = {}
		for role, v in key.Poses do
			poses[swap[role] or role] = { v[1], -v[2], -v[3], v[4] }
		end
		table.insert(keys, { Time = key.Time, Easing = key.Easing, Poses = poses })
	end
	return { Length = style.Length, Impact = style.Impact, Keys = keys }
end

-- Attaque de base « Attaque » d'un modèle riggé.
function Kit.attack(model: Model, style: any): KeyframeSequence
	if typeof(style) == "string" and not Kit.Attacks[style] and string.sub(style, -2) == "_G" then
		local base = Kit.Attacks[string.sub(style, 1, -3)]
		assert(base, `style inconnu : {style}`)
		Kit.Attacks[style] = Kit.mirror(base)
	end
	return Kit.keyed(model, "Attaque", style)
end

-- Ultime « Ultime » d'un héros riggé (même format de style que les attaques, ex. "Rempart").
function Kit.ultimate(model: Model, style: any): KeyframeSequence
	return Kit.keyed(model, "Ultime", style)
end

local function folder(parent: Instance, name: string, className: string?): Instance
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local created = Instance.new(className or "Folder")
	created.Name = name
	created.Parent = parent
	return created
end

-- Range une séquence dans ReplicatedStorage.Assets.Animations.<set> et en copie pour l'Animation
-- Editor (ServerStorage.RBX_ANIMSAVES.<modèle>). Remplace une version précédente.
local function store(model: Model, set: string, sequence: KeyframeSequence): Instance
	local assets = folder(ReplicatedStorage, "Assets")
	local target = folder(folder(assets, "Animations"), set)
	local old = target:FindFirstChild(sequence.Name)
	if old then
		-- Version remplacée gardée hors du jeu (ServerStorage), comme les séquences retirées par Kit.share.
		local archive = folder(ServerStorage, ARCHIVE)
		local previous = archive:FindFirstChild(`{set}_{sequence.Name}`)
		if previous then
			previous:Destroy()
		end
		old.Name = `{set}_{sequence.Name}`
		old.Parent = archive
	end
	sequence.Parent = target
	local saves = folder(folder(ServerStorage, "RBX_ANIMSAVES"), model.Name, "Model")
	local oldSave = saves:FindFirstChild(sequence.Name)
	if oldSave then
		oldSave:Destroy()
	end
	sequence:Clone().Parent = saves
	local link = model:FindFirstChild("AnimSaves") or Instance.new("ObjectValue")
	link.Name = "AnimSaves"
	;(link :: ObjectValue).Value = saves
	link.Parent = model
	return target
end

-- Range une animation propre au modèle dans son jeu de combat (Assets.Animations.<Set>).
function Kit.install(model: Model, set: string, sequence: KeyframeSequence): ()
	store(model, set, sequence)
	model:SetAttribute("JeuAnimationsCombat", set)
	if model:GetAttribute("JeuAnimations") == nil then
		model:SetAttribute("JeuAnimations", set)
	end
end

-- Range une animation du squelette commun dans un jeu partagé (ex. Squelette_Leger) et branche le
-- modèle dessus (attribut JeuAnimationsCommun). Tout autre modèle au squelette commun peut ensuite
-- utiliser ce jeu sans nouvelle séquence : il suffit de lui poser le même JeuAnimationsCommun.
-- La recherche lit le jeu propre avant le jeu commun : l'ancienne séquence du même nom dans les jeux
-- propres du modèle (Marche de l'ancien squelette) est donc déplacée dans ServerStorage.AnimationKitArchive
-- (AnimationSets.unshadow), sinon elle masquerait la commune. Tout modèle de ce jeu propre est concerné :
-- remplacer aussi son asset de combat par la version migrée.
function Kit.share(model: Model, set: string, sequence: KeyframeSequence): ()
	assert(sequence:GetAttribute("Squelette") == Skeleton.Name,
		`{sequence.Name} n'est pas faite sur le squelette commun (Kit.unrig puis Kit.rig, puis régénérer)`)
	local target = store(model, set, sequence)
	target:SetAttribute("Squelette", Skeleton.Name)
	model:SetAttribute("JeuAnimationsCommun", set)
	for _, old in AnimationSets.unshadow(model, sequence.Name, folder(ServerStorage, ARCHIVE)) do
		print(`[AnimationKit] {old.Name} retirée du jeu propre (ServerStorage.{ARCHIVE}) : {sequence.Name} vient de {set}`)
	end
end

-- Aperçu en boucle au Play : l'animation est copiée dans Assets.Animations.Apercu_<Set> sous le nom
-- « Attente », que MonsterAnimationController joue sans jamais la couper.
-- rest (s) : pause en pose neutre ajoutée après une animation non bouclée (attaque...), pour la voir
-- se répéter à un rythme lisible. Par défaut 0,8 s pour une animation non bouclée, 0 sinon.
-- L'animation est cherchée dans <Set>, puis dans les jeux du modèle (dont son jeu commun).
-- Le jeu d'aperçu porte l'attribut Apercu : il n'est jamais complété par le jeu commun, ni lu en combat.
function Kit.preview(model: Model, set: string, animationName: string, rest: number?): ()
	local animations = folder(folder(ReplicatedStorage, "Assets"), "Animations")
	local own = animations:FindFirstChild(set)
	local source = (own and own:FindFirstChild(animationName)) or AnimationSets.find(model, animationName, true)
	assert(source and source:IsA("KeyframeSequence"), `animation {animationName} introuvable dans {set} ni dans les jeux du modèle`)
	local preview = folder(animations, "Apercu_" .. set)
	preview:SetAttribute("Note", "Aperçu uniquement (AtelierAnimation) : l'animation étudiée joue en boucle sous le nom Attente. Ne pas utiliser en combat.")
	preview:SetAttribute("Apercu", true)
	preview:ClearAllChildren()
	local loop = source:Clone()
	local pause = rest or (if source.Loop then 0 else 0.8)
	if pause > 0 then
		local last: Keyframe? = nil
		for _, keyframe in loop:GetKeyframes() do
			if not last or keyframe.Time > last.Time then
				last = keyframe
			end
		end
		assert(last, `{set}.{animationName} n'a aucune clé`)
		local hold = last:Clone()
		hold.Time = last.Time + pause
		for _, marker in hold:GetDescendants() do
			if marker:IsA("KeyframeMarker") then
				marker:Destroy()
			end
		end
		hold.Parent = loop
	end
	loop.Name = "Attente"
	loop.Loop = true
	loop.Priority = Enum.AnimationPriority.Idle
	loop.Parent = preview
	model:SetAttribute("JeuAnimations", "Apercu_" .. set)
	model:SetAttribute("JeuAnimationsCombat", set)
	model:SetAttribute("ApercuPause", 0.1)
	CollectionService:AddTag(model, PREVIEW_TAG)
end

-- Copie un modèle source (jamais modifié) dans Workspace.AtelierAnimation.
function Kit.copy(source: Model, name: string?): Model
	local atelier = folder(workspace, ATELIER)
	local copyName = name or source.Name
	assert(not atelier:FindFirstChild(copyName), `{ATELIER}.{copyName} existe déjà`)
	local model = source:Clone()
	model.Name = copyName
	model:SetAttribute("Modele", source:GetAttribute("Modele") or source.Name) -- fiche SkeletonConfig de la source
	for _, tag in CollectionService:GetTags(model) do
		CollectionService:RemoveTag(model, tag)
	end
	model.Parent = atelier
	return model
end

-- Range tous les modèles de l'atelier en ligne devant le SpawnLocation, tournés vers lui, pieds au sol.
function Kit.arrange(): ()
	local atelier = workspace:FindFirstChild(ATELIER)
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	assert(atelier and spawn, "AtelierAnimation ou SpawnLocation introuvable")
	local spawnPosition = (spawn :: BasePart).Position
	local groundY = spawnPosition.Y - (spawn :: BasePart).Size.Y / 2
	local models = {}
	for _, child in atelier:GetChildren() do
		if child:IsA("Model") and child.PrimaryPart then
			table.insert(models, child)
		end
	end
	table.sort(models, function(a: Model, b: Model): boolean
		return a.Name < b.Name
	end)
	-- Alternance gauche/droite en laissant libre l'axe du spawn, où se tient le joueur ; chaque
	-- modèle prend la place de sa largeur (un boss est bien plus large qu'un héros).
	local gap = 3
	local leftEdge, rightEdge = spawnPosition.X - gap, spawnPosition.X + gap
	for index, model in models do
		local _, size = model:GetBoundingBox()
		local width = math.max(size.X, size.Z)
		local x
		if index % 2 == 1 then
			x = leftEdge - width / 2
			leftEdge -= width + gap
		else
			x = rightEdge + width / 2
			rightEdge += width + gap
		end
		local spot = Vector3.new(x, groundY, spawnPosition.Z - 14)
		local root = model.PrimaryPart :: BasePart
		local offset = root.CFrame:ToObjectSpace(model:GetPivot())
		model:PivotTo(CFrame.lookAt(spot, Vector3.new(spawnPosition.X, groundY, spawnPosition.Z)) * offset)
		model:PivotTo(model:GetPivot() + Vector3.new(0, groundY - lowestPoint(model), 0))
	end
end

-- Tout en un : copie, squelette commun, marche, attaque, ultime, rangement, aperçu près du spawn.
--   options = { Source: Model, Set: string, Name: string?,
--               Map: string | table ? (fiche SkeletonConfig.Models ; par défaut celle de Set),
--               Profile: string | table ? (Kit.Profiles), Attack: string | table ?, Ultimate: string | table ?
--                 (styles de Kit.Attacks), Shared: string | false ? (jeu commun de la marche),
--               CloseArms: Color3? (couvercles de bras couleur peau, voir Kit.closeArms),
--               Held / Parts (anciennes options, voir Kit.rig), Preview: string? ("Marche" par défaut),
--               Arrange: boolean? (false : ne pas ranger tout l'atelier avec Kit.arrange) }
-- Une option absente est lue dans la fiche (Profil, Attaque, Ultime, Commun, CouvercleBras).
-- Avec un jeu commun, la marche y est rangée (Kit.share) ; attaque et ultime vont dans <Set>.
function Kit.prepare(options: { [string]: any }): Model
	local entry = options.Map
	if entry == nil or typeof(entry) == "string" then
		entry = SkeletonConfig.Models[entry or options.Set]
		assert(entry or options.Map == nil, `fiche {options.Map} absente de SkeletonConfig.Models`)
	end
	entry = entry or {}
	local profile = options.Profile or entry.Profil
	assert(profile, `{options.Set} : profil de marche manquant (Profile, ou Profil dans SkeletonConfig)`)
	local sharedSet = if options.Shared == false then nil else options.Shared or entry.Commun
	local attack = options.Attack or entry.Attaque
	local ultimate = options.Ultimate or entry.Ultime
	local skin = options.CloseArms
	if not skin and entry.CouvercleBras then
		skin = Color3.fromRGB(entry.CouvercleBras[1], entry.CouvercleBras[2], entry.CouvercleBras[3])
	end
	local recording = ChangeHistoryService:TryBeginRecording("AnimationKit : " .. options.Set)
	local ok, result = pcall(function()
		local model = Kit.copy(options.Source, options.Name)
		Kit.rig(model, { Map = entry, Held = options.Held, Parts = options.Parts })
		if skin then
			Kit.closeArms(model, skin)
		end
		-- Jeu propre déclaré avant Kit.share : une ancienne Marche de <Set> doit en sortir (bug #56).
		model:SetAttribute("JeuAnimations", options.Set)
		model:SetAttribute("JeuAnimationsCombat", options.Set)
		local walk = Kit.walk(model, profile)
		if sharedSet then
			Kit.share(model, sharedSet, walk)
		else
			Kit.install(model, options.Set, walk)
		end
		if attack then
			Kit.install(model, options.Set, Kit.attack(model, attack))
		end
		if ultimate then
			Kit.install(model, options.Set, Kit.ultimate(model, ultimate))
		end
		Kit.preview(model, options.Set, options.Preview or "Marche")
		if options.Arrange ~= false then
			Kit.arrange()
		end
		return model
	end)
	if recording then
		ChangeHistoryService:FinishRecording(recording, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
	else
		ChangeHistoryService:SetWaypoint("AnimationKit : " .. options.Set)
	end
	if not ok then
		error(result, 0)
	end
	print(`[AnimationKit] {result:GetFullName()} prêt (squelette {Skeleton.Name}, jeu commun {sharedSet or "aucun"}) : lancer Play pour voir la marche.`)
	return result
end

_G.AnimationKit = Kit
return Kit
