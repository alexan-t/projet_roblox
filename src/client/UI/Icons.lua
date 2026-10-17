--!strict
-- Icônes de l'interface (docs/UI_DESIGN_SYSTEM.md § 7) — issue #19.
-- Une icône est un petit objet du monde, pas un pictogramme ni un emoji : formes chunky aux couleurs de
-- la palette, silhouette Ink derrière (contour « cuit »), rendues en 3D dans un ViewportFrame éclairé
-- d'en haut à gauche.
--   Classes de héros : Archer (arc), Epeiste (épée), Barbare (hache), Paladin (bouclier),
--   Magicien (bâton), Tireur (cible).
--   Objets : Parchemin (quête), Or (pièce), Gemmes, Ticket (invocation), Combat (épées croisées),
--   Cadenas (verrouillé).
--   Guidage et menu : Fleche (flèche du tutoriel, pointe vers le bas), Boutique (étal), Sac (sacoche),
--   Index (livre), Guilde (bannière), Stats (barres sur un socle).
-- API : Icons.viewport(parent, id) -> ViewportFrame ; Icons.model(id) -> Model.
-- Identifiant inconnu : petit losange doré neutre.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)

local Colors = UITheme.Colors

local Icons = {}

type Props = { [string]: any }

local function builder(model: Model): (Props) -> Part
	return function(props: Props): Part
		local p = Instance.new("Part")
		p.Anchored = true
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		for k, v in props do
			(p :: any)[k] = v
		end
		p.Parent = model
		return p
	end
end

local DIAGONAL = CFrame.Angles(0, 0, math.rad(-40)) -- objets longs posés en biais : silhouette plus lisible
local FACE = CFrame.Angles(0, math.rad(90), 0) -- disque (cylindre) tourné vers la caméra

local SHAPES: { [string]: (part: (Props) -> Part) -> () } = {
	-- arc en bois (segments sur un demi-cercle) et corde claire
	Archer = function(part)
		local count = 7
		for i = 0, count - 1 do
			local a = math.rad(-75 + i * 150 / (count - 1))
			local position = Vector3.new(math.cos(a) * 1.1 - 0.35, math.sin(a) * 1.25, 0)
			part({ Size = Vector3.new(0.38, 0.5, 0.38), Color = if i == 3 then Colors.WoodDark else Colors.WoodLight, CFrame = CFrame.new(position) * CFrame.Angles(0, 0, a) })
		end
		part({ Size = Vector3.new(0.08, 2.35, 0.08), Color = Colors.Cream, CFrame = CFrame.new(-0.07, 0, 0) })
	end,
	-- épée : lame pierre claire, garde et pommeau dorés, poignée bois
	Epeiste = function(part)
		local function at(y: number): CFrame
			return DIAGONAL * CFrame.new(0, y, 0)
		end
		part({ Size = Vector3.new(0.42, 1.7, 0.18), Color = Colors.Foam, CFrame = at(0.45) })
		part({ Size = Vector3.new(0.3, 0.3, 0.17), Color = Colors.Foam, CFrame = at(1.35) * CFrame.Angles(0, 0, math.rad(45)) })
		part({ Size = Vector3.new(1.1, 0.24, 0.3), Color = Colors.Gold, CFrame = at(-0.45) })
		part({ Size = Vector3.new(0.24, 0.6, 0.24), Color = Colors.WoodDark, CFrame = at(-0.85) })
		part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.38, Color = Colors.Gold, CFrame = at(-1.2) })
	end,
	-- hache : manche bois, fer pierre en éventail
	Barbare = function(part)
		local function at(x: number, y: number): CFrame
			return DIAGONAL * CFrame.new(x, y, 0)
		end
		part({ Size = Vector3.new(0.26, 2.5, 0.26), Color = Colors.Wood, CFrame = at(0, -0.1) })
		part({ Size = Vector3.new(0.9, 0.9, 0.22), Color = Colors.StoneGrey, CFrame = at(0.45, 0.75) })
		part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.22, 1.3, 1.3), Color = Colors.Stone, CFrame = at(0.85, 0.75) * FACE })
		part({ Size = Vector3.new(0.34, 0.34, 0.3), Color = Colors.WoodDark, CFrame = at(0, 0.75) })
	end,
	-- bouclier rond : bois bleu royal, cerclage et bosse dorés
	Paladin = function(part)
		part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 2.3, 2.3), Color = Colors.Gold, CFrame = FACE })
		part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.36, 1.9, 1.9), Color = Colors.RoyalBlue, CFrame = FACE })
		part({ Size = Vector3.new(0.28, 1.9, 0.4), Color = Colors.Gold, CFrame = CFrame.new(0, 0, -0.02) })
		part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.6, Color = Colors.GoldLight, CFrame = CFrame.new(0, 0, -0.2) })
	end,
	-- bâton de mage : bois, cristal au sommet
	Magicien = function(part)
		local function at(y: number): CFrame
			return DIAGONAL * CFrame.new(0, y, 0)
		end
		part({ Size = Vector3.new(0.26, 2.2, 0.26), Color = Colors.Wood, CFrame = at(-0.25) })
		part({ Size = Vector3.new(0.5, 0.24, 0.5), Color = Colors.Gold, CFrame = at(0.85) })
		part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.85, Color = Colors.Crystal, CFrame = at(1.3) })
		part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.3, Color = Colors.Foam, CFrame = at(1.4) * CFrame.new(-0.15, 0.1, -0.3) })
	end,
	-- cible : anneaux rouge royal et crème
	Tireur = function(part)
		local rings = { { 2.3, Colors.RoyalRed }, { 1.7, Colors.Cream }, { 1.1, Colors.RoyalRed }, { 0.5, Colors.Cream } }
		for i, ring in rings do
			part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2 + i * 0.05, ring[1], ring[1]), Color = ring[2], CFrame = FACE })
		end
	end,
	-- parchemin : feuille crème entre deux rouleaux de bois, lignes dorées, ruban rouge
	Parchemin = function(part)
		part({ Size = Vector3.new(1.7, 1.9, 0.12), Color = Colors.Cream })
		for _, y in { 1.0, -1.0 } do
			part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.1, 0.42, 0.42), Color = Colors.WoodLight, CFrame = CFrame.new(0, y, 0) })
		end
		part({ Size = Vector3.new(1.1, 0.12, 0.16), Color = Colors.SandGold, CFrame = CFrame.new(0, 0.35, -0.02) })
		part({ Size = Vector3.new(0.8, 0.12, 0.16), Color = Colors.SandGold, CFrame = CFrame.new(-0.15, 0, -0.02) })
		part({ Size = Vector3.new(0.3, 0.7, 0.18), Color = Colors.RoyalRed, CFrame = CFrame.new(0.55, -0.45, -0.05) })
	end,
	-- pièce d'or : disque doré, liseré foncé, centre clair
	Or = function(part)
		part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, 2.2, 2.2), Color = Colors.GoldDeep, CFrame = FACE })
		part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.42, 1.8, 1.8), Color = Colors.Gold, CFrame = FACE })
		part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.46, 1.1, 1.1), Color = Colors.GoldLight, CFrame = FACE })
	end,
	-- gemme : cube posé sur la pointe, facette haute plus claire
	Gemmes = function(part)
		local tilt = CFrame.Angles(math.rad(45), 0, math.rad(45))
		part({ Size = Vector3.new(1.5, 1.5, 1.5), Color = Colors.CurrencyGems, CFrame = tilt })
		part({ Size = Vector3.new(0.8, 0.8, 0.8), Color = Colors.Foam, CFrame = CFrame.new(-0.25, 0.35, -0.3) * tilt })
	end,
	-- ticket d'invocation : toile rouge sur cadre doré, sceau crème
	Ticket = function(part)
		local tilt = CFrame.Angles(0, 0, math.rad(-12))
		part({ Size = Vector3.new(2.6, 1.6, 0.2), Color = Colors.Gold, CFrame = tilt })
		part({ Size = Vector3.new(2.3, 1.3, 0.26), Color = Colors.RoyalRed, CFrame = tilt })
		part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 0.7, 0.7), Color = Colors.Cream, CFrame = tilt * FACE })
	end,
	-- combat : deux épées croisées
	Combat = function(part)
		for _, angle in { -40, 40 } do
			local base = CFrame.Angles(0, 0, math.rad(angle))
			part({ Size = Vector3.new(0.34, 1.9, 0.16), Color = Colors.Foam, CFrame = base * CFrame.new(0, 0.35, 0) })
			part({ Size = Vector3.new(0.9, 0.22, 0.26), Color = Colors.Gold, CFrame = base * CFrame.new(0, -0.65, 0) })
			part({ Size = Vector3.new(0.22, 0.5, 0.22), Color = Colors.WoodDark, CFrame = base * CFrame.new(0, -1.0, 0) })
		end
	end,
	-- cadenas : corps doré, anse pierre, serrure bois
	Cadenas = function(part)
		part({ Size = Vector3.new(1.6, 1.3, 0.5), Color = Colors.Gold, CFrame = CFrame.new(0, -0.35, 0) })
		part({ Size = Vector3.new(0.28, 0.8, 0.3), Color = Colors.StoneGrey, CFrame = CFrame.new(-0.5, 0.65, 0) })
		part({ Size = Vector3.new(0.28, 0.8, 0.3), Color = Colors.StoneGrey, CFrame = CFrame.new(0.5, 0.65, 0) })
		part({ Size = Vector3.new(1.28, 0.28, 0.3), Color = Colors.StoneGrey, CFrame = CFrame.new(0, 1.0, 0) })
		part({ Size = Vector3.new(0.26, 0.42, 0.56), Color = Colors.WoodDeep, CFrame = CFrame.new(0, -0.35, 0) })
	end,
}

-- Moitié de pointe de flèche (triangle rectangle dans le plan de l'icône) : angle droit en (0, top),
-- côtés de longueur width vers `side` (1 : droite de l'écran, -1 : gauche) et height vers le bas.
-- Un coin (WedgePart) tourné pour que sa face triangulaire regarde la caméra.
local function halfHead(part: (Props) -> Part, side: number, top: number, width: number, height: number, color: Color3)
	-- caméra des icônes en -Z regardant +Z : la droite de l'écran est le -X du monde
	local x = -side * width / 2
	local cframe = CFrame.fromMatrix(Vector3.new(x, top - height / 2, 0), Vector3.new(0, 0, side), Vector3.new(0, -1, 0), Vector3.new(side, 0, 0))
	local p = part({ Shape = Enum.PartType.Wedge, Color = color })
	-- ordre imposé : changer Shape après CFrame déplace la pièce (l'ordre d'une table n'est pas garanti)
	p.Size = Vector3.new(0.3, height, width)
	p.CFrame = cframe
end

-- Flèche chunky (pointe vers le bas) : tige et pointe dorées. Sert à la flèche UI (GuidePointer), à la
-- balise au-dessus d'une cible et, couchée, aux flèches au sol (GuideArrows).
SHAPES.Fleche = function(part)
	part({ Size = Vector3.new(0.95, 1.5, 0.3), Color = Colors.GoldLight, CFrame = CFrame.new(0, 0.8, 0) })
	for _, side in { 1, -1 } do
		halfHead(part, side, 0.15, 1.25, 1.6, Colors.GoldLight)
	end
	-- reflet clair sur la tige (volume « jouet »)
	part({ Size = Vector3.new(0.28, 1.1, 0.32), Color = Colors.Cream, CFrame = CFrame.new(0.2, 0.9, -0.01) })
end

-- étal de marché : comptoir bois, auvent rayé rouge et crème, pièce d'or posée
SHAPES.Boutique = function(part)
	part({ Size = Vector3.new(2.3, 0.9, 0.5), Color = Colors.Wood, CFrame = CFrame.new(0, -0.85, 0) })
	part({ Size = Vector3.new(2.4, 0.2, 0.55), Color = Colors.WoodLight, CFrame = CFrame.new(0, -0.35, 0) })
	for _, x in { -1.0, 1.0 } do
		part({ Size = Vector3.new(0.22, 1.5, 0.3), Color = Colors.WoodDark, CFrame = CFrame.new(x, 0.35, 0.05) })
	end
	for i = 0, 4 do
		part({ Size = Vector3.new(0.52, 0.75, 0.3), Color = if i % 2 == 0 then Colors.RoyalRed else Colors.Cream,
			CFrame = CFrame.new(1.04 - i * 0.52, 1.1, 0) * CFrame.Angles(math.rad(-12), 0, 0) })
	end
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 0.8, 0.8), Color = Colors.Gold, CFrame = CFrame.new(0, -0.05, -0.1) * FACE })
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.34, 0.45, 0.45), Color = Colors.GoldLight, CFrame = CFrame.new(0, -0.05, -0.1) * FACE })
end

-- sacoche de cuir : corps bois clair, rabat bois, boucle dorée, poche
SHAPES.Sac = function(part)
	part({ Size = Vector3.new(1.9, 1.8, 0.6), Color = Colors.WoodLight, CFrame = CFrame.new(0, -0.3, 0) })
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 1.9, 1.0), Color = Colors.WoodLight, CFrame = CFrame.new(0, 0.55, 0) * CFrame.Angles(0, math.rad(90), 0) })
	part({ Size = Vector3.new(1.95, 0.85, 0.66), Color = Colors.Wood, CFrame = CFrame.new(0, 0.55, -0.02) })
	part({ Size = Vector3.new(0.5, 0.45, 0.7), Color = Colors.Gold, CFrame = CFrame.new(0, 0.15, -0.04) })
	part({ Size = Vector3.new(0.22, 0.2, 0.74), Color = Colors.WoodDeep, CFrame = CFrame.new(0, 0.15, -0.05) })
	part({ Size = Vector3.new(1.1, 0.6, 0.64), Color = Colors.Wood, CFrame = CFrame.new(0, -0.75, -0.03) })
	part({ Size = Vector3.new(1.3, 0.22, 0.3), Color = Colors.WoodDark, CFrame = CFrame.new(0, 1.15, 0) })
end

-- livre (index) : couverture bleu royal, dos bois, tranche crème, emblème et coins dorés
SHAPES.Index = function(part)
	local tilt = CFrame.Angles(0, 0, math.rad(-8))
	part({ Size = Vector3.new(1.75, 2.2, 0.3), Color = Colors.Cream, CFrame = tilt * CFrame.new(0.08, 0, 0.1) })
	part({ Size = Vector3.new(1.8, 2.25, 0.2), Color = Colors.RoyalBlue, CFrame = tilt })
	part({ Size = Vector3.new(0.32, 2.3, 0.3), Color = Colors.WoodDark, CFrame = tilt * CFrame.new(0.9, 0, 0) })
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.26, 0.85, 0.85), Color = Colors.Gold, CFrame = tilt * CFrame.new(-0.05, 0.15, -0.05) * FACE })
	part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.38, Color = Colors.GoldLight, CFrame = tilt * CFrame.new(-0.05, 0.15, -0.2) })
	for _, y in { 1.0, -1.0 } do
		part({ Size = Vector3.new(0.34, 0.34, 0.24), Color = Colors.Gold, CFrame = tilt * CFrame.new(-0.78, y, -0.01) })
	end
	part({ Size = Vector3.new(0.9, 0.14, 0.24), Color = Colors.SandGold, CFrame = tilt * CFrame.new(-0.05, -0.65, -0.02) })
end

-- bannière de guilde : hampe bois, toile rouge à queue d'aronde, écu doré
SHAPES.Guilde = function(part)
	part({ Size = Vector3.new(0.22, 2.7, 0.22), Color = Colors.WoodDark, CFrame = CFrame.new(0.95, -0.05, 0) })
	part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.42, Color = Colors.Gold, CFrame = CFrame.new(0.95, 1.38, 0) })
	part({ Size = Vector3.new(1.9, 0.22, 0.24), Color = Colors.WoodLight, CFrame = CFrame.new(0.05, 1.05, 0) })
	part({ Size = Vector3.new(1.55, 1.6, 0.16), Color = Colors.RoyalRed, CFrame = CFrame.new(-0.05, 0.2, 0) })
	for _, x in { -0.5, 0.4 } do
		part({ Size = Vector3.new(0.6, 0.55, 0.16), Color = Colors.RoyalRed, CFrame = CFrame.new(x, -0.8, 0) })
	end
	part({ Size = Vector3.new(0.75, 0.6, 0.22), Color = Colors.Gold, CFrame = CFrame.new(-0.05, 0.4, -0.02) })
	part({ Size = Vector3.new(0.5, 0.5, 0.22), Color = Colors.Gold, CFrame = CFrame.new(-0.05, 0.05, -0.02) * CFrame.Angles(0, 0, math.rad(45)) })
	part({ Size = Vector3.new(0.3, 0.3, 0.26), Color = Colors.GoldLight, CFrame = CFrame.new(-0.05, 0.3, -0.04) })
end

-- statistiques : trois barres (herbe, rivière, or) de plus en plus hautes sur un socle de pierre
SHAPES.Stats = function(part)
	part({ Size = Vector3.new(2.5, 0.35, 0.5), Color = Colors.StoneDark, CFrame = CFrame.new(0, -1.15, 0) })
	local bars = { { -0.8, 0.9, Colors.Grass }, { 0, 1.5, Colors.River }, { 0.8, 2.1, Colors.Gold } }
	for _, bar in bars do
		local x, height, color = bar[1], bar[2], bar[3]
		-- caméra en -Z : x positif = gauche de l'écran ; la plus haute barre à droite
		part({ Size = Vector3.new(0.6, height, 0.4), Color = color, CFrame = CFrame.new(-x, -0.97 + height / 2, 0) })
		part({ Size = Vector3.new(0.18, height - 0.3, 0.42), Color = Colors.Foam, CFrame = CFrame.new(-x + 0.14, -0.97 + height / 2, -0.01) })
	end
end

local function fallback(part: (Props) -> Part)
	part({ Size = Vector3.new(1.2, 1.2, 0.3), Color = Colors.Gold, CFrame = CFrame.Angles(0, 0, math.rad(45)) })
	part({ Size = Vector3.new(0.6, 0.6, 0.34), Color = Colors.GoldLight, CFrame = CFrame.Angles(0, 0, math.rad(45)) })
end

function Icons.model(id: string): Model
	local model = Instance.new("Model")
	model.Name = "Icone_" .. id
	local shape = SHAPES[id] or fallback
	shape(builder(model))
	-- silhouette Ink derrière (contour cuit, environ 6 % de la taille)
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			local back = p:Clone()
			back.Color = UITheme.Stroke.Color
			-- un coin (pointe de flèche) a sa profondeur sur X : on épaissit ses deux côtés visibles
			back.Size = p.Size + (if p.Shape == Enum.PartType.Wedge then Vector3.new(0.05, 0.3, 0.3) else Vector3.new(0.22, 0.22, 0.05))
			back.CFrame = p.CFrame + Vector3.new(0, 0, 0.3)
			back.Parent = model
		end
	end
	-- pivot à l'origine du dessin : tourner l'icône (flèche UI) ou la poser (flèche au sol) reste dans son plan
	model.WorldPivot = CFrame.new()
	return model
end

-- Modèle réel d'un héros activé, copié par HeroService dans ReplicatedStorage.Assets.Heros
-- (attribut HeroId), ou nil s'il n'est pas (encore) répliqué.
function Icons.heroModel(heroId: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local heroes = assets and assets:FindFirstChild("Heros")
	if not heroes then
		return nil
	end
	for _, model in heroes:GetChildren() do
		if model:IsA("Model") and model:GetAttribute("HeroId") == heroId then
			return model
		end
	end
	return nil
end

function Icons.viewport(parent: Instance, id: string): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Icone"
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.Ambient = Colors.Cream
	viewport.LightColor = Color3.new(1, 1, 1)
	viewport.LightDirection = Vector3.new(1, -1, 1) -- lumière chaude d'en haut à gauche
	viewport.Parent = parent
	Icons.model(id).Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0.3, -6.4), Vector3.zero)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return viewport
end

return Icons
