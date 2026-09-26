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

## Conservation des variantes

Quand un monstre ou un personnage est généré en plusieurs variantes (par défaut deux) et qu'une seule est choisie :

- la variante non retenue est **toujours conservée**, jamais supprimée ;
- la déplacer entière (modèle complet, avec ses pièces sources) dans `ServerStorage.Archive_<Famille>`, sans la modifier ;
- la renommer de façon explicite, par exemple `<Nom>_VarianteB_nonRetenue`, et lui laisser son attribut `MonstreId` s'il existe ;
- noter son chemin d'archive dans `automation/state/<task_id>.json` (champ `notes` ou `completed_steps`).

Aucun `Destroy()` sur une variante, même si elle paraît ratée : seul un humain peut décider de supprimer une variante archivée.

## Reprise

Lorsqu'un worker redémarre :

1. lire `automation/control.json`;
2. vérifier l'absence de `automation/STOP`;
3. chercher d'abord une tâche `waiting_for_worker`, `in_progress` ou `fix_required`;
4. lire son fichier d'état ;
5. reprendre `next_step` ;
6. ne prendre une nouvelle tâche `todo` que s'il n'y a aucune tâche interrompue.

## Précisions V1.2

Le STOP doit être créé dans le worktree actif du pipeline, pas dans une autre copie.
Le bridge respecte ces contrôles avant chaque commande et chaque seconde d'attente.
Une commande déjà lancée peut se terminer avant l'arrêt (délai maximal 60 secondes).
Un STOP local n'annule pas une demande Cloud déjà transmise. Pour l'interrompre,
arrêter aussi la session Cloud. Le réveil du worker après quota nécessite encore
une reprise de sa session Windows ; voir `CLOUD_REVIEW_README.md`.
