# Invocation — portail, interface et effet selon la rareté

Côté client :

- `src/client/Controllers/SummonController.lua` : interaction au portail et enchaînement ;
- `src/client/UI/Views/SummonView.lua` : fenêtre et carte du héros ;
- `src/client/Controllers/SummonEffectController.lua` : effet 3D au portail.

Le tirage (quel héros, quelle rareté, doublon ou non) relève de HeroService (voir `docs/HEROES.md`
§ Invocation, § Raretés, § Bannières).

## Au portail

1. **E près de SON portail** : `ProximityPrompt` local « Invoquer », sur le voile du `PortailInvocation`
   de son plot (portée 14 studs ; le serveur accepte 18 studs du pivot). Comme tout prompt Roblox,
   il n'apparaît que si le portail est à l'écran.
2. **Fenêtre « Invocation »** (`SummonView.Show`) :
   - à gauche, un onglet par bannière ;
   - au centre, la bannière choisie : nom, accroche, 3 héros mis en avant en cartes 3D (vrais
     modèles), avec le contour et le badge de leur rareté ;
   - en bas, « Tickets : n » (`Remotes.GetSummonState`), le coût, le bouton **Taux** (chances par
     rareté, en deux colonnes) et le bouton principal **Invoquer**. Sans ticket, « Invoquer » est
     désactivé et une aide indique d'en gagner en combattant.
3. **Invoquer** : `RequestSummon(bannerId)`. En cas de refus, un message bref s'affiche. Sinon :
   - la caméra cadre le portail (plan fixe, de côté, pour que le joueur ne cache pas le héros) ;
   - l'effet se joue selon la rareté ;
   - la carte du héros apparaît (`SummonView.Reveal` : rayons et contour de la couleur de la rareté,
     nom, rareté, « Nouveau »).
4. **Continuer** : le héros posé devant le portail disparaît, la caméra revient au joueur et le
   prompt se réactive.

## Effet (rang 1 Commun → 10 Transcendant)

Tous les rangs suivent la même base :

| Temps | Étape |
| --- | --- |
| 0 → charge | **Charge** : le vortex s'illumine de la couleur de la rareté, des étincelles convergent vers le voile, la lumière monte. La charge dure 1,2 s, plus 0,2 s par rang. |
| charge | **Éclat** : pic de lumière, gerbe d'étincelles, ondes au sol |
| + 0,45 s | Le héros **jaillit du voile** en silhouette colorée et se pose à 7 studs devant le portail |
| + 0,6 s | Poussière, la silhouette s'efface et révèle le héros. Son nom et sa rareté s'affichent au-dessus, avec « Nouveau ». |

Plus la rareté est haute, plus l'effet marque le joueur :

| Rareté | En plus |
| --- | --- |
| Commun, Peu commun | la base, à leur couleur |
| Rare | colonne de lumière vers le ciel (visible de loin), annonce « Rare ! » à l'écran |
| Épique | deux ondes au sol |
| Légendaire | kit doré `EffetJackpot` du portail, secousse de caméra, son « Royaume » |
| Mythique | flash plein écran, grande annonce |
| Maudit | colonne d'ombre (mate, assombrie), fumée sombre, voile d'ombre plein écran, trois ondes |
| Suprême | flash blanc céleste, kit doré |
| Calamité | braises, secousse forte, son « Seisme » |
| Transcendant | quatre ondes ; toute la lumière, la silhouette et le texte parcourent le prisme `UITheme.RarityPrism` |

Couleurs : uniquement `UITheme`. Les raretés utilisent `UITheme.Rarity`. Sans rareté, l'effet est
doré (démonstration). Le kit doré du portail ne sert qu'aux raretés lumineuses (Légendaire,
Mythique, Suprême).

Le portail n'est pas modifié (les attributs `Anim*` de `PortalAmbientController` ne sont pas
touchés) ; seuls des objets temporaires sont ajoutés puis détruits.

## API

```lua
SummonEffectController.Play(portal: Model, heroTemplate: Model, options?) -> Model?
-- options = { Name: string?, New: boolean?, Rarity: string?, Jackpot: boolean?, Keep: number? }
SummonEffectController.Duration(rarity?) -> number -- secondes jusqu'à la révélation du héros
```

- `heroTemplate` n'est pas modifié : une copie locale ancrée, sans collision ni requête, est posée.
- L'avant du héros est déduit de ses bras (`left_arm_geom` / `right_arm_geom`), comme dans
  AnimationKit, car le pivot des modèles générés est arbitraire.
- `Keep` : secondes avant de retirer la copie après la révélation (4 par défaut). Avec `0`, la copie
  reste et l'appelant la détruit lui-même.
- `src/client/UI/RarityStyle.lua` : couleur, libellé, badge et prisme qui tourne d'une rareté
  (partagé par la fenêtre et l'effet).

**Contrat HeroService** :

- le client demande `Remotes.RequestSummon(bannerId)` près du portail de son plot ;
- le serveur décide et sauvegarde tout, puis rafraîchit le royaume ;
- il répond `{ InstanceId, HeroId, Name, New, Rarity }`, et envoie la même chose au seul joueur
  concerné par `Remotes.HeroObtained` ;
- le modèle à révéler est l'enfant de `ReplicatedStorage.Assets.Heros` dont l'attribut `HeroId`
  correspond (copie créée par HeroService au démarrage).

## Démonstration Studio

Dossier tagué `ApercuInvocation` (dans Test 3 : `ReplicatedStorage.AtelierInvocation`, rangé hors du
Workspace pour que les modèles ne soient pas visibles) contenant :

- des copies de héros (jamais ceux du Bestiaire), avec l'attribut `NomAffiche` ;
- un `ObjectValue` nommé `Portail` pointant vers le portail.

Au Play, un héros sort toutes les `ApercuPause` secondes (6 par défaut, 4 minimum), avec une rareté
qui monte d'un rang à chaque tour (Commun → Transcendant). Le portail est sur `PlotTravail`, à environ
170 studs du spawn : s'en approcher.
