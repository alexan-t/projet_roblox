# Icônes des ressources — bilan Studio du 18 octobre 2026

Place : **test 3**, placeId `120616399792561`. Aucun push ni changement de branche.
La mission reste **incomplète : 36/60 icônes renseignées**. Le bilan de la dernière reprise
figure ci-dessous ; les sections suivantes conservent les preuves de la reprise précédente.

## Troisième passe de production — état de référence

Les 28 identifiants restants ont tous été retentés. Quatre nouvelles icônes sont livrées :

| Ressource | AssetId image final | Verdict |
| --- | --- | --- |
| 033 — Pierre Runique | `rbxassetid://101845461360071` | **PASS** |
| 034 — Plaque d'Ardoise | `rbxassetid://112375498120224` | **PASS** |
| 037 — Minerai de Cuivre | `rbxassetid://126822675435008` | **PASS** |
| 038 — Morceau de Charbon | `rbxassetid://71582478481177` | **PASS** |

Sources finales : `assets/icons/resources/resource_{033,034,037,038}.png` ; PNG transparents
512 × 512 avec contour Ink, issus de captures Studio de modèles dans `Workspace.AtelierIcones`.
Captures : `automation/screenshots/resources/resource_NNN-third.jpg`,
`cardNNN-third.jpg`, `minerow-third.jpg`, `minefamily-third.jpg` et
`reference-orc-third.jpg`. Le montage `delivered-readability.png` montre les 36 PNG à 96 et 32 px.

| Critère adapté aux objets | 033 | 034 | 037 | 038 |
| --- | --- | --- | --- | --- |
| Silhouette, lecture à 32 px | OK : pierre et rune | OK : plaque en couches | OK : roche veinée | OK : charbon et braise |
| Volumes et vue trois quarts | OK | OK | OK | OK |
| Matières, palette, cohérence avec les voisines et référence Orc | OK | OK | OK | OK |
| Contour Ink, transparence, cadrage | OK | OK | OK | OK |
| Géométrie, détails attachés, point focal unique au plus | OK | OK | OK | OK |
| Brief, aucune rareté, texte ni quantité dans l'image | OK | OK | OK | OK |
| Carte, Image = AssetId = Icon Git | OK | OK | OK | OK |

Les critères de visage, membres et posture ne s'appliquent pas. La pierre runique et le charbon
ont été tournés de 180° pour exposer leur motif. Le contrôle des 60 cartes contre le catalogue Git
donne **36 images, 24 vides, zéro divergence** (identifiant, index, nom, Image et AssetId).
Les quatre cartes et leur rangée ont été contrôlées sur captures après publication.

### Travail restant après cette passe

| Famille | Livrées | Manquantes — lot FIX |
| --- | --- | --- |
| Forêt | 10/10 | aucune ; production précédente conservée |
| Slimes | 9/10 | 020 |
| Horde | 6/10 | 025, 026, 029, 030 |
| Mine | 7/10 | 031, 036, 040 |
| Arcane | 2/10 | 041, 044, 045, 046, 047, 048, 049, 050 |
| Royaume | 2/10 | 051, 052, 054, 055, 057, 058, 059, 060 |

Six modèles refusés, avec preuves `resource_NNN-third*.jpg` conservées hors des assets livrés :

| Ressource | Défaut visible (FIX) | Correction requise |
| --- | --- | --- |
| 026 | Deux têtes de rivets visibles, même en plongée | Construire trois rivets distincts et les disposer sans occultation |
| 031 | Galet cylindrique à faces planes ; rotation insuffisante pour le rendre poli | Refaire un galet ovale aplati, surface lisse et mousse limitée à un coin |
| 036 | Sphère orange trouée, lecture de fromage | Refaire une pépite irrégulière pleine, bosses arrondies et reflets dorés |
| 040 | Empreinte de main entière sur une motte dressée | Refaire une motte basse avec une seule empreinte de pouce sur le dessus |
| 059 | Bannière suspendue sur une barre, emblème entier | Refaire un carré de tissu plié avec demi-emblème caché |
| 060 | Pilier haut à socle, écusson en relief | Refaire un bloc d'angle trapu avec emblème incrusté |

Les 18 autres essais ont échoué avec **Unable to generate Model** : 020, 025, 029, 030,
041, 044, 045, 046, 047, 048, 049, 050, 051, 052, 054, 055, 057 et 058.
Résultats bruts : `automation/screenshots/resources/generation-third-2026-10-18.json`.
Les identifiants de modèles générés ne sont pas des identifiants d'image à reporter dans le code.
Ne pas relancer indéfiniment : cette troisième tentative succède aux essais consignés dans
`generation-results.json` et `generation-retry-2026-10-18.json`. Les 24 ressources restantes
nécessitent une reprise contrôlée avec revue humaine des briefs/modèles refusés selon
`automation/TASK_FORMAT.md`, puis PNG, publication, carte, code et QA. Le catalogue de tâches
reste au format initial attendu par les tests ; ce rapport fait foi pour l'état de livraison.

Nettoyage de fin : atelier vidé, aucun script laissé, caméra recréée puis remise en `Fixed`.
Aucun push, changement de branche ou publication de la place. Seules les images validées ont été
publiées, conformément à la mission. Les 13 tests Node du catalogue passent ; 36 PNG en 512 × 512.

## Historique — reprise précédente (32/60)

## Contrôle des nouvelles livraisons

| Ressource | AssetId image final | Verdict |
| --- | --- | --- |
| `resource_021` — Lambeau de Tissu Rouge | `rbxassetid://86238190807240` | **PASS** |
| `resource_022` — Lanière de Cuir | `rbxassetid://124467689473100` | **PASS** |

Sources : `assets/icons/resources/resource_021.png` et `resource_022.png`, PNG transparents
512 × 512 issus de captures de modèles 3D construits dans `Workspace.AtelierIcones`.
Les AssetId des modèles 3D ne servent jamais d'icônes.

Captures réelles (dans `automation/screenshots/resources/`) :

- `resource_021-studio.jpg`, `resource_022-retry.jpg` : objets en trois quarts avant détourage.
- `resource_021-carte.jpg`, `resource_022-carte.jpg` : cartes après publication des images finales.
- `horde-rang-retry-final.jpg` : comparaison avec les voisines et visibilité des emplacements vides.
- `delivered-readability.png` : montage des PNG à 96 et 32 px ; complément des captures Studio.
- `reference-treant.jpg`, `reference-slime-king.jpg` : références principales de la production.

Grille adaptée aux objets, selon `RESOURCES.md` § 4–5 et `VISUAL_QA.md` :

| Critère | 021 | 022 |
| --- | --- | --- |
| Silhouette et lecture à 32 px | OK : tissu noué, extrémités déchirées | OK : rouleau, boucle visible |
| Volumes arrondis et superposés | OK | OK |
| Vue trois quarts et occupation du cadre | OK | OK |
| Matière, palette et cohérence avec les voisines | OK : rouge et plis ombrés | OK : cuir sombre et fer gris |
| Contour Ink, transparence, absence de fond résiduel | OK après correction du détourage | OK |
| Géométrie et accroche des détails | OK | OK |
| Brief, absence de texte, quantité et rareté dans l'image | OK | OK |
| Carte, Image = AssetId = Icon du code | OK | OK |

Les critères de visage, membres, posture et équipement porté ne s'appliquent pas à ces objets.
`resources.json` reste un catalogue de tâches modèles (`todo`, captures vides), comme l'exigent
les tests existants ; les notes 021/022 renvoient à cette review et aux AssetId livrés.
Le premier export 021 supprimait des reflets violets : le seuil magenta a été resserré,
puis le PNG réexporté et republié. L'ancienne image `rbxassetid://140086618576004` est remplacée
par `rbxassetid://86238190807240`. Le cadrage 022 a été tourné pour exposer la boucle.

## Lots et travail restant

| Famille | Icônes renseignées | Verdict de livraison du lot |
| --- | --- | --- |
| Forêt | 10/10 | Production précédente conservée ; pas de nouvelle validation complète de ce lot |
| Slimes | 9/10 | **FIX** : 020 manquante |
| Horde | 6/10 | **FIX** : 025, 026, 029, 030 manquantes |
| Mine | 3/10 | **FIX** : 031, 033, 034, 036, 037, 038, 040 manquantes |
| Arcane | 2/10 | **FIX** : 041, 044, 045, 046, 047, 048, 049, 050 manquantes |
| Royaume | 2/10 | **FIX** : 051, 052, 054, 055, 057, 058, 059, 060 manquantes |

### Six modèles générés mais refusés

Ces essais restent dans les captures de travail, sans PNG livré ni nouvel AssetId image dans
le code ou la vitrine. Leurs exports transparents 512 × 512 sont conservés pour review sous
`automation/screenshots/resources/<resource_id>-retry-fix-512.png`.
Les modèles temporaires ont été supprimés de l'atelier après contrôle.

| Ressource | Défaut visible sur `<resource_id>-retry.jpg` | Correction nécessaire |
| --- | --- | --- |
| 020 | Couronne entière posée sur une petite flaque ; pas de fragment à moitié noyé | Refaire une couronne cassée inclinée, base partiellement immergée |
| 026 | Quatre têtes de rivets visibles, au lieu de trois | Refaire trois rivets séparés et composer le groupe |
| 029 | Deux pointes d'ivoire, au lieu d'une défense courbe | Refaire une défense unique cerclée de cuir |
| 030 | Corne et cerclages visibles, mais aucun pic d'os distinct à la base | Refaire une base avec pic intégré ; l'ajout de Parts n'a pas rendu le pic visible sur la capture |
| 052 | Plaque à pied, puis forme à rebord après rotation ; ne se lit pas comme un lingot | Refaire un lingot bas et trapu, losange gravé sur le dessus |
| 059 | Bannière déployée, emblème entier, extrémité pointue | Refaire un pliage carré avec emblème partiellement caché |

### Vingt-deux échecs techniques

`resource_025` : **Failed to publish assets — Too Many Requests**.

**Unable to generate Model** pour : 031, 033, 034, 036, 037, 038, 040, 041, 044, 045,
046, 047, 048, 049, 050, 051, 054, 055, 057, 058 et 060.

Résultats bruts : `automation/screenshots/resources/generation-retry-2026-10-18.json`.
Les échecs précédents restent dans `generation-results.json`. Ne pas confondre réussite de
génération et PASS visuel. Les prochaines reprises doivent traiter ces 28 identifiants,
exporter leur PNG, publier leur image, renseigner leur carte, reporter leur Icon et contrôler
chaque carte ainsi que la rangée. Respecter la limite d'itérations de `TASK_FORMAT.md`.

## Vérification technique et limites

- Comparaison directe des **60 cartes** au catalogue Git : **32 images renseignées, 28 vides,
  zéro écart** sur ResourceId, Index, libellé de Famille, Nom, Image et AssetId.
- Le module `ReplicatedStorage.Shared.Config.ResourceConfig` est absent dans cette session
  Studio. Le contrôle de vitrine a donc été exécuté avec le contenu du catalogue Git évalué
  en mémoire, sans créer de Script ou ModuleScript dans la scène. Reconnecter Rojo avant
  de relancer directement `tools/studio-resources-vitrine.luau`.
- Les 13 tests Node du catalogue et les 5 tests Luau purs passent ; ces derniers ont été
  exécutés en mémoire dans Studio, sans création de script. Les 32 PNG livrés ont les
  dimensions 512 × 512.
- Nettoyage vérifié : `Workspace.AtelierIcones` a zéro enfant ; caméra recréée puis remise
  en mode `Fixed` selon la procédure du projet. Serveur HTTP local d'upload arrêté.
- Aucun système de stockage, d'obtention ou de crafting n'est ajouté par cette mission.
