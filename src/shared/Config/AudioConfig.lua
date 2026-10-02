--!strict
-- Sons de l'Alpha (issue #18) : uniquement des données, lues par AudioController (client).
-- Tous les sons viennent des bibliothèques sous licence de Roblox (Creator Store) :
--   ProSoundEffects (bruitages, « Courtesy of Pro Sound Effects ») et APMOfficial (petites musiques).
-- Ne pas utiliser d'envois de particuliers : beaucoup sont des extraits d'autres jeux, sans droits.
-- Pour changer un son : remplacer son identifiant ici (plusieurs identifiants = variante tirée au hasard).
--   Ids        : identifiants d'assets audio (rbxassetid)
--   Group      : groupe de volume (Groups ci-dessous)
--   Volume     : volume du son (0 à 1, avant le groupe)
--   Pitch      : vitesse de lecture (1 = normale ; < 1 plus grave)
--   Jitter     : variation aléatoire de hauteur (± fraction), contre la répétition
--   Cooldown   : délai minimal entre deux lectures du même son (s), contre le spam
--   Max        : nombre maximal de lectures simultanées du même son
--   Looped     : boucle (ambiance)

export type Sound = {
	Ids: { number },
	Group: string,
	Volume: number,
	Pitch: number?,
	Jitter: number?,
	Cooldown: number?,
	Max: number?,
	Looped: boolean?,
}

local AudioConfig = {
	-- Volumes par groupe (SoundGroup créés par AudioController sous SoundService).
	Groups = {
		Effets = 0.8,
		Interface = 0.7,
		Musique = 0.6,
		Ambiance = 0.35,
	},

	Sounds = {
		-- Combat
		Attaque = { -- coup porté (élan de l'arme), au début de l'attaque
			Ids = { 9120742729, 9120742716, 9120742710 }, -- Whoosh Thick Quick (SFX)
			Group = "Effets", Volume = 0.35, Jitter = 0.08, Cooldown = 0.08, Max = 3,
		},
		Impact = { -- coup reçu, à l'instant du coup visible
			Ids = { 9119061517, 9119061515, 9119061631 }, -- Sharp Punch 6/7/8 (SFX)
			Group = "Effets", Volume = 0.45, Jitter = 0.1, Cooldown = 0.06, Max = 3,
		},
		Seisme = { -- coup au sol du Roi Orc (effet « Seisme »)
			Ids = { 9120901584 }, -- Wood Impact 1 (SFX)
			Group = "Effets", Volume = 0.7, Pitch = 0.75, Cooldown = 0.3, Max = 1,
		},
		UltimeLancement = { -- le héros lance son ultime
			Ids = { 9116393765 }, -- Magic Glow Short Pulsing Bursts 6 (SFX)
			Group = "Effets", Volume = 0.6, Cooldown = 0.2, Max = 2,
		},
		UltimeImpact = { -- l'anneau doré éclate
			Ids = { 9113524242 }, -- Body Impact 3 (SFX)
			Group = "Effets", Volume = 0.7, Pitch = 0.85, Cooldown = 0.2, Max = 2,
		},
		MortEnnemi = { -- le monstre se dissout
			Ids = { 9116406610, 9116406643 }, -- Magic Poofs Thumpy Wheezy Exhale (SFX)
			Group = "Effets", Volume = 0.4, Jitter = 0.08, Cooldown = 0.1, Max = 3,
		},
		MiniBoss = { -- entrée du mini-boss
			Ids = { 9116302511 }, -- Lion Roar Short Blast Attack Angry Sharp 4 (SFX)
			Group = "Effets", Volume = 0.55, Pitch = 0.8, Cooldown = 2, Max = 1,
		},

		-- Fin de combat et récompenses
		Victoire = {
			Ids = { 1842141543 }, -- Victory Lap (sting), APM
			Group = "Musique", Volume = 0.6, Cooldown = 2, Max = 1,
		},
		Defaite = {
			Ids = { 9042992801 }, -- Are You Sad? (sting), APM : piano doux, pas punitif
			Group = "Musique", Volume = 0.6, Cooldown = 2, Max = 1,
		},
		Recompense = { -- chaque carte de récompense qui apparaît (hauteur qui monte de carte en carte)
			Ids = { 9116394545 }, -- Magic Glows Soft Clusters Of Chiming Hits 1 (SFX)
			Group = "Interface", Volume = 0.4, Cooldown = 0.04, Max = 4,
		},

		-- Invocation
		InvocationCharge = { -- le vortex se charge
			Ids = { 9116393976 }, -- Magic Glow Short Pulsing Bursts 9 (SFX)
			Group = "Effets", Volume = 0.55, Cooldown = 0.5, Max = 1,
		},
		InvocationEclat = { -- éclat du voile, le héros jaillit
			Ids = { 9116426727 }, -- Magic Transformation Oscillating Flutter 2 (SFX)
			Group = "Effets", Volume = 0.6, Cooldown = 0.5, Max = 1,
		},
		Revelation = { -- carte du héros obtenu
			Ids = { 125706237686412 }, -- Glistening Harp (sting), APM
			Group = "Musique", Volume = 0.55, Cooldown = 1, Max = 1,
		},

		-- Royaume
		Royaume = { -- le royaume monte de niveau
			Ids = { 9116420961 }, -- Magic Transformation 3, Shimmering Bursts (SFX)
			Group = "Effets", Volume = 0.6, Cooldown = 1, Max = 1,
		},

		-- Ambiance
		AmbianceZone1 = { -- forêt du matin, en boucle, discrète
			Ids = { 9116971174 }, -- Morning Forest Birds 1 (SFX)
			Group = "Ambiance", Volume = 0.5, Looped = true, Max = 1,
		},
	} :: { [string]: Sound },
}

return AudioConfig
