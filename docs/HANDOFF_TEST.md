# Test de passation — nouvel agent

**But :** vérifier qu'un Claude qui n'a jamais travaillé avec nous produit, **avec ces seuls documents**, une créature de qualité proche des créatures validées.

## Règles du test

- L'agent démarre sans historique de conversation. Il n'a accès qu'au repository et au MCP Roblox Studio (place `test`).
- Il ne reçoit **aucune aide artistique** en dehors du brief ci-dessous. Les questions sont autorisées uniquement sur des points bloquants (Studio en mode Play, accès refusé).
- Il doit utiliser la skill `.claude/skills/roblox-creature-artist/SKILL.md`.
- Le résultat va sur le socle **Monstres #16** (`Workspace.Bestiaire.Monstres.Socle_16`), sous le nom `HandoffTest_<Nom>`. Les variantes non retenues vont dans `ServerStorage.Archive_HandoffTest`.

## Message à donner à l'agent

> Lis `CLAUDE.md`, puis utilise la skill `roblox-creature-artist` pour créer le monstre du brief ci-dessous dans la place Roblox Studio « test ». Pose-le sur le socle Monstres #16, nommé `HandoffTest_<Nom>`. Ne déclare terminé qu'après un PASS de `docs/VISUAL_QA.md`, et donne ton rapport QA.
>
> **Brief — « Le Pilleur de la rivière »**
> - Type : monstre (pas un boss), zone 1 « Plaine du Royaume ».
> - Il surgit de la **rivière** de la zone (`Zone1_PlaineDuRoyaume.Riviere`) pour attaquer les héros.
> - Rôle : corps à corps rapide, qui harcèle et se replie.
> - Taille : entre un gobelin et un tréant (5 à 7 studs).
> - Contraintes : **ce n'est ni un poisson, ni un homme-poisson, ni un crabe générique**. Il doit avoir une idée visuelle principale que l'on reconnaît en un coup d'œil.
> - Il doit sembler appartenir à la même faune que les slimes, les tréants et les gobelins déjà présents dans le Bestiaire.

## Ce qu'on attend (sans le dire à l'agent)

- Une **deuxième association** de la rivière : galets polis, roseaux, vase, filet ou nasse de pêcheur volés au camp gobelin… plutôt qu'une créature aquatique évidente.
- Une silhouette massive en haut du corps, des matériaux peints superposés, un point lumineux, une expression hostile.
- Des prises en main et des accroches mesurées, sans clipping ni accessoire flottant.
- Un rapport QA honnête : défauts vus et corrigés, captures réellement faites, caméra réinitialisée.

## Évaluation (par l'équipe)

Placer `HandoffTest_<Nom>` à côté de `GobLanceT_A`, `Treant_Masque` et `Slime_Eau`, puis noter chaque critère de 0 à 2 :

| Critère | 0 | 1 | 2 |
|---|---|---|---|
| Appartient visiblement au même jeu | non | partiellement | évident |
| Idée visuelle principale | générique | présente mais faible | forte, mémorable |
| Silhouette et proportions (ART_DIRECTION § 3, § 5) | hors DA | approchant | conforme |
| Matériaux, couleurs, point lumineux | hors DA | approchant | conforme |
| Visage et expression | enfantin ou raté | correct | conforme |
| Finition (clipping, flottants, textures) | défauts visibles | mineurs | propre |
| Lien avec la zone, sans cliché | cliché ou absent | évident | subtil et pertinent |
| Respect du process (captures, QA, archive, caméra) | non | partiel | complet |

**Lecture du score (sur 16) :**
- **13 à 16** : passation réussie. Les documents suffisent.
- **9 à 12** : passation partielle. Relever les écarts et compléter la section concernée des documents (ART_DIRECTION, MONSTER_PRODUCTION ou VISUAL_QA).
- **8 ou moins** : les documents ne transmettent pas la DA. Refaire le test après correction.

Après chaque test, noter les écarts constatés ci-dessous, pour améliorer les documents.

## Journal des tests

| Date | Agent / modèle | Score | Écarts principaux | Documents corrigés |
|---|---|---|---|---|
| | | | | |
