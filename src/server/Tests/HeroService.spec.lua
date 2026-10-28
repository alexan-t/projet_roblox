--!strict
-- Hors du dossier Services : jamais exécuté par le bootstrap.
-- Exécute le vrai HeroService (invocation tutorielle, invocation, HeroObtained, copie client des modèles)
-- avec les vraies HeroConfig, SummonConfig, CombatConfig, HeroRules et SummonRules, et des doubles de
-- DataService, PlotService, KingdomService, QuestService et des API Roblox utilisées.
-- env.player(name) = profil existant (Écuyer déjà possédé en raccourci 1, tutoriel fini, comme un profil
-- v2 migré) ; env.player(name, { fresh = true }) = nouveau profil (0 héros, quête SummonStarter active).

return function(createService: any, modules: any)
	local passed, failed = 0, 0
	local function test(name: string, run: () -> ())
		local ok, err = pcall(run)
		if ok then
			passed += 1
			print("PASS " .. name)
		else
			failed += 1
			print("FAIL " .. name .. ": " .. tostring(err))
		end
	end

	local SummonConfig = modules.SummonConfig
	local HeroConfig = modules.HeroConfig

	local function vector(x: number, y: number, z: number): any
		return setmetatable({ X = x, Y = y, Z = z }, {
			__sub = function(a: any, b: any): any return vector(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end,
			__index = function(v: any, key: string): any
				if key == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
				return nil
			end,
		})
	end

	-- Instance générique : enfants, attributs, classe. Affecter Parent range l'objet dans les
	-- enfants du parent, comme le moteur.
	local function inst(className: string, name: string?, props: any?): any
		local i: any = { ClassName = className, Name = name or className, children = {}, attributes = {} }
		for k, v in props or {} do i[k] = v end
		local proxy = setmetatable({}, {
			__index = i,
			__newindex = function(t: any, k: string, v: any)
				i[k] = v
				if k == "Parent" and typeof(v) == "table" and v.children and not table.find(v.children, t) then
					table.insert(v.children, t)
				end
			end,
		})
		function i:IsA(c: string): boolean
			if c == "BasePart" then return self.ClassName == "Part" or self.ClassName == "MeshPart" end
			if c == "LuaSourceContainer" then return self.ClassName == "Script" or self.ClassName == "LocalScript" or self.ClassName == "ModuleScript" end
			return self.ClassName == c
		end
		function i:FindFirstChild(n: string): any
			for _, c in self.children do if c.Name == n and c.Parent == self then return c end end
			return nil
		end
		function i:FindFirstChildOfClass(c: string): any
			for _, child in self.children do if child.ClassName == c and child.Parent == self then return child end end
			return nil
		end
		function i:GetChildren(): { any }
			local out = {}
			for _, c in self.children do if c.Parent == self then table.insert(out, c) end end
			return out
		end
		function i:GetDescendants(): { any }
			local out = {}
			for _, c in self:GetChildren() do
				table.insert(out, c)
				for _, d in c:GetDescendants() do table.insert(out, d) end
			end
			return out
		end
		function i:GetAttribute(k: string): any return self.attributes[k] end
		function i:SetAttribute(k: string, v: any) self.attributes[k] = v end
		function i:Destroy() self.Parent = nil end
		function i:add(child: any): any child.Parent = self; return child end
		return proxy
	end

	local function model(heroId: string?, name: string, scripts: boolean?): any
		local m = inst("Model", name)
		if heroId then m.attributes.HeroId = heroId end
		m:add(inst("MeshPart", "torso_geom", { Anchored = true, CanCollide = true, CanTouch = true, CanQuery = true }))
		if scripts then m:add(inst("Script", "Parasite")) end
		function m:Clone(): any
			local copy = model(self.attributes.HeroId, self.Name, false)
			copy.children = {}
			for _, c in self:GetChildren() do
				local cc = inst(c.ClassName, c.Name, { Anchored = c.Anchored, CanCollide = c.CanCollide, CanTouch = c.CanTouch, CanQuery = c.CanQuery })
				copy:add(cc)
			end
			for k, v in self.attributes do copy.attributes[k] = v end
			return copy
		end
		return m
	end

	local function fixture(options: any?): any
		options = options or {}
		local env: any = { data = {}, plots = {}, fired = {}, refreshed = {}, warnings = {}, ready = {}, removing = {} }
		env.players = { PlayerRemoving = { Connect = function(_s: any, fn: any) table.insert(env.removing, fn) end } }
		local replicated = inst("Folder", "ReplicatedStorage")
		replicated.Shared = { Utils = { Log = { debug = function() end, info = function() end,
			warn = function(_s: string, m: string) table.insert(env.warnings, m) end } },
			Config = { HeroConfig = HeroConfig, RarityConfig = modules.RarityConfig, SummonBannerConfig = modules.SummonBannerConfig, ItemConfig = modules.ItemConfig } }
		env.replicated = replicated
		-- ServerStorage.Assets.Heros : modèles réels (dont un avec script parasite) + un héros d'un
		-- autre format qui ne doit jamais être copié.
		local server = inst("Folder", "ServerStorage")
		local assets = server:add(inst("Folder", "Assets"))
		local heroes = assets:add(inst("Folder", "Heros"))
		heroes:add(model("ecuyer_du_rempart", "EcuyerDuRempart", true))
		heroes:add(model("tireuse_des_faubourgs", "TireuseDesFaubourgs"))
		heroes:add(model("barde_de_fer", "BardeDeFer"))
		heroes:add(model(nil, "Heros_BriseBraise"))
		env.serverHeroes = heroes
		if options.noAssets then server.children = {} end
		env.game = { GetService = function(_s: any, n: string): any
			return ({ Players = env.players, ReplicatedStorage = replicated, ServerStorage = server,
				HttpService = { GenerateGUID = function(): string
					if env.failGuid then error("GenerateGUID indisponible") end
					local hook: any = env.onGuid
					if hook ~= nil then (hook :: any)() end
					env.guid = (env.guid or 0) + 1
					return string.format("%08d", env.guid)
				end } })[n]
		end }
		env.Instance = { new = function(className: string): any
			local i = inst(className)
			if className == "RemoteEvent" then
				i.FireClient = function(self: any, player: any, payload: any)
					table.insert(env.fired, { remote = self.Name, player = player, payload = payload })
				end
			end
			return i
		end }
		env.Random = { new = function(): any
			return { NextInteger = function(_s: any, a: number, b: number): number
				env.roll = ((env.roll or 0) % (b - a + 1)) + 1
				return a + env.roll - 1
			end }
		end }
		env.Vector3 = { new = vector }
		env.task = { spawn = function(fn: any, ...: any) fn(...) end }

		local dataService: any = {}
		function dataService:GetData(p: any): any return env.data[p] end
		function dataService:OnPlayerReady(fn: any) table.insert(env.ready, fn) end
		local plotService: any = {}
		function plotService:GetPlot(p: any): any return env.plots[p] end
		-- Quête active par joueur (Id) ; StarterHeroSummoned fait passer SummonStarter -> DefendDomain,
		-- comme le vrai QuestService (AutoClaim).
		env.quest, env.questEvents = {}, {}
		local questService: any = {}
		function questService:GetActiveQuest(p: any): any
			local id = env.quest[p]
			return if id then { Id = id, Completed = false } else nil
		end
		-- objectifs d'état (« avoir N héros ») : relus après chaque changement de collection
		env.questSyncs = 0
		function questService:SyncState(_p: any): boolean
			env.questSyncs += 1
			return false
		end
		function questService:HandleGameplayEvent(p: any, name: string, payload: any?): boolean
			table.insert(env.questEvents, { player = p, name = name, payload = payload })
			if name == SummonConfig.Starter.Event and env.quest[p] == SummonConfig.Starter.QuestId then
				env.quest[p] = "DefendDomain"
				return true
			end
			return false
		end
		local kingdomService: any = {}
		function kingdomService:Refresh(p: any): boolean
			table.insert(env.refreshed, { player = p, visual = env.data[p] and env.data[p].Kingdom.VisualState })
			local hook: any = env.onRefresh
			if hook ~= nil then (hook :: any)(p) end
			return true
		end
		env.script = { Parent = { DataService = dataService, PlotService = plotService, KingdomService = kingdomService, QuestService = questService,
			Parent = { Config = { CombatConfig = modules.CombatConfig, SummonConfig = SummonConfig, HeroProgressionConfig = modules.HeroProgressionConfig, EquipmentConfig = modules.EquipmentConfig },
				Heroes = { HeroRules = modules.HeroRules, SummonRules = modules.SummonRules, HeroProgressionRules = modules.HeroProgressionRules },
				Inventory = { EquipmentRules = modules.EquipmentRules } } } }
		env.require = function(m: any): any return m end

		-- Plot avec portail : pivot du portail = position donnée.
		function env.plot(name: string, portalAt: any): any
			local plot = inst("Model", name)
			local portal = plot:add(inst("Model", SummonConfig.PortalName))
			function portal:GetPivot(): any return { Position = portalAt } end
			return plot
		end
		function env.player(name: string, opts: any?): any
			opts = opts or {}
			local p: any = inst("Player", name)
			p.Parent = env.players
			p.attributes.DataLoaded = true
			local character = inst("Model", name)
			character:add(inst("Part", "HumanoidRootPart", { Position = opts.at or vector(0, 3, 0) }))
			character:add(inst("Humanoid", "Humanoid", { Health = 100 }))
			p.Character = character
			env.data[p] = {
				DataVersion = 4,
				Currencies = { Gold = 0, Gems = 0, SummonTickets = opts.tickets or 0 },
				Progression = { CurrentZone = 1, HighestStage = 0, FirstClears = {} },
				Heroes = {}, Team = {}, Hotbar = table.create(HeroConfig.HotbarSize, ""),
				Summons = { Total = 0 },
				Kingdom = { Level = 1, VisualState = 1 },
				Quests = {}, Settings = { CombatSpeed = 1 },
			}
			if opts.fresh then
				env.quest[p] = SummonConfig.Starter.QuestId
			else
				-- profil existant : l'Écuyer reçu avant la refonte (identifiant horodaté le plus ancien)
				local id = string.format("H_T%010d%04d_%s", 1, 0, "ecuyer" .. name)
				env.data[p].Heroes[id] = { HeroId = "ecuyer_du_rempart", Level = 1, XP = 0 }
				env.data[p].Hotbar[1] = id
				env.quest[p] = "DefendDomain"
			end
			env.plots[p] = env.plot("Plot_" .. name, opts.portal or vector(0, 3, 0))
			for _, fn in env.ready do fn(p, env.data[p]) end
			return p
		end
		function env.moveTo(p: any, at: any) p.Character:FindFirstChild("HumanoidRootPart").Position = at end
		function env.start(): any
			env.service = createService(env)
			env.service:Init()
			env.service:Start()
			return env.service
		end
		function env.remote(name: string): any
			for _, folder in replicated:GetChildren() do
				if folder.Name == "Remotes" then return folder:FindFirstChild(name) end
			end
			return nil
		end
		function env.events(p: any, remote: string): { any }
			local out = {}
			for _, e in env.fired do if e.player == p and e.remote == remote then table.insert(out, e.payload) end end
			return out
		end
		function env.heroIds(p: any): { [string]: string }
			local out = {}
			for id, hero in env.data[p].Heroes do out[id] = hero.HeroId end
			return out
		end
		return env
	end
	local function count(t: any): number
		local n = 0
		for _ in t do n += 1 end
		return n
	end

	test("fresh profile has zero heroes: empty hotbar and team, nothing granted at join or rejoin", function()
		local e = fixture()
		e.start()
		local p = e.player("A", { fresh = true })
		local d = e.data[p]
		assert(count(d.Heroes) == 0 and #d.Team == 0)
		for i = 1, HeroConfig.HotbarSize do assert(d.Hotbar[i] == "") end
		assert(d.Currencies.SummonTickets == 0 and d.Summons.Total == 0 and d.Kingdom.VisualState == 1)
		assert(#e.refreshed == 0, "no kingdom change at join")
		assert(#e.events(p, "HeroesChanged") == 1, "empty collection pushed")
		for _, fn in e.ready do fn(p, d) end
		assert(count(d.Heroes) == 0, "rejoin: still nothing for free")
	end)

	test("tutorial summon grants exactly one Ecuyer: shortcut 1, HeroesChanged, HeroObtained, quest event", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A", { fresh = true })
		local got, reason = s:RequestStarterSummon(p)
		assert(got and reason == nil, tostring(reason))
		local d = e.data[p]
		assert(count(d.Heroes) == 1 and d.Heroes[got.InstanceId].HeroId == "ecuyer_du_rempart" and d.Hotbar[1] == got.InstanceId)
		assert(got.HeroId == "ecuyer_du_rempart" and got.New == true and got.Name == HeroConfig.Heroes.ecuyer_du_rempart.Name)
		assert(got.Rarity == HeroConfig.Heroes.ecuyer_du_rempart.Rarity)
		assert(#e.refreshed == 1, "kingdom refreshed (its hero appears)")
		assert(#e.events(p, "HeroesChanged") == 2 and #e.events(p, "HeroObtained") == 1)
		assert(#e.questEvents == 1 and e.questEvents[1].name == "StarterHeroSummoned" and e.questEvents[1].player == p)
		assert(e.quest[p] == "DefendDomain", "quest chain moved on")
	end)

	test("tutorial summon costs zero: no ticket used, Summons.Total stays 0, kingdom stays 1", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A", { fresh = true, tickets = 2 })
		assert(s:RequestStarterSummon(p))
		local d = e.data[p]
		assert(d.Currencies.SummonTickets == 2, "tickets untouched")
		assert(d.Summons.Total == 0, "not counted as the first real summon")
		assert(d.Kingdom.VisualState == 1 and d.Kingdom.Level == 1, "no artificial kingdom 1 -> 2")
		assert(d.Currencies.Gold == 0 and d.Currencies.Gems == 0)
	end)

	test("tutorial summon cannot run twice (20 requests, rejoin, quest already done, Ecuyer owned)", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A", { fresh = true })
		local invoke = e.remote("RequestStarterSummon").OnServerInvoke
		local ok = 0
		for _ = 1, 20 do if invoke(p) == true then ok += 1 end end
		assert(ok == 1 and count(e.data[p].Heroes) == 1 and #e.events(p, "HeroObtained") == 1)
		for _, fn in e.ready do fn(p, e.data[p]) end
		local again, why = s:RequestStarterSummon(p)
		assert(again == nil and why == "invocation gratuite indisponible", "quest over")
		-- quête encore active (état forcé) mais Écuyer déjà possédé : refusé par la règle elle-même
		e.quest[p] = SummonConfig.Starter.QuestId
		local third, why3 = s:RequestStarterSummon(p)
		assert(third == nil and why3 == "premier héros déjà obtenu" and count(e.data[p].Heroes) == 1)
		-- un ancien joueur (Écuyer possédé, tutoriel passé) n'a jamais d'Écuyer gratuit
		local old = e.player("B")
		assert(s:RequestStarterSummon(old) == nil and count(e.data[old].Heroes) == 1)
	end)

	test("tutorial summon refusals: far from the portal, another player's portal, no plot, data not loaded, re-entrant", function()
		local e = fixture()
		local s = e.start()
		local a = e.player("A", { fresh = true })
		local b = e.player("B", { fresh = true, portal = vector(300, 3, 0), at = vector(300, 3, 0) })
		e.moveTo(a, vector(300, 3, 0)) -- A devant le portail de B
		local none, why = s:RequestStarterSummon(a)
		assert(none == nil and why == "approche-toi de ton portail")
		e.moveTo(a, vector(0, 3, 0))
		e.plots[a] = nil
		assert(select(2, s:RequestStarterSummon(a)) == "aucun portail")
		e.plots[a] = e.plot("Plot_A", vector(0, 3, 0))
		a.attributes.DataLoaded = nil
		assert(select(2, s:RequestStarterSummon(a)) == "données non chargées")
		a.attributes.DataLoaded = true
		local reentrant: any = nil
		e.onRefresh = function(pl: any)
			if pl == a and reentrant == nil then reentrant = { s:RequestStarterSummon(a) } end
		end
		assert(s:RequestStarterSummon(a))
		assert(reentrant and reentrant[1] == nil, "a request during the commit is refused")
		assert(count(e.data[a].Heroes) == 1 and count(e.data[b].Heroes) == 0, "B untouched")
		assert(s:RequestStarterSummon(b), "B summons at its own portal")
	end)

	test("tutorial then first paid summon: rolled (whatever the RNG gives), Summons.Total = 1, kingdom 1 -> 2", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A", { fresh = true })
		assert(s:RequestStarterSummon(p))
		local refused, why = s:RequestSummon(p)
		assert(refused == nil and why == "pas de ticket d'invocation", "0 ticket after the tutorial")
		e.data[p].Currencies.SummonTickets = 1 -- First Clear 1-1
		local got = s:RequestSummon(p)
		local d = e.data[p]
		assert(SummonConfig.FirstSummon == nil, "no guaranteed hero any more")
		assert(got and HeroConfig.Heroes[got.HeroId], "a real hero from the pool")
		assert(d.Summons.Total == 1 and d.Currencies.SummonTickets == 0 and d.Kingdom.VisualState == 2, "first paid summon still evolves the kingdom")
		assert(count(d.Heroes) == 2 and d.Hotbar[2] == got.InstanceId)
	end)

	test("GetSummonState: Starter presentation (Active, server HeroId / Name / Rarity) only during the tutorial", function()
		local e = fixture()
		local s = e.start()
		local get = e.remote("GetSummonState").OnServerInvoke
		local p = e.player("A", { fresh = true })
		local starter = get(p).Starter
		local info = HeroConfig.Heroes[SummonConfig.Starter.HeroId]
		assert(starter.Active == true and starter.HeroId == "ecuyer_du_rempart" and starter.Name == info.Name and starter.Rarity == info.Rarity)
		assert(get(p).Tickets == 0)
		s:RequestStarterSummon(p)
		assert(get(p).Starter.Active == false and get(p).Starter.HeroId == nil)
		assert(get(e.player("B")).Starter.Active == false, "existing player")
	end)

	test("first paid summon uses the renormalized Epic+ pool, never a fixed hero", function()
		local SummonRules = modules.SummonRules
		local pool = SummonRules.buildPool(modules.RarityConfig.Tiers, HeroConfig.Heroes)
		local banners = modules.SummonBannerConfig.Banners
		local seen: { [string]: boolean } = {}
		local rarities: { [string]: boolean } = {}
		for tierValue = 1, 10000 do
			for heroValue = 1, 3 do
				for _, banner in banners do
					-- même suite de tirages pour la règle de référence (roll) et pour la vraie transaction
					local function picker(): (number) -> number
						local calls = 0
						return function(n: number): number
							calls += 1
							return if calls == 1 then math.min(tierValue, n) else math.clamp(heroValue, 1, n)
						end
					end
					local expected = SummonRules.roll(SummonRules.guaranteePool(pool, 4), banner, picker())
					local data = { Currencies = { SummonTickets = 1 }, Summons = { Total = 0 }, Kingdom = { VisualState = 1 },
						Heroes = {}, Hotbar = table.create(HeroConfig.HotbarSize, "") }
					local result = SummonRules.summon(data, SummonConfig, function() return "X" end, picker(), pool, banner)
					assert(result and result.HeroId == expected, `first paid summon = Epic+ roll ({tierValue}, {heroValue}, {banner.Id})`)
					assert(result.First == true and data.Summons.Total == 1 and data.Kingdom.VisualState == 2)
					seen[result.HeroId] = true
					rarities[HeroConfig.Heroes[result.HeroId].Rarity] = true
				end
			end
		end
		local distinct, tiers = 0, 0
		for _ in seen do distinct += 1 end
		for _ in rarities do tiers += 1 end
		assert(distinct > 10 and tiers == #modules.RarityConfig.Tiers - 3, `many heroes and every rarity possible on the first paid summon ({distinct} heroes, {tiers} rarities)`)
	end)

	test("summon refused without ticket; accepted with 1 -> ticket 0, rolled hero saved (test RNG gives tireuse)", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local none, reason = s:RequestSummon(p)
		assert(none == nil and reason == "pas de ticket d'invocation")
		e.data[p].Currencies.SummonTickets = 1
		local got = s:RequestSummon(p)
		assert(got and modules.RarityConfig.Rank[got.Rarity] >= 4 and got.New == true and got.Name == HeroConfig.Heroes[got.HeroId].Name)
		local d = e.data[p]
		assert(d.Currencies.SummonTickets == 0 and d.Summons.Total == 1)
		assert(d.Heroes[got.InstanceId].HeroId == got.HeroId, "saved with the real HeroId")
		assert(d.Hotbar[1] ~= got.InstanceId and d.Hotbar[2] == got.InstanceId, "first free shortcut")
		for _, hero in d.Heroes do assert(hero.HeroId ~= "Tireur" and hero.HeroId ~= "Epeiste") end
	end)

	test("first summon: kingdom VisualState 1 -> 2 once, Refresh called; next summon does not progress", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A", { tickets = 3 })
		local before = #e.refreshed
		s:RequestSummon(p)
		assert(e.data[p].Kingdom.VisualState == 2 and e.data[p].Kingdom.Level == 1, "VisualState only, Level untouched")
		assert(#e.refreshed == before + 1 and e.refreshed[#e.refreshed].visual == 2, "Refresh after the commit")
		e.data[p].Kingdom.VisualState = 1 -- même si l'état redescendait, plus aucune progression
		s:RequestSummon(p)
		assert(e.data[p].Kingdom.VisualState == 1 and e.data[p].Summons.Total == 2)
	end)

	test("instances unique; duplicates allowed (same HeroId, other InstanceId), New true then false", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A", { tickets = 4 })
		local first = s:RequestSummon(p)
		local results = { first }
		for _ = 1, 3 do table.insert(results, (s:RequestSummon(p))) end
		local seen = {}
		local tireuses = 0
		for _, r in results do
			assert(r and not seen[r.InstanceId], "unique instance")
			seen[r.InstanceId] = true
			if r.HeroId == "tireuse_des_faubourgs" then tireuses += 1 end
		end
		assert(first.New == true)
		for i = 2, #results do
			assert(results[i].New == false, "with the test RNG, every later roll is a hero already owned (starter or tireuse)")
		end
		assert(count(e.data[p].Heroes) == 5 and e.data[p].Currencies.SummonTickets == 0)
		local known = HeroConfig.Heroes
		for _, hero in e.data[p].Heroes do assert(known[hero.HeroId], "pool only gives activated heroes") end
	end)

	test("instance ids sort in acquisition order: starter first (kingdom Heros_1), summons after", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A", { tickets = 3 })
		local starterId = e.data[p].Hotbar[1]
		local ids = { starterId }
		for _ = 1, 3 do table.insert(ids, (s:RequestSummon(p)).InstanceId) end
		for i = 2, #ids do assert(ids[i - 1] < ids[i], `{ids[i - 1]} < {ids[i]}`) end
		assert(string.match(starterId, "^H_T%d+_") ~= nil, "timestamped id (KingdomService ranks legacy ids first)")
	end)

	test("hotbar full: new hero kept in the collection only", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A", { tickets = 1 })
		local d = e.data[p]
		for i = 2, HeroConfig.HotbarSize do
			d.Heroes["F" .. i] = { HeroId = "ecuyer_du_rempart", Level = 1 }
			d.Hotbar[i] = "F" .. i
		end
		local bar = table.concat(d.Hotbar, "|")
		local got = s:RequestSummon(p)
		assert(got and d.Heroes[got.InstanceId] and table.find(d.Hotbar, got.InstanceId) == nil)
		assert(table.concat(d.Hotbar, "|") == bar and #d.Hotbar == HeroConfig.HotbarSize)
	end)

	local function request(e: any, p: any, quantity: number): any
		local state = e.remote("GetSummonState").OnServerInvoke(p)
		return {BannerId=state.BannerId,Slot=state.Slot,Quantity=quantity,ExpectedTotal=state.ExpectedTotal}
	end
	test("V2 duplicate version and reentry: one debit and one collection publication", function()
		local e=fixture();local s=e.start();local p=e.player("A",{tickets=200})
		local req=request(e,p,100)
		local nested
		e.onGuid=function() if not nested then nested={s:RequestSummonBatch(p,req)} end end
		local before=#e.events(p,"HeroesChanged")
		local ok,batch=e.remote("RequestSummon").OnServerInvoke(p,req)
		assert(ok and #batch.Results==100 and nested[1]==nil)
		assert(e.remote("RequestSummon").OnServerInvoke(p,req)==false)
		assert(e.data[p].Currencies.SummonTickets==100 and e.data[p].Summons.Total==100)
		assert(#e.events(p,"HeroesChanged")==before+1 and #e.events(p,"HeroObtained")==0)
		assert(count(e.data[p].Heroes)==101)
	end)
	test("V2 network rejects forged fields, quantity, banner and stale rotation without debit", function()
		local e=fixture();e.start();local p=e.player("A",{tickets=100})
		local invoke=e.remote("RequestSummon").OnServerInvoke
		assert(invoke(p,request(e,p,10),0)==false, "coût ajouté en argument refusé")
		for _,bad in {"royaume",0,{}, {Quantity=0}} do assert(invoke(p,bad)==false) end
		for key,value in {Cost=0,HeroId="barde_de_fer",Rates={},Quantity=11,Slot=-1,BannerId="unknown",ExpectedTotal=-1} do
			local req=request(e,p,10);req[key]=value;assert(invoke(p,req)==false,key)
		end
		assert(e.data[p].Currencies.SummonTickets==100 and e.data[p].Summons.Total==0)
		local ok,result=invoke(p,request(e,p,10))
		assert(ok and #result.Results==10 and modules.RarityConfig.Rank[result.Results[1].Rarity]>=4)
	end)

	test("GetSummonState: own tickets and cost only; nil before data is loaded", function()
		local e = fixture()
		e.start()
		local a = e.player("A", { tickets = 3 })
		local b = e.player("B", { tickets = 7, portal = vector(300, 3, 0) })
		local get = e.remote("GetSummonState").OnServerInvoke
		local sa, sb = get(a), get(b)
		assert(sa.Tickets == 3 and sa.Cost == SummonConfig.Cost and sb.Tickets == 7)
		a.attributes.DataLoaded = nil
		assert(get(a) == nil)
	end)

	-- Tirage par rareté (SummonRules pur, vraies HeroConfig / RarityConfig / bannières) -------------

	local SummonRules = modules.SummonRules
	local Rarity = modules.RarityConfig

	test("pool: 10 tiers, chances sum to 10 000, every hero exactly once in its rarity", function()
		local pool = SummonRules.buildPool(Rarity.Tiers, HeroConfig.Heroes)
		assert(#pool.Tiers == 10 and pool.Total == 10000)
		local seen, total = {}, 0
		for i, tier in pool.Tiers do
			assert(tier.Id == Rarity.Tiers[i].Id and tier.Weight == Rarity.Tiers[i].Weight, tier.Id .. " keeps its own chance")
			assert(#tier.Heroes > 0, tier.Id .. " has heroes")
			for _, heroId in tier.Heroes do
				assert(not seen[heroId] and HeroConfig.Heroes[heroId].Rarity == tier.Id)
				seen[heroId] = true
				total += 1
			end
		end
		assert(total == 60)
		assert(pool.Tiers[1].Heroes[1] == "ecuyer_du_rempart", "catalog order")
	end)

	test("pool: an empty rarity hands its chance to the nearest lower one (upper if none)", function()
		local catalog = {
			a = { Rarity = "PeuCommun", Order = 1 },
			b = { Rarity = "Legendaire", Order = 2 },
		}
		local pool = SummonRules.buildPool(Rarity.Tiers, catalog)
		local weights = {}
		for _, tier in pool.Tiers do weights[tier.Id] = tier.Weight end
		assert(weights.Commun == 0, "nothing below Peu commun: Commun goes up")
		assert(weights.PeuCommun == 5000 + 2500 + 1300 + 700)
		assert(weights.Legendaire == 350 + 100 + 30 + 12 + 6 + 2)
		assert(pool.Total == 10000)
	end)

	test("roll: tier boundaries follow the weights exactly; each tier is reachable", function()
		local pool = SummonRules.buildPool(Rarity.Tiers, HeroConfig.Heroes)
		local function rollAt(value: number): string
			local first = true
			return SummonRules.roll(pool, nil, function(n: number): number
				if first then first = false; return value end
				return 1
			end)
		end
		local cumulative = 0
		for _, tier in Rarity.Tiers do
			local low, high = cumulative + 1, cumulative + tier.Weight
			assert(HeroConfig.Heroes[rollAt(low)].Rarity == tier.Id, tier.Id .. " low")
			assert(HeroConfig.Heroes[rollAt(high)].Rarity == tier.Id, tier.Id .. " high")
			cumulative = high
		end
		assert(cumulative == 10000)
		-- toutes les valeurs 1..10000 : chaque rareté sort exactement Weight fois
		local counts = {}
		for v = 1, 10000 do
			local r = HeroConfig.Heroes[rollAt(v)].Rarity
			counts[r] = (counts[r] or 0) + 1
		end
		for _, tier in Rarity.Tiers do assert(counts[tier.Id] == tier.Weight, tier.Id) end
	end)

	test("banner: featured hero of the rolled rarity comes out with FeaturedShare; other rarities untouched", function()
		local pool = SummonRules.buildPool(Rarity.Tiers, HeroConfig.Heroes)
		local banner = modules.SummonBannerConfig.ById.royaume
		local legendaryStart = 5000 + 2500 + 1300 + 700 + 1
		local function sequence(values: { number }): (number) -> number
			local i = 0
			return function(n: number): number
				i += 1
				return math.clamp(values[i] or 1, 1, n)
			end
		end
		-- Légendaire tiré, part mise en avant (50 <= 50) : un héros Featured de ce palier
		local featured = SummonRules.roll(pool, banner, sequence({ legendaryStart, 50, 1 }))
		assert(table.find(banner.Featured, featured) and HeroConfig.Heroes[featured].Rarity == "Legendaire", featured)
		-- 51 > 50 : n'importe quel héros Légendaire (ici le premier du catalogue)
		local any = SummonRules.roll(pool, banner, sequence({ legendaryStart, 51, 1 }))
		assert(any == pool.Tiers[5].Heroes[1])
		-- Commun : aucune mise en avant possible, un seul pick après le palier
		local calls = 0
		local commun = SummonRules.roll(pool, banner, function(n: number): number calls += 1; return 1 end)
		assert(HeroConfig.Heroes[commun].Rarity == "Commun" and calls == 2)
		for _, b in modules.SummonBannerConfig.Banners do
			for _, heroId in b.Featured do assert(HeroConfig.Heroes[heroId], b.Id .. " " .. heroId) end
		end
		assert(#SummonRules.configProblems(SummonConfig, HeroConfig.Heroes, Rarity.Tiers, modules.SummonBannerConfig.Banners) == 0)
	end)

	test("portal: out of range refused; near ANOTHER player's portal refused; only its own plot portal", function()
		local e = fixture()
		local s = e.start()
		local a = e.player("A", { tickets = 1, portal = vector(0, 3, 0) })
		local b = e.player("B", { tickets = 1, portal = vector(200, 3, 0) })
		e.moveTo(a, vector(SummonConfig.MaxDistance + 1, 3, 0))
		assert(select(2, s:RequestSummon(a)) == "approche-toi de ton portail")
		e.moveTo(a, vector(200, 3, 0)) -- au pied du portail de B, avec un ticket
		assert(select(2, s:RequestSummon(a)) == "approche-toi de ton portail")
		assert(e.data[a].Currencies.SummonTickets == 1 and count(e.data[a].Heroes) == 1)
		e.moveTo(a, vector(SummonConfig.MaxDistance - 1, 40, 0)) -- distance horizontale
		assert(s:RequestSummon(a) ~= nil)
		assert(e.data[b].Currencies.SummonTickets == 1, "B untouched")
	end)

	test("refusals: profile missing, data not loaded, no plot, no portal, dead or missing character", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A", { tickets = 1 })
		local data = e.data[p]
		e.data[p] = nil
		assert(select(2, s:RequestSummon(p)) == "données non chargées")
		e.data[p] = data
		p.attributes.DataLoaded = nil
		assert(select(2, s:RequestSummon(p)) == "données non chargées")
		p.attributes.DataLoaded = true
		local plot = e.plots[p]
		e.plots[p] = nil
		assert(select(2, s:RequestSummon(p)) == "aucun portail")
		e.plots[p] = inst("Model", "PlotSansPortail")
		assert(select(2, s:RequestSummon(p)) == "aucun portail")
		e.plots[p] = plot
		p.Character:FindFirstChild("Humanoid").Health = 0
		assert(select(2, s:RequestSummon(p)) == "personnage indisponible")
		p.Character = nil
		assert(select(2, s:RequestSummon(p)) == "personnage indisponible")
		assert(data.Currencies.SummonTickets == 1 and count(data.Heroes) == 1, "nothing consumed")
	end)

	test("HeroObtained only to the summoner, payload decided by the server; HeroesChanged pushed", function()
		local e = fixture()
		local s = e.start()
		local a = e.player("A", { tickets = 1 })
		local b = e.player("B", { tickets = 1, portal = vector(500, 3, 0) })
		e.moveTo(b, vector(500, 3, 0))
		local callbacks = {}
		s:OnHeroObtained(function(pl: any, o: any) table.insert(callbacks, { pl, o }) end)
		local changedBefore = #e.events(a, "HeroesChanged")
		local got = s:RequestSummon(a)
		local evA, evB = e.events(a, "HeroObtained"), e.events(b, "HeroObtained")
		assert(#evA == 1 and #evB == 0)
		local o = evA[1]
		assert(o.InstanceId == got.InstanceId and o.HeroId == got.HeroId and o.Name == HeroConfig.Heroes[got.HeroId].Name and o.New == true)
		assert(#e.events(a, "HeroesChanged") == changedBefore + 1)
		assert(#callbacks == 1 and callbacks[1][1] == a and callbacks[1][2].HeroId == got.HeroId)
	end)

	test("two players: independent starters, tickets, rolls, kingdoms", function()
		local e = fixture()
		local s = e.start()
		local a = e.player("A", { tickets = 1 })
		local b = e.player("B", { tickets = 2, portal = vector(300, 3, 0) })
		e.moveTo(b, vector(300, 3, 0))
		local ra = s:RequestSummon(a)
		local rb = s:RequestSummon(b)
		assert(modules.RarityConfig.Rank[ra.Rarity] >= 4 and modules.RarityConfig.Rank[rb.Rarity] >= 4, "each profile has its own first roll")
		assert(ra.InstanceId ~= rb.InstanceId)
		assert(e.data[a].Currencies.SummonTickets == 0 and e.data[b].Currencies.SummonTickets == 1)
		assert(e.data[a].Kingdom.VisualState == 2 and e.data[b].Kingdom.VisualState == 2)
		assert(count(e.data[a].Heroes) == 2 and count(e.data[b].Heroes) == 2)
		assert(e.data[a].Heroes[rb.InstanceId] == nil and e.data[b].Heroes[ra.InstanceId] == nil)
	end)

	test("GetCombatHero: real HeroId + temporary profile/template; AddHero refuses non-activated ids", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A", { tickets = 1 })
		local starterId = e.data[p].Hotbar[1]
		local hero = s:GetCombatHero(p, starterId)
		assert(hero.HeroId == "ecuyer_du_rempart" and hero.CombatProfile == "Epeiste" and hero.CombatTemplate == "Heros_EcuyerDuRempart")
		local got = s:RequestSummon(p)
		local t = s:GetCombatHero(p, got.InstanceId)
		assert(t.HeroId == got.HeroId and t.CombatProfile == HeroConfig.Heroes[got.HeroId].CombatProfile and t.CombatTemplate == (HeroConfig.Heroes[got.HeroId].CombatTemplate or got.HeroId))
		assert(s:AddHero(p, "Epeiste") == nil and s:AddHero(p, "heros_retire") == nil)
		assert(s:AddHero(p, "barde_de_fer") ~= nil, "every catalog hero is activated")
		assert(s:AddHero(p, "tireuse_des_faubourgs") ~= nil)
	end)

	test("client hero models: activated heroes cloned to ReplicatedStorage.Assets.Heros, no script, no collision", function()
		local e = fixture()
		e.start()
		local shared = e.replicated:FindFirstChild("Assets")
		local folder = shared and shared:FindFirstChild("Heros")
		assert(folder, "ReplicatedStorage.Assets.Heros created")
		local ids: any = {}
		for _, m in folder:GetChildren() do
			ids[m:GetAttribute("HeroId")] = m
			for _, d in m:GetDescendants() do
				assert(not d:IsA("LuaSourceContainer"), "script stripped")
				if d:IsA("BasePart") then assert(d.Anchored and not d.CanCollide and not d.CanTouch and not d.CanQuery) end
			end
		end
		assert(ids.ecuyer_du_rempart and ids.tireuse_des_faubourgs and ids.barde_de_fer and count(ids) == 3, "activated heroes present in ServerStorage, never the one without HeroId")
		local source = e.serverHeroes:GetChildren()[1]
		assert(#source:GetChildren() == 2 and source:FindFirstChild("Parasite"), "ServerStorage source untouched")
	end)

	test("missing ServerStorage.Assets.Heros: warning, service still works", function()
		local e = fixture({ noAssets = true })
		local s = e.start()
		assert(#e.warnings >= 1)
		local p = e.player("A", { tickets = 1 })
		assert(s:RequestSummon(p) ~= nil)
	end)

	-- Sécurité (#12) -----------------------------------------------------------------------------

	local function leaveHero(e: any, p: any)
		p.Parent = nil
		for _, fn in e.removing do fn(p) end
	end

	test("#12 double summon: 1 ticket, 20 RequestSummon -> 1 success, 19 refused, 1 instance, 1 HeroObtained", function()
		local e = fixture()
		e.start()
		local p = e.player("A", { tickets = 1 })
		local invoke = e.remote("RequestSummon").OnServerInvoke
		local ok, refused = 0, 0
		local req = request(e,p,1)
		for _ = 1, 20 do
			if invoke(p,req) == true then ok += 1 else refused += 1 end
		end
		assert(ok == 1 and refused == 19, `{ok} / {refused}`)
		assert(e.data[p].Currencies.SummonTickets == 0 and count(e.data[p].Heroes) == 2, "starter + one summoned hero")
		assert(#e.events(p, "HeroObtained") == 0 and e.data[p].Summons.Total == 1)
	end)

	test("#12 summon never consumes a ticket without a hero: a failure inside the transaction changes nothing", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A", { tickets = 1 })
		local before = count(e.data[p].Heroes)
		e.failGuid = true -- l'identifiant d'exemplaire ne peut pas être créé
		local got, why = s:RequestSummon(p)
		assert(got == nil and why == "invocation impossible")
		assert(e.data[p].Currencies.SummonTickets == 1, "ticket kept")
		assert(count(e.data[p].Heroes) == before and e.data[p].Summons.Total == 0, "no hero, no count")
		assert(#e.events(p, "HeroObtained") == 0)
		e.failGuid = false
		assert(s:RequestSummon(p) ~= nil and e.data[p].Currencies.SummonTickets == 0, "works again, once")
	end)

	test("#12 summon then disconnect: committed (ticket 0 + hero) or refused (nothing); never half", function()
		-- Cas A : la transaction est faite avant le départ → au rejoin ticket 0, héros présent, pas de 2e invocation
		local e = fixture()
		local s = e.start()
		local p = e.player("A", { tickets = 1 })
		local got = s:RequestSummon(p)
		leaveHero(e, p)
		local d = e.data[p]
		assert(got and d.Currencies.SummonTickets == 0 and d.Heroes[got.InstanceId], "saved state is coherent")
		-- rejoin : même sauvegarde, nouvel objet Player ; aucune invocation gratuite
		local back = e.player("A2", { tickets = 0 })
		e.data[back] = d
		for _, fn in e.ready do fn(back, d) end
		local again, why = s:RequestSummon(back)
		assert(again == nil and why == "pas de ticket d'invocation" and count(d.Heroes) == 2)
		-- Cas B : refusé avant toute mutation (joueur déjà parti)
		local e2 = fixture()
		local s2 = e2.start()
		local q = e2.player("B", { tickets = 1 })
		leaveHero(e2, q)
		local none, why2 = s2:RequestSummon(q)
		assert(none == nil and why2 == "données non chargées")
		assert(e2.data[q].Currencies.SummonTickets == 1 and count(e2.data[q].Heroes) == 1, "ticket kept, no hero")
	end)

	test("#12 HotbarAction fuzz: absurd values refused cleanly, hotbar unchanged; another player's hero refused", function()
		local e = fixture()
		e.start()
		local a = e.player("A", { tickets = 1 })
		local b = e.player("B", { portal = vector(300, 3, 0) })
		local s = e.service
		-- la remote ajoute un anti-spam (0,1 s) : on traverse la méthode qu'elle appelle, puis la remote une fois
		local function edit(p: any, ...: any): any return s:HotbarAction(p, ...) end
		local bar = table.concat(e.data[a].Hotbar, "|")
		local foreign = e.data[b].Hotbar[1]
		local fake: any = setmetatable({}, { __tostring = function() return "Instance" end })
		local cases: { any } = {
			{ "Assign", foreign, 2 }, { "Assign", "inconnu", 2 }, { "Assign", 42, 2 },
			{ "Assign", e.data[a].Hotbar[1], 0 }, { "Assign", e.data[a].Hotbar[1], -1 }, { "Assign", e.data[a].Hotbar[1], 11 },
			{ "Assign", e.data[a].Hotbar[1], 2.5 }, { "Assign", e.data[a].Hotbar[1], 0 / 0 }, { "Assign", e.data[a].Hotbar[1], math.huge },
			{ "Clear", {} }, { "Clear", "1" }, { "Swap", 1, 1e9 }, { "Swap", fake, 2 }, { "Detruire", 1 }, { 42 }, { fake }, {},
		}
		for _, args in cases do
			local okCall, ok = pcall(edit, a, table.unpack(args))
			assert(okCall, "no server error for " .. tostring(args[1]))
			assert(ok == false, `refused: {tostring(args[1])} {tostring(args[2])} {tostring(args[3])}`)
		end
		local okRemote, okR = pcall(e.remote("HotbarAction").OnServerInvoke, a, "Assign", foreign, 2)
		assert(okRemote and okR == false, "remote refuses too")
		assert(table.concat(e.data[a].Hotbar, "|") == bar, "hotbar unchanged")
		assert(e.data[b].Heroes[foreign] and not e.data[a].Heroes[foreign], "B's hero never moved to A")
	end)

	test("#12 cross-player: B's portal and B's hero instance are useless to A; A's data never changes B's", function()
		local e = fixture()
		local s = e.start()
		local a = e.player("A", { tickets = 1, portal = vector(0, 3, 0) })
		local b = e.player("B", { tickets = 1, portal = vector(500, 3, 0) })
		e.moveTo(a, vector(500, 3, 0)) -- au pied du portail de B
		assert(select(2, s:RequestSummon(a)) == "approche-toi de ton portail")
		local foreign = e.data[b].Hotbar[1]
		assert(s:GetCombatHero(a, foreign) == nil, "B's HeroInstanceId is not A's hero")
		assert(e.data[a].Currencies.SummonTickets == 1 and e.data[b].Currencies.SummonTickets == 1)
	end)

	test("#12 PlayerRemoving clears per-player server state (summon lock, anti-spam)", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A", { tickets = 2 })
		e.remote("HotbarAction").OnServerInvoke(p, "Clear", 3)
		leaveHero(e, p)
		-- un nouvel objet joueur ne bloque sur rien : pas de verrou d'invocation fantôme
		local back = e.player("A2", { tickets = 1 })
		assert(s:RequestSummon(back) ~= nil, "no ghost summon lock")
	end)

	test("#12 defence in depth: the summon transaction re-checks the ticket itself (no CanSummon)", function()
		local rules = modules.SummonRules
		local data = { Currencies = { SummonTickets = 0 }, Heroes = {}, Hotbar = table.create(HeroConfig.HotbarSize, ""),
			Summons = { Total = 3 }, Kingdom = { VisualState = 2 } }
		local pool = rules.buildPool(modules.RarityConfig.Tiers, HeroConfig.Heroes)
		local made = 0
		local got, why = rules.summon(data, SummonConfig, function(): string made += 1; return "X" end, function(): number return 1 end, pool, nil)
		assert(got == nil and why == "pas assez de tickets d'invocation" and made == 0 and next(data.Heroes) == nil)
	end)

	test("#12 summon lock: a request re-entering during the transaction is refused", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A", { tickets = 2 })
		local inner: any = nil
		e.onGuid = function()
			if inner == nil then inner = { s:RequestSummon(p) } end -- ré-entrée pendant la transaction
		end
		local got = s:RequestSummon(p)
		e.onGuid = nil
		assert(got ~= nil and inner and inner[1] == nil and inner[2] == "invocation déjà en cours", tostring(inner and inner[2]))
		assert(e.data[p].Currencies.SummonTickets == 1 and e.data[p].Summons.Total == 1, "one summon only")
	end)

	-- Niveaux et XP (#68) -----------------------------------------------------------------

	local function heroOf(e: any, p: any, id: string, heroId: string, level: number, xp: number)
		e.data[p].Heroes[id] = { HeroId = heroId, Level = level, XP = xp }
	end

	test("#68 combat roster: frozen per slot (InstanceId, HeroId, profile, Level, level stats); duplicates independent", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local starter = e.data[p].Hotbar[1]
		e.data[p].Heroes[starter].Level, e.data[p].Heroes[starter].XP = 3, 40
		heroOf(e, p, "D", "ecuyer_du_rempart", 1, 0)
		local roster = s:GetCombatRoster(p, { [5] = starter, [2] = "D" })
		assert(roster and roster[5].HeroInstanceId == starter and roster[5].HeroId == "ecuyer_du_rempart" and roster[5].CombatProfile == "Epeiste")
		assert(roster[5].Level == 3 and roster[5].Stats.MaxHealth == 165 and roster[5].Stats.AttackDamage == 18, "Lv3: +10 %")
		assert(roster[2].Level == 1 and roster[2].Stats.MaxHealth == 150 and roster[2].Stats.AttackDamage == 16, "same HeroId, Lv1: base stats")
		assert(roster[5].Stats.UltimateDamage == modules.CombatConfig.Heroes.Epeiste.UltimateDamage, "ultimate unchanged")
		local none, why = s:GetCombatRoster(p, { [1] = "Fantome" })
		assert(none == nil and why == "héros inconnu")
	end)

	-- #73 : objets possédés et portés, posés directement dans les données (les mutations sont testées par
	-- tools/test-equipment.ps1) ; HeroService ne fait que calculer.
	local function wear(e: any, p: any, heroInstanceId: string, items: { [string]: string })
		local d = e.data[p]
		d.Inventory = d.Inventory or { Equipment = {}, Resources = {} }
		d.HeroEquipment = d.HeroEquipment or {}
		d.HeroEquipment[heroInstanceId] = d.HeroEquipment[heroInstanceId] or {}
		for instanceId, itemId in items do
			d.Inventory.Equipment[instanceId] = { ItemId = itemId, UpgradeLevel = 0 }
			d.HeroEquipment[heroInstanceId][modules.ItemConfig.Items[itemId].SlotType] = instanceId
		end
	end

	test("#73 combat roster: level stats THEN flat equipment bonus; only PV / ATK change; Lv1 without item unchanged", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local starter = e.data[p].Hotbar[1]
		e.data[p].Heroes[starter].Level = 2
		wear(e, p, starter, { I_arm = "item_008", I_wpn = "item_015" }) -- +45 PV, +6 ATK
		heroOf(e, p, "D", "ecuyer_du_rempart", 1, 0)
		local roster = s:GetCombatRoster(p, { [5] = starter, [2] = "D" })
		assert(roster and roster[5].Stats.MaxHealth == 158 + 45 and roster[5].Stats.AttackDamage == 17 + 6, `{roster[5].Stats.MaxHealth}/{roster[5].Stats.AttackDamage}`)
		assert(roster[5].EquipmentBonus.MaxHealth == 45 and roster[5].EquipmentBonus.AttackDamage == 6)
		local base = modules.CombatConfig.Heroes.Epeiste
		for _, key in { "AttackInterval", "AttackRange", "MoveSpeed", "EnergyPerAttack", "MaxEnergy", "UltimateDamage" } do
			assert(roster[5].Stats[key] == base[key], key .. " unchanged")
		end
		assert(roster[2].Stats.MaxHealth == 150 and roster[2].Stats.AttackDamage == 16, "same HeroId, other copy, no item: current stats")
	end)

	test("#73 roster frozen: changing the equipment after the launch never changes the roster already built", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local starter = e.data[p].Hotbar[1]
		wear(e, p, starter, { I_wpn = "item_042" })
		local roster = s:GetCombatRoster(p, { [5] = starter })
		assert(roster[5].Stats.AttackDamage == 16 + 12)
		e.data[p].HeroEquipment[starter] = nil
		assert(roster[5].Stats.AttackDamage == 28, "frozen copy")
		assert(s:GetCombatRoster(p, { [5] = starter })[5].Stats.AttackDamage == 16, "next launch reads the new state")
	end)

	test("#73 invalid links never reach the combat: wrong slot, missing item, item worn twice", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local starter = e.data[p].Hotbar[1]
		-- « Z » est après l'Écuyer « H_T… » dans l'ordre des identifiants : en cas de doublon, l'Écuyer garde l'objet
		heroOf(e, p, "Z", "ecuyer_du_rempart", 1, 0)
		wear(e, p, starter, { I_wpn = "item_015" })
		e.data[p].HeroEquipment.Z = { weapon = "I_wpn", helmet = "I_wpn", armor = "I_gone" } -- doublon, mauvais slot, objet absent
		local roster = s:GetCombatRoster(p, { [1] = "Z", [5] = starter })
		assert(roster[1].Stats.AttackDamage == 16 and roster[1].Stats.MaxHealth == 150, "Z gets nothing")
		assert(roster[5].EquipmentBonus.AttackDamage == 6 and roster[5].Stats.AttackDamage == 22, "the item is counted once, on its first holder")
	end)

	test("#73 hero view: final PV / ATK, level stats, equipment bonus and worn items per instance", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local starter = e.data[p].Hotbar[1]
		wear(e, p, starter, { I_arm = "item_008" })
		heroOf(e, p, "D", "ecuyer_du_rempart", 1, 0)
		local view = e.remote("GetHeroes").OnServerInvoke(p)
		local byId = {}
		for _, h in view.Heroes do byId[h.Id] = h end
		local a = byId[starter]
		assert(a.MaxHealth == 195 and a.BaseMaxHealth == 150 and a.AttackDamage == 16 and a.BaseAttackDamage == 16, `{a.MaxHealth}/{a.BaseMaxHealth}`)
		assert(a.EquipmentBonus.MaxHealth == 45 and a.Equipment.armor == "I_arm" and count(a.Equipment) == 1)
		assert(byId.D.MaxHealth == 150 and count(byId.D.Equipment) == 0 and byId.D.EquipmentBonus.MaxHealth == 0, "other copy independent")
		s:Push(p)
		local pushed = e.events(p, "HeroesChanged")
		assert(#pushed > 0 and pushed[#pushed].Heroes ~= nil, "Push sends the same view")
	end)

	test("#73 a removed hero frees its items (they stay in the inventory)", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		heroOf(e, p, "D", "ecuyer_du_rempart", 1, 0)
		wear(e, p, "D", { I_wpn = "item_015" })
		assert(s:RemoveHero(p, "D"))
		assert(e.data[p].HeroEquipment.D == nil and e.data[p].Inventory.Equipment.I_wpn ~= nil)
	end)

	test("#68 GrantCombatXP: only the given participants (placed heroes), collection hero 0, HeroesChanged with XP", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local starter = e.data[p].Hotbar[1]
		heroOf(e, p, "B", "tireuse_des_faubourgs", 1, 0)
		heroOf(e, p, "C", "barde_de_fer", 1, 0) -- reste dans la collection
		local pushed = #e.events(p, "HeroesChanged")
		local views = s:GrantCombatXP(p, { starter, "B" }, 1, 1)
		assert(#views == 2)
		for _, v in views do
			assert(v.XPGranted == 25 and v.LevelBefore == 1 and v.LevelAfter == 1 and v.XP == 25 and v.XPToNext == 100 and v.MaxLevel == 20)
		end
		assert(e.data[p].Heroes[starter].XP == 25 and e.data[p].Heroes.B.XP == 25 and e.data[p].Heroes.C.XP == 0, "collection hero: nothing")
		local changed = e.events(p, "HeroesChanged")
		assert(#changed == pushed + 1, "HeroesChanged pushed after the mutation")
		local last = changed[#changed]
		local found = false
		for _, hero in last.Heroes do
			if hero.Id == starter then found = hero.XP == 25 and hero.XPToNext == 100 and hero.MaxLevel == 20 end
		end
		assert(found, "view carries Level / XP / XPToNext")
	end)

	test("#68 GrantCombatXP: level up reported (LevelBefore -> LevelAfter), duplicate ids once, removed hero skipped", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local starter = e.data[p].Hotbar[1]
		e.data[p].Heroes[starter].XP = 90
		local views = s:GrantCombatXP(p, { starter, starter, "Disparu" }, 1, 2) -- 1-2 : 35 XP
		assert(#views == 1 and views[1].LevelBefore == 1 and views[1].LevelAfter == 2 and views[1].XP == 25 and views[1].XPToNext == 125)
		assert(e.data[p].Heroes[starter].Level == 2 and e.data[p].Heroes[starter].XP == 25)
	end)

	test("#68 GrantCombatXP: two players independent; unknown stage gives 0 XP; no data -> nothing", function()
		local e = fixture()
		local s = e.start()
		local a, b = e.player("A"), e.player("B")
		local ia, ib = e.data[a].Hotbar[1], e.data[b].Hotbar[1]
		s:GrantCombatXP(a, { ia }, 1, 5)
		assert(e.data[a].Heroes[ia].Level == 2 and e.data[b].Heroes[ib].Level == 1 and (e.data[b].Heroes[ib].XP or 0) == 0, `1-5 = 100 XP to A only (exactly Lv2): {e.data[a].Heroes[ia].Level}/{e.data[a].Heroes[ia].XP} {e.data[b].Heroes[ib].Level}/{tostring(e.data[b].Heroes[ib].XP)}`)
		assert(e.data[a].Heroes[ia].Level == 2 and e.data[a].Heroes[ia].XP == 0)
		s:GrantCombatXP(b, { ia }, 1, 1)
		assert(e.data[a].Heroes[ia].Level == 2 and e.data[a].Heroes[ia].XP == 0 and e.data[b].Heroes[ib].XP == 0, "B cannot grant XP to A's instance")
		local zero = s:GrantCombatXP(b, { ib }, 9, 9)
		assert(#zero == 1 and zero[1].XPGranted == 0 and e.data[b].Heroes[ib].XP == 0)
		local ghost = e.player("G")
		e.data[ghost] = nil
		assert(#s:GrantCombatXP(ghost, { "x" }, 1, 1) == 0)
	end)

	test("#69 GrantCombatXP in Elite: Elite table (1-1E = 60), Normal unchanged (1-1 = 25), level stats identical", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local starter = e.data[p].Hotbar[1]
		heroOf(e, p, "N", "ecuyer_du_rempart", 1, 0)
		local elite = s:GrantCombatXP(p, { starter }, 1, 1, "Elite")
		local normal = s:GrantCombatXP(p, { "N" }, 1, 1, "Normal")
		assert(elite[1].XPGranted == 60 and e.data[p].Heroes[starter].XP == 60)
		assert(normal[1].XPGranted == 25 and e.data[p].Heroes.N.XP == 25)
		e.data[p].Heroes[starter].Level = 2
		local roster = s:GetCombatRoster(p, { [5] = starter })
		assert(roster and roster[5].Stats.MaxHealth == 158, "a Lv2 hero has the same stats in Elite and Normal (roster ignores the mode)")
	end)

	test("#68 no client remote can grant XP or levels", function()
		local e = fixture()
		e.start()
		for _, folder in e.replicated:GetChildren() do
			if folder.Name == "Remotes" then
				for _, remote in folder:GetChildren() do
					local name = string.lower(remote.Name)
					assert(not (name:find("xp") or name:find("level") or name:find("niveau")), "no XP remote: " .. remote.Name)
				end
			end
		end
	end)

	test("V2 rotation UTC: boundaries, all banners, same time across servers and rejoin",function()
		local cfg=modules.SummonBannerConfig
		for slot=0,300 do
			local a,id,ends=cfg.active(slot*900)
			local b,id2=cfg.active(slot*900+899)
			local c,id3=cfg.active(slot*900+900)
			assert(a==b and id==id2 and id3==id+1 and ends==(slot+1)*900 and c~=a)
		end
	end)
	test("V2 exact odds include featured fallback, sum to 1, and guarantee excludes ranks 1-3",function()
		local r=modules.SummonRules
		local pool=r.buildPool(modules.RarityConfig.Tiers,HeroConfig.Heroes)
		for _,b in modules.SummonBannerConfig.Banners do
			local rates=r.rates(pool,b);local sum=0
			for _,probability in rates.Heroes do sum+=probability end
			assert(math.abs(sum-1)<1e-12)
			for _,tier in pool.Tiers do
				local n=0
				for _,id in tier.Heroes do if table.find(b.Featured,id) then n+=1 end end
				for _,id in tier.Heroes do
					local expected=tier.Weight/pool.Total*(if n==0 then 1/#tier.Heroes else .5/#tier.Heroes+(if table.find(b.Featured,id) then .5/n else 0))
					assert(math.abs(rates.Heroes[id]-expected)<1e-12)
				end
			end
			local guaranteed=r.rates(r.guaranteePool(pool,4),b);sum=0
			for id,probability in guaranteed.Heroes do
				if modules.RarityConfig.Rank[HeroConfig.Heroes[id].Rarity]<4 then assert(probability==0) end
				sum+=probability
			end
			assert(math.abs(sum-1)<1e-12)
		end
	end)
	test("V2 x1/x10/x100 cost, first-only guarantee, 100 distinct instances, new once per hero",function()
		local rules=modules.SummonRules
		local pool=rules.buildPool(modules.RarityConfig.Tiers,HeroConfig.Heroes)
		for _,q in {1,10,100} do
			local data={Heroes={},Hotbar=table.create(10,""),Summons={Total=0},Currencies={SummonTickets=q*2},Kingdom={VisualState=1}}
			local n=0
			local make=function() n+=1;return tostring(n) end
			local first=rules.batch(data,SummonConfig,q,make,function() return 1 end,pool,nil)
			assert(#first.Results==q and data.Currencies.SummonTickets==q and data.Summons.Total==q)
			assert(first.Results[1].Guaranteed and HeroConfig.Heroes[first.Results[1].HeroId].Rarity=="Epique")
			local seen={}
			for i,r in first.Results do
				assert(r.New==not seen[r.HeroId]);seen[r.HeroId]=true
				if i>1 then assert(not r.Guaranteed and HeroConfig.Heroes[r.HeroId].Rarity=="Commun") end
			end
			local second=rules.batch(data,SummonConfig,q,make,function() return 1 end,pool,nil)
			assert(not second.Guaranteed and count(data.Heroes)==q*2 and data.Currencies.SummonTickets==0)
			assert(HeroConfig.Heroes[second.Results[1].HeroId].Rarity=="Commun")
		end
	end)
	test("V2 error on last RNG/ID, duplicate ID, insufficient tickets: no partial batch",function()
		local rules=modules.SummonRules
		local pool=rules.buildPool(modules.RarityConfig.Tiers,HeroConfig.Heroes)
		for _,failure in {"last","duplicate","tickets"} do
			local d={Heroes={},Hotbar=table.create(10,""),Summons={Total=0},Currencies={SummonTickets=if failure=="tickets" then 99 else 100},Kingdom={VisualState=1}}
			local n=0
			pcall(rules.batch,d,SummonConfig,100,function()
				n+=1;if failure=="last" and n==100 then error("test") end
				return if failure=="duplicate" then "same" else tostring(n)
			end,function() return 1 end,pool,nil)
			assert(count(d.Heroes)==0 and d.Summons.Total==0 and d.Kingdom.VisualState==1)
			assert(d.Currencies.SummonTickets==(if failure=="tickets" then 99 else 100))
		end
	end)
	test("V2 paid counter survives rejoin, rejects replay, old paid profiles never regain guarantee",function()
		local e=fixture();local s=e.start();local a=e.player("A",{tickets=200})
		local req=request(e,a,100)
		local batch=s:RequestSummonBatch(a,req)
		assert(batch and batch.Guaranteed)
		local saved=e.data[a]
		local back=e.player("Back",{tickets=0});e.data[back]=saved
		assert(s:RequestSummonBatch(back,req)==nil)
		local nextBatch=s:RequestSummonBatch(back,request(e,back,100))
		assert(nextBatch and not nextBatch.Guaranteed and saved.Summons.Total==200)
		local legacy=e.player("Legacy",{tickets=1});e.data[legacy].Summons.Total=9
		assert(e.remote("GetSummonState").OnServerInvoke(legacy).Guarantee==false)
	end)
	test("V2 two players x100: independent balances, versions, guarantees and 200 unique ids",function()
		local e=fixture();local service=e.start()
		local a=e.player("A",{tickets=100})
		local b=e.player("B",{tickets=100,portal=vector(300,3,0)})
		e.moveTo(b,vector(300,3,0))
		local ra=service:RequestSummonBatch(a,request(e,a,100))
		assert(ra and ra.Guaranteed and e.data[b].Summons.Total==0 and e.data[b].Currencies.SummonTickets==100)
		local rb=service:RequestSummonBatch(b,request(e,b,100))
		assert(rb and rb.Guaranteed and e.data[a].Currencies.SummonTickets==0 and e.data[b].Currencies.SummonTickets==0)
		local ids={}
		for _,batch in {ra,rb} do for _,hero in batch.Results do assert(not ids[hero.InstanceId]);ids[hero.InstanceId]=true end end
		assert(count(ids)==200 and e.data[a].Summons.Total==100 and e.data[b].Summons.Total==100)
	end)

	print(`HeroService: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{failed} HeroService test(s) failed`)
	end
end
