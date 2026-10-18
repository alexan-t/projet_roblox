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
| Menu | icônes PNG du ZIP « Icones Menu » : Boutique, Sac, Index, Guilde, Stats | `MenuController`, `UI/Views/MenuView`, `UI/Views/InfoView`, `Shared/Config/MenuIconConfig` |

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

## Menu principal

Icônes : les PNG du ZIP « Icones Menu » (512 x 512, fond transparent), publiés **tels quels** sur Roblox ;
les SVG du ZIP ne sont que la source. Tous les AssetIds sont dans `src/shared/Config/MenuIconConfig.lua`
(aucun ailleurs : vérifié par `tests/menu-icons.test.mjs`).

| Entrée | PNG normal / attention | Ouvre |
| --- | --- | --- |
| Boutique | `shop.png` / `shop-badge.png` | « Bientôt disponible » (InfoView) |
| Sac | `bag.png` / `bag-badge.png` | LA Sacoche existante (`HeroBarController.SetBag`) ; bouton sélectionné tant qu'elle est ouverte |
| Index | `index.png` / `index-badge.png` | catalogue des 60 héros (CollectionView) : possédés (vrai modèle, ×n), les autres « ??? » + cadenas |
| Guilde | `guild.png` / `guild-badge.png` | « Bientôt disponible » |
| Stats | `stats.png` / `stats-badge.png` | statistiques du serveur : héros, niveau max, stages, Élite, invocations, royaume |

`badge.png` (le « ! » seul) n'est pas utilisé : chaque variante `*-badge.png` l'intègre déjà.

- Disposition : grille de 2 colonnes (Boutique Sac / Index Guilde / Stats), sans panneau, nom sous
  l'icône. Placée dans la bande libre entre le suivi de quête et la hotbar (sur écran tactile, au-dessus
  de 62 % de la hauteur : joystick), agrandie jusqu'à x1,3 si la place le permet ; bande trop basse
  (téléphone en paysage) : les 5 icônes sur une seule ligne.
- États : survol (léger gonflement), enfoncé, sélectionné (pastille bois sombre, contour doré), attention
  (variante PNG « ! » + petit rebond toutes les 3 s), mis en avant (halo doré qui respire).
- Masqué pendant tout autre écran modal (ScreenState : Expédition, invocation, récompenses…).
- API : `MenuController.SetAttention(id, on)`, `MenuController.SetHighlighted(id, on)`,
  `MenuController.GetButton(id)`. Le tutoriel s'y branche sans y mettre sa logique : attention = drapeaux
  non vus (`TutorialController.Badge`), halo = bouton visé par la flèche UI (`TutorialController.pointing`).
- Aperçu Studio : attribut `Workspace.ApercuMenu`, ex. `"Bag=attention,Index=halo"` (vide : normal).

Le bouton texte « Sac » à côté de la hotbar est remplacé par l'entrée Sac du menu ; la Sacoche s'ouvre
juste à droite du menu (cible `Menu.Area`, sa taille réelle).

### Publier une nouvelle version d'icône

1. Téléverser le PNG sur Roblox (Asset Manager ou Creator Hub), sans le retoucher.
2. Coller `rbxassetid://<id>` dans `MenuIconConfig` (`Icon` ou `BadgeIcon` de l'entrée).
3. `node --test tests/`.

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
