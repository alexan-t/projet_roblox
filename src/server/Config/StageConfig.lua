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
-- Zones 2 à 6 (docs/ZONES.md § Zones 2 à 6) : uniquement des monstres et boss VALIDÉS (docs/ART_DIRECTION.md
-- § 1), aucun inventé. Trois boss validés pour six zones : chacun revient une fois, plus fort.
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
		-- Zone 2 — La Mare aux Slimes : slimes des mares, des ronces et des champignons ; boss Slime King.
		[2] = {
			Difficulty = { MaxHealth = 2.5, AttackDamage = 2.5 },
			Stages = {
				[1] = {
					Waves = {
						{ Enemies = { { EnemyId = "Slime", Count = 2 }, { EnemyId = "SlimePlante", Count = 2 } } },
					},
				},
				[2] = {
					Waves = {
						{ Enemies = { { EnemyId = "SlimePlante", Count = 2 }, { EnemyId = "SlimeChampignon", Count = 2 }, { EnemyId = "Slime", Count = 1 } } },
					},
				},
				[3] = {
					Waves = {
						{ Enemies = { { EnemyId = "Slime", Count = 2 }, { EnemyId = "SlimeChampignon", Count = 2 } } },
						{ Enemies = { { EnemyId = "SlimePlante", Count = 3 } } },
					},
				},
				[4] = {
					Waves = {
						{ Enemies = { { EnemyId = "SlimePlante", Count = 2 }, { EnemyId = "SlimeChampignon", Count = 2 } } },
						{ Enemies = { { EnemyId = "SlimeChampignon", Count = 2 }, { EnemyId = "Slime", Count = 2 } } },
					},
				},
				[5] = {
					Waves = {
						{ Enemies = { { EnemyId = "Slime", Count = 2 }, { EnemyId = "SlimePlante", Count = 1 } } },
					},
					MiniBoss = { EnemyId = "KingSlime" },
				},
			},
		},
		-- Zone 3 — La Forêt des Tréants : tréants masqués, slimes des ronces et gobelins ; boss King Tréant.
		[3] = {
			Difficulty = { MaxHealth = 2.5, AttackDamage = 2.5 },
			Stages = {
				[1] = {
					Waves = {
						{ Enemies = { { EnemyId = "SlimePlante", Count = 2 }, { EnemyId = "Treant", Count = 1 } } },
					},
				},
				[2] = {
					Waves = {
						{ Enemies = { { EnemyId = "SlimePlante", Count = 2 }, { EnemyId = "Gobelin", Count = 2 }, { EnemyId = "Treant", Count = 1 } } },
					},
				},
				[3] = {
					Waves = {
						{ Enemies = { { EnemyId = "SlimePlante", Count = 3 }, { EnemyId = "Gobelin", Count = 1 } } },
						{ Enemies = { { EnemyId = "Treant", Count = 2 } } },
					},
				},
				[4] = {
					Waves = {
						{ Enemies = { { EnemyId = "Gobelin", Count = 2 }, { EnemyId = "Treant", Count = 1 } } },
						{ Enemies = { { EnemyId = "Treant", Count = 2 }, { EnemyId = "SlimePlante", Count = 1 } } },
					},
				},
				[5] = {
					Waves = {
						{ Enemies = { { EnemyId = "Treant", Count = 1 }, { EnemyId = "SlimePlante", Count = 2 } } },
					},
					MiniBoss = { EnemyId = "KingTreant" },
				},
			},
		},
		-- Zone 4 — Le Camp de la Horde : gobelins à lance et à dague ; le Roi Orc revient, plus fort.
		[4] = {
			Difficulty = { MaxHealth = 2.5, AttackDamage = 2.2 },
			Stages = {
				[1] = {
					Waves = {
						{ Enemies = { { EnemyId = "Gobelin", Count = 2 }, { EnemyId = "GobelinDague", Count = 2 } } },
					},
				},
				[2] = {
					Waves = {
						{ Enemies = { { EnemyId = "Gobelin", Count = 3 }, { EnemyId = "GobelinDague", Count = 2 } } },
					},
				},
				[3] = {
					Waves = {
						{ Enemies = { { EnemyId = "Gobelin", Count = 2 }, { EnemyId = "GobelinDague", Count = 2 } } },
						{ Enemies = { { EnemyId = "GobelinDague", Count = 3 } } },
					},
				},
				[4] = {
					Waves = {
						{ Enemies = { { EnemyId = "Gobelin", Count = 3 }, { EnemyId = "GobelinDague", Count = 1 } } },
						{ Enemies = { { EnemyId = "Gobelin", Count = 2 }, { EnemyId = "GobelinDague", Count = 2 } } },
					},
				},
				[5] = {
					Waves = {
						{ Enemies = { { EnemyId = "Gobelin", Count = 2 }, { EnemyId = "GobelinDague", Count = 2 } } },
					},
					MiniBoss = { EnemyId = "Boss" },
				},
			},
		},
		-- Zone 5 — Les Grottes de Lave : slimes de lave et gobelins à dague ; le Slime King revient, plus fort.
		[5] = {
			Difficulty = { MaxHealth = 3.3, AttackDamage = 2.85 },
			Stages = {
				[1] = {
					Waves = {
						{ Enemies = { { EnemyId = "SlimeLave", Count = 2 }, { EnemyId = "GobelinDague", Count = 2 } } },
					},
				},
				[2] = {
					Waves = {
						{ Enemies = { { EnemyId = "SlimeLave", Count = 3 }, { EnemyId = "GobelinDague", Count = 2 } } },
					},
				},
				[3] = {
					Waves = {
						{ Enemies = { { EnemyId = "SlimeLave", Count = 2 }, { EnemyId = "GobelinDague", Count = 2 } } },
						{ Enemies = { { EnemyId = "SlimeLave", Count = 3 } } },
					},
				},
				[4] = {
					Waves = {
						{ Enemies = { { EnemyId = "SlimeLave", Count = 3 }, { EnemyId = "GobelinDague", Count = 1 } } },
						{ Enemies = { { EnemyId = "GobelinDague", Count = 3 }, { EnemyId = "SlimeLave", Count = 1 } } },
					},
				},
				[5] = {
					Waves = {
						{ Enemies = { { EnemyId = "SlimeLave", Count = 2 }, { EnemyId = "GobelinDague", Count = 1 } } },
					},
					MiniBoss = { EnemyId = "KingSlime" },
				},
			},
		},
		-- Zone 6 — Le Bois Ancien : vieux tréants, tréants masqués et slimes champignons ; le King Tréant revient.
		[6] = {
			Difficulty = { MaxHealth = 3.1, AttackDamage = 3.1 },
			Stages = {
				[1] = {
					Waves = {
						{ Enemies = { { EnemyId = "Treant", Count = 1 }, { EnemyId = "SlimeChampignon", Count = 2 } } },
					},
				},
				[2] = {
					Waves = {
						{ Enemies = { { EnemyId = "Treant", Count = 2 }, { EnemyId = "SlimeChampignon", Count = 2 } } },
					},
				},
				[3] = {
					Waves = {
						{ Enemies = { { EnemyId = "Treant", Count = 1 }, { EnemyId = "SlimeChampignon", Count = 3 } } },
						{ Enemies = { { EnemyId = "TreantArbre", Count = 1 }, { EnemyId = "Treant", Count = 1 } } },
					},
				},
				[4] = {
					Waves = {
						{ Enemies = { { EnemyId = "TreantArbre", Count = 1 }, { EnemyId = "SlimeChampignon", Count = 2 } } },
						{ Enemies = { { EnemyId = "TreantArbre", Count = 1 }, { EnemyId = "Treant", Count = 2 } } },
					},
				},
				[5] = {
					Waves = {
						{ Enemies = { { EnemyId = "TreantArbre", Count = 1 }, { EnemyId = "SlimeChampignon", Count = 2 } } },
					},
					MiniBoss = { EnemyId = "KingTreant" },
				},
			},
		},
	},
}

return StageConfig
