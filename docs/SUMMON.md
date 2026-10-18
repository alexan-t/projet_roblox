# Invocation V2 — Alpha 0.0.2 (#80)

## Contrat serveur

`HeroService` décide de la bannière, des coûts, du RNG, de la garantie et des exemplaires. Le client ne simule aucun résultat. Le starter tutoriel reste `RequestStarterSummon()` : Écuyer gratuit, quête vérifiée, aucun ticket ni `Summons.Total` consommé.

`GetSummonState()` publie `Tickets`, `Cost`, `Starter`, `BannerId`, `Slot`, `EndsAt`, `ServerNow`, `ExpectedTotal`, `Guarantee`, `Rates` et `GuaranteeRates`.

`RequestSummon({ BannerId, Slot, Quantity, ExpectedTotal })` accepte uniquement les quantités **1 / 10 / 100** et ces quatre champs. Réponse : `(true, { Results, Quantity, Tickets, Total, Guaranteed, BannerId, Slot })`, sinon `(false, raison)`. Chaque résultat contient `InstanceId`, `HeroId`, `Name`, `Rarity`, `New`, `Guaranteed` et les indicateurs internes de progression.

Le serveur revérifie le profil chargé, le personnage vivant, le portail du joueur et sa distance horizontale (18 studs), le créneau actif, la version attendue et le solde. Une ancienne version, une bannière expirée, une quantité invalide ou un champ de coût/héros/taux ajouté ne consomme rien. `Summons.Total` sert de version persistée : la même requête ne peut pas être appliquée deux fois, y compris après reconnexion.

La transaction pure `SummonRules.batch` prépare tous les tirages et identifiants avant toute mutation. Une erreur au 100e résultat laisse le lot entier intact. Ensuite elle ajoute les exemplaires, débite `Cost × Quantity`, incrémente `Total` et fait évoluer le royaume 1 → 2 si nécessaire. Les doublons gardent leurs identifiants, niveau et XP indépendants ; `New` est vrai seulement pour le premier exemplaire inconnu, y compris au sein du lot. Le royaume et la collection sont publiés **une fois par lot**. Les callbacks serveur reçoivent chaque résultat ; aucun déluge de 100 événements `HeroObtained` n'est envoyé au client.

## Rotation et probabilités

`SummonBannerConfig` centralise les trois bannières et leur ordre : Royaume → Aube → Éclipse. `Featured[1]` est la vedette principale ; les deux suivants sont les secondaires. Aucun tri de rareté ne modifie cet ordre.

Créneau = `floor((UTC Unix - Epoch) / RotationSeconds)`, avec `RotationSeconds = 900` et `Epoch = 0`. La prochaine borne est calculée par le serveur. Tous les serveurs voient donc la même bannière au même instant ; le rejoin ne réinitialise rien. Le client affiche `EndsAt - Workspace:GetServerTimeNow()` et recharge l'état à la borne. L'horloge locale ne décide jamais de la rotation ni de l'acceptation d'un achat.

La rareté est tirée par les poids effectifs de `RarityConfig` (report des paliers vides conservé). Dans une rareté contenant des vedettes, `FeaturedShare = 0,5` choisit le sous-pool vedette ; l'autre moitié choisit le pool complet, qui contient aussi les vedettes. Pour une rareté de probabilité `P`, avec `N` héros et `K` vedettes :

- vedette : `P × (0,5/K + 0,5/N)` ;
- autre héros : `P × 0,5/N` ;
- rareté sans vedette : `P/N`.

`SummonRules.rates` publie les probabilités du même mélange que `roll`. Le panneau Taux affiche les chances spécifiques des vedettes et les dix raretés ; les taux affichés sont arrondis à cinq décimales de pourcentage. La branche normale du prototype design omettait la contribution du pool complet aux vedettes : seule cette donnée mathématique est corrigée, pas la composition visuelle.

## Première invocation payante

`Summons.Total == 0` active une garantie **Épique ou mieux**, conformément au prototype final. Le premier résultat utilise les poids des rangs 4–10 renormalisés ; tous les autres résultats du lot utilisent le pool normal. Aucun HeroId fixe, aucun pity supplémentaire.

Le compteur payant existait déjà : aucun nouveau flag ni changement de DataVersion n'est nécessaire. Un profil existant avec `Total > 0` n'obtient pas de seconde garantie ; un profil qui n'a reçu que le starter gratuit reste éligible. La garantie survit au rejoin via ce même compteur. Le panneau affiche aussi `G` pour les probabilités conditionnelles du premier résultat tant que cette garantie est disponible.

## Interface et reveals

Les sources figées sont conservées dans `docs/references/ui/invocation-v2`. `InvocationVisualConfig` contient les identifiants Roblox des 21 PNG d'origine. Les monnaies réutilisent `CurrencyVisualConfig`. Aucun cadre, ruban, portail, dos de carte ou silhouette livré n'est remplacé par un dessin inventé.

`HeroCard` transpose les dix cadres `RarityConfig`, la zone portrait (x19/y25/w162/h165 sur 200×266), la plaque de nom, les badges et les effets de rareté. Il utilise le modèle via `UIKit.portrait`, ou la silhouette fournie quand le modèle manque. Les rayons et sparkles blancs sont teintés par `UITheme`.

`SummonView` et `SummonLayout` conservent UIKit, Fredoka et UITheme. Desktop : composition 1000×610 avec bannière de 960×430, vedette centrale 196 px, secondaires 140 px et trois boutons en bas. Mobile paysage : 820×354, bannière à gauche et commandes de 250 px à droite, cartes 138/96 px. La fenêtre se met à l'échelle de l'espace disponible et change de composition lorsque nécessaire.

- **x1** : portail 0,9 s → flash 0,25 s → silhouette 0,75 s → rareté 0,6 s → carte. Toucher passe immédiatement à la carte ; Continuer termine, Encore refait une demande serveur après relecture de l'état.
- **x10** : portail court et flash, puis grille 5×2 avec les dos fournis et flips échelonnés ; Légendaire+ arrivent plus tard. Toucher révèle tout immédiatement. Aucune répétition de dix cinématiques complètes.
- **x100** : compteur court, barre par rareté, meilleurs résultats, puis résumé regroupé ou onglet Tous (100) compact et défilant. Le regroupement ne fusionne aucun exemplaire sauvegardé.

La réponse de l'invocation est l'unique déclencheur du reveal ; le starter ne s'affiche donc pas deux fois à cause de `HeroObtained`. `ArenaStore.holdHeroes/releaseHeroes` retarde l'affichage de la collection. `ScreenState` réserve le modal pendant toute la séquence. Respawn, fermeture ou erreur libèrent cet état ; les timers et connexions visuels sont détruits avec l'écran. L'ancien `SummonEffectController` 3D et `SummonLanding` restent disponibles pour les outils de scène, mais ne pilotent plus la séquence V2.

## Tickets — ALPHA 0.0.2 PROVISOIRE

Les nombres de replay sont centralisés dans `RewardConfig.TicketEconomy`. Le contrat du starter et le ticket du premier clear 1-1 restent inchangés. Les quêtes gardent leurs récompenses de progression.

| Replay | 1-1 | 1-2 | 1-3 | 1-4 | Boss 1-5 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Normal | 0 | 1 | 1 | 2 | 5 |
| Élite | 2 | 2 | 2 | 2 | 10 |

Ainsi un x10 correspond par exemple à deux boss normaux rejoués, un boss Élite ou dix replays 1-2. Un x100 correspond à vingt boss normaux ou dix boss Élite, hors quêtes. Le First Clear ouvre la progression ; les gains réguliers arrivent sur les replays suivants. Ces valeurs servent la validation Alpha et doivent être réévaluées avec les durées réelles des combats. Aucune monétisation n'est ajoutée.

## Validation

`tools/test-heroes.ps1` couvre le starter, la rotation UTC et ses bornes, les probabilités exactes, les trois volumes, les coûts, l'atomicité, les identifiants distincts, les doublons, la garantie et le rejoin, les requêtes forgées/dupliquées et les profils existants. `tools/test-rewards.ps1` couvre les gains réguliers et l'absence de double attribution. Les suites sécurité, quêtes, progression et tutoriel doivent rester vertes.

La fiche `docs/INVOCATION_V2_QA.md` consigne les contrôles Studio réellement effectués et leurs limites. Aucune commande de QA ne doit donner silencieusement des tickets à un profil réel : utiliser des copies de données pour les tests serveur et des aperçus sans attribution pour le rendu.
