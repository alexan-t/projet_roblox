# Invocation V2 — validation du 18 octobre 2026

## Périmètre et verdict

**PASS** sur le périmètre fonctionnel automatisé et les compositions visuelles testées. Références : ZIP final figé, `Invocation.dc.html`, `HeroCard.dc.html` et les PNG originaux. Aucun modèle 3D du jeu n'est redessiné par cette issue.

Place Studio : **Projet Roblox - Alpha**, placeId `78875801703886`. Sources synchronisées par Rojo sur `codex/80-invocation-v2`, à partir de `develop` après #79. Les aperçus visuels utilisent des copies d'état ou des lots de démonstration ; ils ne donnent aucun ticket ou héros au profil chargé.

## Captures conservées

- [Desktop, état réel sans tickets](references/ui/invocation-v2/qa/desktop-insuffisant.jpg) : émulation 1920×1080, viewport mesuré 1919×1079, bannière Éclipse, timer serveur et trois commandes désactivées avec le manque affiché.
- [Reveal x1 mobile](references/ui/invocation-v2/qa/x1-mobile.jpg) : aperçu Épique garanti, ruban fourni, cadre de rang 4, modèle, badge Nouveau, Continuer et Encore avec icône/coût.
- [Résumé x100 mobile](references/ui/invocation-v2/qa/x100-mobile.jpg) : aperçu de stress avec 100 identifiants et les 60 héros du catalogue, toutes les raretés représentées. Ce lot visuel n'est pas une distribution RNG revendiquée.

Les captures sont prises dans Studio après chargement des assets. Mobile : iPhone 17 Pro, résolution simulée 874×402, viewport sûr mesuré 750×381. L'orientation globale du jeu est `Sensor` ; le prototype mobile fourni et le contrôle visuel de cette issue sont en **paysage**. La composition portrait n'a pas fait l'objet d'une validation visuelle dédiée.

## Contrôles Studio effectués

| Contrôle | Résultat observé |
| --- | --- |
| Assets du ZIP | Les 21 identifiants retournent `AssetFetchStatus.Success`. Dix cadres de cartes, dos, portail, rayons, sparkles, star, hourglass, silhouette, rubans, sceau et cadre 9-slice employés depuis la config. |
| Desktop et petite fenêtre | Bannière, vedette centrale, secondaires, timer, boutons et cadres visibles ; contrôle en 1919×1079 et dans le viewport initial 1651×623. |
| Mobile paysage | Composition à deux colonnes fidèle au prototype ; x1, x10 et résumé x100 contrôlés sur captures. |
| Taux | Ouverture par un vrai clic sur desktop et mobile, panneau crème, chances spécifiques des vedettes et dix raretés, défilement mobile. |
| Timer / bannière | État lu via `GetSummonState`, borne UTC réelle, évolution observée des bannières au fil des sessions. Le callback de recharge à zéro a aussi été testé sur une copie d'état dont la borne a été rapprochée ; il relit la bannière/créneau réels du serveur. L'horloge gameplay n'est jamais modifiée. |
| Refus sans tickets | Vrai appel client → serveur au portail du joueur : x100 refusé `pas assez de tickets d'invocation`, tickets et compteur payant inchangés. Position du personnage restaurée ensuite. |
| Transaction moteur x100 | `SummonRules.batch` réel exécuté dans Studio sur une table isolée : 100 résultats, 100 IDs distincts, débit 100, `Total = 100`, premier résultat Épique ou mieux. Le profil chargé reste distinct de cette table. |
| Reveal x1 | Portail, flash, silhouette, rareté, carte ; contrôle final du ruban et des badges sans chevauchement bloquant. |
| Reveal x10 | Grille de dix cartes ; clic de skip : dix fronts visibles, zéro dos visible. |
| Reveal x100 | Compteur court, meilleurs résultats puis résumé. Vrais clics sur Voir les 100 résultats et Tous (100) ; 100 cellules avec identifiants distincts. |
| Défilement x100 | Interaction de scroll réelle ; `CanvasPosition.Y = 400` après défilement sur téléphone. |
| Cas dix raretés | Les dix chips restent dans les bornes de leur ligne ; aucune sortie horizontale. |
| Console UI | Aucun message d'erreur lié à SummonView, SummonLayout, SummonReveal ou HeroCard pendant les parcours. Les avertissements moteur déjà présents sur les meshes/CorePackages sont hors de cette modification. |
| Fin de QA | Play arrêté, simulateur remis à `default`, appareil custom de test retiré, caméra de Studio recréée et restaurée selon le protocole du dépôt. |

Les transactions payantes réussies sur des profils persistés, les comptes neufs, le rejoin et deux joueurs sont couverts par les suites du vrai HeroService avec doubles de services. Cette session Studio n'a pas donné artificiellement 111 tickets au profil réel ni réinitialisé sa sauvegarde pour rejouer le starter. Ces deux périmètres de validation sont distingués volontairement.

## Suites exécutées

- `test-heroes.ps1` : règles héros, migrations et progression vertes ; service d'invocation **47 tests PASS**, dont rotation/bornes, trois quantités, coûts, taux exacts, garantie, rejoin, profils existants, erreur au dernier résultat et deux lots x100 indépendants (200 IDs).
- `test-security.ps1` : 23 PASS.
- `test-quests.ps1` : 43 PASS.
- `test-tutorial.ps1` : 13 PASS, relancé après adaptation du texte de guidage à la bannière active.
- `test-rewards.ps1` : RewardService et RewardFlow verts, y compris l'économie de replay et l'absence de récompense dupliquée.
- `test-ui.ps1` : 7 PASS ; `test-presentation.ps1` : 19 PASS.
- Tests Node du dépôt : items, ressources, menu et monnaies verts.
- Compilation de tout `src/**/*.lua` par Luau 0.740 : succès (environ 32 KLOC).
- `rojo build default.project.json -o build/issue-80-invocation-v2.rbxlx` : succès.
- Vérification des sources copiées : **72 fichiers identiques octet pour octet au ZIP**, manifest de ses 111 fichiers.
- `git diff --check` : contrôlé avant commit.

## Écarts techniques assumés

Le portrait utilise le vrai modèle via UIKit quand il existe, et la silhouette du ZIP sinon. Les halos CSS sont approchés avec les rayons/sparkles teintés et les effets Roblox ; les cadres, rubans et icônes restent les originaux. Le 9-slice est ajusté à la réduction Roblox 1200×680 → 1024×580. Les probabilités affichées corrigent la contribution du pool normal oubliée par la démo, sans réorganiser le design.
