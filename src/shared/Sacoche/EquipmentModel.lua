--!strict
-- Logique d'affichage de l'équipement V1 (#73) dans la Sacoche, pure et testée (tools/test-sacoche.ps1).
-- Le serveur reste seul juge : il envoie les stats FINALES de chaque héros (MaxHealth, AttackDamage), leur
-- bonus d'équipement (EquipmentBonus), les liens Equipment { [SlotType] = ItemInstanceId } et, pour chaque
-- objet, son Bonus, EquippedBy et EquippedSlot. Ce module ne fait que l'arithmétique d'AFFICHAGE sur ces
-- nombres (comparaison avant / après) : il n'en renvoie aucun au serveur. La requête d'écriture se limite à
-- (« Equip », héros, objet) ou (« Unequip », héros, emplacement) : EquipmentModel.request.
--   int(v)                      -> entier arrondi, ou nil si ce n'est pas un nombre fini
--   bonus(raw)                  -> { MaxHealth, AttackDamage } (0 si absent ou invalide)
--   bonusText(bonus)            -> « +30 PV », « +4 ATK », « +10 PV · +1 ATK » ; nil si rien
--   signed(n)                   -> « +5 », « −5 », « +0 »
--   heroStats(hero)             -> PV / ATK finales + bonus (« PV 188 (+30) ») ; nil sans stats serveur
--   heroEquipment(hero, order)  -> { [SlotType] = ItemInstanceId } (emplacements connus, non vides)
--   countText(n, total)         -> « 3/7 équipés »
--   compatible(entries, items, slot) -> objets possédés dont l'emplacement est `slot`
--   state(entry, ctx)           -> Disponible / Équipé : <nom court> (héros courant ou autre)
--   compare(hero, new, old)     -> lignes « ATK : 16 → 21 (+5) » (final - ancien + nouveau)
--   detail(entry, ctx)          -> panneau de détail : état, comparaison, UNE action, raison si désactivée
--   decorate(cards, ctx)        -> cartes enrichies : BonusText, Badge (état, jamais la rareté)
--   doll(hero, ctx)             -> poupée : 7 emplacements, compteur, stats
--   pinSlot(filters, slot, names, order) -> filtres + l'emplacement choisi sur la poupée (même vide)
--   reasonText(reason)          -> refus du serveur avec majuscule initiale (« Action refusée » à défaut)
--   request(action)             -> arguments EXACTS envoyés à EquipmentAction (3 valeurs)

local EquipmentModel = {}

export type Bonus = { MaxHealth: number, AttackDamage: number }
export type Entry = { InstanceId: string, ItemId: string, Bonus: Bonus?, EquippedBy: string?, EquippedSlot: string? }
export type Hero = { Id: string, HeroId: string, Level: number?, MaxHealth: number?, AttackDamage: number?,
	EquipmentBonus: any?, Equipment: any? }
export type ItemInfo = { Name: string, SlotType: string, Icon: string? }
export type Context = {
	Heroes: { [string]: Hero }, -- vue serveur des héros (ArenaStore.heroes)
	Names: { [string]: string }, -- HeroId -> nom complet (HeroConfig)
	Items: { [string]: ItemInfo }, -- ItemConfig.Items
	Entries: { [string]: Entry }, -- objets possédés par InstanceId (vue d'inventaire)
	SlotOrder: { string }, -- ItemConfig.SlotTypes (ordre d'affichage)
	SlotNames: { [string]: string }?,
	Current: string?, -- HeroInstanceId du héros de la poupée
	InCombat: boolean?,
	Busy: boolean?,
	Available: boolean?, -- remote EquipmentAction présent
}
export type StatLine = { Key: string, Label: string, Value: number, Bonus: number, Text: string, ValueText: string, BonusText: string? }
export type CompareLine = { Key: string, Label: string, Before: number, After: number, Delta: number, DeltaText: string, Text: string }
export type State = { Kind: string, Label: string, Holder: string? } -- Kind : "Available" | "Current" | "Other"
export type Action = { Kind: string, Label: string, Hero: string?, Target: string?, Enabled: boolean, Reason: string? }
export type Detail = {
	InstanceId: string, State: State, BonusText: string?, Lines: { CompareLine }, Action: Action,
	Note: string?, Replaces: string?,
}
export type DollSlot = { Slot: string, InstanceId: string?, ItemId: string?, Name: string?, Icon: string? }
export type Doll = { Slots: { DollSlot }, Count: number, Total: number, CountText: string, Stats: { StatLine }? }

local STATS = {
	{ Key = "MaxHealth", Label = "PV" },
	{ Key = "AttackDamage", Label = "ATK" },
}
EquipmentModel.Stats = STATS

local MINUS = "−" -- signe moins typographique (U+2212), déjà affiché par la Sacoche

function EquipmentModel.int(value: any): number?
	if typeof(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return math.floor(value + 0.5)
end

function EquipmentModel.bonus(raw: any): Bonus
	if typeof(raw) ~= "table" then
		return { MaxHealth = 0, AttackDamage = 0 }
	end
	return { MaxHealth = EquipmentModel.int(raw.MaxHealth) or 0, AttackDamage = EquipmentModel.int(raw.AttackDamage) or 0 }
end

function EquipmentModel.signed(n: number): string
	if n < 0 then
		return `{MINUS}{-n}`
	end
	return `+{n}`
end

-- « +30 PV », « +4 ATK », « +10 PV · +1 ATK » ; nil si l'objet n'apporte rien (ou bonus absent de la vue).
function EquipmentModel.bonusText(raw: any): string?
	local b = EquipmentModel.bonus(raw)
	local parts = {}
	for _, stat in STATS do
		local value = (b :: any)[stat.Key]
		if value ~= 0 then
			table.insert(parts, `{EquipmentModel.signed(value)} {stat.Label}`)
		end
	end
	return if #parts > 0 then table.concat(parts, " · ") else nil
end

-- Stats FINALES du serveur et leur part d'équipement : « PV 188 (+30) » ; sans bonus : « PV 150 ».
function EquipmentModel.heroStats(hero: Hero?): { StatLine }?
	if not hero then
		return nil
	end
	local h = hero :: any
	local b = EquipmentModel.bonus(hero.EquipmentBonus)
	local lines: { StatLine } = {}
	for _, stat in STATS do
		local value = EquipmentModel.int(h[stat.Key])
		if value == nil then
			return nil -- serveur sans stats : rien d'inventé
		end
		local extra = (b :: any)[stat.Key] :: number
		local bonusText = if extra ~= 0 then `({EquipmentModel.signed(extra)})` else nil
		local valueText = `{stat.Label} {value}`
		table.insert(lines, {
			Key = stat.Key, Label = stat.Label, Value = value, Bonus = extra,
			ValueText = valueText, BonusText = bonusText,
			Text = if bonusText then `{valueText} {bonusText}` else valueText,
		})
	end
	return lines
end

-- Liens du héros, limités aux emplacements connus et non vides (« » = vide).
function EquipmentModel.heroEquipment(hero: Hero?, slotOrder: { string }): { [string]: string }
	local out: { [string]: string } = {}
	local raw = if hero then hero.Equipment else nil
	if typeof(raw) ~= "table" then
		return out
	end
	for _, slot in slotOrder do
		local id = raw[slot]
		if typeof(id) == "string" and id ~= "" then
			out[slot] = id
		end
	end
	return out
end

function EquipmentModel.countText(count: number, total: number): string
	return `{count}/{total} équipés`
end

function EquipmentModel.compatible(entries: { Entry }, items: { [string]: ItemInfo }, slot: string): { Entry }
	local out: { Entry } = {}
	for _, entry in entries do
		local info = items[entry.ItemId]
		if info and info.SlotType == slot then
			table.insert(out, entry)
		end
	end
	return out
end

local function shortName(name: string): string
	return string.match(name, "^[^%s]+") or name
end

local function heroShort(ctx: Context, heroInstanceId: string?): string?
	local hero = if heroInstanceId then ctx.Heroes[heroInstanceId] else nil
	if not hero then
		return nil
	end
	return shortName(ctx.Names[hero.HeroId] or hero.HeroId)
end

-- État d'un objet : Disponible, ou Équipé : <nom court du héros qui le porte>.
function EquipmentModel.state(entry: Entry, ctx: Context): State
	local holder = entry.EquippedBy
	if typeof(holder) ~= "string" or holder == "" then
		return { Kind = "Available", Label = "Disponible" }
	end
	local name = heroShort(ctx, holder)
	return {
		Kind = if holder == ctx.Current then "Current" else "Other",
		Label = if name then `Équipé : {name}` else "Équipé",
		Holder = holder,
	}
end

-- Avant / après pour le héros : final - bonus de l'ancien + bonus du nouveau. Retirer : new = nil, old = bonus.
function EquipmentModel.compare(hero: Hero?, newBonus: any?, oldBonus: any?): { CompareLine }
	local lines: { CompareLine } = {}
	if not hero then
		return lines
	end
	local h = hero :: any
	local add, remove = EquipmentModel.bonus(newBonus), EquipmentModel.bonus(oldBonus)
	for _, stat in STATS do
		local before = EquipmentModel.int(h[stat.Key])
		if before == nil then
			return {} -- serveur sans stats : pas de comparaison inventée
		end
		local after = before - (remove :: any)[stat.Key] + (add :: any)[stat.Key]
		local delta = after - before
		local deltaText = EquipmentModel.signed(delta)
		table.insert(lines, {
			Key = stat.Key, Label = stat.Label, Before = before, After = after, Delta = delta, DeltaText = deltaText,
			Text = `{stat.Label} : {before} → {after} ({deltaText})`,
		})
	end
	return lines
end

-- Panneau de détail d'un objet pour le héros courant : UNE action (Équiper / Retirer).
function EquipmentModel.detail(entry: Entry, ctx: Context): Detail
	local info = ctx.Items[entry.ItemId]
	local slot = if info then info.SlotType else entry.EquippedSlot
	local state = EquipmentModel.state(entry, ctx)
	local hero = if ctx.Current then ctx.Heroes[ctx.Current] else nil
	local lines: { CompareLine } = {}
	local note: string? = nil
	local replaces: string? = nil
	local action: Action
	if state.Kind == "Current" then
		-- porté par le héros courant : Retirer (comparaison du retrait)
		lines = EquipmentModel.compare(hero, nil, entry.Bonus)
		action = { Kind = "Unequip", Label = "Retirer", Hero = state.Holder, Target = entry.EquippedSlot or slot, Enabled = true } :: Action
	elseif state.Kind == "Other" then
		-- porté par un autre héros : le joueur le retire d'abord (le serveur refuse de le déplacer)
		local here = heroShort(ctx, ctx.Current)
		note = if here then `Retire-le pour l'équiper sur {here}` else nil
		action = { Kind = "Unequip", Label = "Retirer", Hero = state.Holder, Target = entry.EquippedSlot or slot, Enabled = true } :: Action
	else
		local current = EquipmentModel.heroEquipment(hero, ctx.SlotOrder)
		local oldId = if slot then current[slot] else nil
		local old = if oldId then ctx.Entries[oldId] else nil
		if old then
			local oldInfo = ctx.Items[old.ItemId]
			replaces = if oldInfo then oldInfo.Name else nil
		end
		lines = EquipmentModel.compare(hero, entry.Bonus, if old then old.Bonus else nil)
		action = { Kind = "Equip", Label = "Équiper", Hero = ctx.Current, Target = entry.InstanceId, Enabled = hero ~= nil and slot ~= nil } :: Action
		if not hero then
			action.Reason = "Aucun héros"
		end
	end
	if ctx.InCombat then
		action.Enabled = false
		action.Reason = "Impossible pendant un combat"
	elseif ctx.Available == false then
		action.Enabled = false
		action.Reason = "Équipement indisponible"
	elseif ctx.Busy then
		action.Enabled = false
	end
	return {
		InstanceId = entry.InstanceId, State = state, BonusText = EquipmentModel.bonusText(entry.Bonus),
		Lines = lines, Action = action, Note = note, Replaces = replaces,
	}
end

-- Cartes de l'onglet : bonus en texte et état dans le badge du haut (la rareté reste dans ItemCard, en texte).
-- « Disponible » n'a pas de badge (état par défaut) ; « Nouveau » le garde tant que l'objet n'est pas porté.
function EquipmentModel.decorate(cards: { any }, ctx: Context)
	for _, card in cards do
		local entry = ctx.Entries[card.InstanceId]
		if entry then
			card.BonusText = EquipmentModel.bonusText(entry.Bonus)
			local state = EquipmentModel.state(entry, ctx)
			if state.Kind ~= "Available" then
				card.Badge, card.BadgeKind = state.Label, "Equipped"
			elseif card.New then
				card.Badge, card.BadgeKind = "Nouveau", "New"
			end
		end
	end
end

-- Poupée du héros courant : un emplacement par SlotType (objet porté s'il est connu), compteur et stats.
function EquipmentModel.doll(hero: Hero?, ctx: Context): Doll
	local links = EquipmentModel.heroEquipment(hero, ctx.SlotOrder)
	local slots: { DollSlot } = {}
	local count = 0
	for _, slot in ctx.SlotOrder do
		local id = links[slot]
		local entry = if id then ctx.Entries[id] else nil
		local info = if entry then ctx.Items[entry.ItemId] else nil
		if id and entry and info then
			count += 1
			table.insert(slots, { Slot = slot, InstanceId = id, ItemId = entry.ItemId, Name = info.Name, Icon = info.Icon })
		else
			table.insert(slots, { Slot = slot })
		end
	end
	local total = #ctx.SlotOrder
	return { Slots = slots, Count = count, Total = total, CountText = EquipmentModel.countText(count, total), Stats = EquipmentModel.heroStats(hero) }
end

-- Filtres de l'onglet : l'emplacement touché sur la poupée reste affiché même sans objet (compte 0), à sa
-- place dans l'ordre du catalogue, pour montrer honnêtement « aucun objet pour cet emplacement ».
function EquipmentModel.pinSlot(filters: { any }, slot: string?, names: { [string]: string }, slotOrder: { string }): { any }
	if not slot or slot == "all" or not table.find(slotOrder, slot) then
		return filters
	end
	for _, filter in filters do
		if filter.Id == slot then
			return filters
		end
	end
	local out = table.clone(filters)
	local rank = table.find(slotOrder, slot) :: number
	local at = #out + 1
	for index, filter in out do
		local other = table.find(slotOrder, filter.Id)
		if other and other > rank then
			at = index
			break
		end
	end
	table.insert(out, at, { Id = slot, Label = names[slot] or slot, Count = 0 })
	return out
end

-- Refus du serveur affiché en clair : majuscule initiale (UTF-8 : « équipé par… » -> « Équipé par… »).
local UPPER: { [string]: string } = { ["é"] = "É", ["è"] = "È", ["ê"] = "Ê", ["à"] = "À", ["â"] = "Â", ["ç"] = "Ç", ["ô"] = "Ô", ["î"] = "Î" }
function EquipmentModel.reasonText(reason: any): string
	if typeof(reason) ~= "string" or reason == "" then
		return "Action refusée"
	end
	local second = utf8.offset(reason, 2)
	if not second then
		return string.upper(reason)
	end
	local head = string.sub(reason, 1, second - 1)
	local first: string = UPPER[head] or string.upper(head)
	return first .. string.sub(reason, second)
end

-- Arguments EXACTS de EquipmentAction:InvokeServer (jamais d'ItemId, de rareté ni de stat).
function EquipmentModel.request(action: Action): (string?, string?, string?)
	if (action.Kind ~= "Equip" and action.Kind ~= "Unequip") or not action.Hero or not action.Target then
		return nil, nil, nil
	end
	return action.Kind, action.Hero, action.Target
end

return EquipmentModel
