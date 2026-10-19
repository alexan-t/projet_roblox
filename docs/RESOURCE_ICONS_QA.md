# Icônes des ressources — bilan Studio

## État final — 19 octobre 2026

**PASS : 60/60 icônes livrées.**

Les 15 dernières ressources (020, 030, 036, 040, 041, 044, 045, 046, 048, 050, 051, 054, 055, 059, 060)
ont été reconstruites à la main dans Studio, sans `generate_mesh` ni `generate_procedural_model`.
Chaque ressource possède désormais :
- un PNG transparent 512 × 512 dans `assets/icons/resources/` ;
- un AssetId publié unique dans `ResourceConfig.lua` ;
- une carte Studio conforme (`Icone.Image = AssetId = Icon Git`) ;
- un rapport PASS `automation/reviews/resource_NNN-handbuilt.md` avec captures de lisibilité.

Audit Studio final : 60 cartes conformes au Git, 60 images, 0 vide ; `Workspace.AtelierIcones` vide.
Les 15 modèles construits à la main sont archivés dans
`ServerStorage.Archive_ResourceIcons_Handbuilt_20261019`.

Validation technique : suite Node **14/14**, acceptation 60/60 PASS, AssetIds et PNG uniques,
RGBA 512 × 512 avec transparence. La spec ResourceConfig a aussi été exécutée en mémoire dans Studio.
Le CLI Luau local n'a pas été relancé dans ce worktree car `build/luau-cli/luau.exe` y était absent.

Les sections ci-dessous sont conservées comme **historique de production** et ne décrivent plus l'état courant.

# Historique — bilan Studio du 18 octobre 2026

## État final de la nouvelle série autorisée

**45/60 livrées ; 15 en human_review.** Les paragraphes ci-dessous cette section
conservent les bilans historiques à 36/60 ; ils ne décrivent plus l'état courant.

Neuf ressources livrées par la reprise précédente : 025, 026, 029, 031, 047, 049,
052, 057, 058. Leurs PASS et captures sont dans `automation/reviews/resource_NNN-resume.md`.
Les commits de livraison sont conservés ; aucune de ces images n'a été remplacée ici.

Dernier essai sur chacune des quinze restantes : 020, 030, 036, 040, 041, 044,
045, 046, 048, 050, 051, 054, 055, 059, 060. Tous les appels ont échoué avec
`Mesh generation failed with error: Unable to generate Model`.
Résultats bruts et jobId :
`automation/screenshots/resources/generation-final-resume-2026-10-18.json`.
Chaque état pointe désormais vers son rapport `automation/reviews/resource_NNN-final-resume.md` :
FIX de livraison, human_review, aucun nouveau PASS artistique sans objet ni capture.

Audit Studio final dans test 3 : **60 cartes conformes à Git, 45 images, 15 vides**,
aucun écart de ResourceId, Index, Famille, Nom, Image ou AssetId.
Les 34 enfants hérités de l'atelier ont été déplacés, sans destruction, dans
`ServerStorage.Archive_ResourceIcons_Restart_20261018` ; étape ChangeHistory enregistrée.
Atelier vide. Caméra Fixed lors de l'audit ; aucune nouvelle screen_capture dans cette reprise.
Ni push, ni changement de branche, ni publication de place.

Tests : Node ciblés 11 réussites / 1 échec (acceptation 60/60 : 15 manquantes).
Les contrôles catalogue et intégrité des PNG livrés passent. Le CLI Luau local
est absent ; même spec ResourceConfig exécutée avec succès dans Studio, en mémoire.
Voir `tests/RESOURCE_ICONS_RESULTS.md` pour les commandes et limites.

Revue de reprise : [RESOURCE_ICONS_RESTART.md](RESOURCE_ICONS_RESTART.md).
Les 24 briefs ont été relus et les six captures refusées de la troisième passe
examinées ; des constructions correctives et critères de contrôle sont proposés
pour chaque ressource. Les états `human_review` et les compteurs restent inchangés.
Aucune nouvelle génération, publication ou validation PASS pendant cette revue.

Place : **test 3**, placeId `120616399792561`. Aucun push ni changement de branche.
La mission reste **incomplète : 36/60 icônes renseignées**. Le bilan de la dernière reprise
figure ci-dessous ; les sections suivantes conservent les preuves de la reprise précédente.

## Contrôle de reprise — états persistants

Contrôle en lecture seule dans Studio « test 3 » : 60 emplacements, 36 images renseignées,
24 vides, zéro divergence avec Git sur ResourceId, Index, Famille, Nom, Image et AssetId.
Les 36 PNG présents sont tous en 512 × 512 ; les 13 tests Node du catalogue passent.
`Workspace.AtelierIcones` est vide. Aucune nouvelle icône ni validation visuelle n'est produite
par ce contrôle technique ; les verdicts précédents restent ceux des captures référencées.

Les 24 ressources manquantes ont désormais chacune leur fichier
`automation/state/resource_NNN.json`, à l'état `human_review`, avec les trois passes historiques,
les preuves et les étapes restantes. Cela applique `TASK_FORMAT.md` : « Si `max_iterations` est
atteint sans PASS, utiliser `human_review`. Ne jamais boucler indéfiniment. »
Ces états de reprise sont séparés de `resources.json`, qui reste le catalogue de tâches modèles.
Une reprise doit lire ces fichiers avant de lancer une nouvelle génération ; le compteur zéro
des modèles du catalogue n'annule pas les essais réellement effectués.

La prochaine étape est la revue des briefs et des défauts listés ci-dessous, puis une reprise
de production contrôlée. Aucun nouvel AssetId, script Studio ou changement de scène n'a été
introduit pendant ce contrôle. Aucun push ni changement de branche.

## Troisième passe de production — état de référence

Les 28 identifiants restants ont tous été retentés. Quatre nouvelles icônes sont livrées :

| Ressource | AssetId image final | Verdict |
| --- | --- | --- |
| 033 — Pierre Runique | `rbxassetid://135985670826077` | **PASS** |
| 034 — Plaque d'Ardoise | `rbxassetid://89919539137406` | **PASS** |
| 037 — Minerai de Cuivre | `rbxassetid://84553181426386` | **PASS** |
| 038 — Morceau de Charbon | `rbxassetid://96000412157071` | **PASS** |

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
| `resource_021` — Lambeau de Tissu Rouge | `rbxassetid://82653946935805` | **PASS** |
| `resource_022` — Lanière de Cuir | `rbxassetid://127458461513892` | **PASS** |

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
par `rbxassetid://82653946935805`. Le cadrage 022 a été tourné pour exposer la boucle.

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
