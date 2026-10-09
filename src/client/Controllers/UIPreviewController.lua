--!strict
-- Démonstrations Studio des vues d'interface (issue #19), sans serveur ni données réelles.
-- Les vues (src/client/UI/Views) ne contiennent aucune règle : ce contrôleur les alimente avec des
-- états factices pour les voir et les manipuler, en attendant les contrôleurs de #11.
-- Attribut Workspace.ApercuUI (texte), au Play ou à chaud :
--   "Quete"      suivi de quête : progression, puis terminée avec « Récupérer »
--   "Monnaies"   pastilles or / gemmes / tickets, gains animés
--   "Expedition" fenêtre de choix du stage (Lancer joue la transition vers l'arène)
--   "Invocation" interface → Invoquer → reveal du héros (copies de ReplicatedStorage.AtelierInvocation)
--   "Collection" collection des héros (mêmes copies)
--   "Transition" rideau entre deux scènes
--   "Tout"       HUD (quête + monnaies) puis chaque fenêtre à la suite
-- Vide ou absent : rien. Studio uniquement.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local UIKit = require(script.Parent.Parent.UI.UIKit)
local CollectionView = require(script.Parent.Parent.UI.Views.CollectionView)
local CurrencyView = require(script.Parent.Parent.UI.Views.CurrencyView)
local ExpeditionView = require(script.Parent.Parent.UI.Views.ExpeditionView)
local QuestView = require(script.Parent.Parent.UI.Views.QuestView)
local SummonView = require(script.Parent.Parent.UI.Views.SummonView)

local ATTRIBUTE = "ApercuUI"

local UIPreviewController = {}

local generation = 0 -- change à chaque nouvelle démo : les boucles précédentes s'arrêtent

local function alive(id: number): boolean
	return generation == id
end

local function pause(id: number, seconds: number): boolean
	task.wait(seconds)
	return alive(id)
end

-- Héros de démonstration : copies posées dans ReplicatedStorage.AtelierInvocation (jamais le Bestiaire),
-- attributs NomAffiche et Classe (icône) facultatifs.
type DemoHero = { Name: string, Model: Model, ClassId: string? }
local function demoHeroes(): { DemoHero }
	local list: { DemoHero } = {}
	local folder = ReplicatedStorage:FindFirstChild("AtelierInvocation")
	if folder then
		for _, model in folder:GetChildren() do
			if model:IsA("Model") then
				local name = model:GetAttribute("NomAffiche")
				local class = model:GetAttribute("Classe")
				table.insert(list, {
					Name = if typeof(name) == "string" then name else model.Name,
					Model = model,
					ClassId = if typeof(class) == "string" then class else nil,
				})
			end
		end
	end
	return list
end

local function quest(id: number)
	local q = { Title = "Défends ton domaine", Progress = 0, Target = 1, Completed = false }
	QuestView.Show(q)
	while pause(id, 3) do
		q = { Title = q.Title, Progress = 1, Target = 1, Completed = true }
		QuestView.Show(q, {
			OnClaim = function()
				QuestView.Hide()
			end,
		})
		if not pause(id, 5) then
			break
		end
		q = { Title = q.Title, Progress = 0, Target = 1, Completed = false }
		QuestView.Hide()
		if not pause(id, 0.5) then
			break
		end
		QuestView.Show(q)
	end
end

local function currencies(id: number)
	local values = { Gold = 1250, Gems = 40, SummonTickets = 0 }
	CurrencyView.Set(values)
	while pause(id, 2.5) do
		values.Gold += 120
		values.Gems += 15
		values.SummonTickets = (values.SummonTickets + 1) % 4
		CurrencyView.Set(values, true)
	end
end

local function expedition(id: number)
	local open
	open = function()
		if not alive(id) then
			return
		end
		ExpeditionView.Show({
			Zone = 1,
			Title = "Zone 1",
			Stages = {
				{ Stage = 1, Unlocked = true, Cleared = true, Waves = 1, Enemies = { { EnemyId = "Slime", Count = 2 }, { EnemyId = "Gobelin", Count = 4 }, { EnemyId = "Boss", Count = 1, MiniBoss = true } } },
				{ Stage = 2, Unlocked = true, Waves = 2, Enemies = { { EnemyId = "Gobelin", Count = 6 }, { EnemyId = "Boss", Count = 1, MiniBoss = true } } },
				{ Stage = 3, Unlocked = false },
				{ Stage = 4, Unlocked = false },
				{ Stage = 5, Unlocked = false },
			},
		}, {
			OnLaunch = function(zone: number, stage: number)
				UIKit.curtain(`Stage {zone}-{stage}`, nil, 0.8)
				task.delay(1, open)
			end,
			OnClose = function()
				task.delay(1.5, open)
			end,
		})
	end
	open()
end

local function summon(id: number)
	local heroes = demoHeroes()
	local index = 0
	local tickets = 2
	local open
	open = function()
		if not alive(id) then
			return
		end
		SummonView.Show({ Tickets = tickets, Cost = 1 }, {
			OnSummon = function()
				tickets -= 1
				index = index % math.max(#heroes, 1) + 1
				local hero = heroes[index]
				-- l'effet 3D du portail joue pendant ce temps (SummonEffectController) ; ici, simple attente
				task.wait(1.2)
				SummonView.Reveal({ Name = if hero then hero.Name else "Héros", Model = if hero then hero.Model else nil, ClassId = if hero then hero.ClassId else nil, New = index ~= 2 }, {
					OnContinue = function()
						if tickets <= 0 then
							tickets = 3
						end
						task.delay(0.6, open)
					end,
				})
			end,
			OnClose = function()
				task.delay(1.5, open)
			end,
		})
		-- sans ticket : la fenêtre reste ouverte 4 s, puis on en redonne
		if tickets <= 0 then
			task.delay(4, function()
				if alive(id) then
					tickets = 3
					open()
				end
			end)
		end
	end
	open()
end

local function collection(id: number)
	local heroes = demoHeroes()
	local entries = {}
	for i, hero in heroes do
		table.insert(entries, { Name = hero.Name, Model = hero.Model, ClassId = hero.ClassId, Count = if i == 1 then 2 else 1, New = i == #heroes, Equipped = i == 1 })
	end
	local open
	open = function()
		if alive(id) then
			CollectionView.Show(entries, {
				OnClose = function()
					task.delay(1.5, open)
				end,
			})
		end
	end
	open()
end

local function transition(id: number)
	while alive(id) do
		UIKit.curtain("Zone 1 · Stage 1", nil, 0.8)
		if not pause(id, 3) then
			break
		end
	end
end

local function hideAll()
	QuestView.Hide()
	CurrencyView.Hide()
	ExpeditionView.Hide()
	SummonView.Hide()
	CollectionView.Hide()
end

local DEMOS: { [string]: (id: number) -> () } = {
	Quete = quest,
	Monnaies = currencies,
	Expedition = expedition,
	Invocation = summon,
	Collection = collection,
	Transition = transition,
	Tout = function(id: number)
		task.spawn(quest, id)
		task.spawn(currencies, id)
		while alive(id) do
			for _, demo in { expedition, summon, collection } do
				-- chaque fenêtre 8 s, puis la suivante
				task.spawn(demo, id)
				if not pause(id, 8) then
					return
				end
				ExpeditionView.Hide()
				SummonView.Hide()
				CollectionView.Hide()
				if not pause(id, 0.5) then
					return
				end
			end
		end
	end,
}

local function restart()
	generation += 1
	local id = generation
	hideAll()
	local name = Workspace:GetAttribute(ATTRIBUTE)
	local demo = if typeof(name) == "string" then DEMOS[name] else nil
	if demo then
		task.spawn(function()
			task.wait(1)
			if alive(id) then
				demo(id)
			end
		end)
	end
end

function UIPreviewController:Start()
	if not RunService:IsStudio() then
		return
	end
	Workspace:GetAttributeChangedSignal(ATTRIBUTE):Connect(restart)
	restart()
end

return UIPreviewController
