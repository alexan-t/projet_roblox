# Outils d'animation — AnimationKit

Outil d'atelier pour l'issue #16 (animations combat et personnages). Il pose un squelette sur un
héros ou un monstre généré par l'IA de Studio, génère sa marche, la range là où le jeu la cherche et
la montre en boucle à côté du spawn au prochain Play.

`tools/animation/AnimationKit.luau` est un **outil Studio**, pas du code de jeu : il n'est pas
synchronisé par Rojo et ne tourne jamais en partie. Il modifie des assets Studio (modèles,
`KeyframeSequence`), comme un artiste le ferait à la main. Aucun script n'est ajouté au place.

**Squelette commun** : `Kit.rig` pose désormais le squelette partagé par tous les héros et monstres
(os `Buste`, `Tete`, `BrasGauche`... ; animations nommées d'après les os, jeux communs
`Squelette_Leger` / `Squelette_Lourd`). Les os, les fiches de modèles (« cette pièce = tel os ») et
la marche à suivre pour **brancher un nouveau héros ou monstre** sont dans
[`SKELETON.md`](SKELETON.md). AnimationKit lit ces modules dans `ReplicatedStorage.Shared` : la
place doit être synchronisée par Rojo.

## Utilisation

Studio en mode **Edit**.

1. Ouvrir `tools/animation/AnimationKit.luau`, tout copier, coller dans la barre de commande
   (View → Command Bar), Entrée. Cela définit `_G.AnimationKit` pour la session Studio.
2. Lancer :

   ```lua
   _G.AnimationKit.prepare({
   	Source = workspace.Bestiaire.Heros.Socle_03.LancierDesChamps,
   	Set = "LancierDesChamps", -- ReplicatedStorage.Assets.Animations.<Set>
   	Profile = "Leger",        -- "Leger" ou "Lourd"
   })
   ```

3. Lire la ligne `[AnimationKit]` de la sortie : elle dit quelle pièce est tenue par quelle main.
4. Play : le personnage marche en boucle devant le `SpawnLocation`, à côté des autres.

Un agent fait la même chose avec `execute_luau` (contenu du fichier, puis l'appel).

## Ce que fait `prepare`

| Étape | Fonction | Résultat |
| --- | --- | --- |
| Copie | `Kit.copy` | clone dans `Workspace.AtelierAnimation`. **Le modèle source n'est jamais modifié** (le Bestiaire contient les références de DA). |
| Squelette | `Kit.rig` | `HumanoidRootPart` invisible et ancrée, os invisibles communs (dossier `Os`), `AnimationController` + `Animator`, articulations `Motor6D` ; attribut `Os` sur chaque pièce ; chaque arme recollée à son `Poing`, os de l'arme pivotant au centre du poing (voir `SKELETON.md` § Prise) |
| Marche | `Kit.walk` | `KeyframeSequence` « Marche » en boucle, priorité `Movement`, `Pose` nommées d'après les os |
| Rangement | `Kit.share` / `Kit.install` | marche dans le jeu commun de la fiche (`Assets.Animations.Squelette_Leger`...), attaque et ultime dans `Assets.Animations.<Set>` (jeu propre) ; copie dans `ServerStorage.RBX_ANIMSAVES.<modèle>` pour l'Animation Editor |
| Aperçu | `Kit.preview` | jeu `Apercu_<Set>` + tag `ApercuAnimation` (voir plus bas) |
| Placement | `Kit.arrange` | tous les modèles de l'atelier en ligne à 14 studs du spawn, tournés vers lui, pieds au sol, axe du spawn laissé libre |

Tout est enregistré comme une seule étape d'annulation quand Studio l'accepte. Chaque fonction peut
aussi être appelée seule (par exemple `Kit.arrange()` après avoir déplacé des modèles).

## Format de modèle attendu

Le format des modèles générés par l'IA de Studio : une pièce par membre, nommée `<membre>_geom`.

| Rôle | Noms acceptés | Articulation |
| --- | --- | --- |
| buste | `torso_geom`, `body_geom`, `chest_geom` | `Racine` (depuis la racine) |
| tête | `head_geom`, `mask_head_geom`, `skull_geom` | `Cou` |
| bras | `left_arm_geom`, `right_arm_geom` | `EpauleGauche`, `EpauleDroite` |
| jambes | `left_leg_geom`, `right_leg_geom` | `HancheGauche`, `HancheDroite` |

- Le repère est déduit des bras : X = du bras gauche vers le bras droit, -Z = avant. Les pivots
  sont placés en haut des membres (épaules, hanches) et en bas de la tête.
- **Autres pièces** : une pièce dont le nom évoque un objet tenu (`sword`, `weapon`, `spear`,
  `buckler`, `staff`, `marteau`, `etendard`...) suit la main la plus proche (os `ArmeGauche` /
  `ArmeDroite`, `Tenu_<nom>`). Tout le reste est fixé au buste (`Fixe_<nom>` : cape, ceinture, cor,
  cristal...). Corriger de préférence dans la fiche du modèle (`SkeletonConfig`, voir `SKELETON.md`)
  ou par l'attribut `Os` de la pièce ; `Held` reste accepté pour un essai rapide :

  ```lua
  _G.AnimationKit.prepare({ Source = ..., Set = ..., Profile = "Leger",
  	Held = { lantern_geom = "left", cape_geom = "torso" } })
  ```

- Constaté le 01/10/2026 dans Test 3 : 20 héros sur 30 suivent ce format. Les autres (et la
  plupart des slimes et des monstres non humanoïdes) demandent un squelette adapté : `Kit.rig`
  s'arrête avec un message qui nomme la pièce manquante.

## Prise des armes

Avant de brancher le squelette sur un héros, ses armes doivent avoir leur `Prise` et ses bras leur `Poing`
(`SKELETON.md` § Prise). Les 62 héros du Bestiaire et les 22 copies de jeu les ont depuis le
22/10/2026. Pour un nouveau héros (sur le modèle source, dans le Workspace) :

```lua
local Kit = _G.AnimationKit
print(table.concat(Kit.grip(model), "\n"))   -- pose Prise et Poing, recentre le manche
Kit.showGrips(model)                          -- capture de la main de face et de profil
print(table.concat(Kit.checkGrips(model), "\n")) -- vide = PASS
Kit.hideGrips(model)
```

Une ligne « À VÉRIFIER EN CAPTURE » ou un manche qui longe le poing se corrige avec `Kit.aim`
(direction du manche, glissement le long du manche), puis nouvelle capture.

Le PASS de `Kit.checkGrips` ne suffit pas (`SKELETON.md` § Prise, limite des mesures). Pour chaque
arme, capture rapprochée de la main **arme masquée** (`LocalTransparencyModifier = 1` sur les pièces
de l'arme) pour lire le poing, puis arme visible, de face et de profil :

- **Poing percé** (trou modelé, souvent peint rouge sombre à l'intérieur) : le manche suit l'axe du
  trou et passe par son centre. Paroi du trou = sommets du bras proches du centre du poing ; leur axe
  principal donne la direction (#24, #36, #37, #40, #42 le 22/10/2026).
- **Poing fermé** (doigts empilés, pas de trou) : le manche suit la rangée des doigts, en pratique
  l'axe épaule → bout du poing, et passe par le centre du poing (#34, #44, #50, #59). Une arme dont la
  tête partirait dans le bras est retournée (tête en bas) ; une lame qui entre dans le socle est
  inclinée vers l'avant.
- Prise validée en capture : attribut `PriseControlee` sur la Prise, date dans `HEROES_QA.md`.

Orientation au repos (contrôle global du 22/10/2026, vue de trois-quarts face de chaque héros) :

- **Arme à hampe** (bâton, hallebarde, lance, quenouille, bec-de-corbin, sceptre) : debout, tête en
  haut, penchée d'environ 12° vers l'avant (+Z) et un peu vers l'extérieur ; si la tête se cache
  contre l'épaule, l'écarter davantage (#52 : 22°).
- **Arme à une main** (épée, marteau, masse, coutelas) : pointe ou tête vers le bas et vers l'avant
  (environ 40°), ou tenue en garde vers l'avant à hauteur de hanche. Jamais à l'horizontale vers le
  côté, jamais cachée dans le bras ni plantée dans le socle.

## Profils de marche

La marche est une **courbe continue** (sinus) échantillonnée en 16 clés linéaires par cycle. Un
easing `Cubic InOut` par clé fait marquer un arrêt au corps à chaque clé : c'est ce qui rendait la
première version saccadée. Les bras et la tête suivent les jambes avec un léger retard.

| Profil | Pour | Cycle | Pas | Caractère |
| --- | --- | --- | --- | --- |
| `Leger` | héros, petit monstre (validé sur l'Écuyer du Rempart) | 0,6 s (≈ 7 studs/s) | ±28° | pas militaire, buste penché, arme basse |
| `Lourd` | tréant, colosse (validé sur le Tréant masqué) | 1,2 s (≈ 5 studs/s) | ±22° | rebond retardé, balancement d'épaules, bras qui traînent |

Pour une variante, passer une table au lieu du nom, en partant d'un profil existant :

```lua
local p = table.clone(_G.AnimationKit.Profiles.Lourd)
p.Cycle, p.Stride = 1.5, 18 -- plus lent, plus court
_G.AnimationKit.prepare({ Source = ..., Set = ..., Profile = p })
```

Paramètres (degrés, studs, secondes) : `Cycle`, `Stride` (jambes), `Lean`/`LeanPulse` (buste
penché), `Yaw`/`Roll`/`RollLag` (rotation et roulis du buste), `BobBase`/`Bob`/`BobLag` (rebond),
`ArmForward`/`ArmSwingRight`/`ArmSwingLeft`/`ArmLag`/`ArmSpread*` (bras), `Head*` (tête).
Les `Lag` sont des retards de phase en radians. Garder la vitesse de pas proche de `MoveSpeed`
de `CombatConfig` pour limiter le glissement des pieds.

## Attaque de base

`Kit.attack(model, style)` crée la `KeyframeSequence` « Attaque » (non bouclée, priorité `Action`)
à partir de poses clés. Sur un modèle déjà riggé dans l'atelier :

```lua
local Kit = _G.AnimationKit
local m = workspace.AtelierAnimation.EcuyerDuRempart
Kit.install(m, "EcuyerDuRempart", Kit.attack(m, "Epee"))
Kit.preview(m, "EcuyerDuRempart", "Attaque") -- au Play : l'attaque, puis 0,8 s de pause, en boucle
```

Ou d'un coup à la préparation : `prepare({ ..., Attack = "Epee", Preview = "Attaque" })`.

| Style | Pour | Durée | Impact | Mouvement |
| --- | --- | --- | --- | --- |
| `Epee` | arme à une main + bouclier (validé sur l'Écuyer) | 0,6 s | 0,2 s | armé de côté, coup en diagonale à travers le corps, petit pas en avant, bouclier gardé devant ; l'arme tourne dans la main à l'impact pour finir vers le bas-gauche sans entrer dans le bouclier (`HEROES_QA.md`) |
| `Griffe` | gros monstre à mains nues (validé sur le Tréant) | 1,0 s | 0,35 s | gros revers de la main droite : bras armé en arrière, buste tourné, balayage à travers le corps, bras gauche en contrepoids |
| `Ecrasement` | variante (non retenue pour le Tréant) | 1,0 s | 0,32 s | deux bras levés, abattus au sol devant lui, buste plié, rebond lourd |

**Synchronisation avec le combat** : `CombatViewController` joue « Attaque », affiche les dégâts et
fait réagir la cible **à la même image** (événement `Attack`). Le coup doit donc tomber tôt :
préparation courte, puis frappe. L'instant du coup est marqué par un `KeyframeMarker` « Impact »
(et l'attribut `Impact` de la séquence) : le code de combat pourra s'en servir pour retarder les
chiffres de dégâts et « Touche » jusqu'au coup (`AnimationTrack:GetMarkerReachedSignal("Impact")`).
Garder la durée sous l'`AttackInterval` le plus court qui utilisera l'animation (`CombatConfig`).

Un nouveau style se décrit comme une table `{ Length, Impact, Keys = { { Time, Easing, Poses } } }`
(voir `Kit.Attacks`) : poses par rôle (`torso`, `head`, `leftArm`, `rightArm`, `leftLeg`,
`rightLeg`) en `{ rx, ry, rz, y }`, dans le repère racine : +rx = membre vers l'avant, +ry = buste
vers la gauche, +rz = bras droit vers l'extérieur (bras gauche : -rz). Les jambes étant attachées au
buste, compenser sur les jambes une inclinaison ou une rotation du buste pour garder les pieds au sol.
L'`Easing` d'une clé règle le trajet vers la clé suivante (`In` = accélère vers le coup).

## Attaques des héros (22/10/2026)

Les 60 héros du Bestiaire ont une attaque de base, rangée dans leur jeu propre
`ReplicatedStorage.Assets.Animations.<NomDuModèle>` (séquence `Attaque`, attribut `Impact`). L'Écuyer
garde son attaque validée dans `EcuyerDuRempart` ; la version de l'atelier est dans
`Atelier_EcuyerDuRempart`. Copies riggées : `Workspace.AtelierAnimation.<Nom>_Anim`, en grille à
X = -140…-32, Z = -280…-360, attaque en boucle au Play.

Six styles par famille d'arme (`Kit.Attacks`), plus le miroir main gauche (suffixe `_G`) :

| Style | Arme | Durée | Impact | Mouvement |
| --- | --- | --- | --- | --- |
| `Epee` | épée, coutelas, épée-clé | 0,6 s | 0,2 s | armé à l'épaule, diagonale vers le bas devant soi |
| `Masse` | masse, marteau, maillet, glaive, faux | 0,65 s | 0,25 s | levée derrière la tête, abattue devant |
| `Estoc` | lance, hallebarde, harpon, trident, étendard | 0,6 s | 0,25 s | pointe abaissée, estoc bras tendu |
| `Sort` | bâton, sceptre, quenouille | 0,7 s | 0,3 s | bâton contre l'épaule, tête pointée vers la cible, main libre en avant |
| `Tir` / `Arbalete` | arc / arbalète | 0,8 s | 0,45 s | buste tourné, corde tirée, lâcher à l'impact |
| `Poing` | mains nues (#20) | 0,5 s | 0,2 s | fente avant, poings projetés (bras modelés levés) |

| Style | Héros |
| --- | --- |
| `Epee` | #01, #15, #23, #27, #29, #37, #40, #49, #54, #57, #59 |
| `Masse` | #05, #21, #24, #26, #34, #36, #42, #44, #45, #46, #50, #61, #63, #65, #66 ; `Masse_G` #19 |
| `Estoc` | #03, #18, #30, #31, #39, #52, #62, #64, #67 ; `Estoc_G` #56 |
| `Sort` | #04, #16, #25, #28, #33, #35, #38, #41, #43, #47, #48, #51, #53, #58, #60, #68 ; `Sort_G` #17, #22, #32, #55 |
| `Tir` / `Arbalete` / `Poing` | #14 / #02 / #20 |

**Visée de l'arme** : les héros ne tiennent pas leur arme pareil au repos (debout, tête en bas, en
travers). Un angle d'arme commun les envoyait dans toutes les directions (lance pointée vers le
ciel, arbalète vers le sol). `Kit.aimedAttack(model, style, options)` garde les poses du style et
calcule, pour chaque clé, la rotation de l'os d'arme qui amène le manche (axe de la `Prise`) sur la
direction de `Kit.AttackAims`. Options : `Flip` quand la Prise pointe vers le talon (#55,
champignon), `Free` pour un bâton dont la Prise est libre (#41, #51, #65).

```lua
local Kit = _G.AnimationKit
local m = workspace.AtelierAnimation.LanciereDesSources_Anim -- copie riggée (Kit.copy + Kit.rig)
Kit.install(m, "LanciereDesSources", Kit.attack(m, Kit.aimedAttack(m, "Estoc")))
Kit.preview(m, "LanciereDesSources", "Attaque")
```

Contrôle fait : pose d'impact de chacun des 60 héros en capture (trois-quarts), puis Play (60/60
animés). Sans visée : #20 (mains nues). Elyria (#68) a deux jambes invisibles ajoutées à sa copie
d'atelier (le squelette commun en demande deux) et lévite à 1 stud.

**En combat (23/10/2026, place test 3)** : les 59 autres héros ont leur modèle articulé
`ReplicatedStorage.Assets.Combat.Heros_<Modèle>` (copie de l'atelier, tags et attributs d'aperçu
retirés) et leur `CombatTemplate` dans `HeroConfig`. Attributs : `JeuAnimations = <Modèle>`,
`JeuAnimationsCommun = Squelette_Leger` (marche commune, générée sur #03), `Squelette = Humanoide`,
`HauteurPieds` = hauteur du pivot au-dessus des pieds : `ArenaService` pose le héros avec, car le bas
de la boîte est l'arme pour #05 et #59 (ils flottaient) ; Elyria : ourlet + 1 stud (lévitation).
Une place qui n'a pas encore ces modèles (DEV) montre le vrai modèle du héros, par son HeroId.
Vérifié en combat réel (stage 1-1, #05, #14, #16, #44) : chaque héros joue sa marche (0,6 s) puis son
attaque (Masse 0,65 s, Tir 0,8 s, Sort 0,7 s), posé sur sa case. L'Écuyer de test 3 est resté sur
l'ancien squelette (la DEV a sa version migrée). **À faire** : importer dans la DEV les 59 modèles,
les jeux `<Modèle>` et `Squelette_Leger`, puis publier les séquences (`AssetId`).

## Ultimes des héros (brief `docs/ultimes/ULTIMES.md`)

Chaque ultime = une séquence « Ultime » dans le jeu propre du héros (style de `Kit.Attacks`) + un
effet du client choisi par l'attribut texte `EffetUltime` du modèle de combat
(`UltimateEffectController`, une fonction par effet). L'instant où l'effet part est l'attribut
`Impact` de la séquence, plus le trajet de l'effet (`TRAVEL`) : les dégâts et disparitions tombent
au coup (`ImpactDelay(speed, caster)`). Sans attribut : onde dorée « Charge du Rempart ».

| Héros | Ultime | Style | Durée / impact | `EffetUltime` |
| --- | --- | --- | --- | --- |
| #01 Écuyer du Rempart | Rempart Fermé | `RempartFerme` | 0,7 s / 0,3 s | `RempartFerme` : écu doré qui frappe 2 à 5 studs devant lui |
| #02 Tireuse des Faubourgs | Le Dernier Carreau | `DernierCarreau` (visé) | 0,8 s / 0,45 s | `DernierCarreau` : carreau lourd qui traverse la cible, traînée fine |

```lua
local Kit = _G.AnimationKit
local m = workspace.AtelierAnimation.TireuseDesFaubourgs_Anim
Kit.install(m, "TireuseDesFaubourgs", Kit.ultimate(m, Kit.aimedAttack(m, "DernierCarreau")))
-- puis attribut EffetUltime = "DernierCarreau" sur Assets.Combat.Heros_TireuseDesFaubourgs
```

Vérifié le 23/10/2026 (test 3) : captures à x0,1 dans l'atelier (pose d'impact de profil, écu,
carreau et traînée) ; combat réel stage 1-1, chaque héros seul : l'Écuyer lance l'écu, la Tireuse
attaque 5 fois puis l'ultime, carreau parti 0,47 s après le début de l'animation. Dans test 3,
l'ultime de l'Écuyer est dans `Atelier_EcuyerDuRempart` (son jeu `EcuyerDuRempart` y est encore sur
l'ancien squelette) ; dans la DEV, le ranger dans `EcuyerDuRempart` à la place du style `Rempart`.

## Aperçu au Play

`MonsterAnimationController` anime en boucle tout modèle tagué `ApercuAnimation` (Attente, puis
Marche, Attaque, Touche, Mort). Il coupe la marche toutes les 2,4 s. Pour l'éviter sans toucher au
code, l'aperçu utilise un jeu séparé `Apercu_<Set>` où l'animation étudiée est rangée sous le nom
`Attente`, jouée en continu. Le vrai jeu (`<Set>`, attribut `JeuAnimationsCombat` du modèle) reste
celui du combat.

Quand un personnage aura plusieurs animations (Attente, Attaque...), remettre son attribut
`JeuAnimations` sur le vrai jeu pour voir l'enchaînement complet.

## Attaque du Roi Orc (boss) et effet d'impact

Préparé à l'origine avec `Parts` / `Held` ; ces réglages sont maintenant la fiche
`SkeletonConfig.Models.RoiOrc` (tête `body_geom`, bannière au buste, pics et crânes d'épaule au bras
le plus proche, profil `Lourd`, attaque `Fendoir`, couvercles de bras). La DEV n'a pas de Roi Orc au
Bestiaire : la source est une copie désarticulée de l'asset de combat (voir `SKELETON.md`, exemples).

```lua
local source = game.ReplicatedStorage.Assets.Combat.Ennemi_RoiOrc:Clone()
_G.AnimationKit.unrig(source)
source.Name = "RoiOrc"
_G.AnimationKit.prepare({ Source = source, Set = "RoiOrc", Name = "RoiOrc_Squelette", Arrange = false })
source:Destroy()
```

`Kit.closeArms` peut être relancé : il remplace les couvercles et toutes les articulations qui les
tenaient (aucun `Motor6D` orphelin).

- `Membres` (ex-`Parts`) désigne la pièce d'un membre au nom inhabituel ; `BrasProche`
  (ex-`"nearest"`) une pièce portée par le bras le plus proche. Voir `SKELETON.md`.
- Les styles peuvent animer l'**arme elle-même** (`weaponRight`, `weaponLeft` : os `ArmeDroite`,
  `ArmeGauche`, pivot dans la main). L'angle de la lame est la somme bras + arme.
- `Fendoir` (1,4 s, impact 0,7 s) : armé lent, le bras lève la lance-hache au-dessus de la tête,
  court temps suspendu, puis l'abat devant lui ; la lame mord le sol. Demande `Kit.closeArms`.
- **Effet d'impact** : poser l'attribut texte `EffetAttaque = "Seisme"` sur le modèle (asset). Au
  coup de son « Attaque », `src/client/Controllers/AttackEffectController.lua` soulève un anneau de
  terre irrégulier sous l'arme, projette des éclats, soulève de la poussière et secoue un peu la
  caméra du joueur proche. Démonstration Studio : tag `ApercuAttaque` (attaque + effet en boucle).
- Le combat retarde les chiffres de dégâts et la disparition de la cible jusqu'à l'impact de toute
  attaque dont la séquence a un attribut `Impact` (héros 0,2 s, Roi Orc 0,7 s).

## Ultime du héros de départ

`Kit.ultimate(model, "Rempart")` crée la séquence « Ultime » de l'Écuyer du Rempart (0,9 s, impact
0,3 s) : ramassé derrière le bouclier, épée tirée en arrière, puis grand estoc. L'arme est tournée
dans la main (`weaponRight`) pour que la pointe vise l'avant pendant l'estoc ; ces angles sont
mesurés sur l'Écuyer : les remesurer pour un autre modèle (`HEROES_QA.md`).

```lua
local Kit = _G.AnimationKit
local m = workspace.AtelierAnimation.EcuyerDuRempart
Kit.install(m, "EcuyerDuRempart", Kit.ultimate(m, "Rempart"))
```

L'effet visuel (lueur, lame dorée, anneau au sol) est du code de jeu :
`src/client/Controllers/UltimateEffectController.lua`, appelé par `CombatViewController` sur
`UltimateUsed`. Garder `ANIMATION_IMPACT` de ce fichier égal à l'`Impact` du style. Pour le voir au
Play, taguer le héros riggé `ApercuUltime` (Studio) : ultime en boucle vers un point à 10 studs
devant lui.

## Disparition à la mort (pas de réaction aux dégâts)

Le jeu est surtout en one-shot : pas d'animation de douleur (« Touche »). À la mort, l'unité se
dissout : c'est du code de jeu, `src/client/Controllers/DefeatEffectController.lua`, appelé par
`CombatViewController` sur `UnitDied` (voir `docs/COMBAT.md`). Il marche sur tout modèle, riggé ou
non, sans réglage.

Pour le voir au Play, taguer un modèle de l'atelier `ApercuDisparition` (Studio uniquement) : une
copie figée du modèle se dissout, puis il réapparaît, en boucle (attribut `ApercuPause`). Les réglages
(durée, sursaut, bascule, poussière, étincelles) sont les constantes en tête du fichier.

## Voir le rendu en x2

Attribut numérique `ApercuVitesse` sur `Workspace.AtelierAnimation` (ou sur un modèle) : toutes les
démonstrations (marche, attaque, ultime, effets) jouent à cette vitesse. `2` = rendu du combat en x2,
supprimer l'attribut pour revenir en x1. En combat, la vitesse vient de `SpeedChanged` (voir
`docs/COMBAT.md`).

## État actuel DEV

Après la migration pilote sur le squelette commun (Écuyer et Roi Orc, voir `SKELETON.md`) :

| Jeu (`ReplicatedStorage.Assets.Animations`) | Séquences | Squelette | `AssetId` |
| --- | --- | --- | --- |
| `EcuyerDuRempart` | Attaque, Ultime | commun | absent |
| `RoiOrc` | Attaque (Fendoir) | commun | absent |
| `Squelette_Leger` | Marche (Écuyer, futurs héros légers) | commun | absent |
| `Squelette_Lourd` | Marche (Roi Orc, futurs modèles lourds) | commun | absent |
| `Gobelin` | Attente, Marche, Attaque, Touche, Mort | ancien | absent |
| `TreantMasque` | Marche, Attaque (pas d'Ultime) | ancien | absent |
| `Apercu_EcuyerDuRempart`, `Apercu_TreantMasque`, `Apercu_RoiOrc` | Attente (démonstration d'atelier, pas pour le combat) | — | absent |

Modèles de combat (`ReplicatedStorage.Assets.Combat`) : `Heros_EcuyerDuRempart` et `Ennemi_RoiOrc`
sur le squelette commun ; `Ennemi_Gobelin` sur l'ancien squelette (les deux coexistent en combat).
Les anciennes versions (assets et séquences) sont dans `ServerStorage.AnimationKitArchive`.

`Workspace.AtelierAnimation` : `EcuyerDuRempart_Squelette` et `RoiOrc_Squelette` (squelette commun,
aperçu de la Marche) ; `Treant_Masque` (ancien squelette, inchangé) ; `EcuyerDuRempart` et `RoiOrc`,
anciennes copies de l'ancien squelette, **obsolètes** (leurs jeux contiennent maintenant des séquences
du squelette commun : à retirer de l'atelier). Les modèles du Bestiaire et de
`ServerStorage.Assets.Heros` ne sont pas articulés. Bestiaire et atelier sont des références / outils
de design, pas une source de vérité gameplay.

- **Studio : fonctionnel.** Vérifié en combat réel (stages 1-1 et 1-5, x1 / x2) et au Play pour
  l'atelier ; les séquences sont enregistrées à la volée.
- **Production : `AssetId` requis.** Aucune `KeyframeSequence` n'a encore d'`AssetId` publié, pas
  même celles du Gobelin. Hors Studio, une séquence sans `AssetId` ne joue pas. Chaque séquence de
  combat doit être publiée **par le propriétaire de l'expérience** (sinon Roblox refuse de la jouer
  dans cette expérience), puis son identifiant mis dans l'attribut `AssetId` de la séquence.
- Avant publication : sortir `Workspace.AtelierAnimation` de la place jouée (aperçus en boucle,
  voir `SKELETON.md` § « Atelier et publication »). Les jeux `Apercu_*` ne se publient pas.
- Dans la DEV, deux `SpawnLocation` existent (`Lobby.Monde.SpawnLobby` actif, ancien
  `Workspace.SpawnLocation` de test désactivé). `Kit.arrange` prend le premier `SpawnLocation`
  trouvé : vérifier lequel avant de ranger l'atelier.

## Limites

- Les animations sont enregistrées à la volée, **uniquement en Studio**. Pour le jeu publié :
  publier chaque `KeyframeSequence` depuis l'Animation Editor, puis mettre son identifiant dans
  l'attribut `AssetId` de la séquence (lu par `MonsterAnimationController`). Publication sous le
  propriétaire de l'expérience uniquement : `docs/ASSET_OWNERSHIP.md`.
- Pas de genoux ni de pieds articulés : les modèles IA ont une seule pièce par jambe.
- Les capes et tabards sont fixés au buste, sans mouvement secondaire.
- Marche (commune), attaque de base (60 héros) et ultime (Écuyer) sont générés ; pas encore d'Attente (repos).
- **Bras en coque** (Roi Orc) : ses bras sont ouverts sur toute leur face intérieure (côté buste).
  Au repos le buste cache l'ouverture ; dès que le bras s'écarte, on voit l'intérieur, noir.
  `Kit.closeArms(model, couleurPeau)` ferme cette face avec un ellipsoïde couleur peau porté par le
  bras, qui reste dans l'aisselle au repos. Roi Orc : `Color3.fromRGB(76, 111, 41)` (moyenne des pixels
  de peau de la texture du bras, via `AssetService:CreateEditableImageAsync`). Pour un autre modèle,
  régler d'abord en rouge vif : bras seul vu du buste (plus de noir), puis modèle entier au repos de
  face, de dos et de dessus (rien ne dépasse), puis en gros plan aux instants clés de l'animation.
  Erreur à ne pas refaire : une sphère centrée sur l'épaule (dépasse au repos sans boucher le trou).
- Les épaules des modèles IA sont des pièces creuses : un bras levé très haut ou très écarté laisse
  voir le dessous sombre de l'épaulière. Garder les bras sous ~80° (rx) et ~30° (rz). Le pivot
  d'épaule est placé près du bord intérieur du bras pour limiter l'effet ; `Kit.unrig` puis
  `Kit.rig` reposent le squelette d'un modèle riggé (sur le squelette commun : régénérer ensuite
  les séquences d'un modèle de l'ancien squelette).
