--!strict
-- Drapeaux « vu une fois » du guidage du tutoriel (voir docs/TUTORIAL_GUIDANCE.md).
-- Le client montre le guidage (TutorialController) ; le serveur garde seulement la mémoire de ce qui a
-- déjà été vu, dans PlayerData.Tutorial.Seen (ajouté aux anciens profils par Reconcile).
-- Remotes :
--   GetTutorialSeen (RemoteFunction) -> { [drapeau]: true } (copie des drapeaux connus), ou nil
--                                       (données pas encore chargées) ;
--   MarkTutorialSeen (RemoteEvent, drapeau) : enregistre un drapeau de TutorialConfig.Flags. Drapeau
--                                       inconnu, déjà vu ou envoyé trop vite : ignoré. Aucun effet de jeu.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TutorialConfig = require(ReplicatedStorage.Shared.Config.TutorialConfig)
local TutorialRules = require(ReplicatedStorage.Shared.Tutorial.TutorialRules)
local DataService = require(script.Parent.DataService)

local TutorialService = {}

local MIN_INTERVAL = 0.2 -- s entre deux enregistrements d'un même joueur

local lastMark: { [Player]: number } = {}

local function seenOf(player: Player): { [string]: boolean }?
	local data: any = if player:GetAttribute("DataLoaded") == true then DataService:GetData(player) else nil
	if not data then
		return nil
	end
	if typeof(data.Tutorial) ~= "table" then
		data.Tutorial = { Seen = {} }
	end
	if typeof(data.Tutorial.Seen) ~= "table" then
		data.Tutorial.Seen = {}
	end
	return data.Tutorial.Seen
end

function TutorialService:GetSeen(player: Player): { [string]: boolean }?
	local seen = seenOf(player)
	return if seen then TutorialRules.view(TutorialConfig, seen) else nil
end

-- true si le drapeau vient d'être enregistré.
function TutorialService:MarkSeen(player: Player, key: any): boolean
	local now = os.clock()
	local last = lastMark[player]
	if last and now - last < MIN_INTERVAL then
		return false
	end
	local seen = seenOf(player)
	if not seen then
		return false
	end
	lastMark[player] = now
	return TutorialRules.mark(TutorialConfig, seen, key)
end

function TutorialService:Forget(player: Player)
	lastMark[player] = nil
end

function TutorialService:Start()
	local problems = TutorialRules.problems(TutorialConfig)
	assert(#problems == 0, "TutorialConfig invalide : " .. table.concat(problems, " ; "))
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end
	assert(remotes)
	local get = Instance.new("RemoteFunction")
	get.Name = "GetTutorialSeen"
	get.OnServerInvoke = function(player: Player): { [string]: boolean }?
		return TutorialService:GetSeen(player)
	end
	get.Parent = remotes
	local mark = Instance.new("RemoteEvent")
	mark.Name = "MarkTutorialSeen"
	mark.OnServerEvent:Connect(function(player: Player, key: any)
		TutorialService:MarkSeen(player, key)
	end)
	mark.Parent = remotes
	game:GetService("Players").PlayerRemoving:Connect(function(player: Player)
		TutorialService:Forget(player)
	end)
end

return TutorialService
