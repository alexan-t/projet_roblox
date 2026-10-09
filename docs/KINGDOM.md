# Royaume miniature — KingdomService V1

`KingdomService` (#4) affiche le royaume et les héros de chaque joueur sur son plot.
Il décide **quoi** afficher (quel état, quels héros, pour quel joueur, quand) ;
les modèles fournis par le design (#5) décident **à quoi ça ressemble**.
Aucune couleur, matière, forme, taille ou VFX n'est réglée dans le code : les
modèles sont clonés tels quels.

## Contrat d'assets (Studio)

Les chemins sont centralisés dans `src/server/Config/KingdomConfig.lua`.

```text
ServerStorage
  Assets
    RoyaumeEtats (Folder)
      <nom libre> (Model, attribut numérique VisualState = 1)
        Emplacements (Folder)
          Heros (Folder)
            Heros_1, Heros_2, ... (BasePart)   repères des héros, facultatifs
      <nom libre> (Model, VisualState = 2)
      ...
    Heros (Folder)
      <nom libre> (Model, attribut texte HeroId = "Chevalier")
      ...

Workspace.Lobby.Plots.<plot> (dossier de PlotConfig, voir docs/PLOTS.md)
  Royaume
    EmplacementCentral (BasePart)   repère du royaume
```

- **États du royaume** : un `Model` par `VisualState`, identifié par l'attribut,
  pas par son nom. Ajouter l'état 3 = ajouter un modèle avec `VisualState = 3`,
  sans toucher au code. Deux modèles avec la même valeur sont refusés.
- **Repère du royaume** : `Royaume.EmplacementCentral` dans le plot, comme dans
  `Workspace.PlotTravail`. Le **pivot** du modèle d'état est posé sur la
  position de ce repère, avec son orientation horizontale uniquement (un disque
  couché ne fait pas basculer le royaume). Le design règle donc le pivot du
  modèle (base, face avant) et l'orientation du repère.
- **Repères des héros** : dans chaque modèle d'état, sous `Emplacements.Heros`,
  sur le modèle de l'arène (`Arene.Emplacements.Heros`). Ils sont triés par le
  numéro final du nom (`Heros_2` avant `Heros_10`). Chaque état peut avoir sa
  propre disposition et son propre nombre de places.
- **Modèles de héros** : un `Model` par `HeroId` (valeur de `PlayerData.Heroes[id].HeroId`),
  pivot posé comme pour le royaume.
- Tous les assets doivent être ancrés, `Archivable` et sans script.

Ce qui n'existe pas encore dans la DEV (constaté le 27/09/2026) : un modèle
d'état 2, les modèles de héros, les repères de héros dans le royaume, et
`Royaume.EmplacementCentral` dans les plots de `Workspace.Plots`. Sans eux, le
service journalise la raison et n'affiche pas l'élément manquant.

### Assets préparés dans Test 3 (issue #35)

Préparés et vérifiés dans la place Studio « test 3 », à copier dans la DEV commune :

- `ServerStorage.Assets.RoyaumeEtats` :
  - `Royaume_Etat1` (`VisualState = 1`) : le royaume niveau 1 validé (celui de `PlotTravail`) ;
  - `Royaume_Etat2` (`VisualState = 2`) : le niveau 2 de la vitrine, aligné sur le niveau 1 comme
    dans `Workspace.AtelierRoyaume` (montée de niveau validée).
  - Pivot = placement de KingdomService sur `EmplacementCentral` : posé sur `PlotTravail`, l'état 1
    retombe exactement sur le royaume d'origine (écart mesuré 0,0000 stud).
  - Chacun contient son modèle `Fumee` tagué `FumeeCheminee`, sans script, tout ancré.
  - `Emplacements.Heros.Heros_1..6` : au sol, en arc de rayon 20 studs devant le socle, du côté
    d'où arrive le joueur (`PointApparition`), tournés vers lui. `Heros_1` au centre, puis
    alternance droite / gauche. Repères invisibles, sans collision ni requête.
- `ServerStorage.Assets.Heros` : les 22 héros du Bestiaire, un `Model` par `HeroId` (reprend
  l'attribut `HerosId` du Bestiaire, attribut `Rarete` conservé). Pivot aux pieds, face avant
  déduite des bras (ou, à défaut, du sens dans lequel les héros font face au Bestiaire).
  - **Héros de départ proposé** : `ecuyer_du_rempart` (celui des animations #16).
  - Tout `HeroId` de la liste peut sortir d'une invocation : `alchimiste_aux_masques`,
    `apprenti_pyromancien`, `barde_de_fer`, `brise_pierre`, `briseur_de_cloche`,
    `cartomancienne_d_ambre`, `chevalier_du_lierre`, `chevalier_du_soleil_creux`,
    `dame_aux_mille_bannieres`, `duelliste_du_croissant`, `ecuyer_du_rempart`, `fauconnier_gris`,
    `forgeron_runique`, `gardien_des_ronces`, `guetteuse_des_pins`, `lancier_des_champs`,
    `lanciere_des_sources`, `mage_des_lanternes`, `moine_du_vent_bas`, `pretresse_aux_lucioles`,
    `tireuse_des_faubourgs`, `veneur_de_givre`.
- `Workspace.Lobby.Plots.Plot_1..8` : `PlotId`, `PointApparition` ancré, `Royaume.EmplacementCentral`,
  **sans** royaume posé (les anciens royaumes posés sont rangés dans
  `ServerStorage.Archive_Plots.Lobby_RoyaumesPosesAvant35`).

## Runtime

```text
<plot>.Runtime          (créé et détruit par PlotService)
  Kingdom (Model)       clone du modèle d'état courant
  Heroes (Folder)
    <modèle de héros>   attribut HeroInstanceId = clé dans PlayerData.Heroes
```

Tout vit sous le `Runtime` de l'attribution : au départ du joueur ou à la perte
de ses données, PlotService détruit le royaume et les héros avec lui. Le décor
permanent du plot n'est jamais modifié. Les autres futurs systèmes peuvent
ajouter leurs propres dossiers dans `Runtime` : KingdomService ne touche qu'à
`Kingdom` et `Heroes`.

## Montée de niveau visible (client)

`src/client/Controllers/KingdomChangeController.lua` (issue #17) transforme le remplacement du
modèle `Kingdom` en montée de niveau lisible, sans rien changer côté serveur : quand un `Kingdom`
d'un **autre** `VisualState` remplace le précédent dans un `Runtime`, un nuage de poussière et des
étincelles jaillissent du sol, le nouveau royaume sort du sol (léger dépassement), une onde dorée
court au sol et « Royaume niveau N ! » s'affiche au-dessus (design system). Le premier affichage
(arrivée du joueur, streaming) ne déclenche rien. Seul le pivot bouge : aucune animation pièce par
pièce sur ces modèles de plusieurs centaines de pièces.

Le modèle d'état doit donc porter l'attribut `VisualState` (déjà requis ci-dessus). Démonstration
Studio : tag `ApercuRoyaume` sur un dossier de modèles portant `VisualState` ou `Niveau`, posés au
même endroit (dans Test 3 : `Workspace.AtelierRoyaume`, copies des niveaux 1 à 3 de la vitrine).

## Cycle de vie

1. `PlotService:OnPlotAssigned` (y compris les attributions déjà faites) appelle `Refresh`.
2. `Refresh` relit `GetPlot`, `GetRuntime` et `DataService:GetData` ; sans l'un d'eux, rien n'est fait.
3. Il cherche le modèle d'état et le repère ; en cas de problème, il journalise la raison
   et **garde l'affichage actuel**.
4. Si l'état affiché vient déjà de ce modèle, il est conservé. Sinon le nouveau clone est
   créé, posé et parenté avant la destruction de l'ancien.
5. Les héros sont synchronisés : un modèle par exemplaire possédé, dans l'ordre des
   identifiants, un par repère. Les héros déjà affichés sont conservés et replacés ; ceux
   qui ont disparu ou changé de `HeroId` sont retirés. Un héros sans asset ou sans repère
   n'est pas affiché et rend le résultat `false`, sans retirer les autres.

Tout `Refresh` est synchrone (aucune attente) : le joueur ne peut pas partir au milieu.
Le service ne garde aucune référence aux données ou aux joueurs entre deux appels.

## API serveur

| Méthode | Résultat / usage |
| --- | --- |
| `Refresh(player)` | Met l'affichage en accord avec `Kingdom.VisualState` et `Heroes`. Voir le résultat ci-dessous |
| `GetKingdom(player)` | Modèle `Kingdom` affiché, ou `nil` |

**Résultat de `Refresh`** :

- `true` : l'affichage complet attendu est synchronisé avec PlayerData, c'est-à-dire le
  royaume de l'état courant **et** chaque héros possédé, chacun sur son repère.
- `false` : une partie de cet affichage n'a pas pu l'être. Causes possibles : pas de plot
  ou de données, `VisualState` invalide, modèle d'état, repère du royaume, asset de héros
  ou repère de héros manquant. La raison est journalisée.

Un échec partiel n'est pas destructeur : tout ce qui est valide reste ou devient visible.
Par exemple, royaume valide et 2 héros possédés dont l'un sans asset : le royaume et le
héros valide sont affichés, l'autre est absent, et `Refresh` renvoie `false`. De même,
un royaume invalide laisse en place le royaume et les héros déjà affichés.

**Intégration HeroService (#10)** : il n'existe pas encore de signal `HeroObtained`.
Après avoir ajouté un héros à `PlayerData.Heroes` (ou changé `Kingdom.VisualState`),
le service concerné appelle `KingdomService:Refresh(player)`. Aucun système
d'événements n'est ajouté tant qu'un seul appelant existe.

## Validation

Tests locaux du vrai module, avec doubles des API Roblox (Luau CLI officiel) :

```powershell
./tools/test-kingdom.ps1 -LuauPath <chemin-vers-luau.exe>
```

Ils couvrent : création des états 1 et 2 sur le repère, remplacement sans doublon,
refresh répété, départ, Runtime détruit, plot réattribué, dossier, repère ou asset
manquant ou invalide, VisualState invalide, plusieurs joueurs indépendants, rejoin,
placement et synchronisation des héros, et le résultat strict de `Refresh` (échecs
partiels compris). Le rendu, la physique et la réplication se
valident dans Studio.

En Studio, `ServerStorage.DebugData` (DebugService, Studio uniquement) permet depuis la
ligne de commande côté Serveur : `"SetKingdomState", 2`, `"AddHero", "<HeroId>"`,
`"RemoveHero", id` et `"RefreshKingdom"`.
