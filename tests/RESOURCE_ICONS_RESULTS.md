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

`./tools/test-resources.ps1` : exécution bloquée, commande `luau` introuvable.
Les tests Luau n'ont donc pas été exécutés pendant cette phase ; les résultats
Studio de la phase précédente ne sont pas comptabilisés comme une nouvelle exécution.

`roblox-studio.list_roblox_studios` : liste vide. L'audit en lecture seule
`tests/resource-icons.studio.luau` ne peut pas être relancé ; état actuel des cartes,
égalité Image/AssetId/Icon, atelier vide et caméra non revérifiés.
Aucune modification de scène ni publication effectuée pendant cette phase.

Reprise du 18 octobre : suite Node relancée après ajout des deux assertions de
troncature, résultat inchangé (11 entrées réussies, 1 échouée). Nouvelle tentative
de `./tools/test-resources.ps1` : `luau` toujours introuvable. Nouvelle interrogation
de `roblox-studio.list_roblox_studios` : `studios: []`. L'audit Studio reste non exécuté.

## Travail restant

Produire, capturer, exporter, publier et valider les ressources suivantes,
puis renseigner leur carte et leur Icon :

`resource_020`, `resource_025`, `resource_026`, `resource_029`, `resource_030`,
`resource_031`, `resource_036`, `resource_040`, `resource_041`, `resource_044`,
`resource_045`, `resource_046`, `resource_047`, `resource_048`, `resource_049`,
`resource_050`, `resource_051`, `resource_052`, `resource_054`, `resource_055`,
`resource_057`, `resource_058`, `resource_059`, `resource_060`.

Reconnecter la place test 3 au serveur Studio et lancer l'audit avec ResourceConfig
de Git évalué en mémoire, sans créer de script. Relancer les tests Luau avec un
interpréteur disponible (`tools/test-resources.ps1 -LuauPath <chemin>`), puis la
suite Node après livraison des icônes manquantes. Conserver les contrôles visuels
sur captures par famille ; le contrôle de transparence ne garantit pas à lui seul
la qualité du détourage ou la lisibilité à 32 px.
