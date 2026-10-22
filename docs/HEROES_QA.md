# Héros — contrôle des armes et des animations du 20 octobre 2026

**Verdict global : FIX.** Les 60 héros du catalogue passent sur la tenue des armes, au repos
et, pour l'Écuyer (seul héros animé), pendant ses animations. Quatre défauts ont été corrigés.
Les deux brouillons de Brise-Braise (socles 10 et 11, hors catalogue) restent non texturés.

## Environnement et portée

- Place Studio **test 3** (placeId `120616399792561`), mode Edit, aucune publication.
- 62 modèles posés sur `Workspace.Bestiaire.Heros` (socles 1 à 5 et 10 à 68 ; 6 à 9, 12 et 13
  sont vides). Copies de jeu : les 22 modèles de `ServerStorage.Assets.Heros`.
- Contrôle centré sur la grille `VISUAL_QA.md` lignes **Armes et accessoires**, **Clipping**,
  **Géométrie** et **Matériaux**. Les lignes de niveau de qualité, d'originalité et de
  comparaison côte à côte avec les références principales n'ont pas été rejouées : les héros
  existants n'ont pas été régénérés.
- Originaux archivés avant toute retouche dans `ServerStorage.Archive_Heros_QA` ; chaque
  retouche est une étape `ChangeHistoryService` (Ctrl+Z).

## Méthode

1. **Mesure de prise** pour chaque objet tenu : centre du poing estimé par les points intérieurs
   du bras les plus éloignés de l'épaule, puis test « dedans » (`GetPartsInPart` avec une sonde)
   de l'arme sur la zone du poing (`MONSTER_PRODUCTION.md`, Outils § D).
2. **Captures réelles** de chaque héros (trois-quarts, puis face, profil ou dessus pour les cas
   douteux), dont avant et après chaque correction.
3. **Animations** : copies de l'Écuyer de l'atelier posées à chaque clé d'Attente, Marche,
   Attaque et Ultime (poses appliquées aux `Motor6D` des copies, jamais au modèle du Bestiaire),
   direction de la pointe mesurée dans le repère du héros, points de la lame testés contre le
   bouclier, le buste, la tête, le bras gauche et les jambes. Copies supprimées après contrôle.

## Corrections appliquées

| Héros | Défaut vu | Correction | Après |
| --- | --- | --- | --- |
| #25 Prêtresse aux Lucioles | Bâton à côté du poing droit (0 point de contact) ; cristal au sommet = cube néon visible du dessus | Bâton déplacé de 0,28 stud sur le centre du poing ; cristal en sphère de 0,6 (Bestiaire et copie de jeu) | Poing fermé sur le manche de face et de profil |
| #47 Tisseur de Destins | Quenouille qui passe à côté du poing droit (3 points sur 28) | Déplacée de 0,26 stud perpendiculairement à son axe, pelote comprise | Manche dans le poing de face et de profil |
| #58 Reine du Firmament Doré | Sceptre qui frôle le côté du poing | Déplacé de 0,34 stud, cristal du sommet déplacé de même | Manche dans le poing de face |
| #01 Écuyer du Rempart, Ultime | « Grand estoc » dont la lame part vers le haut et la gauche à l'impact (pointe à 25 % vers l'avant) | `weaponRight` ajouté au style `Rempart` (AnimationKit) et à la séquence Studio | Pointe à 96–99 % vers l'avant à l'armé et pendant l'estoc ; poing toujours sur le manche |
| #01 Écuyer du Rempart, Attaque | À l'impact et juste après, la lame entre dans le bouclier (4 et 6 points) | `weaponRight` ajouté au style `Epee` (AnimationKit) et à la séquence Studio | Diagonale finie vers le bas-gauche, aucun point de lame dans le corps ou le bouclier, y compris à 0,25 s interpolé |

Les anciennes séquences sont archivées (`Archive_Heros_QA.EcuyerDuRempart_*_avant_QA`) ;
la copie de `ServerStorage.RBX_ANIMSAVES.EcuyerDuRempart` a reçu les mêmes poses.

## Passation du 22 octobre 2026 : visages, armes, coquilles

Repasse complète des 62 modèles du Bestiaire (place test 3) : planche des 62 têtes de face,
gros plans des visages douteux, planche des 62 héros en pied (trois par capture), puis mesure de
prise de chaque arme et vues isolées bras + arme pour les cas douteux.

| Héros | Défaut vu | Correction | Après |
| --- | --- | --- | --- |
| #15 Chevalier du Lierre | Bouclier qui flotte devant l'avant-bras gauche (écart 0,79 stud, vide visible de dessus et de profil). Le rapport du 20 le disait « sanglé », mais il ne touchait pas le bras | Recollé de 0,76 stud vers le bras (Bestiaire et copie de jeu, position par rapport au buste) | Écart 0,03 stud, contact ; capture de trois-quarts |
| #05 Brise-Pierre | Talon du manche posé sur le dessus du poing : le manche ne le traverse pas (repéré par l'utilisateur) | Marteau glissé de 0,8 stud le long du manche (Bestiaire et copie de jeu) | Vue isolée bras + marteau de profil : le manche entre par le haut du poing et le talon ressort dessous |
| #24 Forgeron Runique | Même défaut : le manche s'arrête contre le côté du gant | Marteau glissé de 0,8 stud le long du manche (Bestiaire et copie de jeu) | Vue isolée de profil : le manche traverse le gant |
| #67 Auréon | Lance tenue par l'extrême bout du manche, poing au ras du talon | Glissée de 2,1 studs le long de son axe : poing au tiers bas du manche, talon au-dessus du sol | Manche qui traverse le poing de haut en bas (capture de face) ; pas de copie de jeu |

Ces deux retouches n'ont pas d'étape Ctrl+Z : `ChangeHistoryService:TryBeginRecording` renvoie
`nil` dans cette session de Studio (un enregistrement est resté ouvert plus tôt). Elles sont
gardées par `tools/studio-check-heroes.luau`.

**Prises (Poing et Prise, `SKELETON.md` § Prise)** — après un second signalement du #05 (le manche
longeait encore l'extérieur du poignet), chaque arme est maintenant accrochée à un repère de poing :

- `Kit.grip` lancé sur les 62 héros du Bestiaire (originaux archivés dans
  `ServerStorage.Archive_Prises_20261022`) : Prise sur l'arme, Poing au centre du poing mesuré,
  manche recentré dans le poing (0 à 0,82 stud, médiane 0,17). Report à l'identique sur les 22 copies
  de jeu.
- Vérifié en vues isolées bras + arme, de face et de profil : #02, #04, #05, #10, #14, #16, #27, #30,
  #35, #36, #37, #42, #43, #50, #57, #59, #61 (les plus gros recentrages et tous les cas signalés par
  l'outil en cours de mise au point).
- Corrigés à la main : **#05 Brise-Pierre** (manche recentré dans le poing, de face comme de profil) ;
  **#36 Gardienne de la Dernière Cloche** (le bout du maillet était collé au côté du gant : manche
  glissé de 0,45 stud dans la fente du gant).
- **#05, troisième signalement** : le trou du poing est presque horizontal (axe mesuré par les lignes
  qui traversent le poing sans toucher le bras, entourées sur 7 côtés sur 8) ; un marteau levé à la
  verticale ne pouvait que le longer. Marteau réorienté dans l'axe du trou, tenu devant, tête
  légèrement vers le bas ; Poing posé au centre du trou (Bestiaire et copie de jeu). Leçon : le Poing
  doit suivre l'axe du trou de la main, pas celui de l'arme (voir la proposition « squelette d'arme »).
- Fiches ajoutées (`SkeletonConfig`) : #17 (couteau au fourreau, faucon au bras), #21 (ronces des
  bras), #32 (bras droit = gantelet), #36 (cloche dans le dos), #43 (poing séparé), #45 (clé géante en
  main), #52 (bec de corbin en main).
- Contrôle (section 5) : 95 mains contrôlées, 0 défaut. Il attrape le #05 dans l'état de la capture
  de l'utilisateur (Prise à 0,83 stud du Poing) comme dans l'état d'avant ce chantier (0,19).
- Pendant une animation : #05 riggé dans l'atelier (`AtelierAnimation.BrisePierre_Prise`, jeu
  `BrisePierre`, attaque d'aperçu `Epee`), épaule levée de 110° et arme tournée de 50° : écart
  Prise / Poing 0,000 stud ; marteau dans le poing pendant l'attaque en Play.

**Visages**

- **PASS** : les 50 héros non cités ci-dessous (hors brouillons #10 et #11). Expression lisible (sourcils, yeux, bouche) et cohérente avec la DA.
- **Voulus, laissés tels quels** :
  - visage caché par un masque, une capuche ou un heaume : #53, #56, #52 et #26 ;
  - peau de pierre ou spectrale : #64, #51 et #49 ;
  - #60 : aveugle aux yeux bandés (pas de nez, bouche à peine marquée).
- **FIX à décider** :
  - #54 Lame du Serment Brisé : sous le heaume, orbites noires à points rouges, mais ni bouche ni
    sourcils ; le visage est vide de face. Il faut repeindre la texture de la tête, donc un envoi
    d'image (à valider avant).
  - #22 Cartomancienne : cou nettement plus rouge que le visage (mineur, texture).
- **Observation** : #46, de trois-quarts, la lame du glaive passe devant le visage ; de face, il
  est dégagé.

**Armes** (au repos, 62 modèles) : toutes tenues après les quatre corrections. Attention, la
mesure « l'arme touche le bras » ne suffit pas : un talon de manche posé sur le poing la passe
(#05). Les armes à manche ont donc été revues en vue isolée bras + arme, de face et de profil :
le manche doit traverser le poing. #42, #44, #48, #50, #61 et #63 passent ainsi. Mesure et vues
isolées confirment la prise de #18, #19, #51 et #53, que la mesure automatique donnait douteux
(manches portés hors du centre du poing). #26 tient la cloche par sa couronne ; #42 a la tête du
marteau au sol, manche dans le poing.

## Résultats par héros (au repos)

**PASS** (arme dans le poing, orientation lisible de face et de profil, pas d'interpénétration
visible) : #01 à #05, #14 à #24, #25 (après correction), #26 à #46, #47 (après correction),
#48 à #57, #58 (après correction), #59 à #68.

Cas vérifiés de plus près et laissés tels quels, car voulus :
- #15, #21 : bouclier sanglé à l'avant-bras (pas dans le poing ; #15 recollé le 22 octobre, voir
  plus haut) ; #36 : cloche portée dans le dos ;
  #19 : luth au dos ; #17 : faucon sur le bras levé ; #22 : cartes en éventail entre les doigts.
- #30, #31, #61 : cristaux cubiques tournés à 45°, lus comme le losange de la DA.
- #44 : masse tenue en garde vers l'avant ; #45 : clé géante tenue en travers.

**FIX non traité** : #10 et #11 (`Heros_BriseBraise_Stylise_B` / `_A`). Six pièces sur huit
(et sept sur huit) n'ont aucune texture : le modèle s'affiche gris uni. Ce sont deux variantes
d'un héros absent de `HeroConfig`, en cours de travail (archives `Archive_BriseBraise`). Il faut
choisir la variante, puis la texturer (`generate_texture`) et repasser la grille complète.

## Animations de l'Écuyer

| Séquence | Clés | Pointe vers l'avant | Lame dans le corps ou le bouclier | Verdict |
| --- | --- | --- | --- | --- |
| Attente (aperçu) | 6 | comme l'Attaque | bouclier à 0,20 et 0,30 avant correction (mêmes poses que l'Attaque) ; même correction appliquée | PASS (mesure) |
| Marche | 17 | 0,54 à 0,80 | aucun (la lame passe devant le genou) | PASS |
| Attaque | 5 | lame en diagonale vers le bas-gauche | aucun après correction | PASS |
| Ultime | 5 | 0,72 au repos, 0,96 à 0,99 à l'armé et à l'estoc | aucun | PASS |

L'aperçu d'atelier `Apercu_EcuyerDuRempart.Attente` reprend les poses de l'attaque suivies
d'une pause (démonstration, pas du combat) : il a reçu les mêmes poses d'arme, ancienne version
archivée (`EcuyerDuRempart_ApercuAttente_avant_QA`).

Les 59 autres héros n'ont ni squelette ni animation : en combat, leur vrai modèle est posé
statique (voir `HEROES.md`). Leur contrôle « pendant les animations » sera à faire quand ils
seront articulés (`SKELETON.md`).

## Contre-contrôle

Deux tests gardent les corrections en place :

- `tools/studio-check-heroes.luau` (mode Edit, lecture seule, renvoie le nombre de problèmes) :
  poses de l'épée et marqueur Impact des cinq séquences de l'Écuyer (jeu, aperçu Attente,
  `RBX_ANIMSAVES`), prise de l'arme de #01, #25, #47 et #58, cristal en sphère de #25, copies
  de jeu identiques au Bestiaire (positions par rapport au buste : les pivots diffèrent). Les
  brouillons #10 et #11 sont signalés « CONNU » sans compter.
- `tests/heroes-weapons.test.mjs` (`node --test`) : le script Studio attend les mêmes poses
  qu'AnimationKit, le même impact que `UltimateEffectController`, et reste en lecture seule.

Résultats du 20 octobre 2026 (place test 3) :

| Contrôle | Résultat |
| --- | --- |
| Séquences de l'Écuyer : 5 séquences, 26 clés, 5 marqueurs Impact | PASS |
| Prise : épée 0 stud, bâton #25, quenouille #47, sceptre #58 dans le bras | PASS |
| Prise : bouclier de l'Écuyer, poing plaqué à la poignée (écart 0,14 stud, toléré 0,2) | PASS, vu en capture de profil |
| Cristal de #25 en sphère (Bestiaire et copie de jeu) | PASS |
| 22 copies de jeu identiques au Bestiaire | PASS |
| Captures de #01 (face, profil), #25 (face), #47 et #58 après corrections | PASS |
| Script Studio : 0 problème ; brouillons #10 (5/8 pièces sans texture) et #11 (7/8) | CONNU (FIX) |
| `node --test tests/heroes-weapons.test.mjs` : 7 tests | PASS (7/7) |

Résultats du 22 octobre 2026 (place test 3), après la passation :

| Contrôle | Résultat |
| --- | --- |
| Prise : marteaux #05 et #24, bouclier #15 Chevalier du Lierre (toléré 0,2), lance #67 Auréon | PASS |
| Prises Poing / Prise : 62 héros du Bestiaire et 22 copies de jeu, 95 mains | PASS |
| `tools/test-skeleton.ps1` : Skeleton 20 tests, AnimationSets 14 tests | PASS |
| Script Studio : 0 problème ; brouillons #10 et #11 | CONNU (FIX) |
| Visage de #54 (sans bouche ni sourcils) | FIX, en attente d'accord pour l'envoi de texture |

## Prises du 22 octobre 2026 (second et troisième signalements)

1. L'utilisateur montre le #04 Apprenti Pyromancien : le bâton ne passe pas dans le poing, alors que
   le contrôle donnait PASS. Cause : les mesures de prise ne voient que l'enveloppe de collision des
   MeshParts, qui bouche le creux du poing.
2. Premier correctif (commit 1050021) : règle « manche à au moins 45° de l'avant-bras » et 14 armes
   tournées à 60°. Retour de l'utilisateur : #34, #36, #37, #40, #42, #44, #50, #59 et #24 ont encore
   le problème. La règle ratait #24, #40, #42 et #50 (manche dans le gant, sous le poing ou à côté) et
   avait déplacé à tort les armes de poings fermés (#34, #44, #59). Règle retirée.
3. Correctif par capture, arme masquée pour lire le poing (`ANIMATION_TOOLS.md` § Prise des armes) :

| Héros | Poing | Correction |
| --- | --- | --- |
| #24 Forgeron Runique | percé | marteau dans l'axe du trou, tête en bas devant |
| #36 Gardienne de la Dernière Cloche | percé | maillet dans l'axe du trou, tête vers l'avant |
| #37 Prince des Racines d'Or | percé | épée dans l'axe du trou, pointe vers l'avant |
| #40 Reine des Cent Lames | percé | épée dans l'axe du trou, lame levée devant elle |
| #42 Géant au Cœur de Verre | percé | marteau dans l'axe du trou, tête devant, talon derrière |
| #34 Chasseur de Comètes | fermé | manche le long des doigts, centré, tête en bas |
| #44 Chevalier de l'Éclipse Blanche | fermé | masse pendante, manche centré |
| #50 Chevalier aux Mille Clous | fermé | manche centré, tête en bas |
| #59 Chevalier de l'Aube Infinie | fermé | épée pointe en bas, inclinée vers l'avant (hors du socle) |

- Ces 9 Prises portent `PriseControlee` (le centre du poing mesuré par l'enveloppe contredit le trou
  réel sur #24 et #42).
- Restent tournés à 60° depuis le premier correctif, non signalés : #04, #27, #29, #47, #52, #54, #57,
  #61, #62.
- Copies de jeu mises à jour : #04, #24, #27, #29 (seules présentes parmi ces héros).
- Sauvegardes avant correction : `ServerStorage.Sauvegarde_Prises`.

| Contrôle | Résultat |
| --- | --- |
| Captures rapprochées des 9 mains, arme masquée puis visible | PASS |
| `Kit.checkGrips` sur les 60 modèles du Bestiaire | PASS (0 problème) |
