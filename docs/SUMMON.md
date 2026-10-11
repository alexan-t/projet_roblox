# Invocation — effet d'apparition du héros (issue #17)

Effet purement visuel, côté client : `src/client/Controllers/SummonEffectController.lua`.
En jeu, il se joue au `PortailInvocation` **du plot du joueur** (la démonstration Studio utilise
celui de `PlotTravail`). Le tirage lui-même (quel héros, doublon ou non) relève de HeroService (#10,
voir `docs/HEROES.md`).

## Déroulé (≈ 2,3 s jusqu'au nom affiché)

| Temps | Étape |
| --- | --- |
| 0 → 1,2 s | **Charge** : le vortex s'illumine d'or (Highlight), des étincelles convergent vers le voile, une lumière dorée monte |
| 1,2 s | **Éclat** : pic de lumière, gerbe d'étincelles, onde dorée au sol sous le portail |
| 1,2 → 1,65 s | Le héros **jaillit du voile** en silhouette dorée et se pose à 7 studs devant le portail, tourné vers l'extérieur |
| 1,65 s | Poussière d'atterrissage, la silhouette s'efface en 0,6 s et révèle le héros ; son nom apparaît au-dessus (Fredoka, contour Ink) avec le badge « Nouveau » |

Couleurs : uniquement `UITheme` (`Gold`, `GoldLight`, `TextLight`, `Sand`, `RoyalRed` pour le
badge). Aucune couleur de rareté n'est utilisée.

**Jackpot** (option) : allume le kit `EffetJackpot` préparé dans le portail (faisceau vers le ciel,
cœur, lumière, étincelles, étoile `SignalCiel`, halo au sol) le temps de l'invocation, puis le
rééteint. Le module ne décide pas quand l'utiliser : c'est à HeroService de le demander.

Le portail n'est pas modifié (les attributs `Anim*` de `PortalAmbientController` ne sont pas
touchés) ; seuls des objets temporaires sont ajoutés puis détruits.

## API

```lua
SummonEffectController.Play(portal: Model, heroTemplate: Model, options?) -> Model?
-- options = { Name: string?, New: boolean?, Jackpot: boolean?, Keep: number? }
```

- `heroTemplate` n'est pas modifié : une copie locale ancrée, sans collision ni requête, est posée.
- L'avant du héros est déduit de ses bras (`left_arm_geom` / `right_arm_geom`), comme dans
  AnimationKit, car le pivot des modèles générés est arbitraire.
- `Keep` : secondes avant de retirer la copie après la révélation (4 par défaut, `0` = la garder ;
  l'appelant la détruit alors lui-même).

**Contrat HeroService (#10, en place)** : le client demande `Remotes.RequestSummon` (sans argument)
près du portail de son plot ; le serveur décide et sauvegarde tout, rafraîchit le royaume, puis envoie
`Remotes.HeroObtained` `{ InstanceId, HeroId, Name, New }` au seul joueur concerné. Le modèle à
révéler est l'enfant de `ReplicatedStorage.Assets.Heros` dont l'attribut `HeroId` correspond (copie
créée par HeroService au démarrage). Le branchement client (`Play` sur `HeroObtained`, interface
d'invocation) relève de #11.

## Démonstration Studio

Dossier tagué `ApercuInvocation` (dans Test 3 : `ReplicatedStorage.AtelierInvocation`, rangé hors du
Workspace pour que les modèles ne soient pas visibles) contenant :

- des copies de héros (jamais ceux du Bestiaire), avec l'attribut `NomAffiche` ;
- un `ObjectValue` nommé `Portail` pointant vers le portail.

Au Play, un héros sort toutes les `ApercuPause` secondes (6 par défaut, 4 minimum), un jackpot une
fois sur trois. Le portail est sur `PlotTravail`, à environ 170 studs du spawn : s'en approcher.
