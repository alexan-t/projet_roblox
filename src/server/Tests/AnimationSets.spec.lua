--!strict
-- Jamais exécuté par le jeu : lancé par tools/test-skeleton.ps1.
-- Teste le vrai AnimationSets (recherche des séquences dans ReplicatedStorage.Assets.Animations,
-- jeu propre puis jeu commun, jeux d'aperçu, pièces d'un os) avec le vrai Skeleton et des doubles
-- d'Instance (aucun accès à Studio).

return function(createAnimationSets: any, Skeleton: any)
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

	-- Double d'Instance : nom, classe, attributs, enfants.
	local BASE_PARTS = { Part = true, MeshPart = true, UnionOperation = true }
	local function node(className: string, name: string, attributes: { [string]: any }?, children: { any }?): any
		local self: any = { ClassName = className, Name = name, Size = { Magnitude = 1 } }
		local attrs = attributes or {}
		local kids = children or {}
		-- Parent suivi comme dans Roblox : un enfant re-parenté ailleurs disparaît de ce nœud.
		for _, child in kids do
			child.Parent = self
		end
		local function current(): { any }
			local list = {}
			for _, child in kids do
				if child.Parent == self then
					table.insert(list, child)
				end
			end
			return list
		end
		function self:GetAttribute(key: string): any
			return attrs[key]
		end
		function self:GetChildren(): { any }
			return current()
		end
		function self:FindFirstChild(childName: string): any
			for _, child in current() do
				if child.Name == childName then
					return child
				end
			end
			return nil
		end
		function self:GetDescendants(): { any }
			local list = {}
			for _, child in current() do
				table.insert(list, child)
				for _, sub in child:GetDescendants() do
					table.insert(list, sub)
				end
			end
			return list
		end
		function self:IsA(class: string): boolean
			return class == className or (class == "BasePart" and BASE_PARTS[className] == true)
		end
		return self
	end
	local function sequence(name: string): any
		return node("KeyframeSequence", name)
	end
	local function set(name: string, attributes: { [string]: any }?, names: { string }): any
		local list = {}
		for _, sequenceName in names do
			table.insert(list, sequence(sequenceName))
		end
		return node("Folder", name, attributes, list)
	end

	-- AnimationSets réel, branché sur un ReplicatedStorage double.
	local function load(folders: { any }?): any
		local storage = node("ReplicatedStorage", "ReplicatedStorage", nil,
			if folders then { node("Folder", "Assets", nil, { node("Folder", "Animations", nil, folders) }) } else {})
		local game = { GetService = function(_, service: string)
			assert(service == "ReplicatedStorage", `unexpected service {service}`)
			return storage
		end }
		local script = { Parent = { Skeleton = Skeleton } }
		return createAnimationSets({ game = game, script = script, require = function(module: any)
			return module
		end })
	end
	local function model(attributes: { [string]: any }, children: { any }?): any
		return node("Model", "Modele", attributes, children)
	end
	local function names(folders: { any }): string
		local list = {}
		for _, folder in folders do
			table.insert(list, folder.Name)
		end
		return table.concat(list, ",")
	end

	local LIBRARY = {
		set("RoiOrc", nil, { "Attente", "Attaque" }),
		set("Squelette_Lourd", { Squelette = "Humanoide" }, { "Attente", "Marche", "Coup" }),
		set("Apercu_RoiOrc", { Apercu = true }, { "Attente" }),
		node("Folder", "Vide", nil, { node("Animation", "Marche") }),
	}

	test("folders: own set then shared set, only with the common skeleton", function()
		local AnimationSets = load(LIBRARY)
		local rigged = model({ JeuAnimations = "RoiOrc", JeuAnimationsCommun = "Squelette_Lourd", Squelette = Skeleton.Name })
		assert(names(AnimationSets.folders(rigged)) == "RoiOrc,Squelette_Lourd")
		local legacy = model({ JeuAnimations = "RoiOrc", JeuAnimationsCommun = "Squelette_Lourd" })
		assert(names(AnimationSets.folders(legacy)) == "RoiOrc", "legacy rig ignores the shared set")
	end)

	test("folders: missing sets are skipped, no Assets folder gives nothing", function()
		local AnimationSets = load(LIBRARY)
		local m = model({ JeuAnimations = "Inconnu", JeuAnimationsCommun = "Squelette_Lourd", Squelette = Skeleton.Name })
		assert(names(AnimationSets.folders(m)) == "Squelette_Lourd")
		assert(#load(nil).folders(m) == 0)
	end)

	test("folders: a preview set stops the search, and is ignored in combat", function()
		local AnimationSets = load(LIBRARY)
		local m = model({ JeuAnimations = "Apercu_RoiOrc", JeuAnimationsCombat = "RoiOrc",
			JeuAnimationsCommun = "Squelette_Lourd", Squelette = Skeleton.Name })
		assert(names(AnimationSets.folders(m)) == "Apercu_RoiOrc", "preview is self-sufficient")
		assert(names(AnimationSets.folders(m, true)) == "RoiOrc,Squelette_Lourd", "combat skips the preview")
	end)

	test("sequences: own set wins, shared set fills the gaps, non-sequences ignored", function()
		local AnimationSets = load(LIBRARY)
		local m = model({ JeuAnimations = "RoiOrc", JeuAnimationsCommun = "Squelette_Lourd", Squelette = Skeleton.Name })
		local found = AnimationSets.sequences(m)
		assert(found.Attente == LIBRARY[1]:FindFirstChild("Attente"), "own Attente beats the shared one")
		assert(found.Marche == LIBRARY[2]:FindFirstChild("Marche"), "Marche comes from the shared set")
		assert(found.Coup ~= nil and found.Attaque ~= nil)
		local onlyAnimation = model({ JeuAnimations = "Vide" })
		assert(next(AnimationSets.sequences(onlyAnimation)) == nil, "an Animation is not a KeyframeSequence")
	end)

	test("find: first set holding the sequence, nil otherwise", function()
		local AnimationSets = load(LIBRARY)
		local m = model({ JeuAnimations = "RoiOrc", JeuAnimationsCommun = "Squelette_Lourd", Squelette = Skeleton.Name })
		assert(AnimationSets.find(m, "Coup", true) == LIBRARY[2]:FindFirstChild("Coup"))
		assert(AnimationSets.find(m, "Attaque", true) == LIBRARY[1]:FindFirstChild("Attaque"))
		assert(AnimationSets.find(m, "Ultime", true) == nil)
		assert(AnimationSets.find(model({ JeuAnimations = "Vide" }), "Marche") == nil)
	end)

	test("isAnimated: true as soon as one set is declared", function()
		local AnimationSets = load(LIBRARY)
		assert(AnimationSets.isAnimated(model({ JeuAnimations = "RoiOrc" })))
		assert(AnimationSets.isAnimated(model({ JeuAnimationsCombat = "RoiOrc" })), "combat set alone counts")
		assert(not AnimationSets.isAnimated(model({ JeuAnimationsCommun = "Squelette_Lourd" })), "shared set needs the skeleton")
		assert(not AnimationSets.isAnimated(model({})))
	end)

	test("pieces: visible parts bound to a bone, only on the common skeleton", function()
		local AnimationSets = load(LIBRARY)
		local sword = node("MeshPart", "weapon_geom", { Os = "ArmeDroite" })
		local guard = node("Part", "guard_geom", { Os = "ArmeDroite" })
		local children = {
			node("Folder", Skeleton.Folder, nil, { node("Part", "ArmeDroite") }), -- os invisible : pas d'attribut Os
			node("Part", "torso_geom", { Os = "Buste", OsAncre = true }),
			node("Model", "Lame", { Os = "ArmeDroite" }, { sword }),
			guard,
			node("Part", "buckler_geom", { Os = "ArmeGauche" }),
		}
		local rigged = model({ Squelette = Skeleton.Name }, children)
		local held = AnimationSets.pieces(rigged, "ArmeDroite")
		assert(#held == 2, `got {#held}`)
		assert(table.find(held, sword) and table.find(held, guard), "nested parts are found, the Model itself is not")
		assert(#AnimationSets.pieces(rigged, "Tete") == 0)
		assert(#AnimationSets.pieces(model({}, children), "ArmeDroite") == 0, "legacy rig: caller keeps its old search")
	end)

	-- Bug connu de la PR #56 : après migration, l'ancienne Marche du jeu propre masquait la commune.
	local function migrationLibrary(): ({ any }, any, any, any, any)
		local oldWalk = sequence("Marche") -- Marche_old : Pose de l'ancien squelette
		local ownAttack = sequence("Attaque")
		local sharedWalk = sequence("Marche") -- Marche_shared
		local sharedAttack = sequence("Attaque")
		local library = {
			node("Folder", "EcuyerDuRempart", nil, { oldWalk, ownAttack, sequence("Ultime") }),
			node("Folder", "Squelette_Leger", { Squelette = "Humanoide" }, { sharedWalk, sharedAttack }),
			set("Apercu_EcuyerDuRempart", { Apercu = true }, { "Attente" }),
			set("Gobelin", nil, { "Attente", "Marche", "Attaque", "Touche", "Mort" }),
			set("RoiOrc", nil, { "Marche", "Attaque" }),
		}
		return library, oldWalk, sharedWalk, ownAttack, sharedAttack
	end
	local function migrated(): any
		return model({ JeuAnimations = "EcuyerDuRempart", JeuAnimationsCombat = "EcuyerDuRempart",
			JeuAnimationsCommun = "Squelette_Leger", Squelette = Skeleton.Name })
	end

	test("bug #56: before migration the old own Marche masks the shared one", function()
		local library, oldWalk = migrationLibrary()
		local AnimationSets = load(library)
		assert(AnimationSets.find(migrated(), "Marche") == oldWalk, "reproduces the reported defect")
	end)

	test("migration: unshadow Marche -> find gives Marche_shared, old one archived", function()
		local library, oldWalk, sharedWalk = migrationLibrary()
		local AnimationSets = load(library)
		local archive = node("Folder", "Archive")
		local m = migrated()
		local moved = AnimationSets.unshadow(m, "Marche", archive)
		assert(#moved == 1 and moved[1] == oldWalk, "exactly the old own Marche is moved")
		assert(oldWalk.Parent == archive and oldWalk.Name == "EcuyerDuRempart_Marche")
		assert(AnimationSets.find(m, "Marche") == sharedWalk, "outside combat")
		assert(AnimationSets.find(m, "Marche", true) == sharedWalk, "in combat")
		assert(AnimationSets.sequences(m, true).Marche == sharedWalk)
		assert(#AnimationSets.unshadow(m, "Marche", archive) == 0, "re-running is a no-op")
	end)

	test("migration: a truly specific Attaque stays first, unshadow only touches the given name", function()
		local library, _, _, ownAttack, sharedAttack = migrationLibrary()
		local AnimationSets = load(library)
		local m = migrated()
		AnimationSets.unshadow(m, "Marche", node("Folder", "Archive"))
		assert(AnimationSets.find(m, "Attaque", true) == ownAttack, "own Attaque beats the shared one")
		assert(AnimationSets.find(m, "Attaque", true) ~= sharedAttack)
		assert(AnimationSets.find(m, "Ultime", true) == library[1]:FindFirstChild("Ultime"))
	end)

	test("migration: nothing moves without the common skeleton or without a shared sequence", function()
		local library, oldWalk = migrationLibrary()
		local AnimationSets = load(library)
		local archive = node("Folder", "Archive")
		local legacy = model({ JeuAnimations = "EcuyerDuRempart", JeuAnimationsCommun = "Squelette_Leger" })
		assert(#AnimationSets.unshadow(legacy, "Marche", archive) == 0 and oldWalk.Parent == library[1])
		assert(#AnimationSets.unshadow(migrated(), "Ultime", archive) == 0, "Ultime has no shared version: kept")
		assert(library[1]:FindFirstChild("Ultime") ~= nil)
	end)

	test("migration: the preview set is never touched", function()
		local library = migrationLibrary()
		local AnimationSets = load(library)
		local m = model({ JeuAnimations = "Apercu_EcuyerDuRempart", JeuAnimationsCombat = "EcuyerDuRempart",
			JeuAnimationsCommun = "Squelette_Leger", Squelette = Skeleton.Name })
		AnimationSets.unshadow(m, "Marche", node("Folder", "Archive"))
		assert(library[3]:FindFirstChild("Attente") ~= nil, "preview Attente stays")
		assert(names(AnimationSets.folders(m)) == "Apercu_EcuyerDuRempart", "preview still self-sufficient")
		assert(names(AnimationSets.folders(m, true)) == "EcuyerDuRempart,Squelette_Leger", "combat never reads the preview")
	end)

	test("legacy rigs (Ecuyer, Gobelin, Roi Orc before migration): exactly their own set, as before", function()
		local library = migrationLibrary()
		local AnimationSets = load(library)
		local cases = {
			{ model({ JeuAnimations = "EcuyerDuRempart" }), library[1] },
			{ model({ JeuAnimations = "Gobelin" }), library[4] },
			{ model({ JeuAnimations = "RoiOrc", EffetAttaque = "Seisme" }), library[5] },
		}
		for _, case in cases do
			local m, own = case[1], case[2]
			assert(names(AnimationSets.folders(m)) == own.Name)
			assert(names(AnimationSets.folders(m, true)) == own.Name)
			local found = AnimationSets.sequences(m)
			local count = 0
			for seqName, seq in found do
				count += 1
				assert(seq == own:FindFirstChild(seqName))
			end
			assert(count == #own:GetChildren(), own.Name .. " keeps all its sequences")
			assert(AnimationSets.find(m, "Marche", true) == own:FindFirstChild("Marche"))
			assert(#AnimationSets.pieces(m, "ArmeDroite") == 0, "legacy weapon search stays in the caller")
		end
		-- Même si on lui pose un jeu commun par erreur, un ancien rig ne le lit pas.
		local stray = model({ JeuAnimations = "RoiOrc", JeuAnimationsCommun = "Squelette_Leger" })
		assert(names(AnimationSets.folders(stray, true)) == "RoiOrc")
	end)

	test("shared set alone, missing set, missing sequence", function()
		local library, _, sharedWalk = migrationLibrary()
		local AnimationSets = load(library)
		local onlyShared = model({ JeuAnimationsCommun = "Squelette_Leger", Squelette = Skeleton.Name, JeuAnimations = "Absent" })
		assert(AnimationSets.find(onlyShared, "Marche", true) == sharedWalk)
		assert(AnimationSets.find(onlyShared, "Mort", true) == nil)
		local missing = model({ JeuAnimations = "Absent", JeuAnimationsCommun = "AbsentAussi", Squelette = Skeleton.Name })
		assert(#AnimationSets.folders(missing, true) == 0 and next(AnimationSets.sequences(missing, true)) == nil)
	end)

	print(`AnimationSets: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{failed} AnimationSets test(s) failed`)
	end
end
