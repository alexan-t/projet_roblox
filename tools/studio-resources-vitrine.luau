-- À exécuter dans Studio EDIT (Rojo connecté), place « test ». Assets uniquement, aucun Source de script.
-- 1. Si Workspace.Bestiaire.Inventaire.Ressources n'existe pas : la crée à côté du panneau Équipement,
--    en clonant ce panneau (mêmes cartes, mêmes styles), une rangée par famille de ResourceConfig
--    (docs/RESOURCES.md § 3). Une seule étape ChangeHistoryService (Ctrl+Z). Ne remplace jamais une
--    vitrine existante.
-- 2. Compare la vitrine à ResourceConfig (lecture seule) : emplacement présent, attributs ResourceId /
--    Index / Famille, Nom, Icone.Image = AssetId. Imprime les lignes resource(...) à reporter dans
--    ResourceConfig pour les icônes livrées.
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ResourceConfig = require(game:GetService("ReplicatedStorage").Shared.Config.ResourceConfig)
local inventaire = workspace.Bestiaire.Inventaire
local GAP = 4 -- studs entre les deux panneaux

local function times(value: UDim2, n: number): UDim2
	return UDim2.new(value.X.Scale * n, value.X.Offset * n, value.Y.Scale * n, value.Y.Offset * n)
end

-- Étendue d'un modèle le long d'un axe (coins de toutes ses parts projetés).
local function extent(model: Model, axis: Vector3): (number, number)
	local low, high = math.huge, -math.huge
	for _, part in model:GetDescendants() do
		if not part:IsA("BasePart") then continue end
		local half = part.Size / 2
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local d = (part.CFrame * Vector3.new(sx * half.X, sy * half.Y, sz * half.Z)):Dot(axis)
					low, high = math.min(low, d), math.max(high, d)
				end
			end
		end
	end
	return low, high
end

local function build(): Model?
	local equipement = inventaire.Equipement
	local right = equipement.Panneau.CFrame.RightVector
	local low, high = extent(equipement, right)
	local boxCFrame, boxSize = equipement:GetBoundingBox()
	-- Boîte un peu relevée : le dallage et le sol sous les poteaux ne comptent pas comme obstacle.
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { workspace.Terrain }
	local offset
	for _, side in { -1, 1 } do -- côté gauche (loin de la section Héros) d'abord
		local candidate = right * side * (high - low + GAP)
		local hits = workspace:GetPartBoundsInBox(boxCFrame + candidate + Vector3.new(0, 1, 0), boxSize - Vector3.new(0, 1, 0), params)
		if #hits == 0 then
			offset = candidate
			break
		end
		warn(`Côté {side} occupé par {hits[1]:GetFullName()}`)
	end
	if not offset then
		warn("Aucune place libre à côté du panneau Équipement : vitrine non créée.")
		return nil
	end

	local panel = equipement:Clone()
	panel.Name = "Ressources"
	panel:SetAttribute("Source", "automation/catalogues/resources.json")
	panel:PivotTo(equipement:GetPivot() + offset)

	local fond = panel.Panneau.Affichage.Fond
	local slots = fond.Emplacements
	local template = slots.Item_001:Clone()
	local columnStep = slots.Item_002.Position - slots.Item_001.Position
	local cardRowStep = slots.Item_005.Position - slots.Item_001.Position
	local rowTemplate = fond.Rarete_1:Clone()
	local labelRowStep = fond.Rarete_2.Position - fond.Rarete_1.Position
	for _, child in fond:GetChildren() do
		if child.Name:match("^Rarete_%d+$") then child:Destroy() end
	end
	slots:ClearAllChildren()
	fond.Bandeau.TextLabel.Text = `Ressources · {#ResourceConfig.Ordered} ressources`
	for attribute in template:GetAttributes() do template:SetAttribute(attribute, nil) end
	rowTemplate:SetAttribute("Rarete", nil)

	local perFamily = {}
	for _, info in ResourceConfig.Ordered do perFamily[info.Family] = (perFamily[info.Family] or 0) + 1 end
	local rowOf = {}
	for row, family in ResourceConfig.Families do
		rowOf[family.Id] = row
		local label = rowTemplate:Clone()
		label.Name = `Famille_{row}`
		label:SetAttribute("Famille", family.Name)
		label.Position = rowTemplate.Position + times(labelRowStep, row - 1)
		label.TextLabel.Text = `{family.Name} ({perFamily[family.Id] or 0})`
		label.Parent = fond
	end

	local column = {}
	for _, info in ResourceConfig.Ordered do
		local row = rowOf[info.Family]
		column[row] = (column[row] or 0) + 1
		local card = template:Clone()
		card.Name = ResourceConfig.slotName(info.Index)
		card:SetAttribute("ResourceId", info.Id)
		card:SetAttribute("Index", info.Index)
		card:SetAttribute("Famille", ResourceConfig.FamilyNames[info.Family])
		card:SetAttribute("AssetId", "")
		card.Position = template.Position + times(columnStep, column[row] - 1) + times(cardRowStep, row - 1)
		card.Nom.Text = info.Name
		card.Illustration.Icone.Image = ""
		local numero = card:FindFirstChild("Numero")
		if numero then numero.TextLabel.Text = string.format("%03d", info.Index) end
		card.Parent = slots
	end
	panel.Parent = inventaire
	return panel
end

local panel = inventaire:FindFirstChild("Ressources")
if not panel then
	local recording = ChangeHistoryService:TryBeginRecording("Vitrine des ressources")
	local ok, result = pcall(build)
	if ok and result then
		panel = result
		print("Vitrine Ressources créée (Ctrl+Z pour annuler).")
	elseif not ok then
		warn(`Création de la vitrine interrompue : {result}`)
	end
	if recording then
		ChangeHistoryService:FinishRecording(recording, if ok and result then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
	end
end
if not panel then return end

local slots = panel.Panneau.Affichage.Fond.Emplacements
local problems, delivered, updates = {}, 0, {}
local function report(text) table.insert(problems, text) end

for _, info in ResourceConfig.Ordered do
	local name = ResourceConfig.slotName(info.Index)
	local card = slots:FindFirstChild(name)
	if not card then report(`{name} : emplacement absent`) continue end
	local expected = {
		ResourceId = info.Id,
		Index = info.Index,
		Famille = ResourceConfig.FamilyNames[info.Family],
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
			table.insert(updates, string.format("resource(%q, %q, %q, %q)", info.Id, info.Name, info.Family, assetId))
		end
	end
end
for _, card in slots:GetChildren() do
	local index = tonumber(card.Name:match("^Ressource_(%d+)$"))
	if card:IsA("GuiObject") and not (index and ResourceConfig.Ordered[index]) then
		report(`{card.Name} : emplacement hors catalogue`)
	end
end

print(`Vitrine : {#ResourceConfig.Ordered} ressources, {delivered} icônes livrées, {#problems} écart(s)`)
for _, text in problems do warn(text) end
if #updates > 0 then
	print("Icônes à reporter dans src/shared/Config/ResourceConfig.lua :")
	print(table.concat(updates, "\n"))
end
