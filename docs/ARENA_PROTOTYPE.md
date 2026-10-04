# Préparation de combat dans l'arène du plot

Chaque joueur prépare et combat dans **l'arène de SON plot** (`PlotService:GetPlot(player)` →
`Arene` → `CaseHeros`). Deux joueurs préparent et combattent en même temps, chacun chez soi.
Le combat appartient à **CombatService** (`docs/COMBAT.md`) ; les héros et la hotbar à
**HeroService** (`docs/HEROES.md`).

Deux actions séparées :

```
E    = interaction avec le monde : Placer / Remplacer / Reprendre un héros sur une dalle
Prêt = lancer le combat (panneau Arène)
```

## Flow

```
hotbar (1..0) ou Sacoche > Héros > Placer
        ↓
héros visible dans les mains du personnage (HeldHeroController, client)
        ↓
entrer dans son arène → les dalles valides s'illuminent légèrement
        ↓
s'approcher d'une dalle → prompt « E · Placer Archer » (une seule dalle, la plus proche)
        ↓
E → le serveur pose le héros (le héros reste en main tant qu'il n'a pas accepté)
        ↓
jusqu'à 4 héros
        ↓
panneau Arène : Stage, ennemis, équipe x/4 → Prêt
        ↓
combat automatique, ultimes automatiques, vagues, mini-boss, victoire / défaite
```

1. **Prendre un héros** : touche 1..9 / 0 ou clic sur un raccourci ; ou Sacoche > Héros > un
   héros > **Placer** (la sacoche se ferme). Annuler ou Échap vide les mains.
2. **Placer** : près d'une dalle (8 studs, `ArenaConfig.PromptDistance`), un seul
   `ProximityPrompt` local apparaît, sur la dalle valide la plus proche :
   - héros en main, dalle libre → « Placer Archer » ;
   - héros en main, dalle occupée → « Remplacer Archer » (le héros remplacé retourne à la collection) ;
   - main vide, héros posé → « Reprendre Paladin » : il quitte la dalle et revient dans les mains.
   Sur mobile, le prompt se touche. Refus du serveur : le héros reste en main, message bref.
3. **Prêt** : actif avec 1 à 4 héros posés, hors combat. Il vide les mains puis envoie
   `ArenaAction("Ready")` ; le serveur revalide et appelle `CombatService:StartCombat`.
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

Hors arène, après un placement accepté ou en combat : tout s'éteint. Le bouton **Arène** peut
montrer les dalles volontairement quand rien n'est en main.

### Panneau Arène

À droite, semi-transparent (`UITheme` / `UIKit`) : **Stage x-y** (session ou config, rien en dur),
**ennemis agrégés** (`ArenaRules.summarize` : « Slime ×2 », « Gobelin ×4 », « Mini-boss : Boss »,
jamais de position), **équipe x / 4**, boutons **Arène** (secondaire) et **Prêt** (principal).
Masqué pendant le combat.

## Découpage

| Fichier | Rôle |
| --- | --- |
| `src/shared/Config/ArenaConfig.lua` | nom de l'arène dans le plot, portée du prompt, distance serveur, stage, max 4, mannequins ennemis |
| `src/server/Arena/ArenaRules.lua` | règles pures : roster agrégé, formation case → exemplaire |
| `src/server/Arena/ArenaPrep.lua` | préparation pure, une par joueur : Place / Remove / Ready / Leave, fin, départ (testée) |
| `src/server/Services/ArenaService.lua` | monde du plot : mannequins, remotes, distance, état envoyé (versionné), géométrie pour CombatService |
| `src/client/Arena/PlacementState.lua` | héros en main et décision du prompt E (pur, testé) |
| `src/client/Arena/ArenaStore.lua` | état client partagé (héros, hotbar, préparation, main) |
| `src/client/Arena/PlotView.lua` | plot / arène / monde du joueur local (affichage seulement) |
| `src/client/Controllers/HeroBarController.lua` | hotbar, sacoche |
| `src/client/Controllers/HeldHeroController.lua` | héros visible dans les mains |
| `src/client/Controllers/ArenaPlacementController.lua` | prompt E, lumières, panneau Arène, pastille de combat |

- **Serveur autoritaire** : `Remotes.ArenaAction` n'accepte que `"Place", case, HeroInstanceId`,
  `"Remove", case`, `"Ready"` et `"Leave"`. Il vérifie le plot et l'arène du joueur, la distance
  à la dalle (`ArenaConfig.InteractionDistance`, 14 studs), l'exemplaire possédé, la phase, la
  case, l'unicité, le maximum de 4 et l'absence de combat. Le prompt n'a aucune autorité.
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
