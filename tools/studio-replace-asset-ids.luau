--!strict
-- À exécuter en EDIT dans la place DEV (barre de commande), APRÈS republication sous le propriétaire
-- de l'expérience (docs/ASSET_OWNERSHIP.md § 6). Remplace chaque ancien AssetId de MAPPING par le
-- nouveau dans toutes les instances de ROOTS (copies, Bestiaire et archives compris).
-- DRY_RUN = true : n'écrit rien, liste ce qui serait remplacé. Puis DRY_RUN = false : une seule étape
-- ChangeHistoryService (Ctrl+Z annule tout). Ne sauvegarde pas la place.
-- MeshPart.MeshId n'est pas modifiable par script : le mesh passe par AssetService:CreateMeshPartAsync
-- puis MeshPart:ApplyMesh (taille, CFrame, matériau et enfants conservés).
local AssetService = game:GetService("AssetService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local DRY_RUN = true
-- ["ancien"] = "nouveau" (identifiants numériques seuls). Lot pilote : docs/ASSET_OWNERSHIP_AUDIT.md.
local MAPPING: { [string]: string } = {}
local ROOTS: { Instance } = { workspace, game:GetService("ReplicatedStorage"), game:GetService("ServerStorage") }

local PROPS: { [string]: { string } } = {
	MeshPart = { "MeshId", "TextureID" },
	SpecialMesh = { "MeshId", "TextureId" },
	Decal = { "Texture" },
	Texture = { "Texture" },
	ImageLabel = { "Image" },
	ImageButton = { "Image" },
	ParticleEmitter = { "Texture" },
	Beam = { "Texture" },
	Trail = { "Texture" },
	SurfaceAppearance = { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" },
}

for old, new in MAPPING do
	assert(old:match("^%d+$") and new:match("^%d+$"), `identifiant invalide : {old} → {new}`)
	assert(old ~= new, `ancien et nouveau identiques : {old}`)
end

local meshCache: { [string]: MeshPart } = {}
local function meshSource(id: string): MeshPart
	if not meshCache[id] then
		meshCache[id] = AssetService:CreateMeshPartAsync(Content.fromUri(`rbxassetid://{id}`))
	end
	return meshCache[id]
end

local recording = nil
if not DRY_RUN then
	recording = ChangeHistoryService:TryBeginRecording("Remplacer des AssetIds republiés")
	-- Refusé quand un autre enregistrement est ouvert (ex. outil MCP) : repli sur les points d'étape.
	if not recording then ChangeHistoryService:SetWaypoint("Avant remplacement des AssetIds") end
end

local replaced, failed = 0, 0
local perId: { [string]: number } = {}
local ok, err = pcall(function()
	for _, root in ROOTS do
		local instances = root:GetDescendants()
		table.insert(instances, root)
		for i, d in instances do
			local props = PROPS[d.ClassName]
			if props then
				-- Valeurs lues avant toute écriture : ApplyMesh remet TextureID à vide.
				local values = {}
				for _, prop in props do values[prop] = (d :: any)[prop] end
				for _, prop in props do
					local value = values[prop]
					local old = type(value) == "string" and value:match("rbxassetid://(%d+)") or nil
					local new = old and MAPPING[old]
					if not new then continue end
					perId[old] = (perId[old] or 0) + 1
					if DRY_RUN then
						replaced += 1
						continue
					end
					local done, why = pcall(function()
						if d:IsA("MeshPart") and prop == "MeshId" then
							local part = d :: MeshPart
							part:ApplyMesh(meshSource(new))
							part.TextureID = values.TextureID -- remplacé à son tour si besoin
						else
							(d :: any)[prop] = `rbxassetid://{new}`
						end
					end)
					if done then
						replaced += 1
					else
						failed += 1
						warn(`ÉCHEC {d:GetFullName()}.{prop} {old} → {new} : {why}`)
					end
				end
			end
			if i % 2000 == 0 then task.wait() end
		end
	end
end)

for _, part in meshCache do part:Destroy() end
if recording then
	ChangeHistoryService:FinishRecording(recording, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
elseif not DRY_RUN then
	ChangeHistoryService:SetWaypoint("Remplacement des AssetIds")
end
assert(ok, err)

local missing = {}
for old in MAPPING do
	if not perId[old] then table.insert(missing, old) end
end
print(`{if DRY_RUN then "[ESSAI] " else ""}{replaced} propriétés remplacées, {failed} échecs, {#missing} anciens identifiants introuvables`)
if #missing > 0 then print(`Introuvables : {table.concat(missing, ", ")}`) end
if not DRY_RUN then print("Place NON SAUVEGARDÉE : vérifier en Play (capture), puis enregistrer.") end
return failed
