# Prototype — préparation de combat dans l'arène de test

**On prend un héros et on le pose sur son terrain**, directement dans le monde : pas de
grande fenêtre de préparation. Le combat lui-même appartient à **CombatService**
(`docs/COMBAT.md`) ; les héros possédés et la hotbar à **HeroService** (`docs/HEROES.md`).

## Flow

```
hotbar (1..0) ou sacoche > Héros > Placer
        ↓
héros « en main » (état de placement, aucun Tool Roblox)
        ↓
clic / toucher sur une case de l'arène   →  le serveur pose le héros
        ↓
jusqu'à 4 héros (la hotbar en contient 10 : c'est voulu)
        ↓
E près de l'étendard (« Combattre »)    →  combat immédiat
        ↓
combat automatique, ultimes automatiques, vagues, mini-boss, victoire / défaite
```

1. **Prendre un héros** : touche 1..9 / 0 ou clic sur un raccourci de la **hotbar** ; ou
   **sacoche** (bouton à gauche de la hotbar) > onglet Héros > choisir un héros > **Placer**
   (la sacoche se ferme). Les deux mènent exactement au même mode. Retour visuel : raccourci
   surélevé au contour doré, petit aperçu du héros au curseur, pastille « Archer en main ·
   choisis une case ». Reprendre le même raccourci, **Annuler** ou Échap vide la main.
2. **Poser** : clic ou toucher sur une case → `ArenaAction("Place", case, HeroInstanceId)`.
   Le premier héros posé **réserve l'arène** et lance la session de stage (ZoneService).
   Une case occupée = **remplacement** (le héros remplacé retourne simplement à la collection).
   Un 5e héros sur une case vide est refusé : « 4 héros maximum ».
3. **Déplacer** : cliquer un héros posé (ou reprendre son raccourci) le remet en main ; un clic
   sur une autre case le déplace.
4. **Retirer** : héros posé en main → bouton **Retirer** → `ArenaAction("Remove", case)`. Il
   quitte la formation mais reste dans la hotbar et la collection (aucune donnée supprimée).
   Retirer le dernier héros libère l'arène et annule la session de stage.
5. **Combattre** : E près de l'étendard. Le serveur vérifie session de stage, 1 à 4 héros,
   héros toujours possédés et aucun combat en cours, puis appelle `CombatService:StartCombat`
   aussitôt. Pendant le combat, la hotbar reste visible mais grisée.
6. **Fin** : « Victoire ! » ou « Défaite… », puis l'arène est rangée. **X** (pendant le combat)
   arrête sans résultat et annule la session.

### États des cases (avant combat)

| État | Quand | Rendu (UITheme) |
| --- | --- | --- |
| Vide | rien en main | grille presque invisible (préparation) ou normale (arène libre) |
| Cible valide | héros en main, case posable | voile crème très léger |
| Survolée | sous le curseur | voile crème plus marqué |
| Occupée | héros en main, case avec un autre héros (remplacement) | voile bois |
| Sélectionnée | case d'origine du héros tenu | doré (`Selected`) |
| Refusée | survol d'une case impossible (4/4, arène prise) | rouge discret (`Error`) |

Une surbrillance `Highlight` par case, sans néon ; la grille n'est bien visible qu'avec un
héros en main.

## Découpage

| Fichier | Rôle |
| --- | --- |
| `src/shared/Config/ArenaConfig.lua` | arène de test, stage lancé, max 4, mannequins par `EnemyId` |
| `src/server/Arena/ArenaRules.lua` | règles pures : roster annoncé, formation case → exemplaire (pose, déplacement, remplacement, retrait) |
| `src/server/Arena/ArenaPrep.lua` | préparation pure : réservation, Place / Remove, E, fin, départ (testée) |
| `src/server/Services/ArenaService.lua` | monde : mannequins, prompt « Combattre », remotes, géométrie passée à CombatService |
| `src/client/Arena/PlacementState.lua` | héros « en main » côté client (pur, testé) |
| `src/client/Arena/ArenaStore.lua` | état client partagé (héros, hotbar, préparation, main) |
| `src/client/Controllers/HeroBarController.lua` | hotbar et sacoche |
| `src/client/Controllers/ArenaPlacementController.lua` | cases, aperçu, statut, pastille de combat, messages |
| `src/client/Controllers/CombatViewController.lua` | PV / énergie / dégâts dans le monde, éclat sur `UltimateUsed` |
| `src/client/UI/UIKit.lua` | briques du design system (UITheme) |

- **Serveur autoritaire** : `Remotes.ArenaAction` n'accepte que `"Place", case, HeroInstanceId`,
  `"Remove", case` et `"Leave"`. Le serveur valide : héros possédé et connu du combat
  (HeroService), case 1..9, propriétaire de la préparation, combat pas lancé, 4 maximum, un
  exemplaire posé une seule fois, session de stage valide. Le combat ne démarre que par le
  prompt E (côté serveur). `Remotes.ArenaState` décrit la préparation à son seul propriétaire.
- **Arène occupée** : une seule préparation à la fois. L'attribut `Occupant` (UserId) de l'arène
  est répliqué ; un autre joueur reçoit « Arène occupée par … » et ne peut rien modifier.
- **3x3 héros** : les 9 `CaseHeros` de l'arène (attribut `Slot`, repère `PointDePose`).
- **3x3 ennemi** : `Zones.<ZoneId = 1>.SourcesEnnemis.FrontEnnemi` découpé en 3 × 3.
- **Mannequins** : ceux du design (`ReplicatedStorage.Assets.Combat`), avec les attributs
  `HeroClass`, `HeroInstanceId` et `Slot`.
- **Apparition de test** (Studio uniquement) : `ArenaConfig.TestSpawn` (`nil` pour désactiver).
- **Intro de démonstration** : pendant une préparation ou un combat, le serveur coupe
  `IntroDemoBoucle` (runtime) puis le restaure ; avec un héros en main sur une arène libre, le
  client la suspend localement. Ses restes `IntroCombat` sont retirés.

## Limites (prototype)

- L'arène est celle de `PlotTravail`, pas celle du plot du joueur, qui n'a pas encore d'arène.
- Icônes de héros provisoires (emoji) : à remplacer par les icônes dessinées du design system.
- Mannequins identiques pour toutes les classes.

## Tests

```powershell
./tools/test-arena.ps1 -LuauPath <chemin-vers-luau.exe>
```

ArenaRules (formation), ArenaPrep (placement, E, deux joueurs, cycle de vie, avec des doubles
de ZoneService, HeroService et CombatService) et PlacementState (hotbar, sacoche > Placer,
clic sur une case, verrou pendant le combat).
