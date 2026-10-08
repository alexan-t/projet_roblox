# Héros possédés et hotbar — HeroService (partie Alpha de #10)

Ce qui existe : exemplaires de héros possédés, **kit de départ**, **hotbar** de 10 raccourcis
sauvegardée, vérification de possession pour l'arène. Ce qui manque encore (#10) : invocation,
niveaux, rareté, édition manuelle de la hotbar.

## Données (`PlayerData`)

- `Heroes : { [HeroInstanceId] = { HeroId, Level } }` : un exemplaire par identifiant unique
  (`H_<GUID>`) ; plusieurs exemplaires d'un même `HeroId` sont possibles.
- `Hotbar : { string }` : **exactement 10** identifiants d'exemplaires, `""` = raccourci vide
  (pas de tableau à trous dans ProfileStore). Clé ajoutée par `Profile:Reconcile()` : aucune
  migration de `DataVersion` nécessaire.
- Alpha : `HeroId` = classe de combat (`Archer`, `Epeiste`, `Barbare`, `Paladin`, `Magicien`,
  `Tireur`, clés de `CombatConfig.Heroes`). Noms et icônes : `src/shared/Config/HeroConfig.lua`.

## Règles (`src/server/Heroes/HeroRules.lua`, pur, testé)

- **Kit de départ** : un joueur qui ne possède **aucun** héros reçoit les 6 classes, une fois,
  rangées dans les raccourcis 1 à 6.
- **Nouveau héros** : ajouté à la première case libre de la hotbar ; hotbar pleine → il reste
  dans la collection (sacoche).
- **Hotbar normalisée** au chargement : 10 cases, uniquement des exemplaires possédés, sans
  doublon.
- **Possession** : `ownedHeroId` ne renvoie un `HeroId` que pour un exemplaire possédé ET connu
  du combat ; sinon « héros inconnu » ou « héros non disponible au combat ».
- La hotbar représente les héros **accessibles rapidement**, pas l'équipe : l'arène reste
  limitée à 4 héros posés.

## API serveur

| Méthode | Résultat |
| --- | --- |
| `GetCombatHero(player, instanceId)` | `HeroId`, ou `nil` et la raison (utilisé par ArenaService) |
| `AddHero(player, heroId)` | identifiant du nouvel exemplaire (hotbar si une case est libre) |
| `RemoveHero(player, instanceId)` | `true` si retiré (et libéré de la hotbar) |

Chaque changement rafraîchit le royaume (`KingdomService:Refresh`) et le client.

## Remotes

- `Remotes.GetHeroes` (RemoteFunction) : `{ Heroes = { {Id, HeroId, Level} }, Hotbar = {10} }`.
- `Remotes.HeroesChanged` (RemoteEvent, serveur → joueur) : même vue, à chaque changement.

Le client n'envoie rien à HeroService : sélectionner un héros (hotbar, sacoche) est un état
local ; seul le placement passe par ArenaService, qui revérifie la possession.

## Debug (Studio)

`ServerStorage.DebugData:Invoke(player, "AddHero", "Archer")` et `"RemoveHero", id` passent
par HeroService (hotbar comprise).

## Tests

```powershell
./tools/test-heroes.ps1 -LuauPath <chemin-vers-luau.exe>
```
