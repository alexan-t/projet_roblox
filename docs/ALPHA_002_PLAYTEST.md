# Alpha 0.0.2 : audit gameplay et recette (#111)

29/10/2026, `develop` @ `d0e3384` (#117 Equipment V1 et #118 guidage du premier équipement fusionnées).
Place DEV « Projet Roblox - Alpha », code synchronisé par Rojo et vérifié (167 scripts, octets identiques
au dépôt après conversion des fins de ligne). Store de recette isolé `PlayerData_Recette_A002_A` (profil
neuf, session n°1), attribut `StoreRecette` retiré à la fin. Aucune publication, aucune donnée de
production touchée, aucune valeur de jeu modifiée.

**Statut des informations.** Chaque constat est marqué :

- **[observé]** : vu en jeu dans Studio pendant les parcours ;
- **[code]** : lu dans le dépôt ;
- **[sim]** : simulation de `CombatEngine` portée en JS par un sub-agent, donc une estimation ;
- **[hypothèse]** : avis produit sans mesure.

Il n'existe **aucune donnée joueur** (pas d'Analytics, #113) : rien ici ne mesure la rétention ou le plaisir
réel.

Sub-agents consultés (définitions de la PR #109) : benchmark produit, gameplay/loot/invocation (simulation
chiffrée), QA/sécurité/UI. Leurs conclusions sont intégrées et signalées.

---

## 1. État actuel du jeu

La boucle Alpha fonctionne de bout en bout, sans bug bloquant :

1. plot attribué ;
2. invocation du héros de départ ;
3. combat automatique en arène ;
4. Zone 1 (1-1 à 1-5, boss Roi Orc) ;
5. loot (équipements et ressources) ;
6. équipement des héros (PV/ATK) ;
7. mode Élite 1-1E à 1-5E ;
8. invocation V2 (bannières, ×1/×10/×100) ;
9. quêtes en deux lignes (Défense, Collection) ;
10. sauvegarde et retour.

En revanche, **le contenu jouable s'épuise en un peu plus d'un quart d'heure** :

- les zones 2 à 6 existent mais ne donnent ni butin ni récompense de premier clear ;
- l'or, les gemmes et les 60 ressources n'ont **aucun usage** [code] ;
- la rareté des héros **ne change pas leur puissance** [observé + code].

## 2. Parcours effectués et chronométrés

Les parcours ont été joués par l'agent dans Studio (souris, clavier, déplacements à vitesse normale). Les
premiers combats sont lancés par l'interface (touche F, bouton « Lancer »). Les combats répétitifs
passent par `ArenaAction("Ready")`, le même appel serveur que le bouton, avec toutes les validations
serveur.

Les temps sont **réels côté jeu**, mais un agent lit plus vite qu'un humain qui découvre :
**c'est une borne basse**.

### Parcours A : nouveau joueur [observé]

| Jalon | Temps de session |
|---|---|
| Profil chargé, téléportation sur le plot | ~5 s |
| Premier objectif compris (« Invoque ton premier héros », flèches 3D au sol) | 30 s |
| Héros de départ (Écuyer, révélation 3,6 s) | 1 min 00 |
| Premier combat lancé (hotbar → dalle → F) | 1 min 43 |
| Première victoire (1-1, combat de **5,5 s**) | 2 min 07 |
| Deuxième héros (ticket du 1-1, Épique garanti : Veneur de Givre) | 3 min 25 |
| Premier équipement (Rare, **tombé au hasard en 1-4**, chance de 8 %) | 5 min 46 |
| Zone 1 terminée (1-5 gagné, 2 équipements) | 6 min 23 |
| Combats Normal / défaites | 5 / **0** |

Durée des combats Normal :

| Stage | 1-1 | 1-2 | 1-3 | 1-4 | 1-5 |
|---|---|---|---|---|---|
| Durée | 5,5 s | 6,9 s | 13,4 s | 13,9 s | ~12 s |

### Parcours B : progression et Élite [observé]

| Étape | Résultat |
|---|---|
| Élite 1-1E à 1-3E, 2 héros Nv3-4, **sans équipement** | gagnés du premier coup (6,9 s, 7,7 s, 19,4 s) |
| Élite 1-4E sans équipement | **défaite** (17,8 s) |
| Équipement de l'Écuyer (3 objets) | PV 173 → 223 (+29 %), ATK 18 → 27 (+50 %) |
| Élite 1-4E équipé | 1 défaite, puis victoire |
| Élite 1-5E à 2 héros équipés Nv5 | **2 défaites** : premier mur, à 12 min |
| Farm de 1-4E ×5 (~15,6 s par combat) | +10 tickets, +1 équipement, héros Nv4 → **Nv8** |
| Invocation ×10 | 7 nouveaux héros, dont 1 Légendaire et 2 Épiques |
| Élite 1-5E à 4 héros (2 Nv8, 2 Nv1) | **gagné du premier coup** (19 s) |
| **Contenu Élite terminé** | **16 min 30** de session, 19 combats, 4 défaites |

Effet de l'équipement : perceptible et décisif [observé]. Trois objets Rares ou Communs valent environ
4 niveaux. D'après la simulation [sim], un set complet de 6 pièces Rare équivaut à un niveau 19-20.

### Parcours C : rejouabilité et retour [observé]

- **Replay Normal 1-5** : +5 tickets en 12 s, soit **10 tickets pour 25 s de combat**.
- **Replay 1-1** : +20 or.
- **Replay Élite 1-4** : +2 tickets, XP élevée, 32 % de chance d'équipement.
- **Premier clear contre replay** : le premier clear Élite rapporte **0 ticket**, alors que chaque replay en
  rapporte 2 (10 pour 1-5E). Le premier clear Normal 1-2 à 1-5 ne rapporte ni or, ni gemmes, ni ticket.
- **Après ~20 combats** : 4 équipements (dont 1 doublon) et 92 ressources de 16 types, toutes sans usage.
  L'or est resté à 225 pendant toute l'Élite.
- **Quitter puis revenir** : tout est conservé (12 héros, Écuyer Nv10, 4 équipements dont 3 portés,
  monnaies, 5 clears Normal et 5 Élite). **PASS.**
- **Au retour, rien n'indique quoi faire** : le HUD affiche toujours « Récupérer 1-3 », le stage
  sélectionné est **2-1 (Zone 2 sans butin)**, aucune flèche n'apparaît, et le panneau du plot affiche
  « LIBRE ».

### Projection [sim, sub-agent économie, 1000 profils]

| Jalon | Combats P50 (P10-P90) | Temps de combat seul |
|---|---|---|
| 1re victoire / 2e héros | 1 | ~14 s |
| Fin de la Zone 1 Normal, 1er équipement, accès Élite | 5 (3-5) | ~95 s |
| Fin de l'Élite (3 héros) | 10 | ~3,3 min |
| Fin de l'Élite (2 héros seulement) | 11 (P90 19) | - |

P(aucun équipement avant 1-5) = 79 % : ma chance en 1-4 est l'exception.

## 3. Résultats gameplay et progression

| Système | Verdict | Constat |
|---|---|---|
| Combat automatique | Fonctionne, peu lisible | [observé] Caméra derrière l'avatar, **planté au milieu de l'arène : il masque le combat** (A03). Bandeau « Vague » sans numéro. Combats de 5 à 27 s. Aucun choix pendant le combat, ultimes automatiques. Aucun soin ni bouclier [code]. |
| Composition d'équipe | Intérêt faible | [observé + code] **La rareté ne change pas les stats** : la Légendaire (PV 220, ATK 12) a le profil du Gardien Épique, et une Tireuse Commune a plus d'ATK (20). Seuls comptent le nombre de héros (jusqu'à 4) et leur niveau. Les doublons ne servent à rien. |
| Invocation | Meilleur moment de la session | [observé] Le ×10 est spectaculaire (C01). Mais les tickets arrivent trop vite (100 tickets ≈ 10 combats Élite 1-5 [code]) et le tirage ne change pas la puissance. |
| Niveaux / XP | Trop rapide | [observé] Nv4 → Nv8 en 5 combats Élite. [sim] Nv10 après ~14 combats, Nv20 après ~34. |
| Équipement | Perceptible, voire trop fort | [observé] +29 % PV / +50 % ATK avec 3 objets, et c'est ce qui débloque 1-4E. Comparaison avant/après claire dans la Sacoche. [code] Pas de gants en Normal, armes surreprésentées (51 % des objets de 1-5). |
| Loot | Récompense surtout sur les replays | [observé] Premiers clears 1-2 à 1-5 et Élite vides en monnaies. La fenêtre Expédition Élite affiche les ressources mais **pas la chance d'équipement** (B02). |
| Normal / Élite | Élite = seul vrai défi | [observé] Normal sans aucune défaite à 2 héros. Élite : mur réel à 1-4E/1-5E, franchi en 5 replays + ×10. |
| Ressources, or, gemmes | Sans usage | [code + observé] Aucun puits (#116). Elles s'accumulent sans signification pour le joueur. |
| Tutoriel | Bon pour la 1re minute, puis trop de signaux | [observé] Flèches au sol et légendes claires jusqu'au 1er combat. Après la 1re victoire, **5 appels à l'action simultanés** (A05). Après la Zone 1, plus aucun objectif guidé. |
| Interface | Correcte sur PC, à reprendre sur téléphone | Voir § 4. |

**Mécaniques qui fonctionnent mais n'apportent pas assez au joueur** :

- rareté des héros ;
- doublons de héros et d'équipements ;
- ressources ;
- or et gemmes ;
- premiers clears vides ;
- zones 2 à 6 sans butin ;
- quêtes « Possède N héros » au-delà de 20 (irréalistes en Alpha [sim]).

## 4. Captures et bugs reproductibles

Captures dans [`docs/playtest/alpha-002/`](playtest/alpha-002/) :

| Fichier | Contenu |
|---|---|
| `A01` | arrivée |
| `A02` | héros en main |
| `A03` | combat masqué par l'avatar |
| `A04` | 1re victoire |
| `A05` | surcharge d'appels à l'action |
| `A06` | premier clear 1-2 vide |
| `A07` | drop en 1-4 |
| `A08` | boss |
| `B01` | Zone 2 sans butin |
| `B02` | Expédition Élite |
| `C01` | invocation ×10 |
| `C02` | retour après déconnexion |
| `R01` | téléphone, écran de fin |
| `R02` | téléphone, Sacoche |
| `R03` | tablette, écran de fin |

### Bloquants

Aucun. Aucune perte de données ni duplication, aucun écran bloqué pendant les trois parcours.

### Majeurs (gameplay / produit)

1. **Plus d'objectif après la Zone 1** [observé] : la victoire 1-5 sélectionne 2-1 (Zone 2 : pas de butin,
   portraits d'ennemi et de boss vides), il n'existe aucune quête Élite, et au retour aucun guidage. Lié à
   #115 et **#120**.
2. **Rareté des héros sans effet de combat** (**#121**) [observé + code, `HeroConfig.lua` : profil identique pour
   toutes les raretés].
3. **Économie** [code + observé, #112] :
   - premiers clears vides, et premier clear Élite moins payant que les replays ;
   - inflation de tickets ;
   - aucun puits.
4. **Sauvegarde non forcée après récompense** (**#123**) [code, sub-agent sécurité ; `docs/SECURITY.md` le liste comme
   point ouvert] : un crash serveur dans la fenêtre d'autosave perd le loot et le premier clear.

### Mobile 844 × 390 (zone utile mesurée 750 × 381) [observé, mesures en jeu, à verser dans #119]

| Écran | Défaut mesuré | Capture |
|---|---|---|
| Écran de fin | badge « NIVEAU SUPÉRIEUR ! » à 12,3 px réels | R01 |
| Écran de fin | bouton Continuer haut de 38,6 px | R01 |
| Écran de fin | carte Ticket par-dessus le panneau de quête | R01 |
| Écran de fin | noms de héros tronqués | R01 |
| Sacoche, onglet Héros | noms et niveaux des cartes à 11,6 px | R02 |
| Sacoche, onglet Héros | filtres à 13,4 px | R02 |
| Sacoche, onglet Héros | boutons de filtre 32 px de haut, Fermer 39 px, Loupe 32 px | R02 |
| Sacoche | onglet Héros sous la zone des boutons Roblox (`TopbarInset`) | constat de #118 |

[code] À vérifier en capture : l'Expédition a des badges à 12 px, une bascule de mode haute de 34 px et des
cases d'équipe de 30 px.

La PR #107 corrige les petits textes de l'écran de fin **sur PC**. Elle ne traite ni la Sacoche, ni
l'Expédition, ni `TopbarInset`.

**Tablette 1375 × 1032** [observé] : écran de fin propre, Continuer en 210 × 54. Quatre textes sont à
13,4 px (barres d'XP, badge) : défaut mineur.

### Mineurs (visuels) : **#124**

- Panneau « LIBRE » affiché sur le plot du joueur (A01, C02).
- Titre de bannière « PREMIèRE AUBE » (accent en minuscule dans un titre en capitales).
- Pendant l'animation de fin, deux titres « Victoire ! » / « VICTOIRE ! » se superposent.
- Portraits vides en Zone 2 : « Slime des ronces » et boss 2-5 (B01).
- « ! » allumé en même temps sur Sac, Stats et Quêtes après la première invocation.

## 5. Forces et faiblesses

**Forces**

- Démarrage très rapide [observé] : héros en 1 min, victoire en 2 min, deuxième héros en 3 min 30.
  L'objectif est lisible dès 30 s grâce aux flèches.
- L'invocation ×10 et la révélation des cartes (raretés colorées, « Nouveau ») sont le temps fort émotionnel.
- L'équipement a un impact visible et chiffré (comparaison avant/après) et débloque réellement l'Élite.
- Fondations techniques solides : récompenses entièrement côté serveur, protection contre les doublons de
  complétion, sauvegarde et retour sans perte, 38 tests Node et suites Luau verts.
- Direction artistique cohérente (héros, cartes, écran de fin) sur PC et tablette.

**Faiblesses**

- Boucle courte : tout le contenu est fini en ~17 min [observé], ~3,3 min de combat pur [sim].
- Aucune décision pendant le combat, avec une lisibilité médiocre (avatar devant l'arène).
- La collection n'a pas d'enjeu de puissance (rareté, doublons).
- Économie sans puits, tickets trop abondants, premiers clears vides : la récompense ne suit pas
  l'effort.
- Pas de motif de retour : ni objectif après l'Élite, ni quotidien, ni hors ligne.
- Mobile en dessous du design system (textes, cibles tactiles, `TopbarInset`).

## 6. Comparaison avec les références Roblox

Le sub-agent benchmark le signale lui-même : ses sources sont **pauvres**. Les pages Fandom de PS99 et
d'Anime Fighters ont répondu HTTP 402 ; il a utilisé des guides tiers et les pages officielles Roblox, le
29/10/2026. **Aucune statistique de rétention ni de fréquentation n'est utilisée.** Statut des
informations : déclaré (page officielle ou guide) ou non vérifié.

| Axe | Notre jeu (vérifié) | Anime Vanguards / Last Stand / Defenders (déclaré, guides) | Pet Simulator 99 / Anime Fighters (déclaré, pages Roblox) |
|---|---|---|---|
| Boucle | 5 stages + 5 Élite, zones 2-6 sans butin | Plusieurs modes empilés : Story, Infinite, Raids, Challenges en rotation | Collecter, entraîner, ouvrir de nouveaux mondes |
| 1er gain | Héros à 1 min, ticket à 2 min | Gemmes et or dès le mode Story | Non vérifié |
| Rejouer | Tickets, XP, équipement en Élite | Rotations de défis 30 min / 24 h / 7 j, difficultés supérieures, mode Infinite | Collection de « 3 000+ » pets (page officielle PS99) |
| Idle / auto | Combat auto ×1/×2, pas d'auto-replay | Pas d'auto documenté (Vanguards) ; XP en AFK réduite par patch (Defenders, guides) | Auto Farm vendu en gamepass (PS99) |
| Objectifs | Quêtes 1-5 et « Possède N héros » | Quotidiennes, hebdomadaires, boss hebdo | Non vérifié |
| Puissance | Niveaux et équipement plats, rareté neutre | Évolutions, traits, rerolls (Vanguards) | Non vérifié |

**Ce qu'on retient sans copier.** Notre identité est celle d'un RPG à héros en combat automatique. Les
références tiennent sur trois leviers : **une pile de modes ou d'objectifs** qui se débloquent, **une
rotation** qui redonne une raison de revenir, et **une collection dont la valeur se voit en jeu**.

- L'Élite et les bannières de 15 min sont déjà de bons embryons.
- La rareté neutre et l'absence d'objectif après l'Élite sont nos principaux écarts.
- L'auto-farm en gamepass (PS99) est un levier de monétisation, pas un modèle à reprendre pour l'Alpha
  (#114).

## 7. Recommandations

Aucune n'a été appliquée. Les valeurs proposées par la simulation sont dans #112.

### P0 : avant d'élargir le playtest

1. **Réécrire les récompenses de la Zone 1 (#112)** :
   - premiers clears 1-2 à 1-5 non vides (au moins 1 ticket en 1-3 et 1-4) ;
   - premier clear Élite au moins égal à un replay ;
   - tickets de replay réduits (piste [sim] : Normal `{0,1,1,1,2}`, Élite `{1,1,1,1,3}`).

   Objectif : la première fois paie plus que la répétition, et 100 tickets demandent plus de 10 combats.
2. **Donner un objectif après 1-5** (**#120**) : quête(s) Élite dans `QuestConfig` (contenu, pas de nouvelle
   mécanique), et ne plus sélectionner automatiquement 2-1 tant que la Zone 2 n'a pas de butin (#115).
   Affichage « prochain objectif » au retour.
3. **Afficher la chance d'équipement** (**#120**) dans la fenêtre Expédition (Normal et Élite). C'est la vraie
   motivation du farm.
4. **Mobile minimum (#119 + #107)** : textes ≥ 14 px réels et cibles ≥ 44 px sur l'écran de fin, la Sacoche
   et l'Expédition, et respect de `TopbarInset`.

### P1 : juste après

5. **Donner un sens à la rareté des héros** (**#121**) (arbitrage produit) : écart de stats par rareté, ou ultimes
   différenciés (PR #103 à #106 en cours), et usage des doublons.
6. **Lisibilité du combat** (**#122**) : caméra ou position de l'avatar pendant le combat, numéro de vague, et retour
   visuel des ultimes.
7. **Sauvegarde forcée après récompense importante** (**#123**) (premier clear, objet Rare ou mieux).
8. **Puits d'or et de gemmes** minimal, et usage visible des ressources ou mention « bientôt » (#116).
9. **Hiérarchiser les signaux après une victoire** (**#122**) : une action principale à la fois, au lieu de cinq.
10. **Auto-replay d'un stage validé** à tester (#114), une fois l'économie corrigée.

### P2 : plus tard, après données

11. Loot et premiers clears des zones 2 à 6 (#115), quotidiennes et rotations de défis, mode à difficulté
    croissante.
12. Instrumentation (#113) pour mesurer les jalons de ce rapport sur de vrais joueurs.
13. Poids par emplacement dans le loot (arme 51 % aujourd'hui), gants en Normal, recalibrage des bonus
    plats.
14. Durcissements mineurs (**#124**) [code] : `RequestStartStage` en entrée directe, `MarkTutorialSeen` sans garde
    serveur, `SetCombatSpeed` sans anti-rafale. Plafond de 500 objets sans recours.

## 8. Verdict Alpha 0.0.2 : **FIX**

- **Technique : GO.** La boucle complète tourne sans bloquant, la sauvegarde tient, les récompenses sont
  sûres.
- **Produit : FIX.** Le jeu donne envie pendant ~15 minutes, puis s'arrête faute d'objectif, de puits et
  d'enjeu de collection. Les P0 1 à 4 sont des changements de contenu, de config et d'UI, sans nouvelle
  mécanique. Ils doivent passer avant un playtest élargi.

## Réponses directes

**Le jeu est-il amusant aujourd'hui ?**

Les 15 premières minutes, oui. Je ne peux pas le prouver sans vrais joueurs, mais l'agent a observé des
signaux nets :

- démarrage rapide et guidé ;
- premières victoires immédiates ;
- invocation ×10 gratifiante ;
- mur Élite franchi grâce à l'équipement et aux nouveaux héros.

Ensuite, l'intérêt chute : il n'y a plus d'objectif, la monnaie ne sert à rien, et un héros Légendaire ne
vaut pas mieux qu'un Commun. Le combat se regarde plus qu'il ne se joue.

**La progression est-elle trop rapide, trop lente ou mal récompensée ?**

Les deux à la fois : **trop rapide et mal récompensée**.

- *Trop rapide* : Zone 1 en 6 min sans défaite, Élite en 16 min 30, Nv4 → Nv8 en 5 combats, 10 tickets en
  25 s.
- *Mal récompensée* : premiers clears vides, premier clear Élite moins payant qu'un replay, or, gemmes et
  ressources sans usage.

**Que manque-t-il pour donner envie de rejouer ?**

- Un **prochain objectif visible** après l'Élite.
- Une **collection qui compte** : rareté et doublons utiles.
- Un **puits** pour ce qu'on gagne.
- Plus tard, une **raison de revenir** : rotation, quotidiennes, zone suivante avec butin, auto-replay.

**Les trois améliorations les plus importantes :**

1. Récompenses de la Zone 1 et puits (#112, #116).
2. Objectif après 1-5 et Élite : quêtes Élite, pas de 2-1 vide, « prochain objectif » au retour.
3. Rareté et doublons de héros qui ont un effet en combat.

**Ce qui ne peut pas être établi sans vrais joueurs** : le plaisir réel, le temps de compréhension d'un
humain qui découvre, la rétention. Le protocole ci-dessous permet de le mesurer.

## Protocole de playtest proposé

1. **Profils** : 5 à 8 joueurs qui n'ont jamais vu le jeu (dont 3 sur téléphone), chacun avec un
   `StoreRecette` neuf. Aucune explication préalable.
2. **Session** : 20 min maximum, à voix haute (« je pense que… »). L'observateur ne répond pas aux
   questions.
3. **Mesures** (chronomètre ou #113) : temps jusqu'à 1er objectif compris, 1er combat, 1re victoire, 2e
   héros, 1er équipement porté, fin de la Zone 1, 1re victoire Élite. Nombre de défaites. Moments
   d'hésitation de plus de 10 s.
4. **Questions après la session** (échelle 1-5 et une phrase) :
   - As-tu compris quoi faire ?
   - Quel moment as-tu préféré ?
   - À quoi servent l'or, les gemmes et les ressources ?
   - Ton meilleur héros, et pourquoi ?
   - Rejouerais-tu demain, et pour faire quoi ?
5. **Critères de réussite** : 80 % atteignent la fin de la Zone 1 sans aide, 60 % citent un objectif à
   poursuivre, moins de 30 % jugent l'or ou les ressources « inutiles ». À rejouer après les P0.
