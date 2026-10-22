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
├─ short_sword_geom        attribut Os = "ArmeDroite" ; Motor6D « Tenu_short_sword » depuis l'os
├─ AnimationController
│  └─ Animator
└─ ...
```

Les pivots sont calculés comme avant (épaule près du bord intérieur du bras, hanche en haut de la
jambe, cou en bas de la tête, main en bas du bras), à partir de la **pièce qui donne la forme** de
chaque membre (`OsAncre`).

## Dire « cette pièce = tel os »

Chaque pièce visible du modèle est accrochée à un os. Quatre façons de le dire, de la plus forte à la
plus faible :

1. **La fiche du modèle** dans `src/shared/Config/SkeletonConfig.lua` (Git, relue en PR) :
   - `Membres = { Tete = "body_geom" }` : la pièce qui donne la forme d'un membre, quand son nom
     sort du format IA ;
   - `Pieces = { short_sword_geom = "ArmeDroite", Banniere = "Buste" }` : l'os d'une pièce (toutes les
     pièces de ce nom).
2. **L'attribut texte `Os`** posé sur la pièce dans Studio (ex. `Os = "ArmeGauche"`). Pratique pour
   une pièce au nom générique (`Part`, `MeshPart`) ou en double.
3. **Le groupe** : une pièce rangée dans un sous-modèle suit ce que dit le nom du sous-modèle
   (`cristal_luciole` dans `baton_fleur` suit le bâton ; `Lame_1` dans `halo_lames` reste au buste).
4. **La détection par le nom** (format IA) : `torso_geom` / `body_geom` / `chest_geom` -> `Buste`,
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

## Prise : l'arme toujours dans la main

Le Brise-Pierre (#05) tenait son marteau par le talon posé sur le poing, alors que la mesure
« l'arme touche le bras » passait. Deux repères règlent la question une fois pour toutes, par modèle.

| Attachment | Posé sur | Position | Axes |
| --- | --- | --- | --- |
| `Poing` | la pièce du bras (ou son poing séparé, #43) | centre du poing fermé | X = sens du manche vers la tête de l'arme, Y = côté du tranchant |
| `Prise` | l'objet tenu (pièce principale de la main) | point du manche que serre le poing | mêmes axes que le Poing |

- **`Kit.rig`** recolle chaque objet tenu à son Poing (la Prise vient sur le Poing, les décors de
  l'arme suivent) et met le **pivot de l'os** `ArmeGauche` / `ArmeDroite` **au centre du Poing**.
  Pendant une animation, l'arme ne peut pas quitter la main ; une rotation `weaponRight` /
  `weaponLeft` la fait tourner autour du poing. Vérifié sur le #05 riggé : épaule levée de 110°, arme
  tournée de 50°, écart Prise / Poing 0,000 stud.
- **Une arme changée** (nouvel équipement) n'a besoin que de sa Prise : elle prend sa place au Poing.
- Constantes et règles dans `Skeleton.Grip` et `Skeleton.gripProblems` (module pur, testé) :
  écart Prise / Poing ≤ 0,05 stud, axes à moins de 5°, Poing à moins de 0,35 stud du centre du poing
  mesuré, manche présent à 0,25 stud de part et d'autre du Poing (« il traverse le poing »).
- `PriseLibre` (attribut de la Prise) : objet sans manche qui traverse le poing (bouclier, cartes,
  lanterne par l'anse, cloche par sa couronne, livre ; mots de `Skeleton.Grip.FreeWords`). Seul le
  test « traverse » est sauté.
- `PriseControlee` (attribut de la Prise) : prise validée en capture quand une mesure approximative
  se trompe (bout de manche recourbé caché dans le gant). Le centre du poing et le test « traverse »
  sont sautés ; l'écart Prise / Poing reste contrôlé.
- **Limite des mesures : elles ne voient pas le trou du poing.** Rayons et `GetPartsInPart` touchent
  l'enveloppe de collision des MeshParts (`CollisionFidelity` Default), qui bouche le creux du poing :
  un manche qui passe dans le gant, sous le poing ou à côté passe le contrôle (#04, #24, #40, #42, #50
  le 22/10/2026). Aucune mesure automatique essayée (angle manche / avant-bras, axe ou tunnel du
  poing sur les sommets réels) ne séparait les bonnes prises des mauvaises. Le contrôle reste donc
  la **capture de la main, arme masquée puis arme visible** (`ANIMATION_TOOLS.md` § Prise des armes).

Outils (`tools/animation/AnimationKit.luau`, mode Edit, modèle dans le Workspace) :

| Fonction | Rôle |
| --- | --- |
| `Kit.grip(model)` | pose Prise et Poing d'après la prise actuelle : centre du poing mesuré (volume du bout du bras), axe de l'arme mesuré sur sa surface, manche recentré dans le poing jusqu'à 0,9 stud ; au-delà, rien ne bouge et le compte rendu dit « À VÉRIFIER EN CAPTURE » |
| `Kit.checkGrips(model)` | défauts de prise (liste vide = PASS) |
| `Kit.aim(model, main, direction, côté?, glisse?)` | réoriente l'arme autour du Poing (et le Poing avec) ; `glisse` déplace la prise le long du manche |
| `Kit.showGrips(model)` / `Kit.hideGrips(model)` | repères visibles pour la capture : tige verte = axe, boule rouge = Poing, boule violette = centre du poing mesuré |

Le contrôle `tools/studio-check-heroes.luau` (section 5) refait ces mesures sur les 62 héros du
Bestiaire et les 22 copies de jeu : un objet tenu sans Prise, un bras sans Poing ou une arme déplacée
après coup donne un problème.

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
`Apercu = true`) se suffit à lui-même et n'est jamais lu en combat : `MonsterAnimationController.Play`
(appelé par le combat) lit toujours en mode combat (`JeuAnimationsCombat`, jeu propre, jeu commun,
aperçus ignorés) ; seule la démonstration d'atelier (tag `ApercuAnimation`) lit l'aperçu.

### Priorité propre / commun et migration

La priorité reste **jeu propre, puis jeu commun** : une animation propre voulue (Attaque, Ultime, ou
plus tard une Marche unique pour un modèle précis) l'emporte toujours. Conséquence : quand une
animation devient commune, l'ancienne version du même nom doit **sortir** du jeu propre, sinon elle
masque la commune (défaut connu de la PR #56 : après migration, l'ancienne Marche, aux `Pose` de
l'ancien squelette, passait avant la Marche commune).

C'est la migration qui s'en charge, pas le runtime : `Kit.share` (appelé par `Kit.prepare` pour la
marche) appelle `AnimationSets.unshadow(model, nom, archive)`, qui déplace la séquence de ce nom des
jeux propres du modèle (`JeuAnimationsCombat`, `JeuAnimations`, jamais un aperçu) vers
`ServerStorage.AnimationKitArchive`, renommée `<Jeu>_<nom>`. Elle n'agit que si le modèle a le
squelette commun **et** si son jeu commun contient ce nom ; une réexécution ne fait rien. Une
séquence remplacée par `Kit.install` / `Kit.share` (régénération) y est aussi rangée au lieu d'être
détruite. Le dossier d'archive est dans `ServerStorage` : jamais lu par le jeu, jamais répliqué.

Le jeu propre est partagé par tous les modèles qui le déclarent : migrer un modèle retire sa Marche
pour tous. Remplacer donc aussi leur asset de combat par la version migrée (voir plus bas).

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

   Si le jeu commun a déjà une marche, `prepare` la remplace par une séquence identique (même profil ;
   l'ancienne va dans l'archive). L'ancienne Marche du jeu propre part aussi dans l'archive (voir
   « Priorité propre / commun »). Pour un modèle qui ne doit **pas** partager sa marche :
   `Shared = false` (sa Marche reste alors dans son jeu propre, prioritaire).
   `Arrange = false` : ne pas ranger tout l'atelier (placer la copie à la main).
5. **Lire la sortie** `[AnimationKit]` (pièces hors membres et leur os, avertissements), puis Play :
   le modèle marche en boucle devant le `SpawnLocation`.
6. **Vérifier** : capture d'écran réelle et `docs/VISUAL_QA.md` (PASS ou FIX), puis réinitialiser
   la caméra de Studio (`docs/MONSTER_PRODUCTION.md`, § Outils).
7. **Utiliser en combat** : copier le modèle articulé dans `ReplicatedStorage.Assets.Combat` (monstre,
   voir `ArenaConfig.EnemyTemplates`) ou le désigner comme `CombatTemplate` (héros, `HeroConfig`),
   avec `JeuAnimations` = son jeu propre, `JeuAnimationsCommun` = le jeu commun et
   `Squelette = "Humanoide"` ; retirer de la copie ce qui sert à l'aperçu (tag `ApercuAnimation`,
   `ApercuPause`, `JeuAnimationsCombat`, lien `AnimSaves`). Ranger l'ancien asset dans
   `ServerStorage.AnimationKitArchive` plutôt que le détruire. Tester un vrai combat (Marche, Attaque,
   Ultime, effets, x1 / x2, mort).
8. **Production** : publier chaque séquence (une seule fois pour une séquence du jeu commun) par le
   propriétaire de l'expérience, puis mettre son identifiant dans l'attribut `AssetId` de la séquence.
   Ne jamais inventer d'`AssetId`. Les jeux `Apercu_*` ne se publient pas.

Un nouveau monstre qui ressemble à un modèle déjà branché réutilise ses animations : même jeu commun
(`JeuAnimationsCommun`), et même jeu propre si l'attaque convient (`JeuAnimations`).

## Exemples : Écuyer du Rempart et Roi Orc

Les deux fiches sont dans `SkeletonConfig.Models`.

| Modèle | Fiche | Jeu commun | Jeu propre |
| --- | --- | --- | --- |
| Écuyer du Rempart (héros) | `short_sword_geom -> ArmeDroite`, `shield_geom -> ArmeGauche` ; `cor_geom` (cor) au buste ; reste au format IA | `Squelette_Leger` (Marche, profil `Leger`) | `EcuyerDuRempart` : Attaque (`Epee`), Ultime (`Rempart`) |
| Roi Orc (boss) | `Membres.Tete = body_geom` ; `Banniere -> Buste` ; `PicEpaule`, `Crane_5`, `Crane_6 -> BrasProche` ; `LanceHache`, `Bouclier` -> main la plus proche (par le nom) ; couvercles de bras `(76, 111, 41)` | `Squelette_Lourd` (Marche, profil `Lourd`) | `RoiOrc` : Attaque (`Fendoir`, anime aussi `ArmeDroite`) |

Pièces relevées dans Studio : la fiche #56 d'origine nommait `weapon_geom` / `buckler_geom`, qui
n'existent pas sur l'Écuyer réel. La place DEV n'a **pas** de Roi Orc dans le Bestiaire (socles de
boss vides) : sa source de migration est une copie de `Assets.Combat.Ennemi_RoiOrc`, désarticulée
hors de la place.

```lua
-- Écuyer du Rempart
_G.AnimationKit.prepare({ Source = workspace.Bestiaire.Heros.Socle_01.EcuyerDuRempart,
	Set = "EcuyerDuRempart", Name = "EcuyerDuRempart_Squelette", Arrange = false })
-- Roi Orc : copie de l'asset de combat, désarticulée hors de la place (l'asset n'est pas touché)
local source = game.ReplicatedStorage.Assets.Combat.Ennemi_RoiOrc:Clone()
_G.AnimationKit.unrig(source)
source.Name = "RoiOrc"
_G.AnimationKit.prepare({ Source = source, Set = "RoiOrc", Name = "RoiOrc_Squelette", Arrange = false })
source:Destroy()
```

## Passer un modèle existant au squelette commun

Migration pilote faite dans la DEV (assets Studio, voir la PR « squelette partagé humanoïde ») :

| Modèle | Avant | Après |
| --- | --- | --- |
| `Assets.Combat.Heros_EcuyerDuRempart` | ancien squelette, `EcuyerDuRempart` : Marche, Attaque, Ultime | squelette commun ; Marche de `Squelette_Leger` ; Attaque, Ultime dans `EcuyerDuRempart` |
| `Assets.Combat.Ennemi_RoiOrc` | ancien squelette, `RoiOrc` : Marche, Attaque | squelette commun ; Marche de `Squelette_Lourd` ; Attaque (Fendoir) dans `RoiOrc` ; `EffetAttaque = Seisme` gardé |
| `Assets.Combat.Ennemi_Gobelin` | ancien squelette, `Gobelin` (5 séquences) | **inchangé** (ancien squelette, coexiste en combat) |
| `AtelierAnimation.Treant_Masque` | ancien squelette, `TreantMasque` | inchangé |

Les anciens assets de combat et les anciennes séquences sont dans `ServerStorage.AnimationKitArchive`
(`*_AncienRig`, `<Jeu>_<nom>`). Les anciennes copies d'atelier `EcuyerDuRempart` et `RoiOrc`
(ancien squelette) ne sont plus utilisables : leurs jeux contiennent désormais des séquences aux
`Pose` du squelette commun.

Pour un autre modèle :

1. Sur une copie : `Kit.unrig(m)` puis `Kit.prepare` (ou `Kit.rig(m, { Map = ... })`, `Kit.closeArms`
   si la fiche a `CouvercleBras`). `prepare` régénère ses séquences : les anciennes ne correspondent
   plus aux articulations.
2. Remplacer **en même temps** tous les assets de combat qui déclarent ce jeu propre (étape 7
   ci-dessus), sinon un ancien rig se retrouve sans Marche.
3. Contrôle visuel (VISUAL_QA) au Play et en combat réel.

## Tests

```powershell
./tools/test-skeleton.ps1 -LuauPath <chemin-vers-luau.exe>
```

Ils vérifient la liste des os (noms uniques, parents avant enfants, anciens noms d'articulation), le
rattachement (priorité fiche > attribut `Os` > nom, `OsAncre` d'un rig précédent, membres manquants,
avertissements), les fiches de l'Écuyer (pièces réelles) et du Roi Orc, l'ordre des jeux
d'animations, et `AnimationSets` avec des doubles d'Instance : jeu propre seul, commun seul, propre +
commun, aperçu, combat, jeu ou séquence manquants, anciens rigs (Écuyer, Gobelin, Roi Orc avant
migration), et la migration (`unshadow`) : défaut #56 reproduit, Marche commune après migration, Attaque
propre toujours prioritaire, réexécution sans effet.

## Animations à publier (AssetId)

Inventaire de la DEV après la migration pilote (aucune séquence n'a d'`AssetId`) :

| Jeu | Type | Séquences | Utilisé par (combat) |
| --- | --- | --- | --- |
| `Gobelin` | propre | Attente, Marche, Attaque, Touche, Mort | `Ennemi_Gobelin` |
| `EcuyerDuRempart` | propre | Attaque, Ultime | `Heros_EcuyerDuRempart` |
| `RoiOrc` | propre | Attaque | `Ennemi_RoiOrc` |
| `Squelette_Leger` | commun | Marche | `Heros_EcuyerDuRempart` (et tout futur héros léger) |
| `Squelette_Lourd` | commun | Marche | `Ennemi_RoiOrc` (et tout futur modèle lourd) |
| `TreantMasque` | propre | Marche, Attaque | atelier seulement (pas d'asset de combat) |
| `Apercu_*` (3) | aperçu | Attente | atelier seulement, **ne pas publier** |

15 séquences au total avant comme après (12 de production + 3 aperçus). Séquences nécessaires au
combat actuel : 10 avant (Gobelin 5, Écuyer 3, Roi Orc 2), 10 après (Gobelin 5, Écuyer 2, Roi Orc 1,
2 marches communes). Le gain vient avec les modèles suivants : chaque héros léger ou modèle lourd
branché réutilise la marche déjà publiée au lieu d'en ajouter une.

## Atelier et publication

`Workspace.AtelierAnimation` reste l'espace de travail de Studio. Dans une place publiée, ses modèles
d'aperçu (tags `ApercuAnimation`, `ApercuAttaque`, `ApercuUltime`...) tourneraient en boucle à la vue
des joueurs, sans animation hors Studio tant que les séquences n'ont pas d'`AssetId`. Avant une
publication : retirer l'atelier du `Workspace` (le ranger dans `ServerStorage`, par exemple), ainsi
que les jeux `Apercu_*` si on le souhaite. `ServerStorage.AnimationKitArchive` et
`ServerStorage.RBX_ANIMSAVES` ne sont pas répliqués et peuvent rester.

## Limites

- Un seul squelette pour l'instant (`Humanoide`) : une pièce par membre, pas de genou ni de coude.
  Une créature sans membres séparés (slime) ou à pattes / ailes / queue demandera un autre squelette
  (autre `Skeleton.Name` et autre liste d'os) : le format est prévu pour, pas encore écrit.
- Les os des armes existent même sans arme : une animation qui les anime ne fait alors rien de
  visible.
- Les translations des animations (rebond, en studs) ne s'adaptent pas à la taille du modèle.
- Un jeu commun ne sert qu'aux modèles au squelette commun (`Squelette = "Humanoide"`).
- Humanoïdes simples seulement : slime, quadrupède, ailes, queue restent hors de ce squelette
  (ancien rig ou futur squelette dédié).
- Le Roi Orc n'a pas de séquence Mort ni Touche : sa mort est l'effet de `DefeatEffectController`,
  comme avant.
