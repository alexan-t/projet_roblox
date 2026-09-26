---
name: roblox-creature-artist
description: Crée un nouveau monstre ou boss dans Roblox Studio (MCP) selon la direction artistique validée du jeu (créatures massives, peintes main, matériaux naturels superposés, un point lumineux). À utiliser pour tout brief de monstre, boss ou déclinaison de créature. Aucune rareté pour les monstres.
---

# Roblox creature artist

Workflow obligatoire. On ne saute aucune étape, et on ne déclare rien terminé sans un PASS de `docs/VISUAL_QA.md` obtenu sur des captures réelles.

## 1. Lire

1. Le brief. Noter le type (monstre ou boss), la famille, le rôle, les contraintes et le moodboard.
2. `docs/ART_DIRECTION.md` en entier.
3. `docs/MONSTER_PRODUCTION.md`, surtout les sections « Outils » et « Annexe — prompts ».
4. Le moodboard fourni s'il y en a un, et les moodboards de la même famille dans `docs/references/moodboards/`.

## 2. Inspecter (MCP Roblox Studio)

1. `list_roblox_studios`, puis viser la place `test`. `get_studio_state` doit être en **Edit** ; si Studio est en Play, demander d'arrêter le Play.
2. **Toujours** inspecter au moins deux des **références principales** (`KingTreant`, `Treant_Masque`, `KingSlime`, `RoiOrc` ; `ART_DIRECTION.md` § 1.1), qui fixent le niveau attendu. Y ajouter, seulement si le brief s'y rapporte, une référence **secondaire** (gobelins #12 / #15, slimes, `Treant_Arbre`) pour un point précis. Pour chacune, relever dans `execute_luau` leur taille (`GetBoundingBox`), leur découpage (enfants et `MeshPart`), leurs lumières et leur palette si c'est utile. **Ne pas utiliser** les modèles marqués comme non-références (gobelin chibi, `Heros_Base`, mannequins).
3. Inspecter la zone du brief (ex. `Workspace.PlotTravail.Arene.Zones.<Zone>`) : matières, sources d'ennemis.
4. Une capture de comparaison des références proches si leur aspect n'est pas clair, puis réinitialiser la caméra.

## 3. Concevoir (court, écrit dans la réponse)

En cas d'hésitation entre plusieurs directions visuelles, choisir celle qui suit la logique de King Tréant, Tréant, Slime King et King Orc. On suit leur **langage** (volumes, stylisation, lisibilité, finition, traitement des détails, présence), pas leur apparence : la créature ne doit ressembler à aucune d'elles. Les gobelins ne servent jamais d'arbitre de la DA générale.

- **Idée visuelle principale** en une phrase, et ce qui la rend unique par rapport aux validés.
- **Silhouette :** 3 masses, 1 à 2 éléments qui dépassent, contour supérieur identitaire.
- **Proportions et hauteur cible** (tableau d'échelle de `ART_DIRECTION.md` § 3).
- **Matériaux, palette et point lumineux.**
- **Plan de construction :** pièces du corps (segmentation) et accessoires à générer à part.

## 4. Construire

1. Deux variantes du corps en parallèle (`generate_mesh`, `async: true`, segmentation explicite), avec les deux formulations de prompt de l'annexe. Ajouter « not cute, no smile, no blush ». Un boss se génère les mains vides.
2. Accessoires générés à part (`segmentation: "none"`, `size` réaliste).
3. Nettoyer les noms, ancrer, poser sur un socle libre (`MONSTER_PRODUCTION.md` Outils § F), et enregistrer une étape `ChangeHistoryService`.
4. Assembler par mesure : centre du poing (Outils § D), accroches par raycast, et test de clipping (étape 13).
5. Corriger la texture si besoin : visage (Outils § B), raccord de peau (§ C), pièce grise (§ E).

## 5. Capturer, puis contrôler

1. Faire les captures du tableau 1 de `VISUAL_QA.md` (au minimum face, profil, loin et visage), plus une capture à côté d'au moins une **référence principale**.
2. Remplir la grille de `VISUAL_QA.md` en ne jugeant **que ce qui est visible**.
3. **FIX** : lister les défauts visibles avec leur correction concrète, corriger, **recapturer**, puis repasser la grille entière.
4. **PASS** : réinitialiser la caméra (Outils § A), archiver les variantes non retenues dans `ServerStorage.Archive_<Famille>`, puis nommer le modèle (`PascalCase`) et poser l'attribut `MonstreId` (`snake_case`).

## 6. Rendre compte

Donner le verdict PASS, l'emplacement (socle, chemin Workspace), la taille, l'idée visuelle, ce qui a été corrigé, les limites restantes et les variantes archivées. Si deux variantes sont valables, les montrer et laisser l'utilisateur choisir.

## Interdits

- Inventer une rareté (Common, Rare, Epic…).
- S'inspirer de `Heros_Base`, des mannequins ou du gobelin chibi.
- Déclarer terminé sans capture, ou juger une pièce grise « bonne » sans vérifier le chargement.
- Laisser la caméra de Studio en mode `Scriptable`.
- Écrire du code dans Studio : tout code passe par Git et Rojo.
