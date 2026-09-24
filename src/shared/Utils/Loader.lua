--!strict
-- Charge les ModuleScript d'un dossier, appelle Init() sur tous, puis Start() sur tous.
-- Ordre alphabétique pour que le démarrage soit reproductible.
-- Un module qui plante est signalé sans bloquer les autres.

local Lifecycle = require(script.Parent.Parent.Types.Lifecycle)
local Log = require(script.Parent.Log)

type Module = Lifecycle.Module

export type Entry = {
	name: string,
	module: Module,
}

local Loader = {}

function Loader.loadFolder(folder: Instance, scope: string): { Entry }
	local entries: { Entry } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			local ok, result = pcall(require, child)
			if ok then
				table.insert(entries, { name = child.Name, module = result })
			else
				Log.warn(scope, `Échec du chargement de {child.Name} : {result}`)
			end
		end
	end
	table.sort(entries, function(a: Entry, b: Entry): boolean
		return a.name < b.name
	end)
	return entries
end

function Loader.initAndStart(entries: { Entry }, scope: string)
	for _, entry in entries do
		local init = entry.module.Init
		if init then
			local ok, err = pcall(init, entry.module)
			if not ok then
				Log.warn(scope, `{entry.name}:Init() a échoué : {err}`)
			end
		end
	end

	for _, entry in entries do
		local start = entry.module.Start
		if start then
			task.spawn(function()
				local ok, err = pcall(start, entry.module)
				if not ok then
					Log.warn(scope, `{entry.name}:Start() a échoué : {err}`)
				end
			end)
		end
	end
end

return Loader
