# Design system UI

Référence pour **toutes** les interfaces du jeu : HUD, fenêtres, préparation de combat, panneaux
dans le monde. Les valeurs vivent dans un seul module, `src/shared/Config/UITheme.lua`
(`ReplicatedStorage.Shared.Config.UITheme`). **Aucune couleur, transparence, police, rayon ou
durée en dur dans un Controller** : on lit `UITheme`.

Maquette de validation, construite en Studio avec ces tokens par-dessus l'arène :
`docs/references/ui/maquette_v1.jpg`.

## 1. Charte en une phrase

L'UI est faite **des mêmes matières que la map** (bois, sable, toile, pierre), en **formes
rondes et généreuses**, avec un **contour noir chaud net** et du **texte Fredoka One
contouré**, posée en **semi-transparence** pour que l'on voie toujours le monde derrière.

```
monde 3D toujours visible
+ panneau légèrement teinté (bois sombre ou crème, semi-transparent)
+ contour Ink net qui suit les coins arrondis
+ texte Fredoka One clair, contour Ink
```

Ce qui est **hors DA** : gros rectangles opaques plein écran, dégradés glossy, textures
réalistes, icônes plates génériques ou emoji, traits fins, style futuriste ou « app mobile »,
liseré marron semi-transparent, texte blanc sans contour sur fond transparent.

## 2. Palette

Les couleurs « matière » sont **relevées dans la map** (surfaces de `PlotTravail`, `Lobby` et
`PlotsZones` pondérées par leur taille), pas inventées.

### Matières

| Token | Hex | Vient de | Usage UI |
| --- | --- | --- | --- |
| `Ink` | `#1F1A17` | — | contours, voile, fond des barres |
| `InkSoft` | `#3A2C22` | — | texte sur fond clair (infobulle) |
| `TextLight` | `#FFF6E4` | — | texte sur fond foncé ou coloré |
| `TextMuted` | `#CDBFA6` | — | texte secondaire sur fond foncé |
| `Cream` | `#F3E6C8` | murs, tour | cartes, infobulles |
| `Sand` | `#E2D4B8` | dallage | zone d'illustration des cartes |
| `SandWarm` | `#DEBC82` | clairières | variantes de cartes |
| `SandGold` | `#E8C670` | chemins, pont | progression |
| `Stone` / `StoneDark` / `StoneGrey` | `#D6C6A8` / `#A89880` / `#968A7E` | bordures, murets, rochers | neutre, verrouillé |
| `WoodLight` / `Wood` / `WoodDark` | `#BA8454` / `#96623E` / `#6C442A` | pont, palissade, troncs | boutons secondaires, bandeaux de titre |
| `WoodDeep` | `#3E2A1C` | bois très sombre | fond des panneaux et du HUD |
| `Grass` / `GrassLight` / `Leaf` | `#7AB854` / `#8CC050` / `#408E4A` | herbe, buissons, feuillage | décor, succès |
| `River` / `RiverLight` / `Foam` | `#46A2EC` / `#76CCF6` / `#ECF8FF` | eau, cascade | information, énergie |
| `Gold` / `GoldLight` / `GoldDeep` | `#E6B23A` / `#F5CB5C` / `#C98E22` | emblèmes, bordures | bouton principal, sélection, or |
| `RoyalRed` | `#B83E30` | toiles, drapeaux | fermer, danger, « Nouveau » |
| `RoyalBlue` | `#3460B0` | drapeau du royaume | identité du royaume (rare) |
| `Torch` / `Crystal` | `#FF8C28` / `#48E8E8` | torches, cristaux | accents très rares |

### États

| Token | Hex | Règle |
| --- | --- | --- |
| `Success` | `#5DB043` | quête terminée, « Disponible », gain |
| `Error` | `#D9483B` | refus, perte, PV ennemis |
| `Warning` | `#F2A93B` | attention, ressource presque vide |
| `Info` | `#46A2EC` | aide, information neutre |
| `Disabled` | `#8F8478` | fond gris pierre, contenu à `Transparency.Disabled` |
| `Selected` | `#F5C542` | contour doré épais (4 px) ou onglet doré |
| Hover | — | voile clair `Transparency.Hover` + `Animation.Scale.Hover` ; jamais seul indicateur (tactile) |

### Barres et monnaies

`Health #6CC04A`, `HealthLow #E04A3A` (≤ 30 %), `EnemyHealth #D9483B`, `Energy #46A2EC`,
`EnergyFull #F5C542` (pulse), `Progress #E8C670`, fond `BarTrack` = `Ink`.
Monnaies : `CurrencyGold #E6B23A`, `CurrencyGems #48C8E8`, `CurrencyTickets #B83E30`.

**Rareté des héros** : pas encore définie (#10). Ne pas inventer de paliers ni de couleurs ;
le cadre reste neutre (`Ink`) en attendant. Les **monstres n'ont aucune rareté**.

Règle de dosage, reprise de la DA : base **bois/sable** désaturée, accents saturés (or, rouge,
bleu) **rares** et porteurs de sens.

## 3. Transparence

`BackgroundTransparency` (0 = opaque). Le monde doit rester visible derrière tout ce qui n'est
pas une infobulle.

| Token | Valeur | Composant |
| --- | --- | --- |
| `Panel` | 0,25 | grand panneau, fenêtre (fond `WoodDeep`) |
| `PanelStrong` | 0,12 | sous-panneau, carte, slot, onglet inactif |
| `HUD` | 0,45 | HUD permanent (monnaies, barre de combat) |
| `Overlay` | 0,5 | voile `Ink` derrière une fenêtre modale (jamais noir plein) |
| `Tooltip` | 0,04 | infobulle (fond `Cream`, texte `InkSoft`) |
| `Track` | 0,35 | fond des barres |
| `Shadow` | 0,75 | ombre portée |
| `Disabled` | 0,45 | texte et icône d'un élément désactivé |

**Lisibilité garantie** : tout texte Fredoka posé sur un fond transparent porte un contour
`Ink` (§ 5). Un **texte long** (Builder Sans) ne se pose **jamais** directement sur un
`Panel` : il va dans un sous-panneau `PanelStrong` ou une infobulle, sinon un fond clair du
monde peut le rendre illisible.

## 4. Typographie

| Rôle | Police | Taille (px, écran 1080) | Contour |
| --- | --- | --- | --- |
| Victoire / Défaite | Fredoka One | `Hero` 56 | 4 |
| Titre de fenêtre | Fredoka One | `Title` 32 | 3 |
| Section, nom de héros | Fredoka One | `Heading` 24 | 3 |
| Bouton | Fredoka One | `Button` 22 | 3 |
| Onglet, compteur, label | Fredoka One | `Label` 18 | 2 |
| Badge, mention courte | Fredoka One | `Caption` 14 (minimum absolu) | 2 |
| Description longue | Builder Sans Medium | `Body` 18 | aucun (fond renforcé) |

- **Fredoka One** est déjà la police de tous les textes du monde (476 textes) : l'UI la reprend.
  Builder Sans (police Roblox gratuite) sert uniquement aux phrases longues.
- Texte Fredoka : couleur `TextLight` + `UIStroke` `Contextual` `Ink`. Sur infobulle crème :
  `InkSoft`, sans contour.
- Tailles fixes + `UIScale` global pour adapter à l'écran. `TextScaled` est réservé aux
  panneaux du monde.
- Labels courts, en majuscule initiale uniquement. Pas de phrases dans les boutons.
- La police n'a pas tous les symboles (« ✕ » s'affiche en carré vide) : utiliser « X » ou une icône.

## 5. Contours

- Couleur **`Ink` `#1F1A17`**, opaque, `LineJoinMode.Round`. Plus aucun liseré marron
  semi-transparent ni `TextStroke` (1 px, trop fin).
- **Panneaux, boutons, cartes** : `UIStroke` en mode `Border` sur la `Frame` qui porte le
  `UICorner` : le contour suit les coins arrondis.
- **ScreenGui** : épaisseur fixe en pixels (`StrokeSizingMode.FixedSize`), donc constante quelle
  que soit la taille du panneau : `Thin` 2 (badge, slot, barre), `Regular` 3 (bouton, carte),
  `Thick` 4 (fenêtre).
- **Panneaux du monde** (BillboardGui ou SurfaceGui dimensionnés en studs) : épaisseur relative
  (`StrokeSizingMode.ScaledSize`, `WorldScaled` = 0,08), pour qu'elle reste proportionnée de près
  comme de loin. Exemple appliqué : titre « Zone 1 » de `PlotTravail`.
- **Sélection** : le contour passe en `Selected`, épaisseur 4. Pas de deuxième contour.

## 6. Composants

Rayons : `Small` 8 (badge), `Medium` 12 (bouton, carte, slot), `Large` 18 (panneau),
`Pill` (pastille, barre, bouton rond). Espacements sur une grille de 4 (`XS` 4 → `XXL` 32),
marge d'écran 16, zone tactile minimale 44 × 44.

### Boutons (« chunky »)
Une **face** et une **lèvre** : la lèvre est une copie plus sombre décalée de `ButtonLip`
(4 px) vers le bas, avec le même contour. Face : `UIGradient` vertical **léger** (pas de reflet).

| Type | Face (haut → bas) | Lèvre | Texte |
| --- | --- | --- | --- |
| Principal | `GoldLight` → `GoldDeep` | brun doré foncé | `TextLight` + contour |
| Secondaire | `WoodLight` → `Wood` | `WoodDark` | `TextLight` + contour |
| Danger / fermer | `RoyalRed` (rond, « X ») | — | `TextLight` + contour |
| Désactivé | `Disabled` → `StoneGrey` | gris foncé | contenu à 0,45 |

États : **normal** ; **hover** = scale 1,04 + voile clair ; **pressed** = la face descend sur la
lèvre (lèvre masquée) et scale 0,94 ; **disabled** = gris pierre, aucun retour ; **selected** =
contour `Selected` 4 px. **Un seul bouton principal par écran.**

### Panneaux et fenêtres
- Fond `WoodDeep` à `Panel`, contour `Thick`, rayon `Large`, ombre `Shadow` (décalée, sans flou).
- Titre dans un **bandeau en bois** (`Wood`, opaque, contour `Thick`) à cheval sur le bord haut.
- Bouton fermer : rond `RoyalRed` à cheval sur le coin haut droit.
- Fenêtre modale : voile `Ink` à `Overlay` derrière. Aucune fenêtre plein écran opaque.

### Onglets
Pastilles `Medium` : actif `Gold` opaque, inactif `WoodDeep` à `PanelStrong`. Texte `Label`.

### Cartes de héros, slots, inventaire, récompenses
- Carte `Cream` à `PanelStrong`, contour `Regular`, rayon `Medium`.
- **Grande zone d'illustration** (≥ 60 % de la hauteur) en `Sand` semi-transparent : portrait
  (ViewportFrame) ou icône. Nom court dessous, en `Heading` ou `Label`.
- **Badge d'état** à cheval sur le bord haut : `Disponible` (`Success`), `Équipé` (`Gold`, et
  contour `Selected` sur la carte), `Nouveau` (`RoyalRed`, petit pop), `Verrouillé`
  (`StoneGrey`, carte à 0,4), `Max` (`Gold`).
- Slot vide : même cadre, fond `WoodDeep` à `PanelStrong`, sans contenu.

### Badges
Pastille `Pill`, couleur d'état, contour `Thin`, texte `Caption`. Un seul badge par carte.

### Infobulles
`Cream` à `Tooltip`, contour `Regular`, titre Fredoka `InkSoft`, texte Builder Sans `InkSoft`.

### Barres (PV, énergie, progression)
Fond `BarTrack` à `Track`, contour `Thin`, rayon `Pill`, remplissage opaque. PV au-dessus de
l'énergie ; PV `HealthLow` sous 30 % ; énergie pleine `EnergyFull` qui pulse. Ennemis :
`EnemyHealth`. Mini-boss : barre plus large. Progression (quêtes, niveau) : `Progress`.

### Monnaies
Pastille `HUD` (`WoodDeep` à 0,45, contour `Regular`) avec l'**icône qui déborde** à gauche et le
montant en `Label`. Gain : le montant défile (`Animation.Count`) et l'icône fait un pop.

### Récompenses
Cartes de récompense = cartes standard, l'icône au centre, quantité en bas à droite (« ×3 »).
Apparition en cascade (pop décalé de 0,05 s par carte).

### Quêtes
Ligne = sous-panneau `PanelStrong` : icône, titre `Label`, barre `Progress`, compteur
« 3/5 ». Terminée : badge `Success` et bouton principal « Récupérer ».

## 7. Icônes

Une icône est **un petit objet du monde**, pas un pictogramme.

- **Même construction que les props** : formes chunky arrondies, couleurs de la palette
  matière, éclairage chaud venant d'en haut à gauche, légère ombre propre (volume).
- **Silhouette forte** : lisible en 32 px. L'objet occupe environ 80 % du cadre ; aucun détail
  sous 6 % de la taille. Une couleur dominante + un accent.
- **Contour `Ink`** cuit dans l'image (environ 6 % de la taille), comme le texte.
- Peut **déborder** légèrement de son cadre (pastille de monnaie, carte), pour l'effet chunky.
- Interdits : emoji (provisoires actuels du combat), icônes plates génériques, traits fins,
  style futuriste, photoréalisme.

**Fabrication** : modéliser l'objet en Studio avec les matières de la map (ou réduire un prop
existant : tonneau, pièce, parchemin, tour), le rendre de trois quarts sur fond transparent en
256 ou 512 px, ajouter le contour, puis l'importer en `ImageLabel`. Héros et monstres : portrait
3D en **ViewportFrame** (déjà le cas dans la main de préparation).

Icônes à produire en priorité : pièce d'or, gemme, ticket d'invocation, collection de héros,
quêtes (parchemin), royaume (tour), carte des zones, combat (épées croisées), paramètres
(roue en bois), cadenas, coche, ultime (éclat doré), icône de chaque classe de héros.

## 8. Animations

Courtes, douces, jamais agressives. Durées dans `UITheme.Animation`.

| Situation | Effet |
| --- | --- |
| Pression | scale 0,94 en 0,08 s, retour en 0,12 s |
| Survol | scale 1,04 en 0,12 s |
| Ouverture de fenêtre | 0,9 → 1 en 0,22 s (`Back Out`, petit dépassement) + fondu du voile |
| Fermeture | 1 → 0,9 + fondu en 0,12 s |
| Toast / annonce | glisse et pop en 0,25 s, reste 2 à 3 s, disparaît en fondu |
| Gain, badge « Nouveau » | pop 1 → 1,12 → 1 |
| Compteur | défile en 0,4 s |
| Mana pleine | pulse lent et continu de la barre |

Aucune animation au-delà de 0,4 s, pas de motion blur, un seul rebond au maximum.

## 9. Tokens Roblox

Module `UITheme` (structure) :

```lua
UITheme = {
	Colors = { Ink, InkSoft, TextLight, TextMuted, Cream, Sand, …, Success, Error, Warning,
		Info, Disabled, Selected, Health, HealthLow, EnemyHealth, Energy, EnergyFull, Progress,
		BarTrack, CurrencyGold, CurrencyGems, CurrencyTickets },
	Transparency = { Panel = 0.25, PanelStrong = 0.12, HUD = 0.45, Overlay = 0.5,
		Tooltip = 0.04, Track = 0.35, Shadow = 0.75, Disabled = 0.45, Hover = 0.08 },
	Typography = { Display (Fredoka One), Body / BodyBold (Builder Sans), Size = {…},
		TextStroke = { Small = 2, Medium = 3, Large = 4 } },
	Radius = { Small, Medium, Large, Pill },
	Stroke = { Color, Thin = 2, Regular = 3, Thick = 4, WorldScaled = 0.08, LineJoin },
	Spacing = { XS = 4, S = 8, M = 12, L = 16, XL = 24, XXL = 32, ScreenMargin = 16, TouchTarget = 44 },
	Shadow = { Color, Transparency, Offset, ButtonLip = 4 },
	Animation = { Press, Hover, Open, Close, Fade, Toast, Count, Scale = {…} },
}
```

Utilisation : `local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)`, puis
`frame.BackgroundColor3 = UITheme.Colors.WoodDeep`. Une nouvelle couleur passe d'abord par ce
module et par ce document.

## 10. Exemples appliqués aux écrans existants

### Préparation de combat (`ArenaPrepController`)
- **Main de héros** : cartes héros standard (§ 6) en bas de l'écran, à `PanelStrong`, portrait
  ViewportFrame, icône de classe dessinée (§ 7) à la place des emoji ; carte posée = badge
  `Équipé`. L'arène reste entièrement visible au-dessus.
- **Pastille du roster** (« Stage 1-1 · Slime ×2… ») : pastille `HUD` + texte `Label` contouré.
- **Combattre** : bouton principal doré. **Quitter** : bouton secondaire bois.
- **Grille** : surbrillance de la case survolée en `Selected`.

### Combat (`ArenaPrepController`, `CombatViewController`)
- Les informations des unités restent **dans le monde** : barres PV/énergie (§ 6), icône de
  classe, chiffres de dégâts Fredoka contourés, ultime en touchant le héros prêt.
- **Barre basse légère** : une pastille `HUD` centrée en bas, avec « Vague 1/1 », x1/x2 (onglets,
  actif doré) et un bouton rond « X » pour quitter. Pas de portraits permanents ni de doublon
  des PV.
- **Annonces** (vague, mini-boss) : texte `Title` contouré, sans fond, pop puis fondu.
- **Victoire / Défaite** : texte `Hero` (Victoire en `Gold`, Défaite en `Error`, contour 4),
  récompenses en cartes sous le titre quand #9 existera, bouton principal « Continuer ».
  Voile `Overlay`, jamais d'écran noir.

### Panneaux du monde
- Titres des zones (`AffichageZone`, `EtiquetteZone`) : Fredoka One, contour `Ink` en
  `ScaledSize` (déjà appliqué à « Zone 1 » de `PlotTravail`). Les panneaux Zone 2 à 6
  (`Workspace.PlotsZones`) sont à aligner. Les bordures dorées de cadre peuvent rester : ce sont
  des éléments du décor, pas des contours UI.

## 11. Contrôle avant de livrer une interface

1. Capture réelle en Studio **par-dessus le monde** (fond clair et fond sombre).
2. Le monde se voit derrière tous les panneaux, sauf les infobulles.
3. Tout texte se lit à 100 % sur les deux fonds ; aucun texte sous 14 px.
4. Contours `Ink`, coins arrondis, épaisseurs `Thin` / `Regular` / `Thick` uniquement.
5. Un seul bouton principal visible ; zones tactiles ≥ 44 px.
6. Aucune valeur de style en dur dans le Controller : tout vient de `UITheme`.
7. Pas d'emoji ni d'icône générique dans une version livrée.

## 12. Implémentation : UIKit (issue #19)

Les composants de ce document existent en code, côté client : `src/client/UI/UIKit.lua`
(`StarterPlayerScripts.Client.UI.UIKit`). Un écran se construit avec eux plutôt qu'à la main :

| Fonction | Composant (§) |
| --- | --- |
| `UIKit.screen(name, order?)` | ScreenGui + `UIScale` global (écran de référence 1080 px, entre 0,7 et 1,25) |
| `UIKit.text(parent, text, size, { Color, Stroke, Align })` | texte Fredoka contouré Ink, épaisseur selon la taille (§ 4) |
| `UIKit.button(parent, { Text, Style, Size, OnClick })` | bouton chunky `Primary` / `Secondary` / `Danger` / `Disabled`, états survol, appui, sélection (§ 6) |
| `UIKit.roundButton(parent, { Text = "X", ... })` | bouton rond (fermer) |
| `UIKit.panel(parent, { Size, Title, OnClose })` | fenêtre : fond `WoodDeep`, ombre, bandeau de titre en bois, fermer |
| `UIKit.subPanel`, `UIKit.pill` | sous-panneau `PanelStrong`, pastille `HUD` |
| `UIKit.badge(parent, text, color)` | badge d'état à cheval sur le bord haut |
| `UIKit.bar(parent, { Color })` | barre PV / énergie / progression (`Set(ratio, animate?)`) |
| `UIKit.tabs(parent, { Items, Selected, OnSelect })` | onglets, actif doré |
| `UIKit.card(parent, { Name, Model, Badge, Selected, Locked, Empty })` | carte standard avec portrait 3D |
| `UIKit.portrait(parent, model)` | portrait 3D trois quarts (ViewportFrame) |
| `UIKit.overlay`, `UIKit.open`, `UIKit.close`, `UIKit.popIn`, `UIKit.announce` | voile, ouverture / fermeture, pop, annonce (§ 8) |

Icônes de classe (§ 7) : `src/client/UI/ClassIcons.lua`, petits objets 3D (arc, épée, hache,
bouclier, bâton, cible) avec silhouette Ink, dans un ViewportFrame — plus d'emoji.

Écrans déjà passés au design system : préparation et HUD de combat (`ArenaPrepController`),
barres et bouton « Ultime » au-dessus des héros (`CombatViewController`), écran Victoire /
Défaite et récompenses (`RewardScreenController`), branché sur `CombatEnded`.
Démonstrations Studio sans serveur : `Workspace.ApercuHudCombat = true` (préparation → combat
simulé → victoire), tag `ApercuBarres` sur un modèle (barres, mana, bouton Ultime).
