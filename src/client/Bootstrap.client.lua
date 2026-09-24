--!strict
-- Point d'entrée client : charge chaque ModuleScript du dossier Controllers,
-- appelle Init() sur tous, puis Start() sur tous.
-- Pour ajouter un contrôleur : créer src/client/Controllers/<Nom>Controller.lua
-- qui retourne une table avec Init() et/ou Start() (les deux sont optionnels).

local controllersFolder = script.Parent:WaitForChild("Controllers")

type Controller = {
	Init: ((self: Controller) -> ())?,
	Start: ((self: Controller) -> ())?,
}

local controllers: { [string]: Controller } = {}

for _, module in controllersFolder:GetChildren() do
	if module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok then
			controllers[module.Name] = result
		else
			warn(`[Bootstrap] Échec du chargement de {module.Name} : {result}`)
		end
	end
end

for name, controller in controllers do
	if controller.Init then
		local ok, err = pcall(controller.Init, controller)
		if not ok then
			warn(`[Bootstrap] {name}:Init() a échoué : {err}`)
		end
	end
end

for name, controller in controllers do
	if controller.Start then
		task.spawn(function()
			local ok, err = pcall(controller.Start, controller)
			if not ok then
				warn(`[Bootstrap] {name}:Start() a échoué : {err}`)
			end
		end)
	end
end
