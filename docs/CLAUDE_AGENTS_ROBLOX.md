# Organisation des sub-agents Claude Code — projet Roblox

> Spécification opérationnelle à intégrer dans le dépôt `alexan-t/projet_roblox`.
> Version de cadrage : 2026-10-19. Le code et les issues/PR en cours doivent toujours être re-vérifiés au moment de l'installation.

## 1. Objectif

Mettre en place une équipe de **sub-agents Claude Code natifs**, spécialisés par domaine, pour améliorer la cohérence du jeu, réduire les régressions, mettre en évidence les risques de produit et permettre au Claude principal de rester **coordinateur et responsable de l'intégration**.

**IMPORTANT :** ce fichier est la spécification. Pour réellement activer les agents, les fichiers `.claude/agents/*.md` doivent être présents dans le dépôt ; le ZIP livré avec cette spécification en contient dix. Le Claude principal doit ajouter un court renvoi dans `CLAUDE.md` existant (sans le remplacer), vérifier la configuration puis exploiter les agents de façon ciblée.

## 2. Sources de vérité et règles communes

- Examiner le code réellement présent sur la branche de travail avant toute modification.
- `develop` est la branche d'intégration du projet ; ne jamais supposer que `main` est alignée, ni pousser vers `main` ou publier sur Roblox sans demande explicite.
- Une PR, un ticket, un commentaire ou une ancienne branche n'est **pas** une vérité supérieure au code actuel et aux documents explicitement considérés comme faisant foi.
- Sources fonctionnelles utiles, à consulter selon le sujet : `docs/UI_DESIGN_SYSTEM.md`, `docs/ITEMS.md`, `docs/SUMMON.md`, `docs/ZONES.md`, `docs/VISUAL_QA.md`, `docs/RESOURCE_ICONS_QA.md`, `src/shared/Config/*`, `src/server/Services/*`, `src/client/*`, et tests existants. Vérifier leur présence et leur version.
- Respecter les maquettes déjà figées (notamment Invocation V2, Expédition et Sacoche) : aucune refonte implicite.
- Les récompenses, le loot, les probabilités, les états joueur, les achats et les validations de combat sont **autoritaires côté serveur**. Le client demande/affiche, il n'attribue pas de biens ni de résultat.
- Ne jamais inventer une réussite de test, un résultat Studio, des données Roblox Analytics, un concurrent “qui marche” ni des chiffres de rétention.
- Pas de dépendance externe, de publication d'assets, de changement de permissions Roblox, de dépense de Robux ou d'action destructrice sans autorisation.
- Pas de `git push --force`, réécriture de l'historique partagé, merge automatique de PR conflictuelles, fermeture arbitraire d'issues/PR, ni manipulation de `main` sans demande explicite.
- Un agent ne doit pas modifier des fichiers d'un autre domaine sans l'annoncer au coordinateur ; en cas de contrat partagé, demander une revue croisée.
- Éviter les caractères invisibles parasites (zero-width, BOM inutile, marqueurs IA) dans les fichiers créés.

## 3. Les dix sub-agents

| Fichier `.claude/agents/` | Responsabilité principale | Éviter de lui déléguer |
| --- | --- | --- |
| `roblox-product-benchmark.md` | Études de jeux comparables, alertes sur pertinence/rétention/UX, recommandations produit **sourcées** | Coder, modifier le dépôt, imposer un mimétisme concurrentiel |
| `roblox-gameplay-combat.md` | Combat, arènes, zones, difficulté, progression et règles de victoire | Modifier les maquettes, inventer des récompenses côté client |
| `roblox-loot-inventory.md` | Loot, inventaire, ressources, items instanciés, équipement et équilibrage | Décider seul des prix/monétisation, refondre Invocation |
| `roblox-heroes-summon.md` | Collection de héros, summon, taux, bannières, tickets, XP des héros | Modifier les probabilités sans décision explicite |
| `roblox-ui-ux.md` | UITheme, UIKit, Sacoche, HUD, vues, responsive, accessibilité | Toucher à la logique de gain ou aux droits serveur |
| `roblox-assets-studio.md` | Assets, AssetIds, monde Studio, importation, VFX et recette visuelle | Affirmer avoir testé dans Studio sans exécution réelle |
| `roblox-data-security.md` | Données joueur, persistance, remotes, anti-exploit, validations, idempotence | Ajouter des blocages arbitraires au gameplay |
| `roblox-qa-regression.md` | Tests ciblés Node/Luau/PowerShell, intégration et contrôles de régression | Certifier un rendu Studio sur tests statiques seuls |
| `roblox-git-release.md` | État Git, analyse de PR, dépendances de merges, risque de branche obsolète | Forcer une fusion, pousser en production, contourner les checks |
| `roblox-docs-guardian.md` | Cohérence docs, décisions d'architecture, contrats entre domaines | Remplacer la doc validée par une hypothèse |

**Le Claude principal orchestre** ; inutile d'ajouter un onzième agent « manager » qui ferait doublon. Les sub-agents ont des prompts indépendants : ils reçoivent explicitement la tâche, sa branche, ses contraintes et les fichiers nécessaires.

## 4. Quand déléguer — sans gaspiller les quotas

- **Question simple, correction localisée, changement de moins de quelques fichiers :** Claude principal directement ; pas de “réunion d'agents” pour chaque tâche.
- **Grosse fonctionnalité joueur, économie, progression, UI structurante :** appeler `roblox-product-benchmark` d'abord (ou en parallèle d'une exploration technique), puis le spécialiste du domaine.
- **Feature serveur ayant un impact sur les sauvegardes ou les remotes :** spécialiste + `roblox-data-security` ; `roblox-qa-regression` en fin de lot.
- **Grosse refonte UI/visuelle :** `roblox-ui-ux` + éventuellement `roblox-assets-studio`, puis recette visuelle réelle.
- **PR à fusionner :** `roblox-git-release` évalue la PR, puis QA si la portée le justifie ; le **Claude principal** prend et exécute la décision de merge si les conditions sont remplies.
- **Documentation importante :** `roblox-docs-guardian` seulement si une décision ou un contrat doit être synchronisé.
- **Budget :** par défaut un seul agent spécialiste ; au plus deux agents en parallèle pour des tâches indépendantes. Pas d'appel redondant, pas de scans répétés de tout le dépôt ; une synthèse structurée, concise, est retournée au principal. Laisser les agents légers sur `haiku`, les travaux d'analyse/implémentation sur `sonnet` (ou modèle disponible).

## 5. Agent prioritaire : Roblox Product Benchmark

### Pourquoi

Avant de développer une fonctionnalité coûteuse, examiner si elle a des chances d'améliorer **l'expérience réelle des joueurs** : compréhension immédiate, temps jusqu'au premier plaisir, rythme des gains, boucle répétable, frustration, motivation de retour, compatibilité mobile, économie honnête.

### Déclencheurs

- Nouvelle feature susceptible de changer le parcours joueur ; proposition d'inventaire, forge, progression, boss, summon, monétisation, récompense ou système social.
- Refondre onboarding, navigation, écran principal ou boucle de session.
- Désaccord entre agents sur l'intérêt d'un mécanisme.
- Avant une décision produit difficile à inverser ou une fonctionnalité à coût de développement élevé.

### Méthode impérative

1. Décrire notre fonctionnalité et le stade actuel de notre jeu : **alpha**, sans supposer disposer de statistiques de rétention.
2. Chercher, **si accès web réel**, 3 à 5 expériences Roblox comparables. Choisir des comparables **sur leur boucle de jeu, leur audience et leur plateforme**, pas simplement leur popularité. Mentionner les limites (taille d'équipe, budget, ancienneté, style, marché).
3. Vérifier les informations sur des sources actuelles et datées (pages d'expériences, Creator Hub, gameplay observé, notes de mise à jour, analyses crédibles). Différencier explicitement **observé**, **déclaré**, **inféré** et **non vérifié** ; pas de chiffres CCU, visites ou rétention inventés.
4. Si Internet est inaccessible : le dire immédiatement ; proposer une **revue heuristique non sourcée**, et NE PAS prétendre à une comparaison actuelle.
5. Comparer au moins : premières 1/3/5 minutes, premier combat, premier gain tangible, lisibilité mobile, profondeur vs friction, fréquence des récompenses, progression, motivation de rejouer, honnêteté de la monétisation, accessibilité.
6. Estimer le risque et l'impact par rapport à **notre Alpha**, en distinguant une intuition produit d'une preuve mesurée.
7. Formuler une recommandation proportionnée : **garder / simplifier / tester / différer / revoir**, plus un test joueur mesurable.

### Échelle d'alerte

- **VERT — Cohérent** : bon alignement avec la boucle de jeu et les contraintes actuelles.
- **JAUNE — À surveiller** : choix plausible avec incertitude ou petit coût de friction.
- **ORANGE — Risqué** : difficulté importante d'usage ou coût trop élevé pour le bénéfice plausible.
- **ROUGE — À reconsidérer** : menace sérieuse pour la jouabilité, lisibilité, confiance ou utilité en alpha ; demander une décision avant une implémentation coûteuse.

Un niveau **rouge** déclenche un arbitrage du Claude principal à présenter à l'utilisateur si nécessaire, **pas un veto automatique** de l'agent. La comparaison n'est pas une preuve de causalité. Ne pas copier les assets, UI, textes ou mécanique originale d'un concurrent ; s'en inspirer de façon critique.

### Format obligatoire du rapport Benchmark

```markdown
# Revue produit — [feature/issue]
- Décision proposée : GARDER / SIMPLIFIER / TESTER / DIFFÉRER / REVOIR
- Alerte : VERT / JAUNE / ORANGE / ROUGE
- Confiance : élevée / moyenne / faible
- Question produit : ...
- Notre situation : ... (faits du dépôt vs hypothèses)

## Comparables
| Expérience | Mécanisme observé | Source + date | Degré de comparabilité |
| ... | ... | ... | ... |

## Risques spécifiques à notre jeu
- ... (constat / hypothèse / impact / probabilité)

## Recommandation concrète pour l'Alpha
- Version minimale jouable : ...
- À reporter : ...
- Test joueur / mesure à instrumenter : ...
- Ce qu'on ne peut pas conclure : ...
```

## 6. Pipeline de travail

```text
Demande / issue
    |
Claude principal : lire état du dépôt, issue et dépendances
    |
[Benchmark produit ? si changement significatif de l'expérience joueur]
    |
Décision de portée : MVP Alpha, critères d'acceptation, fichiers/contrats
    |
Agent spécialiste (implémentation ciblée)
    |
QA régressions + Data Security si serveur/persistance + Assets/Studio si rendu
    |
Docs Guardian si contrat/documentation à synchroniser
    |
Git Release : diff / retards / checks / dépendances / risque
    |
Claude principal : annonce résultat, crée PR/merge seulement si approprié
```

**Handoff minimum demandé à l'agent appelé :** objectif, faits vérifiés, fichiers touchés, contrats modifiés, tests réellement exécutés/résultats, cas non testés, risque, proposition d'étape suivante. Toute conclusion doit être traçable à une source ou à un fichier identifié.

## 7. Politique de collaboration et de merges

- Une tâche → une branche de travail à jour, créée depuis le HEAD voulu ; pour intégrer vers `develop`, partir du `develop` actuel.
- Éviter que des agents modifient simultanément les mêmes fichiers ; organiser séquentiellement les tâches dépendantes.
- Si des modifications doivent être isolées en parallèle, utiliser des worktrees contrôlés plutôt qu'un working tree partagé. Ne pas perdre les changements non commités.
- Ne jamais qualifier `mergeable=true` comme test de qualité suffisant.
- Vérifier base/head, commits ahead/behind, diff réel, conflits, dépendances, statuts CI, tests déclarés vs exécutés, couverture et impact produit.
- Les anciennes PR portant sur la rareté ont eu des conflits ; vérifier au moment de l'action les règles actives et les PR remplacées. Ne pas réintégrer les anciens écrans Invocation/Sacoche/Expédition.
- En l'absence de CI/Studio, signaler explicitement **non testé**. Ne pas inventer de validation.
- Les actions externes, merges irréversibles, suppression de branche et release demandent un périmètre explicite de la requête utilisateur. Une demande « merge le nécessaire » autorise des merges **sûrs et justifiés**, pas la fermeture automatique de toutes les PR.

## 8. Exemple concret : Alpha 0.0.2

- Réexaminer la définition actuelle de l'issue **#72 Loot & Inventaire V1** et de l'issue **#73 Equipment V1** ; dans les échanges antérieurs, #73 dépend de #72 (état à revalider).
- Avant de créer le système de loot : l'agent Benchmark signale si la quantité de ressources/équipements et le nombre d'onglets risquent de complexifier les premiers instants. Il propose un test de temps jusqu'au premier équipement gagné.
- `roblox-loot-inventory` réalise ensuite les fonctions prévues par l'issue en réutilisant les catalogues, sans intégrer prématurément la forge ou le bouton Équiper de #73.
- `roblox-data-security` vérifie récompense server-side, anti-double attribution, persistance et rejoin ; `roblox-qa-regression` vérifie les suites touchées ; `roblox-ui-ux` vérifie l'affichage de la Sacoche et de l'écran des récompenses.
- La recommandation Benchmark **n'autorise jamais** à s'écarter silencieusement d'une issue validée : proposer le changement au principal d'abord.

## 9. Installation attendue par Claude

1. Inspecter le dépôt et le `CLAUDE.md` existant ; ne supprimer aucune instruction établie.
2. Installer/adapter les dix fichiers `.claude/agents/*.md` du pack dans le dépôt, en conservant les définitions existantes si elles ne sont pas en conflit.
3. Ajouter dans `CLAUDE.md` un court chapitre « Orchestration des sub-agents Roblox » renvoyant à ce fichier et expliquant la délégation ciblée ; ne pas recopier 10 prompts complets dans `CLAUDE.md`.
4. Laisser cette spécification à la racine (ou déplacer sous `docs/` avec référence ajustée) pour garder une source de vérité stable.
5. Vérifier le frontmatter de chaque agent (`name`, `description`, `tools`, `model`) et les noms uniques ; vérifier les outils réellement disponibles dans la version de Claude Code installée. Adapter les noms d'outils si nécessaire, sans accorder plus de permissions.
6. Si disponible, exécuter `claude plugin validate .claude/agents` puis tester une invocation `roblox-product-benchmark` sur une feature réelle, **sans rien modifier**.
7. Ne toucher à aucune fonctionnalité gameplay pendant ce lot d'installation ; ne créer ni issue ni PR externe sans demande.
8. Livrer les fichiers modifiés et un rapport concis : agents activables, tests de chargement réellement effectués, limites, et exemples de commandes/prompts.

## 10. Références

- Claude Code (sub-agents) : https://code.claude.com/docs/en/sub-agents
- Roblox Creator Hub — Analytics : https://create.roblox.com/docs/production/analytics
- Roblox Creator Hub — Discovery : https://create.roblox.com/docs/discovery
- Roblox Creator Hub — Onboarding : https://create.roblox.com/docs/production/game-design/onboarding

> À retenir : le Benchmark sert à **alerter et éclairer les décisions**, pas à prétendre qu'une mécanique va forcément augmenter la rétention. Les agents techniques servent à exécuter un périmètre validé, pas à gouverner le jeu indépendamment.

## 11. Adaptations au dépôt (installation du 2026-10-19)

Les dix agents du pack sont installés dans `.claude/agents/`, réécrits sur les fichiers réels :

- **Noms et chemins vérifiés** : services (`ArenaService`, `CombatService`, `ZoneService`, `RewardService`, `HeroService`, `DataService`…), configs serveur et partagées, docs existantes, runners `tools/test-*.ps1 -LuauPath build/tools/luau-0.740/luau.exe`, `node --test tests/`, `rojo build`.
- **Studio (MCP)** : `roblox-ui-ux` et `roblox-assets-studio` reçoivent un jeu restreint d'outils Studio (état, Luau, capture, console, Play, inspection). Aucun outil de publication ou de génération d'assets ne leur est donné.
- **Skills existants conservés** : la création de monstres et de héros reste dans `.claude/skills/roblox-creature-artist` et `roblox-character-artist` ; les agents y renvoient.
- **Lecture seule par outils** : `roblox-product-benchmark` (aucun Edit/Write/Bash), `roblox-data-security` et `roblox-git-release` (aucun Edit/Write ; Bash limité par consigne à la lecture et aux tests).
- **Règles du projet intégrées** : maquettes figées (Expédition, Sacoche centrée, Invocation V2), tokens UITheme, captures réelles + réinitialisation de la caméra, modifications Studio signalées non sauvegardées, propriété des AssetIds (expérience `nxtoma`, universe 10767916745), comparaison à `origin/develop`.
- **Modèles** : `sonnet` pour les spécialistes et la QA, `haiku` pour `roblox-docs-guardian`.
- **Validation** : la CLI `claude` n'est pas dans le PATH de l'application de bureau (`claude plugin validate` indisponible) ; frontmatter, noms uniques, outils et chemins cités sont vérifiés par un script local.
- **Benchmark renforcé (validé par l'utilisateur)** : lectures obligatoires avant verdict (issue GitHub fournie par le principal, configs et contrats, docs de design system et de gameplay, dépendances) ; rapport séparé en constats vérifiés du projet, observations vérifiées de jeux comparables, hypothèses et recommandations ; aucune simplification touchant un contrat existant sans conséquences listées et arbitrage. #72 / #73 : 7 emplacements et catalogues complets conservés ; le périmètre visible par les joueurs sera décidé après analyse complète.
