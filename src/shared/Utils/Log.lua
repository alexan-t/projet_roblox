--!strict
-- Logs préfixés par le côté (Serveur/Client) et un scope, ex. "[Serveur][Bootstrap] ...".
-- Log.debug n'affiche rien si GameConfig.Debug vaut false.

local RunService = game:GetService("RunService")

local GameConfig = require(script.Parent.Parent.Config.GameConfig)

local SIDE = if RunService:IsServer() then "Serveur" else "Client"

local Log = {}

local function format(scope: string, message: string): string
	return `[{SIDE}][{scope}] {message}`
end

function Log.info(scope: string, message: string)
	print(format(scope, message))
end

function Log.warn(scope: string, message: string)
	warn(format(scope, message))
end

function Log.debug(scope: string, message: string)
	if GameConfig.Debug then
		print(format(scope, message))
	end
end

return Log
