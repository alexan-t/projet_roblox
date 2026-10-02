--!strict
-- Icônes de classe des héros (docs/UI_DESIGN_SYSTEM.md § 7) — issue #19.
-- Une icône est un petit objet du monde, pas un pictogramme ni un emoji : arc, épée, hache, bouclier,
-- bâton, cible, en formes chunky aux couleurs de la palette, silhouette Ink derrière (contour « cuit »),
-- rendus en 3D dans un ViewportFrame éclairé d'en haut à gauche.
-- API : ClassIcons.viewport(parent, classId) -> ViewportFrame ; ClassIcons.model(classId) -> Model.
-- Classe inconnue : petite étoile dorée neutre.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)

local Colors = UITheme.Colors

local ClassIcons = {}

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
}

local function fallback(part: (Props) -> Part)
	part({ Size = Vector3.new(1.2, 1.2, 0.3), Color = Colors.Gold, CFrame = CFrame.Angles(0, 0, math.rad(45)) })
	part({ Size = Vector3.new(0.6, 0.6, 0.34), Color = Colors.GoldLight, CFrame = CFrame.Angles(0, 0, math.rad(45)) })
end

function ClassIcons.model(classId: string): Model
	local model = Instance.new("Model")
	model.Name = "Icone_" .. classId
	local shape = SHAPES[classId] or fallback
	shape(builder(model))
	-- silhouette Ink derrière (contour cuit, environ 6 % de la taille)
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			local back = p:Clone()
			back.Color = UITheme.Stroke.Color
			back.Size = p.Size + Vector3.new(0.22, 0.22, 0.05)
			back.CFrame = p.CFrame + Vector3.new(0, 0, 0.3)
			back.Parent = model
		end
	end
	return model
end

function ClassIcons.viewport(parent: Instance, classId: string): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "IconeClasse"
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.Ambient = Colors.Cream
	viewport.LightColor = Color3.new(1, 1, 1)
	viewport.LightDirection = Vector3.new(1, -1, 1) -- lumière chaude d'en haut à gauche
	viewport.Parent = parent
	ClassIcons.model(classId).Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0.3, -6.4), Vector3.zero)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return viewport
end

return ClassIcons
