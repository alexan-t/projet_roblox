# Audio — SFX et ambiance minimale (issue #18)

Couche sonore purement présentationnelle, côté client :

- `src/shared/Config/AudioConfig.lua` : la liste des sons (identifiants, volume, hauteur, garde-fous).
  **Pour changer un son, on ne touche qu'à ce fichier.**
- `src/client/Controllers/AudioController.lua` : joue les sons, applique les garde-fous, gère l'ambiance.

Aucune règle de jeu : chaque contrôleur d'effet appelle `AudioController.Play` à l'instant de son
effet visuel. Le son tombe donc avec le coup visible, en x1 comme en x2.

## Provenance (droits)

Uniquement les bibliothèques sous licence de Roblox, gratuites sur le Creator Store :

- **ProSoundEffects** (bruitages, « Courtesy of Pro Sound Effects ») ;
- **APMOfficial** (petites musiques, « Courtesy of APM Music »).

Ne pas prendre d'envois de particuliers : beaucoup sont des extraits d'autres jeux, sans droits.
Pour chercher dans ces seules bibliothèques, utiliser l'API de la boîte à outils avec le filtre
`userId` (ProSoundEffects = 7462895450, APMOfficial = 7462718749), par exemple :
`https://apis.roblox.com/toolbox-service/v2/assets:search?searchCategoryType=Audio&query=whoosh&userId=7462895450`.

## Sons et déclencheurs

| Moment (#18) | Son | Déclenché par |
| --- | --- | --- |
| Attaque de base | `Attaque` (whoosh) | `CombatViewController`, événement `Attack` |
| Impact | `Impact` (coup sec, 3 variantes) | `DamageFeedbackController.Hit`, à l'instant du coup |
| Impact spécial (Roi Orc) | `Seisme` | `AttackEffectController`, effet `Seisme` |
| Ultime | `UltimeLancement` puis `UltimeImpact` | `UltimateEffectController.Play` (impact à l'éclat de l'anneau) |
| Mort ennemi | `MortEnnemi` (« poof » magique) | `DefeatEffectController.Play`, au début de la dissolution |
| Mini-boss | `MiniBoss` (rugissement grave) | `ArenaPlacementController`, événement `MiniBossStarted` |
| Victoire / défaite | `Victoire` / `Defaite` (sting APM) | `RewardScreenController.Show` |
| Reward | `Recompense` (carillon qui monte de carte en carte) | apparition de chaque carte |
| Invocation / reveal | `InvocationCharge`, `InvocationEclat`, `Revelation` | `SummonEffectController`, `SummonView.Reveal` |
| Feedback royaume | `Royaume` | `KingdomChangeController.Play`, quand le royaume sort du sol |
| Ambiance Zone 1 | `AmbianceZone1` (forêt du matin, boucle) | `AudioController` au démarrage, fondu de 2 s |

## Anti-spam

Pour chaque son, dans `AudioConfig` :

- `Cooldown` : délai minimal entre deux lectures (ex. 0,06 s pour `Impact`) ;
- `Max` : lectures simultanées au plus (ex. 3 impacts, 1 mini-boss) ;
- `Jitter` et plusieurs `Ids` : légère variation, pour que la répétition ne fatigue pas.

Volumes par groupe (`SoundGroup` sous `SoundService`) : Effets 0,8, Interface 0,7, Musique 0,6,
Ambiance 0,35.

## Studio

- Les démos Studio (attaque, ultime, dégâts, royaume, invocation, récompenses) jouent aussi leurs
  sons : c'est le moyen le plus simple d'écouter.
- Les démos tournant en boucle, Studio peut devenir bruyant : attribut `Workspace.SonCoupe = true`
  pour tout couper.

## Validation (Test 3)

Mesures en Play : les 20 identifiants se chargent ; l'ambiance démarre ; sur 10 s de démos,
`Impact` ne dépasse jamais 3 lectures simultanées, `Seisme`, `Royaume` et l'invocation 1 ;
victoire puis cartes de récompense toutes les 0,05 s. Le choix des sons se fait à l'oreille :
chacun se remplace en une ligne dans `AudioConfig`.
