--!strict
-- À exécuter en EDIT ou en Play (barre de commande) : lecture seule, ne modifie rien.
-- Précharge toutes les images de MenuIconConfig et indique celles que l'expérience ne peut pas lire
-- (« User is not authorized to access Asset » → Failure). Voir docs/ZONES_QA.md § Reprise.
local ContentProvider = game:GetService("ContentProvider")
local config = require(game.ReplicatedStorage.Shared.Config.MenuIconConfig)

local entries: { { name: string, id: string } } = { { name = "Badge", id = config.Badge } }
for button, icons in config.Buttons do
	table.insert(entries, { name = `{button}.Icon`, id = icons.Icon })
	table.insert(entries, { name = `{button}.BadgeIcon`, id = icons.BadgeIcon })
end
table.sort(entries, function(a, b) return a.name < b.name end)

local failures = {}
for _, entry in entries do
	if entry.id == "" then continue end
	local status: Enum.AssetFetchStatus? = nil
	ContentProvider:PreloadAsync({ entry.id }, function(_content: string, result: Enum.AssetFetchStatus)
		status = result
	end)
	local ok = status == Enum.AssetFetchStatus.Success
	print(`{if ok then "OK  " else "KO  "} {entry.name} {entry.id} ({status})`)
	if not ok then table.insert(failures, entry.id) end
end
print(`Images du menu : {#entries - #failures}/{#entries} lisibles`)
return #failures
