# Roblox Agent Pipeline V1

Cette V1 prépare un pipeline avec :

Claude Windows comme worker artistique principal.

Claude Cloud comme manager QA.

Claude 2 pourra être ajouté plus tard sans changer le format des tâches.

## Installation

Copier le dossier `automation` à la racine du repository qui contient déjà `CLAUDE.md` et `docs/`.

Arborescence attendue :

repository/
    CLAUDE.md
    docs/
    .claude/
    automation/
        tasks.json
        TASK_FORMAT.md
        review.schema.json
        prompts/
        screenshots/
        reviews/
        completed/

## Premier test

Utiliser `monster_001`, « Le Pilleur de la rivière ».

Le worker Windows lit `automation/prompts/worker_windows.md` et exécute la tâche jusqu'à `awaiting_review`.

Ensuite la capture doit être contrôlée par le manager QA avec `automation/prompts/manager_cloud.md`.

Le manager écrit un fichier :

`automation/reviews/monster_001_iteration_00.json`

Si le verdict est `FIX`, le worker applique uniquement les corrections demandées et génère une nouvelle capture.

Si le verdict est `PASS`, la tâche passe à `done`.

## Important

Cette V1 pose le contrat de données avant d'automatiser les appels.

Ne pas faire de boucle infinie.

Ne pas dépasser `max_iterations`.

Ne pas remplacer les règles de DA du repository par des règles inscrites dans les tâches.

La future V2 automatisera l'attribution, l'envoi au manager cloud et le retour des reviews.

## V1.2 — liaison Cloud disponible

La liaison est maintenant fournie par `cloud_review_bridge.py`. Suivre
`CLOUD_REVIEW_README.md` pour configurer une session réelle et sa branche de sortie.
Les paragraphes ci-dessus décrivent la V1 initiale ; l'envoi/récupération Git est
implémenté en V1.2. Le réveil automatique de Claude Windows après quota reste manuel.
Le Pilleur de la rivière est déjà en `awaiting_review` : ne pas le recréer.
