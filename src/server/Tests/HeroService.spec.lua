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
			Config = { HeroConfig = HeroConfig, RarityConfig = modules.RarityConfig, SummonBannerConfig = modules.SummonBannerConfig } }
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
			Parent = { Config = { CombatConfig = modules.CombatConfig, SummonConfig = SummonConfig },
				Heroes = { HeroRules = modules.HeroRules, SummonRules = modules.SummonRules } } } }
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
				DataVersion = 3,
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
				env.data[p].Heroes[id] = { HeroId = "ecuyer_du_rempart", Level = 1 }
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

	test("first paid summon uses the normal roll: Summons.Total == 0 never forces a HeroId (deterministic)", function()
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
					local expected = SummonRules.roll(pool, banner, picker())
					local data = { Currencies = { SummonTickets = 1 }, Summons = { Total = 0 }, Kingdom = { VisualState = 1 },
						Heroes = {}, Hotbar = table.create(HeroConfig.HotbarSize, "") }
					local result = SummonRules.summon(data, SummonConfig, function() return "X" end, picker(), pool, banner)
					assert(result and result.HeroId == expected, `first paid summon = normal roll ({tierValue}, {heroValue}, {banner.Id})`)
					assert(result.First == true and data.Summons.Total == 1 and data.Kingdom.VisualState == 2)
					seen[result.HeroId] = true
					rarities[HeroConfig.Heroes[result.HeroId].Rarity] = true
				end
			end
		end
		local distinct, tiers = 0, 0
		for _ in seen do distinct += 1 end
		for _ in rarities do tiers += 1 end
		assert(distinct > 10 and tiers == #modules.RarityConfig.Tiers, `many heroes and every rarity possible on the first paid summon ({distinct} heroes, {tiers} rarities)`)
	end)

	test("summon refused without ticket; accepted with 1 -> ticket 0, rolled hero saved (test RNG gives tireuse)", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A")
		local none, reason = s:RequestSummon(p)
		assert(none == nil and reason == "pas de ticket d'invocation")
		e.data[p].Currencies.SummonTickets = 1
		local got = s:RequestSummon(p)
		assert(got and got.HeroId == "tireuse_des_faubourgs" and got.New == true and got.Name == "Tireuse des Faubourgs")
		local d = e.data[p]
		assert(d.Currencies.SummonTickets == 0 and d.Summons.Total == 1)
		assert(d.Heroes[got.InstanceId].HeroId == "tireuse_des_faubourgs", "saved with the real HeroId")
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

	test("double request with 1 ticket: exactly 1 success, 1 hero created, ticket 0 (also re-entrant)", function()
		local e = fixture()
		local s = e.start()
		local p = e.player("A", { tickets = 1 })
		local reentrant: any = nil
		e.onRefresh = function(pl: any)
			if pl == p and reentrant == nil then reentrant = { s:RequestSummon(p) } end
		end
		local invoke = e.remote("RequestSummon").OnServerInvoke
		local ok1, r1 = invoke(p)
		local ok2, r2 = invoke(p)
		assert(ok1 == true and r1.HeroId == "tireuse_des_faubourgs")
		assert(ok2 == false and r2 == "pas de ticket d'invocation")
		assert(reentrant and reentrant[1] == nil, "a call issued during the commit is refused")
		assert(count(e.data[p].Heroes) == 2 and e.data[p].Currencies.SummonTickets == 0)
		assert(#e.events(p, "HeroObtained") == 1)
	end)

	test("remote: only a known banner id is read; HeroId, cost and result stay server-side", function()
		local e = fixture()
		e.start()
		local p = e.player("A", { tickets = 1 })
		local invoke = e.remote("RequestSummon").OnServerInvoke
		for _, bad in { "barde_de_fer", 0, { Id = "royaume" }, "" } :: { any } do
			local ok, why = invoke(p, bad, 0, { HeroId = "barde_de_fer", New = true })
			assert(ok == false and why == "bannière inconnue", tostring(bad))
		end
		assert(e.data[p].Currencies.SummonTickets == 1 and e.data[p].Summons.Total == 0, "nothing consumed")
		local ok, r = invoke(p, "aube", "barde_de_fer", 0, { HeroId = "barde_de_fer", New = true })
		assert(ok and r.HeroId == "tireuse_des_faubourgs" and r.Rarity == "Commun" and e.data[p].Currencies.SummonTickets == 0)
		e.data[p].Currencies.SummonTickets = 1
		local ok2, r2 = invoke(p) -- sans bannière : bannière par défaut
		assert(ok2 and modules.HeroConfig.Heroes[r2.HeroId] and r2.Rarity == modules.HeroConfig.Heroes[r2.HeroId].Rarity)
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
		assert(o.InstanceId == got.InstanceId and o.HeroId == "tireuse_des_faubourgs" and o.Name == "Tireuse des Faubourgs" and o.New == true)
		assert(#e.events(a, "HeroesChanged") == changedBefore + 1)
		assert(#callbacks == 1 and callbacks[1][1] == a and callbacks[1][2].HeroId == "tireuse_des_faubourgs")
	end)

	test("two players: independent starters, tickets, rolls, kingdoms", function()
		local e = fixture()
		local s = e.start()
		local a = e.player("A", { tickets = 1 })
		local b = e.player("B", { tickets = 2, portal = vector(300, 3, 0) })
		e.moveTo(b, vector(300, 3, 0))
		local ra = s:RequestSummon(a)
		local rb = s:RequestSummon(b)
		assert(ra.HeroId == "tireuse_des_faubourgs" and rb.HeroId == "tireuse_des_faubourgs", "each profile has its own first roll")
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
		assert(t.HeroId == "tireuse_des_faubourgs" and t.CombatProfile == "Tireur" and t.CombatTemplate == "tireuse_des_faubourgs")
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
		for _ = 1, 20 do
			if invoke(p) == true then ok += 1 else refused += 1 end
		end
		assert(ok == 1 and refused == 19, `{ok} / {refused}`)
		assert(e.data[p].Currencies.SummonTickets == 0 and count(e.data[p].Heroes) == 2, "starter + one summoned hero")
		assert(#e.events(p, "HeroObtained") == 1 and e.data[p].Summons.Total == 1)
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
		assert(got == nil and why == "pas de ticket d'invocation" and made == 0 and next(data.Heroes) == nil)
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

	print(`HeroService: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{failed} HeroService test(s) failed`)
	end
end
