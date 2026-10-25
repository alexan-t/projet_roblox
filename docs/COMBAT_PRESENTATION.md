# Mise en scène du combat

Le combat est une petite scène, côté client : au lancement, les ennemis arrivent du décor du plot du
joueur, les familles d'ennemis attaquent et meurent chacune à leur façon, et la victoire se termine par
un sac de récompenses puis l'écran de fin. Le moteur (`CombatEngine`), les
stats et les récompenses (`RewardService`) ne changent pas : le serveur reste seul juge.

| Fichier | Rôle |
| --- | --- |
| `src/shared/Config/EnemyPresentationConfig.lua` | profils par ennemi (entrée, attaque, mort, déroulé de mort), outro, palette |
| `src/client/Controllers/CombatPresentationController.lua` | entrée de chaque vague depuis le décor, remplacement par les modèles du combat, outro |
| `src/client/Controllers/EnemyPresentationController.lua` | styles d'entrée, d'attaque, de mort, sac |
| `src/client/Combat/RewardBagGuard.lua` | un sac par combat gagné (pur, testé) |
| `src/client/Combat/OutroGate.lua` | déroulé de l'outro et attente de l'écran de fin (pur, testé) |
| `src/server/Config/CombatConfig.lua` (`Presentation`) | retenues du moteur pendant les entrées (`EntranceHold`), modèles gardés en fin de combat (`EndHold`) |
| `tools/test-presentation.ps1` | tests purs (profils, origines, état, sac, outro, guidage) |

## Déroulé

```
Pancarte → « Lancer »  ou  F / clic sur « F · Lancer le combat » dans l'arène (équipe posée)
→ Ready (le serveur revérifie stage, équipe 1 à 4, plot, combat déjà actif) ; pas besoin d'être dans
  l'arène depuis la pancarte
→ le moteur est retenu (StartBreather + plus longue entrée) : la 1re vague sort du décor de SON plot
  jusqu'à ses vraies cases, puis le combat démarre tout seul
→ vagues suivantes / boss : retenue EntranceHold, entrée depuis le décor, reprise automatique
→ victoire : mort complète, sac, respiration, « VICTOIRE ! », écran de fin
→ Continuer : sac retiré ; l'équipe est reposée sur ses dalles (EndHold après la fin)
```

Annulations : Quitter (X du combat), arène fermée ou plot perdu → copies d'entrée, sac et outro
nettoyés. La pastille « F · Lancer » n'apparaît que dans SON arène, équipe posée, rien en main, aucun
écran ouvert, et pas pendant l'outro d'un combat qui vient de finir.

## Origines des ennemis

Repères déjà présents dans chaque plot (aucun asset ajouté) :
`Arene.Zones.<Zone>.SourcesEnnemis`, parties invisibles avec l'attribut `Mode` et des enfants
optionnels `Etape1`, `Etape2`... (points de passage). `FrontEnnemi` = zone de formation (grille 3x3,
la même que `ArenaService`). Depuis l'agrandissement des plots (`docs/PLOTS.md` § Agrandissement),
le front, le camp et les repères du côté ennemi sont 20 studs plus loin des dalles ; les repères des
mares restent en place, les slimes bondissent donc plus loin.

| Style (`SpawnStyles`) | Modes acceptés, par préférence | Zone 1 |
| --- | --- | --- |
| `Lake` (Slime) | `SautMare` | les mares du coin des slimes : sous l'eau, remonte, bondit, petits bonds |
| `Camp` (Gobelin) | `SortieTente`, `DescenteRampe`, `SautPlateau` | la tente et la rampe du camp, marche (animation Marche) |
| `CampBoss` (Roi Orc) | `DescenteRampe`, `SortieTente` | descend la rampe du camp, lourd, poussière et petite secousse à l'arrêt |
| `Bush` (inconnu) | `SortieBuisson` | buissons |

Tout est résolu depuis le plot du joueur local (`PlotView`) : jamais `Workspace.PlotTravail`, jamais le
décor d'un autre plot. Un nouveau monde n'a qu'à poser ses repères `SourcesEnnemis` avec les mêmes `Mode`.

## Profils (`EnemyPresentationConfig.Profiles`)

| Ennemi | Attaque | Mort |
| --- | --- | --- |
| `Slime` | `SlimeHeadbutt` : recul, écrasement, coup de tête (impact 0,27 s), 7 grosses gouttes de sa couleur | `SlimeBurst` : écrasé, gonfle, POP, gouttes, éclaboussure |
| `Gobelin` | `SpearThrust` : animation Attaque (impact 0,45 s), petite traînée et étincelle à la pointe de la vraie lance | `HumanoidFall` : encaisse, animation Mort + bascule du corps au sol, reste au sol, s'efface |
| `Boss` | `HeavyWeapon` : Fendoir + Seisme existants (`AttackEffectController`), inchangés | `HumanoidFallHeavy` : chute lourde, poussière, secousse |

Couleur des effets : attribut `CouleurEffet` (Color3) du modèle de combat (Studio), sinon celle du profil.
Arme : os `ArmeDroite` / `ArmeGauche` (squelette commun), sinon la pièce tenue (ancien rig : `Tenu_*`,
nom d'objet tenu comme `spear_geom`), jamais le centre du modèle. Les chiffres de dégâts et la barre
attendent l'instant d'impact (`hitDelay` de `CombatViewController`). x2 : attaques, morts et effets
suivent la vitesse ; les entrées gardent la vitesse normale.

## Remplacement sans « pop »

Chaque ennemi apparu (1re vague, vagues suivantes, boss) entre sous la forme d'une copie locale (même
asset que le serveur) depuis son origine du décor ; son modèle de combat reste caché localement (barres
cachées par l'attribut local `Intro`). Le serveur ne fait pas avancer le moteur pendant ce temps
(`EntranceHold` = respiration + plus longue entrée, envoyé au client qui cale ses entrées dessus). À
l'arrivée, la copie s'aligne exactement sur le modèle du combat, qui réapparaît dans la même image.

Fin de combat : `CombatService` garde les modèles `EndHold` (6 s) au lieu de les retirer d'un coup, et
`ArenaService` ne repose l'équipe sur ses dalles qu'ensuite (derrière l'écran de fin). Annuler ou
quitter retire tout immédiatement.

## Outro et sac

Le serveur attribue et sauvegarde les récompenses dès la fin (rien n'est ralenti). Seule la présentation
attend : `OutroGate.schedule` à partir du déroulé de la mort du dernier ennemi (`DeathTiming`) :

```
coup fatal → mort complète (Gobelin : au sol ~0,8 s)
→ sac près du corps (BagDrop ; côté héros, BagOffset) → rebond (BagBounce 0,8 s)
→ respiration (Breather 0,7 s) → « VICTOIRE ! » / « BOSS VAINCU ! » (VictoryHold 0,9 s)
→ CombatOutroFinished → écran de fin
```

Mesuré dans Studio (1-1, dernier Gobelin) : sac +1,26 s, VICTOIRE +2,76 s, écran +3,65 s après le
CombatEnded. Le corps ne s'efface qu'après le rebond du sac (`FadeStart`). Défaite : pas de sac, pas
d'annonce, courte pause (`DefeatHold`). Sécurité : l'écran s'ouvre quoi qu'il arrive après `Safety` (8 s).

Le sac est **100 % visuel** (`SacRecompense`, asset Studio de `ReplicatedStorage.Assets.Combat`) :
un seul par combat gagné (`RewardBagGuard`), jamais sur défaite. Retiré à Continuer, au lancement d'un
nouveau combat, au Quit, si le plot / la session disparaît.

## Assets Studio

- `ReplicatedStorage.Assets.Combat.SacRecompense` : sac de toile, corde, pièce d'or en façade (-Z),
  pièces au pied ; `PrimaryPart` = `Corps`.
- `ReplicatedStorage.Assets.Combat.Ennemi_Slime` : attribut `CouleurEffet` = `#76CCF6`.
- `Ennemi_Slime` (`WorldPivot`) et `Ennemi_Gobelin` (`HumanoidRootPart.PivotOffset`) : pivot tourné de
  180° pour que l'avant du pivot soit l'avant du modèle (yeux du slime, bras droit du gobelin) ; avant,
  ils faisaient face dans le mauvais sens, en combat comme à l'entrée. Rig et animations inchangés.
- Aucun repère ajouté : les `SourcesEnnemis` existaient déjà dans les 8 plots.

## Tests Studio

Lancer depuis l'arène se teste avec la vraie touche F (la pancarte E n'est pas affichée dans une session
pilotée par MCP).
