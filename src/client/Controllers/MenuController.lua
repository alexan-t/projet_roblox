--!strict
-- Menu de navigation (MenuView, colonne à gauche) — voir docs/TUTORIAL_GUIDANCE.md.
-- Les entrées viennent de TutorialConfig.Menu.Entries ; chaque View est branchée ici :
--   Bag   : ouvre / ferme la sacoche (HeroBarController), le bouton reste « sélectionné » tant qu'elle est
--           ouverte ;
--   Index : catalogue des héros (CollectionView) : héros possédés avec leur vrai modèle et leur nombre,
--           les autres « ??? » avec un cadenas (aucun spoil) ; « n / total découverts » ;
--   Stats : statistiques du joueur (InfoView), valeurs du serveur (Remotes.GetPlayerStats) ;
--   Soon  : fenêtre « Bientôt disponible » (Boutique, Guilde) : présentée proprement, sans gameplay.
-- Un seul écran modal à la fois (ScreenState "Menu") ; rien ne s'ouvre par-dessus un combat qui finit,
-- une invocation ou un écran de récompense. Badges « ! » : TutorialController.Badge.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HeroConfig = require(ReplicatedStorage.Shared.Config.HeroConfig)
local TutorialConfig = require(ReplicatedStorage.Shared.Config.TutorialConfig)
local ArenaStore = require(script.Parent.Parent.Arena.ArenaStore)
local Icons = require(script.Parent.Parent.UI.Icons)
local ScreenState = require(script.Parent.Parent.UI.ScreenState)
local CollectionView = require(script.Parent.Parent.UI.Views.CollectionView)
local InfoView = require(script.Parent.Parent.UI.Views.InfoView)
local MenuView = require(script.Parent.Parent.UI.Views.MenuView)
local HeroBarController = require(script.Parent.HeroBarController)
local TutorialController = require(script.Parent.TutorialController)

local MenuController = {}

local SCREEN = "Menu"

local entries: { [string]: TutorialConfig.Entry } = {}
local openId: string? = nil -- entrée dont la fenêtre modale est ouverte
local statsRemote: RemoteFunction? = nil

local function refreshSelected()
	MenuView.SetSelected(openId or (if HeroBarController.IsBagOpen() then "Bag" else nil))
end

local function refreshBadges()
	for id, entry in entries do
		MenuView.SetBadge(id, TutorialController.Badge(entry))
	end
end

local function closed()
	openId = nil
	ScreenState.close(SCREEN)
	refreshSelected()
end

-- Ouvre l'écran modal du menu pour `id` ; false si un autre écran est déjà ouvert.
local function claim(id: string): boolean
	if ArenaStore.awaitingResult or not ScreenState.open(SCREEN) then
		return false
	end
	HeroBarController.SetBag(false)
	openId = id
	refreshSelected()
	return true
end

local function showIndex(entry: TutorialConfig.Entry)
	if not claim(entry.Id) then
		return
	end
	local owned: { [string]: number } = {}
	for _, hero in ArenaStore.heroes do
		owned[hero.HeroId] = (owned[hero.HeroId] or 0) + 1
	end
	local catalog: { { id: string, info: HeroConfig.HeroInfo } } = {}
	for heroId, info in HeroConfig.Heroes do
		table.insert(catalog, { id = heroId, info = info })
	end
	-- découverts d'abord (ordre du catalogue), puis les autres
	table.sort(catalog, function(a, b)
		local oa, ob = owned[a.id] ~= nil, owned[b.id] ~= nil
		if oa ~= ob then
			return oa
		end
		return a.info.Order < b.info.Order
	end)
	local list: { CollectionView.HeroEntry } = {}
	local found = 0
	for _, item in catalog do
		local count = owned[item.id]
		if count then
			found += 1
		end
		table.insert(list, {
			Name = item.info.Name,
			Model = if count then Icons.heroModel(item.id) else nil,
			Count = count,
			Locked = count == nil,
		})
	end
	CollectionView.Show(list, {
		Title = "Index des héros",
		Header = `{found} / {#catalog} découverts`,
		Guide = entry.Flag,
		OnClose = closed,
	})
end

local function showStats(entry: TutorialConfig.Entry)
	local remote = statsRemote
	if not remote or not claim(entry.Id) then
		return
	end
	local ok, stats = pcall(remote.InvokeServer, remote)
	if openId ~= entry.Id then
		return -- fermé entre-temps
	end
	if not ok or typeof(stats) ~= "table" then
		closed()
		ArenaStore.toast:Fire("Statistiques indisponibles, réessaie")
		return
	end
	InfoView.Show({
		Title = "Statistiques",
		Icon = entry.Icon,
		Rows = {
			{ Label = "Héros possédés", Value = tostring(stats.Heroes) },
			{ Label = "Héros différents", Value = tostring(stats.UniqueHeroes) },
			{ Label = "Meilleur niveau", Value = `Nv. {stats.HighestLevel}` },
			{ Label = "Stages gagnés", Value = tostring(stats.StagesCleared) },
			{ Label = "Stages Élite gagnés", Value = tostring(stats.EliteCleared) },
			{ Label = "Invocations", Value = tostring(stats.Summons) },
			{ Label = "Niveau du royaume", Value = tostring(stats.KingdomLevel) },
		},
	}, { Guide = entry.Flag, OnClose = closed })
end

local function showSoon(entry: TutorialConfig.Entry)
	if not claim(entry.Id) then
		return
	end
	InfoView.Show({ Title = entry.Label, Icon = entry.Icon, Message = entry.Soon }, { OnClose = closed })
end

local function select(id: string)
	local entry = entries[id]
	if not entry then
		return
	end
	if entry.View == "Bag" then
		if ScreenState.free() then
			HeroBarController.SetBag(not HeroBarController.IsBagOpen())
		end
	elseif entry.View == "Index" then
		showIndex(entry)
	elseif entry.View == "Stats" then
		task.spawn(showStats, entry)
	else
		showSoon(entry)
	end
end

function MenuController:Start()
	local list: { MenuView.Entry } = {}
	for _, entry in TutorialConfig.Menu.Entries do
		entries[entry.Id] = entry
		table.insert(list, { Id = entry.Id, Label = entry.Label, Icon = entry.Icon })
	end
	MenuView.Build(list, select)
	HeroBarController.bagChanged.Event:Connect(refreshSelected)
	TutorialController.changed.Event:Connect(refreshBadges)
	refreshBadges()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local stats = remotes:WaitForChild("GetPlayerStats", 30)
	if stats and stats:IsA("RemoteFunction") then
		statsRemote = stats
	end
end

return MenuController
