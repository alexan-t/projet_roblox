# Contrôle qualité visuel — PASS ou FIX

Protocole commun aux monstres, aux boss et aux futurs personnages. Il se fait **sur des captures réelles de Studio**, jamais de mémoire ni à partir des paramètres de génération.

## 1. Captures obligatoires

| # | Vue | Distance (petit / boss) | But |
|---|---|---|---|
| 1 | Face, à hauteur de poitrine | 6–10 / 18–25 studs | visage, silhouette, équipement |
| 2 | Trois-quarts avant | idem | volumes, couches |
| 3 | Profil | idem | armes, bouclier, posture, clipping |
| 4 | Dos ou trois-quarts arrière | idem | bannière, cape, accessoires |
| 5 | Loin, légèrement en plongée | 30–60 studs | lisibilité en jeu |
| 6 | Gros plan du visage (si visage) | 3–5 studs | expression, défauts de texture |

Ajouter une capture **à côté d'une référence validée** (`GobLanceT_A`, `KingTreant`, etc. ; voir `ART_DIRECTION.md` § 1) pour comparer l'échelle et le style.

Avant de juger : si une pièce est grise ou noire, attendre et recapturer, car c'est souvent un chargement. Si elle le reste, c'est un défaut (FIX, `MONSTER_PRODUCTION.md` Outils § E).

Après la dernière capture : **réinitialiser la caméra** (`MONSTER_PRODUCTION.md` Outils § A).

## 2. Grille de contrôle

Chaque ligne est notée **OK** ou **KO**. Un seul KO bloquant suffit à donner FIX.

| Critère | Question | Bloquant |
|---|---|---|
| Silhouette | Le contour seul (capture 5) identifie-t-il la créature ou le héros ? A-t-il 3 masses et 1 à 2 éléments qui dépassent ? | oui |
| Proportions | Haut du corps lourd, jambes courtes, mains fortes (ART_DIRECTION § 3 / CHARACTER § 2) ? Hauteur dans la bonne tranche ? | oui |
| Volumes | Formes gonflées et arrondies, couches superposées ? Aucune boîte ni facette low-poly visible ? | oui |
| Lisibilité | Un point focal (yeux, cœur, gemme) visible de loin ? Aucun détail essentiel sous 0,5 stud ? | oui |
| Cohérence DA | Au moins 5 des 8 points de ART_DIRECTION § 14 ? Rien de la liste § 15 (hors DA) ? | oui |
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

## 3. Verdict

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

Après correction : **nouvelles captures**, puis nouveau passage de la grille entière. On boucle jusqu'au PASS.

## 5. Rapport attendu

```
Créature : <nom> (<Workspace path>)
Captures : 1..6 (+ comparaison avec <référence>)
Grille : <critère> OK/KO …
Verdict : PASS | FIX
Défauts (si FIX) : …
Corrections appliquées : …
```
