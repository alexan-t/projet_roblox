# Squelette commun des héros et des monstres

Un seul squelette pour tous les personnages humanoïdes (héros, gobelins, orcs, tréants...) : une
liste d'os commune, des animations nommées d'après ces os, et une fiche par modèle qui dit « cette
pièce du modèle = tel os ». Une animation faite une fois (la marche légère, par exemple) joue alors
sur tous les modèles branchés, sans être refaite pour chacun.

| Fichier | Rôle |
| --- | --- |
| `src/shared/Animation/Skeleton.lua` | liste des os, rattachement pièce -> os, ordre des jeux d'animations (module pur, testé) |
| `src/shared/Config/SkeletonConfig.lua` | fiches des modèles (Écuyer du Rempart, Roi Orc) et jeux communs |
| `src/shared/Animation/AnimationSets.lua` | recherche des séquences d'un modèle (jeu propre puis jeu commun), utilisée par les contrôleurs client |
| `tools/animation/AnimationKit.luau` | outil Studio : pose le squelette, génère et range les animations (voir `ANIMATION_TOOLS.md`) |
| `tools/test-skeleton.ps1` | tests du module pur avec les vraies fiches, et d'`AnimationSets` avec des doubles d'Instance |

## Pourquoi

Une `KeyframeSequence` Roblox anime une articulation d'après le **nom de ses pièces** : la `Pose`
`left_arm_geom` sous la `Pose` `torso_geom` anime le `Motor6D` qui relie ces deux pièces. Avec
l'ancien squelette, les articulations reliaient directement les pièces du modèle : chaque animation
ne valait que pour les modèles qui avaient exactement les mêmes noms de pièces (le Roi Orc, dont la
tête s'appelle `body_geom`, avait besoin de ses propres séquences). En production, chaque séquence
doit en plus être publiée (attribut `AssetId`) : une par modèle et par animation.

Avec le squelette commun, les articulations relient des **os invisibles aux noms communs**. Les
pièces visibles sont seulement accrochées aux os. Les `Pose` portent les noms des os : la même
séquence, publiée une seule fois, joue sur tous les modèles qui ont ce squelette.

## Les os

| Os | Parent | Articulation (`Motor6D`) | Clé de pose AnimationKit | Pièce obligatoire |
| --- | --- | --- | --- | --- |
| `Buste` | `HumanoidRootPart` | `Racine` | `torso` | oui |
| `Tete` | `Buste` | `Cou` | `head` | oui |
| `BrasGauche` | `Buste` | `EpauleGauche` | `leftArm` | oui |
| `BrasDroit` | `Buste` | `EpauleDroite` | `rightArm` | oui |
| `JambeGauche` | `Buste` | `HancheGauche` | `leftLeg` | oui |
| `JambeDroite` | `Buste` | `HancheDroite` | `rightLeg` | oui |
| `ArmeGauche` | `BrasGauche` | `MainGauche` | `weaponLeft` | non (os créé même vide) |
| `ArmeDroite` | `BrasDroit` | `MainDroite` | `weaponRight` | non (os créé même vide) |

Les noms d'articulation sont ceux de l'ancien squelette : rien ne change pour le code qui les lit.
Les styles d'AnimationKit (`Kit.Profiles`, `Kit.Attacks`) acceptent la clé de pose (`torso`) ou le
nom de l'os (`Buste`).

Un modèle branché (après `Kit.rig`) ressemble à ceci :

```
EcuyerDuRempart            attributs : Squelette = "Humanoide", JeuAnimations, JeuAnimationsCommun...
├─ HumanoidRootPart        invisible, seule pièce ancrée (PrimaryPart)
├─ Os                      dossier des os invisibles (0,2 stud, sans masse, sans collision)
│  ├─ Buste                Motor6D « Racine » depuis HumanoidRootPart
│  ├─ Tete                 Motor6D « Cou » depuis Buste
│  ├─ BrasDroit            Motor6D « EpauleDroite » depuis Buste
│  ├─ ArmeDroite           Motor6D « MainDroite » depuis BrasDroit (pivot dans la main)
│  └─ ...
├─ torso_geom              attributs Os = "Buste", OsAncre = true ; Motor6D « Fixe_torso » depuis l'os
├─ weapon_geom             attribut Os = "ArmeDroite" ; Motor6D « Tenu_weapon » depuis l'os
├─ AnimationController
│  └─ Animator
└─ ...
```

Les pivots sont calculés comme avant (épaule près du bord intérieur du bras, hanche en haut de la
jambe, cou en bas de la tête, main en bas du bras), à partir de la **pièce qui donne la forme** de
chaque membre (`OsAncre`).

## Dire « cette pièce = tel os »

Chaque pièce visible du modèle est accrochée à un os. Trois façons de le dire, de la plus forte à la
plus faible :

1. **La fiche du modèle** dans `src/shared/Config/SkeletonConfig.lua` (Git, relue en PR) :
   - `Membres = { Tete = "body_geom" }` : la pièce qui donne la forme d'un membre, quand son nom
     sort du format IA ;
   - `Pieces = { weapon_geom = "ArmeDroite", Banniere = "Buste" }` : l'os d'une pièce (toutes les
     pièces de ce nom).
2. **L'attribut texte `Os`** posé sur la pièce dans Studio (ex. `Os = "ArmeGauche"`). Pratique pour
   une pièce au nom générique (`Part`, `MeshPart`) ou en double.
3. **La détection par le nom** (format IA) : `torso_geom` / `body_geom` / `chest_geom` -> `Buste`,
   `head_geom` / `mask_head_geom` / `skull_geom` -> `Tete`, `left_arm_geom` -> `BrasGauche`... Une
   pièce dont le nom évoque un objet tenu (`weapon`, `sword`, `buckler`, `staff`, `hache`,
   `etendard`...) va dans la main la plus proche ; tout le reste est porté par le buste (cape,
   ceinture, cor...).

Valeurs acceptées comme os : les noms du tableau ci-dessus, leurs clés de pose (`torso`,
`rightArm`...), `MainProche` (main la plus proche : `ArmeGauche` ou `ArmeDroite`), `BrasProche`
(bras le plus proche : épaulières, pics, crânes d'épaule), et les anciennes valeurs de `Held`
(`left`, `right`, `nearest`, `torso`).

`Kit.rig` écrit le résultat dans les attributs `Os` (et `OsAncre`) de chaque pièce : un nouveau rig
du même modèle (après `Kit.unrig`) retrouve le même branchement, et le code de jeu peut demander les
pièces d'un os (`AnimationSets.pieces(model, "ArmeDroite")`). Une valeur inconnue dans une fiche ou
un attribut est signalée en avertissement `[AnimationKit]` et ignorée ; un membre obligatoire sans
pièce arrête le rig avec le nom du membre.

## Animations liées au squelette

Les animations restent des `KeyframeSequence` rangées dans `ReplicatedStorage.Assets.Animations`,
en **jeux** (dossiers). Deux sortes de jeux :

| Jeu | Exemple | Contenu | Attribut du modèle |
| --- | --- | --- | --- |
| propre au modèle | `EcuyerDuRempart`, `RoiOrc` | ce qui lui est propre : attaque, ultime | `JeuAnimations` (et `JeuAnimationsCombat` pendant un aperçu) |
| commun (squelette) | `Squelette_Leger`, `Squelette_Lourd` | ce qui se partage : marche (attente, plus tard) | `JeuAnimationsCommun` |

Recherche d'une animation (`AnimationSets`, ordre de `Skeleton.animationSets`) : le jeu propre
d'abord, puis le jeu commun. Le jeu commun n'est lu que si le modèle a l'attribut
`Squelette = "Humanoide"` (posé par `Kit.rig`) : sur un modèle de l'ancien squelette, ses `Pose`
ne trouveraient aucune articulation. Un jeu d'aperçu d'atelier (`Apercu_<Set>`, attribut
`Apercu = true`) se suffit à lui-même et n'est jamais lu en combat.

Code de jeu qui en dépend : `MonsterAnimationController` (toutes les animations), `CombatViewController`
(un modèle est animé s'il déclare un jeu), `AttackEffectController` (séquence « Attaque » et instant
d'impact ; arme = pièces de l'os `ArmeDroite`, sinon `ArmeGauche`), `UltimateEffectController`
(séquence « Ultime » ; départ de la lame depuis l'os `ArmeDroite`). Les modèles de l'ancien
squelette gardent exactement le comportement précédent.

Les jeux communs connus sont listés dans `SkeletonConfig.SharedSets` (un par démarche : la marche ne
dépend que du profil, pas du modèle). Les rotations d'une animation sont en degrés autour des os :
elles valent pour tous les gabarits. Les petites translations (rebond du buste, en studs) sont les
mêmes pour un héros et un boss : garder des profils séparés (léger / lourd) pour les gabarits très
différents.

## Brancher un nouveau héros ou monstre

Studio en mode **Edit**, place synchronisée par Rojo (`rojo serve`) : AnimationKit lit `Skeleton`,
`AnimationSets` et `SkeletonConfig` dans `ReplicatedStorage.Shared`. Toujours travailler sur une
copie dans `Workspace.AtelierAnimation` (`Kit.prepare` la crée), jamais sur le modèle du Bestiaire.

1. **Inspecter le modèle** dans Studio (MCP ou Explorer) : noms des pièces, pièce de la tête, du
   buste, des bras et des jambes, objets tenus. Le format IA (`<membre>_geom`) se branche souvent
   sans fiche. Un modèle sans bras ni jambes séparés (slime, créature non humanoïde) ne rentre pas
   dans ce squelette : voir « Limites ».
2. **Voir ce que donnerait le branchement**, sans rien modifier :

   ```lua
   _G.AnimationKit.inspect(workspace.Bestiaire.Heros.Socle_03.LancierDesChamps)
   ```

   La sortie liste chaque pièce et son os (`lance_geom -> MainProche`, `torso_geom -> Buste (forme
   du membre)`...). Un membre sans pièce arrête l'inspection avec son nom.
3. **Corriger** ce qui est faux : dans une fiche `SkeletonConfig.Models.<Set>` (branche `feature/*`,
   PR vers `develop`, la place se met à jour par Rojo), ou par l'attribut `Os` sur la pièce dans
   Studio (asset, pas de script). Relancer `inspect` jusqu'à ce que tout soit juste.

   ```lua
   LancierDesChamps = table.freeze({
   	Pieces = table.freeze({ lance_geom = "ArmeDroite", carquois_geom = "Buste" }),
   	Commun = "Squelette_Leger", -- marche partagée avec l'Écuyer
   	Profil = "Leger",
   	Attaque = "Epee",           -- ou un nouveau style dans Kit.Attacks
   }),
   ```

4. **Préparer** : copie, squelette, marche (rangée dans le jeu commun), attaque et ultime (rangés
   dans le jeu propre), aperçu près du spawn. Tout est une seule étape d'annulation (Ctrl+Z).

   ```lua
   _G.AnimationKit.prepare({
   	Source = workspace.Bestiaire.Heros.Socle_03.LancierDesChamps,
   	Set = "LancierDesChamps", -- fiche SkeletonConfig.Models.LancierDesChamps, jeu propre
   })
   ```

   Si le jeu commun a déjà une marche, `prepare` la remplace par une séquence identique (même profil).
   Pour un modèle qui ne doit **pas** partager sa marche : `Shared = false`.
5. **Lire la sortie** `[AnimationKit]` (pièces hors membres et leur os, avertissements), puis Play :
   le modèle marche en boucle devant le `SpawnLocation`.
6. **Vérifier** : capture d'écran réelle et `docs/VISUAL_QA.md` (PASS ou FIX), puis réinitialiser
   la caméra de Studio (`docs/MONSTER_PRODUCTION.md`, § Outils).
7. **Utiliser en combat** : copier le modèle articulé dans `ReplicatedStorage.Assets.Combat` (monstre,
   voir `ArenaConfig.EnemyTemplates`) ou le désigner comme `CombatTemplate` (héros, `HeroConfig`),
   avec `JeuAnimations` = son jeu propre et `JeuAnimationsCommun` = le jeu commun.
8. **Production** : publier chaque séquence (une seule fois pour une séquence du jeu commun) par le
   propriétaire de l'expérience, puis mettre son identifiant dans l'attribut `AssetId` de la séquence.

Un nouveau monstre qui ressemble à un modèle déjà branché réutilise ses animations : même jeu commun
(`JeuAnimationsCommun`), et même jeu propre si l'attaque convient (`JeuAnimations`).

## Exemples : Écuyer du Rempart et Roi Orc

Les deux fiches sont dans `SkeletonConfig.Models`.

| Modèle | Fiche | Jeu commun | Jeu propre |
| --- | --- | --- | --- |
| Écuyer du Rempart (héros) | `weapon_geom -> ArmeDroite`, `buckler_geom -> ArmeGauche` ; reste au format IA | `Squelette_Leger` (Marche, profil `Leger`) | `EcuyerDuRempart` : Attaque (`Epee`), Ultime (`Rempart`) |
| Roi Orc (boss) | `Membres.Tete = body_geom` ; `Banniere -> Buste` ; `PicEpaule`, `Crane_5`, `Crane_6 -> BrasProche` ; couvercles de bras `(76, 111, 41)` | `Squelette_Lourd` (Marche, profil `Lourd`) | `RoiOrc` : Attaque (`Fendoir`, anime aussi `ArmeDroite`) |

```lua
-- Écuyer du Rempart
_G.AnimationKit.prepare({ Source = workspace.Bestiaire.Heros.Socle_01.EcuyerDuRempart, Set = "EcuyerDuRempart" })
-- Roi Orc : son arme est détectée par son nom (main la plus proche)
_G.AnimationKit.prepare({ Source = workspace.RoiOrc, Name = "RoiOrc", Set = "RoiOrc" })
```

Les noms `weapon_geom` / `buckler_geom` de l'Écuyer viennent des relevés du Bestiaire : si l'un
d'eux n'existe pas sur le modèle, `inspect` l'annonce (« Pieces : pièce introuvable ») et la
détection par le nom prend le relais. Corriger la fiche dans ce cas.

## Passer un modèle existant au squelette commun

Les modèles articulés de la DEV (`Workspace.AtelierAnimation` : Écuyer, Tréant masqué, Roi Orc ;
`ReplicatedStorage.Assets.Combat` : `Heros_EcuyerDuRempart`, `Ennemi_RoiOrc`, `Ennemi_Gobelin`)
utilisent encore l'ancien squelette et des séquences nommées d'après leurs pièces. Ils continuent de
jouer comme avant. Pour en passer un au squelette commun :

1. Sur la copie de l'atelier : `Kit.unrig(m)`, puis `Kit.rig(m, { Map = "RoiOrc" })` (et
   `Kit.closeArms` si la fiche a `CouvercleBras`) ; ou supprimer la copie et relancer `prepare`.
2. Régénérer ses séquences (`Kit.walk`, `Kit.attack`, `Kit.ultimate`) : les anciennes ne
   correspondent plus aux articulations. `prepare` le fait.
3. Remplacer le modèle de combat (`Assets.Combat`) par la nouvelle copie articulée, avec ses
   attributs `Squelette`, `JeuAnimations`, `JeuAnimationsCommun`.
4. Contrôle visuel (VISUAL_QA) au Play et en combat.

Ces étapes se font dans Studio (assets) : elles ne sont pas faites par la PR qui ajoute le squelette.

## Tests

```powershell
./tools/test-skeleton.ps1 -LuauPath <chemin-vers-luau.exe>
```

Ils vérifient la liste des os (noms uniques, parents avant enfants, anciens noms d'articulation), le
rattachement (priorité fiche > attribut `Os` > nom, `OsAncre` d'un rig précédent, membres manquants,
avertissements), les fiches de l'Écuyer et du Roi Orc, et l'ordre des jeux d'animations.

## Limites

- Un seul squelette pour l'instant (`Humanoide`) : une pièce par membre, pas de genou ni de coude.
  Une créature sans membres séparés (slime) ou à pattes / ailes / queue demandera un autre squelette
  (autre `Skeleton.Name` et autre liste d'os) : le format est prévu pour, pas encore écrit.
- Les os des armes existent même sans arme : une animation qui les anime ne fait alors rien de
  visible.
- Les translations des animations (rebond, en studs) ne s'adaptent pas à la taille du modèle.
- Un jeu commun ne sert qu'aux modèles au squelette commun (`Squelette = "Humanoide"`).
