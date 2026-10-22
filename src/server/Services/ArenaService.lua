--!strict
-- Une préparation et un monde par propriétaire. Aucun chemin vers la sandbox.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config.ArenaConfig)
local ArenaRules = require(script.Parent.Parent.Arena.ArenaRules)
local ArenaPrep = require(script.Parent.Parent.Arena.ArenaPrep)
local PlotService = require(script.Parent.PlotService)
local HeroService = require(script.Parent.HeroService)
local ZoneService = require(script.Parent.ZoneService)
local CombatService = require(script.Parent.CombatService)
local StageConfig = require(script.Parent.Parent.Config.StageConfig)
local RewardConfig = require(script.Parent.Parent.Config.RewardConfig)
local EliteConfig = require(script.Parent.Parent.Config.EliteConfig)
local HeroProgressionConfig = require(script.Parent.Parent.Config.HeroProgressionConfig)
local StagePreview = require(script.Parent.Parent.Arena.StagePreview)
local ZoneDecor = require(script.Parent.Parent.Arena.ZoneDecor)
local CombatConfig = require(script.Parent.Parent.Config.CombatConfig)
local ArenaService = {}
local manager: ArenaPrep.Manager
local contexts: { [Player]: any } = {}
local worlds: { [Player]: any } = {}
local stateEvent: RemoteEvent
-- Anti-spam par joueur ET par action : « Lancer » d'un autre stage envoie SelectStage puis Ready
-- aussitôt ; seules les répétitions d'une même action sont freinées.
local lastAction: { [Player]: { [string]: number } } = {}
local stateVersion: { [Player]: number } = {}
-- Stage sélectionné (pancarte, fenêtre Expédition) : utilisé au prochain lancement de session. Sans
-- choix, il se déduit de la progression (premier stage débloqué non terminé : 1-2 après le 1-1 au
-- rejoin) ; après une victoire, il passe au stage suivant (1-1 → 1-2 … 1-5, pas de 1-6). Jamais lancé
-- automatiquement : seulement sélectionné / affiché.
-- Le choix porte aussi un MODE ("Normal" / "Elite", #69) ; sans choix (join, rejoin) : Normal. En Élite,
-- la victoire sélectionne le stage Élite suivant (1-1E → 1-2E … 1-5E reste 1-5E).
local chosen: { [Player]: { mode: string, zone: number, stage: number } } = {}
-- Fin de combat : le décor ne change pas pendant l'outro (CombatConfig.Presentation.EndHold), même si la
-- victoire a sélectionné le premier stage de la zone suivante.
local outroUntil: { [Player]: number } = {}

local function chosenOf(player: Player): (number, number, string)
	local c = chosen[player]
	if c then
		return c.zone, c.stage, c.mode
	end
	local zone, stage = ArenaRules.defaultStage(ZoneService:ListStages(player) :: any)
	return zone or Config.Zone, stage or Config.Stage, "Normal"
end

local function context(player: Player): any
	local c = contexts[player]
	if c and PlotService:GetPlot(player) == c.plot and PlotService:GetOwner(c.plot) == player
		and PlotService:GetRuntime(player) == c.runtime and c.arena.Parent == c.plot then return c end
	return nil
end

local function flat(v: Vector3): ArenaRules.Point
	return { x = v.X, z = v.Z }
end

-- Le joueur agit-il réellement depuis SA zone de préparation (et, pour une dalle, à portée) ?
-- Position = celle que le serveur connaît du personnage vivant.
local function canInteract(player: Player, c: any, slot: number?): (boolean, string?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return false, "Approche-toi de ton arène"
	end
	local pose = if slot then c.poses[slot] else nil
	return ArenaRules.canInteract(flat(root.Position), c.zone, if pose then flat(pose.Position) else nil, Config.InteractionDistance)
end

-- Choisir un stage / lancer le combat : depuis sa zone de préparation OU près de SA pancarte.
local function canCommand(player: Player, c: any): (boolean, string?)
	local inZone, why = canInteract(player, c, nil)
	if inZone then
		return true, nil
	end
	local character: any = player.Character
	local root: any = character and character:FindFirstChild("HumanoidRootPart")
	local board: any = c.board
	if root and root:IsA("BasePart") and board and board.Parent then
		local offset = root.Position - board.Position
		if Vector3.new(offset.X, 0, offset.Z).Magnitude <= Config.SignDistance then
			return true, nil
		end
	end
	return false, why
end

-- Sources de l'aperçu des stages (StagePreview) : vraies configs serveur. Butin : aucune table de loot
-- tant que #72 (Loot & Inventaire) n'est pas livrée → PotentialDrops absent, section masquée côté UI.
local PREVIEW_SOURCES = { Rewards = RewardConfig, Progression = HeroProgressionConfig, Elite = EliteConfig }

-- Stages proposés au joueur : état serveur (débloqué / verrouillé / terminé), ennemis agrégés (pancarte)
-- et aperçu de la fenêtre Expédition (vagues, boss, XP par héros, récompenses de stage, Élite), en
-- lecture seule : le client n'en déduit aucune économie.
local function stagesOf(player: Player, mode: string?): { any }
	local list = {}
	for _, entry in ZoneService:ListStages(player, mode) do
		local view: any = { Zone = entry.Zone, Stage = entry.Stage, Mode = entry.Mode, Status = entry.Status, Cleared = entry.Cleared,
			Enemies = if entry.Config then ArenaRules.summarize(entry.Config) else {} }
		if entry.Config then
			for key, value in StagePreview.build(entry.Config, entry.Zone, entry.Stage, entry.Mode, PREVIEW_SOURCES) do
				view[key] = value
			end
		end
		table.insert(list, view)
	end
	return list
end

-- fallbackHeroId : héros dont le modèle de combat dédié manque dans cette place (assets pas encore
-- importés) : son vrai modèle prend sa place, plutôt qu'une case vide.
local function spawnModel(templateName: string, parent: Instance, feet: Vector3, lookAt: Vector3, attributes: any, fallbackHeroId: string?): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local templates = assets and assets:FindFirstChild("Combat")
	local template = templates and templates:FindFirstChild(templateName)
	if not template then
		-- Héros sans modèle de combat dédié : son vrai modèle (copie de HeroService), par HeroId.
		local heroes = assets and assets:FindFirstChild("Heros")
		local heroId = fallbackHeroId or templateName
		for _, candidate in if heroes then heroes:GetChildren() else {} do
			if candidate:GetAttribute("HeroId") == heroId then
				template = candidate
				break
			end
		end
	end
	if not template or not template:IsA("Model") then return nil end
	local model = template:Clone()
	-- Modèle articulé (AnimationController + Motor6D) : seule la racine est ancrée, les membres
	-- restent mobiles pour que les animations jouent. Sinon tout est ancré.
	local rigged = model:FindFirstChildOfClass("AnimationController") ~= nil and model.PrimaryPart ~= nil
	for _, child in model:GetDescendants() do
		if child:IsA("BaseScript") then child:Destroy()
		elseif child:IsA("BasePart") then
			child.Anchored = not rigged or child == model.PrimaryPart
			child.CanCollide, child.CanTouch = false, false
		end
	end
	local box, size = model:GetBoundingBox()
	local pivot = model:GetPivot()
	-- HauteurPieds (attribut du modèle articulé) : hauteur du pivot au-dessus des pieds. Le bas de la
	-- boîte ne convient pas quand l'arme descend sous les pieds (#05, #59) ou pour un héros qui lévite.
	local footHeight = model:GetAttribute("HauteurPieds")
	local position = feet + Vector3.new(0, if typeof(footHeight) == "number" then footHeight else pivot.Position.Y - box.Position.Y + size.Y / 2, 0)
	model:PivotTo(CFrame.lookAt(position, Vector3.new(lookAt.X, position.Y, lookAt.Z)))
	for key, value in attributes or {} do model:SetAttribute(key, value) end
	model.Parent = parent
	return model
end

local function feet(pose: BasePart): Vector3
	return pose.Position - Vector3.new(0, pose.Size.Y / 2 - 0.1, 0)
end

local function stageConfigOf(zone: number, stage: number): any
	local zones = StageConfig.Zones
	local entry = zones and zones[zone]
	return entry and entry.Stages and entry.Stages[stage] or nil
end

local function stateOf(player: Player, message: string?): any
	local prep = manager.preps[player]
	local formation = {}
	if prep then
		for slot, instanceId in prep.formation do
			local hero = HeroService:GetCombatHero(player, instanceId)
			table.insert(formation, { Slot = slot, HeroInstanceId = instanceId, HeroId = if hero then hero.HeroId else nil })
		end
	end
	-- Stage réellement courant (session) ou stage que l'arène lancera ; ennemis agrégés, sans position.
	local session = if prep then ZoneService:GetSession(player) else nil
	local chosenZone, chosenStage, chosenMode = chosenOf(player)
	local zone = if session then session.Zone else chosenZone
	local stageNumber = if session then session.Stage else chosenStage
	local mode = if session then session.Mode else chosenMode
	local stage = if session then session.Config else stageConfigOf(zone, stageNumber)
	-- Numéro croissant par joueur : le client ignore un état plus ancien que celui qu'il a déjà
	-- (la lecture initiale GetArenaState peut arriver après un ArenaState plus récent).
	stateVersion[player] = (stateVersion[player] or 0) + 1
	-- Première vague seule (EnemyId, Count) : ce que le client présente avant Prêt (mise en scène).
	-- Sans position : les cases restent tirées par le moteur au lancement.
	local firstWave = {}
	local wave = stage and stage.Waves and stage.Waves[1]
	for _, group in if wave then wave.Enemies else {} do
		table.insert(firstWave, { EnemyId = group.EnemyId, Count = group.Count })
	end
	return { Version = stateVersion[player], Phase = if prep then prep.phase else "Closed", Formation = formation,
		MaxHeroes = Config.MaxHeroes, Zone = zone, Stage = stageNumber, Mode = mode, FirstWave = firstWave,
		Enemies = if stage then ArenaRules.summarize(stage) else {},
		Stages = stagesOf(player), EliteStages = stagesOf(player, "Elite"), EliteUnlocked = ZoneService:IsEliteUnlocked(player, zone),
		Available = context(player) ~= nil, Message = message }
end

local function send(player: Player, message: string?)
	if player.Parent == Players then stateEvent:FireClient(player, stateOf(player, message)) end
end

local function rebuild(player: Player, w: any, c: any)
	-- Placement (y compris le retour après un combat : l'équipe est reposée, les ennemis retirés).
	w.heroes:ClearAllChildren()
	w.enemies:ClearAllChildren()
	for slot, id in w.prep.formation do
		local hero = HeroService:GetCombatHero(player, id)
		if hero then spawnModel(hero.CombatTemplate, w.heroes, feet(c.poses[slot]), c.front.Position,
			{ HeroClass = hero.CombatProfile, HeroId = hero.HeroId, HeroInstanceId = id, Slot = slot, OwnerUserId = player.UserId }, hero.HeroId) end
	end
end

-- Décor de la zone choisie dans l'arène du joueur (ZoneDecor), hors combat et hors outro seulement.
local function showZone(player: Player)
	local c, prep = context(player), manager.preps[player]
	if not c or (prep and prep.phase ~= "Placement") or os.clock() < (outroUntil[player] or 0) then
		return
	end
	local zone = chosenOf(player)
	if ZoneDecor.current(c.arena) ~= zone and not ZoneDecor.apply(c.arena, zone) then
		warn(`ArenaService : aucun décor pour la zone {zone} dans {c.plot:GetFullName()}`)
	end
	local front = c.arena:FindFirstChild("FrontEnnemi", true)
	if front and front:IsA("BasePart") then c.front = front end
end

local function sync(player: Player)
	showZone(player)
	local prep, c, w = manager.preps[player], context(player), worlds[player]
	if w and (w.prep ~= prep or not c or w.folder.Parent ~= c.runtime) then
		w.folder:Destroy()
		worlds[player], w = nil, nil
	end
	if prep and c and not w then
		local folder = Instance.new("Folder")
		folder.Name = "PreparationCombat"
		folder:SetAttribute("OwnerUserId", player.UserId)
		local heroes, enemies = Instance.new("Folder"), Instance.new("Folder")
		heroes.Name, enemies.Name = "Heros", "Ennemis"
		heroes.Parent, enemies.Parent = folder, folder
		folder.Parent = c.runtime
		w = { prep = prep, folder = folder, heroes = heroes, enemies = enemies }
		worlds[player] = w
	end
	if w and prep.phase == "Placement" then rebuild(player, w, c) end
end

local function startCombat(player: Player, sessionId: number, classes: { [number]: string }): (number?, string?)
	local c, w = context(player), worlds[player]
	if not c or not w then return nil, "arène indisponible" end
	-- Un joueur peut relancer avant la fin de l'outro précédent. Le décor du nouveau combat
	-- doit être prêt même si showZone avait différé le changement pour conserver l'outro.
	local zone = chosenOf(player)
	if not ZoneDecor.apply(c.arena, zone) then return nil, "décor de zone indisponible" end
	local front = c.arena:FindFirstChild("FrontEnnemi", true)
	if not front or not front:IsA("BasePart") then return nil, "repère ennemi indisponible" end
	c.front = front
	outroUntil[player] = nil
	local heroPositions, enemyPositions = {}, {}
	for slot, pose in c.poses do heroPositions[slot] = feet(pose) end
	for cell = 1, 9 do
		local offset = Vector3.new(((cell - 1) % 3 - 1) * c.front.Size.X / 3, -c.front.Size.Y / 2 + 0.1, (1 - (cell - 1) // 3) * c.front.Size.Z / 3)
		enemyPositions[cell] = c.front.CFrame:PointToWorldSpace(offset)
	end
	local formation = table.clone(w.prep.formation)
	-- Roster figé (#68) : exemplaires réellement posés, leur niveau et leurs stats ; seuls eux gagneront
	-- l'XP de ce combat, quoi qu'il arrive ensuite à la hotbar ou à la formation.
	local roster, why = HeroService:GetCombatRoster(player, formation)
	if not roster then return nil, why end
	w.heroes:ClearAllChildren()
	return CombatService:StartCombat(player, sessionId, classes, {
		HeroPositions = heroPositions, EnemyPositions = enemyPositions,
		Roster = roster,
		GrantXP = function(participants: { string }, zone: number, stage: number, mode: string): { any }
			return HeroService:GrantCombatXP(player, participants, zone, stage, mode)
		end,
		SpawnUnit = function(unit, position: Vector3, lookAt: Vector3): Model?
			if context(player) ~= c or worlds[player] ~= w then return nil end
			local ally = unit.Team == "Ally"
			-- Allié : modèle de combat du héros posé sur sa case (HeroConfig.CombatTemplate) ;
			-- unit.TypeId est son profil de combat (stats), pas son HeroId.
			local instanceId = if ally and unit.Slot then formation[unit.Slot] else nil
			local hero = if instanceId then HeroService:GetCombatHero(player, instanceId) else nil
			local template = if ally then (if hero then hero.CombatTemplate else nil) else Config.EnemyTemplates[unit.TypeId]
			return if template then spawnModel(template, if ally then w.heroes else w.enemies, position, lookAt,
				{ OwnerUserId = player.UserId, HeroClass = if ally then unit.TypeId else nil,
					HeroId = if hero then hero.HeroId else nil, HeroInstanceId = instanceId }, if hero then hero.HeroId else nil) else nil
		end,
	})
end

local function cleanup(player: Player)
	manager:leave(player)
	sync(player)
	contexts[player] = nil
end

local function setup(player: Player, plot: Model)
	cleanup(player)
	local runtime = PlotService:GetRuntime(player)
	local arena = plot:FindFirstChild(Config.ArenaName)
	local emplacements = arena and arena:FindFirstChild("Emplacements")
	local heroes = emplacements and emplacements:FindFirstChild("Heros")
	local marker = emplacements and emplacements:FindFirstChild("PointEtendard")
	local front = arena and arena:FindFirstChild("FrontEnnemi", true)
	if not runtime or not heroes or not marker or not marker:IsA("BasePart") or not front or not front:IsA("BasePart") then
		warn(`ArenaService : repères manquants dans {plot:GetFullName()}`)
		return
	end
	local poses = {}
	for _, case in heroes:GetChildren() do
		local slot, pose = case:GetAttribute("Slot"), case:FindFirstChild("PointDePose")
		if ArenaRules.isSlot(slot) and pose and pose:IsA("BasePart") then poses[slot] = pose end
	end
	for slot = 1, 9 do if not poses[slot] then warn(`ArenaService : case {slot} absente`); return end end
	-- Plus de prompt « Combattre » : E sert au placement (prompt local du client sur la dalle la
	-- plus proche) et le combat démarre par le bouton Prêt (ArenaAction "Ready").
	local points = {}
	for slot, pose in poses do
		points[slot] = flat(pose.Position)
	end
	local sign: any = arena:FindFirstChild(Config.SignName)
	local board: any = sign and sign:FindFirstChild(Config.SignBoard)
	contexts[player] = { plot = plot, runtime = runtime, arena = arena, poses = poses, front = front,
		board = if board and board:IsA("BasePart") then board else nil,
		zone = ArenaRules.zone(points, Config.ZoneMargin) }
	showZone(player)
	send(player)
end

function ArenaService:Init()
	manager = ArenaPrep.new({ maxHeroes = Config.MaxHeroes, name = function(p) return p.Name end,
		startStage = function(player)
			local zone, stage, mode = chosenOf(player)
			-- figé au lancement : la fin du combat sait quel stage (et quel mode) vient d'être joué
			chosen[player] = { mode = mode, zone = zone, stage = stage }
			local session, reason = ZoneService:StartStage(player, zone, stage, mode)
			return if session then session.Id else nil, reason
		end,
		sessionAlive = function(player, id)
			local session = ZoneService:GetSession(player)
			return context(player) ~= nil and session ~= nil and session.Id == id
		end,
		cancelStage = function(player) ZoneService:CancelStage(player) end,
		-- Profil de combat (clé de CombatConfig.Heroes) de l'exemplaire, pas son HeroId.
		heroOf = function(player, id)
			local hero, reason = HeroService:GetCombatHero(player, id)
			return if hero then hero.CombatProfile else nil, reason
		end,
		startCombat = startCombat, cancelCombat = function(player) CombatService:CancelCombat(player) end,
	})
end

function ArenaService:Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	stateEvent = Instance.new("RemoteEvent")
	stateEvent.Name, stateEvent.Parent = "ArenaState", remotes
	local get = Instance.new("RemoteFunction")
	get.Name = "GetArenaState"
	get.OnServerInvoke = function(player) return stateOf(player) end
	get.Parent = remotes
	local action = Instance.new("RemoteFunction")
	action.Name = "ArenaAction"
	action.OnServerInvoke = function(player, verb, slot, instanceId, extra)
		local now = os.clock()
		local key = if typeof(verb) == "string" then verb else "?"
		local last = lastAction[player] or {}
		lastAction[player] = last
		if now - (last[key] or -math.huge) < 0.12 then return false, "Patiente un instant" end
		last[key] = now
		local c = context(player)
		if not c then return false, "Ton arène est indisponible" end
		local ok, reason
		-- L'arène visée est toujours celle du plot du joueur (c) : aucune action sur l'arène d'un autre.
		if verb == "Leave" then ok = manager:leave(player) -- abandonner reste possible de partout
		elseif verb == "Ready" then
			-- depuis la zone de préparation ou depuis la pancarte (menu de stage)
			local allowed, why = canCommand(player, c)
			if not allowed then return false, why :: any end
			ok, reason = manager:ready(player)
		elseif verb == "SelectStage" then
			-- Le client n'envoie que deux entiers et un nom de mode (nil = Normal) ; le serveur revérifie que
			-- le stage existe et est débloqué pour ce joueur DANS CE MODE, puis relance la session si des
			-- héros sont déjà posés.
			local zone, stage = slot, instanceId
			local mode = if extra == nil then "Normal" else extra
			if mode ~= "Normal" and mode ~= "Elite" then return false, "mode inconnu" end
			local allowed, why = canCommand(player, c)
			if not allowed then return false, why :: any end
			local entry
			for _, s in ZoneService:ListStages(player, mode) do
				if s.Zone == zone and s.Stage == stage then entry = s end
			end
			if not entry then return false, "stage inconnu" end
			if entry.Status ~= "Unlocked" then
				if mode == "Elite" and not ZoneService:IsEliteUnlocked(player, zone) then
					return false, "Élite verrouillé : termine 1-5"
				end
				return false, if entry.Status == "Locked" then "Stage verrouillé : termine le précédent" else "stage indisponible"
			end
			local previous = chosen[player]
			chosen[player] = { mode = mode, zone = zone, stage = stage }
			ok, reason = manager:restage(player)
			if not ok and reason == "combat déjà lancé" then chosen[player] = previous end
		elseif verb == "Place" or verb == "Remove" then
			if not ArenaRules.isSlot(slot) then return false, "case invalide" end
			local inReach, why = canInteract(player, c, slot)
			if not inReach then return false, why end
			if verb == "Place" then ok, reason = manager:place(player, slot, instanceId)
			else ok, reason = manager:remove(player, slot) end
		else return false, "action inconnue" end
		sync(player)
		send(player)
		return ok, reason, stateOf(player)
	end
	action.Parent = remotes
	PlotService:OnPlotAssigned(setup)
	CombatService:OnCombatEnded(function(player, id, result)
		-- Victoire : le stage suivant (débloqué par le First Clear, déjà enregistré) devient le stage
		-- sélectionné, AVANT la nouvelle session de placement. Jamais relancé automatiquement.
		local prep = manager.preps[player]
		if result == "Victory" and prep and prep.combatId == id then
			local zone, stage, mode = chosenOf(player)
			local nextZone, nextStage = ArenaRules.nextStage(ZoneService:ListStages(player, mode) :: any, zone, stage)
			chosen[player] = { mode = mode, zone = nextZone, stage = nextStage }
		end
		-- Le résultat n'est annoncé que par l'écran de fin (RewardScreenController), pas par un message.
		if manager:combatEnded(player, id) then
			outroUntil[player] = os.clock() + CombatConfig.Presentation.EndHold
			send(player)
			-- Les modèles du combat restent le temps de l'outro du client (morts, sac, « VICTOIRE ! ») ;
			-- l'équipe est ensuite reposée sur ses dalles. Un nouveau combat lancé entre-temps l'emporte.
			task.delay(CombatConfig.Presentation.EndHold, function()
				outroUntil[player] = nil
				local prep = manager.preps[player]
				if prep and prep.phase == "Placement" then
					sync(player)
				else
					showZone(player)
				end
			end)
		end
	end)
	local function watch(player: Player)
		player.CharacterRemoving:Connect(function()
			manager:leave(player); sync(player); send(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do watch(player) end
	Players.PlayerRemoving:Connect(function(player) cleanup(player); lastAction[player] = nil; stateVersion[player] = nil; chosen[player] = nil; outroUntil[player] = nil end)
	task.spawn(function()
		while true do
			task.wait(1)
			for player in contexts do
				if not context(player) then cleanup(player); send(player, "Plot indisponible")
				elseif manager:check(player) then
					CombatService:CancelCombat(player); sync(player); send(player, "Stage terminé")
				end
			end
		end
	end)
end

return ArenaService
