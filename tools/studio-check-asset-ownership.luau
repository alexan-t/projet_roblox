--!strict
-- À exécuter en EDIT dans la place DEV (barre de commande) : lecture seule, ne modifie rien.
-- Contrôle la propriété des assets (docs/ASSET_OWNERSHIP.md) : chaque AssetId des configs
-- (ReplicatedStorage.Shared.Config) et des instances de ROOTS doit appartenir au propriétaire de
-- l'expérience (game.CreatorType / game.CreatorId).
-- Long sur toute la place (GetProductInfo est limité en débit) : restreindre ROOTS à un modèle.
-- Le chargement ne se juge pas ici : ContentProvider:PreloadAsync sur un identifiant renvoie
-- Failure même pour des images qui s'affichent (constaté le 23/10/2026). Il se contrôle en Play
-- (console : « not authorized », « not approved ») et sur capture (docs/ASSET_OWNERSHIP.md § 4).
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Instances à parcourir ; {} = configs seules. Ex. { workspace.Bestiaire.Heros }.
local ROOTS: { Instance } = {}
-- Comptes officiels dont l'audio sous licence est utilisable par toutes les expériences.
local LICENSED = { APMOfficial = true, ProSoundEffects = true, Roblox = true }

local PROPS: { [string]: { string } } = {
	MeshPart = { "MeshId", "TextureID" },
	SpecialMesh = { "MeshId", "TextureId" },
	Decal = { "Texture" },
	Texture = { "Texture" },
	ImageLabel = { "Image" },
	ImageButton = { "Image" },
	Sound = { "SoundId" },
	Animation = { "AnimationId" },
	ParticleEmitter = { "Texture" },
	Beam = { "Texture" },
	Trail = { "Texture" },
	SurfaceAppearance = { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" },
	MaterialVariant = { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" },
	Sky = { "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp" },
}

local ownerType = game.CreatorType
local ownerId = game.CreatorId
local refs: { [string]: { string } } = {}

local function add(id: string, where: string)
	refs[id] = refs[id] or {}
	table.insert(refs[id], where)
end

local function idOf(value: string): string?
	return value:match("rbxassetid://(%d+)") or value:match("[?&]id=(%d+)")
end

-- Configs : toute valeur « rbxassetid:// », et les listes Ids de AudioConfig.
local function walk(value: any, path: string, seen: { [any]: boolean })
	if type(value) == "string" then
		local id = idOf(value)
		if id then add(id, path) end
	elseif type(value) == "table" and not seen[value] then
		seen[value] = true
		for key, child in value do
			if key == "Ids" and type(child) == "table" then
				for _, n in child do
					if type(n) == "number" then add(tostring(n), `{path}.Ids`) end
				end
			else
				walk(child, `{path}.{tostring(key)}`, seen)
			end
		end
	end
end

for _, module in ReplicatedStorage.Shared.Config:GetChildren() do
	if module:IsA("ModuleScript") then
		local ok, config = pcall(require, module)
		if ok then walk(config, module.Name, {}) end
	end
end

for _, root in ROOTS do
	local instances = root:GetDescendants()
	table.insert(instances, root) -- la racine peut elle-même être un MeshPart
	for _, d in instances do
		-- Animations publiées : attribut AssetId des KeyframeSequence (docs/ANIMATION_TOOLS.md).
		local assetId = d:IsA("KeyframeSequence") and d:GetAttribute("AssetId")
		if assetId and assetId ~= "" and assetId ~= 0 then add(tostring(assetId), `{d:GetFullName()}@AssetId`) end
		local props = PROPS[d.ClassName]
		if not props then continue end
		for _, prop in props do
			local ok, value = pcall(function() return (d :: any)[prop] end)
			local id = if ok and type(value) == "string" then idOf(value) else nil
			if id then add(id, `{d:GetFullName()}.{prop}`) end
		end
	end
end

local ids = {}
for id in refs do table.insert(ids, id) end
table.sort(ids)

local counts: { [string]: number } = {}
print(`Propriétaire cible : {ownerType.Name} {ownerId} — {#ids} AssetIds`)
print("Statut\tAssetId\tType\tNom\tPropriétaire\tRéférences")
for i, id in ids do
	local status, creator, kind, name = "ERREUR", "?", "?", "?"
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(tonumber(id) :: number, Enum.InfoType.Asset)
	end)
	if ok then
		creator, kind, name = info.Creator.Name, tostring(info.AssetTypeId), info.Name
		local owned = info.Creator.CreatorTargetId == ownerId
			and info.Creator.CreatorType == (if ownerType == Enum.CreatorType.Group then "Group" else "User")
		if owned then
			status = "OK"
		elseif LICENSED[creator] and info.AssetTypeId == Enum.AssetType.Audio.Value then
			status = "TIERS-LICENCE"
		else
			status = "FIX-PROPRIETAIRE"
		end
	end
	counts[status] = (counts[status] or 0) + 1
	local where = refs[id]
	local more = if #where > 1 then ` (+{#where - 1})` else ""
	print(`{status}\t{id}\t{kind}\t{name}\t{creator}\t{where[1]}{more}`)
	if i % 20 == 0 then task.wait() end
end

local fixes = (counts["FIX-PROPRIETAIRE"] or 0) + (counts["ERREUR"] or 0)
local summary = {}
for status, n in counts do table.insert(summary, `{status}={n}`) end
table.sort(summary)
print(`Propriété des assets : {table.concat(summary, " ")} → {if fixes == 0 then "PASS" else "FIX"}`)
return fixes
