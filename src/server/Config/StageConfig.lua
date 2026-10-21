--!strict
-- Zones et stages de l'Alpha (voir docs/ZONES.md). Uniquement des données : ZoneService ne connaît aucun stage.
--   Zones[zoneId].Stages[stageId] : identifiants entiers consécutifs à partir de 1.
--   Waves  : vagues dans l'ordre, chacune avec ses groupes d'ennemis { EnemyId, Count }.
--   MiniBoss : { EnemyId } facultatif, après la dernière vague (le boss de zone).
--   Difficulty : { MaxHealth?, AttackDamage? } facultatif, multiplicateurs des stats de CombatConfig.Enemies
--     pour TOUTE la zone (Combat.Difficulty), multipliés par ceux de l'Élite. Un même EnemyId reste le même
--     monstre d'une zone à l'autre : seule la zone le rend plus coriace.
-- EnemyId est un identifiant logique ("Slime", "Gobelin", "Boss"…) ; statistiques, modèles et
-- animations y sont associés par CombatConfig et ArenaConfig.EnemyTemplates, pas ici.
-- Aucune récompense ici : elles relèvent de RewardService (#9).
--
-- Convention de progression d'une zone Alpha : X-1 à X-4 = ennemis communs, X-5 = boss de zone.
-- Zone 1 : boss = "Boss" (modèle Ennemi_RoiOrc, le Roi Orc). Simulations (CombatEngine + CombatConfig,
-- 20 tirages) : 1-1 gagné par l'Écuyer seul ; 1-1 à 1-5 gagnés par l'Écuyer + n'importe quel héros n°2
-- (chaque profil de combat ; aucun héros n'est garanti après l'Écuyer). PV ennemis totaux : 280, 340,
-- 480, 520, 650.
--
-- Zones 2 à 6 (docs/ZONES.md § Zones 2 à 6) : la faune des fiches automation/briefs (désert, glace, forges,
-- abysses, ciel), cinq monstres par zone et, en X-5, le monstre fort de fin de zone comme boss. Chaque monstre
-- reprend les stats de l'archétype qu'il remplace (CombatConfig) : mêmes totaux de PV et de dégâts par vague.
-- Simulations (tests #13) : chaque zone se gagne avec l'équipe et le niveau visés dans docs/ZONES.md, et
-- son boss résiste à la même équipe au niveau 1. VALEURS ALPHA PROVISOIRES, pas un balancing final.

local StageConfig = {
	Zones = {
		[1] = {
			Stages = {
				-- 1-1 : stage d'entrée, gagnable par le héros de départ seul.
				[1] = {
					Waves = {
						{ Enemies = { { EnemyId = "Slime", Count = 2 }, { EnemyId = "Gobelin", Count = 2 } } },
					},
				},
				[2] = {
					Waves = {
						{ Enemies = { { EnemyId = "Slime", Count = 3 }, { EnemyId = "Gobelin", Count = 2 } } },
					},
				},
				[3] = {
					Waves = {
						{ Enemies = { { EnemyId = "Slime", Count = 2 }, { EnemyId = "Gobelin", Count = 2 } } },
						{ Enemies = { { EnemyId = "Slime", Count = 2 }, { EnemyId = "Gobelin", Count = 1 } } },
					},
				},
				[4] = {
					Waves = {
						{ Enemies = { { EnemyId = "Slime", Count = 2 }, { EnemyId = "Gobelin", Count = 2 } } },
						{ Enemies = { { EnemyId = "Gobelin", Count = 3 } } },
					},
				},
				-- 1-5 : boss de zone (Roi Orc), précédé d'une petite vague.
				[5] = {
					Waves = {
						{ Enemies = { { EnemyId = "Slime", Count = 2 }, { EnemyId = "Gobelin", Count = 1 } } },
					},
					MiniBoss = { EnemyId = "Boss" },
				},
			},
		},
		-- Zone 2 — Le Royaume des Sables : Vase des Sables, Chacal Parchemin, Scarabée Forge-Soleil, Mange-Dune, Gardien sans Visage ; boss Colosse Enseveli.
		[2] = {
			Difficulty = { MaxHealth = 2.5, AttackDamage = 2.5 },
			Stages = {
				[1] = {
					Waves = {
						{ Enemies = { { EnemyId = "VaseDesSables", Count = 1 }, { EnemyId = "ChacalParchemin", Count = 1 }, { EnemyId = "ScarabeeForgeSoleil", Count = 1 }, { EnemyId = "MangeDune", Count = 1 } } },
					},
				},
				[2] = {
					Waves = {
						{ Enemies = { { EnemyId = "ScarabeeForgeSoleil", Count = 1 }, { EnemyId = "MangeDune", Count = 1 }, { EnemyId = "GardienSansVisage", Count = 2 }, { EnemyId = "VaseDesSables", Count = 1 } } },
					},
				},
				[3] = {
					Waves = {
						{ Enemies = { { EnemyId = "ChacalParchemin", Count = 1 }, { EnemyId = "VaseDesSables", Count = 1 }, { EnemyId = "GardienSansVisage", Count = 2 } } },
						{ Enemies = { { EnemyId = "ScarabeeForgeSoleil", Count = 2 }, { EnemyId = "MangeDune", Count = 1 } } },
					},
				},
				[4] = {
					Waves = {
						{ Enemies = { { EnemyId = "ScarabeeForgeSoleil", Count = 1 }, { EnemyId = "MangeDune", Count = 1 }, { EnemyId = "GardienSansVisage", Count = 2 } } },
						{ Enemies = { { EnemyId = "GardienSansVisage", Count = 2 }, { EnemyId = "ChacalParchemin", Count = 1 }, { EnemyId = "VaseDesSables", Count = 1 } } },
					},
				},
				[5] = {
					Waves = {
						{ Enemies = { { EnemyId = "ChacalParchemin", Count = 1 }, { EnemyId = "VaseDesSables", Count = 1 }, { EnemyId = "ScarabeeForgeSoleil", Count = 1 } } },
					},
					MiniBoss = { EnemyId = "ColosseEnseveli" },
				},
			},
		},
		-- Zone 3 — Le Royaume Gelé : Givrelot, Croc de Glacier, Armure Gelée, Bonhomme Royal, Mammouth Cristallin ; boss Roi sans Été.
		[3] = {
			Difficulty = { MaxHealth = 2.5, AttackDamage = 2.5 },
			Stages = {
				[1] = {
					Waves = {
						{ Enemies = { { EnemyId = "Givrelot", Count = 1 }, { EnemyId = "CrocDeGlacier", Count = 1 }, { EnemyId = "MammouthCristallin", Count = 1 } } },
					},
				},
				[2] = {
					Waves = {
						{ Enemies = { { EnemyId = "Givrelot", Count = 1 }, { EnemyId = "CrocDeGlacier", Count = 1 }, { EnemyId = "ArmureGelee", Count = 1 }, { EnemyId = "BonhommeRoyal", Count = 1 }, { EnemyId = "MammouthCristallin", Count = 1 } } },
					},
				},
				[3] = {
					Waves = {
						{ Enemies = { { EnemyId = "Givrelot", Count = 2 }, { EnemyId = "CrocDeGlacier", Count = 1 }, { EnemyId = "ArmureGelee", Count = 1 } } },
						{ Enemies = { { EnemyId = "MammouthCristallin", Count = 2 } } },
					},
				},
				[4] = {
					Waves = {
						{ Enemies = { { EnemyId = "BonhommeRoyal", Count = 1 }, { EnemyId = "ArmureGelee", Count = 1 }, { EnemyId = "MammouthCristallin", Count = 1 } } },
						{ Enemies = { { EnemyId = "MammouthCristallin", Count = 2 }, { EnemyId = "Givrelot", Count = 1 } } },
					},
				},
				[5] = {
					Waves = {
						{ Enemies = { { EnemyId = "MammouthCristallin", Count = 1 }, { EnemyId = "CrocDeGlacier", Count = 1 }, { EnemyId = "Givrelot", Count = 1 } } },
					},
					MiniBoss = { EnemyId = "RoiSansEte" },
				},
			},
		},
		-- Zone 4 — Les Forges : Chevalier Riveté, Golem Cloche, Fourneau Ambulant, Martelet, Chaîné ; boss Maître des Forges.
		[4] = {
			Difficulty = { MaxHealth = 2.5, AttackDamage = 2.2 },
			Stages = {
				[1] = {
					Waves = {
						{ Enemies = { { EnemyId = "ChevalierRivete", Count = 1 }, { EnemyId = "GolemCloche", Count = 1 }, { EnemyId = "Martelet", Count = 1 }, { EnemyId = "Chaine", Count = 1 } } },
					},
				},
				[2] = {
					Waves = {
						{ Enemies = { { EnemyId = "FourneauAmbulant", Count = 1 }, { EnemyId = "ChevalierRivete", Count = 1 }, { EnemyId = "GolemCloche", Count = 1 }, { EnemyId = "Martelet", Count = 1 }, { EnemyId = "Chaine", Count = 1 } } },
					},
				},
				[3] = {
					Waves = {
						{ Enemies = { { EnemyId = "FourneauAmbulant", Count = 1 }, { EnemyId = "ChevalierRivete", Count = 1 }, { EnemyId = "Martelet", Count = 1 }, { EnemyId = "Chaine", Count = 1 } } },
						{ Enemies = { { EnemyId = "Martelet", Count = 2 }, { EnemyId = "Chaine", Count = 1 } } },
					},
				},
				[4] = {
					Waves = {
						{ Enemies = { { EnemyId = "GolemCloche", Count = 1 }, { EnemyId = "FourneauAmbulant", Count = 1 }, { EnemyId = "ChevalierRivete", Count = 1 }, { EnemyId = "Martelet", Count = 1 } } },
						{ Enemies = { { EnemyId = "GolemCloche", Count = 1 }, { EnemyId = "FourneauAmbulant", Count = 1 }, { EnemyId = "Chaine", Count = 1 }, { EnemyId = "Martelet", Count = 1 } } },
					},
				},
				[5] = {
					Waves = {
						{ Enemies = { { EnemyId = "ChevalierRivete", Count = 1 }, { EnemyId = "GolemCloche", Count = 1 }, { EnemyId = "Chaine", Count = 1 }, { EnemyId = "Martelet", Count = 1 } } },
					},
					MiniBoss = { EnemyId = "MaitreDesForges" },
				},
			},
		},
		-- Zone 5 — Les Abysses : Méduse Couronnée, Murène Miroir, Coffre Bernard, Chevalier Noyé, Crabe Cathédrale ; boss Léviathan.
		[5] = {
			Difficulty = { MaxHealth = 3.3, AttackDamage = 2.85 },
			Stages = {
				[1] = {
					Waves = {
						{ Enemies = { { EnemyId = "MeduseCouronnee", Count = 1 }, { EnemyId = "MureneMiroir", Count = 1 }, { EnemyId = "ChevalierNoye", Count = 1 }, { EnemyId = "CrabeCathedrale", Count = 1 } } },
					},
				},
				[2] = {
					Waves = {
						{ Enemies = { { EnemyId = "CoffreBernard", Count = 1 }, { EnemyId = "MeduseCouronnee", Count = 1 }, { EnemyId = "MureneMiroir", Count = 1 }, { EnemyId = "ChevalierNoye", Count = 1 }, { EnemyId = "CrabeCathedrale", Count = 1 } } },
					},
				},
				[3] = {
					Waves = {
						{ Enemies = { { EnemyId = "CoffreBernard", Count = 1 }, { EnemyId = "MeduseCouronnee", Count = 1 }, { EnemyId = "ChevalierNoye", Count = 1 }, { EnemyId = "CrabeCathedrale", Count = 1 } } },
						{ Enemies = { { EnemyId = "MureneMiroir", Count = 1 }, { EnemyId = "CoffreBernard", Count = 1 }, { EnemyId = "MeduseCouronnee", Count = 1 } } },
					},
				},
				[4] = {
					Waves = {
						{ Enemies = { { EnemyId = "MureneMiroir", Count = 1 }, { EnemyId = "CoffreBernard", Count = 1 }, { EnemyId = "MeduseCouronnee", Count = 1 }, { EnemyId = "ChevalierNoye", Count = 1 } } },
						{ Enemies = { { EnemyId = "CrabeCathedrale", Count = 2 }, { EnemyId = "ChevalierNoye", Count = 1 }, { EnemyId = "MureneMiroir", Count = 1 } } },
					},
				},
				[5] = {
					Waves = {
						{ Enemies = { { EnemyId = "CoffreBernard", Count = 1 }, { EnemyId = "MeduseCouronnee", Count = 1 }, { EnemyId = "CrabeCathedrale", Count = 1 } } },
					},
					MiniBoss = { EnemyId = "Leviathan" },
				},
			},
		},
		-- Zone 6 — Les Îles du Ciel : Gargouille Ailée, Mini Colosse Céleste, Mouton Nuage, Poisson du Ciel, Bec Tonnerre ; boss Gardien Céleste.
		[6] = {
			Difficulty = { MaxHealth = 3.1, AttackDamage = 3.1 },
			Stages = {
				[1] = {
					Waves = {
						{ Enemies = { { EnemyId = "GargouilleAilee", Count = 1 }, { EnemyId = "MoutonNuage", Count = 1 }, { EnemyId = "PoissonDuCiel", Count = 1 } } },
					},
				},
				[2] = {
					Waves = {
						{ Enemies = { { EnemyId = "MiniColosseCeleste", Count = 1 }, { EnemyId = "GargouilleAilee", Count = 1 }, { EnemyId = "MoutonNuage", Count = 1 }, { EnemyId = "PoissonDuCiel", Count = 1 } } },
					},
				},
				[3] = {
					Waves = {
						{ Enemies = { { EnemyId = "MiniColosseCeleste", Count = 1 }, { EnemyId = "MoutonNuage", Count = 2 }, { EnemyId = "PoissonDuCiel", Count = 1 } } },
						{ Enemies = { { EnemyId = "BecTonnerre", Count = 1 }, { EnemyId = "GargouilleAilee", Count = 1 } } },
					},
				},
				[4] = {
					Waves = {
						{ Enemies = { { EnemyId = "BecTonnerre", Count = 1 }, { EnemyId = "MoutonNuage", Count = 1 }, { EnemyId = "PoissonDuCiel", Count = 1 } } },
						{ Enemies = { { EnemyId = "BecTonnerre", Count = 1 }, { EnemyId = "MiniColosseCeleste", Count = 1 }, { EnemyId = "GargouilleAilee", Count = 1 } } },
					},
				},
				[5] = {
					Waves = {
						{ Enemies = { { EnemyId = "BecTonnerre", Count = 1 }, { EnemyId = "MoutonNuage", Count = 1 }, { EnemyId = "PoissonDuCiel", Count = 1 } } },
					},
					MiniBoss = { EnemyId = "GardienCeleste" },
				},
			},
		},
	},
}

return StageConfig
