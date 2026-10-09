--!strict
-- Couche sonore minimale (issue #18), côté client : purement présentationnelle.
-- Les sons sont décrits dans ReplicatedStorage.Shared.Config.AudioConfig (identifiants, volumes, garde-fous).
-- Les contrôleurs d'effets appellent AudioController.Play à l'instant de leur effet visuel : le son suit
-- donc le coup visible, en x1 comme en x2, sans aucune règle de jeu ici.
-- Garde-fous contre le spam : délai minimal entre deux lectures d'un même son (Cooldown), nombre maximal
-- de lectures simultanées (Max), légère variation de hauteur (Jitter), variantes tirées au hasard.
-- Sons en 2D (non spatialisés) : la caméra du jeu reste proche de l'action.
-- API : AudioController.Play(name, options?) -> Sound? ; AudioController.StartAmbiance(name) ;
--       AudioController.StopAmbiance().
--   options = { Delay: number? (s), Volume: number? (multiplicateur), Pitch: number? (multiplicateur) }
-- Ambiance : « AmbianceZone1 » démarre au lancement, en boucle et discrète.
-- Studio : attribut Workspace.SonCoupe = true pour couper tous les sons (essais en silence).

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local AudioConfig = require(ReplicatedStorage.Shared.Config.AudioConfig)

local AMBIANCE_FADE = 2 -- s, fondu d'entrée et de sortie de l'ambiance

export type Options = { Delay: number?, Volume: number?, Pitch: number? }

local AudioController = {}

local groups: { [string]: SoundGroup } = {}
local lastPlayed: { [string]: number } = {}
local active: { [string]: number } = {}
local random = Random.new()
local ambiance: Sound? = nil

local function group(name: string): SoundGroup
	local existing = groups[name]
	if existing then
		return existing
	end
	local g = Instance.new("SoundGroup")
	g.Name = "Sons_" .. name
	g.Volume = (AudioConfig.Groups :: any)[name] or 1
	g.Parent = SoundService
	groups[name] = g
	return g
end

local function muted(): boolean
	return Workspace:GetAttribute("SonCoupe") == true
end

local function create(name: string, def: AudioConfig.Sound, options: Options?): Sound
	local opts: Options = options or {}
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = "rbxassetid://" .. tostring(def.Ids[random:NextInteger(1, #def.Ids)])
	sound.Volume = def.Volume * (opts.Volume or 1)
	local jitter = def.Jitter or 0
	sound.PlaybackSpeed = (def.Pitch or 1) * (opts.Pitch or 1) * (1 + random:NextNumber(-jitter, jitter))
	sound.Looped = def.Looped == true
	sound.SoundGroup = group(def.Group)
	sound.Parent = SoundService
	return sound
end

local function playNow(name: string, options: Options?): Sound?
	local def = AudioConfig.Sounds[name]
	if not def then
		warn(`[AudioController] son inconnu : {name}`)
		return nil
	end
	if muted() then
		return nil
	end
	local now = os.clock()
	if def.Cooldown and now - (lastPlayed[name] or -math.huge) < def.Cooldown then
		return nil
	end
	if def.Max and (active[name] or 0) >= def.Max then
		return nil
	end
	lastPlayed[name] = now
	active[name] = (active[name] or 0) + 1
	local sound = create(name, def, options)
	local released = false
	local function release()
		if not released then
			released = true
			active[name] = math.max(0, (active[name] or 1) - 1)
		end
	end
	sound.Ended:Connect(function()
		release()
		sound:Destroy()
	end)
	sound.Destroying:Connect(release)
	sound:Play()
	-- filet de sécurité : un son qui ne se charge pas ne doit pas bloquer Max
	if not sound.Looped then
		task.delay(12, function()
			if sound.Parent then
				sound:Destroy()
			end
		end)
	end
	return sound
end

-- Joue un son de AudioConfig. Avec Delay, le son part plus tard (instant du coup visible) et la
-- fonction renvoie nil.
function AudioController.Play(name: string, options: Options?): Sound?
	local delay = options and options.Delay
	if delay and delay > 0 then
		task.delay(delay, playNow, name, options)
		return nil
	end
	return playNow(name, options)
end

function AudioController.StopAmbiance()
	local current = ambiance
	ambiance = nil
	if current then
		-- fondu de sortie, puis destruction
		local start = current.Volume
		task.spawn(function()
			local t0 = os.clock()
			while current.Parent and os.clock() - t0 < AMBIANCE_FADE do
				current.Volume = start * (1 - (os.clock() - t0) / AMBIANCE_FADE)
				task.wait()
			end
			current:Destroy()
		end)
	end
end

function AudioController.StartAmbiance(name: string)
	AudioController.StopAmbiance()
	local def = AudioConfig.Sounds[name]
	if not def or muted() then
		return
	end
	local sound = create(name, def)
	local target = sound.Volume
	sound.Volume = 0
	sound:Play()
	ambiance = sound
	task.spawn(function()
		local t0 = os.clock()
		while ambiance == sound and os.clock() - t0 < AMBIANCE_FADE do
			sound.Volume = target * (os.clock() - t0) / AMBIANCE_FADE
			task.wait()
		end
		if ambiance == sound then
			sound.Volume = target
		end
	end)
end

function AudioController:Start()
	-- préchargement, pour que le premier coup ne soit pas muet
	task.spawn(function()
		local list: { Instance } = {}
		for name, def in AudioConfig.Sounds do
			for _, id in def.Ids do
				local s = Instance.new("Sound")
				s.Name = name
				s.SoundId = "rbxassetid://" .. tostring(id)
				table.insert(list, s)
			end
		end
		pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
		for _, s in list do
			s:Destroy()
		end
	end)
	AudioController.StartAmbiance("AmbianceZone1")
	Workspace:GetAttributeChangedSignal("SonCoupe"):Connect(function()
		if muted() then
			AudioController.StopAmbiance()
			for _, s in SoundService:GetChildren() do
				if s:IsA("Sound") then
					s:Destroy()
				end
			end
		else
			AudioController.StartAmbiance("AmbianceZone1")
		end
	end)
end

return AudioController
