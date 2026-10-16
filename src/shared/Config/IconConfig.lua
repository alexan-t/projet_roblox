--!strict
-- Catalogue des icônes de l'interface (docs/UI_DESIGN_SYSTEM.md § 7). Partagé : Icons.icon (client)
-- affiche le PNG livré en ImageLabel, sinon le modèle 3D provisoire d'Icons.lua (même identifiant).
--   Id    = identifiant passé à Icons.icon / Icons.model (et clé de SHAPES dans Icons.lua) ;
--   Group = "Classe" (CombatProfile de HeroConfig), "Objet" ou "Navigation" ;
--   Hook  = l'objet à rendre lisible (idée principale du PNG) ;
--   Image = rbxassetid du PNG livré (512 × 512, contour Ink cuit), nil tant qu'il n'est pas produit.
-- Une icône livrée s'ajoute en cinquième argument :
--   icon("Royaume", "Royaume", "Navigation", "tour du royaume ...", "rbxassetid://...").

export type IconInfo = {
	Id: string,
	Name: string,
	Group: string,
	Hook: string,
	Image: string?,
}

local Icons: { [string]: IconInfo } = {}
local Ordered: { IconInfo } = {}

local function icon(id: string, name: string, group: string, hook: string, image: string?)
	local info: IconInfo = {
		Id = id,
		Name = name,
		Group = group,
		Hook = hook,
		Image = image,
	}
	Icons[id] = info
	table.insert(Ordered, info)
	table.freeze(info)
end

-- Classes de héros
icon("Archer", "Archer", "Classe", "arc en bois courbé, corde crème")
icon("Epeiste", "Épéiste", "Classe", "épée en biais, lame pierre claire, garde et pommeau dorés")
icon("Barbare", "Barbare", "Classe", "hache, manche bois, fer en éventail")
icon("Paladin", "Paladin", "Classe", "bouclier rond bleu royal, cerclage et bosse dorés")
icon("Magicien", "Magicien", "Classe", "bâton de bois, cristal cyan au sommet (seul point lumineux)")
icon("Tireur", "Tireur", "Classe", "cible, anneaux rouge royal et crème")
-- Objets
icon("Or", "Or", "Objet", "pièce d'or épaisse, liseré foncé, centre clair")
icon("Gemmes", "Gemmes", "Objet", "gemme cyan posée sur la pointe, facette haute claire")
icon("Ticket", "Ticket d'invocation", "Objet", "ticket de toile rouge sur cadre doré, sceau crème")
icon("Parchemin", "Quêtes", "Objet", "parchemin crème entre deux rouleaux de bois, ruban rouge")
icon("Combat", "Combat", "Objet", "deux épées croisées")
icon("Cadenas", "Verrouillé", "Objet", "cadenas doré, anse de pierre, serrure bois")
-- Navigation et états : les 7 icônes prioritaires qui manquaient (revue du 16 octobre)
icon("Collection", "Collection de héros", "Navigation", "grimoire relié de bois, coins dorés, médaillon de héros sur la couverture")
icon("Royaume", "Royaume", "Navigation", "tour crème crénelée, porte de bois, petit drapeau rouge")
icon("Carte", "Carte des zones", "Navigation", "carte de parchemin dépliée, chemin doré, repère rouge")
icon("Parametres", "Paramètres", "Navigation", "roue dentée en bois épais, moyeu doré")
icon("Coche", "Validé", "Navigation", "coche épaisse vert Success, posée de biais")
icon("Ultime", "Ultime", "Navigation", "éclat doré à quatre branches, cœur clair")
icon("Sacoche", "Sacoche", "Navigation", "sacoche de cuir brun, rabat et boucle dorée")

table.freeze(Icons)
table.freeze(Ordered)

return {
	Icons = Icons,
	Ordered = Ordered,
	-- PNG livré pour cet identifiant, ou nil (Icons.icon retombe alors sur le modèle 3D).
	image = function(id: string): string?
		local info = Icons[id]
		return info and info.Image
	end,
}
