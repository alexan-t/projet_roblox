--!strict
-- R15 inspecté : position stable devant les mains depuis HumanoidRootPart.
-- Client-only ; aucune collision, aucun Remote, aucune modification du modèle serveur.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HeroConfig = require(ReplicatedStorage.Shared.Config.HeroConfig)
local Store = require(script.Parent.Parent.Arena.ArenaStore)
local PlacementState = require(script.Parent.Parent.Arena.PlacementState)
local PlotView = require(script.Parent.Parent.Arena.PlotView)
local Controller = {}
local preview: Model? = nil
local heldId: string? = nil
local hidden: { [BasePart]: number } = {}

local function restore()
	for part, value in hidden do if part.Parent then part.LocalTransparencyModifier = value end end
	table.clear(hidden)
end
local function clear()
	if preview then preview:Destroy(); preview = nil end
	heldId = nil
	restore()
end
local function render()
	local held = Store.placement.held
	local hero = held and Store.heroes[held.instanceId]
	if not held or not hero or Store.inCombat() then clear(); return end
	if heldId ~= held.instanceId then
		clear()
		-- Même modèle de combat temporaire que l'arène (HeroConfig.CombatTemplate), pas le HeroId.
		local info = HeroConfig.Heroes[hero.HeroId]
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local combat = assets and assets:FindFirstChild("Combat")
		local template = if combat and info then combat:FindFirstChild(info.CombatTemplate) else nil
		if not template or not template:IsA("Model") then return end
		local model = template:Clone()
		model.Name = "HeldHeroPreview"
		model:SetAttribute("HeroInstanceId", held.instanceId)
		for _, item in model:GetDescendants() do
			if item:IsA("BaseScript") then item:Destroy()
			elseif item:IsA("BasePart") then
				item.Anchored, item.CanCollide, item.CanTouch, item.CanQuery = true, false, false, false
			end
		end
		local _, size = model:GetBoundingBox()
		model:ScaleTo(model:GetScale() * 2.6 / math.max(size.X, size.Y, size.Z))
		preview, heldId = model, held.instanceId
		model.Parent = workspace
	end
	restore()
	local world = PlotView.world()
	local heroes = world and world:FindFirstChild("Heros")
	if held.fromSlot and heroes then
		for _, model in heroes:GetChildren() do
			if model:GetAttribute("HeroInstanceId") == held.instanceId then
				for _, part in model:GetDescendants() do
					if part:IsA("BasePart") then hidden[part] = part.LocalTransparencyModifier; part.LocalTransparencyModifier = 1 end
				end
			end
		end
	end
end
function Controller:Start()
	Store.changed.Event:Connect(render)
	local function cancel() PlacementState.cancel(Store.placement); clear(); Store.notify() end
	Players.LocalPlayer.CharacterRemoving:Connect(cancel)
	Players.LocalPlayer.CharacterAdded:Connect(cancel)
	RunService.RenderStepped:Connect(function()
		local model = preview
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if model and root and root:IsA("BasePart") then model:PivotTo(root.CFrame * CFrame.new(0, 0.1, -2.4)) end
	end)
	-- Le serveur peut reconstruire les mannequins après un refus ou une mise à jour.
	workspace.DescendantAdded:Connect(function(item)
		if item:IsA("Model") and item:GetAttribute("HeroInstanceId") == heldId then task.defer(render) end
	end)
	Store.start()
end
return Controller
