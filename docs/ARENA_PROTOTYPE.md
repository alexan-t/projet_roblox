# Préparation de combat dans l'arène du plot

Chaque joueur prépare et combat dans **l'arène de SON plot** (`PlotService:GetPlot(player)` →
`Arene` → `CaseHeros`). Deux joueurs préparent et combattent en même temps, chacun chez soi.
Le combat appartient à **CombatService** (`docs/COMBAT.md`) ; les héros et la hotbar à
**HeroService** (`docs/HEROES.md`).

Deux actions séparées :

```
E près d'une dalle    = Placer / Remplacer / Reprendre un héros
E près de la pancarte = fenêtre des stages : choisir un stage, Préparer l'équipe, Lancer
```

## Flow

```
hotbar (1..0) ou Sacoche > Héros > Placer
        ↓
héros visible dans les mains du personnage (HeldHeroController, client)
        ↓
entrer dans son arène → les dalles valides s'illuminent légèrement
        ↓
s'approcher d'une dalle → prompt « E · Placer Écuyer du Rempart » (une seule dalle, la plus proche)
        ↓
E → le serveur pose le héros (le héros reste en main tant qu'il n'a pas accepté)
        ↓
jusqu'à 4 héros
        ↓
pancarte du stage (entrée de l'arène) : Stage, ennemis, équipe x/4 → E → fenêtre → Lancer
        ↓
combat automatique, ultimes automatiques, vagues, mini-boss, victoire / défaite
```

1. **Prendre un héros** : touche 1..9 / 0 ou clic sur un raccourci ; ou Sacoche > Héros > un
   héros > **Placer** (la sacoche se ferme). Annuler ou Échap vide les mains.
2. **Placer** : près d'une dalle (8 studs, `ArenaConfig.PromptDistance`), un seul
   `ProximityPrompt` local apparaît, sur la dalle valide la plus proche :
   - héros en main, dalle libre → « Placer Écuyer du Rempart » ;
   - héros en main, dalle occupée → « Remplacer Écuyer du Rempart » (le héros remplacé retourne à la collection) ;
   - main vide, héros posé → « Reprendre Tireuse des Faubourgs » : il quitte la dalle et revient dans les mains.
   Sur mobile, le prompt se touche. Refus du serveur : le héros reste en main, message bref.
3. **Lancer** (fenêtre des stages) : actif avec 1 à 4 héros posés, hors combat. Il vide les mains
   puis envoie `ArenaAction("Ready")` ; le serveur revalide et appelle `CombatService:StartCombat`.
   Ready est accepté depuis la zone de préparation **ou** à `ArenaConfig.SignDistance` (12 studs,
   horizontal) de la bannière de la pancarte.
4. **Pendant le combat** : aucun prompt, aucune lumière, aucun changement de formation ; pastille
   x1 / x2 / X. **X** arrête sans résultat.
5. **Fin** : « Victoire ! » ou « Défaite… », la préparation est libérée.

### Lumières de placement (client seulement)

Allumées seulement si **héros en main + joueur dans son arène + hors combat**, et uniquement sur
les dalles du plot du joueur (jamais celles d'un autre). Surbrillances `Highlight` locales, sans
modifier les dalles (`UITheme.World.Case`) :

| État | Rendu |
| --- | --- |
| Libre valide | voile crème léger (`ValidTarget`) |
| Candidate du prompt E | voile et contour plus marqués (`Hover`) |
| Occupée (remplacement) | teinte bois (`Occupied`) |
| Libre à 4/4 | rien : pas une cible |
| Dalle du héros tenu | doré (`Selected`) |

Hors arène, après un placement accepté ou en combat : tout s'éteint. **Préparer l'équipe** (fenêtre
des stages) montre les dalles volontairement quand rien n'est en main.

### Pancarte du stage

Asset `Arene.PanneauStage` (copie de `PanneauProprietaire`, bannière `Banniere` 5,6 × 6,4 studs),
dans les 8 arènes, à droite du porche « Zone 1 » (repère local de l'arène : (15,3 ; 52,8), face
tournée vers le chemin qui arrive du spawn). `SurfaceGui` locale `PancarteStage`, posée seulement sur
la pancarte de **son** arène, **affichage seul** : **Stage x-y** (session, sinon stage choisi),
**ennemis agrégés** (`ArenaRules.summarize` : « Slime ×2 », « Gobelin ×4 », « Mini-boss : Boss »,
jamais de position), **équipe x / 4**, et en pied « E · Choisir un stage » (« Combat en cours »
pendant le combat). Visible jusqu'à `UITheme.World.CombatDistance`.

### Fenêtre des stages

`ProximityPrompt` local « Choisir un stage » sur la bannière (portée `SignDistance - 2`, désactivé en
combat) → `ExpeditionView` (fenêtre « Expédition », voile, titre « Zone 1 · La Plaine du Royaume »
lu dans l'attribut `Nom` du modèle de zone). Une carte par stage de `StageConfig`, état serveur
(`ArenaState.Stages`) : Disponible / Terminé / Verrouillé (le précédent n'a pas son First Clear).
- choisir un stage débloqué → `ArenaAction("SelectStage", zone, stage)` : le serveur revalide
  (stage inconnu / verrouillé / indisponible), le mémorise et, si des héros sont déjà posés,
  relance la session de stage en gardant la formation (`ArenaPrep.restage`) ; refusé en combat ;
- **Préparer l'équipe** : ferme la fenêtre et met les dalles en évidence ;
- **Lancer** : `Ready` (désactivé tant qu'aucun héros n'est posé ; la ligne de détail le dit).

## Découpage

| Fichier | Rôle |
| --- | --- |
| `src/shared/Config/ArenaConfig.lua` | nom de l'arène dans le plot, portée du prompt, distance serveur, stage, max 4, mannequins ennemis |
| `src/server/Arena/ArenaRules.lua` | règles pures : roster agrégé, formation case → exemplaire |
| `src/server/Arena/ArenaPrep.lua` | préparation pure, une par joueur : Place / Remove / Ready / Leave, changement de stage, fin, départ (testée) |
| `src/server/Services/ArenaService.lua` | monde du plot : mannequins, remotes, distance, état envoyé (versionné), géométrie pour CombatService |
| `src/client/Arena/PlacementState.lua` | héros en main et décision du prompt E (pur, testé) |
| `src/client/Arena/ArenaStore.lua` | état client partagé (héros, hotbar, préparation, main) |
| `src/client/Arena/PlotView.lua` | plot / arène / monde du joueur local (affichage seulement) |
| `src/client/Controllers/HeroBarController.lua` | hotbar, sacoche |
| `src/client/Controllers/HeldHeroController.lua` | héros visible dans les mains |
| `src/client/Controllers/ArenaPlacementController.lua` | prompt E, lumières, panneau Arène, pastille de combat |

- **Serveur autoritaire** : `Remotes.ArenaAction` n'accepte que `"Place", case, HeroInstanceId`,
  `"Remove", case`, `"SelectStage", zone, stage`, `"Ready"` et `"Leave"`. Il vérifie l'exemplaire possédé, la phase, la case,
  l'unicité, le maximum de 4 et l'absence de combat. Le prompt n'a aucune autorité.
- **Chacun sa propre arène, et seulement sur place** : une action ne désigne qu'un numéro de case,
  toujours résolu dans l'arène du plot du joueur qui l'envoie ; aucun paramètre ne permet de viser
  l'arène d'un autre. Placer / Reprendre / Prêt exigent en plus que le personnage (vivant) soit
  dans **sa zone de préparation** : cercle autour de ses 9 dalles + `ArenaConfig.ZoneMargin`
  (10 studs) ; Placer / Reprendre exigent aussi d'être à portée de la dalle
  (`ArenaConfig.InteractionDistance`, 14 studs). Règle pure : `ArenaRules.canInteract` (testée).
  Seul Quitter (X) reste possible de partout. Le client applique la même zone (lumières, Prêt).
- **État versionné** : chaque `ArenaState` porte un `Version` croissant ; le client ignore un état
  plus ancien (évite qu'une réponse initiale en retard masque le panneau).
- **Pas de prompt serveur « Combattre »** : il a été supprimé.

## Tests

```powershell
./tools/test-arena.ps1 -LuauPath <chemin-vers-luau.exe>
```

ArenaRules (formation), ArenaPrep (placement, refus, Prêt avec 0 / 1 / 4 héros, double Prêt,
arènes indépendantes) et PlacementState (hotbar, sacoche, prompt Placer / Remplacer / Reprendre,
refus qui garde le héros en main, verrou en combat).
