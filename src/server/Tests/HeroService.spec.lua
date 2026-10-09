--!strict
-- Hors du dossier Services : jamais exécuté par le bootstrap.
-- Exécute le vrai HeroService (héros de départ, invocation, HeroObtained, copie client des modèles)
-- avec les vraies HeroConfig, SummonConfig, CombatConfig, HeroRules et SummonRules, et des doubles de
-- DataService, PlotService, KingdomService et des API Roblox utilisées.

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
			Config = { HeroConfig = HeroConfig } }
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
		local kingdomService: any = {}
		function kingdomService:Refresh(p: any): boolean
			table.insert(env.refreshed, { player = p, visual = env.data[p] and env.data[p].Kingdom.VisualState })
			local hook: any = env.onRefresh
			if hook ~= nil then (hook :: any)(p) end
			return true
		end
		env.script = { Parent = { DataService = dataService, PlotService = plotService, KingdomService = kingdomService,
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
				DataVersion = 2,
				Currencies = { Gold = 0, Gems = 0, SummonTickets = opts.tickets or 0 },
				Progression = { CurrentZone = 1, HighestStage = 0, FirstClears = {} },
				Heroes = {}, Team = {}, Hotbar = table.create(HeroConfig.HotbarSize, ""),
				Summons = { Total = 0 },
				Kingdom = { Level = 1, VisualState = 1 },
				Quests = {}, Settings = { CombatSpeed = 1 },
			}
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

	test("new player: exactly 1 hero, ecuyer_du_rempart, shortcut 1, kingdom refreshed", function()
		local e = fixture()
		e.start()
		local p = e.player("A")
		local d = e.data[p]
		assert(count(d.Heroes) == 1)
		local id, hero = next(d.Heroes)
		assert(hero.HeroId == "ecuyer_du_rempart" and d.Hotbar[1] == id)
		for i = 2, HeroConfig.HotbarSize do assert(d.Hotbar[i] == "") end
		assert(d.Kingdom.VisualState == 1 and #e.refreshed == 1)
		assert(#e.events(p, "HeroesChanged") == 1, "collection pushed")
		-- rejoin : aucun starter supplémentaire
		for _, fn in e.ready do fn(p, d) end
		assert(count(d.Heroes) == 1)
	end)

	test("summon refused without ticket; accepted with 1 -> ticket 0, first roll tireuse_des_faubourgs", function()
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
			assert(results[i].New == false, "every later roll is a hero already owned (starter or tireuse)")
		end
		assert(count(e.data[p].Heroes) == 5 and e.data[p].Currencies.SummonTickets == 0)
		local known = HeroConfig.Heroes
		for _, hero in e.data[p].Heroes do assert(known[hero.HeroId], "pool only gives activated heroes") end
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

	test("remote ignores every client argument (HeroId, cost, result)", function()
		local e = fixture()
		e.start()
		local p = e.player("A", { tickets = 1 })
		local ok, r = e.remote("RequestSummon").OnServerInvoke(p, "barde_de_fer", 0, { HeroId = "barde_de_fer", New = true })
		assert(ok and r.HeroId == "tireuse_des_faubourgs" and e.data[p].Currencies.SummonTickets == 0)
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
		assert(hero.HeroId == "ecuyer_du_rempart" and hero.CombatProfile == "Epeiste" and hero.CombatTemplate == "Heros_Epeiste")
		local got = s:RequestSummon(p)
		local t = s:GetCombatHero(p, got.InstanceId)
		assert(t.HeroId == "tireuse_des_faubourgs" and t.CombatProfile == "Tireur" and t.CombatTemplate == "Heros_Tireur")
		assert(s:AddHero(p, "Epeiste") == nil and s:AddHero(p, "barde_de_fer") == nil)
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
		assert(ids.ecuyer_du_rempart and ids.tireuse_des_faubourgs and count(ids) == 2, "only activated heroes")
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

	print(`HeroService: {passed} passed, {failed} failed`)
	if failed > 0 then
		error(`{failed} HeroService test(s) failed`)
	end
end
