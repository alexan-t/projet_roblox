# Production d'un monstre ou d'un boss

Workflow utilisé pour produire les créatures validées : slimes, tréants, gobelins de style tréant, Roi Orc, King Slime, King Tréant. À lire après `ART_DIRECTION.md`. Il n'y a **aucune rareté** pour les monstres : ne pas en inventer, ni dans les noms, ni dans les couleurs, ni dans les attributs.

## Étape 1 — Analyse du brief

Noter en 5 lignes :
- **Type :** monstre (socles Monstres, 4 à 10 studs) ou boss (socles Boss, 13 à 21 studs).
- **Famille :** nouvelle famille ou déclinaison d'une famille existante (slime, tréant, gobelin, orc). Une déclinaison **reprend le design de base** et change une idée : les slimes élémentaires ne diffèrent que par la teinte et la coiffe.
- **Rôle en combat :** corps à corps, distance, tank. Ce rôle dicte l'arme et la posture.
- **Contraintes explicites du brief :** arme, taille, couleurs imposées.
- **Moodboard fourni ?** S'il y en a un, c'est la référence n°1 pour le contenu. Pour le style, on l'interprète selon notre DA (le moodboard gobelin était trop chibi : on n'a gardé que l'équipement).

## Étape 2 — Analyse de la zone

Inspecter la zone dans Studio. Exemple pour la zone 1 : `Workspace.PlotTravail.Arene.Zones.Zone1_PlaineDuRoyaume` contient `CampGobelin`, `Riviere`, `CoinSlimes`, `Ruines`, `Rochers`, `Vegetation`, `Lisiere`, `Clotures`, `Balises`, `Rempart` et `SourcesEnnemis`.

- La zone donne des **matières** et une **ambiance**, pas un déguisement. Le tréant ne ressemble pas à un arbre de la plaine : il en reprend l'écorce, la mousse et les champignons, pour une créature qui a sa propre idée (le masque d'os).
- **Éviter les associations évidentes** : monstre de rivière = poisson, monstre de ruines = golem de pierre, monstre de forêt = arbre qui marche. Chercher une **deuxième association** : une rivière donne des galets polis, des roseaux, de la vase ou un filet de pêcheur abandonné. Des ruines donnent des blasons brisés, des chaînes, des lanternes éteintes ou du lierre qui a mangé une armure.
- Regarder la sortie d'ennemi associée dans `SourcesEnnemis` (mare, tente, buisson, tour) : la créature doit pouvoir en sortir de façon crédible.

## Étape 3 — Idée visuelle principale

Écrire **une phrase** qui décrit l'idée, lisible sur une vignette de 64 px. Exemples validés :
- King Tréant : « un colosse d'écorce avec un masque d'os à spirale et des bois de cerf géants ».
- King Slime : « une gelée royale couronnée de cristaux, avec une cour de cristaux flottants ».
- Roi Orc : « une brute couverte de trophées, avec une lance-hache et un bouclier-blason ».
- Gobelin à dague : « un assassin trapu encapuchonné de rouge, armuré de bois et de cuir ».

**Comment éviter le générique :**
- **Gobelin générique** : petit bonhomme vert en pagne avec une massue. **Notre version** : trapu et musclé, capuche rouge, armure tribale en bois, os et cuir, mousse, yeux jaunes lumineux.
- **Slime générique** : boule de gelée unie. **Notre version** : gelée brillante à reflets et bulles, avec une **coiffe** qui raconte quelque chose (touffe de feuilles, chapeau de champignon, feuilles de feu, couronne de cristaux).
- **Golem générique** : empilement de blocs. **Notre version** : corps d'un seul tenant en matière vivante (écorce, racines, mousse), un **masque** à la place du visage et un **cœur lumineux**.
- **Test :** si l'on peut remplacer le nom de la créature par « un monstre de fantasy » sans rien perdre, l'idée est trop faible. Il faut un élément qu'on ne verrait sur aucun autre monstre du jeu.

## Étape 4 — Silhouette

- Définir les **3 masses principales et 1 à 2 éléments qui dépassent** (ART_DIRECTION § 5).
- Le **contour supérieur** doit être unique et différent de toutes les créatures validées.
- Prévoir l'**asymétrie** par l'équipement (arme d'un côté, bouclier ou main libre de l'autre).

## Étape 5 — Proportions

Appliquer ART_DIRECTION § 3 : haut du corps lourd, jambes à un tiers de la hauteur, bras longs et épais, tête petite (créatures fortes) ou grande sans excès (gobelins), posture voûtée. Fixer la hauteur cible selon l'échelle du tableau § 3.

## Étape 6 — Volumes et construction

C'est la méthode qui donne nos meilleurs résultats :

1. **Générer 2 variantes du corps en parallèle** (`generate_mesh`, `async: true`) avec deux formulations différentes (voir les modèles de prompt en annexe) :
   - une formulation **descriptive et précise** : ordre corps, visage, équipement, palette ;
   - une formulation **« Warcraft-like stylized … chunky readable silhouette, painterly hand-painted texture »**.
2. **Segmentation explicite** avec des noms de membres : `["head", "torso", "left arm", "right arm", "left leg", "right leg", <arme>, <bouclier>]`. Les tréants ont en plus `"crystal core"`, les slimes `["body", "eyes", "<coiffe>"]`. Maximum 8 pièces.
3. **Pour un boss :** générer le corps **les mains vides** (« empty hands in fists »), puis générer **chaque accessoire à part** : arme, bouclier, couronne, cornes, crânes, bannière, cristaux, bois, champignons, avec une taille cible (`size`). Enfin, les assembler par mesure. Un prompt surchargé produit un modèle trop simple.
4. `size` du corps : 4 × 6 × 3 pour un gobelin, 7 × 8 × 4 pour un tréant, 11 × 12 × 6 à 12 × 14 × 7 pour un boss. Mettre à l'échelle ensuite avec `Model:ScaleTo` si besoin (King Tréant ×1,35, King Slime ×1,3 puis ×1,25).
5. Poser les variantes sur des socles libres, les comparer en capture, et **montrer les deux** à l'équipe avant de continuer.

## Étape 7 — Visage

- Vérifier en capture de face, de près : **aucun sourire, aucune joue rose, aucune fossette, aucun groin**.
- Si seule la peinture est fausse : retoucher les pixels (Outils § B) ou `generate_texture` sur la seule tête, avec un prompt court et positif (un prompt long a renvoyé « Bad Request »).
- Si la **forme** est fausse (nez en groin, par exemple) : régénérer **la tête seule** (`segmentation: "none"`), la mettre à l'échelle, la recaler sur le cou, puis recolorer sa peau sur celle du torse (Outils § C).

## Étape 8 — Membres et prises en main

- **Centre du poing** : le trouver par mesure (Outils § D). Le manche passe par ce point.
- Arme d'hast perpendiculaire au corps, lames dans le plan vertical. Dague pointée vers l'avant, plat visible de profil.
- Bouclier : dos plaqué contre le poing, face vers l'avant, légèrement tourné vers l'extérieur (environ 8°).
- Vérifier sous 3 angles : face, profil, dessus.

## Étape 9 — Éléments distinctifs

Ajouter les 1 à 3 éléments qui portent l'idée (étape 3) : couronne, bois, masque, cristaux flottants, bannière. Les **accrocher à une surface mesurée** (raycast), jamais « à vue ». Tout ce qui flotte sans raison magique évidente est refusé.

## Étape 10 — Matériaux et couleurs

- Tout est dans la texture peinte. Le `Neon` est réservé aux yeux lumineux ; une `PointLight` discrète (luminosité ≤ 1,5, portée ≤ 16) seulement sur le point focal.
- **Même peau partout :** comparer la teinte moyenne de la tête et des mains avec celle du torse. Recolorer si l'écart est visible.
- Pièces restées **grises** après génération ou retexture : `generate_texture` sur tout le modèle pour les harmoniser, sinon réenregistrer la texture (Outils § E).
- **Variante élémentaire :** décaler la teinte (HSV) de la texture de base plutôt que retexturer par IA. Cela garde les reflets et le design identiques.

## Étape 11 — Détails secondaires

Petits groupes impairs, concentrés en haut du corps : 3 pics d'épaule, 5 à 7 feuilles, 2 à 3 champignons, crânes à la ceinture. Chaque détail est **accroché** (sur l'écorce, pendu à une corde, glissé sous une sangle). Aucun détail sous 0,5 stud.

## Étape 12 — Polish

- Retirer les artefacts de texture : couture sombre (bord de texture qui déborde), taches de couleur parasites.
- Ancrer toutes les pièces (`Anchored = true`, `CanCollide = false` sur les accessoires).
- Nommer : `Model` racine en PascalCase (`KingTreant`), attribut `MonstreId` en snake_case (`boss_king_treant`). Pièces : `<membre>/<membre>_geom`, ajouts dans `equipement` ou `accessoires`.
- Déplacer les variantes non retenues et les pièces sources dans `ServerStorage.Archive_<Famille>`.

## Étape 13 — Contrôle du clipping

Par mesure, pas seulement à l'œil :
- **Arme et bras :** échantillonner des points sur la lame et tester s'ils sont « dans » le bras (Outils § D). Seul le manche doit l'être.
- **Accessoire et corps :** pour une pièce plaquée (bannière, bouclier), mesurer l'écart entre son dos et la surface du corps sur une grille de points. Il doit être partout **positif** (≥ 0,03) et petit (≤ 0,4) sur l'essentiel de la surface.
- **Accessoire et accessoire :** `workspace:GetPartsInPart(pièce, OverlapParams)` (le crâne qui traversait le bouclier a été trouvé ainsi).

## Étape 14 — Cadrage et capture finale

- Captures à hauteur de poitrine, à 6 à 10 studs pour un petit monstre et 18 à 25 pour un boss : **face**, **trois-quarts**, **profil**, plus une capture **de loin** (30 à 60 studs) pour la lisibilité.
- Attendre que les textures soient chargées : une pièce grise ou noire à la première capture est souvent un chargement en cours. Relancer la capture avant de conclure.
- Passer `VISUAL_QA.md`. En cas de FIX : corriger, puis recapturer.
- **Réinitialiser la caméra** (Outils § A) après la dernière capture.

---

## Outils (MCP Roblox Studio) — pièges connus et procédures

- **Studio :** l'identifiant change à chaque relance. Appeler `list_roblox_studios` et viser la place `test`. En mode **Play**, on ne peut ni générer ni modifier (« Model generation should only be called from the server ») : demander d'arrêter le Play.
- **`generate_mesh` :** long, souvent plus de 5 minutes. Utiliser `async: true`, puis `wait_job_finished` ; relancer l'attente si elle expire. Les noms de pièces arrivent avec des guillemets et des crochets : les nettoyer. **Les étiquettes de segmentation sont parfois fausses** (sur un slime, « leaves » contenait les yeux et « flower » les feuilles) : vérifier les tailles avant de supprimer. Les modèles arrivent souvent tournés : corriger l'orientation. `segment_mesh` est cassé (« parts must be a table »).
- **`generate_texture` :** remplace la texture du `MeshPart` ou du `Model` visé. Il ajoute volontiers des sourires et des joues roses : toujours vérifier.

**A. Caméra.** Après `screen_capture`, la caméra reste en mode `Scriptable`, et l'utilisateur perd le clic droit et le clic molette. Remettre `CameraType = Fixed` **ne suffit pas**. Procédure qui marche : attendre environ 2 s après la dernière capture, sauvegarder `CFrame` et `Focus`, faire `workspace.CurrentCamera:Destroy()`, attendre la nouvelle caméra, remettre `CameraType = Fixed` et restaurer `CFrame` et `Focus`. Limiter le nombre de captures.

**B. Retouche de pixels.** Ouvrir la texture avec `AssetService:CreateEditableImageAsync(Content.fromUri(id))`, puis `ReadPixelsBuffer`. Modifier dans Luau pour les petits cas ; sinon exporter vers un petit serveur HTTP local (Python, `127.0.0.1:8765`, qui écrit un PNG) via `EncodingService:Base64Encode` et `HttpService:RequestAsync`, en activant `HttpEnabled` **puis en le remettant à `false` dans le même script**. Retoucher en Python (numpy, PIL), puis `upload_image` sur `http://127.0.0.1:8765/<fichier>.png` pour obtenir un `rbxassetid`, et l'appliquer à `TextureContent`. `AssetService:CreateAssetAsync` n'est pas disponible. Les sorties d'outil de plus de 100 000 caractères sont tronquées : ne jamais renvoyer des pixels par `return`.

**C. Raccord de peau.** Calculer la moyenne HSV des pixels « peau » (vert dominant) du torse et de la tête, puis décaler teinte, saturation et luminosité de la tête vers celles du torse. Les autres pixels restent intacts.

**D. Centre du poing et test « dedans ».** Un point est considéré dans une pièce si au moins 5 des 6 rayons axiaux de 1,5 stud touchent cette pièce. Chercher sur une grille autour du poing le point qui maximise ce score : c'est le centre de prise. Pour valider une arme : aucun point de la lame (au-delà du manche) ne doit être « dedans ».

**E. Texture grise ou noire qui ne s'affiche pas.** Lire l'image (si `CreateEditableImageAsync` réussit, la texture existe), l'exporter puis la réenregistrer (§ B), et appliquer le nouvel identifiant. `ContentProvider:PreloadAsync` seul n'a pas suffi.

**F. Placement sur socle.** Dessus du socle = `Dessus.Position.Y + Dessus.Size.X / 2` (cylindre couché). Centrer la boîte englobante du **corps** (pas de l'équipement) sur `PointDePose`, et poser le bas de la boîte sur le dessus du socle.

## Annexe — prompts qui ont produit des validés

Corps de boss (King Tréant, validé) :
> Stylized hand-painted KING TREANT boss, massive hulking tree golem, facing front, hunched powerful stance, very broad shoulders. Body of twisted brown bark and roots densely covered with green ivy leaves and small white flowers. Head is a cream bone-colored carved wooden mask shaped like a pointed diamond with a brown spiral rune and two glowing cyan eyes. Huge branching antler-like branches growing from the head and shoulders with leaves. Glowing cyan diamond crystal core in the chest held by twisted roots. Grey carved stone shoulder pads with diamond runes. Long heavy arms ending in huge curved pale wooden claws, stone plate with diamond rune on the forearms. Thick root legs. Red spotted mushrooms growing on shoulders. Rope belt.

Gobelin (`GobLanceT_A`, validé) :
> Stylized hand-painted goblin warrior in the same art style as a chunky forest treant boss: rich painterly textures, earthy palette, adult and fierce, not cute. Wiry but muscular body, hunched aggressive stance, facing forward. Dark olive green skin with scars, long pointed ears with bone rings, fierce face with heavy brow, glowing yellow eyes, snarl with sharp fangs. Layered tribal gear: dark red tattered hood, carved bone and wooden shoulder plate with diamond rune, leather straps, rope belt with small skulls and wooden charms, moss and leaves tucked in, cloth-wrapped forearms, clawed bare feet. Right hand holds a long wooden spear with a jagged stone-and-iron head and red rag; left arm holds a round wooden shield with bone rim and a carved diamond rune.

Gobelin (`GobDagueT_B`, validé, formulation « Warcraft-like ») :
> Warcraft-like stylized goblin rogue with a dagger, chunky readable silhouette, painterly hand-painted texture, earthy browns and dark greens with red cloth accents, crouched ready to strike, glowing yellow eyes, fanged snarl, pointed ears, hood, tribal gear of carved wood, bone and leather with diamond rune carvings, moss and leaves, charms on a rope belt, holding a jagged curved dagger. Adult, menacing, detailed.

Corps de boss mains vides (`RoiOrc`, validé après assemblage) :
> Massive orc warlord king, stylized fantasy game character, hand-painted texture, extremely detailed armor. Giant muscular green body, hunched, fists clenched, front view. Angry face with yellow eyes, giant tusks jutting up from lower jaw, pierced ears with gold hoops. Spiked crown of iron and wooden stakes crowned with many bone spikes and two large ivory horns. Enormous shoulder armor: stacked wooden planks bound by riveted iron plates with big bone spikes. Red ragged scarf, crossed leather straps with dangling skulls, fangs and bone totems, heavy belt with skull trophies and gold rings, long ragged red banner loincloth with cream diamond emblem, iron knee guards, bulky plated boots. Earthy palette olive green, red, brown, iron grey, bone white.

Accessoire (modèle de formulation) :
> Stylized hand-painted <objet> only, <forme précise>, <matières>, <1 détail identitaire>, cartoon game prop.

Avec `segmentation: "none"`, un `size` réaliste et `maxTriangles` de 600 à 5000 selon l'objet.

À ajouter systématiquement pour un visage : « no smile, no blush, not cute ». Pour une gelée : « no dark outline stripes on the sides ».
