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
| Menu | icônes PNG du pack : Boutique, Sac, Index, Guilde, Stats, Quêtes | `MenuController`, `UI/Views/MenuView`, `UI/Views/InfoView`, `Shared/Config/MenuIconConfig` |

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
| `Summon` | invocation tutorielle (gratuite) | bouton « GRATUIT » |
| `SummonBanners` | première invocation avec les vraies bannières | 1. bannière active ; 2. tickets ; 3. bouton ×1 |
| `Index` | Index ouvert | le compteur « n / 60 découverts » |
| `Stats` | Stats ouvertes | aucune étape (le drapeau éteint le badge) |
| `Currencies` | premier gain d'or (HUD, attend qu'aucun écran ne soit ouvert) | la pastille d'or (« Ton or ») |
| `Equipment` | Sacoche ouverte avec un objet à équiper (`Screen = "Bag"`, `Condition = "HasEquipment"`), après la découverte `Bag`, hors combat | 1. l'onglet Équipement (« Ton équipement », sauté s'il est déjà affiché) ; 2. le héros de la poupée (« Ton héros ») ; 3. le premier objet porté par personne (« Choisis un objet ») ; 4. « Équiper » (« Équipe-le ! »), seulement s'il est possible |

Une entrée avec `Screen` guide une partie d'une interface déjà découverte : elle démarre quand `Screen`
est ouverte et que sa condition est vraie (`TutorialRules.followUp`). Condition fausse (aucun héros, aucun
objet libre) : rien n'est montré **ni enregistré**, le joueur n'est jamais bloqué. Rien n'est acheté ni
généré : le guidage ne fait que montrer « Équiper », que le joueur touche lui-même. Les étapes où le joueur
agit (onglet, objet, « Équiper ») sont `Hold` : sans durée, elles attendent son clic (ou la disparition de
leur cible), sinon une étape écoulée sauterait toute la suite.

Une étape passe à la suivante au clic sur sa cible ou après sa durée (`Seconds`, 4 s par défaut). Une cible
absente (ex. aucun héros) est sautée. **Le drapeau est enregistré dès le début** : fermer puis rouvrir
ne relance rien (pas de boucle).

## Rappels et badges

- Rappel `OpenBag` : après la première victoire, tant que la Sacoche n'a jamais été ouverte, la flèche
  montre le bouton Sac. Pas avant : pendant la première défense, la quête guide déjà.
- Rappel `OpenEquipment` (`Badge = true`) : un objet à équiper et le guidage `Equipment` jamais vu, la flèche
  et le « ! » montrent le bouton Sac, une fois l'écran de fin fermé (rien pendant le combat ni sur l'écran).
  Même cible qu'`OpenBag` : une seule flèche. Le « ! » s'allume aussi pour tout équipement nouveau de la
  session (`HeroBarController.HasNew`) ; il ne s'allume que sur le Sac (test : un seul badge à la fois).
- Badges « ! » du menu : Sac (au moins un héros), Index (au moins deux héros), Stats (au moins un stage
  gagné), tant que le drapeau n'est pas vu. Un nouveau joueur n'en voit qu'un à la fois (test).

Conditions, toujours venues du serveur : `HasHero` et `SecondHero` (collection `ArenaStore`),
`FirstVictory` (`Remotes.GetPlayerStats`), `HasEquipment` (un héros possédé et un objet du catalogue porté
par personne, vue d'inventaire `InventoryStore`, `TutorialRules.hasEquipment`).

## Menu principal

Reproduit le menu de la maquette « Quêtes HUD » du pack visuel validé (ZIP « Icones Menu », PNG 512 x 512 à
fond transparent, publiés **tels quels**, sans retouche ; les SVG ne sont que la source). Tous les AssetIds
sont dans `src/shared/Config/MenuIconConfig.lua` (aucun ailleurs : `tests/ui-assets.test.mjs`), les
mesures dans `UITheme.Pack.Menu`.

| Entrée | PNG | Ouvre |
| --- | --- | --- |
| Boutique | `shop.png` | « Bientôt disponible » (InfoView) |
| Sac | `bag.png` | LA Sacoche existante (`HeroBarController.SetBag`) ; bouton sélectionné tant qu'elle est ouverte |
| Index | `index.png` | catalogue des 60 héros (CollectionView) : possédés (vrai modèle, ×n), les autres « ??? » + cadenas |
| Guilde | `guild.png` | « Bientôt disponible » |
| Stats | `stats.png` | statistiques du serveur : héros, niveau max, stages, Élite, invocations, royaume |
| Quêtes | `quest.png` | le panneau Quêtes (`QuestController.OpenPanel`, voir `docs/QUESTS.md` § Panneau) |

- Disposition : grille de 2 colonnes x 3 lignes (Boutique Sac / Index Guilde / Stats Quêtes). Chaque entrée :
  tuile chunky (face Cream → Sand sur lèvre WoodDark, contour Ink), icône qui déborde au-dessus, nom dessous.
  Placée, centrée, dans la bande libre sous le suivi de quête **et sous la fenêtre de chat de Roblox** (elle
  capte les clics : un bouton dessous ne répondrait pas), au-dessus de la hotbar (sur écran tactile,
  au-dessus de 62 % de la hauteur : joystick) ; agrandie jusqu'à x1,3 si la place le permet ; bande trop
  basse (téléphone en paysage) : les 6 icônes sur une seule ligne.
- États : survol (léger gonflement), enfoncé, sélectionné (face dorée, contour Selected), attention (le
  « ! » du pack, `badge.png`, au coin haut droit, qui flotte doucement, comme la maquette), mis en avant
  (halo doré qui respire). Les variantes `*-badge.png` sont publiées et gardées dans la config mais la
  maquette affiche l'icône normale + `badge.png` : on ne cumule pas les deux.
- Visible sous le voile de ses propres fenêtres (Menu, Quêtes : bouton sélectionné) ; caché pendant tout
  autre écran modal (ScreenState : Expédition, invocation, récompenses…). Un écran modal qui s'ouvre ferme
  la Sacoche (jamais de fenêtre par-dessus elle).
- API : `MenuController.SetAttention(id, on)`, `MenuController.SetHighlighted(id, on)`,
  `MenuController.GetButton(id)`. Aucune règle de quête dans le menu : attention = drapeaux non vus
  (`TutorialController.Badge`) ou `QuestController.attention` (récompense à récupérer, nouvelle quête) ;
  halo = bouton visé par la flèche UI (`TutorialController.pointing`).
- Aperçu Studio : attribut `Workspace.ApercuMenu`, ex. `"Bag=attention,Index=halo"` (vide : normal).

Le bouton texte « Sac » à côté de la hotbar est remplacé par l'entrée Sac du menu ; la Sacoche s'ouvre
juste à droite du menu (cible `Menu.Area`, sa taille réelle).

### Publier une nouvelle version d'icône

1. Téléverser le PNG sur Roblox (Asset Manager ou Creator Hub), sans le retoucher.
2. Coller `rbxassetid://<id>` dans `MenuIconConfig` (ou `CurrencyVisualConfig` pour une monnaie).
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
