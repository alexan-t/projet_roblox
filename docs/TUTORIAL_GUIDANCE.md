# Guidage du tutoriel et menu de navigation

Objectif : un nouveau joueur sait toujours où aller et quoi regarder, presque sans lire. Le guidage est
**fort mais jamais chaotique** : une seule flèche UI à la fois, des légendes de 2 à 4 mots, rien de
permanent.

## Vue d'ensemble

| Couche | Quoi | Où |
| --- | --- | --- |
| Monde | flèches dorées couchées au sol en chaîne vers la cible + grosse flèche qui rebondit au-dessus de la cible + cible qui « respire » | `QuestGuideController`, `UI/GuideArrows`, `UI/WorldPulse` |
| Interface | UNE flèche UI qui rebondit vers un élément, lueur dorée autour, légende courte | `TutorialController`, `UI/GuidePointer` |
| Cibles UI | noms logiques « Zone.Element » enregistrés par les vues elles-mêmes | `UI/GuideTargets` |
| Données | étapes, drapeaux, rappels, entrées du menu | `src/shared/Config/TutorialConfig.lua` |
| Règles | validation, priorités, première fois, badges (pur, testé) | `src/shared/Tutorial/TutorialRules.lua` |
| Mémoire | drapeaux « vu une fois » | `PlayerData.Tutorial.Seen`, `TutorialService` |
| Menu | colonne d'icônes : Boutique, Sac, Index, Guilde, Stats | `MenuController`, `UI/Views/MenuView`, `UI/Views/InfoView` |

Aucune coordonnée en dur : le monde vise des cibles de `Shared.Quests.QuestGuide` (toujours dans le plot
du joueur), l'interface vise des cibles enregistrées par les vues (`GuideTargets.register`).

## Les trois sources de flèche UI

`TutorialRules.pick` choisit une seule flèche, par priorité :

1. **FirstOpen** : découverte d'une interface que le joueur vient d'ouvrir (son regard y est déjà).
2. **Quest** : étape active du tuto, rejouée tant qu'elle est active :
   - raccourci du héros à poser (« Prends ton héros », `Hotbar.Guide`) ;
   - « Lancer » dans l'Expédition une fois un héros posé (`Expedition.Launch`) ;
   - « Invoquer » pendant l'invocation tutorielle (`Summon.Invoke`).
3. **Nudge** : rappel « ouvre ce menu », seulement sans écran ouvert et hors combat.

Rien pendant un combat, son outro ou l'écran de fin, sauf la découverte d'une fenêtre ouverte par le joueur.

## Premières ouvertures (`TutorialConfig.FirstOpen`)

| Drapeau | Déclencheur | Étapes |
| --- | --- | --- |
| `Bag` | Sacoche ouverte | 1. la première carte héros (« Tes héros ») ; 2. « Placer » (« Pose-le dans l'arène ») |
| `Expedition` | fenêtre Expédition ouverte | 1. le stage proposé (« Choisis un stage ») ; 2. l'action possible : « Lancer » si un héros est posé, sinon « Préparer l'équipe » (`Expedition.Next`, légende donnée par la vue) |
| `Summon` | invocation tutorielle (gratuite) | « Invoquer · Gratuit » |
| `SummonBanners` | première invocation avec les vraies bannières | 1. colonne des bannières ; 2. tickets ; 3. « Invoquer » |
| `Index` | Index ouvert | le compteur « n / 60 découverts » |
| `Stats` | Stats ouvertes | aucune étape (le drapeau éteint le badge) |
| `Currencies` | premier gain d'or (HUD, attend qu'aucun écran ne soit ouvert) | la pastille d'or (« Ton or ») |

Une étape passe à la suivante au clic sur sa cible ou après sa durée (`Seconds`, 4 s par défaut). Une cible
absente (ex. aucun héros) est sautée. **Le drapeau est enregistré dès le début** : fermer puis rouvrir
ne relance rien (pas de boucle).

## Rappels et badges

- Rappel `OpenBag` : après la première victoire, tant que la Sacoche n'a jamais été ouverte, la flèche
  montre le bouton Sac. Pas avant : pendant la première défense, la quête guide déjà.
- Badges « ! » du menu : Sac (au moins un héros), Index (au moins deux héros), Stats (au moins un stage
  gagné), tant que le drapeau n'est pas vu. Un nouveau joueur n'en voit qu'un à la fois (test).

Conditions, toujours venues du serveur : `HasHero` et `SecondHero` (collection `ArenaStore`),
`FirstVictory` (`Remotes.GetPlayerStats`).

## Menu de navigation

| Entrée | Icône (maison, `UI/Icons`) | Ouvre |
| --- | --- | --- |
| Boutique | étal à auvent rayé, pièce d'or | « Bientôt disponible » (InfoView) |
| Sac | sacoche de cuir, boucle dorée | la Sacoche (`HeroBarController.SetBag`) ; bouton sélectionné tant qu'elle est ouverte |
| Index | livre bleu royal, emblème doré | catalogue des 60 héros : possédés (vrai modèle, ×n), les autres « ??? » + cadenas, sans spoil |
| Guilde | bannière rouge à queue d'aronde | « Bientôt disponible » |
| Stats | trois barres sur un socle | statistiques du serveur : héros, niveau max, stages, Élite, invocations, royaume |

Le bouton texte « Sac » à côté de la hotbar est remplacé par l'entrée Sac du menu ; la Sacoche s'ouvre
juste à droite de la colonne (`UITheme.Spacing.MenuColumn`).

## Ajouter un guidage

1. La vue enregistre son élément : `GuideTargets.register("Zone.Element", gui)` ; si c'est une fenêtre,
   elle signale `GuideTargets.open(drapeau)` / `GuideTargets.close(drapeau)`.
2. Ajouter le drapeau à `TutorialConfig.Flags` (ne jamais renommer un drapeau livré) et ses étapes à
   `TutorialConfig.FirstOpen` (ou un rappel à `Nudges`).
3. `./tools/test-tutorial.ps1` valide la config (`TutorialRules.problems`).

Une nouvelle cible dans le monde : `Shared.Quests.QuestGuide.Targets`, puis `Guide.Target` dans
`QuestConfig` (voir `docs/QUESTS.md` § Guidage).

## Serveur

- `PlayerData.Tutorial = { Seen = {} }` : ajouté aux anciens profils par `Reconcile` (aucune migration).
- `GetTutorialSeen` (RemoteFunction) : copie des drapeaux connus.
- `MarkTutorialSeen` (RemoteEvent, drapeau) : drapeau inconnu, déjà vu ou envoyé trop vite (moins de
  0,2 s) ignoré ; aucun effet de jeu. Le client espace ses envois de 0,3 s.
- `GetPlayerStats` (`PlayerStateService`, lecture seule) : comptes relus dans PlayerData.

## Tests

```powershell
./tools/test-tutorial.ps1 -LuauPath <luau.exe>     # config, règles, TutorialService
./tools/test-playerstate.ps1 -LuauPath <luau.exe>  # GetPlayerStats
```
