--!strict
-- Jamais exécuté par le jeu : lancé par tools/test-skeleton.ps1.
-- Teste le vrai Skeleton (os communs, rattachement des pièces, ordre des jeux d'animations)
-- avec la vraie SkeletonConfig (fiches de l'Écuyer du Rempart et du Roi Orc).

return function(Skeleton: any, skeletonConfig: any)
	local passed, failed = 0, 0
	local function test(name: string, run: () -> ())
		local ok, err = pcall(run)
		if ok then
			passed += 1
			print("PASS " .. name)
		else
			failed += 1
			print("FAIL " .. name .. ": " .. tostring(err))
		end
	end

	local function pieces(names: { string }): { any }
		local list = {}
		for _, name in names do
			table.insert(list, { Name = name })
		end
		return list
	end
	local function targetOf(resolution: any, list: { any }, name: string): string?
		for index, piece in list do
			if piece.Name == name then
				return resolution.targets[index]
			end
		end
		return nil
	end
	local STANDARD = { "torso_geom", "head_geom", "left_arm_geom", "right_arm_geom", "left_leg_geom", "right_leg_geom" }

	test("bones: unique names, parents declared before children, legacy joint names kept", function()
		local seen = { [Skeleton.Root] = true }
		local joints = {}
		for _, bone in Skeleton.Bones do
			assert(not seen[bone.Name], `duplicate bone {bone.Name}`)
			assert(seen[bone.Parent], `{bone.Name}: parent {bone.Parent} must come first`)
			assert(not joints[bone.Joint], `duplicate joint {bone.Joint}`)
			seen[bone.Name] = true
			joints[bone.Joint] = true
		end
		for _, joint in { "Racine", "Cou", "EpauleGauche", "EpauleDroite", "HancheGauche", "HancheDroite" } do
			assert(joints[joint], `joint {joint} renamed: old rigs would break`)
		end
		assert(Skeleton.bone("Buste").Parent == Skeleton.Root)
		assert(Skeleton.bone("ArmeDroite").Parent == "BrasDroit")
		assert(table.concat(Skeleton.children("Buste"), ",") == "Tete,BrasGauche,BrasDroit,JambeGauche,JambeDroite")
	end)

	test("resolveBone accepts bone names and AnimationKit role keys", function()
		assert(Skeleton.resolveBone("Buste").Name == "Buste")
		assert(Skeleton.resolveBone("torso").Name == "Buste")
		assert(Skeleton.resolveBone("weaponRight").Name == "ArmeDroite")
		assert(Skeleton.boneOfJoint("EpauleGauche").Name == "BrasGauche")
		assert(Skeleton.resolveBone("queue") == nil)
	end)

	test("target: bones, special targets and legacy Held values", function()
		assert(Skeleton.target("left") == "ArmeGauche")
		assert(Skeleton.target("right") == "ArmeDroite")
		assert(Skeleton.target("nearest") == Skeleton.NearestArm)
		assert(Skeleton.target("torso") == "Buste")
		assert(Skeleton.target("rightArm") == "BrasDroit")
		assert(Skeleton.target("MainProche") == Skeleton.NearestHand)
		assert(Skeleton.target("Aile") == nil)
		assert(Skeleton.target(3) == nil)
	end)

	test("guess: held objects go to the nearest hand, worn ones to the torso", function()
		assert(Skeleton.guess("weapon_geom") == Skeleton.NearestHand)
		assert(Skeleton.guess("Buckler_geom") == Skeleton.NearestHand)
		assert(Skeleton.guess("shoulder_guard_geom") == "Buste", "worn word wins over 'guard'")
		assert(Skeleton.guess("belt_geom") == "Buste")
		assert(Skeleton.guess("cape_geom") == "Buste")
	end)

	test("resolve: standard AI model, every piece bound, nothing missing", function()
		local list = pieces(STANDARD)
		table.insert(list, { Name = "weapon_geom" })
		table.insert(list, { Name = "cape_geom" })
		local r = Skeleton.resolve(list, nil)
		assert(#r.missing == 0 and #r.warnings == 0)
		assert(list[r.anchors.Buste].Name == "torso_geom")
		assert(list[r.anchors.JambeDroite].Name == "right_leg_geom")
		assert(r.anchors.ArmeDroite == nil, "weapon bones have no anchor piece")
		assert(targetOf(r, list, "weapon_geom") == Skeleton.NearestHand)
		assert(targetOf(r, list, "cape_geom") == "Buste")
	end)

	test("resolve: missing member is reported, optional weapon bones are not", function()
		local list = pieces({ "torso_geom", "head_geom", "left_arm_geom", "right_arm_geom" })
		local r = Skeleton.resolve(list, nil)
		assert(table.concat(r.missing, ",") == "JambeDroite,JambeGauche")
	end)

	test("resolve: priority is config, then Os attribute, then name", function()
		local list = pieces(STANDARD)
		table.insert(list, { Name = "lantern_geom", Os = "Buste" })
		table.insert(list, { Name = "horn_geom", Os = "Tete" })
		table.insert(list, { Name = "pic", Os = "Tete" })
		local r = Skeleton.resolve(list, { Pieces = { pic = "nearest" } })
		assert(targetOf(r, list, "lantern_geom") == "Buste", "attribute beats name detection")
		assert(targetOf(r, list, "horn_geom") == "Tete")
		assert(targetOf(r, list, "pic") == Skeleton.NearestArm, "config beats attribute")
	end)

	test("resolve: a previous rig's OsAncre is kept on re-rig", function()
		local list = pieces({ "torso_geom", "left_arm_geom", "right_arm_geom", "left_leg_geom", "right_leg_geom", "crane" })
		list[6].Os, list[6].Ancre = "Tete", true
		local r = Skeleton.resolve(list, nil)
		assert(#r.missing == 0)
		assert(list[r.anchors.Tete].Name == "crane")
	end)

	test("resolve: unknown bones and pieces become warnings, not errors", function()
		local list = pieces(STANDARD)
		table.insert(list, { Name = "aile", Os = "Aile" })
		local r = Skeleton.resolve(list, { Membres = { Queue = "x", Tete = "absent" }, Pieces = { fantome = "Buste", aile = "Vol" } })
		assert(#r.warnings == 5, `got {#r.warnings}: {table.concat(r.warnings, " | ")}`)
		assert(list[r.anchors.Tete].Name == "head_geom", "falls back to name detection")
		assert(targetOf(r, list, "aile") == "Buste")
	end)

	test("config: Ecuyer du Rempart resolves on its AI pieces", function()
		local entry = skeletonConfig.Models.EcuyerDuRempart
		local list = pieces(STANDARD)
		-- Pièces réelles relevées dans Studio (Bestiaire.Heros.Socle_01.EcuyerDuRempart).
		table.insert(list, { Name = "short_sword_geom" })
		table.insert(list, { Name = "shield_geom" })
		table.insert(list, { Name = "cor_geom" })
		local r = Skeleton.resolve(list, entry)
		assert(#r.missing == 0 and #r.warnings == 0, table.concat(r.warnings, " | "))
		assert(targetOf(r, list, "short_sword_geom") == "ArmeDroite")
		assert(targetOf(r, list, "shield_geom") == "ArmeGauche")
		assert(targetOf(r, list, "cor_geom") == "Buste", "the horn is worn, not held")
		assert(skeletonConfig.SharedSets[entry.Commun] == entry.Profil)
	end)

	test("config: Roi Orc head is body_geom, shoulder pieces follow the nearest arm", function()
		local entry = skeletonConfig.Models.RoiOrc
		local list = pieces({ "body_geom", "chest_geom", "left_arm_geom", "right_arm_geom", "left_leg_geom", "right_leg_geom",
			"Banniere", "PicEpaule", "PicEpaule", "Crane_5", "Crane_6", "hache_geom" })
		local r = Skeleton.resolve(list, entry)
		assert(#r.missing == 0 and #r.warnings == 0, table.concat(r.warnings, " | "))
		assert(list[r.anchors.Tete].Name == "body_geom")
		assert(list[r.anchors.Buste].Name == "chest_geom", "body_geom is taken by the head")
		assert(targetOf(r, list, "Banniere") == "Buste", "config beats the 'banniere' held word")
		assert(r.targets[9] == Skeleton.NearestArm, "every piece of that name")
		assert(targetOf(r, list, "hache_geom") == Skeleton.NearestHand)
		assert(skeletonConfig.SharedSets[entry.Commun] == entry.Profil)
	end)

	test("config: every entry uses known bones and targets", function()
		for key, entry in skeletonConfig.Models do
			for bone in entry.Membres or {} do
				assert(Skeleton.bone(bone), `{key}: unknown bone {bone}`)
			end
			for piece, target in entry.Pieces or {} do
				assert(Skeleton.target(target), `{key}: unknown target {target} for {piece}`)
			end
			assert(entry.Commun == nil or skeletonConfig.SharedSets[entry.Commun], `{key}: unknown shared set`)
		end
	end)

	test("animationSets: own set first, shared set only with the common skeleton", function()
		local sets = Skeleton.animationSets({ JeuAnimations = "RoiOrc", JeuAnimationsCommun = "Squelette_Lourd", Squelette = Skeleton.Name })
		assert(table.concat(sets, ",") == "RoiOrc,Squelette_Lourd")
		sets = Skeleton.animationSets({ JeuAnimations = "RoiOrc", JeuAnimationsCommun = "Squelette_Lourd" })
		assert(table.concat(sets, ",") == "RoiOrc", "legacy rig: pose names would not match")
		sets = Skeleton.animationSets({ JeuAnimations = "Apercu_X", JeuAnimationsCombat = "X", JeuAnimationsCommun = "S", Squelette = Skeleton.Name }, true)
		assert(table.concat(sets, ",") == "X,Apercu_X,S")
		sets = Skeleton.animationSets({ JeuAnimations = "X", JeuAnimationsCombat = "X" }, true)
		assert(table.concat(sets, ",") == "X", "no duplicates")
		assert(#Skeleton.animationSets({ JeuAnimations = "" }) == 0)
	end)

	print(`Skeleton: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{failed} Skeleton test(s) failed`)
	end
end
