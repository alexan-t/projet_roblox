--!strict
-- Difficulté d'un combat (Mode Élite, voir docs/COMBAT.md) : stats ennemies de la session. Pur, testé.
-- Seules MaxHealth et AttackDamage sont multipliées (arrondies à l'entier) ; toute autre stat est copiée
-- telle quelle. Sans multiplicateurs : les stats de base, inchangées (Mode Normal).

local Difficulty = {}

-- Stats modifiables par la difficulté (toute autre clé de multiplicateurs est refusée par check).
Difficulty.Scaled = table.freeze({ MaxHealth = true, AttackDamage = true } :: { [string]: boolean })

export type Multipliers = { MaxHealth: number?, AttackDamage: number? }

-- Copie de la table des ennemis (EnemyId -> stats), multipliée ; les EnemyId ne changent pas.
function Difficulty.enemies(base: { [string]: any }, multipliers: Multipliers?): { [string]: any }
	local out: { [string]: any } = {}
	for enemyId, stats in base do
		local copy = table.clone(stats)
		if multipliers then
			for key, factor in multipliers :: any do
				if Difficulty.Scaled[key] and typeof(copy[key]) == "number" and typeof(factor) == "number" then
					copy[key] = math.floor(copy[key] * factor + 0.5)
				end
			end
		end
		out[enemyId] = copy
	end
	return out
end

-- Problèmes d'un jeu de multiplicateurs ; vide s'il est utilisable.
function Difficulty.problems(multipliers: any): { string }
	local problems: { string } = {}
	if typeof(multipliers) ~= "table" then
		return { "multiplicateurs attendus" }
	end
	for key, factor in multipliers do
		if not Difficulty.Scaled[key] then
			table.insert(problems, `stat non modifiable : {tostring(key)}`)
		elseif typeof(factor) ~= "number" or factor ~= factor or factor <= 0 or factor == math.huge then
			table.insert(problems, `{key} : multiplicateur > 0 attendu`)
		end
	end
	return problems
end

return Difficulty
