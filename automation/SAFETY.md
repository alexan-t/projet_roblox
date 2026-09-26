# Sécurité et reprise du pipeline

## Règle principale

Avant chaque nouvelle action importante, le worker doit vérifier :

1. `automation/STOP`
2. `automation/control.json`

## STOP immédiat

Si le fichier `automation/STOP` existe :

- ne commencer aucune nouvelle action ;
- ne modifier aucun nouvel asset ;
- sauvegarder l'état courant dans `automation/state/<task_id>.json` ;
- arrêter le travail sur la tâche.

Pour reprendre, supprimer simplement `automation/STOP`.

## Pause propre

Si `control.json` contient `"paused": true` :

- terminer uniquement l'étape atomique en cours ;
- sauvegarder l'état ;
- ne pas commencer l'étape suivante ;
- ne pas prendre une nouvelle tâche.

## Emergency stop

Si `control.json` contient `"emergency_stop": true` :

- sauvegarder immédiatement l'état courant si possible ;
- ne lancer aucune nouvelle commande Studio/MCP ;
- arrêter la tâche.

## Quota Claude / indisponibilité

Si le worker ne peut plus continuer à cause d'une limite d'utilisation :

- ne pas marquer la tâche comme `failed` ;
- mettre la tâche en `waiting_for_worker` ;
- sauvegarder l'état courant ;
- conserver le même `task_id`, le même `iteration` et le même emplacement Studio ;
- à la reprise, relire le fichier d'état et continuer la même tâche.

## État de tâche

Chaque tâche active doit avoir :

`automation/state/<task_id>.json`

Exemple :

{
  "task_id": "monster_001",
  "status": "in_progress",
  "stage": "construction",
  "iteration": 0,
  "last_completed_step": "body_and_head_done",
  "next_step": "build_weapon",
  "studio_target": "Monstres #16",
  "notes": ""
}

Mettre à jour ce fichier après chaque étape importante :

- références inspectées ;
- blockout terminé ;
- visage terminé ;
- équipement terminé ;
- première capture ;
- review reçue ;
- corrections appliquées ;
- nouvelle capture ;
- PASS.

## Reprise

Lorsqu'un worker redémarre :

1. lire `automation/control.json`;
2. vérifier l'absence de `automation/STOP`;
3. chercher d'abord une tâche `waiting_for_worker`, `in_progress` ou `fix_required`;
4. lire son fichier d'état ;
5. reprendre `next_step` ;
6. ne prendre une nouvelle tâche `todo` que s'il n'y a aucune tâche interrompue.
