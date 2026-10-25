# Republication — lots des héros (préparés, non lancés)

Suite du lot pilote (`REPUBLICATION_LOT_PILOTE.md`, PASS le 24/10/2026). **Rien n'est téléchargé,
publié ni remplacé** : chaque lot attend l'accord explicite de l'utilisateur.

## Périmètre

Les 60 héros de `HeroConfig` sont tous jouables et réellement affichés en jeu : HeroService clone
leurs modèles de `ServerStorage.Assets.Heros` vers `ReplicatedStorage.Assets.Heros` (portraits de la
hotbar, révélation de l'invocation, modèle de combat statique quand il n'y a pas de `CombatTemplate`,
royaume). Relevé dans Studio le 25/10/2026 (`GetProductInfo`, lecture seule) :

- **Écuyer du Rempart** : déjà au propriétaire `nxtoma` (18 assets, lot pilote).
- **59 autres héros** : **1 042 assets**, tous publiés par `cypher1359` (521 meshes, 521 textures),
  aucun asset tiers, aucun asset partagé entre deux héros. Les copies de `Workspace.Bestiaire.Heros`
  utilisent les mêmes identifiants : le remplacement sur toute la place les met à jour aussi.

## Découpage proposé (par rareté, 5 à 10 héros)

Ordre : les héros les plus souvent obtenus d'abord (départ et raretés basses), pour sécuriser le plus
visible en premier.

| Lot | Rareté | Héros | Assets | Héros du lot |
|---|---|---|---|---|
| `lot-heros-01` | Commun + Peu commun | 5 | 86 | Tireuse des Faubourgs (héros de départ), Lancier des Champs, Apprenti Pyromancien, Brise-Pierre, Guetteuse des Pins |
| `lot-heros-02` | Rare | 6 | 96 | Chevalier du Lierre, Mage des Lanternes, Fauconnier Gris, Lancière des Sources, Barde de Fer, Moine du Vent Bas |
| `lot-heros-03` | Épique | 8 | 144 | Gardien des Ronces, Cartomancienne d'Ambre, Duelliste du Croissant, Forgeron Runique, Prêtresse aux Lucioles, Briseur de Cloche, Veneur de Givre, Alchimiste aux Masques |
| `lot-heros-04` | Légendaire | 10 | 168 | Chevalier du Soleil Creux, Dame aux Mille Bannières, Lancier des Sept Orages, Architecte de Golems, Veuve du Lac Miroir, Chasseur de Comètes, Saint du Brasier Bleu, Gardienne de la Dernière Cloche, Prince des Racines d'Or, Archiviste du Temps Mort |
| `lot-heros-05` | Mythique | 10 | 186 | Navigateur des Cieux Renversés, Reine des Cent Lames, Berger des Astres, Géant au Cœur de Verre, Sorcière des Marées Lunaires, Chevalier de l'Éclipse Blanche, Maître des Portes Oubliées, Gardienne du Dragon Dormant, Tisseur de Destins, Empereur des Cendres d'Or |
| `lot-heros-06` | Maudit | 8 | 146 | Porteur du Cœur Noir, Chevalier aux Mille Clous, Nonne de la Lune Fendue, Roi des Corbeaux sans Ombre, Marionnettiste des Tombes, Lame du Serment Brisé, Sorcier de la Couronne Parasite, Chasseur de Noms |
| `lot-heros-07` | Suprême | 6 | 112 | Séraphin des Sept Sceaux, Reine du Firmament Doré, Chevalier de l'Aube Infinie, Oracle aux Cent Yeux, Forgeâme, Gardien du Trône Vide |
| `lot-heros-08` | Calamité + Transcendant | 6 | 104 | Marcheur du Cataclysme, Reine de la Mer Renversée, Soleil Dévoré, Titanide des Derniers Jours, Auréon, Porteur de la Première Aube, Elyria, qui Marche hors du Temps |
| **Total** | | **59** | **1 042** | |

Fichiers de lot : `automation/republication/lot-heros-0N.json` (ancien AssetId, type, HeroId).

## Procédure par lot (identique au pilote)

Chaque étape demande l'accord de l'utilisateur.

1. `download` du lot (lecture seule) : formats, tailles, aucun refus d'accès.
2. `publish --confirm --limit <taille du lot>`, puis `refresh` jusqu'à 100 % `Approved`, puis `mapping`.
3. Contrôle dans Studio, en lecture seule : propriétaire `nxtoma` et contenu identique (pixels,
   géométrie) pour chaque paire.
4. Remplacement : `tools/studio-replace-asset-ids.luau`, `DRY_RUN` d'abord, puis une étape Ctrl+Z.
5. Recette en Play **sur un store de recette** (`StoreRecette`, `SECURITY.md` § Recettes Studio) :
   portraits de la hotbar, révélation d'invocation, héros posés en arène et en combat, royaume ;
   console sans « not authorized » ni « not approved » ; captures ; caméra réinitialisée.
6. Inventaire et mapping commités (`automation/republication/lot-heros-0N.mapping.json`), verdict.

Volume Open Cloud par lot : au plus 186 publications, sous les 120/min de l'Assets API (l'outil
espace les appels). Durée attendue : quelques minutes par lot, plus la modération des textures.

## Hors de ces lots

Royaume (`RoyaumeEtats`, `Royaume`, `VitrineRoyaumes`), `Lobby.Plots` et `GrandArbre` : lots
suivants (`ASSET_OWNERSHIP_AUDIT.md`, opération 4). Mannequins R15 et assets tiers : à arbitrer.
