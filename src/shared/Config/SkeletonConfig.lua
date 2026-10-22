--!strict
-- Fiches de branchement des modèles sur le squelette commun (voir docs/SKELETON.md).
-- Clé = nom du jeu d'animations propre au modèle (Set d'AnimationKit, attribut JeuAnimations).
--   Membres : os -> pièce qui donne la forme du membre, quand son nom sort du format IA
--             (Buste, Tete, BrasGauche, BrasDroit, JambeGauche, JambeDroite).
--   Pieces  : pièce -> os de rattachement (toutes les pièces de ce nom). Os : Buste, Tete, Bras*,
--             Jambe*, ArmeGauche / ArmeDroite (tenue en main) ; ou "BrasProche" / "MainProche".
--             Une pièce absente des fiches suit son attribut Os, sinon la détection par le nom.
--   Commun  : jeu d'animations partagé (nommé d'après les os) qui complète le jeu propre.
--   Profil, Attaque, Ultime : styles d'AnimationKit (Kit.Profiles, Kit.Attacks).
--   CouvercleBras : couleur de peau { R, G, B } pour Kit.closeArms (bras en coque), sinon absent.

export type Entry = {
	Membres: { [string]: string }?,
	Pieces: { [string]: string }?,
	Commun: string?,
	Profil: string?,
	Attaque: string?,
	Ultime: string?,
	CouvercleBras: { number }?,
}

local SkeletonConfig = {
	-- Jeux partagés : un par démarche. Toute séquence y est nommée d'après les os.
	SharedSets = table.freeze({
		Squelette_Leger = "Leger", -- héros, petits monstres
		Squelette_Lourd = "Lourd", -- tréants, colosses, boss
	}),

	Models = table.freeze({
		-- Héros de départ : format IA standard (Bestiaire.Heros.Socle_01 et Assets.Combat.Heros_EcuyerDuRempart).
		-- Épée courte en main droite, bouclier en main gauche ; cor_geom (cor de chasse) reste au buste.
		EcuyerDuRempart = table.freeze({
			Pieces = table.freeze({ short_sword_geom = "ArmeDroite", shield_geom = "ArmeGauche" }),
			Commun = "Squelette_Leger",
			Profil = "Leger",
			Attaque = "Epee",
			Ultime = "Rempart",
		}),
		-- Boss de la Zone 1 : sa tête s'appelle body_geom ; bannière dans le dos, pics et crânes
		-- d'épaule portés par le bras le plus proche ; bras en coque à fermer.
		RoiOrc = table.freeze({
			Membres = table.freeze({ Tete = "body_geom" }),
			Pieces = table.freeze({
				Banniere = "Buste",
				PicEpaule = "BrasProche",
				Crane_5 = "BrasProche",
				Crane_6 = "BrasProche",
			}),
			Commun = "Squelette_Lourd",
			Profil = "Lourd",
			Attaque = "Fendoir",
			CouvercleBras = table.freeze({ 76, 111, 41 }),
		}),

		-- Héros du Bestiaire dont une pièce sort de la détection par le nom (relevé du 22/10/2026,
		-- docs/HEROES_QA.md). Pas encore de jeu d'animations : ces fiches servent au rig et aux prises.
		-- #17 : faucon posé sur le bras levé.
		-- Couteau de chasse rangé au fourreau, à la ceinture.
		FauconnierGris = table.freeze({ Pieces = table.freeze({ falcon = "BrasProche", hunting_knife = "Buste" }) }),
		-- #21 : ronces enroulées sur chaque bras.
		GardienDesRonces = table.freeze({
			Pieces = table.freeze({ ronces_left_arm = "BrasGauche", ronces_right_arm = "BrasDroit" }),
		}),
		-- #32 : le bras droit est un gantelet de golem.
		ArchitecteDeGolems = table.freeze({ Membres = table.freeze({ BrasDroit = "gantelet_golem_geom" }) }),
		-- #36 : cloche portée dans le dos, maillet en main.
		GardienneDeLaDerniereCloche = table.freeze({ Pieces = table.freeze({ cloche_geom = "Buste" }) }),
		-- #45 : clé géante tenue en travers.
		MaitreDesPortesOubliees = table.freeze({ Pieces = table.freeze({ cle_geom = "MainProche" }) }),
		-- #52 : bec de corbin (marteau de guerre) en main.
		RoiDesCorbeauxSansOmbre = table.freeze({ Pieces = table.freeze({ BecDeCorbin = "MainProche" }) }),
		-- #43 : poing droit séparé du bras.
		SorciereDesMareesLunaires = table.freeze({ Pieces = table.freeze({ poing_droit_geom = "BrasDroit" }) }),
	} :: { [string]: Entry }),
}

return table.freeze(SkeletonConfig)
