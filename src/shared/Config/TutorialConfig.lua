--!strict
-- Guidage du tutoriel et menu de navigation (voir docs/TUTORIAL_GUIDANCE.md). Uniquement des données :
-- le code ne connaît aucune étape. Partagé : le serveur n'accepte que les drapeaux listés ici
-- (TutorialService), le client y lit ce qu'il montre (TutorialController, MenuController).
--
-- Flags : drapeaux « vu une fois » sauvegardés dans PlayerData.Tutorial.Seen (clé = true). Un drapeau
--   inconnu est refusé par le serveur. Ne jamais renommer un drapeau livré (il réapparaîtrait).
--
-- FirstOpen[drapeau] : guidage montré à la PREMIÈRE ouverture d'une interface, une seule fois par profil.
--   Steps : étapes montrées l'une après l'autre ; chacune pointe une cible UI logique (GuideTargets,
--     enregistrée par la vue elle-même : jamais de coordonnées) :
--       Target  : identifiant de la cible (« Zone.Element ») ;
--       Text    : légende très courte (2 à 4 mots) à côté de la flèche, facultative (sans Text : la
--                 légende proposée par la vue, ex. l'action possible de l'Expédition) ;
--       Seconds : durée maximale de l'étape (s) ; un clic sur la cible passe aussi à la suivante.
--   Hud : true pour un élément du HUD (pas une fenêtre) : le guidage attend qu'aucun écran ne soit ouvert.
--   Screen + Condition : guidage d'une partie d'une interface (ex. l'onglet Équipement de la Sacoche),
--     montré quand l'interface `Screen` est ouverte ET que la condition (voir Nudges) est vraie, après sa
--     propre découverte, jamais pendant un combat. Condition fausse : rien n'est montré ni enregistré (le
--     joueur sans objet n'est pas bloqué, son guidage viendra quand il en aura un).
--   Une étape dont la cible n'existe pas (ex. aucun héros) est sautée. Le drapeau est enregistré dès le
--   début du guidage ; interface fermée : le guidage s'arrête (pas de boucle à la réouverture).
--
-- Nudges : rappels « ouvre ce menu », une flèche UI sur une entrée tant que son drapeau n'est pas vu et
--   que la condition est remplie, seulement quand aucun écran n'est ouvert et hors combat.
--   Conditions (calculées par TutorialController, valeurs du serveur) : HasHero (au moins un héros),
--   SecondHero (au moins deux héros), FirstVictory (au moins un stage gagné), QuestClaimable (la quête
--   active attend « Récupérer », vue du serveur), HasEquipment (un héros possédé et un équipement
--   porté par personne : InventoryStore).
--   Badge : true pour allumer aussi le « ! » de l'entrée du menu visée (« Menu.<Id> ») tant que le rappel
--   est actif (une seule entrée à la fois : test).
--
-- Menu.Entries : boutons du menu principal (grille de 2 colonnes x 3 lignes à gauche), dans l'ordre :
--   Id (cible UI « Menu.<Id> », clé de Shared.Config.MenuIconConfig pour l'icône), Label (sous l'icône),
--   View (ce qu'ouvre le bouton : "Bag", "Index", "Stats", "Quests" ou "Soon"), Soon (texte de la fenêtre
--   « Bientôt disponible »), Flag (drapeau dont l'absence met le bouton en « attention », variante « ! »),
--   Badge (condition facultative de cette attention).

export type Step = { Target: string, Text: string?, Seconds: number? }
export type FirstOpen = { Steps: { Step }, Hud: boolean?, Screen: string?, Condition: string? }
export type Nudge = { Id: string, Target: string, Flag: string, Condition: string, Badge: boolean? }
export type Entry = { Id: string, Label: string, View: string, Soon: string?, Flag: string?, Badge: string? }

local TutorialConfig = {
	Flags = {
		"Bag", -- Sacoche ouverte
		"Expedition", -- fenêtre Expédition ouverte
		"Summon", -- fenêtre Invocation ouverte
		"SummonBanners", -- fenêtre Invocation avec les vraies bannières (après l'invocation tutorielle)
		"Index", -- Index des héros ouvert
		"Stats", -- Statistiques ouvertes
		"Currencies", -- première monnaie gagnée : les pastilles du HUD
		"Quests", -- panneau Quêtes ouvert
		"Equipment", -- premier équipement : onglet Équipement de la Sacoche, objet, « Équiper »
	},

	-- Durée d'une étape par défaut (s) et pause entre deux étapes.
	StepSeconds = 4,
	StepGap = 0.25,

	FirstOpen = {
		Bag = {
			Steps = {
				{ Target = "Bag.FirstHero", Text = "Tes héros", Seconds = 3 },
				{ Target = "Bag.Place", Text = "Pose-le dans l'arène" },
			},
		},
		Expedition = {
			Steps = {
				{ Target = "Expedition.Stage", Text = "Choisis un stage", Seconds = 3 },
				-- « Lancer » si un héros est posé, sinon « Préparer l'équipe » (la vue choisit)
				{ Target = "Expedition.Next" },
			},
		},
		Summon = {
			Steps = {
				{ Target = "Summon.Invoke", Text = "Invoque !" },
			},
		},
		SummonBanners = {
			Steps = {
				{ Target = "Summon.Banners", Text = "La bannière active", Seconds = 3 },
				{ Target = "Summon.Tickets", Text = "Tes tickets", Seconds = 3 },
				{ Target = "Summon.Invoke", Text = "Invoque !" },
			},
		},
		Index = {
			Steps = {
				{ Target = "Index.Counter", Text = "Héros découverts", Seconds = 3 },
			},
		},
		Stats = {
			Steps = {},
		},
		Quests = {
			Steps = {
				{ Target = "Quests.Claim", Text = "Récupère !" },
			},
		},
		-- Sacoche ouverte avec un objet à équiper, après la découverte « Bag » : héros possédé, objet, Équiper
		Equipment = {
			Screen = "Bag",
			Condition = "HasEquipment",
			Steps = {
				{ Target = "Bag.EquipmentTab", Text = "Ton équipement", Seconds = 6 },
				{ Target = "Bag.EquipHero", Text = "Ton héros", Seconds = 3 },
				{ Target = "Bag.FirstItem", Text = "Choisis un objet", Seconds = 6 },
				{ Target = "Bag.EquipAction", Text = "Équipe-le !", Seconds = 6 },
			},
		},
		Currencies = {
			Hud = true,
			Steps = {
				{ Target = "Currency.Gold", Text = "Ton or", Seconds = 3 },
			},
		},
	} :: { [string]: FirstOpen },

	Nudges = {
		-- Premier stage gagné, Sacoche jamais ouverte : la flèche montre le bouton Sac (pas avant : pendant
		-- la première défense, le guidage de quête montre déjà la hotbar et la pancarte).
		{ Id = "OpenBag", Target = "Menu.Bag", Flag = "Bag", Condition = "FirstVictory" },
		-- Première récompense de quête à récupérer, panneau jamais ouvert : la flèche montre le bouton Quêtes.
		{ Id = "OpenQuests", Target = "Menu.Quest", Flag = "Quests", Condition = "QuestClaimable" },
		-- Objet à équiper, guidage jamais vu : la flèche et le « ! » montrent le bouton Sac, une fois l'écran
		-- de fin fermé (rien pendant le combat ni sur l'écran). Même cible qu'OpenBag : une seule flèche.
		{ Id = "OpenEquipment", Target = "Menu.Bag", Flag = "Equipment", Condition = "HasEquipment", Badge = true },
	} :: { Nudge },

	Menu = {
		Entries = {
			{ Id = "Shop", Label = "Boutique", View = "Soon", Soon = "La boutique ouvrira bientôt : reviens après tes premières victoires !" },
			{ Id = "Bag", Label = "Sac", View = "Bag", Flag = "Bag", Badge = "HasHero" },
			{ Id = "Index", Label = "Index", View = "Index", Flag = "Index", Badge = "SecondHero" },
			{ Id = "Guild", Label = "Guilde", View = "Soon", Soon = "Les guildes arriveront dans une prochaine version." },
			{ Id = "Stats", Label = "Stats", View = "Stats", Flag = "Stats", Badge = "FirstVictory" },
			-- attention : quête à récupérer ou nouvelle quête (QuestController), pas de drapeau
			{ Id = "Quest", Label = "Quêtes", View = "Quests" },
		} :: { Entry },
	},
}

return TutorialConfig
