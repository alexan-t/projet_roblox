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
}

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
	-- États des cases avant combat : remplissage et contour (transparences).
	Case = {
		Hover = { Fill = Colors.Cream, FillT = 0.55, Outline = Colors.Cream, OutlineT = 0 },
		ValidTarget = { Fill = Colors.Cream, FillT = 0.85, Outline = Colors.Cream, OutlineT = 0.55 },
		Occupied = { Fill = Colors.WoodLight, FillT = 0.8, Outline = Colors.WoodLight, OutlineT = 0.4 },
		Selected = { Fill = Colors.Selected, FillT = 0.65, Outline = Colors.Selected, OutlineT = 0 },
		Invalid = { Fill = Colors.Error, FillT = 0.75, Outline = Colors.Error, OutlineT = 0.2 },
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
	},
}

local UITheme = {
	Colors = table.freeze(Colors),
	Transparency = table.freeze(Transparency),
	World = table.freeze({
		GridHidden = World.GridHidden,
		Glow = World.Glow,
		Case = table.freeze({
			Hover = table.freeze(World.Case.Hover),
			ValidTarget = table.freeze(World.Case.ValidTarget),
			Occupied = table.freeze(World.Case.Occupied),
			Selected = table.freeze(World.Case.Selected),
			Invalid = table.freeze(World.Case.Invalid),
		}),
	}),
	Typography = table.freeze({
		Display = Typography.Display,
		Body = Typography.Body,
		BodyBold = Typography.BodyBold,
		Size = table.freeze(Typography.Size),
		TextStroke = table.freeze(Typography.TextStroke),
	}),
	Radius = table.freeze(Radius),
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
