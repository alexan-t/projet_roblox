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

Un élément manquant (modèle d'état, repère, asset de héros) n'est pas inventé : le
service journalise la raison et ne l'affiche pas.

## État actuel DEV

Assets préparés dans la place Studio « test 3 » (issue #35), puis intégrés dans la DEV commune
(« Projet Roblox - Alpha ») et validés en Studio : `Refresh` affiche l'état 1 et l'état 2, sans
doublon, et renvoie `true` avec des héros réels (`ecuyer_du_rempart` sur `Heros_1`,
`barde_de_fer` sur `Heros_2`).

- `ServerStorage.Assets.RoyaumeEtats` (présent) :
  - `Royaume_Etat1` (`VisualState = 1`) : le royaume niveau 1 validé (celui de `PlotTravail`) ;
  - `Royaume_Etat2` (`VisualState = 2`) : le niveau 2 de la vitrine, aligné sur le niveau 1 comme
    dans `Workspace.AtelierRoyaume` (montée de niveau validée).
  - Pivot = placement de KingdomService sur `EmplacementCentral` : posé sur `PlotTravail`, l'état 1
    retombe exactement sur le royaume d'origine (écart mesuré 0,0000 stud).
  - Chacun contient son modèle `Fumee` tagué `FumeeCheminee`, sans script, tout ancré.
  - `Emplacements.Heros.Heros_1..6` : au sol, en arc de rayon 20 studs devant le socle, du côté
    d'où arrive le joueur (`PointApparition`), tournés vers lui. `Heros_1` au centre, puis
    alternance droite / gauche. Repères invisibles, sans collision ni requête.
- `ServerStorage.Assets.Heros` (présent) : les **60 héros réels** du Bestiaire, un `Model` par
  `HeroId` (reprend l'attribut `HerosId` du Bestiaire, attribut `Rarete` conservé). Pivot aux pieds,
  face avant déduite des bras (ou, à défaut, du sens dans lequel les héros font face au Bestiaire).
  Le pivot de `briseur_de_cloche`, posé sur le buste dans Test 3, a été recalé aux pieds dans la DEV.
  - **Héros de départ proposé** : `ecuyer_du_rempart` (celui des animations #16).
  - Les 38 derniers (raretés Légendaire à Transcendant surtout) ont été copiés du Bestiaire avec la
    même règle (pivot aux pieds, face avant des bras, sinon +Z du Bestiaire) ; le Bestiaire n'est
    pas modifié.
  - Tout `HeroId` de `HeroConfig` (les 60) peut sortir d'une invocation (`docs/HEROES.md`).
- `Workspace.Lobby.Plots.Plot_1..8` : `PlotId`, `PointApparition` ancré, `Royaume.EmplacementCentral`,
  **sans** royaume posé (les anciens royaumes posés sont rangés dans
  `ServerStorage.Archive_Plots.Lobby_RoyaumesPosesAvant35`).

**HeroId réels depuis #10** : `PlayerData.Heroes` ne contient plus que des `HeroId` réels
(`docs/HEROES.md`). Un nouveau joueur obtient l'Écuyer (`Heros_1`) par l'invocation tutorielle, sans
changer le royaume ; sa première invocation payante (héros tiré au hasard, `Heros_2`) fait passer le
royaume de l'état 1 à l'état 2. Les anciens
profils (6 classes temporaires `Archer`… `Tireur`, sans modèle ici) sont migrés en DataVersion 2.
`CombatConfig` garde ces classes comme **profils de combat** temporaires, pas comme HeroId.

## Vitrine des niveaux (Test 3)

`Workspace.VitrineRoyaumes` montre un royaume par niveau, sur 20 socles (`Socle_01` à `Socle_20`,
attribut `Niveau`, plaque « Niveau N », `PointDePose` = repère du royaume). Chaque modèle
`Royaume_NiveauN` (attribut `Niveau = N`) est posé sur le `PointDePose` de son socle, comme le royaume
sur `EmplacementCentral` dans un plot. **Règle de progression** : un niveau reprend le niveau précédent
(même île, même entrée vers -Z local, même palette : bois, chaume, pierre, bleu royal et or, losange
emblème) et le fait grandir ; rien n'est réinventé d'un niveau à l'autre.

| Niveau | Royaume | Nouveautés |
| --- | --- | --- |
| 1 | Campement | Maison du chef, tente, puits, feu de camp, champ, palissade partielle, portail (modèles importés) |
| 2 | Hameau | Palissade fermée, maison de villageois, atelier de bûcheron, meules de foin |
| 3 | Village | Tour de guet, étal de marché, palissade complète |
| 4 | Village fortifié | Deux tours de guet à l'entrée, moulin, maison neuve sur le terrain à bâtir |
| 5 | Bourg | Rempart de pierre à l'avant, porte fortifiée à herse, tours d'angle, chapelle (à la place de la tente), second étal |
| 6 | Ville fortifiée | Enceinte de pierre complète, tours du fond, tour de guet de pierre |
| 7 | Château | Donjon crénelé à quatre tourelles au fond (à la place de la maison de villageois) |
| 8 | Citadelle royale | Donjon couronné d'un étage royal et d'un cœur lumineux, tours plus hautes à bandeaux et étendards d'or, porte dorée, grand étendard |
| 9 | Cité royale | Île élargie, tours latérales dorées, grande salle du palais (à la place de la maison neuve), piliers royaux à brasero devant la porte |
| 10 | Capitale | Douves et pont devant la porte, cathédrale à rosace et clocher doré (à la place de la chapelle, du moulin et de l'atelier) |
| 11 | Royaume radieux | Tour des mages à cristal flottant et anneaux d'or (à la place de la tour de guet), statue d'or du roi sur la place (à la place du feu de camp), lanternes flottantes |
| 12 | Palais du roi | Palais à dôme d'or, étage et tourelles dorées (à la place du donjon), chemin de ronde doré, fronton à grand losange sur la porte |
| 13 | Cité haute | Passerelles de pierre à garde-corps d'or du palais aux tours du fond, jardins suspendus sur le rempart du fond, fontaine royale sur l'allée |
| 14 | Empire du roi | Deux chevaliers gardiens géants sur le rempart, de part et d'autre de la porte ; couronne d'or à joyaux flottant autour de la flèche du palais |
| 15 | Royaume des cascades | L'île ne peut plus s'élargir (socle de 38) : le royaume grandit vers le haut. Cascades qui débordent du rempart dans les douves, longues tentures bleues sur le rempart avant, arche fleurie à l'entrée de la place |
| 16 | Îles célestes | Trois îlots flottants à tours dorées, enchaînés d'or aux tours du royaume et au palais |
| 17 | Royaume des arcanes | Cœur de cristal géant à anneaux d'or au-dessus de la couronne, faisceaux de lumière vers les îlots et la tour des mages, cercle de runes lumineuses sur la place |
| 18 | Âge d'or | Arc de triomphe de pierre et d'or sur le pont (à la place des piliers royaux), statue d'or du roi au sommet, tours du rempart coiffées d'or |
| 19 | Royaume ailé | Immenses ailes d'or déployées derrière le palais, auréole lumineuse |
| 20 | Royaume légendaire | Citadelle céleste (sanctuaire, tourelles, dôme d'or) sur une roche flottante au-dessus du royaume, reliée par une colonne de lumière, étoiles |

Niveaux 4 à 20 : `tools/studio-royaumes-vitrine.luau` (`FIRST`, `LAST` : niveaux reconstruits) (Studio EDIT, répétable, une étape d'annulation),
construits en pièces Roblox aux couleurs relevées sur les niveaux 1 à 3, à partir d'une copie du niveau
précédent. Ils ne sont **pas encore** des états de jeu : `RoyaumeEtats` ne contient que les états 1 et 2.
Pour en faire un état : copier le modèle dans `RoyaumeEtats` avec `VisualState = N`, pivot aligné sur
`Royaume_Etat1` (voir `Royaume_Etat2`), ses `Emplacements.Heros.Heros_1..6` et son modèle `Fumee`.

Contrôle visuel des niveaux 4 à 20 (captures réelles, `docs/VISUAL_QA.md`) : **PASS** pour chacun
([4](../automation/screenshots/royaumes/niveau-4.jpg), [5](../automation/screenshots/royaumes/niveau-5.jpg),
[6](../automation/screenshots/royaumes/niveau-6.jpg), [7](../automation/screenshots/royaumes/niveau-7.jpg),
[8](../automation/screenshots/royaumes/niveau-8.jpg), [9](../automation/screenshots/royaumes/niveau-9.jpg),
[10 à 12](../automation/screenshots/royaumes/niveaux-10-11-12.jpg), [13](../automation/screenshots/royaumes/niveau-13.jpg),
[14](../automation/screenshots/royaumes/niveau-14.jpg), [15](../automation/screenshots/royaumes/niveau-15.jpg),
[16 et 17](../automation/screenshots/royaumes/niveaux-16-17.jpg), [18 et 19](../automation/screenshots/royaumes/niveaux-18-19.jpg),
[20](../automation/screenshots/royaumes/niveau-20.jpg)). Remarque non bloquante : au niveau 13, les passerelles et
les jardins suspendus, derrière le palais, se voient peu de face (la fontaine porte la différence). Remarque non bloquante : au niveau 18, l'arc de triomphe masque une partie de la porte fortifiée de face. Remarque non bloquante : de face, le donjon du niveau 7
est en partie caché par les maisons, le niveau 7 se distingue moins du 6 que le 8 du 7.

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
même endroit (dans Test 3 : `Workspace.AtelierRoyaume`, copies des niveaux 1 à 3 de la vitrine ;
cet atelier n'a pas été importé dans la DEV).

## Cycle de vie

1. `PlotService:OnPlotAssigned` (y compris les attributions déjà faites) appelle `Refresh`.
2. `Refresh` relit `GetPlot`, `GetRuntime` et `DataService:GetData` ; sans l'un d'eux, rien n'est fait.
3. Il cherche le modèle d'état et le repère ; en cas de problème, il journalise la raison
   et **garde l'affichage actuel**.
4. Si l'état affiché vient déjà de ce modèle, il est conservé. Sinon le nouveau clone est
   créé, posé et parenté avant la destruction de l'ancien.
5. Les héros sont synchronisés : un modèle par exemplaire possédé, dans l'**ordre d'obtention**,
   un par repère : d'abord les anciens identifiants (sans horodatage), puis les identifiants
   horodatés de HeroService (`H_T<horodatage>_…`) par date ; à égalité, ordre des identifiants.
   Le starter reste donc sur `Heros_1`. Les héros déjà affichés sont conservés et replacés ; ceux
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
