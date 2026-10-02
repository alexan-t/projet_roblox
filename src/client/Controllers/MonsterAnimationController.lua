--!strict
-- Animations des monstres (purement visuelles, côté client).
-- Chaque monstre animé est un Model avec un squelette Motor6D, un AnimationController/Animator,
-- et l'attribut "JeuAnimations" = nom du dossier ReplicatedStorage.Assets.Animations.<JeuAnimations>
-- qui contient ses KeyframeSequence : Attente, Marche, Attaque, Touche, Mort.
--   • Si la KeyframeSequence porte l'attribut "AssetId" (animation publiée), on l'utilise.
--   • Sinon, dans Studio uniquement, on l'enregistre à la volée (aperçu avant publication).
-- Tag "ApercuAnimation" (Model) : démonstration en boucle (Attente, puis Marche, Attaque,
--   Touche et Mort à tour de rôle). Attribut optionnel : ApercuPause (s entre deux actions).
-- API : MonsterAnimationController.Play(model, nom) -> AnimationTrack? ; Stop(model, nom) ;
--   SetTimeScale(vitesse) : vitesse du combat (x1 / x2), appliquée aux animations en cours et suivantes.
-- Attribut ApercuVitesse (nombre, sur le modèle ou son dossier) : vitesse de la démonstration (ex. 2).

local CollectionService = game:GetService("CollectionService")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TAG_APERCU = "ApercuAnimation"
local ACTIONS = { "Marche", "Attaque", "Touche", "Mort" }

local MonsterAnimationController = {}

local tracks: { [Model]: { [string]: AnimationTrack } } = {}
local timeScale = 1
local registered: { [KeyframeSequence]: string } = {}

local function animationId(sequence: KeyframeSequence): string?
	local assetId = sequence:GetAttribute("AssetId")
	if typeof(assetId) == "number" or (typeof(assetId) == "string" and assetId ~= "") then
		return `rbxassetid://{assetId}`
	end
	if not RunService:IsStudio() then
		return nil
	end
	local cached = registered[sequence]
	if cached then
		return cached
	end
	local ok, id = pcall(KeyframeSequenceProvider.RegisterKeyframeSequence, KeyframeSequenceProvider, sequence)
	if not ok then
		warn(`[MonsterAnimation] {sequence:GetFullName()} : {id}`)
		return nil
	end
	registered[sequence] = id
	return id
end

local function load(model: Model): { [string]: AnimationTrack }?
	local existing = tracks[model]
	if existing then
		return existing
	end
	local setName = model:GetAttribute("JeuAnimations")
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local animations = assets and assets:FindFirstChild("Animations")
	local folder = if typeof(setName) == "string" and animations then animations:FindFirstChild(setName) else nil
	local controller = model:FindFirstChildOfClass("AnimationController")
	local animator = controller and controller:FindFirstChildOfClass("Animator")
	if not folder or not animator then
		return nil
	end
	local loaded: { [string]: AnimationTrack } = {}
	for _, sequence in folder:GetChildren() do
		if sequence:IsA("KeyframeSequence") then
			local id = animationId(sequence)
			if id then
				local animation = Instance.new("Animation")
				animation.AnimationId = id
				local track = (animator :: Animator):LoadAnimation(animation)
				track.Looped = sequence.Loop
				loaded[sequence.Name] = track
			end
		end
	end
	tracks[model] = loaded
	return loaded
end

function MonsterAnimationController.Play(model: Model, name: string, fadeTime: number?): AnimationTrack?
	local loaded = load(model)
	local track = loaded and loaded[name]
	if track then
		track:Play(fadeTime or 0.15)
		track:AdjustSpeed(timeScale)
	end
	return track
end

function MonsterAnimationController.Stop(model: Model, name: string, fadeTime: number?)
	local loaded = tracks[model]
	local track = loaded and loaded[name]
	if track and track.IsPlaying then
		track:Stop(fadeTime or 0.2)
	end
end

-- Vitesse du combat : x2 joue toutes les animations deux fois plus vite, comme la simulation.
function MonsterAnimationController.SetTimeScale(scale: number)
	timeScale = scale
	for model, loaded in tracks do
		if not model.Parent then
			tracks[model] = nil
			continue
		end
		for _, track in loaded do
			if track.IsPlaying and track.Speed ~= 0 then
				track:AdjustSpeed(scale)
			end
		end
	end
end

local function demoSpeed(model: Model): number
	local value = model:GetAttribute("ApercuVitesse")
	if typeof(value) ~= "number" and model.Parent then
		value = model.Parent:GetAttribute("ApercuVitesse")
	end
	return if typeof(value) == "number" and value > 0 then value else 1
end

local function runDemo(model: Model)
	local loaded = load(model)
	if not loaded then
		warn(`[MonsterAnimation] {model:GetFullName()} : squelette ou animations introuvables`)
		return
	end
	local idle = loaded.Attente
	if idle then
		idle:Play(0.2)
		idle:AdjustSpeed(demoSpeed(model))
	end
	local index = 0
	while model.Parent and CollectionService:HasTag(model, TAG_APERCU) do
		local pause = model:GetAttribute("ApercuPause")
		task.wait(if typeof(pause) == "number" then pause else 2.5)
		local speed = demoSpeed(model)
		if idle then
			idle:AdjustSpeed(speed) -- suit un changement d'ApercuVitesse pendant la démonstration
		end
		index = index % #ACTIONS + 1
		local name = ACTIONS[index]
		local track = loaded[name]
		if track then
			track:Play(0.15)
			track:AdjustSpeed(speed)
			if name == "Marche" then
				task.wait(2.4)
				track:Stop(0.3)
			elseif name == "Mort" then
				-- rester au sol un moment, puis se relever
				task.wait(track.Length / speed - 0.05)
				track:AdjustSpeed(0)
				task.wait(1.5)
				track:Stop(0.5)
			else
				task.wait(track.Length / speed)
			end
		end
	end
	for _, track in loaded do
		track:Stop(0.2)
	end
end

function MonsterAnimationController:Start()
	for _, model in CollectionService:GetTagged(TAG_APERCU) do
		if model:IsA("Model") then
			task.spawn(runDemo, model)
		end
	end
	CollectionService:GetInstanceAddedSignal(TAG_APERCU):Connect(function(model)
		if model:IsA("Model") then
			task.spawn(runDemo, model)
		end
	end)
end

return MonsterAnimationController
