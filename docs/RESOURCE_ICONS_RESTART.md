# Reprise des 24 icônes en revue humaine

Revue des briefs du catalogue et des états persistants le 18 octobre 2026.
Ce document prépare la reprise ; il ne constitue ni une validation humaine,
ni un PASS, ni une remise à zéro des trois itérations consommées.
La limite de `automation/TASK_FORMAT.md` reste applicable.

## Constats vérifiés

Studio « test 3 », placeId `120616399792561`, en Edit : 36 images renseignées,
24 emplacements vides ; `Workspace.AtelierIcones` vide. Aucune mutation Studio
effectuée pendant cette revue. Les briefs originaux de
`automation/catalogues/resources.json` restent la source de vérité.

Les six captures `automation/screenshots/resources/resource_026-third-fix.jpg`
et `resource_{031,036,040,059,060}-third.jpg` ont été ouvertes et examinées.
Elles confirment les six FIX de `RESOURCE_ICONS_QA.md`.
Les erreurs techniques de génération ne permettent aucun verdict visuel sur
les objets qui n'ont pas été produits.

## Construction et contrôle à préparer par famille

Les propositions suivantes sont des corrections à examiner en revue humaine.
Elles ne remplacent aucun élément du brief. Pour les échecs techniques,
la décomposition proposée est une piste, sans garantie de génération.

| Id | Construction proposée | Contrôle déterminant avant export |
| --- | --- | --- |
| 020 | Fragment de couronne cassé incliné dans une flaque bleue ; construire séparément métal et gelée. | Cassure visible, pointes rondes, moitié inférieure du fragment immergée ; aucune couronne entière. |
| 025 | Plume brun-roux en une masse courbe, extrémité rouge et lien de cuir épais à la base. | Plume, pointe rouge et attache identifiables à 32 px. |
| 026 | Préparer un rivet texturé, puis trois exemplaires disposés en triangle sans occultation. | Compter exactement trois têtes bombées distinctes ; fer gris et rouille brune sur les bords. |
| 029 | Une défense courbe unique ; ajouter le cerclage de cuir sombre à sa base. | Une seule pointe d'ivoire crème et attache visible. |
| 030 | Corne massive ivoire/os ; anneau de fer riveté ; pic d'os à la base orienté vers la caméra. | Pic distinct du corps de la corne en trois quarts et à 32 px. |
| 031 | Refaire le volume en ovale aplati lisse ; mousse sur un coin et reflet clair peint. | Surface polie continue ; aucune tranche cylindrique ni face plane dominante. |
| 036 | Masse d'or pleine irrégulière avec bosses arrondies et reflet supérieur gauche. | Lecture de métal doré, aucune cavité circulaire donnant un aspect de fromage. |
| 040 | Motte basse rouge-brun ; une dépression ovale de pouce sur le dessus. | Creux unique visible en plongée ; aucun doigt, aucune paume ni empreinte complète. |
| 041 | Éclat cyan pointu à deux grandes facettes ; cœur doucement lumineux. | Deux facettes larges lisibles, un seul foyer lumineux ; conserver les facettes demandées par ce brief. |
| 044 | Noyau de bois rond à veines spiralées ; fente cyan centrale. | Bois dominant, spirale visible, lumière contenue dans une seule fente. |
| 045 | Cage de fer noir rivetée autour d'une braise orange ; ouverture orientée vers la caméra. | Cage et braise lisibles simultanément ; braise unique, barreaux épais sans masquer le centre. |
| 046 | Feuille verte recourbée en coupe puis goutte bleu pâle au creux. | Goutte attachée à la feuille, silhouettes distinctes à 32 px. |
| 047 | Flacon rond à long col, liquide vert feuille, bouchon de liège et lien. | Col, bouchon et liquide identifiables ; conserver le verre sans perdre la silhouette. |
| 048 | Galet gris lisse avec grande spirale gravée cyan. | Spirale visible sur la face exposée, lueur douce unique ; distinguer de la rune en losange de 033. |
| 049 | Encrier trapu en bois sombre ; surface d'encre bleu-noir ; plume crème insérée. | Base en bois lisible, plume attachée au goulot et contraste de l'encre. |
| 050 | Orbe laiteux bleu-gris, cerclage bronze et pied court. | Verre trouble dominant ; anneau et petit pied visibles, pas de grand socle. |
| 051 | Trois planches claires distinctes empilées en travers, bouts nets, veines peintes. | Compter trois planches ; extrémités dégagées et épaisseur lisible. |
| 052 | Lingot gris bas, trapu, arêtes adoucies ; losange frappé sur la face supérieure. | Lecture de lingot massif sans rebord ni pied ; marque gravée, pas une plaque dressée. |
| 054 | Rouleau de corde beige en brins tressés épais ; bout pendant détaché du contour du rouleau. | Boucle et extrémité reconnaissables à 32 px ; tressage sans traits fins. |
| 055 | Rouleau épais de toile crème, bande rouge royal au bord, ficelle nouée. | Tranche roulée, bande et nœud visibles sans multiplication des accents. |
| 057 | Trois tuiles courbes rouge-brun empilées avec léger décalage. | Trois tranches distinctes et courbure visible ; bords arrondis. |
| 058 | Parchemin crème roulé à bords irréguliers, ruban rouge noué au milieu. | Ruban central et extrémités roulées visibles ; aucun texte. |
| 059 | Tissu bleu royal plié en carré, liseré or ; repli couvrant la moitié de la tour. | Pliage carré lisible ; demi-emblème visible, sans barre de suspension. |
| 060 | Bloc d'angle beige trapu, emblème du royaume doré incrusté sur la face avant. | Deux faces en trois quarts ; emblème affleurant, absence de pied et de silhouette de pilier. |

## Séquence après résolution de la revue humaine

1. Conserver les preuves et le compteur historique ; consigner la décision de reprise
   avant de modifier le statut `human_review`.
2. Travailler une famille à la fois dans `Workspace.AtelierIcones`, inspecter une
   référence principale dans Studio et enregistrer une étape d'annulation.
3. Construire et cadrer les objets en trois quarts ; capturer avec `screen_capture`.
   Vérifier le contrôle déterminant ci-dessus avant l'export et la publication.
4. Exporter `assets/icons/resources/resource_NNN.png`, transparent 512 × 512,
   contour Ink, objet occupant environ 80 % du cadre ; contrôler à 32 px.
5. Publier le PNG via `upload_image`. Reporter uniquement l'identifiant d'image
   retourné dans `Illustration.Icone.Image`, l'attribut `AssetId` de la carte
   réservée et `ResourceConfig.lua`.
6. Capturer chaque carte et sa famille ; appliquer toute la grille adaptée de
   `docs/RESOURCE_ICONS_QA.md` et `docs/VISUAL_QA.md`. Seul PASS permet `done`.
7. Vérifier les correspondances carte/catalogue, vider l'atelier, supprimer tout
   script temporaire et réinitialiser la caméra selon `MONSTER_PRODUCTION.md`.

Les 24 PNG, leurs publications, leurs cartes, leurs champs `Icon` et leurs PASS
restent à produire. Aucun nouvel AssetId n'est attribué par cette revue.
