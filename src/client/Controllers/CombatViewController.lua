--!strict
-- Retour visuel du combat côté client (voir docs/COMBAT.md) : consomme Remotes.CombatEvent.
--   • barre de PV provisoire au-dessus de chaque unité (placeholder, le design la remplacera) ;
--   • animations : Marche / Attaque / Touche / Mort via MonsterAnimationController, pour les
--     modèles qui portent l'attribut JeuAnimations (sans effet sur les mannequins actuels).
-- Aucune règle de combat ici : PV, morts et résultat viennent uniquement du serveur.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MonsterAnimationController = require(script.Parent.MonsterAnimationController)

local CombatViewController = {}

local RETRY_DELAY = 0.2
local RETRIES = 10

local bars: { [number]: Frame } = {}
local health: { [number]: { current: number, max: number } } = {}

-- Modèle de l'unité dans le dossier de combat du joueur local (attribut UnitId posé par le serveur).
local function findModel(unitId: number): Model?
	local folder = Workspace:FindFirstChild(`PreparationCombat_{Players.LocalPlayer.UserId}`)
	if not folder then
		return nil
	end
	for _, model in folder:GetDescendants() do
		if model:IsA("Model") and model:GetAttribute("UnitId") == unitId then
			return model
		end
	end
	return nil
end

local function refresh(unitId: number)
	local fill = bars[unitId]
	local value = health[unitId]
	if fill and value then
		fill.Size = UDim2.fromScale(math.clamp(value.current / value.max, 0, 1), 1)
	end
end

local function attachBar(unitId: number, team: string, attempt: number)
	local model = findModel(unitId)
	if not model then
		if attempt < RETRIES then
			task.delay(RETRY_DELAY, attachBar, unitId, team, attempt + 1)
		end
		return
	end
	local _, size = model:GetBoundingBox()
	local gui = Instance.new("BillboardGui")
	gui.Name = "BarrePV"
	gui.Size = UDim2.fromOffset(70, 8)
	gui.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 0.4, 0)
	gui.AlwaysOnTop = true
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.new(0, 0, 0)
	back.BackgroundTransparency = 0.3
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = if team == "Ally" then Color3.fromRGB(90, 200, 90) else Color3.fromRGB(220, 80, 70)
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = back
	gui.Parent = model
	bars[unitId] = fill
	refresh(unitId)
end

local function animate(unitId: number?, name: string)
	if not unitId then
		return
	end
	local model = findModel(unitId)
	if model and model:GetAttribute("JeuAnimations") ~= nil then
		MonsterAnimationController.Play(model, name)
	end
end

local function onEvents(_combatId: number, events: { { [string]: any } })
	for _, event in events do
		local kind = event.Type
		if kind == "CombatStarted" then
			table.clear(bars)
			table.clear(health)
		elseif kind == "UnitSpawned" then
			health[event.UnitId] = { current = event.Health, max = event.MaxHealth }
			attachBar(event.UnitId, event.Team, 0)
		elseif kind == "Damage" then
			local value = health[event.TargetId]
			if value then
				value.current = event.Health
				refresh(event.TargetId)
			end
			animate(event.TargetId, "Touche")
		elseif kind == "Attack" then
			animate(event.UnitId, "Attaque")
		elseif kind == "MoveStarted" then
			animate(event.UnitId, "Marche")
		elseif kind == "UnitDied" then
			animate(event.UnitId, "Mort")
			bars[event.UnitId] = nil
			health[event.UnitId] = nil
		end
	end
end

function CombatViewController:Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local events = remotes:WaitForChild("CombatEvent", 30)
	if events and events:IsA("RemoteEvent") then
		events.OnClientEvent:Connect(onEvents)
	end
end

return CombatViewController
