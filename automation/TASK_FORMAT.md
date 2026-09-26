# Format standard d'une tâche

Chaque création possède un identifiant stable, par exemple `monster_001`.

## Champs

`id`
Identifiant technique unique. Ne jamais le réutiliser.

`name`
Nom lisible de la créature.

`type`
Pour le moment : `monster` ou `boss`.

`brief_source`
Chemin vers le brief. Le worker doit lire ce fichier avant toute création.

`target_studio_slot`
Emplacement prévu dans Roblox Studio.

`worker`
`windows` pour le worker Claude Windows. Plus tard : `claude2`.

`status`
Valeurs autorisées :
`todo`
`in_progress`
`awaiting_review`
`fix_required`
`done`
`human_review`
`failed`
`waiting_for_worker` (worker indisponible, voir `SAFETY.md`)

`iteration`
Nombre de passes de correction déjà effectuées.

`max_iterations`
Nombre maximal de passes automatiques avant `human_review`.

`priority`
Plus le nombre est élevé, plus la tâche passe tôt.

`reference_priority`
Références artistiques à privilégier. La direction artistique du repository reste l'autorité.

`screenshots`
Liste des captures produites pour cette tâche.

`latest_review`
Chemin vers le dernier fichier de review.

`notes`
Informations spécifiques ne relevant pas du brief artistique.

## Règle essentielle

Une tâche ne peut passer à `done` que si la dernière review contient `PASS`.

Si `max_iterations` est atteint sans PASS, utiliser `human_review`. Ne jamais boucler indéfiniment.
