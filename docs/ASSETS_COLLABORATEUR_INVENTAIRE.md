# Inventaire — place « test 3 » et place DEV

Relevé du 02/11/2026, lecture seule. Synthèse et verdict : [`ASSETS_COLLABORATEUR_AUDIT.md`](ASSETS_COLLABORATEUR_AUDIT.md).

## 1. Méthode

- **DEV** (`78875801703886`, Edit, session `nxtoma`) : parcours récursif par `execute_luau`, sans
  écriture, de `ReplicatedStorage.Assets`, `ServerStorage.Assets`, `ServerStorage.RBX_ANIMSAVES`,
  `Workspace` (racine), `Workspace.Lobby.Plots.Plot_1.Arene.Zones`, `Workspace.PlotsZones`, et des
  38 monstres sources utilisés par `tools/studio-zones-assets.luau`. Propriétés relevées : celles de
  `tools/studio-check-asset-ownership.luau` (`MeshPart.MeshId/TextureID`, `SpecialMesh`, `Decal`,
  `Texture`, `ImageLabel/Button`, `Sound`, `Animation.AnimationId`, `ParticleEmitter`, `Beam`,
  `Trail`, `SurfaceAppearance`) et l'attribut `AssetId` des `KeyframeSequence`. Formats
  normalisés (`rbxassetid://N`, `?id=N`, `N`), dédupliqués par identifiant numérique.
- **Propriétaire** : `MarketplaceService:GetProductInfo` pour chacun des 817 identifiants
  (0 erreur). Champ `Creator` lu, jamais déduit de l'identifiant ni du nom.
- **test 3** (`120616399792561`) : **non ouverte** dans Studio pendant l'audit, donc rien n'y est
  relevé. Ses objets sont **déclarés** d'après les PR et les outils Git. Les deux objets portant le
  même nom dans les deux places ne sont **pas** supposés identiques.
- **Git** : `git fetch`, worktree séparé sur `origin/develop` (`79e236e`), essais de fusion
  `--no-commit` annulés, `rojo build` des branches #100 et #106.

## 2. Ce que DEV contient (relevé réel)

### `ReplicatedStorage.Assets.Combat` (16 modèles)

| Modèle | Rôle | Squelette / animations | Assets |
|---|---|---|---|
| `Heros_EcuyerDuRempart` | seul héros articulé | `JeuAnimations=EcuyerDuRempart`, `JeuAnimationsCommun=Squelette_Leger` ; **pas d'`EffetUltime`** | `nxtoma` (lot pilote) |
| `Ennemi_Gobelin`, `Ennemi_RoiOrc`, `Ennemi_Slime` | monstres de la Zone 1 | jeux `Gobelin`, `RoiOrc` | `nxtoma` (lot pilote) |
| `Heros_Archer`, `_Barbare`, `_Epeiste`, `_Magicien`, `_Paladin`, `_Tireur`, `MannequinBoss`, `MannequinGobelin`, `MannequinHeros`, `MannequinSlime` | mannequins R15 provisoires (`ProvisionalAsset=true`) | 27 `Animation` chacun | **43 assets tiers** (27 Roblox, 14 RBLXImagineer, 1 AvLab, 1 tombluedog84) |
| `Etendard_Niveau1`, `SacRecompense` | accessoires de combat | — | aucun AssetId |

**Absents** : les 59 autres `Heros_<Modèle>` (#104) et 38 `Ennemi_*` (8 déjà attendus par
`ArenaConfig` de `develop` : SlimePlante, SlimeChampignon, SlimeLave, GobelinDague, Treant,
TreantArbre, KingSlime, KingTreant ; 30 ajoutés par #100).

### `ReplicatedStorage.Assets.Animations` (9 jeux, 0 séquence publiée)

| Jeu | Séquences | `AssetId` |
|---|---|---|
| `EcuyerDuRempart` | Attaque, Ultime | aucun |
| `Gobelin` | Attaque, Attente, Marche, Mort, Touche | aucun |
| `RoiOrc` | Attaque | aucun |
| `TreantMasque` | Attaque, Marche | aucun |
| `Squelette_Leger`, `Squelette_Lourd` | Marche | aucun |
| `Apercu_EcuyerDuRempart`, `Apercu_RoiOrc`, `Apercu_TreantMasque` | Attente (atelier) | aucun |

`ServerStorage.RBX_ANIMSAVES` : `Gobelin` (×2), `EcuyerDuRempart_Squelette`, `RoiOrc_Squelette`.
`ServerStorage.AnimationKitArchive` : 7 séquences retirées.

### Zones

- `ServerStorage.Assets.ZonesArene` : **absent**. `ServerStorage.ZonesRangees_*` : absent.
- `Workspace.Lobby.Plots.Plot_1.Arene.Zones.Zone1_PlaineDuRoyaume` : présent (`ZoneId=1`,
  1 273 descendants, **0 AssetId**). C'est le prérequis de `tools/studio-zones-assets.luau`.
- `Workspace.PlotsZones.Plot_Zone2..6` : présents (786 descendants chacun), **252 AssetIds
  uniques, tous `cypher1359`**, 1 260 propriétés (vitrine de la version A, fusionnée par #95/#97).
- Monstres sources dans `Workspace` : les 38 requis par l'outil sont présents.

## 3. Propriété des 817 AssetIds uniques de DEV

| Périmètre DEV | AssetIds uniques | nxtoma | cypher1359 | tiers |
|---|---|---|---|---|
| `ReplicatedStorage.Assets.Combat` | 105 | 62 | 0 | 43 |
| 38 monstres sources (`Workspace`) | 476 | 14 (feuilles et gouttes réutilisées du lot pilote) | 462 | 0 |
| `Workspace.PlotsZones` | 252 | 0 | 252 | 0 |
| `Zone1_PlaineDuRoyaume` | 0 | — | — | — |
| **Total dédupliqué** | **817** | **62** | **712** | **43** |

Par type : `cypher1359` 480 meshes + 232 images ; `nxtoma` 31 + 31 ; tiers 15 meshes, 1 image,
27 animations. Propriétés d'instance : 2 700 (cypher1359 1 899, nxtoma 371, tiers 430).
Registres : les 62 `nxtoma` sont les **nouveaux** identifiants du lot pilote
(`lot-pilote-combat.mapping.json`) ; **aucun** ancien identifiant du pilote ne reste dans les
périmètres relevés ; aucun des 712 n'appartient aux lots héros (`lot-heros-0N.json`), qui couvrent
`ServerStorage.Assets.Heros`, hors de ce relevé.

Détail par monstre source (AssetIds uniques, tous `cypher1359` sauf mention) :
ArmureGelee 8 · BecTonnerre 14 · BonhommeRoyal 8 · ChacalParchemin 8 · Chaine 18 ·
ChevalierNoye 14 · ChevalierRivete 16 · CoffreBernard 14 · ColosseEnseveli 12 · CrabeCathedrale 12 ·
CrocDeGlacier 6 · FourneauAmbulant 16 · GardienCeleste 16 · GardienSansVisage 10 · GargouilleAilee 14 ·
Givrelot 6 · GobDagueT_B 14 · GolemCloche 14 · KingSlime 11 · KingTreant 18 · Leviathan 16 ·
MaitreDesForges 18 · MammouthCristallin 16 · MangeDune 6 · Martelet 18 · MeduseCouronnee 12 ·
MiniColosseCeleste 12 · MoutonNuage 17 · MureneMiroir 12 · PoissonDuCiel 16 · RoiSansEte 16 ·
ScarabeeForgeSoleil 10 · Slime_Champignon 6 (3 nxtoma) · Slime_Lave 6 (4 nxtoma) ·
Slime_Plante 7 (5 nxtoma) · Treant_Arbre 17 (2 nxtoma) · Treant_Masque 14 · VaseDesSables 8.

Liste complète, une ligne par AssetId (type, propriétaire, statut, registre, catégorie,
emplacements) : `automation/audit/assets-collaborateur-dev.csv`.

**Autres contrôles** : les trois images que `ZONES_QA.md` signale « not authorized » dans test 3
(`74149875739571`, `99196320622532`, `136778535271316`) appartiennent à `nxtoma` : l'échec vient de
la place test 3 (propriété de `cypher1359`), pas d'un défaut de l'asset. Aucune n'est référencée
dans DEV.

## 4. Objets propres à test 3 (déclarés, non vérifiés)

Fichier : `automation/audit/objets-collaborateur-test3-dev.csv` (177 lignes : chemin attendu,
classe, PR, présence test 3 / DEV, publication, propriétaire attendu, catégorie).

### Héros et ultimes — les 12 premiers

`EffetUltime` est un attribut du modèle `Heros_<Modèle>`. Sans lui, `UltimateEffectController`
joue l'onde dorée par défaut. Aucune des valeurs ci-dessous n'est lisible : test 3 est fermée.

| N° | Héros | Ultime | PR | Modèle de combat DEV | Attaque DEV | Ultime DEV | Publié | Propriétaire |
|---|---|---|---|---|---|---|---|---|
| 01 | Écuyer du Rempart | Rempart Fermé | #104 | présent | présente (version DEV) | présente, **ancien style** | non | modèle `nxtoma`, séquences non publiées |
| 02 | Tireuse des Faubourgs | Le Dernier Carreau | #104 | absent | absente | absente | non | inconnu |
| 03 | Lancier des Champs | Haie de Lances | #105 | absent | absente | absente | non | inconnu |
| 04 | Apprenti Pyromancien | Braise Indocile | #105 | absent | absente | absente | non | inconnu |
| 05 | Brise-Pierre | Fendaille de Carrière | #105 | absent | absente | absente | non | inconnu |
| 06 | Guetteuse des Pins | Cor des Cimes | #105 | absent | absente | absente | non | inconnu |
| 07 | Chevalier du Lierre | Muraille de Lierre | #106 | absent | absente | absente | non | inconnu |
| 08 | Mage des Lanternes | La Veillée | #106 | absent | absente | absente | non | inconnu |
| 09 | Fauconnier Gris | Piqué du Fauconnier | #106 | absent | absente | absente | non | inconnu |
| 10 | Lancière des Sources | Serment de la Source | #106 | absent | absente | absente | non | inconnu |
| 11 | Barde de Fer | Accord de Fer | #106 | absent | absente | absente | non | inconnu |
| 12 | Moine du Vent Bas | Trois Pas Rasants | #106 | absent | absente | absente | non | inconnu |

Héros n° 13 à 60 : modèle de combat absent, attaque absente, pas d'ultime prévu dans ces PR.

Dépendances de chaque héros pour fonctionner comme dans test 3 : modèle
`Assets.Combat.Heros_<Modèle>` (attributs `HauteurPieds`, `EffetUltime`, `JeuAnimations`,
`JeuAnimationsCommun`, `Squelette`, `ReperesPrise`), jeu `Assets.Animations.<Modèle>`
(`Attaque`, `Ultime` avec l'attribut `Impact`), jeu commun `Squelette_Leger`. #09 dépend aussi
du faucon du modèle (copié puis masqué par l'effet).

Risques de compatibilité avec DEV : (1) si l'import n'est que partiel, `HeroConfig` pointe vers 59
modèles absents → repli sur le modèle statique (pas de crash, mais pas d'animation) ; (2) un
`Heros_EcuyerDuRempart` venu de test 3 **remplacerait** le modèle `nxtoma` du lot pilote par une
copie dont les AssetIds sont inconnus ; (3) les séquences venues de test 3 n'ont pas d'`AssetId`.

### Zones (#100)

| Objet | DEV | Reproductible depuis Git | Remarque |
|---|---|---|---|
| `ServerStorage.Assets.ZonesArene.Zone2_RoyaumeDesSables` … `Zone6_IlesDuCiel` | absents | **oui** : `tools/studio-zones-assets.luau` (procédural, aucun AssetId en dur), à partir de `Zone1_PlaineDuRoyaume` | repères `SourcesEnnemis`, `FrontEnnemi`, portique et cases des héros repris de la Zone 1 ; limites, collisions et zones de bataille générées par l'outil |
| 38 `ReplicatedStorage.Assets.Combat.Ennemi_*` | absents | **oui**, même outil, copies des 38 monstres sources présents dans DEV | les copies héritent des AssetIds `cypher1359` des sources |
| vitrine des zones au sud du Lobby | `PlotsZones` (version A) présent | **oui** : `tools/studio-zones-vitrine.luau` | nom du dossier créé à confirmer |
| Pancartes de stage | présentes | oui : `tools/studio-zone-stage-signs.luau` | — |

Éléments que Git **ne** peut **pas** reproduire : aucun pour les zones (si les sources de DEV sont
identiques à celles de test 3, **non vérifié** ; le relevé du 21/10 de `ZONES_QA.md` mentionne un
KO non bloquant « falaises basses »). Retouches manuelles éventuelles faites dans test 3 après
l'outil : inconnues.

## 5. Git — PR et `develop`

| PR | Base | Retard sur `develop` | Fusion d'essai | `rojo build` |
|---|---|---|---|---|
| #100 `feature/zones-2-6` | `1043677` | 61 commits | **sans conflit** | OK |
| #103 `feature/ultimes-brief` | `6c81a73` | 37 | sans conflit | — |
| #104 `feature/ultimes-communs` | `97a8256` | 51 | **conflit `ArenaService.lua`** | — |
| #105 `feature/ultimes-peu-communs` | `97a8256` (contient #104) | 51 | même conflit | — |
| #106 `feature/ultimes-rares` | `97a8256` (contient #104, #105) | 51 | même conflit | OK |

Conflit : `develop` (#120, `c43313a`) a ajouté `progressOf`, `objectiveOf` et un `chosenOf` à trois
valeurs juste avant `spawnModel` ; #104 ajoute le paramètre `fallbackHeroId` à `spawnModel`.
Résolution : garder les deux blocs. #100 modifie `showZone` / `startCombat` (`local zone, stage =
chosenOf(player)`) : compatible avec le `chosenOf` à trois valeurs de `develop`.
Fichiers touchés par plusieurs PR : `ArenaService.lua` (#100 et #104–#106, zones différentes du
fichier) ; `HeroConfig`, `UltimateEffectController`, `AnimationKit`, `CombatViewController`,
`HeroRules.spec`, `ANIMATION_TOOLS.md` (chaîne #104 → #106 seulement).
