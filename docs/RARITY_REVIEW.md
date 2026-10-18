# Rareté : coordination de la revue des PR (18 octobre)

Les règles sont dans `docs/UI_DESIGN_SYSTEM.md` § 2, « Rendu des raretés ». Ce fichier dit
**dans quel ordre** relire et fusionner les PR qui touchent à la rareté, et **ce que chacune doit
changer** pour s'y conformer. Il se vide au fil des fusions : une PR fusionnée sort de la liste.

## Pourquoi

Quatre branches ont modifié la rareté chacune de leur côté, toutes depuis `4736922` (avant
Invocation V2 #80, Expédition #82 et icônes #83). Elles sont **en conflit** avec `develop` et se
contredisent :

| Sujet | #61 items | #75 repère | #62 VISUAL_QA | `develop` (#80) |
| --- | --- | --- | --- | --- |
| Couleur sur une carte d'item | oui (zone d'illustration) | — | **interdite** | cadre neutre |
| Couleur seule pour dire la rareté | oui (carte d'item) | **interdite** | — | libellé à côté |
| Accès à `UITheme.Rarity` | via `RarityStyle` | via `RarityStyle` (testé) | — | 3 accès directs |
| Rendu de la carte de héros | — | badge + pastille sur `SummonView` | — | 10 cadres PNG figés |

Arbitrage : règles 1 à 7 du § 2. En bref : une palette, jamais la couleur seule, accès par
`RarityStyle`, état ≠ rareté, maquette Invocation V2 prioritaire sur ses écrans, couleur des
items sur la carte et jamais dans l'icône.

## Ordre de revue et de fusion

1. **Cette branche** (arbitrage) : règles du § 2, tokens `DropChanceLow` / `Guarantee`, plus
   aucun accès direct à `UITheme.Rarity` hors `RarityStyle` (`HeroCard`, `SummonLayout`,
   `ExpeditionView`), test `tests/rarity-rules.test.mjs`.
2. **#75** (repère de forme), rebasée sur `develop`.
3. **#61** (couleurs des items), rebasée **après** #75 : elle en a besoin (`RarityStyle.chip`).
4. **#62** (grille VISUAL_QA), rebasée, wording corrigé.
5. **#65** (tokens d'effets), rebasée : vérifier qu'elle ne touche pas la rareté.

Une PR n'est relue qu'une fois rebasée et verte (`node tests/*.test.mjs`). Chaque relecteur
coche les points de sa PR ci-dessous dans son commentaire de revue.

## Changements demandés par PR

### #75 — second repère, forme ou motif

- Rebaser sur `develop`. Abandonner les modifications de `SummonView.lua` : la vue a été réécrite
  par #80 (maquette figée, règle 5).
- Garder `UITheme.RarityMark`, `RarityStyle.mark` / `chip` et le tableau à trois colonnes du § 2.
- Placer le repère seulement là où la maquette montre déjà une rareté en ligne ou en pastille :
  liste des taux (`SummonLayout`, ligne de `Rarity.name(rate.Id)`) et pastilles du résumé
  x10/x100 (`SummonReveal`, remplacer le carré `dot` par `RarityStyle.chip`). Pas de badge
  ajouté sur `HeroCard` : les cadres PNG et le libellé portent la rareté.
- Le test « no client view shows a rarity by its color alone » doit passer sur `develop` tel
  qu'il est (accès directs déjà retirés ici). Garder le point 8 du § 11 tel que rédigé ici.
- Captures avant/après de la fenêtre Taux et du résumé x10, en couleur et désaturées.

### #61 — couleurs de rareté des items

- Rebaser **après** #75. Dans le § 2, remplacer son paragraphe « Rendu commun… » par un renvoi
  aux règles arbitrées (pas de seconde version des mêmes règles) ; « une barre » s'entend barre
  de PV, d'énergie ou de progression (règle 4), pas la barre des rangs de l'invocation.
- `RarityStyle.itemCard` ajoute `RarityStyle.chip` dans un coin bas de la zone d'illustration
  (règle 6) : sans libellé sur la carte, la teinte seule est refusée (règle 2).
- `Transparency.RarityTint` : garder le token, l'ajouter au § 3 et au § 9.
- Mettre à jour `docs/ITEMS.md` § 2 (remplacer le paragraphe « Arbitrage du 18 octobre ») et la
  ligne « Items 2D » du § 6 : retirer « tant que #61 n'est pas fusionnée ».
- Vérifier qu'aucune icône PNG n'est teintée et que la vitrine Studio (`Workspace.Bestiaire.
  Inventaire.Equipement`) est repeinte une fois par script outil (`tools/`), pas à la main.
- Capture de la rangée Légendaire équipée (or de la rareté ≠ contour `Selected`) et d'une rangée
  Épique à côté d'une rangée Maudit, en couleur et désaturées.

### #62 — grille VISUAL_QA

- Remplacer « Aucune couleur de rareté sur un monstre ou un item ? » par « Aucune couleur de
  rareté sur un monstre ou une ressource ? Sur un item, seulement sur la carte (zone
  d'illustration), jamais dans l'icône ? ».
- Ajouter au critère « Couleurs » : « Rareté jamais par la couleur seule (libellé ou repère) ;
  contrôle sur capture désaturée ».
- Ligne « Intégration » des icônes : « le cadre extérieur reste neutre » (la zone d'illustration
  peut être teintée).

### #65 — tokens des effets

- Rebaser. Les couleurs d'effet par rareté passent par `RarityStyle.sequence` / `colorAt` (déjà le
  cas de `SummonEffectController`) ; aucun nouveau token ne doit dupliquer `UITheme.Rarity`
  sous un autre nom.

## Reste à faire par l'équipe (hors dépôt)

- Captures Studio de la fenêtre Taux, du résumé x10/x100 et de l'Expédition (chances de butin)
  après fusion de cette branche, puis contrôle `docs/VISUAL_QA.md` : le rendu doit être identique
  (même hex), sauf l'étincelle des cartes Maudit, maintenant `#7B2FA8` comme la maquette
  `HeroCard.dc.html` (avant : `#A45BE0`, la couleur d'Épique).
- Les rebasages et relectures listés ci-dessus (auteurs et relecteurs de chaque PR).
