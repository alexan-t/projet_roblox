--!strict
-- Résolution visuelle seulement. Le serveur utilise PlotService et ignore cette sélection.
local Players = game:GetService("Players")
local PlotView = {}
function PlotView.plot(): Instance?
	local lobby = workspace:FindFirstChild("Lobby")
	local plots = lobby and lobby:FindFirstChild("Plots")
	if plots then
		for _, plot in plots:GetChildren() do
			if plot:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId then return plot end
		end
	end
	return nil
end
function PlotView.arena(): Instance?
	local plot = PlotView.plot()
	return plot and plot:FindFirstChild("Arene")
end
function PlotView.world(): Instance?
	local plot = PlotView.plot()
	local runtime = plot and plot:FindFirstChild("Runtime")
	return runtime and runtime:FindFirstChild("PreparationCombat")
end
return PlotView
