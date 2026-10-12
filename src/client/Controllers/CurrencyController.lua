--!strict
-- HUD des monnaies (Gold, Gems, SummonTickets) — CurrencyView, valeurs du serveur uniquement.
-- Le client ne calcule jamais une monnaie : il relit Remotes.GetCurrencies (PlayerStateService)
--   • au join (dès que les données sont chargées) ;
--   • après une invocation (HeroesChanged / HeroObtained : le ticket est déjà débité) ;
--   • à « Continuer » sur l'écran de fin (ArenaPlacementController) : les récompenses sont déjà
--     sauvegardées, le HUD défile alors sous les yeux du joueur.
-- API : CurrencyController.Refresh(animate?)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CurrencyView = require(script.Parent.Parent.UI.Views.CurrencyView)

local CurrencyController = {}

local getRemote: RemoteFunction? = nil
local shown = false

-- Relit les monnaies du serveur et met le HUD à jour. Renvoie false si l'état n'est pas encore disponible.
function CurrencyController.Refresh(animate: boolean?): boolean
	local remote = getRemote
	if not remote then
		return false
	end
	local ok, currencies = pcall(remote.InvokeServer, remote)
	if not ok or typeof(currencies) ~= "table" then
		return false
	end
	CurrencyView.Set(currencies, animate == true and shown)
	shown = true
	return true
end

function CurrencyController:Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local get = remotes:WaitForChild("GetCurrencies", 30)
	if not get or not get:IsA("RemoteFunction") then
		return
	end
	getRemote = get
	for _, name in { "HeroesChanged", "HeroObtained" } do
		local event = remotes:WaitForChild(name, 30)
		if event and event:IsA("RemoteEvent") then
			event.OnClientEvent:Connect(function()
				CurrencyController.Refresh(true)
			end)
		end
	end
	-- Au join : les données peuvent arriver après le client.
	while not CurrencyController.Refresh(false) do
		task.wait(1)
	end
end

return CurrencyController
