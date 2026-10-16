--!strict
-- Premier spawn d'un nouveau joueur (voir docs/QUESTS.md § Onboarding) : « ça, c'est chez moi ».
-- Quand la quête active est la quête d'accueil (QuestConfig Onboarding = true, SummonStarter), une fois
-- le plot attribué et le personnage posé sur SON PointApparition, le personnage est tourné vers SON
-- arène et la caméra glisse (OnboardingView.Duration) derrière lui, légèrement au-dessus, vers l'arène.
-- Puis la caméra est rendue tout de suite au joueur (Custom, sujet = Humanoid) : rien n'est verrouillé.
-- Une seule fois par session : pas après un reset, une mort, ni pour un profil sorti du tutoriel.
-- La cible est toujours résolue dans le plot du joueur local (PlotView), jamais PlotTravail.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local PlotView = require(script.Parent.Parent.Arena.PlotView)
local OnboardingView = require(script.Parent.Parent.Arena.OnboardingView)

local OnboardingCameraController = {}

local SPAWN_NAME = "PointApparition"
local SPAWN_RADIUS = 25 -- studs : le personnage est bien sur son point d'apparition
local WAIT_SPAWN = 8 -- s au plus pour que le serveur pose le personnage sur son plot

local played = false
local running = false
local view: any = nil

-- Point regardé : centre de l'arène du plot (dalles + front ennemi), sinon la pancarte du stage.
local function arenaTarget(plot: Instance): Vector3?
	local arena = plot:FindFirstChild("Arene")
	if not arena then
		return nil
	end
	if arena:IsA("Model") then
		return arena:GetBoundingBox().Position
	end
	local sign = arena:FindFirstChild("PanneauStage")
	return if sign and sign:IsA("Model") then sign:GetPivot().Position else nil
end

local function spawnOf(plot: Instance): BasePart?
	local spawn = plot:FindFirstChild(SPAWN_NAME)
	return if spawn and spawn:IsA("BasePart") then spawn else nil
end

local function play()
	if running or not OnboardingView.shouldPlay(view, played) then
		return
	end
	running = true
	local player = Players.LocalPlayer
	local deadline = os.clock() + WAIT_SPAWN
	local plot, root, humanoid, spawn
	-- plot attribué, personnage présent ET posé sur son point d'apparition par le serveur
	while os.clock() < deadline do
		plot = PlotView.plot()
		local character = player.Character
		local found = character and character:FindFirstChild("HumanoidRootPart")
		root = if found and found:IsA("BasePart") then found else nil
		humanoid = character and character:FindFirstChildOfClass("Humanoid")
		spawn = if plot then spawnOf(plot) else nil
		if plot and root and humanoid and spawn
			and ((root.Position - spawn.Position) * Vector3.new(1, 0, 1)).Magnitude <= SPAWN_RADIUS
		then
			break
		end
		root = nil
		task.wait(0.1)
	end
	local target = if plot and root then arenaTarget(plot) else nil
	local direction = if root and target then OnboardingView.facing(root.Position, target) else nil
	local camera = Workspace.CurrentCamera
	if not root or not humanoid or not direction or not camera or not OnboardingView.shouldPlay(view, played) then
		running = false
		return
	end
	played = true
	local rootPart = root :: BasePart
	-- personnage face à son arène (déjà le cas si PointApparition est bien orienté)
	rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + direction)
	local eye, look = OnboardingView.frame(rootPart.Position, direction)
	camera.CameraType = Enum.CameraType.Scriptable
	local tween = TweenService:Create(camera, TweenInfo.new(OnboardingView.Duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		CFrame = CFrame.lookAt(eye, look),
	})
	tween:Play()
	tween.Completed:Wait()
	-- la caméra est rendue au joueur, orientée vers son arène
	camera.CameraSubject = humanoid
	camera.CameraType = Enum.CameraType.Custom
	running = false
end

local function setView(next: any)
	view = if typeof(next) == "table" then next else nil
	task.spawn(play)
end

function OnboardingCameraController:Start()
	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("Remotes")
		local changed = remotes:WaitForChild("QuestChanged", 30)
		if changed and changed:IsA("RemoteEvent") then
			changed.OnClientEvent:Connect(setView)
		end
		local get = remotes:WaitForChild("GetActiveQuest", 30)
		if get and get:IsA("RemoteFunction") then
			local ok, current = pcall(get.InvokeServer, get)
			if ok and typeof(current) == "table" then
				setView(current)
			end
		end
	end)
end

return OnboardingCameraController
