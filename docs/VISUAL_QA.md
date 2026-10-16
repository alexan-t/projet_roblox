# Contrôle qualité visuel — PASS ou FIX

Protocole commun à **tout ce qui se voit** : monstres, boss, futurs personnages, interfaces, icônes et effets visuels (VFX). Il se fait **sur des captures réelles de Studio**, jamais de mémoire, ni à partir des paramètres de génération, ni à la lecture du code.

| Livrable | Captures | Grille | Rapport |
|---|---|---|---|
| Monstre, boss, personnage | § 1 | § 2 | § 5 |
| Interface (HUD, fenêtre, carte, panneau du monde) | § 6.1 | § 6.2 | § 6.3 |
| Icône (item, ressource, monnaie, classe, objet d'UI) | § 7.1 | § 7.2 | § 7.3 |
| Effet visuel (attaque, ultime, dégâts, mort, invocation, ambiance) | § 8.1 | § 8.2 | § 8.3 |

Pour tous : le verdict suit § 3 (**PASS** ou **FIX**, rien d'autre), un FIX se rédige selon § 4, et **pas de PASS sans capture**. Un livrable qui en touche plusieurs (ex. l'écran d'invocation : fenêtre + effet 3D + icônes) passe **chaque** grille concernée.

## 1. Captures obligatoires (créatures)

| # | Vue | Distance (petit / boss) | But |
|---|---|---|---|
| 1 | Face, à hauteur de poitrine | 6–10 / 18–25 studs | visage, silhouette, équipement |
| 2 | Trois-quarts avant | idem | volumes, couches |
| 3 | Profil | idem | armes, bouclier, posture, clipping |
| 4 | Dos ou trois-quarts arrière | idem | bannière, cape, accessoires |
| 5 | Loin, légèrement en plongée | 30–60 studs | lisibilité en jeu |
| 6 | Gros plan du visage (si visage) | 3–5 studs | expression, défauts de texture |

Ajouter une capture **à côté d'au moins une référence PRINCIPALE** (`KingTreant`, `Treant_Masque`, `KingSlime` ou `RoiOrc` ; voir `ART_DIRECTION.md` § 1.1) pour comparer le style, la finition et la présence. Une référence secondaire (gobelins `GobLanceT_A` / `GobDagueT_B`, slimes) peut s'ajouter pour l'échelle d'un petit monstre, mais **ne remplace jamais** la comparaison avec une principale.

Avant de juger : si une pièce est grise ou noire, attendre et recapturer, car c'est souvent un chargement. Si elle le reste, c'est un défaut (FIX, `MONSTER_PRODUCTION.md` Outils § E).

Après la dernière capture : **réinitialiser la caméra** (`MONSTER_PRODUCTION.md` Outils § A).

## 2. Grille de contrôle (créatures)

Chaque ligne est notée **OK** ou **KO**. Un seul KO bloquant suffit à donner FIX.

| Critère | Question | Bloquant |
|---|---|---|
| Silhouette | Le contour seul (capture 5) identifie-t-il la créature ou le héros ? A-t-il 3 masses et 1 à 2 éléments qui dépassent ? | oui |
| Proportions | Haut du corps lourd, jambes courtes, mains fortes (ART_DIRECTION § 3 / CHARACTER § 2) ? Hauteur dans la bonne tranche ? | oui |
| Volumes | Formes gonflées et arrondies, couches superposées ? Aucune boîte ni facette low-poly visible ? | oui |
| Lisibilité | Un point focal (yeux, cœur, gemme) visible de loin ? Aucun détail essentiel sous 0,5 stud ? | oui |
| Cohérence DA | Au moins 5 des 8 points de ART_DIRECTION § 14 ? Rien de la liste § 15 (hors DA) ? | oui |
| Niveau de qualité | À côté des références principales, le niveau de volumes, de présence visuelle, de finition, de richesse des formes et de sophistication générale est-il **sensiblement inférieur** à celui de King Tréant, Tréant, Slime King et King Orc ? Si oui, KO. Ces quatre modèles fixent le plafond actuel de qualité et le langage artistique, **pas une complexité ni une silhouette imposées** : une créature plus simple ou plus petite peut être OK si son niveau de réalisation tient la comparaison. Ressembler aux gobelins n'est pas un défaut en soi, car ce sont des créations valides du jeu. | oui |
| Originalité | L'idée visuelle principale tient-elle en une phrase ? La créature est-elle différente de toutes les validées, et pas seulement un « gobelin, slime ou golem de fantasy » ? | oui |
| Géométrie | Pas de trous, pas de pièces retournées, pas de membre tordu, orientation face à l'avant ? | oui |
| Détails | Groupes impairs concentrés en haut, zones de repos, détails accrochés (rien ne flotte sans raison magique) ? | oui |
| Matériaux | Tout est texturé et peint (aucune pièce grise, noire ou de couleur unie) ? Matériaux de notre famille ? | oui |
| Couleurs | Base terreuse et un accent saturé ? Même teinte de peau sur la tête, les bras et les mains ? Lueur qui ne déborde pas ? | oui |
| Clipping | Aucune interpénétration visible sous les 4 angles (arme et bras, crâne et bouclier, bannière et ventre) ? | oui |
| Visage (si présent) | Expression conforme : hostile pour un monstre, déterminée pour un héros. Pas de sourire, de joues roses, de fossettes ni de groin. Pas de tache de couleur ? | oui |
| Cheveux (héros) | Grosses mèches groupées, qui participent à la silhouette ? | oui |
| Armes et accessoires | Manche dans le creux du poing, orientation correcte de profil, bouclier plaqué au poing ? | oui |
| Brief | Tous les éléments demandés sont-ils présents (arme, couleurs, rôle, taille) ? | oui |
| Zone | Matières et ambiance de la zone présentes, sans association trop évidente ? | non |
| Présence | La créature a-t-elle l'air dangereuse ou importante ? Un boss domine-t-il clairement son socle de 18 studs ? | oui pour un boss |
| Finition | Coutures, taches ou artefacts de texture visibles ? Pièces ancrées, noms propres, variantes archivées ? | non |

**Arbitrage :** si deux critères ou deux références se contredisent, on tranche selon la logique visuelle de King Tréant, Tréant, Slime King et King Orc.

## 3. Verdict

Valable pour toutes les grilles (§ 2, § 6.2, § 7.2, § 8.2) :

- **PASS** : aucun KO bloquant, et au plus 2 KO non bloquants, signalés à l'utilisateur.
- **FIX** : au moins un KO bloquant.

Il n'y a pas d'autre résultat possible.

## 4. En cas de FIX

Rédiger une liste de **défauts réellement visibles sur les captures**, chacun sous la forme :

> **[Critère] Ce qu'on voit** (capture n°, zone), puis **Correction concrète** (outil et procédure).

Exemples tirés de nos corrections réelles :
- [Visage] Sourire et joues roses (capture 6, joues) : retouche des pixels sur la texture de la tête, joues repeintes avec la teinte de peau moyenne des alentours.
- [Visage] Nez en groin de cochon de profil (capture 3) : c'est un défaut de géométrie, donc régénérer la tête seule, recaler sur le cou et raccorder la peau au torse.
- [Armes] La lance-hache est à côté de la main (capture 3) : trouver le centre du poing par le test des 6 rayons, puis y faire passer le manche.
- [Détails] Breloques qui flottent devant le torse (capture 3) : les accrocher à la surface mesurée par raycast, ou les retirer si l'accroche est peu lisible.
- [Clipping] Crâne de ceinture dans le bouclier (`GetPartsInPart`) : déplacer le crâne sur la hanche, puis revérifier.
- [Couleurs] Tête plus vive que le corps (capture 1) : recoloration HSV de la tête sur la moyenne du torse.
- [Matériaux] Bras resté gris : `generate_texture` sur tout le modèle, sinon réenregistrer la texture.
- [Volumes] Feuillage en cubes : le remplacer par un dôme de grandes feuilles peintes.

Pour une interface, une icône ou un effet, même format : critère de la grille concernée, numéro de capture (`U2`, `I3`, `V4`…), zone, puis correction concrète (token `UITheme`, fichier et fonction, réglage de l'émetteur…).

Après correction : **nouvelles captures**, puis nouveau passage de la grille entière. On boucle jusqu'au PASS.

## 5. Rapport attendu (créatures)

```
Créature : <nom> (<Workspace path>)
Captures : 1..6 (+ comparaison avec <référence>)
Grille : <critère> OK/KO …
Verdict : PASS | FIX
Défauts (si FIX) : …
Corrections appliquées : …
```

## 6. Interfaces

Règles de référence : `UI_DESIGN_SYSTEM.md` (§ 1 à § 8) et la maquette `docs/references/ui/maquette_v1.jpg`. Concerne le HUD, les fenêtres, les cartes, les toasts et annonces, et les panneaux du monde (BillboardGui, SurfaceGui).

### 6.1 Captures obligatoires

Toujours **en Play**, interface **par-dessus le monde**. Les démonstrations sans serveur servent à afficher chaque écran : `Workspace.ApercuUI` (`Quete`, `Monnaies`, `Expedition`, `Invocation`, `Collection`, `Transition`, `Tout`) et `Workspace.ApercuEcranRecompenses` (`UI_DESIGN_SYSTEM.md` § 12).

| # | Vue | But |
|---|---|---|
| U1 | Écran entier, **fond clair** du monde derrière (sable, dallage, ciel) | transparence, lisibilité, contours |
| U2 | Écran entier, **fond sombre** derrière (forêt, bois, ombre) | lisibilité du texte et des icônes |
| U3 | Au **plus petit écran ciblé** (émulateur d'appareil de Studio, format téléphone) | `UIScale`, tailles minimales, zones tactiles, chevauchements |
| U4 | **Chaque état** visible du composant livré : normal, sélectionné, désactivé, verrouillé, vide, « Nouveau » | les états se lisent sans survol |
| U5 | Panneau du monde (si concerné) : **de près** (5–10 studs) et **de loin** (30–60 studs) | contour `ScaledSize`, lisibilité |

Ajouter une capture **à côté de la maquette** `maquette_v1.jpg` ou d'un écran déjà passé (ex. la hotbar et la sacoche) pour comparer le niveau de finition.

La capture doit **montrer l'interface**. Si l'outil de capture ne restitue pas les `ScreenGui`, elle ne compte pas : prendre une capture de la fenêtre de Studio à la place, ou demander à l'équipe de la prendre. Après la dernière capture, réinitialiser la caméra (`MONSTER_PRODUCTION.md` Outils § A).

### 6.2 Grille de contrôle

Chaque ligne est notée **OK** ou **KO**.

| Critère | Question | Bloquant |
|---|---|---|
| Monde visible | Le monde se voit-il derrière tous les panneaux (U1, U2), sauf les infobulles ? Aucun rectangle opaque plein écran, aucun voile noir plein ? | oui |
| Lisibilité | Tout le texte se lit à 100 % sur U1 **et** U2 ? Fredoka contouré `Ink` sur fond transparent, texte long (Builder Sans) uniquement sur `PanelStrong` ou infobulle ? Rien sous 14 px (`Caption`) ? | oui |
| Contours | Contour `Ink` net, qui suit les coins arrondis ? Épaisseurs `Thin` / `Regular` / `Thick` uniquement ? Aucun liseré marron semi-transparent ni `TextStroke` fin ? | oui |
| Formes | Coins arrondis aux rayons du thème ? Boutons « chunky » avec face et lèvre ? Aucun angle vif, aucun trait fin ? | oui |
| Couleurs | Base bois / sable désaturée, accents (or, rouge, bleu) rares et porteurs de sens ? Couleurs d'état justes (`Success`, `Error`, `Selected`…) ? Aucune couleur de rareté sur un monstre ou un item ? | oui |
| Hiérarchie | Un seul bouton principal visible ? Un seul badge par carte ? Une seule fenêtre modale à la fois ? Le regard va-t-il d'abord à l'information importante ? | oui |
| États | Sélectionné, désactivé, verrouillé, vide se distinguent sur U4 **sans survol** ? Sélection = un seul contour `Selected` épais ? | oui |
| Tactile et échelle | Sur U3 : zones tactiles ≥ 44 px, aucun texte tronqué, aucun chevauchement, rien sous la liste des joueurs de Roblox (haut à droite) ? | oui |
| Placement | Marge d'écran respectée ? Quête en haut à gauche, monnaies en haut au centre, fenêtres centrées ? Une information qui peut vivre dans le monde n'a pas de HUD en double ? | oui |
| Icônes | Aucune emoji, aucune icône plate générique dans une version livrée ? Les icônes passent § 7 ? | oui |
| Cohérence DA | Rien de la liste « hors DA » (`UI_DESIGN_SYSTEM.md` § 1) : dégradé glossy, texture réaliste, style futuriste ou « app mobile » ? | oui |
| Niveau de qualité | À côté de la maquette ou d'un écran déjà passé, la finition est-elle **sensiblement inférieure** ? Si oui, KO. | oui |
| Panneau du monde | (si concerné) Contour en `ScaledSize`, lisible de près et de loin (U5) ? | oui |
| Tokens | Aucune couleur, transparence, police, rayon ou durée en dur dans le Controller : tout vient de `UITheme` ? (Se vérifie dans le diff, pas à l'écran.) | oui |
| Animations | Ouverture, pop, survol courts (≤ 0,4 s), un seul rebond au maximum (`UI_DESIGN_SYSTEM.md` § 8) ? | non |
| Finition | Alignements, espacements sur la grille de 4, pixels parasites, ombre décalée propre ? | non |

### 6.3 Rapport attendu

```
Interface : <écran ou composant> (<Controller / vue>, démonstration utilisée)
Captures : U1..U5 (+ comparaison avec <maquette ou écran>)
Grille : <critère> OK/KO …
Verdict : PASS | FIX
Défauts (si FIX) : …
Corrections appliquées : …
```

## 7. Icônes

Règles de référence : `UI_DESIGN_SYSTEM.md` § 7, `ITEMS.md` § 4, `RESOURCES.md` § 4. Concerne les icônes 2D importées (`ImageLabel`) et les icônes 3D en `ViewportFrame` (`src/client/UI/Icons.lua`).

### 7.1 Captures obligatoires

| # | Vue | But |
|---|---|---|
| I1 | L'icône seule en grand (256 ou 512 px), sur fond clair **et** sur fond sombre | contour, fond transparent, frange, détails |
| I2 | À **32 px** (taille hotbar ou rangée de vitrine) | silhouette, lisibilité |
| I3 | **Dans son contexte** : carte (§ 6 du design system), pastille de monnaie, vitrine `Workspace.Bestiaire.Inventaire` | intégration, débordement, cadre neutre |
| I4 | **À côté d'au moins deux icônes validées** de la même famille (items, ressources, monnaies, classes) | cohérence de rendu |

Une série (famille de ressources, lot d'items) se contrôle aussi **en rangée entière** : une capture de la rangée remplace I2 et I4 pour toutes les icônes de la rangée.

### 7.2 Grille de contrôle

Chaque ligne est notée **OK** ou **KO**.

| Critère | Question | Bloquant |
|---|---|---|
| Objet du monde | C'est un petit objet en volume (formes chunky arrondies, matières de la map ou des créatures), pas un pictogramme plat ? | oui |
| Silhouette | Sur I2, l'objet se reconnaît au premier coup d'œil, sans le nom ? | oui |
| Cadrage | L'objet occupe environ 80 % du cadre ? Aucun détail essentiel sous 6 % de la taille ? | oui |
| Contour | Contour `Ink` cuit dans l'image (environ 6 % de la taille), régulier, sans trou ? (3D : silhouette `Ink` d'`Icons.lua`.) | oui |
| Lumière et volume | Lumière chaude venant d'en haut à gauche, légère ombre propre, vue de trois quarts ? | oui |
| Couleurs | Une couleur dominante + un accent ? Base terreuse désaturée ? Au plus **un** point lumineux (rune, cœur, cristal) ? | oui |
| Cohérence | Sur I4, même contour, même lumière, même saturation et même taille d'objet que les voisines ? | oui |
| Fond | Fond transparent, sans halo blanc ni frange autour du contour (I1 sur fond sombre) ? | oui |
| Sens | Correspond à l'`icon_hook` de sa tâche et à son `SlotType` ou à sa famille ? | oui |
| Rien d'inventé | Aucune couleur de rareté, statistique, quantité ni texte dans l'image ? | oui |
| Interdits | Aucune emoji, icône générique, trait fin, style futuriste ou photoréalisme ? | oui |
| Intégration | Sur I3, l'icône tient dans la zone d'illustration (débordement léger permis) et le cadre reste neutre ? | oui |
| Livraison | Dans **son** emplacement (`Item_NNN`, `Ressource_NNN`), `Icone.Image` et `AssetId` remplis ? Fichier source `<id>.png` en 512 × 512 (256 minimum) ? | oui |
| Finition | Artefacts de détourage, pixels isolés, bords mâchés à la réduction ? | non |

### 7.3 Rapport attendu

```
Icône(s) : <id> <nom> (<emplacement Workspace ou Icons.lua>)
Captures : I1..I4 (+ comparaison avec <icônes validées>)
Grille : <critère> OK/KO …
Verdict : PASS | FIX
Défauts (si FIX) : …
Corrections appliquées : …
```

## 8. Effets visuels (VFX)

Règles de référence : `COMBAT.md` (attaque, ultime, dégâts, mort), `SUMMON.md` (effet d'invocation par rareté), `ART_DIRECTION.md` (lueur, `Neon`, liste « mal fini »). Concerne `AttackEffectController`, `UltimateEffectController`, `DamageFeedbackController`, `DefeatEffectController`, `SummonEffectController` et les ambiances (`PortalAmbientController`, `ZoneAmbientController`, `KingdomAmbientController`).

Un effet bouge : **une seule capture ne suffit jamais**. On juge une **séquence** d'images prises aux instants clés.

### 8.1 Captures obligatoires

Démonstrations utilisables : tags `ApercuDegats` / `ApercuAllie` (dégâts), `ApercuDisparition` (mort), `Workspace.ApercuUI = "Invocation"` (invocation), ou un vrai combat en Play.

| # | Vue | But |
|---|---|---|
| V1 | Avant l'effet (même cadrage) | état de référence |
| V2 | **Montée** : charge, élan, début | lisibilité de l'intention |
| V3 | **Pic** : impact, éclat, flash | intensité, lueur, couleurs |
| V4 | **Fin** : 1 à 2 s après l'effet | rien ne reste, la scène revient à V1 |
| V5 | **Vue de jeu** : caméra du joueur, combat complet (4 héros + une vague) | lisible dans la mêlée, n'écrase pas les barres et les chiffres |
| V6 | (combat) Même effet en **vitesse x2** | synchronisation conservée |

Effets **par rareté** (invocation) : séquence V2–V4 pour la rareté livrée ou modifiée, plus le pic V3 de **Commun** et de **Légendaire** pour vérifier la gradation (`SUMMON.md`, tableau « En plus »).

Après la dernière capture, réinitialiser la caméra (`MONSTER_PRODUCTION.md` Outils § A).

### 8.2 Grille de contrôle

Chaque ligne est notée **OK** ou **KO**.

| Critère | Question | Bloquant |
|---|---|---|
| Lisibilité | Sur V2–V3, comprend-on l'action (qui frappe qui, coup de base ou ultime, quelle rareté) ? | oui |
| Forme DA | Particules et formes rondes, chunky, peintes (poussière, étincelles, feuilles, ondes) ? Rien de futuriste, d'holographique ni de réaliste ? | oui |
| Couleurs | Uniquement des couleurs de `UITheme` (`UITheme.Rarity` pour les raretés, doré pour l'ultime) ? Aucune couleur de rareté sur un effet de monstre ? | oui |
| Lueur | Sur V3, la lumière ne déborde pas et ne teinte pas les modèles voisins (cas refusé : épaules du tréant teintées de bleu) ? `Neon` réservé au point lumineux ? | oui |
| Gradation | L'intensité suit l'importance : coup de base < ultime ; Commun < Légendaire < Transcendant ; les ajouts de chaque rang (`SUMMON.md`) sont présents et seulement eux ? | oui |
| Jeu lisible | Sur V5, les barres de PV, les chiffres de dégâts et les unités restent visibles hors du pic ? | oui |
| Synchronisation | L'impact tombe sur l'instant `Impact` de l'animation ; les chiffres et la disparition l'attendent ; idem en x2 (V6) ? | oui |
| Durée | L'effet reste court et ne bloque pas la partie (mort 0,85 s, invocation selon `SUMMON.md`) ? | oui |
| Confort | Flash plein écran et secousse de caméra seulement dans les cas prévus (`SUMMON.md` : Légendaire et au-delà) ? Aucun clignotement rapide répété ? | oui |
| Nettoyage | Sur V4 et dans l'Explorer : aucun objet résiduel, modèles sources et portail non modifiés (attributs `Anim*`) ? | oui |
| Fluidité | Pas de saccade visible en V5 avec plusieurs effets simultanés ? | non |
| Finition | Particules qui traversent le sol, coupure nette d'un émetteur, ondes décalées du sol ? | non |

### 8.3 Rapport attendu

```
Effet : <nom> (<Controller>, démonstration ou combat utilisé)
Captures : V1..V6 (+ raretés comparées si invocation)
Grille : <critère> OK/KO …
Verdict : PASS | FIX
Défauts (si FIX) : …
Corrections appliquées : …
```
