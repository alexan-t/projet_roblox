# Mise en scène du combat

Le combat est une petite scène, entièrement côté client : les ennemis arrivent du décor du plot du
joueur, le joueur lance la défense, les familles d'ennemis attaquent et meurent chacune à leur façon, et
la victoire se termine par un sac de récompenses puis l'écran de fin. Le moteur (`CombatEngine`), les
stats et les récompenses (`RewardService`) ne changent pas : le serveur reste seul juge.

| Fichier | Rôle |
| --- | --- |
| `src/shared/Config/EnemyPresentationConfig.lua` | profils par ennemi (entrée, attaque, mort, déroulé de mort), outro, palette |
| `src/client/Controllers/CombatPresentationController.lua` | intro avant Prêt, CTA « Défendre la base », remplacement par les modèles du combat, vagues suivantes, outro |
| `src/client/Controllers/EnemyPresentationController.lua` | styles d'entrée, d'attaque, de mort, sac |
| `src/client/Combat/PresentationFlow.lua` | état de présentation (pur, testé) |
| `src/client/Combat/RewardBagGuard.lua` | un sac par combat gagné (pur, testé) |
| `src/client/Combat/OutroGate.lua` | déroulé de l'outro et attente de l'écran de fin (pur, testé) |
| `src/server/Config/CombatConfig.lua` (`Presentation`) | retenues du moteur pendant les entrées (`EntranceHold`) |
| `tools/test-presentation.ps1` | tests purs (profils, origines, état, sac, outro, guidage) |

## Déroulé

```
Pancarte → « Lancer »  (ExpeditionView ; plus de combat immédiat)
→ le joueur est (ou entre) dans SON arène          WaitingForArenaEntry → EnemyIntro
→ la 1re vague sort du décor de SON plot, prend position
→ « DÉFENDRE LA BASE · E »                         AwaitingDefense
→ E / clic / toucher → Ready (le serveur revérifie stage, équipe 1 à 4, plot, combat déjà actif)
→ le moteur est retenu StartHold : chaque ennemi présenté rejoint sa vraie case (tirée par le moteur),
  puis le modèle du combat le remplace dans la même image                                    Combat
→ vagues suivantes / boss : retenue EntranceHold, entrée depuis le décor, reprise automatique
→ victoire : mort complète, sac, respiration, « VICTOIRE ! », écran de fin                   Reward
→ Continuer : sac retiré, retour au calme                                                     Idle
```

Annulations : X du CTA (annule la défense, garde l'équipe), Quitter, changement de stage, arène fermée
ou plot perdu → copies d'intro, CTA, sac et outro nettoyés (`PresentationFlow:cancel`, générations : une
intro périmée ne peut plus rien faire). Le CTA n'existe qu'en `AwaitingDefense`, joueur dans son arène,
au moins un héros posé ; jamais pendant un combat ; un seul Ready à la fois.

## Origines des ennemis

Repères déjà présents dans chaque plot (aucun asset ajouté) :
`Arene.Zones.<Zone>.SourcesEnnemis`, parties invisibles avec l'attribut `Mode` et des enfants
optionnels `Etape1`, `Etape2`... (points de passage). `FrontEnnemi` = zone de formation (grille 3x3,
la même que `ArenaService`).

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

Stratégie retenue : **transition invisible**. Les ennemis présentés avant Prêt sont des copies locales
(même asset que le serveur). Après Prêt, `CombatService` retient le moteur (`StartHold` 0,6 s) : chaque
copie rejoint la case de son modèle de combat (caché localement, barres cachées par l'attribut local
`Intro`), s'aligne exactement sur lui, puis le modèle réapparaît et la copie est détruite dans la même
image. Vagues suivantes et boss : `EntranceHold` = respiration + plus longue entrée de la vague
(`CombatConfig.Presentation`), envoyé au client qui cale ses entrées dessus.

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
- Aucun repère ajouté : les `SourcesEnnemis` existaient déjà dans les 8 plots.

## Tests Studio

Hook réservé à Studio (`RunService:IsStudio()`) : l'attribut local `StudioLancer` du joueur arme la
défense comme « Lancer » (la pancarte E n'est pas affichée dans une session pilotée par MCP).
