# Zones 2 à 6 — contrôle du 19 octobre 2026

**Verdict global : FIX.** Les cinq zones fonctionnent en test solo, mais des images de
l'interface restent absentes dans le sandbox connecté. Aucun PASS global n'est revendiqué.
La mission reste à finaliser après correction des accès aux assets et contrôle multijoueur.

## Environnement et portée

- Place Studio connectée : **test 3**, placeId `120616399792561` ; aucune publication.
- Code synchronisé avec le plugin **Rojo 7.7.0**, depuis ce worktree, avant les tests.
- Les cinq décors et huit nouveaux modèles de combat sont dans Studio, les pancartes dans
  les huit arènes ; trois modèles de base absents ont été copiés des références validées.
- ProfileStore a signalé **API services unavailable — data will not be saved** : les profils
  de test étaient en mémoire. Les clears simulés et héros de test disparaissent à Stop.
- Les contrôles de combat ont utilisé Chevalier du Lierre, Brise-Pierre, Apprenti Pyromancien
  et Guetteuse des Pins, niveau 20, posés sur les cases 1 à 4, vitesse x2.
- Les victoires de combat sont distinctes des clears préparatoires simulés via DebugData.
  Aucun nouvel ennemi ni nouvelle rareté de monstre n'a été créé.

## Contrôles fonctionnels

| Contrôle | Résultat | Preuve / portée |
| --- | --- | --- |
| Six zones, trente stages exposés par le serveur | PASS | GetArenaState en Client : 30 entrées, compositions, XP et récompenses |
| Accès initial aux boss refusé, déblocage successif | PASS | DebugData StartStage/CompleteStage, 1-1 à 6-5 ; fins simulées, pas des combats |
| Choix des zones 2 à 6 | PASS | ArenaAction SelectStage ; exactement un décor actif avec le bon ZoneId |
| Boss 2-5, 3-5, 4-5, 5-5, 6-5 | PASS | Combats réels de CombatService, fin Victory ; retours en Placement |
| Boss de zone et héros visibles | PASS | Captures de Slime King et King Tréant en combat ; modèles texturés existants |
| Relance pendant l'outro | PASS | Après Victory de 3-5, SelectStage 5-5 puis Ready en moins d'une seconde : décor Zone 5 confirmé |
| Pancarte : E ouvre Expédition | PASS | Nouveau Play après correction ; ScreenGui Expedition présent |
| Flèches du menu jusqu'à la Zone 6 verrouillée | PASS | Cinq clics réels, cinq cartes 6-1..6-5, pas d'onglet Élite en Zone 6 |
| Indication de déblocage d'une première étape | PASS | « Termine la zone 5 » vérifié dans le GUI ; test pur pour les zones 2 à 6 |
| Deux décors sur deux plots tournés différents | PASS | ZoneDecor appliqué sur Plot_2 et Plot_3, Zone 1 inchangée sur Plot_1, pivots relatifs vérifiés puis restaurés |
| Deux joueurs et deux combats simultanés | FIX | Non exécuté dans cette session mono-client ; les tests purs d'isolation ne le remplacent pas |

Le test au niveau 20 vérifie le fonctionnement. L'équilibrage aux niveaux cibles 4/8/12/16/20
est couvert séparément par les simulations CombatEngine (trois équipes, cinq graines).

## Captures réelles et grille visuelle

Les originaux sont dans `automation/screenshots/zones/` :

| Capture | Contenu |
| --- | --- |
| [zone2-combat.jpg](../automation/screenshots/zones/zone2-combat.jpg) | Slime King contre l'équipe dans la Mare aux Slimes |
| [zone2-overview.jpg](../automation/screenshots/zones/zone2-overview.jpg) | Première vue isolée du gabarit, sans sol du plot ; contrôle de construction seulement |
| [zone3-final.jpg](../automation/screenshots/zones/zone3-final.jpg) | Décor de la Forêt des Tréants posé sur Plot_1, Edit |
| [zone4-final.jpg](../automation/screenshots/zones/zone4-final.jpg) | Décor du Camp de la Horde posé sur Plot_1, Edit |
| [zone5-before-fix.jpg](../automation/screenshots/zones/zone5-before-fix.jpg) | Lave trop lumineuse et anciennes pointes anguleuses, avant correction |
| [zone5-final.jpg](../automation/screenshots/zones/zone5-final.jpg) | Lave sans surexposition, stalagmites arrondies, après correction, Edit |
| [zone6-combat.jpg](../automation/screenshots/zones/zone6-combat.jpg) | King Tréant, équipe et grands arbres du Bois Ancien |
| [expedition-zone6-final.jpg](../automation/screenshots/zones/expedition-zone6-final.jpg) | Consultation réelle de la Zone 6 verrouillée depuis la pancarte ; images de récompenses absentes |

Application de VISUAL_QA aux **décors et à leur intégration**, avec les monstres validés
réutilisés sans remodelage. Ces captures ne constituent pas une nouvelle validation de
créature à six angles ; aucune nouvelle créature n'est livrée.

| Critère | Grille | Observation |
| --- | --- | --- |
| Brief / progression | OK | Cinq décors distincts, cinq stages chacun, boss sur X-5 |
| Zone / palette | OK | Mares vertes, forêt dense, camp ocre, roche/lave orange, vieux bois sombre/cyan |
| Lisibilité de l'arène | OK | Clairière, neuf cases et passage d'entrée dégagés dans les vues finales |
| Géométrie / clipping visible | OK | Réutilisation des repères de Zone 1 ; accessoires hors cases, stalagmites pleines après correction |
| Cohérence des monstres | OK | Copies des références validées ; Slime King et King Tréant restent dominants face aux héros |
| Couleurs / lumière du décor | OK | Lave corrigée, points lumineux limités ; formes arrondies remplaçant les blocs de basalte |
| Interface / matériaux des images | KO | Cases de menu et récompenses vides dans les captures Play, malgré les textes présents |

**Défaut bloquant réellement visible :** [Interface] les icônes du menu et des récompenses
ne se chargent pas (`zone2-combat`, `zone6-combat`, `expedition-zone6-final`). La console
signale notamment `User is not authorized to access Asset` pour des images existantes,
dont `74149875739571`, `99196320622532` et `136778535271316`. Le propriétaire doit rétablir
l'accès de cette expérience aux images concernées (ou effectuer la validation dans la place
DEV autorisée), puis recapturer. Aucun AssetId de remplacement n'a été inventé ou publié.

Les annonces « Rare ! » visibles dans certaines captures proviennent de l'aperçu d'invocation
du sandbox, pas d'une rareté attribuée aux monstres. La capture finale du menu est sans annonce.

## Corrections issues du test Studio

- `ProximityPrompt.Triggered` transmettait le Player au paramètre optionnel de numéro de zone :
  E affichait « Aucun stage disponible ». Le callback ignore maintenant cet argument.
- Un lancement avant la fin de l'outro pouvait garder le décor précédent. Le décor et le
  FrontEnnemi sont maintenant résolus avant la création du nouveau combat.
- L'aperçu UI utilisait encore `Waves = 1/2`, incompatible avec les vraies listes de vagues :
  son fixture utilise désormais le contrat courant et les statuts Unlocked/Locked.
- L'étape 6-1 verrouillée demandait « Termine 6-0 » ; elle demande désormais de finir la zone 5.
- La lave saturait l'image et les pointes étaient anguleuses : matière et géométrie corrigées,
  puis recapturées. Les images avant correction restent identifiées comme telles.

## Tests automatisés et état de sortie

Neuf lanceurs exécutés avec Luau CLI : `test-zones`, `test-combat`, `test-arena`,
`test-rewards`, `test-expedition`, `test-presentation`, `test-heroes`, `test-ui`, `test-security`.
Tous les cas signalés passent, aucun échec final. Le test Expédition a été rejoué après
l'ajout de la vérification du message inter-zone. `rojo build` et `git diff --check` passent.

Studio est revenu en Edit. Les huit plots ont retrouvé leur Zone 1, les objets d'aperçu
temporaires sont retirés, les caméras ont été recréées suivant MONSTER_PRODUCTION § Outils A.
L'attribut de démonstration initial `ApercuUI = Expedition` est restauré.
Les gabarits et les pancartes restent disponibles pour le prochain Play.
Branche `acc/mission-f9c766ee` conservée conformément à la consigne de mission, qui interdit
le changement de branche ; aucun push, aucune fusion, aucune publication.
