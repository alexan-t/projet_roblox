# Résultats des tests de l'agrandissement des plots — 19 octobre 2026

Résultat actuel : **tests hors Studio PASS (16/16)**. **Contrôle visuel : FIX** tant que le script
n'a pas été exécuté dans Studio et que les captures avant / après n'existent pas (aucun accès
Studio MCP dans cette session). Pas de PASS sans capture (`docs/VISUAL_QA.md`).

## Commandes

- `node tests/plots-agrandissement.test.mjs` : **16 réussis, 0 échoué**, code 0.
- `node --test --test-isolation=none tests/*.test.mjs` (les 5 fichiers) : **15 entrées
  node:test réussies, 0 échouée**, code 0. Les autres contrôles (catalogue, items, icônes, UI)
  sont inchangés et passent.
- `tools/test-*.ps1` (specs Luau) : **non lancés**, `luau.exe` absent de la machine. Seul un
  commentaire de `CombatService.spec.lua` a changé dans cette mission.

## Ce que vérifie `plots-agrandissement.test.mjs`

Le script `tools/studio-agrandir-plots.luau` est lu comme texte ; sa géométrie (survey, plan, apply,
neighbourGap) est recalculée à l'identique sur les 8 `Lobby.Plots` du snapshot
`studio/sandbox/partner_sandbox_v4.rbxl` (CFrame, tailles, formes lues dans le fichier binaire).

| Contrôle | Résultat |
| --- | --- |
| Réglages du script = tableau de `docs/PLOTS.md` (20 studs, 5 par côté, 30, 4) | PASS |
| Assets uniquement : aucun `Source`, aucun script créé, rien de détruit | PASS |
| Une seule étape Ctrl+Z, annulée en cas d'erreur | PASS |
| Répétable (`AgrandiCombat`), mode mesure seule (`APPLIQUER = false`) | PASS |
| Refus des voisins trop proches avant toute modification | PASS |
| Sol avant 122 × 178, après 132 × 203 (8 plots) | PASS |
| Dalles → front ennemi : 23 → 43 studs | PASS |
| Pointe extérieure (depuis `SpawnLobby`) : 328 → 353 studs | PASS |
| Écart minimal entre sols voisins : 22,3 → 15,8 studs (seuil du script : 4) | PASS |
| Aucune pièce d'un plot sur le sol agrandi d'un voisin (marge minimale 14,7 studs) | PASS |
| Dalles, royaume, portail, pancarte du propriétaire, point d'apparition immobiles | PASS |
| Front reculé de 20 studs ; les 7 places ennemies à plus de 15 studs du bord | PASS |
| Camp ennemi reculé d'un bloc (écartement ≤ 5 studs, nul à moins de 30 studs du bout du sol) | PASS |
| Couloir dalles → ennemis (largeur ± 10) sans obstacle ; premier décor à 10,2 studs de l'axe | PASS |
| Portées (max 28) < 43 : les héros à distance avancent ; mêlée à plus de 40 studs du bord | PASS |
| Murs invisibles hors de l'emprise : 41,1 → 28,1 studs du sol le plus proche | PASS |
| Forêt : 63 arbres sur 900 dans la nouvelle emprise, archivés par le script | PASS |

## Écarts constatés et corrigés

- `docs/PLOTS.md` et `docs/WORLD.md` annonçaient un écart entre voisins de 21,6 → 15,0 studs ; la
  mesure du script lui-même donne **22,3 → 15,8** (calcul exact, identique à l'échantillonnage du
  script). Chiffres corrigés ; le seuil de sécurité (4 studs) reste largement respecté.
- `PanneauStage` (pancarte du stage) n'existe pas dans le snapshot v4 : contrôlé seulement s'il est présent.

## Limites

- Boîtes des modèles alignées sur le repère du front (Studio : `GetBoundingBox` orientée) : tolérance
  de quelques dixièmes de stud.
- Le snapshot v4 n'est pas la DEV actuelle. Le déplacement réel des personnages (Pathfinding,
  collisions des copies du rempart) se vérifie dans Studio : test « Serveur et clients », 1-1 et 1-5,
  puis les 5 captures et la grille PASS/FIX de `docs/PLOTS.md`.
