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

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Kit = {}

local ATELIER = "AtelierAnimation"
local PREVIEW_TAG = "ApercuAnimation"
local KEYS_PER_CYCLE = 16

-- Pièces repérées par leur nom : format des modèles générés par l'IA de Studio.
local PART_NAMES = {
	torso = { "torso_geom", "body_geom", "chest_geom" },
	head = { "head_geom", "mask_head_geom", "skull_geom" },
	leftArm = { "left_arm_geom" },
	rightArm = { "right_arm_geom" },
	leftLeg = { "left_leg_geom" },
	rightLeg = { "right_leg_geom" },
}
-- Une pièce dont le nom contient l'un de ces mots est tenue par la main la plus proche ;
-- toute autre pièce restante est fixée au buste (ceinture, cor, cristal, cape...).
-- Noms relevés sur les héros du Bestiaire (weapon_geom, buckler_geom, coutelas_geom, etendard_geom...).
local HELD_WORDS = {
	"weapon", "arme", "sword", "epee", "blade", "lame", "grip", "guard", "pommel", "garde", "pommeau", "poignee",
	"axe", "hache", "spear", "lance", "staff", "baton", "wand", "bow", "arc", "shield", "bouclier", "buckler",
	"dagger", "dague", "knife", "couteau", "coutelas", "hammer", "marteau", "mace", "masse", "club", "gourdin",
	"scythe", "faux", "torch", "torche", "lantern", "lanterne", "book", "livre", "banner", "banniere", "etendard",
	"cloche", "battant",
}
-- Toujours fixées au buste, même si leur nom contient un mot ci-dessus (shoulder_guard, ceinture...).
local WORN_WORDS = { "shoulder", "epaul", "cape", "tabard", "apron", "tablier", "quiver", "carquois", "belt", "ceinture", "helm", "heaume" }

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

-- Rôle d'une pièce animée, déduit du nom de son articulation.
local JOINT_ROLES = {
	Racine = "torso", Cou = "head",
	EpauleGauche = "leftArm", EpauleDroite = "rightArm",
	HancheGauche = "leftLeg", HancheDroite = "rightLeg",
}

local function find(model: Model, names: { string }): BasePart?
	for _, name in names do
		local part = model:FindFirstChild(name, true)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

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

local function lowestPoint(model: Model): number
	local y = math.huge
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			local mn = bounds(part, CFrame.identity)
			y = math.min(y, mn.Y)
		end
	end
	return y
end

local function isHeld(part: BasePart): boolean
	local name = string.lower(part.Name)
	for _, word in WORN_WORDS do
		if string.find(name, word, 1, true) then
			return false
		end
	end
	for _, word in HELD_WORDS do
		if string.find(name, word, 1, true) then
			return true
		end
	end
	return false
end

local function jointName(part: BasePart): string
	local base = string.gsub(part.Name, "_geom$", "")
	return "Fixe_" .. base
end

-- Pose un squelette Motor6D sur un modèle de pièces séparées (format IA : <membre>_geom).
-- Repère racine : X = droite du personnage (du bras gauche vers le bras droit), -Z = avant.
-- options.Held = { [nomDePièce] = mode } force le rattachement d'une pièce (toutes celles de ce nom) :
--   "left" / "right" : tenue en main (suit la main, animable comme arme : weaponLeft / weaponRight) ;
--   "nearest"        : portée par le bras le plus proche (épaulière, pic, crâne d'épaule) ;
--   "torso"          : fixée au buste.
-- options.Parts = { [rôle] = nomDePièce } désigne une pièce de rôle au nom inhabituel
--   (ex. { head = "body_geom" } pour le Roi Orc).
function Kit.rig(model: Model, options: { Held: { [string]: string }?, Parts: { [string]: string }? }?): ()
	assert(not model:FindFirstChild("HumanoidRootPart"), `{model.Name} a déjà un squelette`)
	local parts: { [string]: BasePart } = {}
	local named = if options and options.Parts then options.Parts else {}
	for role, names in PART_NAMES do
		local part = find(model, if named[role] then { named[role] } else names)
		assert(part, `{model.Name} : pièce {role} introuvable ({table.concat(names, ", ")}) ; voir docs/ANIMATION_TOOLS.md`)
		parts[role] = part
	end
	local torso, leftArm, rightArm = parts.torso, parts.leftArm, parts.rightArm
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

	local armInset = math.clamp(leftArm.Size.Y * 0.15, 0.3, 0.8)
	local legInset = math.clamp(parts.leftLeg.Size.Y * 0.1, 0.2, 0.5)
	joint("Racine", root, torso, middle(torso))
	joint("EpauleGauche", torso, leftArm, shoulder(leftArm, armInset))
	joint("EpauleDroite", torso, rightArm, shoulder(rightArm, armInset))
	joint("HancheGauche", torso, parts.leftLeg, top(parts.leftLeg, legInset))
	joint("HancheDroite", torso, parts.rightLeg, top(parts.rightLeg, legInset))
	local hmn, hmx = bounds(parts.head, basis)
	joint("Cou", torso, parts.head, Vector3.new((hmn.X + hmx.X) / 2, hmn.Y + 0.2, (hmn.Z + hmx.Z) / 2))

	local used: { [BasePart]: boolean } = {}
	for _, part in parts do
		used[part] = true
	end
	local forced = if options and options.Held then options.Held else {}
	local leftHand, rightHand = basis * hand(leftArm), basis * hand(rightArm)
	local leftShoulder = basis * shoulder(leftArm, armInset)
	local rightShoulder = basis * shoulder(rightArm, armInset)
	local summary: { string } = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part ~= root and not used[part] then
			local mode = forced[part.Name]
			if not mode then
				if isHeld(part) then
					mode = if (part.Position - leftHand).Magnitude < (part.Position - rightHand).Magnitude then "left" else "right"
				else
					mode = "torso"
				end
			end
			if mode == "nearest" then
				mode = if (part.Position - leftShoulder).Magnitude < (part.Position - rightShoulder).Magnitude then "leftArm" else "rightArm"
			end
			local label = if mode == "left" then "main gauche" elseif mode == "right" then "main droite"
				elseif mode == "leftArm" then "bras gauche" elseif mode == "rightArm" then "bras droit" else "buste"
			table.insert(summary, `{part.Name} -> {label}`)
			if mode == "leftArm" or mode == "rightArm" then
				joint("Porte_" .. string.gsub(part.Name, "_geom$", ""), if mode == "leftArm" then leftArm else rightArm, part, middle(part))
			elseif mode == "left" then
				joint("Tenu_" .. string.gsub(part.Name, "_geom$", ""), leftArm, part, hand(leftArm))
			elseif mode == "right" then
				joint("Tenu_" .. string.gsub(part.Name, "_geom$", ""), rightArm, part, hand(rightArm))
			else
				joint(jointName(part), torso, part, middle(part))
			end
		end
	end

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part ~= root then
			part.Anchored = false
			part.CanCollide = false
		end
	end
	local controller = Instance.new("AnimationController")
	controller.Parent = model
	Instance.new("Animator").Parent = controller
	table.sort(summary)
	print(`[AnimationKit] {model.Name} : {table.concat(summary, " ; ")} (corriger avec Held si besoin)`)
end

-- Retire le squelette posé par Kit.rig (modèle en pose de repos, mode Edit) pour le reposer
-- après une correction de l'outil. Les animations ne dépendent que des noms de pièces : elles restent valables.
function Kit.unrig(model: Model): ()
	for _, item in model:GetDescendants() do
		if item:IsA("Motor6D") or item:IsA("AnimationController") then
			item:Destroy()
		end
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root then
		root:Destroy()
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
end

-- Arbre des articulations du modèle : partName -> { enfants }, depuis la racine.
local function poseTree(model: Model): (string, { [string]: { string } }, { [string]: string })
	local children: { [string]: { string } } = {}
	local roles: { [string]: string } = {}
	for _, motor in model:GetDescendants() do
		if motor:IsA("Motor6D") and motor.Part0 and motor.Part1 then
			local parent = (motor.Part0 :: BasePart).Name
			children[parent] = children[parent] or {}
			table.insert(children[parent], (motor.Part1 :: BasePart).Name)
			local role = JOINT_ROLES[motor.Name]
			if role then
				roles[role] = (motor.Part1 :: BasePart).Name
			end
		end
	end
	-- Armes : première pièce tenue (articulation Tenu_*) par chaque main.
	for _, motor in model:GetDescendants() do
		if motor:IsA("Motor6D") and string.sub(motor.Name, 1, 5) == "Tenu_" and motor.Part0 and motor.Part1 then
			local holder = (motor.Part0 :: BasePart).Name
			local role = if holder == roles.rightArm then "weaponRight" elseif holder == roles.leftArm then "weaponLeft" else nil
			if role and not roles[role] then
				roles[role] = (motor.Part1 :: BasePart).Name
			end
		end
	end
	local root = model.PrimaryPart
	assert(root, `{model.Name} n'a pas de squelette (lancer Kit.rig)`)
	return root.Name, children, roles
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
	local rootName, children, roles = poseTree(model)
	local byPart: { [string]: string } = {}
	for role, partName in roles do
		byPart[partName] = role
	end
	local sequence = Instance.new("KeyframeSequence")
	sequence.Name = "Marche"
	sequence.Loop = true
	sequence.Priority = Enum.AnimationPriority.Movement
	for i = 0, KEYS_PER_CYCLE do
		local values = Kit.walkPose(p, 2 * math.pi * i / KEYS_PER_CYCLE)
		local keyframe = Instance.new("Keyframe")
		keyframe.Time = p.Cycle * i / KEYS_PER_CYCLE
		local function add(parent: Instance, partName: string)
			local pose = Instance.new("Pose")
			pose.Name = partName
			local role = byPart[partName]
			local v = role and values[role]
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
				rightArm = { 25, 0, -30 }, leftArm = { 25, 0, -6 },
				rightLeg = { -6, -30, 0 }, leftLeg = { 30, -30, 0 },
				head = { 8, -25, 0 },
			} },
			{ Time = 0.3, Easing = "InOut", Poses = {
				torso = { -16, 36, 0, -0.2 },
				rightArm = { 12, 0, -36 }, leftArm = { 22, 0, -6 },
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
	Rempart = {
		Length = 0.9, Impact = 0.3,
		Keys = {
			{ Time = 0, Easing = "Out", Poses = {} },
			{ Time = 0.15, Easing = "In", Poses = {
				torso = { 10, -20, 0, -0.25 },
				rightArm = { -30, 0, 25 }, leftArm = { 50, 0, -5 },
				rightLeg = { -25, 20, 0 }, leftLeg = { 15, 20, 0 },
				head = { -5, 15, 0 },
			} },
			{ Time = 0.3, Easing = "Out", Poses = {
				torso = { -18, 25, 0, -0.1 },
				rightArm = { 80, 0, -10 }, leftArm = { -15, 0, -25 },
				rightLeg = { -10, -25, 0 }, leftLeg = { 38, -25, 0 },
				head = { 10, -20, 0 },
			} },
			{ Time = 0.5, Easing = "InOut", Poses = {
				torso = { -20, 28, 0, -0.12 },
				rightArm = { 78, 0, -12 }, leftArm = { -18, 0, -25 },
				rightLeg = { -10, -28, 0 }, leftLeg = { 40, -28, 0 },
				head = { 11, -22, 0 },
			} },
			{ Time = 0.9, Easing = "InOut", Poses = {} },
		},
	},
	-- Roi Orc « Fendoir du Roi » : armé lent, lance-hache levée au-dessus de l'épaule en se cambrant,
	-- court temps suspendu, puis abattue devant lui en plongeant (la lame mord le sol), rebond lourd.
	-- weaponRight = l'arme elle-même, pivot dans la main : +rx relève la pointe. L'angle de la lame
	-- est la somme bras + arme : armé 70 + 60 (au-dessus de la tête), impact 45 - 45 (lame qui mord le sol devant).
	-- À l'impact, AttackEffectController joue l'effet « Seisme » (attribut EffetAttaque du modèle).
	Fendoir = {
		Length = 1.4, Impact = 0.7,
		Keys = {
			{ Time = 0, Easing = "Out", Poses = {} },
			{ Time = 0.45, Easing = "Out", Poses = {
				torso = { 14, -30, 0, 0.35 },
				rightArm = { 70, 0, 20 }, weaponRight = { 60, 0, 0 },
				leftArm = { 40, 0, -10 },
				rightLeg = { -20, 30, 0 }, leftLeg = { 0, 30, 0 },
				head = { -8, 20, 0 },
			} },
			{ Time = 0.55, Easing = "In", Poses = {
				torso = { 16, -34, 0, 0.4 },
				rightArm = { 80, 0, 22 }, weaponRight = { 65, 0, 0 },
				leftArm = { 42, 0, -10 },
				rightLeg = { -22, 34, 0 }, leftLeg = { -2, 34, 0 },
				head = { -9, 22, 0 },
			} },
			{ Time = 0.7, Easing = "Out", Poses = {
				torso = { -24, 20, 0, 0.2 },
				rightArm = { 45, 0, -12 }, weaponRight = { -45, 0, 0 },
				leftArm = { -10, 0, -30 },
				rightLeg = { 10, -20, 0 }, leftLeg = { 40, -20, 0 },
				head = { 12, -15, 0 },
			} },
			{ Time = 0.85, Easing = "InOut", Poses = {
				torso = { -20, 18, 0, 0.2 },
				rightArm = { 40, 0, -12 }, weaponRight = { -40, 0, 0 },
				leftArm = { -8, 0, -28 },
				rightLeg = { 8, -18, 0 }, leftLeg = { 36, -18, 0 },
				head = { 10, -14, 0 },
			} },
			{ Time = 1.4, Easing = "InOut", Poses = {} },
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
	local rootName, children, roles = poseTree(model)
	local byPart: { [string]: string } = {}
	for role, partName in roles do
		byPart[partName] = role
	end
	local sequence = Instance.new("KeyframeSequence")
	sequence.Name = name
	sequence.Loop = false
	sequence.Priority = Enum.AnimationPriority.Action
	sequence:SetAttribute("Impact", s.Impact)
	for _, key in s.Keys do
		local keyframe = Instance.new("Keyframe")
		keyframe.Time = key.Time
		local function add(parent: Instance, partName: string)
			local pose = Instance.new("Pose")
			pose.Name = partName
			local role = byPart[partName]
			local v = role and key.Poses[role]
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

-- Attaque de base « Attaque » d'un modèle riggé.
function Kit.attack(model: Model, style: any): KeyframeSequence
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

-- Range une animation dans le jeu de combat (ReplicatedStorage.Assets.Animations.<Set>) et en copie
-- pour l'Animation Editor (ServerStorage.RBX_ANIMSAVES.<modèle>). Remplace une version précédente.
function Kit.install(model: Model, set: string, sequence: KeyframeSequence): ()
	local assets = folder(ReplicatedStorage, "Assets")
	local target = folder(folder(assets, "Animations"), set)
	local old = target:FindFirstChild(sequence.Name)
	if old then
		old:Destroy()
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
	model:SetAttribute("JeuAnimationsCombat", set)
	if model:GetAttribute("JeuAnimations") == nil then
		model:SetAttribute("JeuAnimations", set)
	end
end

-- Aperçu en boucle au Play : l'animation est copiée dans Assets.Animations.Apercu_<Set> sous le nom
-- « Attente », que MonsterAnimationController joue sans jamais la couper.
-- rest (s) : pause en pose neutre ajoutée après une animation non bouclée (attaque...), pour la voir
-- se répéter à un rythme lisible. Par défaut 0,8 s pour une animation non bouclée, 0 sinon.
function Kit.preview(model: Model, set: string, animationName: string, rest: number?): ()
	local animations = folder(folder(ReplicatedStorage, "Assets"), "Animations")
	local source = animations:FindFirstChild(set) and (animations :: any)[set]:FindFirstChild(animationName)
	assert(source, `animation {set}.{animationName} introuvable`)
	local preview = folder(animations, "Apercu_" .. set)
	preview:SetAttribute("Note", "Aperçu uniquement (AtelierAnimation) : l'animation étudiée joue en boucle sous le nom Attente. Ne pas utiliser en combat.")
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

-- Tout en un : copie, squelette, marche, rangement en jeu de combat, aperçu près du spawn.
--   options = { Source: Model, Set: string, Profile: string | table, Name: string?, Held: { [string]: string }?,
--               Attack: string | table ? (style de Kit.Attacks), Preview: string? (animation montrée, "Marche" par défaut) }
function Kit.prepare(options: { [string]: any }): Model
	local recording = ChangeHistoryService:TryBeginRecording("AnimationKit : " .. options.Set)
	local ok, result = pcall(function()
		local model = Kit.copy(options.Source, options.Name)
		Kit.rig(model, { Held = options.Held, Parts = options.Parts })
		Kit.install(model, options.Set, Kit.walk(model, options.Profile))
		if options.Attack then
			Kit.install(model, options.Set, Kit.attack(model, options.Attack))
		end
		Kit.preview(model, options.Set, options.Preview or "Marche")
		Kit.arrange()
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
	print(`[AnimationKit] {result:GetFullName()} prêt : lancer Play pour voir la marche ({options.Profile}).`)
	return result
end

_G.AnimationKit = Kit
return Kit
