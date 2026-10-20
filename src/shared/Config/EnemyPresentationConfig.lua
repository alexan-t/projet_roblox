--!strict
-- Profils de mise en scène des ennemis (voir docs/COMBAT_PRESENTATION.md). Purement visuel, côté client :
-- entrée depuis le décor, style d'attaque, style de mort. Aucune stat, aucune règle de combat ici
-- (CombatEngine reste seul juge ; les temps de retenue du moteur sont dans CombatConfig.Presentation).
--
-- Clé = EnemyId (TypeId des événements de combat, ArenaConfig.EnemyTemplates). Un ennemi absent garde le
-- profil Default : il marche depuis une source du décor, joue ses animations et se dissout comme avant.
--
-- Origines : repères du décor de l'arène du plot du joueur, Arene.Zones.<Zone>.SourcesEnnemis (parties
-- invisibles, attribut Mode, enfants optionnels Etape1, Etape2... = points de passage). Un style d'entrée
-- liste les Mode qu'il accepte, par ordre de préférence. Jamais de coordonnées ici.

-- Déroulé d'une mort, en secondes depuis le coup fatal visible (à x1 ; divisé par la vitesse du combat).
-- Sert l'outro : le sac tombe à BagDrop près du corps, le corps ne s'efface qu'à FadeStart (après le
-- rebond du sac), tout est fini à Complete.
export type DeathTiming = {
	GroundImpact: number?, -- le corps touche le sol (chutes)
	BagDrop: number, -- le sac tombe (si c'était le dernier ennemi d'un combat gagné)
	FadeStart: number, -- le corps commence à s'effacer
	Complete: number, -- plus rien de la mort à l'écran
}

export type Profile = {
	Family: string,
	SpawnStyle: string, -- clé de SpawnStyles
	AttackStyle: string, -- "SlimeHeadbutt" | "SpearThrust" | "HeavyWeapon" | "Animation"
	DeathStyle: string, -- "SlimeBurst" | "HumanoidFall" | "HumanoidFallHeavy" | "Dissolve"
	Impact: number?, -- instant du coup à x1 (s) quand la séquence « Attaque » n'a pas d'attribut Impact
	EffectColor: Color3?, -- couleur des effets si le modèle n'a pas l'attribut CouleurEffet
	DeathTiming: DeathTiming,
}

export type SpawnStyle = {
	Modes: { string }, -- Mode des repères SourcesEnnemis acceptés, par préférence
	Kind: string, -- "Lake" (sort de l'eau, petits bonds) | "Walk" (marche le long des étapes)
	Heavy: boolean?, -- démarche lourde, impact au sol à l'arrivée (boss)
}

local EnemyPresentationConfig = {
	-- Attribut couleur des effets posé sur l'asset (Studio), ex. Ennemi_Slime : bleu de son eau.
	EffectColorAttribute = "CouleurEffet",
	-- Dossier des repères et zone de formation, dans le modèle de zone de l'arène du plot.
	SourcesFolder = "SourcesEnnemis",
	FrontName = "FrontEnnemi",
	-- Ordre des cases de formation pour la présentation avant Prêt (même grille 3x3 que ArenaService ;
	-- les vraies cases sont tirées par le moteur au lancement, les ennemis les rejoignent alors).
	IntroCells = table.freeze({ 5, 4, 6, 2, 8, 1, 3, 7, 9 }),
	-- Décalage aléatoire entre deux entrées (s) : jamais tous au même instant.
	Stagger = table.freeze({ Min = 0.1, Max = 0.25 }),
	-- Entrée avant Prêt (le moteur ne tourne pas) : durée cible d'une entrée (s).
	IntroDuration = 1.8,
	-- Sac de récompenses (visuel seulement) : asset de ReplicatedStorage.Assets.Combat.
	BagTemplate = "SacRecompense",
	-- Écart du sac par rapport aux pieds du dernier ennemi (studs), vers les héros : posé près du corps.
	BagOffset = 1.8,

	-- Outro d'un combat (client seulement ; RewardService a déjà tout attribué et sauvegardé) :
	--   coup fatal → mort complète → sac (chute + rebonds, BagBounce) → respiration (Breather)
	--   → annonce « VICTOIRE ! » (VictoryHold) → écran de récompenses.
	Outro = table.freeze({
		BagBounce = 0.8, -- chute et rebonds du sac
		Breather = 0.7, -- respiration avant l'annonce
		VictoryHold = 0.9, -- annonce « VICTOIRE ! » tenue avant l'écran de récompenses
		DefeatHold = 1.2, -- défaite : rien ne tombe, courte pause avant l'écran
		Safety = 8, -- l'écran s'ouvre quoi qu'il arrive après ce délai (aucun blocage possible)
	}),

	-- Teintes des effets (matière de la map, docs/UI_DESIGN_SYSTEM.md : palette relevée dans la map).
	Palette = table.freeze({
		Dust = Color3.fromHex("#E2D4B8"), -- sable (Sand)
		Spark = Color3.fromHex("#E8C670"), -- or chaud (SandGold)
		Water = Color3.fromHex("#76CCF6"), -- eau des mares (RiverLight)
		Glow = Color3.fromHex("#F5CB5C"), -- lueur du sac (GoldLight)
	}),

	SpawnStyles = table.freeze({
		Lake = table.freeze({ Modes = table.freeze({ "SautMare" }), Kind = "Lake" }),
		Camp = table.freeze({ Modes = table.freeze({ "SortieTente", "DescenteRampe", "SautPlateau" }), Kind = "Walk" }),
		CampBoss = table.freeze({ Modes = table.freeze({ "DescenteRampe", "SortieTente" }), Kind = "Walk", Heavy = true }),
		Bush = table.freeze({ Modes = table.freeze({ "SortieBuisson" }), Kind = "Walk" }),
	} :: { [string]: SpawnStyle }),

	Profiles = table.freeze({
		Slime = table.freeze({
			Family = "Slime",
			SpawnStyle = "Lake",
			AttackStyle = "SlimeHeadbutt",
			DeathStyle = "SlimeBurst",
			Impact = 0.27,
			EffectColor = Color3.fromHex("#76CCF6"),
			-- écrasé, gonfle, POP (0,26 s) puis gouttes ; le sac tombe dans l'éclaboussure
			DeathTiming = table.freeze({ BagDrop = 0.45, FadeStart = 0.26, Complete = 0.8 }),
		}),
		Gobelin = table.freeze({
			Family = "Goblin",
			SpawnStyle = "Camp",
			AttackStyle = "SpearThrust",
			DeathStyle = "HumanoidFall",
			Impact = 0.45, -- poussée de la lance dans Assets.Animations.Gobelin.Attaque (clé 0,45 s)
			-- Mort (1,1 s) : au sol vers 0,8 s ; le sac tombe à côté, rebondit, puis le corps s'efface
			DeathTiming = table.freeze({ GroundImpact = 0.8, BagDrop = 1.0, FadeStart = 2.3, Complete = 2.75 }),
		}),
		Boss = table.freeze({
			Family = "Orc",
			SpawnStyle = "CampBoss",
			AttackStyle = "HeavyWeapon", -- Fendoir + Seisme existants (AttackEffectController)
			DeathStyle = "HumanoidFallHeavy",
			-- réaction, chute lourde (0,9 s), poussière, pause, sac, puis effacement lent
			DeathTiming = table.freeze({ GroundImpact = 1.15, BagDrop = 1.5, FadeStart = 2.9, Complete = 3.4 }),
		}),
		-- Zones 2 à 6. Copies de combat statiques (sans squelette, comme Ennemi_Slime) : les slimes gardent le
		-- profil Slime (teinte de leur élément), les autres chargent d'un bloc (SlimeHeadbutt : élan + éclats de la
		-- couleur de l'effet) et tombent d'un bloc (HumanoidFall sans animation Mort : le corps bascule).
		SlimePlante = table.freeze({
			Family = "Slime", SpawnStyle = "Lake", AttackStyle = "SlimeHeadbutt", DeathStyle = "SlimeBurst", Impact = 0.27,
			EffectColor = Color3.fromHex("#64B464"), -- vert feuille (ART_DIRECTION § 8)
			DeathTiming = table.freeze({ BagDrop = 0.45, FadeStart = 0.26, Complete = 0.8 }),
		}),
		SlimeChampignon = table.freeze({
			Family = "Slime", SpawnStyle = "Bush", AttackStyle = "SlimeHeadbutt", DeathStyle = "SlimeBurst", Impact = 0.27,
			EffectColor = Color3.fromHex("#DCB48C"), -- crème du chapeau
			DeathTiming = table.freeze({ BagDrop = 0.45, FadeStart = 0.26, Complete = 0.8 }),
		}),
		SlimeLave = table.freeze({
			Family = "Slime", SpawnStyle = "Lake", AttackStyle = "SlimeHeadbutt", DeathStyle = "SlimeBurst", Impact = 0.27,
			EffectColor = Color3.fromHex("#F08C3C"), -- braise
			DeathTiming = table.freeze({ BagDrop = 0.45, FadeStart = 0.26, Complete = 0.8 }),
		}),
		GobelinDague = table.freeze({
			Family = "Goblin", SpawnStyle = "Camp", AttackStyle = "SlimeHeadbutt", DeathStyle = "HumanoidFall", Impact = 0.3,
			EffectColor = Color3.fromHex("#8C8C8C"), -- fer de la dague
			DeathTiming = table.freeze({ GroundImpact = 0.8, BagDrop = 1.0, FadeStart = 2.3, Complete = 2.75 }),
		}),
		Treant = table.freeze({
			Family = "Treant", SpawnStyle = "Bush", AttackStyle = "SlimeHeadbutt", DeathStyle = "HumanoidFall", Impact = 0.35,
			EffectColor = Color3.fromHex("#8C643C"), -- éclats d'écorce
			DeathTiming = table.freeze({ GroundImpact = 0.8, BagDrop = 1.0, FadeStart = 2.3, Complete = 2.75 }),
		}),
		TreantArbre = table.freeze({
			Family = "Treant", SpawnStyle = "Bush", AttackStyle = "SlimeHeadbutt", DeathStyle = "HumanoidFallHeavy", Impact = 0.4,
			EffectColor = Color3.fromHex("#8CDC64"), -- feuilles
			DeathTiming = table.freeze({ GroundImpact = 1.15, BagDrop = 1.5, FadeStart = 2.9, Complete = 3.4 }),
		}),
		KingSlime = table.freeze({
			Family = "Slime", SpawnStyle = "CampBoss", AttackStyle = "SlimeHeadbutt", DeathStyle = "SlimeBurst", Impact = 0.3,
			EffectColor = Color3.fromHex("#64B4DC"), -- gelée bleue
			DeathTiming = table.freeze({ BagDrop = 0.6, FadeStart = 0.3, Complete = 1.0 }),
		}),
		KingTreant = table.freeze({
			Family = "Treant", SpawnStyle = "CampBoss", AttackStyle = "SlimeHeadbutt", DeathStyle = "HumanoidFallHeavy", Impact = 0.45,
			EffectColor = Color3.fromHex("#8C643C"),
			DeathTiming = table.freeze({ GroundImpact = 1.15, BagDrop = 1.5, FadeStart = 2.9, Complete = 3.4 }),
		}),
		-- Zones 2 à 6, version B : copies de combat statiques des monstres des fiches (comme les précédents) ;
		-- les gelées sortent de l'eau et éclatent, les autres chargent d'un bloc et basculent.
		VaseDesSables = table.freeze({
			Family = "Slime", SpawnStyle = "Lake", AttackStyle = "SlimeHeadbutt", DeathStyle = "SlimeBurst", Impact = 0.27,
			EffectColor = Color3.fromHex("#DCB48C"),
			DeathTiming = table.freeze({ BagDrop = 0.45, FadeStart = 0.26, Complete = 0.8 }),
		}),
		ChacalParchemin = table.freeze({
			Family = "Desert", SpawnStyle = "Bush", AttackStyle = "SlimeHeadbutt", DeathStyle = "HumanoidFall", Impact = 0.35,
			EffectColor = Color3.fromHex("#B4B48C"),
			DeathTiming = table.freeze({ GroundImpact = 0.8, BagDrop = 1.0, FadeStart = 2.3, Complete = 2.75 }),
		}),
		ScarabeeForgeSoleil = table.freeze({
			Family = "Desert", SpawnStyle = "Bush", AttackStyle = "SlimeHeadbutt", DeathStyle = "HumanoidFall", Impact = 0.35,
			EffectColor = Color3.fromHex("#F5C542"),
			DeathTiming = table.freeze({ GroundImpact = 0.8, BagDrop = 1.0, FadeStart = 2.3, Complete = 2.75 }),
		}),
		MangeDune = table.freeze({
			Family = "Desert", SpawnStyle = "Bush", AttackStyle = "SlimeHeadbutt", DeathStyle = "HumanoidFall", Impact = 0.35,
			EffectColor = Color3.fromHex("#8C643C"),
			DeathTiming = table.freeze({ GroundImpact = 0.8, BagDrop = 1.0, FadeStart = 2.3, Complete = 2.75 }),
		}),
		GardienSansVisage = table.freeze({
			Family = "Desert", SpawnStyle = "Bush", AttackStyle = "SlimeHeadbutt", DeathStyle = "HumanoidFall", Impact = 0.35,
			EffectColor = Color3.fromHex("#B4B48C"),
			DeathTiming = table.freeze({ GroundImpact = 0.8, BagDrop = 1.0, FadeStart = 2.3, Complete = 2.75 }),
		}),
		ColosseEnseveli = table.freeze({
			Family = "Desert", SpawnStyle = "CampBoss", AttackStyle = "SlimeHeadbutt", DeathStyle = "HumanoidFallHeavy", Impact = 0.45,
			EffectColor = Color3.fromHex("#DCB48C"),
			DeathTiming = table.freeze({ GroundImpact = 1.15, BagDrop = 1.5, FadeStart = 2.9, Complete = 3.4 }),
		}),
		Givrelot = table.freeze({
			Family = "Glace", SpawnStyle = "Bush", AttackStyle = "SlimeHeadbutt", DeathStyle = "HumanoidFall", Impact = 0.35,
			EffectColor = Color3.fromHex("#8CB4DC"),
			DeathTiming = table.freeze({ GroundImpact = 0.8, BagDrop = 1.0, FadeStart = 2.3, Complete = 2.75 }),
		}),
		CrocDeGlacier = table.freeze({
			Family = "Glace", SpawnStyle = "Bush", AttackStyle = "SlimeHeadbutt", DeathStyle = "HumanoidFall", Impact = 0.35,
			EffectColor = Color3.fromHex("#64B4DC"),
			DeathTiming = table.freeze({ GroundImpact = 0.8, BagDrop = 1.0, FadeStart = 2.3, Complete = 2.75 }),
		}),
		ArmureGelee = table.freeze({
			Family = "Glace", SpawnStyle = "Bush", AttackStyle = "SlimeHeadbutt", DeathStyle = "HumanoidFall", Impact = 0.35,
			EffectColor = Color3.fromHex("#8CB4DC"),
			DeathTiming = table.freeze({ GroundImpact = 0.8, BagDrop = 1.0, FadeStart = 2.3, Complete = 2.75 }),
		}),
		BonhommeRoyal = table.freeze({
			Family = "Glace", SpawnStyle = "Bush", AttackStyle = "SlimeHeadbutt", DeathStyle = "HumanoidFall", Impact = 0.35,
			EffectColor = Color3.fromHex("#DCDCDC"),
			DeathTiming = table.freeze({ GroundImpact = 0.8, BagDrop = 1.0, FadeStart = 2.3, Complete = 2.75 }),
		}),
		MammouthCristallin = table.freeze({
			Family = "Glace", SpawnStyle = "Bush", AttackStyle = "SlimeHeadbutt", DeathStyle = "HumanoidFallHeavy", Impact = 0.4,
			EffectColor = Color3.fromHex("#64B4DC"),
			DeathTiming = table.freeze({ GroundImpact = 1.15, BagDrop = 1.5, FadeStart = 2.9, Complete = 3.4 }),
		}),
		RoiSansEte = table.freeze({
			Family = "Glace", SpawnStyle = "CampBoss", AttackStyle = "SlimeHeadbutt", DeathStyle = "HumanoidFallHeavy", Impact = 0.45,
			EffectColor = Color3.fromHex("#8CB4DC"),
			DeathTiming = table.freeze({ GroundImpact = 1.15, BagDrop = 1.5, FadeStart = 2.9, Complete = 3.4 }),
		}),
		ChevalierRivete = table.freeze({
			Family = "Forge", SpawnStyle = "Bush", AttackStyle = "SlimeHeadbutt", DeathStyle = "HumanoidFall", Impact = 0.35,
			EffectColor = Color3.fromHex("#8C8C8C"),
			DeathTiming = table.freeze({ GroundImpact = 0.8, BagDrop = 1.0, FadeStart = 2.3, Complete = 2.75 }),
		}),
		GolemCloche = table.freeze({
			Family = "Forge", SpawnStyle = "Bush", AttackStyle = "SlimeHeadbutt", DeathStyle = "HumanoidFall", Impact = 0.35,
			EffectColor = Color3.fromHex("#B48C3C"),
			DeathTiming = table.freeze({ GroundImpact = 0.8, BagDrop = 1.0, FadeStart = 2.3, Complete = 2.75 }),
		}),
		FourneauAmbulant = table.freeze({
			Family = "Forge", SpawnStyle = "Bush", AttackStyle = "SlimeHeadbutt", DeathStyle = "HumanoidFall", Impact = 0.35,
			EffectColor = Color3.fromHex("#F08C3C"),
			DeathTiming = table.freeze({ GroundImpact = 0.8, BagDrop = 1.0, FadeStart = 2.3, Complete = 2.75 }),
		}),
		Martelet = table.freeze({
			Family = "Forge", SpawnStyle = "Bush", AttackStyle = "SlimeHeadbutt", DeathStyle = "HumanoidFall", Impact = 0.35,
			EffectColor = Color3.fromHex("#8C8C8C"),
			DeathTiming = table.freeze({ GroundImpact = 0.8, BagDrop = 1.0, FadeStart = 2.3, Complete = 2.75 }),
		}),
		Chaine = table.freeze({
			Family = "Forge", SpawnStyle = "Bush", AttackStyle = "SlimeHeadbutt", DeathStyle = "HumanoidFall", Impact = 0.35,
			EffectColor = Color3.fromHex("#646464"),
			DeathTiming = table.freeze({ GroundImpact = 0.8, BagDrop = 1.0, FadeStart = 2.3, Complete = 2.75 }),
		}),
		MaitreDesForges = table.freeze({
			Family = "Forge", SpawnStyle = "CampBoss", AttackStyle = "SlimeHeadbutt", DeathStyle = "HumanoidFallHeavy", Impact = 0.45,
			EffectColor = Color3.fromHex("#F08C3C"),
			DeathTiming = table.freeze({ GroundImpact = 1.15, BagDrop = 1.5, FadeStart = 2.9, Complete = 3.4 }),
		}),
		MeduseCouronnee = table.freeze({
			Family = "Slime", SpawnStyle = "Lake", AttackStyle = "SlimeHeadbutt", DeathStyle = "SlimeBurst", Impact = 0.27,
			EffectColor = Color3.fromHex("#64B4DC"),
			DeathTiming = table.freeze({ BagDrop = 0.45, FadeStart = 0.26, Complete = 0.8 }),
		}),
		MureneMiroir = table.freeze({
			Family = "Abysses", SpawnStyle = "Bush", AttackStyle = "SlimeHeadbutt", DeathStyle = "HumanoidFall", Impact = 0.35,
			EffectColor = Color3.fromHex("#648CDC"),
			DeathTiming = table.freeze({ GroundImpact = 0.8, BagDrop = 1.0, FadeStart = 2.3, Complete = 2.75 }),
		}),
		CoffreBernard = table.freeze({
			Family = "Abysses", SpawnStyle = "Bush", AttackStyle = "SlimeHeadbutt", DeathStyle = "HumanoidFall", Impact = 0.35,
			EffectColor = Color3.fromHex("#B48C3C"),
			DeathTiming = table.freeze({ GroundImpact = 0.8, BagDrop = 1.0, FadeStart = 2.3, Complete = 2.75 }),
		}),
		ChevalierNoye = table.freeze({
			Family = "Abysses", SpawnStyle = "Bush", AttackStyle = "SlimeHeadbutt", DeathStyle = "HumanoidFall", Impact = 0.35,
			EffectColor = Color3.fromHex("#64B4A0"),
			DeathTiming = table.freeze({ GroundImpact = 0.8, BagDrop = 1.0, FadeStart = 2.3, Complete = 2.75 }),
		}),
		CrabeCathedrale = table.freeze({
			Family = "Abysses", SpawnStyle = "Bush", AttackStyle = "SlimeHeadbutt", DeathStyle = "HumanoidFall", Impact = 0.35,
			EffectColor = Color3.fromHex("#B4643C"),
			DeathTiming = table.freeze({ GroundImpact = 0.8, BagDrop = 1.0, FadeStart = 2.3, Complete = 2.75 }),
		}),
		Leviathan = table.freeze({
			Family = "Abysses", SpawnStyle = "CampBoss", AttackStyle = "SlimeHeadbutt", DeathStyle = "HumanoidFallHeavy", Impact = 0.45,
			EffectColor = Color3.fromHex("#648CDC"),
			DeathTiming = table.freeze({ GroundImpact = 1.15, BagDrop = 1.5, FadeStart = 2.9, Complete = 3.4 }),
		}),
		GargouilleAilee = table.freeze({
			Family = "Ciel", SpawnStyle = "Bush", AttackStyle = "SlimeHeadbutt", DeathStyle = "HumanoidFallHeavy", Impact = 0.4,
			EffectColor = Color3.fromHex("#8C8C8C"),
			DeathTiming = table.freeze({ GroundImpact = 1.15, BagDrop = 1.5, FadeStart = 2.9, Complete = 3.4 }),
		}),
		MiniColosseCeleste = table.freeze({
			Family = "Ciel", SpawnStyle = "Bush", AttackStyle = "SlimeHeadbutt", DeathStyle = "HumanoidFallHeavy", Impact = 0.4,
			EffectColor = Color3.fromHex("#F5C542"),
			DeathTiming = table.freeze({ GroundImpact = 1.15, BagDrop = 1.5, FadeStart = 2.9, Complete = 3.4 }),
		}),
		MoutonNuage = table.freeze({
			Family = "Slime", SpawnStyle = "Lake", AttackStyle = "SlimeHeadbutt", DeathStyle = "SlimeBurst", Impact = 0.27,
			EffectColor = Color3.fromHex("#DCDCEB"),
			DeathTiming = table.freeze({ BagDrop = 0.45, FadeStart = 0.26, Complete = 0.8 }),
		}),
		PoissonDuCiel = table.freeze({
			Family = "Ciel", SpawnStyle = "Bush", AttackStyle = "SlimeHeadbutt", DeathStyle = "HumanoidFall", Impact = 0.35,
			EffectColor = Color3.fromHex("#8CB4DC"),
			DeathTiming = table.freeze({ GroundImpact = 0.8, BagDrop = 1.0, FadeStart = 2.3, Complete = 2.75 }),
		}),
		BecTonnerre = table.freeze({
			Family = "Ciel", SpawnStyle = "Bush", AttackStyle = "SlimeHeadbutt", DeathStyle = "HumanoidFallHeavy", Impact = 0.4,
			EffectColor = Color3.fromHex("#F5C542"),
			DeathTiming = table.freeze({ GroundImpact = 1.15, BagDrop = 1.5, FadeStart = 2.9, Complete = 3.4 }),
		}),
		GardienCeleste = table.freeze({
			Family = "Ciel", SpawnStyle = "CampBoss", AttackStyle = "SlimeHeadbutt", DeathStyle = "HumanoidFallHeavy", Impact = 0.45,
			EffectColor = Color3.fromHex("#F5C542"),
			DeathTiming = table.freeze({ GroundImpact = 1.15, BagDrop = 1.5, FadeStart = 2.9, Complete = 3.4 }),
		}),
	} :: { [string]: Profile }),

	Default = table.freeze({
		Family = "Inconnue",
		SpawnStyle = "Bush",
		AttackStyle = "Animation",
		DeathStyle = "Dissolve",
		-- DefeatEffectController (dissolution 0,85 s)
		DeathTiming = table.freeze({ BagDrop = 0.6, FadeStart = 0, Complete = 0.85 }),
	}) :: Profile,
}

-- Profil d'un ennemi (Default si inconnu).
function EnemyPresentationConfig.profile(enemyId: any): Profile
	local found = if typeof(enemyId) == "string" then EnemyPresentationConfig.Profiles[enemyId] else nil
	return found or EnemyPresentationConfig.Default
end

-- Style d'entrée d'un profil (Bush si le nom est inconnu).
function EnemyPresentationConfig.spawnStyle(profile: Profile): SpawnStyle
	return EnemyPresentationConfig.SpawnStyles[profile.SpawnStyle] or EnemyPresentationConfig.SpawnStyles.Bush
end

export type Source = { Name: string, Mode: string? }

-- Repères acceptés par un style, dans l'ordre de préférence de ses Modes (pur, testé).
-- Aucun repère du style : tous les repères qui ont un Mode (l'ennemi sort quand même du décor).
function EnemyPresentationConfig.sourcesFor(style: SpawnStyle, sources: { Source }): { number }
	local picked: { number } = {}
	for _, mode in style.Modes do
		for index, source in sources do
			if source.Mode == mode then
				table.insert(picked, index)
			end
		end
	end
	if #picked == 0 then
		for index, source in sources do
			if typeof(source.Mode) == "string" then
				table.insert(picked, index)
			end
		end
	end
	return picked
end

-- Couleur des effets : attribut du modèle (Color3), sinon celle du profil, sinon l'eau.
function EnemyPresentationConfig.effectColor(attribute: any, profile: Profile): Color3
	if typeof(attribute) == "Color3" then
		return attribute
	end
	return profile.EffectColor or EnemyPresentationConfig.Palette.Water
end

return table.freeze(EnemyPresentationConfig)
