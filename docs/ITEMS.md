# Items 2D

Les items (équipements et ressources) sont des **icônes 2D**, pas des modèles 3D. Ce document
dit ce qui existe déjà, comment produire une icône et **où chaque item doit s'afficher**.

## 1. État actuel

- **Aucun système d'items en jeu** pour l'instant : `PlayerData` ne stocke que les monnaies
  (`Gold`, `Gems`, `SummonTickets`), les héros, l'équipe, le royaume, les quêtes et les
  réglages (`src/shared/Types/PlayerDataTypes.lua`). Le catalogue, les statistiques, le stockage
  et l'obtention des items restent à définir côté gameplay. **Ne pas inventer de rareté** :
  elle n'est pas définie (voir `UI_DESIGN_SYSTEM.md` § 2).
- La **Sacoche** du joueur (`HeroBarController`, PR #44) prévoit déjà les onglets
  **Équipement** et **Ressources**, encore vides (« Bientôt disponible »).
- Les règles visuelles viennent du design system UI : cartes et slots (§ 6), icônes (§ 7).

## 2. Où les items s'affichent

| Où | Quand | Rôle |
| --- | --- | --- |
| **Vitrine `Inventaire`** de la place Studio « test » | dès qu'une icône est produite | voir toutes les icônes ensemble, à la bonne taille, dans le cadre réel des cartes, et les valider |
| **Sacoche**, onglets Équipement / Ressources | quand le système d'items existera | inventaire du joueur en jeu |
| **Écran de récompenses** | quand #9 existera | cartes de récompense, quantité en bas à droite (« ×3 ») |

**Règle : tout item produit doit être posé dans la vitrine `Inventaire`.** Un item qui n'y est
pas n'est pas considéré comme livré.

### Vitrine `Inventaire` (Studio)

`Workspace.Bestiaire.Inventaire`, à gauche de la section Héros du Bestiaire. Deux panneaux en
bois, une catégorie par panneau, mêmes noms que les onglets de la Sacoche :

```
Workspace.Bestiaire.Inventaire
  Equipement.Panneau.Affichage.Frame.Emplacements.Slot_01 … Slot_45
  Ressources.Panneau.Affichage.Frame.Emplacements.Slot_01 … Slot_45
```

Chaque `Slot_NN` reprend la carte standard de la Sacoche (`Cream`, contour `Ink`, zone
d'illustration `Sand`, numéro en badge) et contient :

| Élément | À remplir |
| --- | --- |
| `Illustration.Icone` (ImageLabel) | `Image` = `rbxassetid://…` de l'icône |
| `Nom` (TextLabel) | nom court affiché (« Épée en bois ») |
| attribut `ItemId` du slot | identifiant `snake_case` (`epee_bois`) |
| attribut `Categorie` | déjà rempli (`Équipement` ou `Ressources`) |

Remplir les slots dans l'ordre, sans trou. Quand un panneau est plein, en ajouter un à côté
(même construction) plutôt que de réduire les cartes.

## 3. Produire une icône

Règles du design system (§ 7), résumées :

- Une icône est **un petit objet du monde**, pas un pictogramme : formes chunky arrondies,
  couleurs de la palette matière (bois, sable, pierre, or…), lumière chaude venant d'en haut à
  gauche, légère ombre propre.
- **Silhouette lisible à 32 px** : l'objet occupe environ 80 % du cadre, aucun détail sous 6 %,
  une couleur dominante + un accent.
- **Contour `Ink` (`#1F1A17`) cuit dans l'image**, environ 6 % de la taille.
- Vue de **trois quarts**, **fond transparent**, PNG **512 × 512** (256 minimum).
- Interdits : emoji, icônes plates génériques, traits fins, style futuriste, photoréalisme.

Nommage : fichier `item_<item_id>.png`, `ItemId` en `snake_case`, nom affiché court en
majuscule initiale uniquement.

## 4. Contrôle avant de livrer un item

1. L'icône est posée dans le bon panneau de la vitrine, avec `Nom` et `ItemId` remplis.
2. Elle se lit de loin (capture de la vitrine entière) et de près (capture de la carte).
3. Elle a le même rendu que ses voisines : contour, lumière, saturation, taille de l'objet.
4. Aucune rareté ni statistique inventée dans le nom ou l'image.
