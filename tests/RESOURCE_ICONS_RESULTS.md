# Résultats des tests des icônes — 18 octobre 2026

Verdict de livraison : **FIX**, 36/60 icônes livrées dans les fichiers du dépôt.
Ce rapport technique ne constitue pas une nouvelle validation artistique.
Les captures et verdicts de production restent dans `docs/RESOURCE_ICONS_QA.md`.

## Exécution

`node --test tests/*.test.mjs` : code de sortie 1 ; 11 entrées réussies,
1 échouée dans le résumé Node. Les fichiers historiques agrègent leurs propres
assertions : 9 contrôles items et 13 contrôles catalogue ressources passent.
Les 5 contrôles UI passent également.

Icônes : 4 tests réussis, 1 échoué.

- Correspondance exacte entre les 36 PNG et les entrées Icon publiées : PASS.
- Identifiants Roblox et contenus PNG uniques : PASS.
- Rejet d'un PNG volontairement corrompu : PASS.
- Rejet d'un en-tête de chunk tronqué et d'un chunk final incomplet : PASS
  (assertions ajoutées au même test de rejet des PNG corrompus).
- Décodage des 36 PNG en RGBA 512 × 512, contenu visible et pixels transparents : PASS.
  Le décodeur vérifie désormais aussi le CRC de chaque chunk et les en-têtes tronqués.
- Acceptation des 60 ressources : FIX, 24 icônes manquantes. Ce test reste bloquant.

`./tools/test-resources.ps1 -LuauPath "$PWD/build/luau-cli/luau.exe"` :
code de sortie 0, **5 contrôles réussis, 0 échoué**. Interpréteur officiel Luau
0.743 téléchargé depuis la release `luau-lang/luau` dans `build/luau-cli/`
(dossier ignoré par Git). Catalogue complet, familles, absence de rareté,
noms/icônes et gel du catalogue vérifiés. Le blocage initial dû à l'absence
de `luau` dans PATH est résolu avec ce chemin explicite.

Reprise finale : Studio « test 3 » connecté (placeId 120616399792561), mode Edit.
Audit `tests/resource-icons.studio.luau` exécuté avec ResourceConfig de Git évalué
uniquement en mémoire : **PASS**, 60 cartes conformes, 36 images, 24 vides.
ResourceId, Index, Famille, Nom, Image et AssetId correspondent au catalogue.
`Workspace.AtelierIcones` : **PASS**, zéro enfant, donc aucun script temporaire.
Aucune icône produite ni publiée pendant cette phase de tests.

Caméra initialement Scriptable. Recréation selon la procédure du projet :
Fixed, CFrame et Focus restaurés dans le même appel. Cependant, l'appel d'audit
suivant retrouve Scriptable : la persistance de la restauration reste non validée.
Le test Studio expose maintenant cameraType dans son résultat, sans confondre
ce constat avec la conformité des cartes. Une dernière restauration est tentée
après les contrôles ; vérifier manuellement le clic droit et le clic molette.

Suite Node relancée : 11 entrées réussies, 1 échec (24 icônes manquantes).
Suite Luau relancée : 5 réussites, 0 échec. Aucun nouveau PASS artistique.

## Travail restant

## Recontrôle de la tentative 4/5 — 18 octobre 2026

- Suite Node réexécutée : **11 réussites, 1 échec**, code de sortie 1.
  Seule l'acceptation des 60 icônes échoue : 36 livrées, 24 manquantes.
- Suite Luau ressources réexécutée avec le chemin explicite ci-dessus :
  **5 réussites, 0 échec**, code de sortie 0.
- Audit Studio réexécuté dans « test 3 », avec le catalogue Git en mémoire :
  **60 cartes conformes, 36 images, 24 vides, atelier vide**.
  Le test retourne maintenant aussi `missingIds`, pour rendre le relevé exploitable.
  Cette version complétée a été exécutée avec succès dans Studio.
- Caméra constatée Scriptable au début de l'audit, puis recréée selon la procédure :
  le dernier appel confirme **Fixed**. Persistance entre appels et commandes souris
  toujours non validées ; aucune nouvelle capture ni validation artistique.
- Les 24 ressources restent en revue humaine selon la reprise de mission.
  Aucun nouvel essai de production, aucun upload et aucune publication Git.

## Actions après revue humaine

Produire, capturer, exporter, publier et valider les ressources suivantes,
puis renseigner leur carte et leur Icon :

`resource_020`, `resource_025`, `resource_026`, `resource_029`, `resource_030`,
`resource_031`, `resource_036`, `resource_040`, `resource_041`, `resource_044`,
`resource_045`, `resource_046`, `resource_047`, `resource_048`, `resource_049`,
`resource_050`, `resource_051`, `resource_052`, `resource_054`, `resource_055`,
`resource_057`, `resource_058`, `resource_059`, `resource_060`.

Relancer après livraison l'audit Studio avec ResourceConfig
de Git évalué en mémoire, sans créer de script. Relancer les suites Node et Luau
après livraison des icônes manquantes. Conserver les contrôles visuels
sur captures par famille ; le contrôle de transparence ne garantit pas à lui seul
la qualité du détourage ou la lisibilité à 32 px.
