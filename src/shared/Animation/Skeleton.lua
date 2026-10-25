--!strict
-- Squelette commun des héros et des monstres (voir docs/SKELETON.md).
-- Module pur : aucune Instance, testable hors Studio (tools/test-skeleton.ps1).
--
-- Un modèle articulé par AnimationKit reçoit des os invisibles qui portent les noms communs
-- ci-dessous (Buste, Tete, BrasGauche...). Une KeyframeSequence nomme ses Pose d'après ces os :
-- la même animation joue donc sur tout modèle qui a ce squelette, quels que soient les noms de
-- ses pièces (torso_geom, body_geom...). Les pièces visibles sont seulement accrochées aux os.
--
-- « Cette pièce = tel os » se dit de quatre façons, de la plus forte à la plus faible :
--   1. la fiche du modèle dans Config/SkeletonConfig (Git) : Membres et Pieces ;
--   2. l'attribut texte "Os" posé sur la pièce dans Studio (ex. Os = "ArmeDroite") ;
--   3. le nom du groupe (sous-modèle) qui contient la pièce : fiche, puis mot porté / tenu ;
--   4. la détection par le nom (format des modèles IA : torso_geom, left_arm_geom, weapon_geom...).

local Skeleton = {}

-- Nom du squelette, écrit dans l'attribut "Squelette" du modèle articulé.
Skeleton.Name = "Humanoide"
-- Racine du modèle (invisible, ancrée), parent du Buste. Nom imposé par les Pose racine.
Skeleton.Root = "HumanoidRootPart"
-- Dossier du modèle qui contient les os invisibles.
Skeleton.Folder = "Os"
-- Attributs posés sur les pièces : os de rattachement, et pièce qui donne la forme du membre.
Skeleton.BoneAttribute = "Os"
Skeleton.AnchorAttribute = "OsAncre"

export type Bone = {
	Name: string, -- nom de l'os = nom de la Pose dans les animations
	Parent: string, -- os parent (ou Skeleton.Root)
	Joint: string, -- nom de l'articulation Motor6D (identique à l'ancien squelette)
	Role: string, -- clé des poses d'AnimationKit (Kit.Profiles, Kit.Attacks)
	Required: boolean, -- le modèle doit avoir une pièce pour ce membre
}

-- Ordre = ordre de création : un parent passe toujours avant ses enfants.
Skeleton.Bones = table.freeze({
	table.freeze({ Name = "Buste", Parent = "HumanoidRootPart", Joint = "Racine", Role = "torso", Required = true }),
	table.freeze({ Name = "Tete", Parent = "Buste", Joint = "Cou", Role = "head", Required = true }),
	table.freeze({ Name = "BrasGauche", Parent = "Buste", Joint = "EpauleGauche", Role = "leftArm", Required = true }),
	table.freeze({ Name = "BrasDroit", Parent = "Buste", Joint = "EpauleDroite", Role = "rightArm", Required = true }),
	table.freeze({ Name = "JambeGauche", Parent = "Buste", Joint = "HancheGauche", Role = "leftLeg", Required = true }),
	table.freeze({ Name = "JambeDroite", Parent = "Buste", Joint = "HancheDroite", Role = "rightLeg", Required = true }),
	-- Armes : os dans la main, créés même vides (une animation qui les anime reste valable).
	table.freeze({ Name = "ArmeGauche", Parent = "BrasGauche", Joint = "MainGauche", Role = "weaponLeft", Required = false }),
	table.freeze({ Name = "ArmeDroite", Parent = "BrasDroit", Joint = "MainDroite", Role = "weaponRight", Required = false }),
} :: { Bone })

local byName: { [string]: Bone } = {}
local byRole: { [string]: Bone } = {}
local byJoint: { [string]: Bone } = {}
for _, bone in Skeleton.Bones do
	byName[bone.Name] = bone
	byRole[bone.Role] = bone
	byJoint[bone.Joint] = bone
end

function Skeleton.bone(name: string): Bone?
	return byName[name]
end

-- Os désigné par son nom (Buste) ou par sa clé de pose AnimationKit (torso).
function Skeleton.resolveBone(key: string): Bone?
	return byName[key] or byRole[key]
end

function Skeleton.boneOfJoint(jointName: string): Bone?
	return byJoint[jointName]
end

-- Enfants directs d'un os (ou de la racine), dans l'ordre de Skeleton.Bones.
function Skeleton.children(name: string): { string }
	local list = {}
	for _, bone in Skeleton.Bones do
		if bone.Parent == name then
			table.insert(list, bone.Name)
		end
	end
	return list
end

-- Détection par le nom (format des modèles générés par l'IA de Studio : <membre>_geom). Variantes
-- relevées au Bestiaire : sans suffixe (héros #14 à #21) et avec une espace (#65, #66).
Skeleton.MemberNames = table.freeze({
	Buste = { "torso_geom", "body_geom", "chest_geom", "torso" },
	Tete = { "head_geom", "mask_head_geom", "skull_geom", "head" },
	BrasGauche = { "left_arm_geom", "left_arm", "left arm_geom" },
	BrasDroit = { "right_arm_geom", "right_arm", "right arm_geom" },
	JambeGauche = { "left_leg_geom", "left_leg", "left leg_geom" },
	JambeDroite = { "right_leg_geom", "right_leg", "right leg_geom" },
} :: { [string]: { string } })

-- Une pièce dont le nom contient l'un de ces mots est tenue par la main la plus proche.
-- Pas « arc » : il prenait pour des armes l'arche de #45 (arche_portes) et les halos ArcDAube, CentreArc.
-- Noms relevés sur les héros du Bestiaire (weapon_geom, buckler_geom, coutelas_geom, etendard_geom...).
Skeleton.HeldWords = table.freeze({
	"weapon", "arme", "sword", "epee", "blade", "lame", "grip", "guard", "pommel", "garde", "pommeau", "poignee",
	"axe", "hache", "spear", "lance", "staff", "baton", "wand", "bow", "shield", "bouclier", "buckler",
	"dagger", "dague", "knife", "couteau", "coutelas", "hammer", "marteau", "mace", "masse", "club", "gourdin",
	"scythe", "faux", "torch", "torche", "lantern", "lanterne", "book", "livre", "banner", "banniere", "etendard",
	"cloche", "battant", "sceptre", "scepter", "glaive", "harpoon", "harpon", "trident", "maul", "mallet",
	"quenouille", "houlette", "hallebarde", "halberd", "shaft", "carte", "card", "flail", "fleau",
})
-- Toujours portées par le buste, même si leur nom contient un mot ci-dessus (shoulder_guard, ceinture,
-- halo_lames : couronne de lames au-dessus de la tête, menhir crown...).
Skeleton.WornWords = table.freeze({
	"shoulder", "epaul", "cape", "tabard", "apron", "tablier", "quiver", "carquois", "belt", "ceinture", "helm", "heaume",
	"halo", "wing", "aile", "crown", "couronne", "hat", "chapeau", "hood", "capuche", "collar", "mantle", "manteau",
	"robe", "gown", "skirt", "braid", "hair", "tresse",
})

-- Cibles spéciales de rattachement, tranchées par la géométrie au moment du rig (AnimationKit) :
Skeleton.NearestHand = "MainProche" -- ArmeGauche ou ArmeDroite, selon la main la plus proche
Skeleton.NearestArm = "BrasProche" -- BrasGauche ou BrasDroit, selon l'épaule la plus proche

-- Anciennes valeurs de options.Held (AnimationKit) : toujours acceptées.
local LEGACY_TARGETS = {
	left = "ArmeGauche",
	right = "ArmeDroite",
	nearest = Skeleton.NearestArm,
	torso = "Buste",
}

-- Cible de rattachement valide (nom d'os, cible spéciale ou ancienne valeur), sinon nil.
function Skeleton.target(value: any): string?
	if typeof(value) ~= "string" then
		return nil
	end
	local legacy = LEGACY_TARGETS[value]
	if legacy then
		return legacy
	end
	local bone = Skeleton.resolveBone(value)
	if bone then
		return bone.Name
	end
	if value == Skeleton.NearestHand or value == Skeleton.NearestArm then
		return value
	end
	return nil
end

-- Rattachement lu dans le nom, seulement si un mot le dit : porté (Buste) ou tenu (MainProche), sinon nil.
function Skeleton.explicit(pieceName: string): string?
	local name = string.lower(pieceName)
	for _, word in Skeleton.WornWords do
		if string.find(name, word, 1, true) then
			return "Buste"
		end
	end
	for _, word in Skeleton.HeldWords do
		if string.find(name, word, 1, true) then
			return Skeleton.NearestHand
		end
	end
	return nil
end

-- Rattachement deviné d'après le nom : objet tenu -> main la plus proche, sinon buste.
function Skeleton.guess(pieceName: string): string
	return Skeleton.explicit(pieceName) or "Buste"
end

export type Piece = {
	Name: string,
	Os: string?, -- attribut "Os" de la pièce
	Ancre: boolean?, -- attribut "OsAncre" (posé par un rig précédent)
	-- Nom du groupe (enfant direct du modèle) qui contient la pièce, s'il y en a un : les décors d'une
	-- arme (cristal_luciole dans baton_fleur) suivent l'arme, ceux d'un halo (Lame_1 dans halo_lames)
	-- restent au buste.
	Groupe: string?,
}

export type Map = {
	-- os -> nom de la pièce qui donne la forme du membre (pivot de l'articulation)
	Membres: { [string]: string }?,
	-- nom de pièce -> os (ou cible spéciale) ; s'applique à toutes les pièces de ce nom
	Pieces: { [string]: string }?,
}

export type Resolution = {
	-- os -> index (dans pieces) de la pièce qui donne la forme du membre
	anchors: { [string]: number },
	-- index de chaque pièce -> os ou cible spéciale
	targets: { [number]: string },
	-- membres obligatoires sans pièce
	missing: { string },
	-- valeurs ignorées (os inconnu dans une fiche ou un attribut)
	warnings: { string },
}

-- Associe chaque pièce du modèle à un os. Pure : reçoit la liste des pièces (nom + attributs).
function Skeleton.resolve(pieces: { Piece }, map: Map?): Resolution
	local members = if map and map.Membres then map.Membres else {}
	local forced = if map and map.Pieces then map.Pieces else {}
	local anchors: { [string]: number } = {}
	local targets: { [number]: string } = {}
	local missing: { string } = {}
	local warnings: { string } = {}

	for boneName in members do
		if not byName[boneName] then
			table.insert(warnings, `Membres : os inconnu « {boneName} »`)
		end
	end
	-- Première pièce libre (pas déjà forme d'un membre) qui vérifie la condition.
	local function first(predicate: (Piece) -> boolean): number?
		for index, piece in pieces do
			if not targets[index] and predicate(piece) then
				return index
			end
		end
		return nil
	end
	local function bind(bone: Bone, index: number)
		anchors[bone.Name] = index
		targets[index] = bone.Name
	end
	-- 1. Désignations explicites (fiche, puis rig précédent), pour tous les os avant toute détection :
	--    la fiche du Roi Orc donne body_geom à la Tete, la détection ne doit pas le prendre pour le Buste.
	for _, bone in Skeleton.Bones do
		local wanted = members[bone.Name]
		local index: number? = nil
		if wanted then
			index = first(function(piece)
				return piece.Name == wanted
			end)
			if not index then
				table.insert(warnings, `Membres : pièce « {wanted} » ({bone.Name}) introuvable`)
			end
		end
		index = index or first(function(piece)
			return piece.Ancre == true and piece.Os == bone.Name
		end)
		if index then
			bind(bone, index)
		end
	end
	-- 2. Détection par le nom pour les membres restants.
	for _, bone in Skeleton.Bones do
		local names = Skeleton.MemberNames[bone.Name]
		if anchors[bone.Name] or not names then
			continue
		end
		for _, name in names do
			local index = first(function(piece)
				return piece.Name == name
			end)
			if index then
				bind(bone, index)
				break
			end
		end
	end
	for _, bone in Skeleton.Bones do
		if bone.Required and not anchors[bone.Name] then
			table.insert(missing, bone.Name)
		end
	end

	for index, piece in pieces do
		if targets[index] then
			continue
		end
		local target = Skeleton.target(forced[piece.Name])
		if forced[piece.Name] ~= nil and not target then
			table.insert(warnings, `Pieces : cible inconnue « {tostring(forced[piece.Name])} » pour {piece.Name}`)
		end
		if not target and piece.Os ~= nil then
			target = Skeleton.target(piece.Os)
			if not target then
				table.insert(warnings, `attribut Os inconnu « {tostring(piece.Os)} » sur {piece.Name}`)
			end
		end
		if not target and piece.Groupe then
			target = Skeleton.target(forced[piece.Groupe]) or Skeleton.explicit(piece.Groupe)
		end
		targets[index] = target or Skeleton.guess(piece.Name)
	end
	local present: { [string]: boolean } = {}
	for _, piece in pieces do
		present[piece.Name] = true
		if piece.Groupe then
			present[piece.Groupe] = true
		end
	end
	for key in forced do
		if not present[key] then
			table.insert(warnings, `Pieces : pièce « {key} » introuvable`)
		end
	end
	table.sort(missing)
	table.sort(warnings)
	return { anchors = anchors, targets = targets, missing = missing, warnings = warnings }
end

-- Prise des objets tenus (docs/SKELETON.md § Prise). Deux Attachment, posés une fois par modèle :
--   Poing (Hand) : sur une pièce du bras, au centre du poing fermé. Axis (X) = sens du manche qui
--                  traverse le poing, vers la tête de l'arme ; SecondaryAxis (Y) = côté du tranchant.
--   Prise (Weapon) : sur l'objet tenu, au point du manche que serre le poing, mêmes axes.
-- Kit.rig superpose Prise à Poing et met le pivot de l'os ArmeGauche / ArmeDroite au Poing : l'arme
-- est toujours dans la main, au repos comme pendant une animation, et tourne autour du poing.
Skeleton.Grip = table.freeze({
	Hand = "Poing",
	Weapon = "Prise",
	-- Attribut booléen de Prise : objet tenu sans manche qui traverse le poing (cartes entre les
	-- doigts, lanterne par l'anse). Seul le test « traverse » est sauté.
	Free = "PriseLibre",
	-- Objets tenus sans manche qui traverse le poing : bouclier sanglé, cartes, lanterne par l'anse,
	-- cloche par sa couronne, livre. Leur Prise est le centre du poing, avec PriseLibre.
	-- Attribut booléen de Prise : prise validée en capture (date dans docs/HEROES_QA.md). Les deux
	-- mesures approximatives (centre du poing, « traverse ») sont alors sautées ; l'écart Prise / Poing
	-- reste contrôlé : déplacer l'arme ou le bras après validation casse toujours le contrôle.
	Checked = "PriseControlee",
	FreeWords = table.freeze({ "shield", "bouclier", "buckler", "ecu", "carte", "card", "lantern", "lanterne",
		"cloche", "book", "livre", "torch", "torche" }),
	MaxGap = 0.05, -- écart toléré entre Prise et Poing (studs)
	MaxAngle = 5, -- écart toléré entre leurs axes (degrés)
	MaxOffset = 0.35, -- écart toléré entre le Poing et le centre du poing mesuré sur le bras (studs)
	Through = 0.25, -- le manche doit être présent à cette distance de part et d'autre du Poing (studs)
})

export type GripMeasure = {
	Piece: string, -- objet tenu
	HasPrise: boolean,
	HasPoing: boolean,
	Gap: number?, -- distance Prise <-> Poing
	Angle: number?, -- angle entre leurs axes (degrés)
	Offset: number?, -- distance Poing <-> centre du poing mesuré
	Before: boolean?, -- manche présent côté talon (Prise - Through)
	After: boolean?, -- manche présent côté tête (Prise + Through)
	Free: boolean?, -- attribut PriseLibre
	Checked: boolean?, -- attribut PriseControlee
}

-- Défauts d'une prise mesurée dans Studio (liste vide = l'objet est bien en main). Pure.
function Skeleton.gripProblems(measure: GripMeasure): { string }
	local grip = Skeleton.Grip
	local problems: { string } = {}
	local piece = measure.Piece
	if not measure.HasPrise then
		table.insert(problems, `{piece} : pas d'Attachment {grip.Weapon}`)
	end
	if not measure.HasPoing then
		table.insert(problems, `{piece} : pas d'Attachment {grip.Hand} sur le bras qui le tient`)
	end
	if #problems > 0 then
		return problems
	end
	if (measure.Gap or math.huge) > grip.MaxGap then
		table.insert(problems, string.format("%s : %s à %.2f stud du %s (toléré %.2f)", piece, grip.Weapon, measure.Gap or math.huge, grip.Hand, grip.MaxGap))
	end
	if (measure.Angle or 180) > grip.MaxAngle then
		table.insert(problems, string.format("%s : manche tourné de %.0f° par rapport au %s (toléré %d°)", piece, measure.Angle or 180, grip.Hand, grip.MaxAngle))
	end
	if measure.Checked then
		return problems
	end
	if measure.Offset and measure.Offset > grip.MaxOffset then
		table.insert(problems, string.format("%s : %s à %.2f stud du centre du poing (toléré %.2f)", piece, grip.Hand, measure.Offset, grip.MaxOffset))
	end
	if not measure.Free then
		if measure.Before == false then
			table.insert(problems, `{piece} : le manche s'arrête dans le poing côté talon (il doit le traverser)`)
		end
		if measure.After == false then
			table.insert(problems, `{piece} : rien ne sort du poing côté tête`)
		end
	end
	return problems
end

-- Attributs d'animation d'un modèle :
--   JeuAnimations        : jeu propre au modèle (ou jeu d'aperçu Apercu_<Set>) ;
--   JeuAnimationsCombat  : jeu de combat quand JeuAnimations sert à l'aperçu (posé par AnimationKit) ;
--   JeuAnimationsCommun  : jeu partagé, nommé d'après les os (ex. Squelette_Leger), qui complète le
--                          jeu propre pour les animations qu'il n'a pas. Lu seulement si le modèle a
--                          le squelette commun (attribut Squelette), sinon ses Pose ne trouvent rien.
export type SetAttributes = {
	JeuAnimations: any,
	JeuAnimationsCombat: any,
	JeuAnimationsCommun: any,
	Squelette: any,
}

local function text(value: any): string?
	return if typeof(value) == "string" and value ~= "" then value else nil
end

-- Jeux d'animations à consulter, du plus prioritaire au moins prioritaire.
-- combat = true : le jeu de combat passe avant le jeu d'aperçu (effets d'attaque, ultime).
function Skeleton.animationSets(attributes: SetAttributes, combat: boolean?): { string }
	local sets: { string } = {}
	local function add(value: any)
		local name = text(value)
		if name and not table.find(sets, name) then
			table.insert(sets, name)
		end
	end
	if combat then
		add(attributes.JeuAnimationsCombat)
	end
	add(attributes.JeuAnimations)
	if attributes.Squelette == Skeleton.Name then
		add(attributes.JeuAnimationsCommun)
	end
	return sets
end

return table.freeze(Skeleton)
