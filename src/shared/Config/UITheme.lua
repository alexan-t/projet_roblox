--!strict
-- Design system UI (voir docs/UI_DESIGN_SYSTEM.md). Seule source des couleurs, transparences,
-- polices, rayons, contours, espacements, ombres et animations de l'interface.
-- Les Controllers lisent ces tokens : aucune valeur de style en dur dans un Controller.
-- Couleurs « matière » relevées dans la map (PlotTravail, Lobby, PlotsZones), pas inventées.

local function hex(value: string): Color3
	return Color3.fromHex(value)
end

local Colors = {
	-- Contour et texte
	Ink = hex("#1F1A17"), -- contour noir chaud de tous les éléments
	InkSoft = hex("#3A2C22"), -- texte sur fond clair
	TextLight = hex("#FFF6E4"), -- texte sur fond foncé ou coloré (toujours avec contour Ink)
	TextMuted = hex("#CDBFA6"), -- texte secondaire sur fond foncé

	-- Matières de la map
	Cream = hex("#F3E6C8"), -- murs, tour (#F0E2C4, #EEE4CE)
	Sand = hex("#E2D4B8"), -- dallage
	SandWarm = hex("#DEBC82"), -- clairières
	SandGold = hex("#E8C670"), -- chemins, pont
	Stone = hex("#D6C6A8"), -- bordures, dalles
	StoneDark = hex("#A89880"), -- muret, marches
	StoneGrey = hex("#968A7E"), -- socle rocheux
	WoodLight = hex("#BA8454"), -- planches du pont, tour
	Wood = hex("#96623E"), -- palissade, poteaux
	WoodDark = hex("#6C442A"), -- troncs, croisillons
	WoodDeep = hex("#3E2A1C"), -- fond des panneaux foncés (bois très sombre)
	Grass = hex("#7AB854"), -- sol herbe
	GrassLight = hex("#8CC050"), -- buissons, corniches
	Leaf = hex("#408E4A"), -- feuillage sombre
	River = hex("#46A2EC"), -- eau
	RiverLight = hex("#76CCF6"), -- cascade
	Foam = hex("#ECF8FF"), -- écume
	Gold = hex("#E6B23A"), -- emblèmes, bordures dorées
	GoldLight = hex("#F5CB5C"), -- haut des boutons principaux
	GoldDeep = hex("#C98E22"), -- bas des boutons principaux, lèvre
	RoyalRed = hex("#B83E30"), -- toiles, drapeaux
	RoyalBlue = hex("#3460B0"), -- drapeau du royaume
	Torch = hex("#FF8C28"), -- flammes (accent rare)
	Crystal = hex("#48E8E8"), -- cristaux (accent rare)

	-- Sémantique
	Success = hex("#5DB043"),
	Error = hex("#D9483B"),
	Warning = hex("#F2A93B"),
	Info = hex("#46A2EC"),
	Disabled = hex("#8F8478"),
	Selected = hex("#F5C542"),

	-- Barres
	Health = hex("#6CC04A"),
	HealthLow = hex("#E04A3A"),
	EnemyHealth = hex("#D9483B"),
	Energy = hex("#46A2EC"),
	EnergyFull = hex("#F5C542"),
	Progress = hex("#E8C670"),
	BarTrack = hex("#1F1A17"),

	-- Monnaies (teinte du fond de pastille ; l'icône porte la couleur principale)
	CurrencyGold = hex("#E6B23A"),
	CurrencyGems = hex("#48C8E8"),
	CurrencyTickets = hex("#B83E30"),
	TicketLight = hex("#D8584A"), -- montant d'un ticket dans un reveal (pack « Monnaies »)
	DisabledLip = hex("#5A524A"), -- lèvre d'un bouton gris « En cours » (pack « Quêtes HUD »)
	-- Mode Élite (fenêtre Expédition, maquette figée) : rouge royal profond, accent or.
	EliteTop = hex("#C8503E"), -- plaque de titre Élite (haut)
	EliteBottom = hex("#8E2A20"), -- plaque de titre Élite (bas)
	EliteFaceTop = hex("#D8584A"), -- onglet / bouton Élite (haut)
	EliteFaceBottom = hex("#9A2E22"), -- onglet / bouton Élite (bas)
	EliteCardTop = hex("#A63A2E"), -- carte de stage Élite (haut)
	EliteCardBottom = hex("#6E2219"), -- carte de stage Élite (bas)
	EliteLip = hex("#5E1A12"), -- lèvre d'un bouton Élite
	ElitePale = hex("#FFB4A8"), -- texte clair sur fond Élite (multiplicateurs, équipe vide)
	GoldLip = hex("#8A5D12"), -- lèvre d'un bouton doré
	LockedTop = hex("#9A9086"), -- carte verrouillée (haut)
	LockedBottom = hex("#776E65"), -- carte verrouillée (bas)
	SuccessLight = hex("#8FD873"), -- « ✓ Obtenue »
	DropChanceLow = hex("#A45BE0"), -- chance de butin de 5 à 10 % (fenêtre Expédition, maquette figée)
	Guarantee = hex("#7B2FA8"), -- bandeau « Épique garanti » (Invocation V2, maquette figée)
}

-- Raretés des héros (RarityConfig) : badge, cadre de carte, lumière de l'invocation. Les monstres
-- n'ont aucune rareté. Transcendant n'a pas une couleur mais un dégradé qui tourne (RarityPrism).
-- Réservées à l'affichage d'une rareté, lues via RarityStyle (jamais UITheme.Rarity dans une vue) ;
-- une couleur au même hex qui dit autre chose a son propre token dans Colors (docs/UI_DESIGN_SYSTEM.md § 2).
local Rarity = {
	Commun = hex("#B9B0A3"), -- pierre claire
	PeuCommun = hex("#6CC04A"), -- vert prairie
	Rare = hex("#46A2EC"), -- bleu rivière
	Epique = hex("#A45BE0"), -- violet
	Legendaire = hex("#F5C542"), -- or
	Mythique = hex("#FF5A8A"), -- rose rubis
	Maudit = hex("#7B2FA8"), -- violet sombre (avec fumée noire)
	Supreme = hex("#EAF3FF"), -- blanc céleste
	Calamite = hex("#D2321E"), -- braise rouge
	Transcendant = hex("#7FF7E8"), -- teinte de repli du dégradé
}
local RarityPrism = { hex("#FF7A7A"), hex("#FFD36B"), hex("#7FF7A0"), hex("#7FF7E8"), hex("#8FA8FF"), hex("#E08CFF") }

-- Transparence de fond (BackgroundTransparency : 0 = opaque). Le monde reste visible derrière.
local Transparency = {
	Panel = 0.25, -- grand panneau, fenêtre
	PanelStrong = 0.12, -- sous-panneau, carte, slot
	HUD = 0.45, -- éléments de combat et de jeu permanents
	Overlay = 0.5, -- voile noir derrière une fenêtre
	Tooltip = 0.04, -- infobulle, presque opaque
	Track = 0.35, -- fond des barres
	Shadow = 0.75, -- ombre portée
	Disabled = 0.45, -- contenu (texte, icône) d'un élément désactivé
	Hover = 0.08, -- voile clair ajouté au survol
	Slot = 0.32, -- raccourci de hotbar occupé (plus léger qu'une carte)
	Empty = 0.85, -- raccourci vide
	Art = 0.35, -- zone d'illustration d'une carte
	Pulse = 0.45, -- creux de la pulsation d'une jauge pleine
}

-- Éléments dans le monde : grille de l'arène et surbrillances (Highlight), sans néon.
local World = {
	GridHidden = 0.85, -- transparence locale des cases hors placement
	Glow = 0.35, -- contour d'un héros à jauge pleine, éclat d'ultime
	-- Distance maximale (studs) d'affichage des infos flottantes (BillboardGui.MaxDistance) :
	-- combat (barres, icône de classe, chiffres, annonce d'ultime) visible depuis son arène, pas depuis
	-- les autres plots ; effets ponctuels (nom du héros invoqué, niveau du royaume) un peu plus loin.
	CombatDistance = 80,
	EffectDistance = 120,
	-- États des cases avant combat : remplissage et contour (transparences).
	Case = {
		Hover = { Fill = Colors.Cream, FillT = 0.55, Outline = Colors.Cream, OutlineT = 0 },
		ValidTarget = { Fill = Colors.Cream, FillT = 0.85, Outline = Colors.Cream, OutlineT = 0.55 },
		Occupied = { Fill = Colors.WoodLight, FillT = 0.8, Outline = Colors.WoodLight, OutlineT = 0.4 },
		Selected = { Fill = Colors.Selected, FillT = 0.65, Outline = Colors.Selected, OutlineT = 0 },
		Invalid = { Fill = Colors.Error, FillT = 0.75, Outline = Colors.Error, OutlineT = 0.2 },
	},
	-- Cible du tutoriel « vivante » (portail, pancarte, dalle) : même langage partout, sans pancarte ni
	-- gros contour permanent. Respiration douce : léger voile doré (Highlight), lumière qui pulse et
	-- quelques étincelles. Fill / Outline = transparences au creux (From) et au sommet (To) du battement.
	Guide = {
		Color = Colors.GoldLight,
		FillFrom = 0.95,
		FillTo = 0.72,
		OutlineFrom = 1, -- aucun contour au creux
		OutlineTo = 0.55, -- contour léger au sommet seulement
		Period = 1.4, -- s par battement
		LightRange = 14, -- studs
		LightFrom = 0.2,
		LightTo = 1.6,
		Sparkles = 3, -- étincelles par seconde
		SparkleSize = 0.35, -- studs
		HotbarScale = 1.08, -- raccourci de hotbar à prendre : léger gonflement
		Near = 0.6, -- arrivé près de la cible : battement plus marqué (part du sommet ajoutée au creux)
	},
}

-- Fredoka One : titres, boutons, onglets, noms, compteurs, labels courts.
-- Builder Sans : descriptions longues uniquement.
local Typography = {
	Display = Font.new("rbxasset://fonts/families/FredokaOne.json"),
	Body = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium),
	BodyBold = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
	-- Tailles en pixels pour un écran de référence de 1080 px de haut (UIScale adapte le reste).
	Size = {
		Hero = 56, -- Victoire / Défaite
		Title = 32, -- titre de fenêtre
		Heading = 24, -- titre de section, nom de héros
		Button = 22,
		Label = 18, -- onglet, compteur, badge long
		Body = 18, -- description (Builder Sans)
		Caption = 14, -- badge, mention courte ; jamais en dessous
		Icon = 30, -- icône de raccourci, aperçu du héros en main
		IconLarge = 40, -- icône de carte
	},
	-- Épaisseur du contour Ink du texte Fredoka selon sa taille (px).
	TextStroke = {
		Small = 2, -- jusqu'à 18 px
		Medium = 3, -- 19 à 32 px
		Large = 4, -- au-delà
	},
}

local Radius = {
	Small = UDim.new(0, 8), -- badge, petite icône
	Medium = UDim.new(0, 12), -- bouton, slot, carte
	Large = UDim.new(0, 18), -- panneau, fenêtre
	Pill = UDim.new(1, 0), -- pastille, barre, bouton rond
}

local Stroke = {
	Color = Colors.Ink,
	Thin = 2, -- badge, slot, barre
	Regular = 3, -- bouton, carte
	Thick = 4, -- fenêtre, panneau principal
	-- Panneaux dans le monde (BillboardGui / SurfaceGui en studs) : épaisseur relative
	-- (UIStroke.StrokeSizingMode = ScaledSize) pour rester constante quelle que soit la distance.
	WorldScaled = 0.08,
	LineJoin = Enum.LineJoinMode.Round,
	ScrollBar = 6, -- barre de défilement d'une liste
}

local Spacing = {
	XS = 4,
	S = 8,
	M = 12,
	L = 16,
	XL = 24,
	XXL = 32,
	ScreenMargin = 16, -- marge minimale au bord de l'écran (mobile compris)
	TouchTarget = 44, -- taille minimale d'une zone tactile
}

local Shadow = {
	Color = Colors.Ink,
	Transparency = Transparency.Shadow,
	Offset = UDim2.fromOffset(0, 4), -- ombre pleine décalée, sans flou
	ButtonLip = 4, -- hauteur de la « lèvre » des boutons chunky (px)
}

local Animation = {
	Press = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Hover = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Open = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	Close = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
	Fade = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Toast = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	Count = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), -- compteur qui défile
	Pulse = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), -- jauge pleine
	Damage = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), -- chiffre de dégâts
	Burst = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), -- éclat d'ultime
	Scale = {
		Pressed = 0.94,
		Hover = 1.04,
		OpenFrom = 0.9,
		Pop = 1.12, -- gain de monnaie, badge « Nouveau »
		Highlight = 1.08, -- bouton mis en avant par le tutoriel : léger gonflement qui respire
	},
}

-- Pack visuel validé (ZIP « Icones Menu », « Monnaies », « Quêtes HUD ») : mesures relevées dans les
-- maquettes HTML, en px pour un écran de 1080 px de haut (UIScale adapte le reste).
local Pack = {
	-- Menu principal : tuile chunky (face crème sur lèvre bois), icône PNG qui déborde en haut, nom dessous.
	Menu = {
		Column = 84, -- largeur d'une colonne
		Tile = Vector2.new(72, 68), -- tuile derrière l'icône
		Icon = 84, -- icône (déborde de la tuile)
		IconRise = 14, -- px dont l'icône dépasse en haut de la tuile
		Label = 16, -- taille du nom
		LabelHeight = 20,
		GapX = 14,
		GapY = 18,
		Badge = Vector2.new(22, 40), -- « ! » (badge.png) à cheval sur le coin haut droit
		BadgeOffset = Vector2.new(-12, -20), -- depuis le coin haut droit de la tuile
		BadgeBob = 5, -- px de flottement du « ! »
		BadgePeriod = 1.2, -- s par flottement
	},
	-- HUD des monnaies : capsules sombres, icône qui dépasse à gauche.
	Currency = {
		Height = 36,
		Icon = 50,
		IconLeft = -22, -- px : l'icône dépasse à gauche de la capsule
		PadLeft = 34,
		PadRight = 18,
		Gap = 28,
		Top = 16,
		ValueMin = 44, -- largeur minimale de la valeur
		Fill = 0.45, -- transparence du fond WoodDeep
	},
	-- Fenêtre Expédition (maquette « Expedition.dc.html », figée) : trois dispositions. PC et tablette
	-- gardent la même hiérarchie (tablette : espacements réduits) ; téléphone (844 x 390) a ses propres
	-- tailles, sans texte minuscule. Device = taille de l'écran de référence de chaque disposition.
	Expedition = {
		Wide = {
			Device = Vector2.new(1600, 900), Window = Vector2.new(1080, 740), Top = 92,
			Pad = { Top = 34, Side = 20, Bottom = 18 }, Gap = 14,
			TabTop = -28, TabIcon = 40, TabSize = 30,
			HeadPad = 10, ZoneSize = 28, SubSize = 14, ModeHeight = 56, ModePadX = 18, ModeIcon = 30, ModeSize = 22,
			RailPad = { Top = 22, Side = 16, Bottom = 14 }, TrackInset = 60, TrackTop = 86, NodeGap = 14,
			NodeHeight = 124, NodeHeightBoss = 146, NodeIcon = 50, NodeSize = 22, BadgeSize = 14, BossPortrait = 78,
			LockIcon = 44, LockSize = 20,
			Columns = { 1.15, 1, 1 }, ColumnGap = 20, DetailPad = { Top = 14, Side = 18 }, SectionGap = 10, SectionSize = 22,
			WaveGap = 10, WaveLabel = 62, Monster = 70, TileGap = 12, BossTile = 84, BossSize = 26,
			BoxPad = 10, BoxSize = 18, Reward = 60, QuantitySize = 18,
			DropGap = 10, DropIcon = 44, DropSize = 16, ChanceWidth = 52,
			FootGap = 12, CtaHeight = 66, CtaPadX = 22, CtaSize = 24, LaunchWidth = 210, Slot = 48, TeamSize = 20,
		},
		Tablet = {
			Device = Vector2.new(1180, 820), Gap = 10, ColumnGap = 14, NodeGap = 10, TileGap = 10, Monster = 62,
			Pad = { Top = 32, Side = 16, Bottom = 14 }, DetailPad = { Top = 10, Side = 14 },
		},
		Phone = {
			Device = Vector2.new(844, 390), Window = Vector2.new(828, 362), Top = 20,
			Pad = { Top = 14, Side = 10, Bottom = 8 }, Gap = 5,
			TabTop = -20, TabIcon = 26, TabSize = 18,
			HeadPad = 3, ZoneSize = 18, SubSize = 0, ModeHeight = 34, ModePadX = 12, ModeIcon = 22, ModeSize = 17,
			RailPad = { Top = 14, Side = 8, Bottom = 4 }, TrackInset = 40, TrackTop = 40, NodeGap = 8,
			NodeHeight = 46, NodeHeightBoss = 46, NodeIcon = 0, NodeSize = 18, BadgeSize = 12, BossPortrait = 0,
			LockIcon = 30, LockSize = 16,
			Columns = { 1.15, 1.25, 0.9 }, ColumnGap = 10, DetailPad = { Top = 5, Side = 10 }, SectionGap = 3, SectionSize = 15,
			WaveGap = 4, WaveLabel = 22, Monster = 48, TileGap = 5, BossTile = 40, BossSize = 16,
			BoxPad = 4, BoxSize = 14, Reward = 40, QuantitySize = 14,
			DropGap = 4, DropIcon = 28, DropSize = 14, ChanceWidth = 44,
			FootGap = 8, CtaHeight = 48, CtaPadX = 14, CtaSize = 18, LaunchWidth = 150, Slot = 30, TeamSize = 16,
		},
		Breathe = 1.6, -- s d'un battement du bouton mis en avant (scale 1 → 1,04)
		Shine = 3.2, -- s d'un reflet qui traverse « Lancer »
		Lift = 6, -- px : la carte choisie se soulève
	},
	-- Fenêtre Sacoche (maquette « Sacoche.dc.html », figée) : mesures des trois dispositions. La position
	-- gauche du prototype (winL) n'est PAS reprise : la fenêtre est centrée dans la zone libre entre le HUD
	-- du haut et la hotbar (Shared.Sacoche.SacocheModel.frame), puis mise à l'échelle pour y tenir.
	Sacoche = {
		Wide = {
			Window = Vector2.new(1000, 680), Pad = { Top = 32, Side = 16, Bottom = 16 }, Gap = 14,
			TabTop = -26, TitleIcon = 52, TitleSize = 30,
			TabWidth = 230, TabHeight = 58, TabHeightOn = 66, TabIcon = 32, TabIconOn = 40, TabSize = 19, TabSizeOn = 22, TabsGap = 12,
			ChipHeight = 40, ChipSize = 15, SearchWidth = 200,
			HeroCols = 5, CardGap = 16, CardName = 30, CardNameSize = 16, LevelSize = 14,
			DetailWidth = 340, DetailGap = 12, DetailPad = 14, BigWidth = 130, HeroNameSize = 24,
			StatIcon = 34, StatSize = 26, CtaHeight = 66, CtaSize = 26, Cta2Height = 50, Cta2Size = 18,
			DollWidth = 360, SlotSize = 84, DollMid = 120, HeroRow = 130, DollGap = 14,
			EmptyIcon = 96, EmptyTitle = 22,
			PickBottom = 118, PickSize = 20,
			-- Équipement / Ressources (#72) : filtres >= 44 px, cartes d'item, tuiles de ressource compactes.
			FilterHeight = 44, CountWidth = 84,
			ItemCols = 3, ItemCellH = 176, ItemArt = 84, ItemNameSize = 16, ItemLineSize = 14, ItemGap = 12,
			ResCols = 2, ResTileH = 52, ResIcon = 40, ResNameSize = 14, ResAmountSize = 18, ResGap = 10,
			ResHeaderSize = 16, ResHintSize = 15, ResHintHeight = 24,
		},
		Tablet = {
			Window = Vector2.new(970, 610), HeroCols = 4, DetailWidth = 320, DollWidth = 340, TabWidth = 210,
		},
		Phone = {
			Window = Vector2.new(824, 290), Pad = { Top = 8, Side = 10, Bottom = 8 }, Gap = 8,
			TabTop = -6, TitleIcon = 0, TitleSize = 0,
			TabWidth = 64, TabHeight = 72, TabHeightOn = 84, TabIcon = 36, TabIconOn = 44, TabSize = 0, TabSizeOn = 0, TabsGap = 8,
			ChipHeight = 36, ChipSize = 15, SearchWidth = 120,
			HeroCols = 4, CardGap = 10, CardName = 22, CardNameSize = 13, LevelSize = 13,
			DetailWidth = 290, DetailGap = 6, DetailPad = 8, BigWidth = 56, HeroNameSize = 18,
			StatIcon = 24, StatSize = 19, CtaHeight = 52, CtaSize = 20, Cta2Height = 52, Cta2Size = 15,
			DollWidth = 250, SlotSize = 44, DollMid = 64, HeroRow = 58, DollGap = 8,
			EmptyIcon = 64, EmptyTitle = 18,
			PickBottom = 76, PickSize = 17,
			FilterHeight = 44, CountWidth = 70,
			ItemCols = 3, ItemCellH = 132, ItemArt = 52, ItemNameSize = 14, ItemLineSize = 14, ItemGap = 8,
			ResCols = 2, ResTileH = 48, ResIcon = 36, ResNameSize = 14, ResAmountSize = 16, ResGap = 8,
			ResHeaderSize = 15, ResHintSize = 14, ResHintHeight = 20,
		},
		Margin = 16, -- px : marge minimale autour de la fenêtre centrée (écran, HUD, hotbar)
		MinScale = 0.5,
		MaxScale = 1.25,
		Open = 0.22, -- s : ouverture scale 0,94 → 1,01 → 1 + fondu (aucun glissement horizontal)
		Lift = 6, -- px : la carte choisie se soulève
		Breathe = 1.8, -- s : respiration de « Placer »
		SlotPulse = 1.4, -- s : pulsation des raccourcis pendant le choix d'une case
	},
	-- Écran de fin de combat (RewardScreenController, Shared.Sacoche.LootModel) : mesures du design, en px pour
	-- un écran de 1080 px de haut ; la hauteur du contenu est CALCULÉE (LootModel.layout), l'échelle tient
	-- compte des deux axes (LootModel.fit). PC et tablette : une colonne (mesures ci-dessous). Téléphone
	-- (hauteur < 520, comme la Sacoche et l'Expédition) : surcharges Phone, deux colonnes (LootModel.pack).
	Reward = {
		Width = 760, SideMargin = 10, TitleY = 90, BelowTitle = 95,
		TitleSize = Typography.Size.Hero, TitleBox = Vector2.new(560, 80),
		RayLength = 230, Sparks = Vector2.new(230, 150), -- étincelles : ±X autour du titre, Y de 20 à Sparks.Y
		FirstClearSize = Vector2.new(170, 30), FirstClearOffset = Vector2.new(0, 58), -- depuis le centre du titre
		-- badges : taille minimale ; le texte grossi (textSize) les élargit, hauteur = texte + BadgePad
		NewBadge = Vector2.new(84, 24), BadgeTextSize = Typography.Size.Caption, BadgePad = 8,
		BadgeLift = 6, -- « NIVEAU SUPÉRIEUR ! » posé au-dessus de la puce (bas du badge à 6 px sous le bord), jamais sur le nom
		-- cartes de monnaie : illustration 60 %, puis nom et quantité sur deux lignes de CardLine px (texte au pire)
		CardSize = Vector2.new(132, 176), CardGap = Spacing.XL, CardsPad = 9, AfterCards = 18,
		CardNameSize = Typography.Size.Label, CardAmountSize = Typography.Size.Heading, CardLine = 28,
		LootGap = 10, AfterLoot = 20,
		BandSize = Vector2.new(740, 112), BandArt = 92, BandHeadSize = 16, BandNameSize = 24, BandLineSize = 18, BandMoreSize = 18, BandMoreWidth = 200,
		ChipSize = Vector2.new(128, 48), ChipIcon = 36, ChipGap = 8, ChipRowWidth = 740, ChipAmountSize = 18, ChipMoreSize = 16,
		CaptionSize = 16, CaptionHeight = 32, NoteSize = 15, NoteHeight = 32,
		-- héros sur UNE ligne (jusqu'à ArenaConfig.MaxHeroes) : l'écran s'élargit au lieu de passer à la ligne
		-- puce de héros : nom, « Nv. » et « +XP », barre, « x / y XP » ; lignes de HeroLine px (texte au pire)
		HeroChip = Vector2.new(440, 120), HeroHeading = 30, HeroGap = 12,
		HeroNameSize = Typography.Size.Label, HeroLevelSize = Typography.Size.Heading, HeroNoteSize = Typography.Size.Caption,
		HeroLine = 28, HeroBar = 14,
		ButtonSize = Vector2.new(220, 56), ButtonLip = Shadow.ButtonLip, ButtonTextSize = Typography.Size.Button,
		ButtonGap = 20, BottomPad = 80, MinHeight = 520,
		-- échelle : contenu tenu entre le bas des monnaies et le haut de la hotbar (Margin de chaque côté)
		ReferenceHeight = 1080, Margin = 16, MinScale = 0.5, MaxScale = 1.4,
		-- zone trop étroite (téléphone en paysage) : tout l'écran, échelle jusqu'à FloorScale, hotbar masquée
		-- par un voile opaque (transparence OverlapMask) au lieu d'être recouverte en silence
		FloorScale = 0.3, OverlapMask = 0.12,
		-- px réels minimum de TOUS les petits textes (butin, badges, cartes, héros, bouton), jusqu'à MinScale
		-- (design system § 4) : à MinScale un texte fait MinText / MinScale = 28 px du design, les boîtes en tiennent compte
		MinText = 14,
		-- Téléphone en paysage (écran de référence 844 x 390, px réels à l'échelle 1). Deux colonnes : à gauche
		-- les monnaies (cartes horizontales compactes) puis le butin ; à droite les héros (deux par ligne) puis
		-- « Continuer », aligné sur le bas du contenu. La zone entre les monnaies et la hotbar (~200 px) ne
		-- suffit pas : la hotbar est masquée par le voile (Overlap explicite), les monnaies restent visibles.
		-- Aucun texte sous 14 px réels jusqu'à MinScale (textes compensés par LootModel.textSize).
		Phone = {
			Width = 828, TwoColumns = true, ColumnGap = 16, SideMargin = 0,
			TitleY = 22, BelowTitle = 36, TitleSize = 34, TitleBox = Vector2.new(320, 44),
			RayLength = 100, Sparks = Vector2.new(240, 40),
			FirstClearSize = Vector2.new(150, 24), FirstClearOffset = Vector2.new(180, 0),
			NewBadge = Vector2.new(72, 20), BadgeLift = 6, -- badges posés au-dessus du coin droit (bas du badge à 6 px sous le bord)
			CardSize = Vector2.new(136, 48), CardGap = 8, CardsPad = 0, AfterCards = 8, Compact = true,
			CardNameSize = 14, CardAmountSize = 18,
			LootGap = 6, AfterLoot = 0,
			BandSize = Vector2.new(440, 68), BandArt = 52, BandNameSize = 16, BandLineSize = 14, BandMoreSize = 16, BandMoreWidth = 150,
			ChipSize = Vector2.new(82, 44), ChipIcon = 30, ChipGap = 7, ChipRowWidth = 440, ChipAmountSize = 16, ChipMoreSize = 14,
			CaptionSize = 14, CaptionHeight = 18, NoteSize = 14, NoteHeight = 18,
			HeroChip = Vector2.new(178, 58), HeroHeading = 0, HeroGap = 14, HeroPerRow = 2, -- sans intitulé « Héros » (place des badges de niveau)
			HeroNameSize = 14, HeroLevelSize = 16, HeroBar = 8,
			ButtonSize = Vector2.new(180, 44), ButtonTextSize = 20,
			ButtonGap = 12, BottomPad = 0, MinHeight = 0,
			ReferenceHeight = 390, Margin = 8, MinScale = 0.8, MaxScale = 1.3,
		},
	},
	-- Panneau Quêtes et reveal.
	Quest = {
		Width = 600,
		Padding = Vector2.new(20, 20), -- côtés, bas
		PaddingTop = 44,
		Fill = 0.12, -- fond WoodDeep de la fenêtre
		RowFill = 0.65, -- fond Ink d'une quête
		RowClaimableFill = 0.78, -- fond SandGold d'une quête à récupérer
		ClaimedFade = 0.45, -- quête récupérée : contenu estompé
		Track = 0.35, -- fond Ink de la barre
		TileFill = 0.1, -- fond Sand d'une récompense
		Tile = 52,
		TileIcon = 38,
		Button = Vector2.new(128, 44),
		RevealGlow = 150, -- px de l'icône Glow dans le reveal
		RevealRays = 420,
		Toast = 2.6, -- s d'affichage du résumé après le reveal
	},
}

local UITheme = {
	Colors = table.freeze(Colors),
	Rarity = table.freeze(Rarity),
	RarityPrism = table.freeze(RarityPrism),
	Transparency = table.freeze(Transparency),
	World = table.freeze({
		GridHidden = World.GridHidden,
		Glow = World.Glow,
		CombatDistance = World.CombatDistance,
		EffectDistance = World.EffectDistance,
		Case = table.freeze({
			Hover = table.freeze(World.Case.Hover),
			ValidTarget = table.freeze(World.Case.ValidTarget),
			Occupied = table.freeze(World.Case.Occupied),
			Selected = table.freeze(World.Case.Selected),
			Invalid = table.freeze(World.Case.Invalid),
		}),
		Guide = table.freeze(World.Guide),
	}),
	Typography = table.freeze({
		Display = Typography.Display,
		Body = Typography.Body,
		BodyBold = Typography.BodyBold,
		Size = table.freeze(Typography.Size),
		TextStroke = table.freeze(Typography.TextStroke),
	}),
	Radius = table.freeze(Radius),
	Pack = table.freeze({
		Menu = table.freeze(Pack.Menu),
		Currency = table.freeze(Pack.Currency),
		Quest = table.freeze(Pack.Quest),
		Expedition = table.freeze(Pack.Expedition),
		Sacoche = table.freeze(Pack.Sacoche),
		Reward = table.freeze(Pack.Reward),
	}),
	Stroke = table.freeze(Stroke),
	Spacing = table.freeze(Spacing),
	Shadow = table.freeze(Shadow),
	Animation = table.freeze({
		Press = Animation.Press,
		Hover = Animation.Hover,
		Open = Animation.Open,
		Close = Animation.Close,
		Fade = Animation.Fade,
		Toast = Animation.Toast,
		Count = Animation.Count,
		Pulse = Animation.Pulse,
		Damage = Animation.Damage,
		Burst = Animation.Burst,
		Scale = table.freeze(Animation.Scale),
	}),
}

return table.freeze(UITheme)
