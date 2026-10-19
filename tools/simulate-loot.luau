--!strict
-- Module de simulation du loot (#72), exécuté par tools/simulate-loot.ps1 : OUTIL À LA DEMANDE, ni test ni CI.
-- Rejoue les VRAIES LootRules sur la VRAIE LootConfig avec un générateur à graine PROPRE (mulberry32, pas
-- math.random) : mêmes paramètres = mêmes chiffres, sur n'importe quelle machine et version de Luau.
--
-- ALPHA 0.0.2 PROVISOIRE : les valeurs de LootConfig sont des placeholders. Ce rapport mesure ce que ces
-- placeholders produisent ; ce n'est PAS un fait de design et aucun seuil n'est validé. Il sert à décider de
-- les remplacer.
--
-- Modèle : `Players` joueurs indépendants (graine dérivée de Seed et de l'index du joueur) font chacun `Runs`
-- victoires dans le mode choisi. Stage 1..5 : toujours ce stage ; Stage 0 : cycle 1-1, 1-2 ... 1-5, 1-1 ...
-- Le premier passage sur un stage compte comme First Clear. Aucun plafond d'inventaire (il est mesuré, pas
-- appliqué). Les victoires sont supposées acquises (la difficulté n'est pas simulée).

return function(LootRules: any, LootConfig: any, catalogs: any, params: { Seed: number, Runs: number, Players: number, Mode: string, Stage: number }): { string }
	local TWO32 = 4294967296
	local CHECKPOINTS = { 10, 50, 100, 500 }

	-- Multiplication 32 bits exacte (les doubles perdent des bits au-delà de 2^53).
	local function mul32(a: number, b: number): number
		local aLo, aHi = bit32.band(a, 0xFFFF), bit32.rshift(a, 16)
		local bLo, bHi = bit32.band(b, 0xFFFF), bit32.rshift(b, 16)
		local high = (aHi * bLo + aLo * bHi) % 65536
		return (high * 65536 + aLo * bLo) % TWO32
	end

	-- mulberry32 : générateur 32 bits à graine, interface de Random (NextNumber, NextInteger).
	local function newRng(seed: number): any
		local a = seed % TWO32
		local rng: any = {}
		function rng.NextNumber(_self: any): number
			a = (a + 0x6D2B79F5) % TWO32
			local t = mul32(bit32.bxor(a, bit32.rshift(a, 15)), bit32.bor(a, 1))
			t = bit32.bxor(t, (t + mul32(bit32.bxor(t, bit32.rshift(t, 7)), bit32.bor(t, 61))) % TWO32)
			return bit32.bxor(t, bit32.rshift(t, 14)) / TWO32
		end
		function rng.NextInteger(self: any, min: number, max: number): number
			return min + math.floor(self:NextNumber() * (max - min + 1))
		end
		return rng
	end

	local elite = params.Mode == "Elite"
	local entries = if elite then LootConfig.EliteStages else LootConfig.Stages
	local slots = {}
	for _, slot in catalogs.Item.SlotTypes do table.insert(slots, slot.Id) end
	local rarities = {}
	for _, tier in catalogs.Rarity.Tiers do table.insert(rarities, tier.Id) end

	local firstBySlot: { [string]: { number } } = {}
	for _, slot in slots do firstBySlot[slot] = {} end
	local complete: { number } = {}
	local atCheckpoint: { [number]: { number } } = {}
	for _, n in CHECKPOINTS do atCheckpoint[n] = {} end
	local rarityCount: { [string]: number } = {}
	local resourceTotal: { [string]: number } = {}
	local totalRuns, runsWithoutEquipment, totalItems = 0, 0, 0

	for player = 1, params.Players do
		local rng = newRng(params.Seed * 1000003 + player * 7919 + 1)
		local first: { [string]: number } = {}
		local seenSlots = 0
		local items = 0
		local cleared: { [number]: boolean } = {}
		local completeAt = math.huge
		for run = 1, params.Runs do
			local stage = if params.Stage > 0 then params.Stage else ((run - 1) % 5) + 1
			local rolled = LootRules.roll(entries[`1-{stage}`], rng, { FirstClear = not cleared[stage], Catalogs = catalogs })
			cleared[stage] = true
			totalRuns += 1
			if #rolled.Items == 0 then runsWithoutEquipment += 1 end
			for _, drop in rolled.Items do
				local info = catalogs.Item.Items[drop.ItemId]
				items += 1
				totalItems += 1
				rarityCount[info.Rarity] = (rarityCount[info.Rarity] or 0) + 1
				if first[info.SlotType] == nil then
					first[info.SlotType] = run
					seenSlots += 1
					if seenSlots == #slots then completeAt = run end
				end
			end
			for _, drop in rolled.Resources do
				resourceTotal[drop.ResourceId] = (resourceTotal[drop.ResourceId] or 0) + drop.Amount
			end
			if atCheckpoint[run] then
				table.insert(atCheckpoint[run], items)
			end
		end
		for _, slot in slots do table.insert(firstBySlot[slot], first[slot] or math.huge) end
		table.insert(complete, completeAt)
	end

	-- Rang le plus proche (nearest-rank) ; math.huge = jamais atteint dans les Runs simulés.
	local function percentile(values: { number }, p: number): number
		local sorted = table.clone(values)
		table.sort(sorted)
		return sorted[math.max(1, math.ceil(p * #sorted))]
	end
	local function show(value: number): string
		return if value == math.huge then `>{params.Runs}` else string.format("%d", value)
	end
	local function triple(values: { number }): string
		return `médiane {show(percentile(values, 0.5))} | p10 {show(percentile(values, 0.1))} | p90 {show(percentile(values, 0.9))}`
	end
	local function reached(values: { number }): string
		local n = 0
		for _, v in values do if v ~= math.huge then n += 1 end end
		return string.format("%.1f %%", 100 * n / #values)
	end

	-- Items atteignables dans ce mode et ces stages (raretés configurées), par emplacement : un emplacement à 0
	-- rend le 7/7 impossible quel que soit le nombre de victoires (constat sur le catalogue, pas un réglage).
	local reachableRarity: { [string]: boolean } = {}
	for stage = 1, 5 do
		if params.Stage == 0 or params.Stage == stage then
			local entry = entries[`1-{stage}`]
			for _, list in { entry.Equipment and entry.Equipment.Rarities, entry.FirstClearEquipment and entry.FirstClearEquipment.Rarities } do
				for _, r in list do reachableRarity[r.Rarity] = true end
			end
		end
	end
	local reachableBySlot: { [string]: number } = {}
	for _, slot in slots do reachableBySlot[slot] = 0 end
	for _, info in catalogs.Item.Ordered do
		if reachableRarity[info.Rarity] then reachableBySlot[info.SlotType] += 1 end
	end

	local out: { string } = {}
	local function line(text: string) table.insert(out, text) end
	line("# Simulation de loot, Zone 1 - OUTIL A LA DEMANDE (tools/simulate-loot.ps1), ni test ni CI")
	line("# ALPHA 0.0.2 PROVISOIRE - placeholder, à remplacer après simulation.")
	line("# Les valeurs de LootConfig sont des placeholders : ces chiffres ne sont PAS un fait de design, aucun seuil n'est validé.")
	line(`Paramètres : Seed={params.Seed} Runs={params.Runs} Players={params.Players} Mode={params.Mode} Stage={if params.Stage > 0 then `1-{params.Stage}` else "cycle 1-1..1-5"}`)
	line("Modèle : victoires acquises, First Clear au premier passage de chaque stage, aucun plafond d'inventaire appliqué.")
	line("")
	line("## Items du catalogue atteignables par emplacement (raretés configurées dans ce mode / ces stages)")
	do
		local parts = {}
		for _, slot in slots do table.insert(parts, `{slot}={reachableBySlot[slot]}`) end
		line("  " .. table.concat(parts, "  "))
		for _, slot in slots do
			if reachableBySlot[slot] == 0 then line(`  ATTENTION : aucun item {slot} atteignable ici, le 7/7 est impossible tel que configuré`) end
		end
	end
	line("")
	line("## Premier équipement par emplacement (numéro de victoire, sur les joueurs simulés)")
	for _, slot in slots do
		line(string.format("  %-10s %s | atteint par %s", slot, triple(firstBySlot[slot]), reached(firstBySlot[slot])))
	end
	line("")
	line("## Victoires jusqu'à 7/7 emplacements (au moins un équipement de chaque type)")
	line(`  {triple(complete)} | atteint par {reached(complete)}`)
	line("")
	line("## Répartition des raretés (tous les équipements obtenus)")
	for _, rarity in rarities do
		local n = rarityCount[rarity] or 0
		if n > 0 then
			line(string.format("  %-13s %8d  %5.1f %%", rarity, n, 100 * n / totalItems))
		end
	end
	if totalItems == 0 then line("  (aucun équipement obtenu)") end
	line("")
	line("## Instances d'équipement possédées après N victoires (moyenne | médiane)")
	for _, n in CHECKPOINTS do
		if n <= params.Runs then
			local values = atCheckpoint[n]
			local sum = 0
			for _, v in values do sum += v end
			line(string.format("  après %3d : %.2f | %d", n, sum / #values, percentile(values, 0.5)))
		else
			line(string.format("  après %3d : (Runs=%d trop court)", n, params.Runs))
		end
	end
	line("")
	line("## Ressources obtenues (moyenne par joueur sur Runs victoires | moyenne par victoire)")
	local ids = {}
	for id in resourceTotal do table.insert(ids, id) end
	table.sort(ids)
	for _, id in ids do
		local perPlayer = resourceTotal[id] / params.Players
		line(string.format("  %s  %-26s %9.2f | %6.3f", id, catalogs.Resource.Resources[id].Name, perPlayer, perPlayer / params.Runs))
	end
	line("")
	line("## Victoires sans équipement")
	line(string.format("  %.1f %% (%d sur %d)", 100 * runsWithoutEquipment / totalRuns, runsWithoutEquipment, totalRuns))
	return out
end
