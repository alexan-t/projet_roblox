-- À exécuter dans Studio EDIT (Rojo connecté). Lecture seule : ne modifie rien dans la place.
-- Compare la vitrine Workspace.Bestiaire.Inventaire avec ItemConfig (docs/ITEMS.md § 3, § 5) :
-- emplacement présent, attributs ItemId / Index / Rarete / SlotType, Nom, Icone.Image = AssetId.
-- Imprime aussi les lignes item(...) à reporter dans ItemConfig pour les icônes livrées.
local Shared = game:GetService("ReplicatedStorage").Shared.Config
local ItemConfig = require(Shared.ItemConfig)
local RarityConfig = require(Shared.RarityConfig)
local slots = workspace.Bestiaire.Inventaire.Equipement.Panneau.Affichage.Fond.Emplacements
local problems, delivered, updates = {}, 0, {}
local function report(text) table.insert(problems, text) end

for _, info in ItemConfig.Ordered do
	local name = ItemConfig.slotName(info.Index)
	local card = slots:FindFirstChild(name)
	if not card then report(`{name} : emplacement absent`) continue end
	local expected = {
		ItemId = info.Id,
		Index = info.Index,
		Rarete = RarityConfig.tier(info.Rarity).Name,
		SlotType = info.SlotType,
	}
	for attribute, value in expected do
		local actual = card:GetAttribute(attribute)
		if actual ~= value then report(`{name} : {attribute} = {actual}, attendu {value}`) end
	end
	local label = card:FindFirstChild("Nom")
	if not label or label.Text ~= info.Name then
		report(`{name} : Nom = {label and label.Text}, attendu {info.Name}`)
	end
	local icon = card:FindFirstChild("Illustration") and card.Illustration:FindFirstChild("Icone")
	local image = if icon then icon.Image else nil
	local assetId = card:GetAttribute("AssetId") or ""
	if not icon then report(`{name} : Illustration.Icone absente`) end
	if image and image ~= assetId then report(`{name} : Icone.Image = {image}, AssetId = {assetId}`) end
	if assetId ~= "" then
		delivered += 1
		if assetId ~= info.Icon then
			table.insert(updates, string.format("item(%q, %q, %q, %q, %q)", info.Id, info.Name, info.Rarity, info.SlotType, assetId))
		end
	end
end
for _, card in slots:GetChildren() do
	local index = tonumber(card.Name:match("^Item_(%d+)$"))
	if card:IsA("GuiObject") and not (index and ItemConfig.Ordered[index]) then
		report(`{card.Name} : emplacement hors catalogue`)
	end
end

print(`Vitrine : {#ItemConfig.Ordered} items, {delivered} icônes livrées, {#problems} écart(s)`)
for _, text in problems do warn(text) end
if #updates > 0 then
	print("Icônes à reporter dans src/shared/Config/ItemConfig.lua :")
	print(table.concat(updates, "\n"))
end
