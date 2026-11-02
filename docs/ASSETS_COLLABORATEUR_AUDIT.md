# Audit des assets du collaborateur — synthèse et verdict

Audit **en lecture seule** du 02/11/2026. Rien n'a été publié, republié, remplacé, importé,
supprimé ni modifié dans Studio ou sur Roblox. Aucun secret n'a été utilisé ni affiché.

Détail : [`ASSETS_COLLABORATEUR_INVENTAIRE.md`](ASSETS_COLLABORATEUR_INVENTAIRE.md) (comparaison),
[`ASSETS_COLLABORATEUR_INTEGRATION.md`](ASSETS_COLLABORATEUR_INTEGRATION.md) (plan, sans exécution).
Données : `automation/audit/assets-collaborateur-dev.csv` (817 AssetIds uniques) et
`automation/audit/objets-collaborateur-test3-dev.csv` (177 objets attendus).

## Verdict : **FIX**

Le code des PR peut être intégré, après la résolution d'un conflit simple. En revanche, les assets
Studio dont ce code dépend ne sont **ni vérifiables ni intégrables** en l'état :

1. La place « test 3 » n'a pas pu être inventoriée (voir § Périmètre) : **aucun objet propre à
   test 3 n'est vérifié**. Les chiffres « test 3 » ci-dessous sont **déclarés par les PR**.
2. Tous les modèles du collaborateur relevés dans DEV sont publiés sous son compte personnel
   **`cypher1359`** (712 AssetIds uniques) : règle `ASSET_OWNERSHIP.md` § 2.2 → FIX.
3. Les animations du collaborateur (60 attaques, 12 ultimes) sont des `KeyframeSequence`
   **non publiées** : hors de Studio, `MonsterAnimationController` ne les joue pas (pas
   d'`AssetId`, `RegisterKeyframeSequence` réservé à Studio). Les effets d'ultime, eux, sont du
   code et jouent partout.

Pas de NO-GO : aucun blocage technique majeur, tout est réversible, et le comportement de repli
(#104 : vrai modèle du héros si le modèle de combat manque) évite les cases vides.

## Périmètre et accès

| Élément | Résultat |
|---|---|
| Place DEV « Projet Roblox - Alpha » | placeId `78875801703886`, universe `10767916745`, `CreatorType = User`, `CreatorId = 11714751172` (`nxtoma`) — **ouverte dans Studio, inventoriée** |
| Place « test 3 » | placeId `120616399792561` (`docs/ZONES_QA.md`, `HEROES_QA.md`) ; `GetProductInfo` : propriétaire **`cypher1359`** (User), type Place — **non ouverte dans Studio**, donc **non inventoriée** |
| Snapshot Git de test 3 | `studio/sandbox/partner_sandbox_v4.rbxl` du **09/10/2026**, antérieur aux PR #100 (21/10) et #104–#106 (23/10) : inutilisable pour ces PR |
| Collaborateur | GitHub `AIpromoter` (auteur des PR), commits signés « Atelier du pouf », compte Roblox `cypher1359` (nommé dans `ASSET_OWNERSHIP.md`). Le lien GitHub ↔ Roblox est **déduit des docs, non vérifié** |
| Modération | **NON VÉRIFIÉE** : `GetProductInfo` ne la donne pas ; aucune clé Open Cloud n'a été utilisée |

## Chiffres demandés

Les trois unités ne sont pas interchangeables : **objet** (modèle, dossier, séquence), **AssetId
unique**, **propriété d'instance** (une même texture posée sur 10 pièces = 1 AssetId, 10 propriétés).

| # | Indicateur | Valeur | Source |
|---|---|---|---|
| 1 | Modèles nouveaux | **102 déclarés, 0 vérifié dans test 3** : 59 `Heros_<Modèle>` (#104), 38 `Ennemi_*` (outil de #100 et de `develop`), 5 décors `ZonesArene` (#100) | PR, outils Git |
| 2 | Animations nouvelles | **70 `KeyframeSequence` nouvelles déclarées (+2 refaites pour l'Écuyer), 0 publiée** : 59 attaques, 11 ultimes ; Écuyer : attaque refaite, ultime « Rempart » remplacé par « Rempart Fermé » | PR #104–#106 |
| 3 | Assets publiés vérifiés | **817 AssetIds uniques** (2 700 propriétés d'instance), propriétaire lu par `GetProductInfo`, 0 erreur | DEV |
| 4 | Appartenant à `nxtoma` | **62** (= les 62 du lot pilote, 100 % dans `lot-pilote-combat.mapping.json`) | DEV |
| 5 | Appartenant au collaborateur (`cypher1359`) | **712** (480 meshes, 232 images) | DEV |
| 6 | Appartenant à des tiers | **43** : 27 animations `Roblox`, 14 meshes `RBLXImagineer`, 1 image `AvLab` (groupe), 1 mesh `tombluedog84` — tous dans les mannequins R15 provisoires | DEV |
| 7 | Propriété inconnue | **0** sur les 817 vérifiés ; **tous** les assets des objets propres à test 3 sont **NON VÉRIFIÉS** (hypothèse : les 59 `Heros_<Modèle>` reprennent les 1 042 AssetIds `cypher1359` déjà listés dans `lot-heros-0N.json`) | — |
| 8 | Présents dans test 3, absents de DEV | **≥ 173 objets déclarés** : 59 modèles de héros, 38 `Ennemi_*`, 5 décors, 59 attaques, 11 ultimes, la vitrine des zones | PR |
| 9 | Déjà intégrés dans DEV | `Heros_EcuyerDuRempart` + ses séquences `Attaque` / `Ultime` (ancien style), 38 monstres sources dans `Workspace`, `Workspace.PlotsZones` (5 plots, 252 AssetIds `cypher1359`), décor `Zone1_PlaineDuRoyaume`, 60 héros de `ServerStorage.Assets.Heros`, jeu `Squelette_Leger` (Marche seule) | DEV |
| 10 | Dépendances et blocages | ci-dessous | — |

## Ce que le collaborateur a réellement ajouté

**Dans Git (vérifié)** — aucune PR n'ajoute d'AssetId (0 identifiant dans les diffs).

| PR | Contenu Git | Dépend de Studio |
|---|---|---|
| #100 Zones 2 à 6, Royaume des Sables | `ArenaConfig`, `StageConfig`, `CombatConfig`, `EnemyPresentationConfig`, `BossGate`, `DecorVivantController`, `ArenaService` (+ `StageDecor`), outils `studio-zones-assets.luau` (+2 499 lignes), `studio-zones-vitrine.luau`, 51 captures | `ZonesArene.Zone2..6`, 30 `Ennemi_*` nouveaux — **reproductibles depuis Git** |
| #103 Brief des ultimes | 3 fichiers de documentation | rien |
| #104 Attaques de base, héros en combat, ultimes Communs | `HeroConfig` (`CombatTemplate` des 59), `ArenaService` (repli), `UltimateEffectController`, `AnimationKit` | 59 `Heros_<Modèle>`, séquences, `EffetUltime` — **uniquement dans test 3** |
| #105 Ultimes Peu communs | + 4 effets | 4 séquences `Ultime` + `EffetUltime` — **uniquement dans test 3** |
| #106 Ultimes Rares | + 6 effets | 6 séquences `Ultime` + `EffetUltime` — **uniquement dans test 3** |

Contributions déjà fusionnées (`AIpromoter`) : #76, #83, #84, #85, #89 (icônes, republiées par #90),
#94 (plots agrandis), #95, #97 (zones, version A), #98 (héros), #101 (niveaux du royaume),
#102 (prises des armes). Elles ont laissé dans DEV les monstres sources des zones 2 à 6 et
`PlotsZones`, tous en `cypher1359`.

## Dépendances et blocages

| # | Blocage | Gravité | Catégorie |
|---|---|---|---|
| B1 | test 3 non ouverte dans Studio : inventaire réel impossible | bloquant pour l'intégration Studio | D |
| B2 | 712 AssetIds `cypher1359` dans DEV (monstres des zones 2 à 6, Treant, KingSlime, KingTreant, `PlotsZones`) | FIX propriété | C |
| B3 | 72 séquences non publiées (70 nouvelles, 2 refaites) : animations absentes hors de Studio | FIX avant toute publication du jeu | C/D |
| B4 | Conflit `ArenaService.lua` entre #104/#105/#106 et `develop` (#120 a ajouté `progressOf` / `objectiveOf` / `chosenOf` à l'endroit où #104 change la signature de `spawnModel`) | simple, à résoudre à la main | — |
| B5 | `develop` attend déjà 8 `Ennemi_*` (SlimePlante… KingTreant) **absents de DEV**, et DEV n'a pas `ServerStorage.Assets.ZonesArene` : les zones 2+ n'ont ni décor ni ennemis dans DEV, avant même #100 | écart existant | B |
| B6 | #105 dépend de #104, #106 de #105 : chaque branche contient les commits précédents | ordre imposé | — |
| B7 | 43 assets tiers dans les mannequins R15 (`Heros_<Classe>`, `Mannequin*`) ; après #104, plus aucun héros ne les utilise | à retirer ou à garder hors jeu | D |
| B8 | Registre de réutilisation et retour arrière (`published-registry.json`, `lot-pilote-combat.rollback.json`) seulement dans la PR #110, pas dans `develop` | prérequis des lots | — |
| B9 | Tests Luau non rejoués ici (pas de CLI `luau` installée) ; `rojo build` des branches #100 et #106 : OK | à rejouer | — |

## En résumé

- **Ajouté par le collaborateur** : le code des zones 2 à 6 et des 12 premiers ultimes (Git,
  propre, sans AssetId), et dans **sa** place test 3 : 59 héros articulés, 72 animations, les
  décors des zones 2 à 6.
- **Manque dans DEV** : les 59 modèles de combat, toutes les animations sauf celles de l'Écuyer,
  les 38 `Ennemi_*` et les 5 décors de zone. Les décors et les `Ennemi_*` se reconstruisent depuis
  Git. Les héros et les animations doivent venir de test 3.
- **Appartient déjà à `nxtoma`** : les 62 assets du lot pilote (Écuyer, Gobelin, Slime, Roi Orc),
  réutilisables tels quels.
- **À régulariser** : 712 assets `cypher1359` déjà dans DEV, les ~1 042 assets des héros (lots
  préparés par #110), toutes les animations (publication sous `nxtoma`), et les 43 assets tiers
  des mannequins (décision : retirer ou garder).
